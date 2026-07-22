# PQ-CBAS-DSH — Paket Siap Jalan (Verified)

Paket ini adalah artifact PQ-CBAS-DSH yang **sudah diuji-jalankan** dan disesuaikan
dengan naskah. Semua skrip Python berhasil dieksekusi; hasilnya dicocokkan dengan
angka-angka di naskah.

---

## ⚡ Cara tercepat menjalankan

```bash
bash RUN_ALL.sh
```

Skrip ini otomatis: memasang `cmake`/`ninja`/`numpy`/`liboqs-python`, membangun
`liboqs` (khusus ML-DSA, sekali saja, ±3-5 menit), lalu menjalankan **semua**
benchmark. Hasil tersimpan di folder `out/`.

Tidak butuh `sudo`. Diuji pada Ubuntu 24.04 + Python 3.12 + Intel Xeon vCPU.

---

## ✅ Status verifikasi tiap komponen (diuji di sandbox)

| Skrip | Status | Mereproduksi | Catatan |
|-------|--------|--------------|---------|
| `src/bench_pqcbas.py` | ✅ JALAN | Tabel 5, 6, 11, 12 | Ukuran byte & hasil keamanan **identik naskah** |
| `src/e2e_workflow.py` | ✅ JALAN | Tabel 8 (full), 9 (digest) | W=90, 5 seeds → **zero deadline miss**, jumlah pesan identik |
| `src/bench_compact.py` | ✅ JALAN | §PQ-CBAS-DSH-C | RespCheck `EXPECTED-FAIL` (shared-A belum diimplementasi — sesuai keterbatasan yang diakui naskah) |
| `src/sumo_pqcbas_bridge.py` | ✅ JALAN | Tabel 10 (mode `--no-sumo`) | Pakai FCD ter-bundle (sintetis, 270 kendaraan) |

### Hasil kunci yang **identik** dengan naskah (hardware-independent)

```
Ukuran objek:  pk 1,952 B | sig 3,309 B | cert 5,277 B | tuple 10,662 B
Aggregate:     m=1 → 5,232 B | m=10 → 5,664 B
Keamanan:      FRA=0 | RSA=0 | AMA(byte)=0 | AMA(subst)=0
               CCSA+DSH=0 | CCSA tanpa DSH=10,000/10,000
E2E (W=90,5seed,full):  47.0/47.0/46.9/47.9 ms, 0 deadline miss
```

Angka **timing absolut** (Setup/Sign/dll.) bergantung CPU. Di Apple M2 (naskah)
lebih cepat 1.3-1.6× daripada Xeon sandbox; ukuran byte & hasil keamanan sama persis.

---

## ⚠️ PENTING — soal trace SUMO (harus Anda perhatikan)

Naskah (Tabel 10) mengutip **"real SUMO 1.26 FCD trace, 3,193 kendaraan"**. Namun:

- Artifact ini **hanya menyertakan** `sumo/synthetic_fcd.xml` — trace **sintetis**
  (270 kendaraan, 3600 detik), untuk uji cepat tanpa memasang SUMO.
- Trace **nyata** (3,193 kendaraan) **tidak di-bundle**. Yang di-bundle adalah
  **bahan untuk membuatnya**: `StudyAreNetwork.net.xml` + `Demand.rou.xml` +
  `studyarea_test.sumocfg`. Hasil tersimpan ada di
  `results/sumo_pqcbas_W90_full_real_mac_m2.json` (46.3 ms, 3,193 veh).

**Untuk mereproduksi angka SUMO nyata di naskah, Anda WAJIB:**

```bash
# 1) Pasang SUMO 1.26 (butuh conda atau paket sistem)
conda create -n sumo-env python=3.11 -y
conda activate sumo-env
conda install -c conda-forge sumo -y

# 2) Jalankan bridge dengan SUMO nyata (bukan --no-sumo)
cd src
OQS_INSTALL_PATH=~/_oqs python3 sumo_pqcbas_bridge.py \
    --cfg ../sumo/studyarea_test.sumocfg \
    --net ../sumo/StudyAreNetwork.net.xml \
    --window 90 --seeds 3
```

Ini akan menjalankan SUMO headless → menghasilkan FCD nyata → menjalankan
PQ-CBAS-DSH di atasnya. **Angka yang keluar itulah** yang sah dikutip di naskah.
Jangan mengutip angka dari `--no-sumo` (trace sintetis) sebagai "real SUMO trace".

---

## 📁 Struktur paket

```
runnable_pkg/
├── RUN_ALL.sh                  # runner otomatis (mulai dari sini)
├── README_JALANKAN.md          # file ini
├── src/                        # kode Python (SEMUA sudah diuji jalan)
│   ├── bench_pqcbas.py         # Persamaan (1)-(27) + benchmark + keamanan
│   ├── e2e_workflow.py         # harness E2E uniform-arrival multi-seed
│   ├── bench_compact.py        # PQ-CBAS-DSH-C RespCheck
│   └── sumo_pqcbas_bridge.py   # bridge SUMO FCD → PQ-CBAS-DSH
├── sumo/                       # bahan SUMO
│   ├── StudyAreNetwork.net.xml # network 666m×138m
│   ├── Demand.rou.xml          # demand kendaraan campuran
│   ├── studyarea_test.sumocfg  # konfigurasi SUMO
│   ├── synthetic_fcd.xml       # FCD SINTETIS (uji cepat, 270 veh)
│   └── ...                     # POI RSU, transport publik, runner asli
├── results/                    # hasil ASLI naskah (Apple M2 + Xeon)
│   ├── results_mac_m2.json     # angka resmi naskah
│   ├── sumo_pqcbas_W90_full_real_mac_m2.json   # SUMO NYATA (3,193 veh)
│   └── ...
├── verified_results/           # hasil yang SAYA regenerate di sandbox (Xeon)
│   ├── bench_xeon_sandbox_verified.json
│   ├── e2e_results_W90_full.json
│   ├── e2e_results_W90_digest.json
│   └── sumo_pqcbas_W90_digest.json
└── out/                        # hasil terbaru dari RUN_ALL.sh
```

---

## 🔧 Menjalankan skrip satu per satu (manual)

```bash
export OQS_INSTALL_PATH=~/_oqs   # path liboqs hasil build RUN_ALL.sh

cd src
# Benchmark operasi + keamanan (Tabel 5, 6, 11, 12)
python3 bench_pqcbas.py

# E2E full & digest (Tabel 8 & 9) — WAJIB pakai W=90 --seeds 5 spt naskah
python3 e2e_workflow.py --window 90 --seeds 5
python3 e2e_workflow.py --window 90 --seeds 5 --digest

# Compact RespCheck
python3 bench_compact.py

# SUMO bridge (uji cepat tanpa SUMO)
python3 sumo_pqcbas_bridge.py --no-sumo --fcd synthetic_fcd.xml --window 90 --seeds 3 --digest
```

---

## 🩹 Troubleshooting

### `ModuleNotFoundError: No module named 'oqs'` (sering di macOS)

Ini terjadi ketika `pip` dan `python3` menunjuk ke environment **berbeda**:
liboqs-python terpasang di satu Python, tapi skrip dijalankan dengan Python lain.
Build liboqs (`.dylib`) sudah sukses — yang kurang hanya modul Python-nya.

**Solusi (pilih salah satu):**

1) **Paksa interpreter yang sama** (paling ampuh) — pasang modul dengan `python3 -m pip`:
   ```bash
   python3 -m pip install liboqs-python
   # lalu jalankan ulang
   export OQS_INSTALL_PATH=~/_oqs
   bash RUN_ALL.sh
   ```

2) **Tentukan Python secara eksplisit** saat menjalankan skrip:
   ```bash
   PYTHON=$(which python3) bash RUN_ALL.sh
   ```
   (RUN_ALL.sh versi ini membaca variabel `PYTHON` dan memakai `python3 -m pip`,
   jadi modul dijamin masuk ke interpreter yang sama.)

3) **Pakai virtualenv bersih** (menghindari konflik Homebrew/system Python):
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install numpy cryptography liboqs-python
   export OQS_INSTALL_PATH=~/_oqs
   bash RUN_ALL.sh
   ```

Cek environment mana yang aktif:
```bash
which python3 ; which pip
python3 -c "import sys; print(sys.executable)"
```
`pip` dan `python3` harus menunjuk folder yang sama.

### macOS: `oqs` ada tapi library tak ketemu saat runtime
macOS SIP menghapus `DYLD_LIBRARY_PATH`. **Selalu pakai** `OQS_INSTALL_PATH`:
```bash
export OQS_INSTALL_PATH=~/_oqs
python3 -c "import oqs; print(oqs.oqs_version())"
```

---



- Naskah memakai **liboqs 0.15.0**; sandbox ini membangun **liboqs 0.16.0**.
  ML-DSA-65 identik di kedua versi (ukuran & perilaku sama). Muncul
  `UserWarning` versi — tidak memengaruhi hasil.
- Jika ingin persis 0.15.0: ganti `git clone --depth 1 ...liboqs.git` di
  `RUN_ALL.sh` menjadi `git clone --branch 0.15.0 ...`.
