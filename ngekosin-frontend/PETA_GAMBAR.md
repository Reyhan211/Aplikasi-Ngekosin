# Peta Gambar Ngekos.in

Ganti gambar dengan **menimpa file yang namanya sama** (format .jpg, disarankan rasio 3:2, mis. 640x440 px).
Setelah menimpa, jalankan ulang aplikasi (hot restart `R`, bukan hot reload).

| Yang tampil di aplikasi | Lokasi file | Dipakai di |
|---|---|---|
| Foto kota "Area Kos Populer" (Beranda) | `assets/cities/<kota>.jpg` (yogyakarta, jakarta, bandung, surabaya, malang, semarang, medan) | `shared/widgets/area_card.dart`; path didaftarkan di `data/kos_repository.dart` (`_areas`) |
| Foto kos (kartu Beranda, Diskon Kilat, Pilihan Editor, Kos untukmu, hasil area/kampus, Favorit, detail kos, daftar chat) | `assets/kos/kos-<id>.jpg` (id 1 sampai 18) | `shared/widgets/kos_card.dart` (`KosCover`) dan `features/chat/chat_list_page.dart`, lewat `shared/widgets/smart_image.dart` |
| Ikon aplikasi di HP (Android) | `android/app/src/main/res/mipmap-*/ic_launcher.png` | launcher Android (5 ukuran) |
| Ikon/favicon versi web | `web/favicon.png`, `web/icons/Icon-*.png` | hanya jika dijalankan di browser |

## Menambah kos baru
1. Tambahkan datanya di `data/kos_repository.dart` dengan `coverUrl: 'assets/kos/kos-19.jpg'`.
2. Taruh fotonya di `assets/kos/kos-19.jpg`.

## Yang bukan file gambar
- Logo "Ngekosin" (`core/widgets/ngekosin_brand.dart`) digambar dengan kode (kotak gradasi + ikon rumah). Untuk memakai logo sendiri, ganti `Icon(...)` di `NgekosinLogo` dengan `Image.asset('assets/logo.png')` dan daftarkan `assets/` di `pubspec.yaml`.
- Badge kampus (`shared/widgets/campus_card.dart`) berisi singkatan huruf, bukan gambar.
- Banner promo di Beranda berupa kartu berwarna, bukan gambar.
- Avatar profil dan ulasan berupa huruf inisial.

## Saat backend sudah dipakai (`useMock = false`)
`coverUrl` berisi path dari database (mis. `uploads/kos/a.jpg`). Aplikasi otomatis mengambilnya dari server
(`ApiConfig.host`); gambar di `assets/kos/` hanya untuk data dummy.

## Logo kampus ("Kos Sekitar Kampus")
Taruh logo di `assets/campus/` dengan nama **singkatan kampus huruf kecil + .png**, mis. `ugm.png`, `undip.png`, `ui.png`.
Disarankan PNG transparan persegi (mis. 256x256). Kampus yang logonya belum ada otomatis tampil sebagai badge singkatan huruf.
Daftar kampus dan singkatannya ada di `lib/data/kos_repository.dart` (`_campuses`); tampilan badge di `lib/shared/widgets/campus_card.dart` (`CampusBadge`).
