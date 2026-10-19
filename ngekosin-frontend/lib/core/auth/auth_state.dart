import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AuthUser {
  final int id;
  final String name;
  final String? username;
  final String email;
  final String role; // pencari | pemilik | admin
  final String? phone;

  const AuthUser({
    required this.id,
    required this.name,
    this.username,
    required this.email,
    required this.role,
    this.phone,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: int.parse(j['id'].toString()),
        name: (j['name'] ?? '').toString(),
        username: j['username']?.toString(),
        email: (j['email'] ?? '').toString(),
        role: (j['role'] ?? 'pencari').toString(),
        phone: j['phone']?.toString(),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'username': username, 'email': email, 'role': role, 'phone': phone};
}

/// Status login global. Dipakai router (redirect) dan halaman Profil.
class AuthState extends ChangeNotifier {
  AuthState._();
  static final AuthState instance = AuthState._();

  AuthUser? user;
  String? token;

  bool get isLoggedIn => user != null;

  /// Panggil sekali di main() untuk memulihkan sesi.
  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
    final raw = p.getString('user');
    if (raw != null) {
      user = AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  }

  /// Simpan token + user ke memori dan penyimpanan lokal, lalu beri tahu router.
  Future<void> _startSession(Map<String, dynamic> data) async {
    token = data['token'] as String;
    user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    final p = await SharedPreferences.getInstance();
    await p.setString('token', token!);
    await p.setString('user', jsonEncode(user!.toJson()));
    notifyListeners();
  }

  /// [identity] boleh email ATAU username.
  /// Return null jika sukses, atau pesan error.
  Future<String?> login(String identity, String password) async {
    if (ApiConfig.useMock) {
      final isEmail = identity.contains('@');
      user = AuthUser(
        id: 3,
        name: 'Raka Mahasiswa',
        username: isEmail ? identity.split('@').first : identity,
        email: isEmail ? identity : '$identity@ngekos.in',
        role: 'pencari',
      );
      notifyListeners();
      return null;
    }
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'login': identity, 'password': password}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) {
        await _startSession(body['data'] as Map<String, dynamic>);
        return null;
      }
      return body['message']?.toString() ?? 'Login gagal';
    } catch (_) {
      return 'Tidak dapat terhubung ke server';
    }
  }

  /// POST /auth/register, lalu langsung login. [role] = 'pencari' | 'pemilik'
  /// (pemilik = pengajuan yang ditinjau admin). Return null jika sukses, atau pesan error.
  Future<String?> register({
    required String name,
    required String username,
    required String email,
    String? phone,
    required String password,
    String role = 'pencari',
  }) async {
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      user = AuthUser(
          id: 3, name: name, username: username, email: email, role: 'pencari', phone: phone);
      notifyListeners();
      return null;
    }
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'username': username,
          'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          'password': password,
          'role': role,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if ((res.statusCode == 201 || res.statusCode == 200) && body['success'] == true) {
        await _startSession(body['data'] as Map<String, dynamic>);
        return null;
      }
      return body['message']?.toString() ?? 'Pendaftaran gagal';
    } catch (_) {
      return 'Tidak dapat terhubung ke server';
    }
  }

  /// GET /auth/check-username. true = bisa dipakai, false = sudah dipakai /
  /// tidak valid, null = gagal mengecek (mis. server mati).
  Future<bool?> isUsernameAvailable(String username) async {
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      return !const {'admin', 'ngekosin', 'raka', 'sari'}.contains(username);
    }
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/auth/check-username')
          .replace(queryParameters: {'username': username});
      final res = await http.get(uri);
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode != 200 || body['success'] != true) return null;
      return body['data']['available'] == true;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// PUT /auth/profile. Return null jika sukses, atau pesan error.
  Future<String?> updateProfile({required String name, String? phone}) async {
    final u = user;
    if (u == null) return 'Sesi berakhir, silakan login ulang';
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
    } else {
      try {
        final res = await http.put(
          Uri.parse('${ApiConfig.baseUrl}/auth/profile'),
          headers: _authHeaders,
          body: jsonEncode({'name': name, 'phone': phone}),
        );
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (res.statusCode != 200 || body['success'] != true) {
          return body['message']?.toString() ?? 'Gagal menyimpan profil';
        }
      } catch (_) {
        return 'Tidak dapat terhubung ke server';
      }
    }
    user = AuthUser(
        id: u.id, name: name, username: u.username, email: u.email, role: u.role, phone: phone);
    if (token != null) {
      final p = await SharedPreferences.getInstance();
      await p.setString('user', jsonEncode(user!.toJson()));
    }
    notifyListeners();
    return null;
  }

  /// PUT /auth/password. Return null jika sukses, atau pesan error.
  Future<String?> changePassword(String oldPassword, String newPassword) async {
    if (ApiConfig.useMock) {
      await Future.delayed(const Duration(milliseconds: 400));
      return null;
    }
    try {
      final res = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/auth/password'),
        headers: _authHeaders,
        body: jsonEncode({'old_password': oldPassword, 'new_password': newPassword}),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 && body['success'] == true) return null;
      return body['message']?.toString() ?? 'Gagal mengganti password';
    } catch (_) {
      return 'Tidak dapat terhubung ke server';
    }
  }

  Future<void> logout() async {
    user = null;
    token = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('token');
    await p.remove('user');
    notifyListeners();
  }
}
