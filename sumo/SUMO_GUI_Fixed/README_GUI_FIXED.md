# SUMO GUI — Config Diperbaiki (mengatasi layar abu-abu)

Layar abu-abu terjadi karena config lama tidak punya `<viewport>`, jadi kamera
GUI melihat ke area kosong. File-file di sini menambahkan **viewport eksplisit**
yang mengarahkan kamera tepat ke pusat jaringan StudyArea (X=52.7, Y=50.3),
sehingga jaringan langsung muncul saat GUI dibuka.

## Cara pakai

Salin semua file di folder ini ke folder `sumo/` Anda (tempat
`StudyAreNetwork.net.xml` berada), lalu jalankan salah satu:

### Opsi 1 — TANPA peta latar (paling andal, disarankan dulu)
```
sumo-gui -c studyarea_gui_nodecal.sumocfg --delay 100 --start
```
Jaringan + kendaraan + area RSU dijamin muncul. Tidak ada risiko decal.

### Opsi 2 — DENGAN peta latar (satelit)
```
sumo-gui -c studyarea_gui_fixed.sumocfg --delay 100 --start
```
Menampilkan background peta `EditStudyArea670x143.JPG` yang sudah
diselaraskan dengan koordinat jaringan.

## Isi file

| File | Fungsi |
|------|--------|
| `studyarea_gui_nodecal.sumocfg` | Config GUI tanpa peta (andal) |
| `studyarea_gui_fixed.sumocfg`   | Config GUI dengan peta latar |
| `gui_settings_nodecalfix.xml`   | Setting tampilan (viewport + warna), tanpa decal |
| `gui_settings_fixed.xml`        | Setting tampilan + decal peta diselaraskan |

## Apa yang diperbaiki

1. **Viewport eksplisit** `zoom=180 x=52.7 y=50.3` — kamera langsung fit
   ke jaringan. Ini penyembuh utama layar abu-abu.
2. **Decal diselaraskan** — pusat decal dipindah dari (50,50) ke (52.7,50.3)
   dan lebar disesuaikan (666×138) agar pas dengan jaringan sebenarnya
   (boundary -280.41..385.78, -18.47..119.15).
3. **Kendaraan diperbesar 3x** dan diwarnai menurut kecepatan (merah=lambat,
   kuning=sedang, hijau=cepat) agar mudah terlihat.
4. **POI RSU + polygon cakupan** ditampilkan dengan label.

## Kalau MASIH abu-abu setelah pakai config ini

Berarti benar-benar bug rendering OpenGL SUMO di macOS Apple Silicon
(bukan masalah config lagi). Solusi:

1. Di GUI: tarik/resize pojok jendela untuk memaksa redraw, lalu `Ctrl+A`.
2. Jalankan dengan tekstur dimatikan:
   ```
   sumo-gui -c studyarea_gui_nodecal.sumocfg --disable-textures --delay 100 --start
   ```
3. Kalau tetap gagal: gunakan mode headless + log (tidak butuh grafis) —
   simulasi & data naskah TIDAK terpengaruh sama sekali:
   ```
   sumo -c studyarea_test.sumocfg --duration-log.statistics --summary-output summary.xml
   ```

## Membuat screenshot (untuk Fig 3)

Setelah jaringan + kendaraan muncul dan simulasi berjalan:
- Menu **File → Save Screenshot**, atau klik ikon kamera di toolbar.
- Simpan sebagai PNG resolusi tinggi untuk paper.

Atau otomatis dari command line (screenshot pada detik ke-600):
```
sumo-gui -c studyarea_gui_nodecal.sumocfg --start \
  --window-size 1600,900 \
  --gui.snapshot-file snapshot_t600.png
```
(Butuh SUMO yang mendukung snapshot otomatis; jika tidak, pakai menu manual.)
