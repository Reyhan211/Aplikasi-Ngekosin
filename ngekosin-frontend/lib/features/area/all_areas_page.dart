import 'package:flutter/material.dart';
import '../../data/kos_repository.dart';
import '../../models/area.dart';
import '../../shared/widgets/area_card.dart';
import '../../shared/widgets/async_list.dart';

/// Semua area kos (tujuan tombol "Lihat semua" di Beranda).
class AllAreasPage extends StatefulWidget {
  const AllAreasPage({super.key});
  @override
  State<AllAreasPage> createState() => _AllAreasPageState();
}

class _AllAreasPageState extends State<AllAreasPage> {
  late Future<List<Area>> _future = KosRepository.instance.areas();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Area Kos Populer')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AsyncList<Area>(
            future: _future,
            onRetry: () => setState(() => _future = KosRepository.instance.areas()),
            loadingHeight: 300,
            builder: (_, areas) => AreaGrid(areas: areas),
          ),
        ],
      ),
    );
  }
}
