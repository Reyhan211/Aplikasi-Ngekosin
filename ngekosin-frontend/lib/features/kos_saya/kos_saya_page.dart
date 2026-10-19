import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/app_colors.dart';
import '../../data/booking_store.dart';
import '../../models/booking.dart';
import '../../shared/widgets/empty_state.dart';
import 'booking_card.dart';
import 'owner_bookings_view.dart';

/// Tab Kos Saya: kos yang sedang ditempati, pengajuan sewa, dan riwayat.
/// Data dari [BookingStore] (GET /bookings).
///
/// Untuk akun pemilik/admin ada pemilih "Penyewa | Sewaanku": "Penyewa" menampilkan
/// siapa yang mengajukan/membayar kos miliknya ([OwnerBookingsView]).
///
/// [tab] ("ditempati" | "pengajuan" | "riwayat") memilih tab saat dibuka,
/// mis. setelah mengajukan sewa. [stamp] berubah tiap navigasi supaya tab
/// berpindah lagi walau [tab]-nya sama.
class KosSayaPage extends StatefulWidget {
  final String? tab;
  final String? stamp;
  const KosSayaPage({super.key, this.tab, this.stamp});

  @override
  State<KosSayaPage> createState() => _KosSayaPageState();
}

class _KosSayaPageState extends State<KosSayaPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: _indexOf(widget.tab),
  );

  static int _indexOf(String? t) {
    final i = BookingGroup.values.indexWhere((g) => g.name == t);
    return i == -1 ? 0 : i;
  }

  @override
  void initState() {
    super.initState();
    BookingStore.instance.load();
  }

  @override
  void didUpdateWidget(KosSayaPage old) {
    super.didUpdateWidget(old);
    if (widget.tab != old.tab || widget.stamp != old.stamp) {
      _tabs.animateTo(_indexOf(widget.tab));
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// true = tampilan pemilik ("Penyewa"), false = sewaan milik sendiri.
  bool _ownerMode = true;

  bool get _isOwner {
    final r = AuthState.instance.user?.role;
    return r == 'pemilik' || r == 'admin';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: AuthState.instance,
        builder: (context, _) {
          final owner = _isOwner;
          return Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('Kos Saya', style: Theme.of(context).textTheme.headlineSmall),
                ),
              ),
              if (owner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: true, icon: Icon(Icons.groups_rounded), label: Text('Penyewa')),
                      ButtonSegment(
                          value: false, icon: Icon(Icons.key_rounded), label: Text('Sewaanku')),
                    ],
                    selected: {_ownerMode},
                    onSelectionChanged: (s) => setState(() => _ownerMode = s.first),
                  ),
                ),
              if (owner && _ownerMode)
                const Expanded(child: OwnerBookingsView())
              else ...[
                TabBar(
                  controller: _tabs,
                  labelColor: AppColors.ink,
                  indicatorColor: AppColors.marigold,
                  indicatorWeight: 3,
                  tabs: const [Tab(text: 'Ditempati'), Tab(text: 'Pengajuan'), Tab(text: 'Riwayat')],
                ),
                Expanded(
                  child: ListenableBuilder(
                    listenable: BookingStore.instance,
                    builder: (context, _) => TabBarView(
                      controller: _tabs,
                      children: [
                        for (final g in BookingGroup.values) _GroupList(group: g),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GroupList extends StatelessWidget {
  final BookingGroup group;
  const _GroupList({required this.group});

  @override
  Widget build(BuildContext context) {
    final store = BookingStore.instance;
    final items = store.byGroup(group);

    if (items.isEmpty) {
      if (store.loading) {
        return const Center(child: CircularProgressIndicator(color: AppColors.ink));
      }
      return switch (group) {
        BookingGroup.ditempati => EmptyState(
            icon: Icons.home_work_outlined,
            title: 'Belum ada kos yang ditempati',
            message: 'Setelah pengajuan sewa disetujui dan dibayar, kosmu muncul di sini.',
            actionLabel: 'Cari kos',
            onAction: () => context.go('/home'),
          ),
        BookingGroup.pengajuan => EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada pengajuan sewa',
            message: 'Pilih kos, lalu tekan "Ajukan Sewa" untuk memulai.',
            actionLabel: 'Cari kos',
            onAction: () => context.go('/home'),
          ),
        BookingGroup.riwayat => const EmptyState(
            icon: Icons.history_rounded,
            title: 'Belum ada riwayat sewa',
            message: 'Kos yang pernah kamu sewa akan tercatat di sini.',
          ),
      };
    }

    // bawah 120: ruang untuk bottom nav "pill" yang melayang
    return RefreshIndicator(
      onRefresh: store.load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => BookingCard(booking: items[i]),
      ),
    );
  }
}
