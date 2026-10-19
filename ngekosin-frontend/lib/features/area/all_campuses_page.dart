import 'package:flutter/material.dart';
import '../../data/kos_repository.dart';
import '../../models/campus.dart';
import '../../shared/widgets/async_list.dart';
import '../../shared/widgets/campus_card.dart';

/// Semua kampus (tujuan tombol "Lihat semua" di "Kos Sekitar Kampus").
class AllCampusesPage extends StatefulWidget {
  const AllCampusesPage({super.key});
  @override
  State<AllCampusesPage> createState() => _AllCampusesPageState();
}

class _AllCampusesPageState extends State<AllCampusesPage> {
  late Future<List<Campus>> _future = KosRepository.instance.campuses();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kos Sekitar Kampus')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          AsyncList<Campus>(
            future: _future,
            onRetry: () => setState(() => _future = KosRepository.instance.campuses()),
            loadingHeight: 300,
            builder: (_, list) => CampusGrid(campuses: list),
          ),
        ],
      ),
    );
  }
}
