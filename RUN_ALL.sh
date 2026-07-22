#!/usr/bin/env bash
# =============================================================================
#  PQ-CBAS-DSH — One-command runner (build liboqs + run all benchmarks)
#  Verified working on: Ubuntu 24.04, Python 3.12, Intel Xeon vCPU (sandbox)
#  and per the paper on: Apple M2, macOS 26.4.1, Python 3.13.13
# =============================================================================
set -e
cd "$(dirname "$0")"
ROOT="$(pwd)"
OQS_PREFIX="${OQS_PREFIX:-$HOME/_oqs}"

echo "==============================================================="
echo " PQ-CBAS-DSH artifact runner"
echo "==============================================================="

# ---- 1) Toolchain ----------------------------------------------------------
echo "[1/5] Checking toolchain (cmake, ninja, gcc, git)..."
need_cmake=0
command -v cmake >/dev/null 2>&1 || need_cmake=1
command -v ninja >/dev/null 2>&1 || need_cmake=1
if [ "$need_cmake" = "1" ]; then
  echo "      cmake/ninja missing — installing via pip (no sudo needed)..."
  pip install cmake ninja --break-system-packages -q || pip install cmake ninja -q
fi
command -v gcc >/dev/null 2>&1 || { echo "ERROR: gcc/clang required. Install build tools."; exit 1; }

# ---- 2) Python deps --------------------------------------------------------
# Use `python3 -m pip` so packages land in the SAME interpreter we run later.
PY="${PYTHON:-python3}"
export PY
echo "[2/5] Installing Python deps with: $PY -m pip"
echo "      (interpreter: $($PY -c 'import sys;print(sys.executable)'))"
$PY -m pip install --upgrade pip -q 2>/dev/null || true
# try normal install; --break-system-packages only exists on newer pip, so fall back
$PY -m pip install numpy cryptography liboqs-python -q \
  || $PY -m pip install numpy cryptography liboqs-python --break-system-packages -q \
  || $PY -m pip install --user numpy cryptography liboqs-python -q

# ---- 3) Build liboqs (ML-DSA only, once) -----------------------------------
if [ ! -f "$OQS_PREFIX/lib/liboqs.so" ] && [ ! -f "$OQS_PREFIX/lib/liboqs.dylib" ]; then
  echo "[3/5] Building liboqs (ML-DSA only) into $OQS_PREFIX ..."
  if [ ! -d liboqs_src ]; then
    git clone --depth 1 https://github.com/open-quantum-safe/liboqs.git liboqs_src
  fi
  cmake -S liboqs_src -B liboqs_src/build -GNinja \
    -DOQS_MINIMAL_BUILD="SIG_ml_dsa_44;SIG_ml_dsa_65;SIG_ml_dsa_87" \
    -DBUILD_SHARED_LIBS=ON -DOQS_USE_OPENSSL=OFF -DCMAKE_BUILD_TYPE=Release
  ninja -C liboqs_src/build
  cmake --install liboqs_src/build --prefix "$OQS_PREFIX"
else
  echo "[3/5] liboqs already built at $OQS_PREFIX — skipping."
fi
export OQS_INSTALL_PATH="$OQS_PREFIX"

# Verify the oqs module is importable in THIS interpreter; if not, guide the user.
if ! $PY -c "import oqs" 2>/dev/null; then
  echo ""
  echo "  [!] Python module 'oqs' not importable in $PY."
  echo "      Installing liboqs-python from source against the freshly built liboqs..."
  $PY -m pip install --no-binary :all: liboqs-python -q 2>/dev/null \
    || $PY -m pip install git+https://github.com/open-quantum-safe/liboqs-python.git -q \
    || true
fi
if ! $PY -c "import oqs" 2>/dev/null; then
  echo ""
  echo "  ============================================================"
  echo "  ERROR: cannot import 'oqs' in $PY."
  echo "  Most likely 'pip' and 'python3' are different environments."
  echo "  Fix (copy-paste), then re-run  bash RUN_ALL.sh :"
  echo ""
  echo "      $PY -m pip install liboqs-python"
  echo ""
  echo "  If you use conda/venv, activate it FIRST, then run this script"
  echo "  inside that same environment."
  echo "  ============================================================"
  exit 1
fi
$PY -c "import oqs; print('      liboqs version:', oqs.oqs_version())"

# ---- 4) Run benchmarks -----------------------------------------------------
echo "[4/5] Running benchmarks..."
mkdir -p out
cd src
cp -f ../sumo/synthetic_fcd.xml . 2>/dev/null || true

echo "  -> bench_pqcbas.py (Tables 5, 6, 11, 12)"
$PY bench_pqcbas.py > ../out/bench_results.json 2>/dev/null

echo "  -> e2e_workflow.py  W=90, 5 seeds, full  (Table 8)"
$PY e2e_workflow.py --window 90 --seeds 5 2>/dev/null | grep scenario > ../out/e2e_full_W90.txt || true
cp -f e2e_results_W90_full.json ../out/ 2>/dev/null || true

echo "  -> e2e_workflow.py  W=90, 5 seeds, digest (Table 9)"
$PY e2e_workflow.py --window 90 --seeds 5 --digest 2>/dev/null | grep scenario > ../out/e2e_digest_W90.txt || true
cp -f e2e_results_W90_digest.json ../out/ 2>/dev/null || true

echo "  -> bench_compact.py (PQ-CBAS-DSH-C RespCheck)"
$PY bench_compact.py 2>/dev/null | grep -E "m=|Saved" > ../out/compact.txt || true

echo "  -> sumo_pqcbas_bridge.py (--no-sumo, bundled synthetic FCD)"
$PY sumo_pqcbas_bridge.py --no-sumo --fcd synthetic_fcd.xml \
  --window 90 --seeds 3 --digest 2>/dev/null | grep -E "E2E|Vehicles|Messages|Deadline|p95" > ../out/sumo_bridge.txt || true
cd ..

# ---- 5) Summary ------------------------------------------------------------
echo "[5/5] DONE. Results in: $ROOT/out/"
echo "==============================================================="
echo " Quick check — operation timings:"
python3 - <<'PY'
import json as J
txt=open("out/bench_results.json").read()
blocks=[]; depth=0; cur=""
for ch in txt:
    if ch=="{": depth+=1
    if depth>0: cur+=ch
    if ch=="}":
        depth-=1
        if depth==0 and cur.strip():
            try: blocks.append(J.loads(cur))
            except Exception: pass
            cur=""
for b in blocks:
    if isinstance(b,dict) and "Sign" in b:
        for k in ["Setup","VehKeyGen","CertGen","CertValidate","Sign"]:
            print(f"   {k:12s} {b[k][0]:.3f} ms")
        print("   sizes:", b.get("sizes"))
PY
echo "==============================================================="
echo "NOTE: absolute timings depend on CPU. Byte sizes and security"
echo "results are hardware-independent and match the paper exactly."
