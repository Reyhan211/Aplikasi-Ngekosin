import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/favorites_store.dart';
import '../../models/kos.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/kos_card.dart';

/// Tab Favorit: kos yang disimpan + terakhir dilihat.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});
  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _store = FavoritesStore.instance;

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Favorit', style: Theme.of(context).textTheme.headlineSmall),
              ),
            ),
            const TabBar(
              labelColor: AppColors.ink,
              indicatorColor: AppColors.marigold,
              indicatorWeight: 3,
              tabs: [Tab(text: 'Disimpan'), Tab(text: 'Terakhir dilihat')],
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _store,
                builder: (context, _) => TabBarView(
                  children: [
                    _KosList(
                      list: _store.favorites,
                      loading: _store.loading,
                      emptyIcon: Icons.favorite_border_rounded,
                      emptyTitle: 'Belum ada kos favorit',
                      emptyMessage:
                          'Ketuk ikon hati di kartu kos untuk menyimpannya di sini.',
                    ),
                    _KosList(
                      list: _store.recent,
                      loading: _store.loading,
                      emptyIcon: Icons.history_rounded,
                      emptyTitle: 'Belum ada riwayat',
                      emptyMessage: 'Kos yang kamu buka akan muncul di sini.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KosList extends StatelessWidget {
  final List<Kos> list;
  final bool loading;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptyMessage;
  const _KosList({
    required this.list,
    required this.loading,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && list.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.ink));
    }
    if (list.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        message: emptyMessage,
        actionLabel: 'Cari kos',
        onAction: () => context.go('/home'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => KosTile(kos: list[i]),
    );
  }
}
