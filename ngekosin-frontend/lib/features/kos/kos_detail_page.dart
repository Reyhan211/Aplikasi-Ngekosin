import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/chat_repository.dart';
import '../../data/favorites_store.dart';
import '../../data/kos_repository.dart';
import '../../models/kos.dart';
import '../../models/kos_detail.dart';
import '../../shared/widgets/async_list.dart';
import '../../shared/widgets/kos_card.dart';
import 'sections.dart';
import 'write_review_sheet.dart';

/// Detail kos: tentang, fasilitas, aturan, lokasi (peta), dan ulasan.
/// TODO berikutnya: galeri foto, tipe kamar + harga per periode, dan jadwal survei.
class KosDetailPage extends StatefulWidget {
  final int kosId;
  const KosDetailPage({super.key, required this.kosId});
  @override
  State<KosDetailPage> createState() => _KosDetailPageState();
}

class _KosDetailPageState extends State<KosDetailPage> {
  final _repo = KosRepository.instance;
  late Future<KosDetail?> _detail = _repo.detail(widget.kosId);
  late Future<List<Review>> _reviews = _repo.reviews(widget.kosId, limit: 3);
  bool _openingChat = false;
  Review? _myReview; // ulasan milik user login (null = belum mengulas)

  /// Tombol "Chat pemilik": POST /chat/rooms lalu buka ruangnya.
  Future<void> _chatOwner(int kosId) async {
    if (!AuthState.instance.isLoggedIn) {
      context.push('/login');
      return;
    }
    if (_openingChat) return;
    setState(() => _openingChat = true);
    try {
      final room = await ChatRepository.instance.openRoom(kosId);
      if (!mounted) return;
      context.push('/chat/${room.id}', extra: room);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  Future<void> _loadMine() async {
    try {
      final r = await _repo.myReview(widget.kosId);
      if (mounted) setState(() => _myReview = r);
    } catch (_) {
      // abaikan: tombol tetap tampil sebagai "Tulis ulasan"
    }
  }

  /// Tombol "Tulis ulasan": wajib login, lalu buka form.
  Future<void> _writeReview(Kos kos) async {
    if (!AuthState.instance.isLoggedIn) {
      context.push('/login');
      return;
    }
    final sent = await showWriteReviewSheet(
      context,
      kosId: kos.id,
      kosName: kos.name,
      existing: _myReview,
    );
    if (!sent || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_myReview == null
            ? 'Terima kasih, ulasanmu sudah terkirim'
            : 'Ulasanmu berhasil diperbarui'),
      ),
    );
    _reload();
    _loadMine();
  }

  @override
  void initState() {
    super.initState();
    _loadMine();
    // catat ke "Terakhir dilihat" setelah data kos berhasil dimuat
    _detail.then((d) {
      if (d != null) FavoritesStore.instance.addRecent(d.kos);
    });
  }

  void _reload() => setState(() {
        _detail = _repo.detail(widget.kosId);
        _reviews = _repo.reviews(widget.kosId, limit: 3);
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<KosDetail?>(
      future: _detail,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done && snap.data == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator(color: AppColors.ink)),
          );
        }
        final d = snap.data;
        if (snap.hasError || d == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snap.hasError ? 'Gagal memuat data' : 'Kos tidak ditemukan'),
                  TextButton(onPressed: _reload, child: const Text('Coba lagi')),
                ],
              ),
            ),
          );
        }
        final kos = d.kos;
        return Scaffold(
          appBar: AppBar(
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FavButton(kos: kos),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: KosCover(kos: kos, height: 220, width: double.infinity),
              ),
              const SizedBox(height: 16),
              Row(children: [
                TypeBadge(kos.type),
                const SizedBox(width: 8),
                const Icon(Icons.star_rounded, size: 18, color: AppColors.marigold),
                Flexible(
                  child: Text(' ${kos.rating.toStringAsFixed(1)} (${kos.ratingCount} ulasan)',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ]),
              const SizedBox(height: 10),
              Text(kos.name, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.place_outlined, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(kos.location, style: const TextStyle(color: AppColors.textMuted)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(
                kos.availableRooms == 0 ? 'Kamar penuh' : 'Sisa ${kos.availableRooms} kamar',
                style: TextStyle(
                  color: kos.availableRooms <= 3 ? AppColors.danger : AppColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),

              if (d.description.isNotEmpty)
                DetailBlock(
                  title: 'Tentang kos',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExpandableText(d.description),
                      if (d.ownerName.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(children: [
                          const Icon(Icons.verified_user_rounded,
                              size: 16, color: AppColors.success),
                          const SizedBox(width: 6),
                          Text('Dikelola oleh ${d.ownerName}',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        ]),
                      ],
                    ],
                  ),
                ),

              DetailBlock(
                title: 'Fasilitas',
                child: FacilitiesSection(items: d.facilities),
              ),

              if (d.rules.isNotEmpty)
                DetailBlock(title: 'Aturan kos', child: RulesSection(rules: d.rules)),

              if (d.hasLocation)
                DetailBlock(
                  title: 'Lokasi',
                  child: LocationSection(
                    address: d.address.isEmpty ? kos.location : d.address,
                    lat: d.latitude!,
                    lng: d.longitude!,
                    name: kos.name,
                  ),
                ),

              DetailBlock(
                title: 'Ulasan',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RatingSummary(
                      rating: kos.rating,
                      count: kos.ratingCount,
                      breakdown: d.ratingBreakdown,
                    ),
                    // pemilik/admin tidak mengulas kosnya sendiri
                    if (AuthState.instance.user?.role == null ||
                        AuthState.instance.user?.role == 'pencari') ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _writeReview(kos),
                          icon: Icon(_myReview == null
                              ? Icons.rate_review_outlined
                              : Icons.edit_outlined),
                          label: Text(_myReview == null ? 'Tulis ulasan' : 'Ubah ulasanmu'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    AsyncList<Review>(
                      future: _reviews,
                      onRetry: () => setState(
                          () => _reviews = _repo.reviews(widget.kosId, limit: 3)),
                      loadingHeight: 120,
                      emptyText: 'Belum ada ulasan.',
                      builder: (_, list) => Column(
                        children: [
                          for (final r in list)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: ReviewTile(review: r),
                            ),
                          if (kos.ratingCount > list.length)
                            OutlinedButton(
                              onPressed: () => context.push(
                                '/kos/${kos.id}/reviews',
                                extra: kos.name,
                              ),
                              child: Text('Lihat semua ${kos.ratingCount} ulasan'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mulai dari',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      Text('${rupiah(kos.minPrice)}/bln',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _openingChat ? null : () => _chatOwner(kos.id),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(52, 52),
                        padding: EdgeInsets.zero,
                      ),
                      child: _openingChat
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                            )
                          : const Icon(Icons.chat_bubble_outline_rounded),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: AppTheme.ctaStyle,
                      // router mengarahkan ke /login bila belum masuk
                      onPressed: kos.availableRooms == 0
                          ? null
                          : () => context.push('/kos/${kos.id}/booking'),
                      child: Text(kos.availableRooms == 0 ? 'Kamar Penuh' : 'Ajukan Sewa'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
