/// Urutan hasil pencarian. [apiValue] dikirim sebagai query `sort`.
enum KosSort {
  recommended('recommended', 'Paling direkomendasikan'),
  priceAsc('price_asc', 'Harga terendah'),
  priceDesc('price_desc', 'Harga tertinggi'),
  rating('rating', 'Rating tertinggi');

  const KosSort(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

/// Model kartu kos (sesuai item respons GET /kos di docs/API.md).
class Kos {
  final int id;
  final String name;
  final String type; // putra | putri | campur
  final String district;
  final String city;
  final String? coverUrl;
  final int minPrice;
  final double rating;
  final int ratingCount;
  final int availableRooms;
  final bool isFavorite;
  final String? promoLabel;
  final List<String> facilities; // ringkasan 3-4 fasilitas utama

  const Kos({
    required this.id,
    required this.name,
    required this.type,
    required this.district,
    required this.city,
    this.coverUrl,
    required this.minPrice,
    required this.rating,
    required this.ratingCount,
    required this.availableRooms,
    this.isFavorite = false,
    this.promoLabel,
    this.facilities = const [],
  });

  // MySQL DECIMAL sering datang sebagai String ("4.7"), jadi parse lewat toString().
  factory Kos.fromJson(Map<String, dynamic> j) => Kos(
        id: int.parse(j['id'].toString()),
        name: (j['name'] ?? '').toString(),
        type: (j['kos_type'] ?? 'campur').toString(),
        district: (j['district'] ?? '').toString(),
        city: (j['city'] ?? '').toString(),
        coverUrl: j['cover_url']?.toString(),
        minPrice: int.tryParse('${j['min_price']}') ?? 0,
        rating: double.tryParse('${j['rating_avg']}') ?? 0,
        ratingCount: int.tryParse('${j['rating_count']}') ?? 0,
        availableRooms: int.tryParse('${j['available_rooms']}') ?? 0,
        isFavorite: j['is_favorite'] == true || j['is_favorite'] == 1,
        promoLabel: j['promo_label']?.toString(),
        facilities:
            (j['facilities'] as List?)
                ?.map((e) => e is Map ? '${e['name']}' : e.toString())
                .toList() ??
            const [],
      );

  String get location => district.isEmpty ? city : '$district, $city';
}
