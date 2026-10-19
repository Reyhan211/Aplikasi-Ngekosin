# Ngekos.in REST API v1

Base URL: `http://<host>:3000/api/v1`
Auth: header `Authorization: Bearer <token>` (token dari `/auth/login` atau `/auth/register`).

Respons sukses: `{ "success": true, "data": ... }`
Respons gagal : `{ "success": false, "message": "..." }` (status 400/401/403/404/409/422/429/500)

Kolom **Auth**: `-` publik · `opsional` (login mengisi `is_favorite`) · `user` wajib login · `pemilik` · `admin`

## Auth
| Method | Path | Auth | Body / catatan |
|---|---|---|---|
| POST | /auth/register | - | `name, username, email, password(min 8), phone?, role?` → 201 `{token,user}`. Username 3–30 karakter huruf kecil/angka/titik/garis bawah, unik (tidak peka huruf besar/kecil; `admin`, `ngekos`, dll. dicadangkan). `role:"pemilik"` = daftar sebagai pencari + pengajuan pemilik (menunggu admin). Bonus 500 koin |
| POST | /auth/login | - | `login` (email **atau** username; field `email`/`username` juga diterima), `password` → `{token,user}` |
| GET | /auth/check-username | - | `?username=` → `{available}` (untuk form daftar) |
| GET | /auth/me | user | profil |
| PUT | /auth/profile | user | `name, phone?` |
| PUT | /auth/password | user | `old_password, new_password` |

## Area, kampus, kos
| Method | Path | Auth | Catatan |
|---|---|---|---|
| GET | /cities/popular | - | "Area Kos Populer": `id,name,image_url,kos_count` |
| GET | /cities | - | semua kota |
| GET | /landmarks | - | query: `type=kampus, q, popular=1, city_id` → `id,short_name,name,city` |
| GET | /kos | opsional | query: `q` (nama/kecamatan/kota/fasilitas/nama kampus), `type` (putra/putri/campur), `city_id`, `landmark_id` + `radius_km` (default 3, Haversine), `available=1`, `promo=1`, `sort` (recommended/price_asc/price_desc/rating), `limit`, `offset` |
| GET | /kos/featured | opsional | "Pilihan Editor" (rating ≥ 4.6) |
| GET | /kos/promo | opsional | "Diskon Kilat" |
| GET | /kos/:id | opsional | detail: alamat, koordinat, fasilitas, rules, rating_breakdown, owner, rooms. Mencatat "terakhir dilihat" bila login |
| GET | /kos/:id/reviews | - | `limit, offset` |
| GET | /kos/:id/reviews/me | user | 404 bila belum mengulas |
| POST | /kos/:id/reviews | user | `ratings:{cleanliness,comfort,safety,price,room_facility,public_facility}` (1–5), `comment` → 201 baru / 200 diperbarui; rating kos dihitung ulang; +50 koin (sekali) |

## Favorit, koin, voucher, promo
| Method | Path | Auth | Catatan |
|---|---|---|---|
| GET | /favorites | user | |
| POST / DELETE | /favorites/:kosId | user | |
| GET | /recently-viewed | user | maks. 10 |
| GET | /coins | user | `{balance, history[]}` |
| GET | /vouchers | user | voucher milik yang belum dipakai |
| POST | /vouchers/claim | user | `code` |
| POST | /promos/validate | user | `code, kos_id, amount` → `{discount}` |

## Booking & pembayaran
| Method | Path | Auth | Catatan |
|---|---|---|---|
| POST | /bookings | user | `kos_id, room_type_id, checkin_date(YYYY-MM-DD), duration_unit(harian/mingguan/bulanan/tahunan), duration_count, occupants, tenant_name, tenant_phone, note?, promo_code?` → 201. Total = harga×durasi + deposit + admin Rp5.000 − diskon (dihitung server). Stok kamar −1, kedaluwarsa 24 jam |
| GET | /bookings | user | `status?` |
| GET | /bookings/:id | user | penyewa / pemilik kos / admin |
| POST | /bookings/:id/cancel | user | hanya menunggu_konfirmasi / menunggu_pembayaran; stok & voucher dipulihkan |
| POST | /bookings/:id/pay | user | multipart: `method` (bca/mandiri/bni/gopay/dana/qris), `proof` (gambar; wajib untuk bca/mandiri/bni) → status `dibayar` |
| GET | /bookings/:id/proof | user | gambar bukti bayar |

Status: `menunggu_konfirmasi → menunggu_pembayaran → dibayar → aktif → selesai`; cabang `ditolak`, `dibatalkan`, `kadaluarsa`.

## Chat
| Method | Path | Auth | Catatan |
|---|---|---|---|
| GET | /chat/rooms | user | `id, kos{id,name,cover_url}, other_name, last_message, last_message_at, unread_count` |
| POST | /chat/rooms | user | `kos_id` → 201 baru / 200 sudah ada |
| GET | /chat/rooms/:id/messages | user | `after_id?` (polling); menandai terbaca |
| POST | /chat/rooms/:id/messages | user | multipart/JSON: `body?`, `image?` (maks. 5 MB) |

Gambar chat dibuka lewat `http://<host>/<image_url>` (mis. `/uploads/chat/xxx.png`).

## Pemilik & admin
| Method | Path | Auth | Catatan |
|---|---|---|---|
| GET | /owner/status | user | `role, owner_status` |
| POST | /owner/apply | user | ajukan jadi pemilik → pending |
| GET | /owner/kos | pemilik | |
| GET | /owner/bookings | pemilik | `status?` |
| POST | /owner/bookings/:id/confirm | pemilik | menunggu_konfirmasi → menunggu_pembayaran |
| POST | /owner/bookings/:id/reject | pemilik | → ditolak (stok kembali) |
| POST | /owner/bookings/:id/activate | pemilik | dibayar → aktif |
| POST | /owner/bookings/:id/complete | pemilik | aktif → selesai, penyewa dapat koin |
| POST | /owner/reviews/:id/reply | pemilik | `reply` |
| GET | /admin/owner-applications | admin | |
| POST | /admin/owner-applications/:userId/approve \| reject | admin | |

`GET /health` → cek server & database.
