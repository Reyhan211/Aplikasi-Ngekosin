import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../../models/area.dart';

/// Kartu kota: gambar + nama di kiri bawah. Responsif lewat grid 2 kolom.
class AreaCard extends StatelessWidget {
  final Area area;
  const AreaCard({super.key, required this.area});

  Widget _image() {
    final p = area.imagePath;
    final fallback = Container(
      color: AppColors.ink,
      child: const Center(
        child: Icon(Icons.location_city_rounded, color: Colors.white54, size: 36),
      ),
    );
    if (p == null) return fallback;
    if (p.startsWith('assets/')) {
      return Image.asset(p, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
    }
    final url = ApiConfig.fileUrl(p);
    return url == null
        ? fallback
        : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      color: AppColors.ink,
      child: InkWell(
        onTap: () => context.push('/area/${area.id}', extra: area),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _image(),
            // gradasi gelap supaya teks putih selalu terbaca
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.35, 1.0],
                  colors: [Color(0x00111A40), Color(0xE6111A40)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kos ${area.name}',
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (area.kosCount > 0)
                    Text(
                      '${area.kosCount} kos',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kartu "Lihat semua" di ujung grid.
class MoreAreaCard extends StatelessWidget {
  const MoreAreaCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.marigoldSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/areas'),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lihat semua',
                  style: TextStyle(
                      color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 15)),
              SizedBox(height: 4),
              Icon(Icons.arrow_forward_rounded, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid 2 kolom yang pas di HP. [limit] membatasi jumlah kota dan
/// menambah kartu "Lihat semua" di akhir.
class AreaGrid extends StatelessWidget {
  final List<Area> areas;
  final int? limit;
  const AreaGrid({super.key, required this.areas, this.limit});

  @override
  Widget build(BuildContext context) {
    final shown = limit == null ? areas : areas.take(limit!).toList();
    final showMore = limit != null && areas.length > limit!;
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.35,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        for (final a in shown) AreaCard(area: a),
        if (showMore) const MoreAreaCard(),
      ],
    );
  }
}
