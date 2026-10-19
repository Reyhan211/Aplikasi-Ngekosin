import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/app_colors.dart';
import '../../data/kos_repository.dart';
import '../../models/area.dart';
import '../../models/campus.dart';
import '../../models/kos.dart';
import '../../shared/widgets/area_card.dart';
import '../../shared/widgets/campus_card.dart';
import '../../shared/widgets/async_list.dart';
import '../../shared/widgets/kos_card.dart';
import '../../core/widgets/ngekosin_brand.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _repo = KosRepository.instance;
  late Future<List<Kos>> _promo;
  late Future<List<Kos>> _featured;
  late Future<List<Kos>> _forYou;
  late Future<List<Area>> _areas;
  late Future<List<Campus>> _campuses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _promo = _repo.promo();
    _featured = _repo.featured();
    _forYou = _repo.list();
    _areas = _repo.areas();
    _campuses = _repo.campuses();
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_promo, _featured, _forYou, _areas, _campuses]);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: _refresh,
      child: CustomScrollView(
        slivers: [
          // chip jenis kos membuka halaman hasil yang sudah terfilter
          SliverToBoxAdapter(
            child: _Header(
              onType: (t) =>
                  context.push(t == null ? '/explore' : '/explore?type=$t'),
            ),
          ),
          const SliverToBoxAdapter(child: _Shortcuts()),
          const SliverToBoxAdapter(child: _PromoBanners()),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Area Kos Populer',
              subtitle: 'Pilih kota tujuanmu',
              onSeeAll: () => context.push('/areas'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AsyncList<Area>(
                  future: _areas,
                  onRetry: () => setState(() => _areas = _repo.areas()),
                  loadingHeight: 200,
                  // 5 kota + kartu "Lihat semua" = 6 kartu (3 baris x 2 kolom)
                  builder: (_, areas) => AreaGrid(areas: areas, limit: 5),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Diskon Kilat',
              subtitle: 'Potongan sewa bulan pertama',
              child: _HList(
                future: _promo,
                onRetry: () => setState(() => _promo = _repo.promo()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Pilihan Editor',
              subtitle: 'Rating tinggi, kamar terawat',
              child: _HList(
                future: _featured,
                onRetry: () => setState(() => _featured = _repo.featured()),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Kos Sekitar Kampus',
              subtitle: 'Dekat ke kelas, hemat ongkos',
              onSeeAll: () => context.push('/campuses'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AsyncList<Campus>(
                  future: _campuses,
                  onRetry: () => setState(() => _campuses = _repo.campuses()),
                  loadingHeight: 160,
                  // 5 kampus + kartu "Lihat semua" = 6 kartu (3 baris x 2 kolom)
                  builder: (_, list) => CampusGrid(campuses: list, limit: 5),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _Section(
              title: 'Kos untukmu',
              child: AsyncList<Kos>(
                future: _forYou,
                onRetry: () => setState(() => _forYou = _repo.list()),
                emptyText: 'Belum ada kos.',
                builder: (_, list) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (final k in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: KosTile(kos: k),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ruang agar konten tidak tertutup bottom nav melayang
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- header
class _Header extends StatelessWidget {
  final ValueChanged<String?> onType;
  const _Header({required this.onType});

  @override
  Widget build(BuildContext context) {
    final auth = AuthState.instance;
    final name = auth.user?.name.split(' ').first;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 16,
        20,
        22,
      ),
      decoration: const BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const NgekosinWordmark(height: 36, onDark: true),
              const Spacer(),
              IconButton(
                onPressed: () {
                  // TODO: halaman notifikasi (GET /notifications)
                },
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: Colors.white,
                ),
                tooltip: 'Notifikasi',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name == null ? 'Halo, calon anak kos' : 'Halo, $name',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Mau ngekos di mana?',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 16),
          // kolom pencarian: ketuk untuk membuka tab Jelajah
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/explore'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: AppColors.ink),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cari kampus, area, atau nama kos',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ),
                    Icon(
                      Icons.tune_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _TypeChip(
                  label: 'Semua',
                  selected: true,
                  onTap: () => onType(null),
                ),
                _TypeChip(
                  label: 'Putra',
                  selected: false,
                  onTap: () => onType('putra'),
                ),
                _TypeChip(
                  label: 'Putri',
                  selected: false,
                  onTap: () => onType('putri'),
                ),
                _TypeChip(
                  label: 'Campur',
                  selected: false,
                  onTap: () => onType('campur'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.marigold
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.ink : Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- shortcut
class _Shortcuts extends StatelessWidget {
  const _Shortcuts();

  static const _items = <(IconData, String, String)>[
    (Icons.school_rounded, 'Dekat kampus', 'kampus'),
    (Icons.calendar_today_rounded, 'Sewa harian', 'harian'),
    (Icons.ac_unit_rounded, 'Ber-AC', 'AC'),
    (Icons.shower_rounded, 'KM dalam', 'Kamar Mandi Dalam'),
    (Icons.directions_car_rounded, 'Parkir mobil', 'Parkir Mobil'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final (icon, label, q) = _items[i];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () =>
                context.push('/explore?q=${Uri.encodeQueryComponent(q)}'),
            child: Container(
              width: 84,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.marigoldSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 20, color: AppColors.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- promo
class _PromoBanners extends StatelessWidget {
  const _PromoBanners();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: SizedBox(
        height: 120,
        child: PageView(
          padEnds: false,
          controller: PageController(viewportFraction: 0.88),
          children: const [
            _PromoCard(
              code: 'NGEKOSBARU',
              title: 'Sewa pertama lebih hemat',
              desc: 'Potongan Rp100.000 untuk pengguna baru',
              color: AppColors.marigold,
            ),
            _PromoCard(
              code: 'NGEKOSBARENG',
              title: 'Ajak teman ngekos bareng',
              desc: 'Dapat Koin Ngekos tiap teman yang menyewa',
              color: AppColors.marigoldSoft,
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final String code;
  final String title;
  final String desc;
  final Color color;
  const _PromoCard({
    required this.code,
    required this.title,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    maxLines: 2,
                    style: const TextStyle(
                      color: AppColors.inkDeep,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Kode $code disalin')));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Salin kode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- seksi
class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final Widget child;
  const _Section({
    required this.title,
    this.subtitle,
    this.onSeeAll,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onSeeAll ?? () => context.push('/explore'),
                  child: const Text('Lihat semua'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _HList extends StatelessWidget {
  final Future<List<Kos>> future;
  final VoidCallback onRetry;
  const _HList({required this.future, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AsyncList<Kos>(
      future: future,
      onRetry: onRetry,
      loadingHeight: 220,
      builder: (_, list) => SizedBox(
        height: 238,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => KosCard(kos: list[i]),
        ),
      ),
    );
  }
}
