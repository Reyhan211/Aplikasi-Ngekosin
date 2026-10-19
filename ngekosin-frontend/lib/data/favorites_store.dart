import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/auth/auth_state.dart';
import '../core/config/api_config.dart';
import '../models/kos.dart';

/// Kos yang disimpan (favorit) dan terakhir dilihat.
/// Mock: disimpan di memori. API: GET/POST/DELETE /favorites, GET /recently-viewed.
class FavoritesStore extends ChangeNotifier {
  FavoritesStore._();
  static final FavoritesStore instance = FavoritesStore._();

  final Map<int, Kos> _fav = {};
  final List<Kos> _recent = [];
  bool loading = false;

  /// Favorit terbaru di atas.
  List<Kos> get favorites => _fav.values.toList().reversed.toList();
  List<Kos> get recent => List.unmodifiable(_recent);
  bool isFavorite(int id) => _fav.containsKey(id);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthState.instance.token != null)
          'Authorization': 'Bearer ${AuthState.instance.token}',
      };

  Future<List<Kos>> _getList(String path) async {
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200 || body['success'] != true) {
      throw Exception(body['message'] ?? 'Gagal memuat data');
    }
    return (body['data'] as List)
        .map((e) => Kos.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Ambil data dari server (tidak berbuat apa-apa saat mode mock).
  Future<void> load() async {
    if (ApiConfig.useMock || !AuthState.instance.isLoggedIn) return;
    loading = true;
    notifyListeners();
    try {
      final favs = await _getList('/favorites');
      _fav
        ..clear()
        ..addEntries(favs.map((k) => MapEntry(k.id, k)));
      _recent
        ..clear()
        ..addAll(await _getList('/recently-viewed'));
    } catch (_) {
      // biarkan data lama; halaman tetap bisa dipakai
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Simpan / hapus dari favorit (optimistis: UI berubah dulu, dibatalkan jika server gagal).
  Future<void> toggle(Kos k) async {
    final wasFav = isFavorite(k.id);
    if (wasFav) {
      _fav.remove(k.id);
    } else {
      _fav[k.id] = k;
    }
    notifyListeners();
    if (ApiConfig.useMock) return;
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/favorites/${k.id}');
      final res = wasFav
          ? await http.delete(uri, headers: _headers)
          : await http.post(uri, headers: _headers);
      if (res.statusCode >= 400) throw Exception('gagal');
    } catch (_) {
      if (wasFav) {
        _fav[k.id] = k;
      } else {
        _fav.remove(k.id);
      }
      notifyListeners();
    }
  }

  /// Catat kos yang baru dibuka. (Di server tercatat otomatis lewat GET /kos/:id.)
  void addRecent(Kos k) {
    _recent.removeWhere((e) => e.id == k.id);
    _recent.insert(0, k);
    if (_recent.length > 10) _recent.removeLast();
    notifyListeners();
  }

  void clear() {
    _fav.clear();
    _recent.clear();
    notifyListeners();
  }
}
