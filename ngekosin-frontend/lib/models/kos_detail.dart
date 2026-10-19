import 'kos.dart';

/// Satu fasilitas (dari tabel `facilities`).
class FacilityItem {
  final String name;
  final String category; // kamar | kamar_mandi | umum | parkir
  final String? icon;    // nama ikon, mis. 'wifi'
  const FacilityItem(this.name, this.category, [this.icon]);

  factory FacilityItem.fromJson(Map<String, dynamic> j) => FacilityItem(
        (j['name'] ?? '').toString(),
        (j['category'] ?? 'umum').toString(),
        j['icon']?.toString(),
      );
}

/// Tipe kamar dengan harga per periode (tabel `room_types`).
class RoomType {
  final int id;
  final String name;
  final String? sizeLabel; // "3 x 4"
  final int? priceDaily;
  final int? priceWeekly;
  final int priceMonthly;
  final int? priceYearly;
  final int deposit;
  final int stock;

  const RoomType({
    required this.id,
    required this.name,
    this.sizeLabel,
    this.priceDaily,
    this.priceWeekly,
    required this.priceMonthly,
    this.priceYearly,
    this.deposit = 0,
    this.stock = 0,
  });

  factory RoomType.fromJson(Map<String, dynamic> j) => RoomType(
        id: int.parse(j['id'].toString()),
        name: (j['name'] ?? '').toString(),
        sizeLabel: j['size_label']?.toString(),
        priceDaily: int.tryParse('${j['price_daily']}'),
        priceWeekly: int.tryParse('${j['price_weekly']}'),
        priceMonthly: int.tryParse('${j['price_monthly']}') ?? 0,
        priceYearly: int.tryParse('${j['price_yearly']}'),
        deposit: int.tryParse('${j['deposit']}') ?? 0,
        stock: int.tryParse('${j['stock']}') ?? 0,
      );
}

class Review {
  final int id;
  final String userName;
  final double rating;
  final String comment;
  final String? ownerReply;
  final DateTime createdAt;

  /// Skor per aspek (kunci sama dengan KosDetail.ratingBreakdown).
  /// Kosong bila API tidak mengirimnya; dipakai untuk mengisi ulang form ulasan.
  final Map<String, double> ratings;

  const Review({
    required this.id,
    required this.userName,
    required this.rating,
    required this.comment,
    this.ownerReply,
    required this.createdAt,
    this.ratings = const {},
  });

  factory Review.fromJson(Map<String, dynamic> j) {
    final reply = j['owner_reply']?.toString();
    return Review(
      id: int.parse(j['id'].toString()),
      userName: (j['user_name'] ?? 'Pengguna').toString(),
      rating: double.tryParse('${j['rating_overall']}') ?? 0,
      comment: (j['comment'] ?? '').toString(),
      ownerReply: (reply == null || reply.isEmpty) ? null : reply,
      createdAt: DateTime.tryParse('${j['created_at']}') ?? DateTime.now(),
      ratings: {
        for (final e in ((j['ratings'] as Map?) ?? const {}).entries)
          e.key.toString(): double.tryParse('${e.value}') ?? 0,
      },
    );
  }
}

/// Respons GET /kos/:id (lihat docs/API.md).
class KosDetail {
  final Kos kos;
  final String address;
  final String description;
  final double? latitude;
  final double? longitude;
  final List<FacilityItem> facilities;
  final List<String> rules;

  /// Skor rata-rata per aspek (1-5). Kunci: cleanliness, comfort, safety,
  /// price, room_facility, public_facility.
  final Map<String, double> ratingBreakdown;
  final String ownerName;
  final List<RoomType> rooms;

  const KosDetail({
    required this.kos,
    required this.address,
    required this.description,
    this.latitude,
    this.longitude,
    this.facilities = const [],
    this.rules = const [],
    this.ratingBreakdown = const {},
    this.ownerName = '',
    this.rooms = const [],
  });

  bool get hasLocation => latitude != null && longitude != null;

  factory KosDetail.fromJson(Map<String, dynamic> j) {
    final fac = (j['facilities'] as List?) ?? const [];
    final bd = (j['rating_breakdown'] as Map?) ?? const {};
    return KosDetail(
      kos: Kos.fromJson(j),
      address: (j['address'] ?? '').toString(),
      description: (j['description'] ?? '').toString(),
      latitude: double.tryParse('${j['latitude']}'),
      longitude: double.tryParse('${j['longitude']}'),
      facilities: fac
          .whereType<Map>()
          .map((e) => FacilityItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      rules: ((j['rules'] as List?) ?? const []).map((e) => e.toString()).toList(),
      ratingBreakdown: {
        for (final e in bd.entries) e.key.toString(): double.tryParse('${e.value}') ?? 0,
      },
      ownerName: ((j['owner'] as Map?)?['name'] ?? '').toString(),
      rooms: ((j['rooms'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => RoomType.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
