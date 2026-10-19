import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/campus.dart';

/// Badge bulat kampus. Memakai logo dari assets/campus/<singkatan huruf kecil>.png|.jpg|.jpeg
/// (mis. assets/campus/ugm.jpg). Jika file logo belum ada, tampil singkatan huruf.
class CampusBadge extends StatelessWidget {
  final Campus campus;
  final double size;
  const CampusBadge({super.key, required this.campus, this.size = 40});

  static const _palette = <Color>[
    AppColors.ink,
    AppColors.putri,
    AppColors.campur,
    AppColors.putra,
    Color(0xFFB45309),
    AppColors.success,
  ];

  Widget _logo(String key, String ext, Widget Function() next) => Image.asset(
        'assets/campus/$key.$ext',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => next(),
      );

  @override
  Widget build(BuildContext context) {
    final c = _palette[campus.id % _palette.length];
    final key = campus.shortName.toLowerCase();
    final initials = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        campus.shortName,
        maxLines: 1,
        style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      // urutan pencarian logo: .png -> .jpg -> .jpeg -> singkatan huruf
      child: ClipOval(
        child: _logo(key, 'png', () => _logo(key, 'jpg', () => _logo(key, 'jpeg', () => initials))),
      ),
    );
  }
}

class CampusCard extends StatelessWidget {
  final Campus campus;
  const CampusCard({super.key, required this.campus});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/campus/${campus.id}', extra: campus),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            children: [
              CampusBadge(campus: campus),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(campus.shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(campus.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MoreCampusCard extends StatelessWidget {
  const MoreCampusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.marigoldSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/campuses'),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lihat semua',
                  style: TextStyle(
                      color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 14)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, color: AppColors.ink, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid 2 kolom. [limit] membatasi jumlah kampus dan menambah kartu "Lihat semua".
class CampusGrid extends StatelessWidget {
  final List<Campus> campuses;
  final int? limit;
  const CampusGrid({super.key, required this.campuses, this.limit});

  @override
  Widget build(BuildContext context) {
    final shown = limit == null ? campuses : campuses.take(limit!).toList();
    final showMore = limit != null && campuses.length > limit!;
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        for (final c in shown) CampusCard(campus: c),
        if (showMore) const MoreCampusCard(),
      ],
    );
  }
}
