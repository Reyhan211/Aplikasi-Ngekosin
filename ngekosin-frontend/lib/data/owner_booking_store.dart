import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/auth/auth_state.dart';
import '../core/config/api_config.dart';
import '../models/booking.dart';

/// Kelompok tab untuk pemilik kos.
enum OwnerGroup { perluTindakan, berjalan, riwayat }

/// Pengajuan sewa & pembayaran yang masuk ke kos milik pemilik.
/// API: GET /owner/bookings, POST /owner/bookings/:id/{confirm|reject|activate|complete}.
/// Saat ApiConfig.useMock = true daftar selalu kosong (tidak ada data dummy).
class OwnerBookingStore extends ChangeNotifier {
  OwnerBookingStore._();
  static final OwnerBookingStore instance = OwnerBookingStore._();

  final List<Booking> _items = [];
  bool loading = false;
  String? error;

  static OwnerGroup groupOf(Booking b) => switch (b.status) {
        'menunggu_konfirmasi' || 'dibayar' => OwnerGroup.perluTindakan,
        'menunggu_pembayaran' || 'aktif' => OwnerGroup.berjalan,
        _ => OwnerGroup.riwayat,
      };

  List<Booking> byGroup(OwnerGroup g) => _items.where((b) => groupOf(b) == g).toList();
  int count(OwnerGroup g) => _items.where((b) => groupOf(b) == g).length;

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (AuthState.instance.token != null)
          'Authorization': 'Bearer ${AuthState.instance.token}',
      };

  /// URL gambar bukti bayar (butuh header Authorization).
  String proofUrl(Booking b) => '${ApiConfig.baseUrl}/bookings/${b.id}/proof';

  Future<void> load() async {
    if (ApiConfig.useMock || !AuthState.instance.isLoggedIn) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/owner/bookings'), headers: headers);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        _items
          ..clear()
          ..addAll((body['data'] as List)
              .map((e) => Booking.fromJson(e as Map<String, dynamic>)));
      } else {
        error = body['message']?.toString() ?? 'Gagal memuat data';
      }
    } catch (_) {
      error = 'Tidak dapat terhubung ke server';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// [action]: confirm | reject | activate | complete.
  /// Melempar Exception(pesan) bila gagal.
  Future<void> act(Booking b, String action) async {
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/owner/bookings/${b.id}/$action'),
      headers: headers,
    );
    Map<String, dynamic> body = {};
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message']?.toString() ?? 'Terjadi kesalahan (${res.statusCode})');
    }
    final updated = Booking.fromJson(body['data'] as Map<String, dynamic>);
    final i = _items.indexWhere((e) => e.id == b.id);
    if (i != -1) _items[i] = updated;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    error = null;
    notifyListeners();
  }
}
