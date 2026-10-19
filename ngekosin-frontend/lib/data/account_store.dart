import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/auth/auth_state.dart';
import '../core/config/api_config.dart';
import '../models/account.dart';

/// Data halaman Akun: koin, voucher, dan pengajuan pemilik kos.
/// Mock: disimpan di memori.
/// API (usulan): GET /coins, GET /vouchers, POST /vouchers/claim, POST /owner/apply.
/// (Ubah profil & password ada di [AuthState] karena menyentuh data user.)
class AccountStore extends ChangeNotifier {
  AccountStore._();
  static final AccountStore instance = AccountStore._();

  int _coins = 0;
  final List<CoinTx> _history = [];
  final List<Voucher> _vouchers = [];
  OwnerStatus ownerStatus = OwnerStatus.none;
  bool loading = false;
  bool _seeded = false;

  int get coins {
    _seedMock();
    return _coins;
  }

  List<CoinTx> get history {
    _seedMock();
    return List.unmodifiable(_history);
  }

  List<Voucher> get vouchers {
    _seedMock();
    return List.unmodifiable(_vouchers);
  }

  /// Jumlah voucher yang masih berlaku.
  int get activeVoucherCount => vouchers.where((v) => !v.expired).length;

  // ---------- mock ----------

  /// Data awal agar halaman tidak kosong saat dev UI.
  void _seedMock() {
    if (_seeded || !ApiConfig.useMock) return;
    _seeded = true;
    final now = DateTime.now();
    _coins = 1250;
    _history.addAll([
      CoinTx(title: 'Bonus akun baru', amount: 500, date: now.subtract(const Duration(days: 14))),
      CoinTx(title: 'Menulis ulasan', amount: 50, date: now.subtract(const Duration(days: 9))),
      CoinTx(title: 'Menyelesaikan masa sewa', amount: 700, date: now.subtract(const Duration(days: 3))),
    ]);
    _vouchers.addAll([
      Voucher(
        code: 'NGEKOSBARU',
        title: 'Diskon penyewa baru',
        description: 'Potongan untuk sewa pertamamu di Ngekos.in.',
        discount: 100000,
        minAmount: 500000,
        expiresAt: now.add(const Duration(days: 30)),
      ),
      Voucher(
        code: 'LIBURAN15',
        title: 'Promo musim liburan',
        description: 'Berlaku untuk semua tipe kos.',
        discount: 150000,
        minAmount: 1200000,
        expiresAt: now.add(const Duration(days: 12)),
      ),
    ]);
  }

  /// Kode yang bisa diklaim saat mode mock.
  Map<String, Voucher> _mockCatalog() {
    final now = DateTime.now();
    return {
      'HEMAT50': Voucher(
        code: 'HEMAT50',
        title: 'Hemat Rp50 rb',
        description: 'Potongan langsung untuk pengajuan sewa.',
        discount: 50000,
        minAmount: 800000,
        expiresAt: now.add(const Duration(days: 20)),
      ),
      'MAHASISWA': Voucher(
        code: 'MAHASISWA',
        title: 'Promo mahasiswa',
        description: 'Khusus mahasiswa, berlaku semua kos.',
        discount: 75000,
        minAmount: 1000000,
        expiresAt: now.add(const Duration(days: 45)),
      ),
    };
  }

  // ---------- API ----------

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (AuthState.instance.token != null)
          'Authorization': 'Bearer ${AuthState.instance.token}',
      };

  Future<Map<String, dynamic>> _call(String method, String path,
      {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final res = method == 'GET'
        ? await http.get(uri, headers: _headers)
        : await http.post(uri, headers: _headers, body: jsonEncode(body ?? {}));
    var json = <String, dynamic>{};
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode >= 400 || json['success'] == false) {
      throw Exception(json['message']?.toString() ?? 'Terjadi kesalahan (${res.statusCode})');
    }
    return json;
  }

  /// Muat koin & voucher dari server (tidak berbuat apa-apa saat mock).
  Future<void> load() async {
    if (ApiConfig.useMock || !AuthState.instance.isLoggedIn) return;
    loading = true;
    notifyListeners();
    try {
      final c = await _call('GET', '/coins');
      _coins = int.tryParse('${c['data']['balance']}') ?? 0;
      _history
        ..clear()
        ..addAll((c['data']['history'] as List)
            .map((e) => CoinTx.fromJson(e as Map<String, dynamic>)));
      final v = await _call('GET', '/vouchers');
      _vouchers
        ..clear()
        ..addAll((v['data'] as List)
            .map((e) => Voucher.fromJson(e as Map<String, dynamic>)));
    } catch (_) {
      // pertahankan data lama
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Masukkan kode voucher. Return voucher yang didapat, atau lempar Exception berisi pesan.
  Future<Voucher> claimVoucher(String raw) async {
    final code = raw.trim().toUpperCase();
    if (code.isEmpty) throw Exception('Masukkan kode voucher dulu');
    if (vouchers.any((v) => v.code == code)) {
      throw Exception('Voucher ini sudah ada di daftarmu');
    }
    final Voucher v;
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 350));
      final found = _mockCatalog()[code];
      if (found == null) throw Exception('Kode voucher tidak valid atau sudah berakhir');
      v = found;
    } else {
      final j = await _call('POST', '/vouchers/claim', body: {'code': code});
      v = Voucher.fromJson(j['data'] as Map<String, dynamic>);
    }
    _vouchers.insert(0, v);
    notifyListeners();
    return v;
  }

  /// Ajukan diri jadi pemilik kos. Status jadi "pending" sampai ditinjau admin.
  Future<void> applyOwner() async {
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 600));
    } else {
      await _call('POST', '/owner/apply');
    }
    ownerStatus = OwnerStatus.pending;
    notifyListeners();
  }

  void clear() {
    _coins = 0;
    _history.clear();
    _vouchers.clear();
    ownerStatus = OwnerStatus.none;
    _seeded = false;
    notifyListeners();
  }
}
