import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../models/kos_detail.dart';

/// Pembungkus satu bagian halaman: judul + isi.
class DetailBlock extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  const DetailBlock({super.key, required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ deskripsi
class ExpandableText extends StatefulWidget {
  final String text;
  const ExpandableText(this.text, {super.key});
  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > 150;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _open || !long ? null : 4,
          overflow: _open || !long ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(height: 1.5, color: AppColors.textPrimary),
        ),
        if (long)
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_open ? 'Sembunyikan' : 'Selengkapnya',
                  style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------ fasilitas
IconData facilityIcon(String? name) {
  switch (name) {
    case 'ac_unit':
      return Icons.ac_unit_rounded;
    case 'bed':
      return Icons.bed_rounded;
    case 'checkroom':
      return Icons.checkroom_rounded;
    case 'chair':
      return Icons.chair_rounded;
    case 'wifi':
      return Icons.wifi_rounded;
    case 'window':
      return Icons.window_rounded;
    case 'shower':
      return Icons.shower_rounded;
    case 'bathroom':
      return Icons.bathroom_rounded;
    case 'wc':
      return Icons.wc_rounded;
    case 'hot_tub':
      return Icons.hot_tub_rounded;
    case 'kitchen':
      return Icons.kitchen_rounded;
    case 'local_laundry_service':
      return Icons.local_laundry_service_rounded;
    case 'videocam':
      return Icons.videocam_rounded;
    case 'weekend':
      return Icons.weekend_rounded;
    case 'two_wheeler':
      return Icons.two_wheeler_rounded;
    case 'directions_car':
      return Icons.directions_car_rounded;
    case 'security':
      return Icons.security_rounded;
    case 'bolt':
      return Icons.bolt_rounded;
    default:
      return Icons.check_circle_outline_rounded;
  }
}

class FacilitiesSection extends StatelessWidget {
  final List<FacilityItem> items;
  const FacilitiesSection({super.key, required this.items});

  static const _order = <(String, String)>[
    ('kamar', 'Kamar'),
    ('kamar_mandi', 'Kamar mandi'),
    ('umum', 'Umum'),
    ('parkir', 'Parkir'),
  ];

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('Belum ada data fasilitas.', style: TextStyle(color: AppColors.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (key, label) in _order)
          if (items.any((f) => f.category == key)) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in items.where((f) => f.category == key))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(facilityIcon(f.icon), size: 17, color: AppColors.ink),
                        const SizedBox(width: 7),
                        Text(f.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

// ------------------------------------------------------------ aturan
class RulesSection extends StatelessWidget {
  final List<String> rules;
  const RulesSection({super.key, required this.rules});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            for (var i = 0; i < rules.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.info_outline_rounded, size: 18, color: AppColors.marigold),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(rules[i], style: const TextStyle(height: 1.35))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ lokasi / peta
class LocationSection extends StatelessWidget {
  final String address;
  final double lat;
  final double lng;
  final String name;
  const LocationSection({
    super.key,
    required this.address,
    required this.lat,
    required this.lng,
    required this.name,
  });

  Future<void> _openMaps(BuildContext context) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka aplikasi peta')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final point = LatLng(lat, lng);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.place_rounded, size: 18, color: AppColors.danger),
            const SizedBox(width: 6),
            Expanded(child: Text(address, style: const TextStyle(height: 1.35))),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 190,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 15.5,
                    // peta statis: agar tidak "merebut" gestur scroll halaman
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ngekosin',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: point,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_on_rounded,
                            size: 44, color: AppColors.danger),
                      ),
                    ]),
                  ],
                ),
                // wajib: atribusi OpenStreetMap
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Colors.white.withValues(alpha: 0.8),
                    child: const Text('© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
                  ),
                ),
                // ketuk peta = buka aplikasi peta
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(onTap: () => _openMaps(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _openMaps(context),
          icon: const Icon(Icons.directions_rounded),
          label: const Text('Buka di Google Maps'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ ulasan
/// Aspek penilaian (kunci API, label). Dipakai RatingSummary dan form ulasan.
const kReviewAspects = <(String, String)>[
  ('cleanliness', 'Kebersihan'),
  ('comfort', 'Kenyamanan'),
  ('safety', 'Keamanan'),
  ('price', 'Harga'),
  ('room_facility', 'Fasilitas kamar'),
  ('public_facility', 'Fasilitas umum'),
];

class RatingSummary extends StatelessWidget {
  final double rating;
  final int count;
  final Map<String, double> breakdown;
  const RatingSummary({
    super.key,
    required this.rating,
    required this.count,
    required this.breakdown,
  });

  static const _labels = kReviewAspects;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text(rating.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 38)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          rating >= i
                              ? Icons.star_rounded
                              : (rating >= i - 0.5
                                  ? Icons.star_half_rounded
                                  : Icons.star_outline_rounded),
                          size: 20,
                          color: AppColors.marigold,
                        ),
                    ]),
                    const SizedBox(height: 2),
                    Text('$count ulasan',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ],
            ),
            if (breakdown.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(),
              const SizedBox(height: 10),
              for (final (key, label) in _labels)
                if (breakdown.containsKey(key))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 112,
                          child: Text(label, style: const TextStyle(fontSize: 13)),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (breakdown[key]! / 5).clamp(0.0, 1.0),
                              minHeight: 7,
                              backgroundColor: AppColors.line,
                              color: AppColors.marigold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 34,
                          child: Text(breakdown[key]!.toStringAsFixed(1),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class ReviewTile extends StatelessWidget {
  final Review review;
  const ReviewTile({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final initial = review.userName.isEmpty ? '?' : review.userName[0].toUpperCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.marigoldSoft,
                  child: Text(initial,
                      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(review.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(DateFormat('d MMM yyyy', 'id_ID').format(review.createdAt),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.star_rounded, size: 17, color: AppColors.marigold),
                const SizedBox(width: 2),
                Text(review.rating.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(review.comment, style: const TextStyle(height: 1.4)),
            ],
            if (review.ownerReply != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Balasan pemilik',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    const SizedBox(height: 3),
                    Text(review.ownerReply!,
                        style: const TextStyle(fontSize: 13, height: 1.35)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
