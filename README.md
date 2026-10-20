# Ngekos.in

Aplikasi mobile untuk mencari dan menyewa kos, dibuat dengan **Flutter** dan didukung REST API **Node.js + MySQL**. Cari kos berdasarkan area atau kampus terdekat, lihat lokasinya di peta, ajukan sewa, lalu chat langsung dengan pemilik kos.

Proyek UTS Pemrograman Aplikasi Bergerak.

## Nama Anggota

- Ahnaf Reyhan Kenneth Alvaro (24051214179)
- Achmad Aldi Saputra (24051214193)
- Akila Safiano Drianto (24051214188)
- Shalsa berliana firdausi (24051214190)

## Fitur

- Pencarian kos berdasarkan nama, area/kota, atau kampus terdekat, dengan filter dan urutan hasil
- Detail kos: fasilitas, aturan, tipe kamar dengan harga per periode, ulasan, dan peta lokasi (OpenStreetMap)
- Favorit dan riwayat kos yang terakhir dilihat
- Pengajuan sewa (harian, mingguan, bulanan, tahunan) dengan kode promo, lalu pembayaran
- Halaman **Kos Saya** untuk memantau status pengajuan
- **Chat** dengan pemilik kos (teks dan gambar)
- Koin, voucher, dan ulasan
- Mode pemilik kos (kelola pengajuan sewa) dan peran admin

## Isi repo

```
Aplikasi-Ngekosin/
├─ ngekosin-frontend/   # aplikasi Flutter
└─ ngekosin-backend/    # REST API (Node.js + Express) + database MySQL
```

## Yang perlu dipasang dulu

| Kebutuhan | Keterangan |
|---|---|
| [Git](https://git-scm.com) | untuk clone repo (atau download ZIP dari GitHub) |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | harus yang memakai Dart 3.9 atau lebih baru; cek dengan `flutter --version` |
| [Node.js](https://nodejs.org) | versi 18 atau lebih baru; cek dengan `node -v` |
| MySQL | cara paling mudah: [Laragon](https://laragon.org) (Windows), atau XAMPP |
| Android Studio | untuk emulator Android (atau pakai HP Android asli) |

## Cara menjalankan

Urutannya penting: **jalankan backend dulu, baru aplikasinya.**

### 1. Ambil kodenya

```bash
git clone https://github.com/Reyhan211/Aplikasi-Ngekosin.git
cd Aplikasi-Ngekosin
```

Tanpa git: klik tombol hijau **Code** di GitHub, pilih **Download ZIP**, lalu extract.

### 2. Jalankan backend

1. Nyalakan MySQL. Kalau pakai Laragon: buka Laragon lalu klik **Start All**.
2. Buka terminal di folder `ngekosin-backend`:

   ```bash
   cd ngekosin-backend
   npm install
   ```

3. Buat file `.env` dari contohnya. File `.env` sengaja tidak ada di repo karena berisi pengaturan pribadi.

   Windows (PowerShell atau CMD):
   ```bash
   copy .env.example .env
   ```
   Mac/Linux:
   ```bash
   cp .env.example .env
   ```

   Pengaturan bawaan sudah cocok untuk Laragon (user `root`, tanpa password). Kalau MySQL-mu memakai password, isi `DB_PASSWORD` di file `.env`.

4. Buat database, tabel, dan data awal, lalu jalankan servernya:

   ```bash
   npm run db:setup
   npm start
   ```

5. Cek di browser: <http://localhost:3000/api/v1/health>. Kalau muncul `"status":"ok"`, backend sudah siap. Biarkan terminal ini tetap terbuka.

### 3. Jalankan aplikasi Flutter

Buka terminal **baru** (jangan tutup terminal backend):

```bash
cd ngekosin-frontend
flutter pub get
flutter run
```

Pastikan emulator Android sudah menyala (atau HP tersambung dengan USB debugging aktif) sebelum `flutter run`. Build pertama bisa memakan waktu beberapa menit.

Untuk **emulator Android**, tidak ada yang perlu diubah: alamat server sudah diarahkan ke `http://10.0.2.2:3000` (itu alamat `localhost` laptop dari dalam emulator).

Untuk **HP Android asli**, HP dan laptop harus satu WiFi. Buka `ngekosin-frontend/lib/core/config/api_config.dart`, lalu ganti `host` dengan IP laptopmu:

```dart
static const String host = 'http://192.168.1.10:3000'; // ganti dengan IP laptopmu
```

IP laptop bisa dilihat lewat `ipconfig` di Windows (cari **IPv4 Address**). Kalau HP tetap tidak bisa terhubung, izinkan Node.js atau port 3000 di Windows Firewall.

Mau mencoba tampilan tanpa backend? Ubah `useMock` menjadi `true` di file yang sama. Aplikasi akan memakai data dummy.

## Akun demo

Login bisa memakai email **atau** username.

| Email | Username | Password | Peran |
|---|---|---|---|
| raka@ngekos.in | `raka` | `password123` | pencari kos |
| sari@ngekos.in | `sari` | `password123` | pemilik semua kos |
| admin@ngekos.in | `admin` | `admin123` | admin |

Untuk mencoba chat dua arah: login sebagai `raka` di satu perangkat, lalu sebagai `sari` di perangkat lain. Pesan baru muncul otomatis tiap beberapa detik.

> Ganti semua password akun demo dan `JWT_SECRET` di `.env` sebelum dipakai di server sungguhan.

## Masalah yang sering muncul

| Masalah | Solusi |
|---|---|
| `Gagal terhubung ke MySQL: ECONNREFUSED` | MySQL belum menyala. Buka Laragon lalu klik **Start All**. |
| `ER_ACCESS_DENIED_ERROR` | User atau password MySQL salah. Periksa `DB_USER` dan `DB_PASSWORD` di `.env`. |
| `Port 3000 already in use` | Ada program lain di port itu. Tutup, atau ganti `PORT` di `.env` (dan sesuaikan `host` di `api_config.dart`). |
| Aplikasi menampilkan "Tidak dapat terhubung ke server" | Pastikan backend masih berjalan dan `host` di `api_config.dart` sudah benar (lihat langkah 3). |
| Error merah di VS Code seperti `Target of URI doesn't exist` | Jalankan `flutter pub get` di dalam folder `ngekosin-frontend`. |
| Mau mengulang database dari nol | `npm run db:reset` di folder backend. **Perintah ini menghapus semua data.** |

## Dokumentasi dan pengujian

- Daftar endpoint API: [`ngekosin-backend/docs/API.md`](ngekosin-backend/docs/API.md)
- Uji otomatis semua endpoint (server harus sedang berjalan): `npm run test:api` di folder backend

## Teknologi

- **Frontend:** Flutter, go_router, http, image_picker, flutter_map (OpenStreetMap), shared_preferences
- **Backend:** Node.js, Express, MySQL (mysql2), JWT, bcrypt, multer
