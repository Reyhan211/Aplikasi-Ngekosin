import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/favorites_store.dart';
import '../../models/kos.dart';
import 'smart_image.dart';

/// Foto kos; jika belum ada / gagal dimuat tampil blok warna + ikon.
class KosCover extends StatelessWidget {
  final Kos kos;
  final double? height;
  final double? width;
  const KosCover({super.key, required this.kos, this.height, this.width});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forType(kos.type);
    final fallback = Container(
      height: height,
      width: width,
      color: color.withValues(alpha: 0.14),
      child: Icon(Icons.apartment_rounded, size: 40, color: color),
    );
    return SmartImage(
      path: kos.coverUrl,
      width: width,
      height: height,
      fallback: fallback,
    );
  }
}

class TypeBadge extends StatelessWidget {
  final String type;
  const TypeBadge(this.type, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.forType(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(typeLabel(type),
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

/// Tombol hati "Favorit". Butuh login; status disimpan di [FavoritesStore].
class FavButton extends StatelessWidget {
  final Kos kos;
  const FavButton({super.key, required this.kos});

  @override
  Widget build(BuildContext context) {
    final store = FavoritesStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final on = store.isFavorite(kos.id);
        return InkWell(
          onTap: () {
            if (!AuthState.instance.isLoggedIn) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Masuk dulu untuk menyimpan kos favorit')),
              );
              context.push('/login');
              return;
            }
            store.toggle(kos);
          },
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(
              on ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 18,
              color: on ? AppColors.danger : AppColors.textMuted,
            ),
          ),
        );
      },
    );
  }
}

/// Kartu vertikal (untuk daftar horizontal di Beranda).
class KosCard extends StatelessWidget {
  final Kos kos;
  final double width;
  const KosCard({super.key, required this.kos, this.width = 240});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/kos/${kos.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  KosCover(kos: kos, height: 128, width: double.infinity),
                  Positioned(left: 10, top: 10, child: TypeBadge(kos.type)),
                  Positioned(right: 8, top: 8, child: FavButton(kos: kos)),
                  if (kos.promoLabel != null)
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: const BoxDecoration(
                          color: AppColors.marigold,
                          borderRadius: BorderRadius.only(topRight: Radius.circular(12)),
                        ),
                        child: Text(kos.promoLabel!,
                            style: const TextStyle(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w800,
                                fontSize: 11)),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kos.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(kos.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(TextSpan(children: [
                            TextSpan(
                                text: rupiahShort(kos.minPrice),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15)),
                            const TextSpan(
                                text: ' /bln',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ])),
                        ),
                        const Icon(Icons.star_rounded, size: 16, color: AppColors.marigold),
                        const SizedBox(width: 2),
                        Text(kos.rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
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

/// Baris horizontal (untuk daftar vertikal: "Kos untukmu" & hasil Jelajah).
class KosTile extends StatelessWidget {
  final Kos kos;
  const KosTile({super.key, required this.kos});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/kos/${kos.id}'),
        child: SizedBox(
          height: 112,
          child: Row(
            children: [
              SizedBox(width: 112, child: KosCover(kos: kos, height: 112, width: 112)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        TypeBadge(kos.type),
                        const Spacer(),
                        FavButton(kos: kos),
                      ]),
                      Text(kos.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(kos.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Row(children: [
                        Text(rupiahShort(kos.minPrice),
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        const Text(' /bln',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        const Spacer(),
                        const Icon(Icons.star_rounded, size: 15, color: AppColors.marigold),
                        Text(' ${kos.rating.toStringAsFixed(1)}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kartu lebar untuk halaman hasil (daftar kos per area): foto besar di atas,
/// info di bawah. Muat di HP karena semua teks dibatasi 1-2 baris.
class KosWideCard extends StatelessWidget {
  final Kos kos;
  const KosWideCard({super.key, required this.kos});

  @override
  Widget build(BuildContext context) {
    final full = kos.availableRooms == 0;
    final low = kos.availableRooms > 0 && kos.availableRooms <= 3;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/kos/${kos.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                KosCover(kos: kos, height: 168, width: double.infinity),
                Positioned(right: 10, top: 10, child: FavButton(kos: kos)),
                if (kos.promoLabel != null)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: const BoxDecoration(
                        color: AppColors.marigold,
                        borderRadius: BorderRadius.only(topRight: Radius.circular(12)),
                      ),
                      child: Text(kos.promoLabel!,
                          style: const TextStyle(
                              color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TypeBadge(kos.type),
                      const SizedBox(width: 8),
                      Text(
                        full ? 'Penuh' : 'Sisa ${kos.availableRooms} kamar',
                        style: TextStyle(
                          color: full || low ? AppColors.danger : AppColors.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.star_rounded, size: 16, color: AppColors.marigold),
                      Text(' ${kos.rating.toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(kos.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(kos.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  if (kos.facilities.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(kos.facilities.take(4).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: rupiah(kos.minPrice),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      const TextSpan(
                          text: '/bulan',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ])),
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
