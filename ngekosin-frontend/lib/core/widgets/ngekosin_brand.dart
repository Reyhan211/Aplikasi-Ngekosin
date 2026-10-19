import 'package:flutter/material.dart';

/// Logo resmi Ngekos.in (gambar). [onDark] = true memakai versi putih
/// untuk latar gelap (mis. header biru di Beranda).
/// File: assets/brand/logo_wordmark.png dan logo_wordmark_white.png
class NgekosinWordmark extends StatelessWidget {
  final double height;
  final bool onDark;
  const NgekosinWordmark({super.key, this.height = 36, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      onDark
          ? 'assets/brand/logo_wordmark_white.png'
          : 'assets/brand/logo_wordmark.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Ngekos.in',
      // jika file belum ada, tampil teks agar aplikasi tidak error
      errorBuilder: (_, __, ___) => Text(
        'Ngekos.in',
        style: TextStyle(
          fontSize: height * 0.6,
          fontWeight: FontWeight.w800,
          color: onDark ? Colors.white : Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Logo Ngekosin versi ikon: kotak membulat bergradasi dengan ikon rumah.
class NgekosinLogo extends StatelessWidget {
  final double size;
  const NgekosinLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final darker = HSLColor.fromColor(primary)
        .withLightness(
            (HSLColor.fromColor(primary).lightness - 0.12).clamp(0.0, 1.0))
        .toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, darker],
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(Icons.home_rounded, color: Colors.white, size: size * 0.62),
    );
  }
}

/// Header brand: logo + tulisan "Ngekosin" di kiri atas.
/// [trailing] opsional, untuk ikon di kanan (notifikasi, chat, dll).
class NgekosinHeader extends StatelessWidget {
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const NgekosinHeader({
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          const NgekosinWordmark(),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
