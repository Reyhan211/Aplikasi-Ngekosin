import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/auth/auth_state.dart';
import '../core/config/api_config.dart';
import '../models/area.dart';
import '../models/campus.dart';
import '../models/kos.dart';
import '../models/kos_detail.dart';

/// Satu pintu akses data kos. Saat ApiConfig.useMock = true,
/// data diambil dari daftar dummy di bawah.
class KosRepository {
  KosRepository._();
  static final KosRepository instance = KosRepository._();

  // id harus sama dengan tabel `cities` di database/schema.sql
  static const _areas = <Area>[
    Area(id: 3, name: 'Yogyakarta', imagePath: 'assets/cities/yogyakarta.jpg'),
    Area(id: 1, name: 'Jakarta', imagePath: 'assets/cities/jakarta.jpg'),
    Area(id: 2, name: 'Bandung', imagePath: 'assets/cities/bandung.jpg'),
    Area(id: 4, name: 'Surabaya', imagePath: 'assets/cities/surabaya.jpg'),
    Area(id: 5, name: 'Malang', imagePath: 'assets/cities/malang.jpg'),
    Area(id: 6, name: 'Semarang', imagePath: 'assets/cities/semarang.jpg'),
    Area(id: 7, name: 'Medan', imagePath: 'assets/cities/medan.jpg'),
  ];

  // id harus sama dengan tabel `landmarks` (type kampus) di database/schema.sql
  static const _campuses = <Campus>[
    Campus(id: 1, shortName: 'UGM', name: 'Universitas Gadjah Mada', city: 'Jogja'),
    Campus(id: 2, shortName: 'UNDIP', name: 'Universitas Diponegoro', city: 'Semarang'),
    Campus(id: 3, shortName: 'UI', name: 'Universitas Indonesia', city: 'Depok'),
    Campus(id: 4, shortName: 'UNPAD', name: 'Universitas Padjadjaran', city: 'Jatinangor'),
    Campus(id: 5, shortName: 'STAN', name: 'Politeknik Keuangan Negara STAN', city: 'Jakarta'),
    Campus(id: 6, shortName: 'UB', name: 'Universitas Brawijaya', city: 'Malang'),
    Campus(id: 7, shortName: 'UNAIR', name: 'Universitas Airlangga', city: 'Surabaya'),
    Campus(id: 8, shortName: 'UNESA', name: 'Universitas Negeri Surabaya', city: 'Surabaya'),
    Campus(id: 9, shortName: 'ITS', name: 'Institut Teknologi Sepuluh Nopember', city: 'Surabaya'),
    Campus(id: 10, shortName: 'UINSA', name: 'UIN Sunan Ampel Surabaya', city: 'Surabaya'),
    Campus(id: 11, shortName: 'UM', name: 'Universitas Negeri Malang', city: 'Malang'),
  ];

  // Data dummy: kos mana saja yang "dekat" tiap kampus (id kampus -> id kos).
  // Di backend ini dihitung dari koordinat (Haversine), lihat docs/API.md.
  static const _nearCampus = <int, List<int>>{
    1: [4, 11],
    2: [6, 14],
    3: [5, 13],
    4: [3, 12],
    5: [13],
    6: [1, 2],
    7: [7, 8],
    8: [8, 15, 16, 18], // UNESA
    9: [7, 17], // ITS
    10: [7, 8], // UINSA
    11: [1, 2], // UM
  };

  static const _fA = ['K. Mandi Dalam', 'WiFi', 'AC', 'Kasur'];
  static const _fB = ['K. Mandi Dalam', 'WiFi', 'Kasur', 'Lemari'];
  static const _fC = ['K. Mandi Luar', 'WiFi', 'Kasur', 'Parkir Motor'];
  static const _fD = ['AC', 'Kloset Duduk', 'Kasur', 'Akses 24 Jam'];

  static const _mock = <Kos>[
    Kos(id: 1, coverUrl: 'assets/kos/kos-1.jpg', name: 'Kos Melati Asri', type: 'putri', district: 'Lowokwaru', city: 'Malang', minPrice: 1200000, rating: 4.7, ratingCount: 38, availableRooms: 3, facilities: _fB),
    Kos(id: 2, coverUrl: 'assets/kos/kos-2.jpg', name: 'Kos Kenanga Putra', type: 'putra', district: 'Klojen', city: 'Malang', minPrice: 850000, rating: 4.3, ratingCount: 21, availableRooms: 5, facilities: _fC),
    Kos(id: 3, coverUrl: 'assets/kos/kos-3.jpg', name: 'Kos Anggrek Residence', type: 'campur', district: 'Coblong', city: 'Bandung', minPrice: 1750000, rating: 4.8, ratingCount: 64, availableRooms: 8, promoLabel: 'Diskon 15%', facilities: _fA),
    Kos(id: 4, coverUrl: 'assets/kos/kos-4.jpg', name: 'Kos Seruni', type: 'putri', district: 'Gedongtengen', city: 'Yogyakarta', minPrice: 950000, rating: 4.5, ratingCount: 17, availableRooms: 2, promoLabel: 'Diskon 10%', facilities: _fB),
    Kos(id: 5, coverUrl: 'assets/kos/kos-5.jpg', name: 'Kos Dahlia Putra', type: 'putra', district: 'Tebet', city: 'Jakarta', minPrice: 1900000, rating: 4.4, ratingCount: 29, availableRooms: 4, facilities: _fA),
    Kos(id: 6, coverUrl: 'assets/kos/kos-6.jpg', name: 'Kos Flamboyan', type: 'campur', district: 'Tembalang', city: 'Semarang', minPrice: 1350000, rating: 4.6, ratingCount: 33, availableRooms: 6, promoLabel: 'Diskon 20%', facilities: _fB),
    Kos(id: 7, coverUrl: 'assets/kos/kos-7.jpg', name: 'Kos Mawar Putri', type: 'putri', district: 'Gubeng', city: 'Surabaya', minPrice: 1250000, rating: 4.5, ratingCount: 26, availableRooms: 4, facilities: _fB),
    Kos(id: 8, coverUrl: 'assets/kos/kos-8.jpg', name: 'Kos Cempaka Residence', type: 'campur', district: 'Wonokromo', city: 'Surabaya', minPrice: 1600000, rating: 4.7, ratingCount: 41, availableRooms: 7, promoLabel: 'Diskon 10%', facilities: _fD),
    Kos(id: 9, coverUrl: 'assets/kos/kos-9.jpg', name: 'Kos Teratai Putra', type: 'putra', district: 'Medan Baru', city: 'Medan', minPrice: 900000, rating: 4.2, ratingCount: 14, availableRooms: 5, facilities: _fC),
    Kos(id: 10, coverUrl: 'assets/kos/kos-10.jpg', name: 'Kos Kamboja', type: 'putri', district: 'Medan Johor', city: 'Medan', minPrice: 1050000, rating: 4.4, ratingCount: 19, availableRooms: 3, facilities: _fB),
    Kos(id: 11, coverUrl: 'assets/kos/kos-11.jpg', name: 'Kos Sakura Putra', type: 'putra', district: 'Sleman', city: 'Yogyakarta', minPrice: 1150000, rating: 4.6, ratingCount: 31, availableRooms: 6, facilities: _fA),
    Kos(id: 12, coverUrl: 'assets/kos/kos-12.jpg', name: 'Kos Bougenville', type: 'campur', district: 'Dago', city: 'Bandung', minPrice: 1450000, rating: 4.3, ratingCount: 22, availableRooms: 0, facilities: _fB),
    Kos(id: 13, coverUrl: 'assets/kos/kos-13.jpg', name: 'Kos Lavender Senopati', type: 'putri', district: 'Setiabudi', city: 'Jakarta', minPrice: 2600000, rating: 4.8, ratingCount: 47, availableRooms: 2, promoLabel: 'Diskon 15%', facilities: _fD),
    Kos(id: 15, coverUrl: 'assets/kos/kos-15.jpg', name: 'Kos Ketintang Asri', type: 'putri', district: 'Gayungan', city: 'Surabaya', minPrice: 950000, rating: 4.4, ratingCount: 18, availableRooms: 4, facilities: _fB),
    Kos(id: 16, coverUrl: 'assets/kos/kos-16.jpg', name: 'Kos Lidah Wetan Putra', type: 'putra', district: 'Lakarsantri', city: 'Surabaya', minPrice: 800000, rating: 4.2, ratingCount: 11, availableRooms: 6, facilities: _fC),
    Kos(id: 17, coverUrl: 'assets/kos/kos-17.jpg', name: 'Kos Keputih Residence', type: 'campur', district: 'Sukolilo', city: 'Surabaya', minPrice: 1100000, rating: 4.6, ratingCount: 27, availableRooms: 5, promoLabel: 'Diskon 10%', facilities: _fA),
    Kos(id: 18, coverUrl: 'assets/kos/kos-18.jpg', name: 'Kos Wiyung Mandiri', type: 'putra', district: 'Wiyung', city: 'Surabaya', minPrice: 750000, rating: 4.1, ratingCount: 9, availableRooms: 7, facilities: _fC),
    Kos(id: 14, coverUrl: 'assets/kos/kos-14.jpg', name: 'Kos Jati Putra', type: 'putra', district: 'Banyumanik', city: 'Semarang', minPrice: 800000, rating: 4.1, ratingCount: 12, availableRooms: 8, facilities: _fC),
  ];

  // ------------------------------------------------------------------
  // PENCARIAN (mock). Di backend: parameter `q` pada GET /kos dan
  // GET /landmarks?type=kampus&q=
  // ------------------------------------------------------------------
  static const _stopWords = {
    'kos', 'kost', 'kosan', 'dekat', 'sekitar', 'sekitaran', 'sekitarnya',
    'di', 'daerah', 'area', 'wilayah', 'dari', 'ke', 'yang', 'untuk', 'dan',
  };

  /// "Kos dekat Universitas Negeri Surabaya" -> [universitas, negeri, surabaya]
  static List<String> _tokens(String q) => q
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty && !_stopWords.contains(t))
      .toList();

  static int _lev(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final best = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost]
            .reduce((x, y) => x < y ? x : y);
        cur[j] = best;
      }
      prev = cur;
    }
    return prev[b.length];
  }

  /// Semua kata kunci harus ada di [haystack]; typo ringan ditoleransi
  /// ("universitras" tetap cocok dengan "universitas").
  static bool _matchesAll(List<String> tokens, String haystack) {
    final hay = haystack.toLowerCase();
    final words = hay.split(RegExp(r'[^a-z0-9]+'));
    return tokens.every((t) {
      if (hay.contains(t)) return true;
      if (t.length < 5) return false;
      final tol = t.length >= 8 ? 2 : 1;
      return words.any((w) => (w.length - t.length).abs() <= tol && _lev(t, w) <= tol);
    });
  }

  /// Saran kampus & area saat mengetik di kolom cari.
  Future<(List<Campus>, List<Area>)> suggest(String q) async {
    final tokens = _tokens(q);
    if (tokens.isEmpty) return (<Campus>[], <Area>[]);
    if (ApiConfig.useMock) {
      return (
        _campuses
            .where((c) => _matchesAll(tokens, '${c.shortName} ${c.name} ${c.city}'))
            .take(4)
            .toList(),
        _areas.where((a) => _matchesAll(tokens, a.name)).take(3).toList(),
      );
    }
    var campuses = <Campus>[];
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/landmarks')
          .replace(queryParameters: {'type': 'kampus', 'q': q});
      final res = await http.get(uri);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        campuses = (body['data'] as List)
            .map((e) => Campus.fromJson(e as Map<String, dynamic>))
            .take(4)
            .toList();
      }
    } catch (_) {}
    var matchedAreas = <Area>[];
    try {
      matchedAreas =
          (await areas()).where((a) => _matchesAll(tokens, a.name)).take(3).toList();
    } catch (_) {}
    return (campuses, matchedAreas);
  }

  Future<T> _delay<T>(T v) =>
      Future.delayed(const Duration(milliseconds: 450), () => v);

  Future<List<Kos>> _getList(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: query);
    final res = await http.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memuat data');
    }
    return (body['data'] as List)
        .map((e) => Kos.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// "Area Kos Populer". API: GET /cities/popular
  Future<List<Area>> areas() async {
    if (ApiConfig.useMock) {
      return _delay([
        for (final a in _areas)
          Area(
            id: a.id,
            name: a.name,
            imagePath: a.imagePath,
            kosCount: _mock.where((k) => k.city == a.name).length,
          ),
      ]);
    }
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/cities/popular'));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memuat area');
    }
    return (body['data'] as List)
        .map((e) => Area.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// "Kos Sekitar Kampus". API: GET /landmarks?type=kampus&popular=1
  Future<List<Campus>> campuses() async {
    if (ApiConfig.useMock) return _delay(_campuses);
    final uri = Uri.parse('${ApiConfig.baseUrl}/landmarks')
        .replace(queryParameters: {'type': 'kampus', 'popular': '1'});
    final res = await http.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memuat kampus');
    }
    return (body['data'] as List)
        .map((e) => Campus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// "Pilihan Editor"
  Future<List<Kos>> featured() => ApiConfig.useMock
      ? _delay(_mock.where((k) => k.rating >= 4.6).toList())
      : _getList('/kos/featured');

  /// "Diskon Kilat"
  Future<List<Kos>> promo() => ApiConfig.useMock
      ? _delay(_mock.where((k) => k.promoLabel != null).toList())
      : _getList('/kos/promo');

  /// Pencarian + filter (lihat tabel parameter GET /kos di docs/API.md).
  Future<List<Kos>> list({
    String? q,
    String? type,
    int? areaId,
    int? campusId,
    bool availableOnly = false,
    bool promoOnly = false,
    KosSort sort = KosSort.recommended,
  }) {
    if (ApiConfig.useMock) {
      final tokens = _tokens(q ?? '');
      // kos yang dekat kampus yang cocok dengan kata kunci (mis. "unesa")
      final nearMatchedCampus = <int>{
        if (tokens.isNotEmpty)
          for (final c in _campuses)
            if (_matchesAll(tokens, '${c.shortName} ${c.name} ${c.city}'))
              ...?_nearCampus[c.id],
      };
      final cityName = areaId == null
          ? null
          : _areas.where((a) => a.id == areaId).map((a) => a.name).firstOrNull;
      final result = _mock.where((k) {
        final okType = type == null || k.type == type;
        final okCity = cityName == null || k.city == cityName;
        final okCampus = campusId == null || (_nearCampus[campusId]?.contains(k.id) ?? false);
        final okAvail = !availableOnly || k.availableRooms > 0;
        final okPromo = !promoOnly || k.promoLabel != null;
        final okQ = tokens.isEmpty ||
            _matchesAll(tokens,
                '${k.name} ${k.district} ${k.city} ${k.facilities.join(' ')}') ||
            nearMatchedCampus.contains(k.id);
        return okType && okCity && okCampus && okAvail && okPromo && okQ;
      }).toList();

      switch (sort) {
        case KosSort.recommended:
          result.sort((a, b) {
            final c = b.rating.compareTo(a.rating);
            return c != 0 ? c : b.ratingCount.compareTo(a.ratingCount);
          });
        case KosSort.priceAsc:
          result.sort((a, b) => a.minPrice.compareTo(b.minPrice));
        case KosSort.priceDesc:
          result.sort((a, b) => b.minPrice.compareTo(a.minPrice));
        case KosSort.rating:
          result.sort((a, b) => b.rating.compareTo(a.rating));
      }
      return _delay(result);
    }
    return _getList('/kos', {
      if (q != null && q.isNotEmpty) 'q': q,
      if (type != null) 'type': type,
      if (areaId != null) 'city_id': '$areaId',
      if (campusId != null) ...{'landmark_id': '$campusId', 'radius_km': '3'},
      if (availableOnly) 'available': '1',
      if (promoOnly) 'promo': '1',
      'sort': sort.apiValue,
    });
  }

  // ------------------------------------------------------------------
  // DETAIL KOS (dummy). Di backend: GET /kos/:id dan GET /kos/:id/reviews
  // ------------------------------------------------------------------
  static const _facBasic = <FacilityItem>[
    FacilityItem('Kasur', 'kamar', 'bed'),
    FacilityItem('Lemari', 'kamar', 'checkroom'),
    FacilityItem('Meja & Kursi', 'kamar', 'chair'),
    FacilityItem('Jendela', 'kamar', 'window'),
    FacilityItem('Kamar Mandi Luar', 'kamar_mandi', 'bathroom'),
    FacilityItem('WiFi', 'umum', 'wifi'),
    FacilityItem('Parkir Motor', 'parkir', 'two_wheeler'),
  ];
  static const _facMid = <FacilityItem>[
    FacilityItem('Kasur', 'kamar', 'bed'),
    FacilityItem('Lemari', 'kamar', 'checkroom'),
    FacilityItem('Meja & Kursi', 'kamar', 'chair'),
    FacilityItem('Kamar Mandi Dalam', 'kamar_mandi', 'shower'),
    FacilityItem('Kloset Duduk', 'kamar_mandi', 'wc'),
    FacilityItem('WiFi', 'umum', 'wifi'),
    FacilityItem('CCTV', 'umum', 'videocam'),
    FacilityItem('Listrik Termasuk', 'umum', 'bolt'),
    FacilityItem('Parkir Motor', 'parkir', 'two_wheeler'),
  ];
  static const _facPlus = <FacilityItem>[
    FacilityItem('AC', 'kamar', 'ac_unit'),
    FacilityItem('Kasur', 'kamar', 'bed'),
    FacilityItem('Lemari', 'kamar', 'checkroom'),
    FacilityItem('Meja & Kursi', 'kamar', 'chair'),
    FacilityItem('Kamar Mandi Dalam', 'kamar_mandi', 'shower'),
    FacilityItem('Kloset Duduk', 'kamar_mandi', 'wc'),
    FacilityItem('Air Panas', 'kamar_mandi', 'hot_tub'),
    FacilityItem('WiFi', 'umum', 'wifi'),
    FacilityItem('Dapur Bersama', 'umum', 'kitchen'),
    FacilityItem('Mesin Cuci', 'umum', 'local_laundry_service'),
    FacilityItem('CCTV', 'umum', 'videocam'),
    FacilityItem('Penjaga Kos', 'umum', 'security'),
    FacilityItem('Listrik Termasuk', 'umum', 'bolt'),
    FacilityItem('Parkir Motor', 'parkir', 'two_wheeler'),
    FacilityItem('Parkir Mobil', 'parkir', 'directions_car'),
  ];

  static const _rules = <List<String>>[
    ['Tamu dilarang masuk kamar', 'Jam malam pukul 22.00', 'Dilarang merokok di dalam kamar'],
    ['Dilarang membawa hewan peliharaan', 'Tamu lawan jenis hanya di ruang tamu', 'Jaga kebersihan area bersama'],
    ['Jam malam pukul 23.00', 'Dilarang membawa alat masak listrik ke kamar', 'Pembayaran paling lambat tanggal 10'],
  ];

  // titik pusat kota (lat, lng) untuk koordinat dummy
  static const _cityCenter = <String, (double, double)>{
    'Yogyakarta': (-7.7956, 110.3695),
    'Jakarta': (-6.2088, 106.8456),
    'Bandung': (-6.9175, 107.6191),
    'Surabaya': (-7.2575, 112.7521),
    'Malang': (-7.9666, 112.6326),
    'Semarang': (-6.9932, 110.4203),
    'Medan': (3.5952, 98.6722),
  };

  KosDetail _mockDetail(Kos k) {
    final c = _cityCenter[k.city] ?? (-6.2, 106.8);
    final r = k.rating;
    double v(double d) => ((r + d).clamp(1.0, 5.0) * 10).round() / 10;
    final who = switch (k.type) {
      'putra' => 'penghuni putra',
      'putri' => 'penghuni putri',
      _ => 'penghuni putra dan putri',
    };
    return KosDetail(
      kos: k,
      address: 'Jl. ${k.district} No. ${k.id * 3 + 4}, ${k.district}, ${k.city}',
      description:
          '${k.name} berada di ${k.district}, ${k.city}. Lingkungannya nyaman dan aman, '
          'cocok untuk $who. Dekat dengan warung makan, minimarket, dan akses '
          'transportasi umum. Kamar bersih, sirkulasi udara baik, dan pemilik '
          'responsif terhadap keluhan penghuni.',
      latitude: c.$1 + ((k.id % 5) - 2) * 0.004,
      longitude: c.$2 + ((k.id % 3) - 1) * 0.005,
      facilities: k.minPrice >= 1500000
          ? _facPlus
          : (k.minPrice >= 1000000 ? _facMid : _facBasic),
      rules: _rules[k.id % _rules.length],
      ratingBreakdown: {
        'cleanliness': v(0.1),
        'comfort': v(0),
        'safety': v(0.1),
        'price': v(-0.2),
        'room_facility': v(-0.1),
        'public_facility': v(-0.15),
      },
      ownerName: 'Bu Sari',
      rooms: _mockRooms(k),
    );
  }

  List<RoomType> _mockRooms(Kos k) {
    int r5(num v) => (v / 5000).round() * 5000;
    final even = k.id.isEven; // contoh: hanya sebagian kos yang menerima sewa harian/mingguan
    final rooms = <RoomType>[
      RoomType(
        id: k.id * 10 + 1,
        name: 'Tipe Standar',
        sizeLabel: k.minPrice >= 1500000 ? '3 x 4' : '3 x 3',
        priceDaily: even ? r5(k.minPrice / 18) : null,
        priceWeekly: even ? r5(k.minPrice * 0.3) : null,
        priceMonthly: k.minPrice,
        priceYearly: r5(k.minPrice * 11),
        deposit: r5(k.minPrice * 0.25),
        stock: k.availableRooms,
      ),
    ];
    if (k.id % 3 == 0) {
      final m = k.minPrice + 350000;
      rooms.add(RoomType(
        id: k.id * 10 + 2,
        name: 'Tipe Deluxe (AC)',
        sizeLabel: '3 x 4',
        priceMonthly: m,
        priceYearly: r5(m * 11),
        deposit: r5(m * 0.25),
        stock: k.availableRooms ~/ 2,
      ));
    }
    return rooms;
  }

  static const _mockReviews = <(String, double, String, String?)>[
    ('Raka P.', 5.0, 'Kamarnya bersih dan wifi kencang. Ibu kos ramah, lokasi dekat kampus.', 'Terima kasih Kak Raka, semoga betah!'),
    ('Dewi A.', 4.5, 'Lingkungan aman dan tenang, cocok buat belajar. Air selalu lancar.', null),
    ('Bima S.', 4.0, 'Fasilitas sesuai foto. Parkir motor agak sempit kalau lagi ramai.', 'Terima kasih masukannya, akan kami rapikan area parkir.'),
    ('Nadia F.', 5.0, 'Kamar mandi dalam bersih, ada penjaga jadi merasa tenang.', null),
    ('Fajar R.', 4.5, 'Harga sebanding dengan fasilitas. Listrik sudah termasuk.', null),
    ('Salsa M.', 4.0, 'Secara umum bagus, sinyal di lantai 2 kadang kurang.', null),
  ];

  /// Ulasan yang ditulis pengguna saat sesi mock ini (satu per kos).
  /// Hilang saat aplikasi di-restart; di backend disimpan di tabel `reviews`.
  final Map<int, Review> _myMockReviews = {};

  /// Gabungkan ulasan pengguna ke rating kos (mock) supaya angka ikut berubah.
  KosDetail _withMyReview(KosDetail d) {
    final mine = _myMockReviews[d.kos.id];
    if (mine == null) return d;
    final k = d.kos;
    final n = k.ratingCount;
    double mix(double base, double mineVal) =>
        ((base * n + mineVal) / (n + 1) * 10).round() / 10;
    return KosDetail(
      kos: Kos(
        id: k.id,
        name: k.name,
        type: k.type,
        district: k.district,
        city: k.city,
        coverUrl: k.coverUrl,
        minPrice: k.minPrice,
        rating: mix(k.rating, mine.rating),
        ratingCount: n + 1,
        availableRooms: k.availableRooms,
        isFavorite: k.isFavorite,
        promoLabel: k.promoLabel,
        facilities: k.facilities,
      ),
      address: d.address,
      description: d.description,
      latitude: d.latitude,
      longitude: d.longitude,
      facilities: d.facilities,
      rules: d.rules,
      ratingBreakdown: {
        for (final e in d.ratingBreakdown.entries)
          e.key: mix(e.value, mine.ratings[e.key] ?? e.value),
      },
      ownerName: d.ownerName,
      rooms: d.rooms,
    );
  }

  /// Detail lengkap satu kos. API: GET /kos/:id
  Future<KosDetail?> detail(int id) async {
    if (ApiConfig.useMock) {
      final k = _mock.where((e) => e.id == id).cast<Kos?>().firstOrNull;
      return _delay(k == null ? null : _withMyReview(_mockDetail(k)));
    }
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/kos/$id'));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return KosDetail.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Ulasan satu kos. API: GET /kos/:id/reviews?limit=
  Future<List<Review>> reviews(int kosId, {int limit = 20}) async {
    if (ApiConfig.useMock) {
      final k = _mock.where((e) => e.id == kosId).cast<Kos?>().firstOrNull;
      final n = (k == null ? 0 : k.ratingCount).clamp(0, _mockReviews.length);
      final now = DateTime.now();
      final mine = _myMockReviews[kosId];
      return _delay([
        if (mine != null) mine,
        for (var i = 0; i < n && i < limit - (mine == null ? 0 : 1); i++)
          Review(
            id: kosId * 100 + i,
            userName: _mockReviews[i].$1,
            rating: _mockReviews[i].$2,
            comment: _mockReviews[i].$3,
            ownerReply: _mockReviews[i].$4,
            createdAt: now.subtract(Duration(days: 4 + i * 9)),
          ),
      ]);
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/kos/$kosId/reviews')
        .replace(queryParameters: {'limit': '$limit'});
    final res = await http.get(uri);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memuat ulasan');
    }
    return (body['data'] as List)
        .map((e) => Review.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AuthState.instance.token}',
      };

  /// Ulasan milik pengguna yang sedang login untuk kos ini (null jika belum ada).
  /// API: GET /kos/:id/reviews/me  -> 200 {data: {...}} atau 404.
  Future<Review?> myReview(int kosId) async {
    if (!AuthState.instance.isLoggedIn) return null;
    if (ApiConfig.useMock) return _delay(_myMockReviews[kosId]);
    final res = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/kos/$kosId/reviews/me'),
      headers: _authHeaders,
    );
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'];
    return data is Map<String, dynamic> ? Review.fromJson(data) : null;
  }

  /// Kirim (atau perbarui) ulasan. [ratings] berisi 6 aspek skor 1-5,
  /// nilai keseluruhan = rata-ratanya.
  /// API: POST /kos/:id/reviews
  ///   body {ratings: {cleanliness, comfort, safety, price, room_facility,
  ///   public_facility}, comment}. Server membuat atau memperbarui ulasan
  ///   milik user yang sama, lalu menghitung ulang rating_avg kos.
  /// Melempar Exception(message) bila gagal.
  Future<Review> submitReview(
    int kosId, {
    required Map<String, double> ratings,
    required String comment,
  }) async {
    final overall = ratings.values.reduce((a, b) => a + b) / ratings.length;
    if (ApiConfig.useMock) {
      final name = AuthState.instance.user?.name ?? 'Pengguna';
      final parts = name.trim().split(RegExp(r'\s+'));
      final shortName =
          parts.length > 1 ? '${parts.first} ${parts[1][0].toUpperCase()}.' : parts.first;
      final old = _myMockReviews[kosId];
      final r = Review(
        id: kosId * 100 + 99,
        userName: shortName,
        rating: (overall * 10).round() / 10,
        comment: comment,
        ownerReply: old?.ownerReply,
        createdAt: old?.createdAt ?? DateTime.now(),
        ratings: Map.of(ratings),
      );
      _myMockReviews[kosId] = r;
      return _delay(r);
    }
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/kos/$kosId/reviews'),
      headers: _authHeaders,
      body: jsonEncode({'ratings': ratings, 'comment': comment}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if ((res.statusCode != 200 && res.statusCode != 201) || body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal mengirim ulasan');
    }
    return Review.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<Kos?> getById(int id) async {
    if (ApiConfig.useMock) {
      return _delay(_mock.where((k) => k.id == id).cast<Kos?>().firstOrNull);
    }
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/kos/$id'));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) return null;
    return Kos.fromJson(body['data'] as Map<String, dynamic>);
  }
}
