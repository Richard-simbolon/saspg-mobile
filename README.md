# SIGRA FORCE — Mobile App (SPG)

Aplikasi field-app untuk SPG (Sales Promotion Girl), dibangun dengan Flutter untuk
web, iOS, dan Android. Terhubung langsung ke backend yang sama dengan
dashboard admin (`../dashboard-api`) — bukan data mock.

## Menjalankan

1. Pastikan `dashboard-api` sudah jalan (lihat `../RUNNING.md`): Postgres via
   Docker, lalu `npm run start:dev` di folder `dashboard-api`.
2. Install dependencies:
   ```
   flutter pub get
   ```
3. Jalankan:
   ```
   flutter run -d chrome                                    # web, default localhost
   flutter run -d chrome --dart-define=API_BASE_URL=...      # override URL API
   ```

### URL API per platform

Default `API_BASE_URL` adalah `http://localhost:3000/api`, cocok untuk **Flutter
web** dan **iOS Simulator**. Untuk platform lain, override lewat `--dart-define`:

- **Android Emulator**: `--dart-define=API_BASE_URL=http://10.0.2.2:3000/api`
  (alamat khusus emulator untuk mengakses `localhost` host)
- **Perangkat fisik** (Android/iOS): gunakan IP LAN komputer Anda, mis.
  `--dart-define=API_BASE_URL=http://192.168.1.10:3000/api`, dan pastikan
  perangkat berada di jaringan Wi-Fi yang sama.

### Login

Akun SPG di-seed otomatis oleh `npm run seed` di `dashboard-api` — satu akun
per SPG, username bergaya NIK:

| Username    | Password  | SPG               |
|-------------|-----------|-------------------|
| SPG-1000    | sigra123  | Dinda Prameswari  |
| SPG-1001    | sigra123  | Ayu Lestari       |
| SPG-1002    | sigra123  | Putri Handayani   |
| SPG-1003    | sigra123  | Siti Nurhaliza    |
| SPG-1004    | sigra123  | Rahma Fitriani    |
| SPG-1005    | sigra123  | Nadia Kusuma      |

## Yang sudah terhubung ke backend nyata

- Login SPG (JWT, role `spg`), lokasi/outlet yang ditugaskan (per brand),
  brand & produk, training & penyelesaiannya.
- **Check-in** memvalidasi geofence (radius toko) di sisi server memakai titik
  GPS & radius yang diset admin di dashboard — check-in ditolak kalau di luar
  radius. Selfie verifikasi disimpan bersama data absensi.
- **Check-out**, **Laporan Kunjungan** & **Foto Bukti** (tersambung ke fitur
  "Approval Laporan" yang sama dengan yang dilihat admin di dashboard),
  **Input Penjualan** (masuk ke laporan penjualan harian real, dipakai mesin
  insentif brand).
- Live tracking: posisi GPS SPG dikirim ke server saat check-in, muncul di
  peta Live Tracking dashboard admin.
- Tab **Kinerja** memakai data asli (target/realisasi, kehadiran, training,
  insentif, tren kunjungan mingguan dari riwayat absensi asli).

## Keterbatasan yang disengaja (belum diimplementasi)

- **Tab Chat** murni tampilan lokal — pesan yang dikirim tidak benar-benar
  terkirim ke supervisor karena belum ada backend chat/realtime. Bisa
  dibangun sebagai iterasi berikutnya kalau dibutuhkan.
- **Materi training** (product knowledge) belum ada field-nya di database —
  layar detail training menampilkan info jadwal + tombol "Tandai Selesai"
  saja, tanpa daftar materi (tidak dikarang/di-fake).
- **Riwayat bulanan** (beberapa bulan ke belakang) tidak ditampilkan karena
  belum ada data historis per-bulan yang cukup andal di backend — yang
  ditampilkan hanya bulan berjalan + tren mingguan dari absensi asli.
