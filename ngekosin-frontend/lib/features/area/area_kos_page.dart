import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/kos_repository.dart';
import '../../models/area.dart';
import '../../models/campus.dart';
import '../../models/kos.dart';
import '../../shared/widgets/async_list.dart';
import '../../shared/widgets/kos_card.dart';

/// Daftar kos di satu kota ATAU di sekitar satu kampus (tanpa peta).
/// Filter: jenis kos, kamar tersedia, diskon, dan urutan.
class AreaKosPage extends StatefulWidget {
  final Area? area;
  final Campus? campus;
  const AreaKosPage({super.key, this.area, this.campus})
      : assert(area != null || campus != null, 'isi area atau campus');
  @override
  State<AreaKosPage> createState() => _AreaKosPageState();
}

class _AreaKosPageState extends State<AreaKosPage> {
  final _repo = KosRepository.instance;
  String? _type;
  bool _availableOnly = false;
  bool _promoOnly = false;
  KosSort _sort = KosSort.recommended;
  late Future<List<Kos>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  String get _title =>
      widget.campus != null ? 'Kos ${widget.campus!.shortName}' : 'Kos ${widget.area!.name}';

  String get _where =>
      widget.campus != null ? 'di sekitar ${widget.campus!.shortName}' : 'di ${widget.area!.name}';

  Future<List<Kos>> _fetch() => _repo.list(
        areaId: widget.area?.id,
        campusId: widget.campus?.id,
        type: _type,
        availableOnly: _availableOnly,
        promoOnly: _promoOnly,
        sort: _sort,
      );

  void _reload(VoidCallback change) => setState(() {
        change();
        _future = _fetch();
      });

  Future<T?> _pick<T>(String title, List<(String, T)> options, T current) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
              ),
              for (final (label, value) in options)
                ListTile(
                  title: Text(label),
                  trailing: value == current
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.ink)
                      : null,
                  onTap: () => Navigator.pop(ctx, value),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickType() async {
    // nilai '' mewakili "Semua tipe" (null tidak bisa dikembalikan dari sheet)
    final v = await _pick<String>('Tipe kos', const [
      ('Semua tipe kos', ''),
      ('Putra', 'putra'),
      ('Putri', 'putri'),
      ('Campur', 'campur'),
    ], _type ?? '');
    if (v != null) _reload(() => _type = v.isEmpty ? null : v);
  }

  Future<void> _pickSort() async {
    final v = await _pick<KosSort>(
      'Urutkan',
      [for (final s in KosSort.values) (s.label, s)],
      _sort,
    );
    if (v != null) _reload(() => _sort = v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _Pill(
                  label: _type == null
                      ? 'Semua Tipe Kos'
                      : 'Kos ${_type![0].toUpperCase()}${_type!.substring(1)}',
                  active: _type != null,
                  icon: Icons.keyboard_arrow_down_rounded,
                  onTap: _pickType,
                ),
                _Pill(
                  label: _sort.label,
                  active: _sort != KosSort.recommended,
                  icon: Icons.swap_vert_rounded,
                  onTap: _pickSort,
                ),
                _Pill(
                  label: 'Kamar Tersedia',
                  active: _availableOnly,
                  onTap: () => _reload(() => _availableOnly = !_availableOnly),
                ),
                _Pill(
                  label: 'Diskon Kilat',
                  active: _promoOnly,
                  icon: Icons.bolt_rounded,
                  onTap: () => _reload(() => _promoOnly = !_promoOnly),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncList<Kos>(
              future: _future,
              onRetry: () => setState(() => _future = _fetch()),
              loadingHeight: 300,
              emptyText: 'Belum ada kos yang cocok dengan filter ini.',
              builder: (_, list) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: list.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
                      child: Text(
                        'Menampilkan ${list.length} kos $_where',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontWeight: FontWeight.w600),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: KosWideCard(kos: list[i - 1]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool active;
  final IconData? icon;
  final VoidCallback onTap;
  const _Pill({required this.label, required this.active, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? AppColors.ink : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? AppColors.ink : AppColors.line),
          ),
          child: Row(
            children: [
              Text(label,
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  )),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 16, color: active ? Colors.white : AppColors.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
