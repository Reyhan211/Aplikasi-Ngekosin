# Ngekos.in Backend (MySQL + REST API)

Database MySQL dan REST API (Node.js + Express) untuk aplikasi Flutter **Ngekos.in**.
Alamat API sudah cocok dengan `ApiConfig` di aplikasi: `http://<host>:3000/api/v1`.

## Struktur
```
ngekosin-backend/
├─ database/migrations/  # 19 file migrasi (1 per tabel, ada bagian Up & Down)
├─ database/schema.sql   # ringkasan semua tabel dalam 1 file (untuk import manual)
├─ database/seed.sql     # data awal = data dummy aplikasi (18 kos, 7 kota, 11 kampus, dll.)
├─ src/                  # kode API (routes, services, middleware)
├─ scripts/migrate.js    # perintah migrasi (up, rollback, status, fresh, seed)
├─ scripts/setup-db.js   # satu perintah: migrasi + seed
├─ scripts/smoke-test.js # uji otomatis semua endpoint
├─ docs/API.md           # daftar endpoint
└─ uploads/              # foto chat & bukti bayar yang diunggah
```

## Cara menjalankan di Laragon (Windows)
1. Buka **Laragon** → klik **Start All** (MySQL harus jalan).
2. Salin folder `ngekosin-backend` ke mana saja, mis. `C:\laragon\www\ngekosin-backend`.
3. Buka **Terminal** Laragon, lalu:
   ```
   cd C:\laragon\www\ngekosin-backend
   npm install
   npm run db:setup
   npm start
   ```
   - `npm run db:setup` membuat database `ngekosin`, semua tabel, dan data awal.
   - Default `.env` sudah memakai user `root` tanpa password (default Laragon).
     Jika MySQL-mu berpassword, ubah `DB_PASSWORD` di `.env`.
4. Cek di browser: <http://localhost:3000/api/v1/kos>
5. (Opsional) Lihat isi database lewat **HeidiSQL** (Laragon → Database) → pilih `ngekosin`.

> Database tidak berupa "file di folder"; MySQL menyimpannya sendiri di `laragon\data\mysql`.
> Yang kamu import/jalankan adalah `schema.sql` dan `seed.sql` (otomatis lewat `npm run db:setup`,
> atau manual lewat HeidiSQL: *File → Run SQL file*, jalankan `schema.sql` lalu `seed.sql`).

Mulai dari nol lagi: `npm run db:reset` (**menghapus** database lalu membuatnya ulang).

## Migrasi database
Struktur tabel dikelola lewat file di `database/migrations/` (`001_create_users_table.sql` dst.).
Tiap file punya bagian `-- +migrate Up` (membuat tabel) dan `-- +migrate Down` (menghapusnya).
Riwayat yang sudah dijalankan dicatat di tabel `migrations`.

| Perintah | Fungsi |
|---|---|
| `npm run migrate` | jalankan migrasi yang belum dijalankan |
| `npm run migrate:status` | lihat status tiap migrasi (Ran / Pending) |
| `npm run migrate:rollback` | batalkan batch migrasi terakhir |
| `npm run migrate:fresh` | **hapus** database lalu migrasi ulang dari nol |
| `npm run seed` | isi data awal dari `database/seed.sql` |
| `npm run db:setup` | migrasi + seed (bila masih kosong) |
| `npm run db:reset` | **hapus** database, migrasi ulang, lalu seed |

Menambah/mengubah tabel: buat file baru berikutnya, mis. `020_add_foto_to_users_table.sql`, isi bagian Up
(`ALTER TABLE ...`) dan Down, lalu jalankan `npm run migrate`. Database lama yang dibuat dari `schema.sql`
terdeteksi otomatis (tidak dibuat ulang).

## Menyambungkan aplikasi Flutter
Di `lib/core/config/api_config.dart`:
```dart
static const bool useMock = false;                    // pakai REST API sungguhan
static const String host = 'http://10.0.2.2:3000';    // emulator Android
// HP fisik (satu WiFi dengan laptop): 'http://192.168.x.x:3000'  (IP laptop; tampil saat npm start)
```
Lalu jalankan ulang aplikasi (hot restart). Jika HP fisik tidak bisa terhubung, izinkan
Node.js / port 3000 di Windows Firewall.

Catatan: gambar kos & kota memakai path `assets/...` dari aplikasi (sama seperti data dummy),
jadi tetap tampil tanpa upload apa pun. Foto chat dan bukti bayar tersimpan di `uploads/`.

## Akun demo
| Email | Password | Peran |
|---|---|---|
| raka@ngekos.in (username `raka`) | password123 | pencari kos (punya koin, 2 voucher, 1 chat) |
| sari@ngekos.in (username `sari`) | password123 | pemilik semua kos |
| admin@ngekos.in (username `admin`) | admin123 | admin |

Login bisa memakai **email atau username**.

## Uji otomatis
Dengan server berjalan: `npm run test:api` (149 pemeriksaan: auth, pencarian, ulasan,
booking, bayar, chat, voucher, alur pemilik & admin).

## Catatan keamanan
- Password disimpan sebagai hash bcrypt; sesi memakai JWT (ganti `JWT_SECRET` di `.env`).
- Harga booking selalu dihitung ulang di server, angka dari aplikasi hanya estimasi.
- Bukti bayar hanya bisa dilihat penyewa, pemilik kos terkait, dan admin.
- Ganti semua password akun demo sebelum dipakai di server sungguhan.
