import 'package:flutter/material.dart';
import '../../core/config/api_config.dart';

/// Menampilkan gambar dari:
///  - aset lokal  : path diawali "assets/" (mis. "assets/kos/kos-1.jpg")
///  - server/API  : path relatif ("uploads/kos/a.jpg") atau URL penuh (http...)
/// Jika path kosong atau gambar gagal dimuat, tampil [fallback].
class SmartImage extends StatelessWidget {
  final String? path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget fallback;

  const SmartImage({
    super.key,
    required this.path,
    required this.fallback,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null || p.isEmpty) return fallback;
    if (p.startsWith('assets/')) {
      return Image.asset(p, width: width, height: height, fit: fit,
          errorBuilder: (_, __, ___) => fallback);
    }
    final url = ApiConfig.fileUrl(p);
    if (url == null) return fallback;
    return Image.network(url, width: width, height: height, fit: fit,
        errorBuilder: (_, __, ___) => fallback);
  }
}
