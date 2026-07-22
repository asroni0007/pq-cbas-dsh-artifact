#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
render_network.py — Gambar jaringan SUMO + area RSU ke file PNG.

TIDAK butuh GUI, OpenGL, atau SUMO tools. Hanya matplotlib.
Mengatasi total masalah layar abu-abu SUMO GUI di macOS.

Pakai:
    python3 render_network.py
    python3 render_network.py --net StudyAreNetwork.net.xml --out network.png
    python3 render_network.py --fcd studyarea_fcd.xml --time 600   # + kendaraan pd detik 600
"""
import argparse, xml.etree.ElementTree as ET
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Circle

def parse_shape(s):
    pts = []
    for pair in s.strip().split():
        x, y = pair.split(",")[:2]
        pts.append((float(x), float(y)))
    return pts

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--net", default="StudyAreNetwork.net.xml")
    ap.add_argument("--out", default="network_render.png")
    ap.add_argument("--rsu-x", type=float, default=80.0)
    ap.add_argument("--rsu-y", type=float, default=36.0)
    ap.add_argument("--rsu-r", type=float, default=150.0)
    ap.add_argument("--fcd", default=None, help="optional FCD file to overlay vehicles")
    ap.add_argument("--time", type=float, default=None, help="timestep (s) to draw vehicles at")
    ap.add_argument("--dpi", type=int, default=200)
    args = ap.parse_args()

    root = ET.parse(args.net).getroot()

    fig, ax = plt.subplots(figsize=(12, 4))

    # gambar semua lane (jalan)
    nlane = 0
    for lane in root.findall(".//lane"):
        shp = lane.get("shape")
        if not shp:
            continue
        pts = parse_shape(shp)
        xs = [p[0] for p in pts]; ys = [p[1] for p in pts]
        ax.plot(xs, ys, color="#4d4d4d", linewidth=1.6, solid_capstyle="round", zorder=2)
        nlane += 1

    # junction (persimpangan) sebagai titik
    for j in root.findall(".//junction"):
        if j.get("type") in ("internal",):
            continue
        try:
            jx = float(j.get("x")); jy = float(j.get("y"))
            ax.plot(jx, jy, "o", color="#888888", markersize=2, zorder=3)
        except (TypeError, ValueError):
            continue

    # area cakupan RSU (garis putus-putus tipis, isi sangat transparan agar jalan tetap terbaca)
    rsu = Circle((args.rsu_x, args.rsu_y), args.rsu_r, facecolor="#2c6fb5",
                 alpha=0.06, edgecolor="#2c6fb5", linewidth=1.1, linestyle="--", zorder=1)
    ax.add_patch(rsu)
    ax.plot(args.rsu_x, args.rsu_y, "^", color="#c0392b", markersize=10, zorder=5,
            markeredgecolor="white", markeredgewidth=0.8,
            label=f"RSU (R={args.rsu_r:.0f} m)")
    ax.annotate("RSU", (args.rsu_x, args.rsu_y), textcoords="offset points",
                xytext=(8, 8), fontsize=10, fontweight="bold", color="#c0392b")

    # opsional: overlay kendaraan dari FCD pada waktu tertentu
    nveh = 0
    if args.fcd and args.time is not None:
        for ts in ET.parse(args.fcd).getroot().findall("timestep"):
            if abs(float(ts.get("time")) - args.time) < 0.5:
                for v in ts.findall("vehicle"):
                    vx = float(v.get("x")); vy = float(v.get("y"))
                    ax.plot(vx, vy, "s", color="#e67e22", markersize=4, zorder=4)
                    nveh += 1
                break

    ax.set_aspect("equal")
    ax.set_xlabel("x (m)"); ax.set_ylabel("y (m)")
    title = f"StudyArea network ({nlane} lanes)"
    if nveh:
        title += f" — {nveh} vehicles at t={args.time:.0f}s"
    ax.set_title(title, fontsize=12)
    ax.legend(loc="upper right", fontsize=9)
    ax.grid(True, alpha=0.2)

    plt.tight_layout()
    plt.savefig(args.out, dpi=args.dpi, bbox_inches="tight", facecolor="white")
    print(f"Saved: {args.out}  ({nlane} lanes"
          + (f", {nveh} vehicles" if nveh else "") + ")")

if __name__ == "__main__":
    main()
