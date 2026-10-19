# Ngekos.in - Backend + database (Laragon)

Aplikasi Flutter dikirim terpisah (`ngekosin-flutter.zip`).

1. Buka Laragon -> **Start All** (MySQL harus hijau).
2. Salin folder ini ke `C:\laragon\www\ngekosin-backend`.
3. Buka Terminal Laragon:
   ```
   cd C:\laragon\www\ngekosin-backend
   npm install
   npm run db:setup
   npm start
   ```
   Terminal harus tetap terbuka selama aplikasi dipakai.
   Bila MySQL-mu berpassword: isi `DB_PASSWORD=` di file `.env`.
4. Cek di browser: http://localhost:3000/api/v1/kos

Detail: `README.md` dan `docs/API.md`.
