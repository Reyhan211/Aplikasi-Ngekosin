import 'package:flutter/material.dart';
import '../../data/kos_repository.dart';
import '../../models/kos_detail.dart';
import '../../shared/widgets/async_list.dart';
import 'sections.dart';

/// Semua ulasan satu kos.
class ReviewsPage extends StatefulWidget {
  final int kosId;
  final String kosName;
  const ReviewsPage({super.key, required this.kosId, required this.kosName});
  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  late Future<List<Review>> _future = KosRepository.instance.reviews(widget.kosId, limit: 50);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ulasan')),
      body: AsyncList<Review>(
        future: _future,
        onRetry: () => setState(
            () => _future = KosRepository.instance.reviews(widget.kosId, limit: 50)),
        loadingHeight: 300,
        emptyText: 'Belum ada ulasan untuk ${widget.kosName}.',
        builder: (_, list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => ReviewTile(review: list[i]),
        ),
      ),
    );
  }
}
