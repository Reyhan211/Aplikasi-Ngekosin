import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../core/auth/auth_state.dart';
import '../core/config/api_config.dart';
import '../models/booking.dart';

/// Daftar pengajuan sewa milik user. Mock: disimpan di memori.
/// API: POST /bookings, GET /bookings, POST /bookings/:id/cancel, POST /promos/validate.
class BookingStore extends ChangeNotifier {
  BookingStore._();
  static final BookingStore instance = BookingStore._();

  final List<Booking> _items = [];
  int _nextId = 1;
  bool loading = false;

  List<Booking> byGroup(BookingGroup g) => _items.where((b) => b.group == g).toList();

  Booking? byId(int id) {
    for (final b in _items) {
      if (b.id == id) return b;
    }
    return null;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthState.instance.token != null)
          'Authorization': 'Bearer ${AuthState.instance.token}',
      };

  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Never _fail(http.Response res) {
    String msg = 'Terjadi kesalahan (${res.statusCode})';
    try {
      msg = (jsonDecode(res.body) as Map<String, dynamic>)['message']?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  /// Muat ulang dari server (tidak berbuat apa-apa saat mock).
  Future<void> load() async {
    if (ApiConfig.useMock || !AuthState.instance.isLoggedIn) return;
    loading = true;
    notifyListeners();
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/bookings'), headers: _headers);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        _items
          ..clear()
          ..addAll((body['data'] as List)
              .map((e) => Booking.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {
      // pertahankan data lama
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Cek kode promo. Return nominal diskon, atau lempar Exception berisi pesan.
  Future<int> validatePromo({
    required String code,
    required int kosId,
    required int amount,
  }) async {
    final c = code.trim().toUpperCase();
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (c == 'NGEKOSBARU') {
        if (amount < 500000) throw Exception('Minimal sewa Rp500.000 untuk kode ini');
        return 100000;
      }
      throw Exception('Kode promo tidak valid atau sudah berakhir');
    }
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/promos/validate'),
      headers: _headers,
      body: jsonEncode({'code': c, 'kos_id': kosId, 'amount': amount}),
    );
    if (res.statusCode != 200) _fail(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return int.tryParse('${body['data']['discount']}') ?? 0;
  }

  /// Kirim pengajuan sewa. Status awal: menunggu_konfirmasi.
  Future<Booking> create(BookingDraft d) async {
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 700));
      final now = DateTime.now();
      final price = d.unit.priceOf(d.room) ?? d.room.priceMonthly;
      final pricing = BookingPricing(
        pricePerUnit: price,
        count: d.count,
        deposit: d.room.deposit,
        discount: d.discount,
      );
      final id = _nextId++;
      final day = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final b = Booking(
        id: id,
        code: 'NGK-$day-${id.toString().padLeft(4, '0')}',
        kosId: d.kos.id,
        kosName: d.kos.name,
        kosType: d.kos.type,
        kosLocation: d.kos.location,
        coverUrl: d.kos.coverUrl,
        roomName: d.room.name,
        checkin: d.checkin,
        checkout: d.unit.endDate(d.checkin, d.count),
        unit: d.unit,
        durationCount: d.count,
        pricePerUnit: price,
        deposit: d.room.deposit,
        adminFee: BookingPricing.adminFee,
        discount: d.discount,
        total: pricing.total,
        occupants: d.occupants,
        tenantName: d.tenantName,
        tenantPhone: d.tenantPhone,
        note: d.note,
        status: 'menunggu_konfirmasi',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 24)),
      );
      _items.insert(0, b);
      notifyListeners();
      return b;
    }

    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/bookings'),
      headers: _headers,
      body: jsonEncode({
        'kos_id': d.kos.id,
        'room_type_id': d.room.id,
        'checkin_date': _date(d.checkin),
        'duration_unit': d.unit.apiValue,
        'duration_count': d.count,
        'occupants': d.occupants,
        'tenant_name': d.tenantName,
        'tenant_phone': d.tenantPhone,
        if (d.promoCode != null) 'promo_code': d.promoCode,
        if (d.note != null && d.note!.isNotEmpty) 'note': d.note,
      }),
    );
    if (res.statusCode != 201 && res.statusCode != 200) _fail(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final b = Booking.fromJson(body['data'] as Map<String, dynamic>);
    _items.insert(0, b);
    notifyListeners();
    return b;
  }

  /// Batalkan pengajuan (hanya saat menunggu konfirmasi / pembayaran).
  Future<void> cancel(Booking b) async {
    if (!ApiConfig.useMock) {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/bookings/${b.id}/cancel'),
        headers: _headers,
      );
      if (res.statusCode != 200) _fail(res);
    } else {
      await Future.delayed(const Duration(milliseconds: 300));
    }
    final i = _items.indexWhere((e) => e.id == b.id);
    if (i != -1) _items[i] = b.withStatus('dibatalkan');
    notifyListeners();
  }

  /// Bayar pengajuan. [method] = kode metode (mis. `bca`, `gopay`, `qris`),
  /// [proof] = bukti transfer (wajib untuk transfer bank).
  /// API: POST /bookings/:id/pay (multipart: method, proof). Status jadi `dibayar`.
  Future<void> pay(Booking b, {required String method, XFile? proof}) async {
    if (!ApiConfig.useMock) {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/bookings/${b.id}/pay'),
      )
        ..headers.addAll({
          if (AuthState.instance.token != null)
            'Authorization': 'Bearer ${AuthState.instance.token}',
        })
        ..fields['method'] = method;
      if (proof != null) {
        req.files.add(await http.MultipartFile.fromPath('proof', proof.path));
      }
      final res = await http.Response.fromStream(await req.send());
      if (res.statusCode != 200 && res.statusCode != 201) _fail(res);
    } else {
      await Future.delayed(const Duration(milliseconds: 900));
    }
    final i = _items.indexWhere((e) => e.id == b.id);
    if (i != -1) _items[i] = b.withStatus('dibayar');
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
