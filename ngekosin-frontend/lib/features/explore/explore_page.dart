import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/kos_repository.dart';
import '../../models/area.dart';
import '../../models/campus.dart';
import '../../models/kos.dart';
import '../../shared/widgets/async_list.dart';
import '../../shared/widgets/kos_card.dart';

/// Halaman pencarian (dibuka dari Beranda): pencarian + filter jenis. Filter lanjutan (harga, fasilitas,
/// periode sewa, jarak) tinggal ditambah di bottom sheet sesuai docs/API.md.
class ExplorePage extends StatefulWidget {
  final String? initialQuery;
  final String? initialType;
  const ExplorePage({super.key, this.initialQuery, this.initialType});
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final _repo = KosRepository.instance;
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialQuery);
  late String? _type = widget.initialType;
  late Future<List<Kos>> _future;
  late Future<(List<Campus>, List<Area>)> _suggest;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void didUpdateWidget(covariant ExplorePage old) {
    super.didUpdateWidget(old);
    // tab ini dipertahankan hidup; perbarui saat datang dari shortcut Beranda
    if (old.initialQuery != widget.initialQuery || old.initialType != widget.initialType) {
      _ctrl.text = widget.initialQuery ?? '';
      _type = widget.initialType;
      setState(_search);
    }
  }

  void _search() {
    final q = _ctrl.text.trim();
    _future = _repo.list(q: q, type: _type);
    _suggest = _repo.suggest(q);
  }

  /// Cari otomatis 400 ms setelah berhenti mengetik.
  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(_search);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cari kos')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: widget.initialQuery == null && widget.initialType == null,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (_) {
                _debounce?.cancel();
                setState(_search);
              },
              decoration: InputDecoration(
                hintText: 'Cari kampus, area, atau nama kos',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _ctrl.clear();
                    setState(_search);
                  },
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                for (final (label, value) in const [
                  ('Semua', null),
                  ('Putra', 'putra'),
                  ('Putri', 'putri'),
                  ('Campur', 'campur'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _type == value,
                      showCheckmark: false,
                      selectedColor: AppColors.ink,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _type == value ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (_) => setState(() {
                        _type = value;
                        _search();
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Suggestions(future: _suggest),
                  AsyncList<Kos>(
                    future: _future,
                    onRetry: () => setState(_search),
                    emptyText: 'Kos tidak ditemukan. Coba kata kunci lain.',
                    loadingHeight: 240,
                    builder: (_, list) => Column(
                      children: [
                        for (final k in list)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: KosTile(kos: k),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Saran kampus / area yang cocok dengan kata kunci; ketuk untuk membuka
/// daftar kos di sekitarnya.
class _Suggestions extends StatelessWidget {
  final Future<(List<Campus>, List<Area>)> future;
  const _Suggestions({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<Campus>, List<Area>)>(
      future: future,
      builder: (context, snap) {
        final data = snap.data;
        if (data == null || (data.$1.isEmpty && data.$2.isEmpty)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Column(
              children: [
                for (final c in data.$1)
                  ListTile(
                    leading: const Icon(Icons.school_outlined, color: AppColors.ink),
                    title: Text('${c.shortName} · ${c.name}'),
                    subtitle: const Text('Kos sekitar kampus'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/campus/${c.id}', extra: c),
                  ),
                for (final a in data.$2)
                  ListTile(
                    leading: const Icon(Icons.location_city_rounded, color: AppColors.ink),
                    title: Text(a.name),
                    subtitle: const Text('Semua kos di area ini'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => context.push('/area/${a.id}', extra: a),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
