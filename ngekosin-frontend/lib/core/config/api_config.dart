class ApiConfig {
  ApiConfig._();

  /// true  = pakai data dummy (bisa jalan tanpa backend, cocok untuk dev UI)
  /// false = panggil REST API sungguhan
  static const bool useMock = false;

  /// Emulator Android: 10.0.2.2 = localhost komputer.
  /// HP fisik: ganti dengan IP LAN komputer, mis. http://192.168.1.10:3000
  static const String host = 'http://10.0.2.2:3000';
  static const String baseUrl = '$host/api/v1';

  /// Ubah path relatif dari DB ("uploads/kos/a.jpg") jadi URL penuh.
  static String? fileUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '$host/$path';
  }
}
