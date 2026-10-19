import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/kos_repository.dart';
import '../../models/kos_detail.dart';
import 'sections.dart';

/// Buka form ulasan. Mengembalikan true bila ulasan berhasil dikirim.
/// [existing] diisi bila pengguna sudah pernah mengulas (mode ubah).
Future<bool> showWriteReviewSheet(
  BuildContext context, {
  required int kosId,
  required String kosName,
  Review? existing,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => WriteReviewSheet(kosId: kosId, kosName: kosName, existing: existing),
  );
  return ok == true;
}

class WriteReviewSheet extends StatefulWidget {
  final int kosId;
  final String kosName;
  final Review? existing;
  const WriteReviewSheet({
    super.key,
    required this.kosId,
    required this.kosName,
    this.existing,
  });

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  static const _maxComment = 500;

  late final Map<String, double> _ratings = {
    for (final (key, _) in kReviewAspects) key: widget.existing?.ratings[key] ?? 0,
  };
  late final _comment = TextEditingController(text: widget.existing?.comment ?? '');
  bool _sending = false;
  String? _error;

  bool get _complete => _ratings.values.every((v) => v >= 1);

  double get _overall => _complete
      ? _ratings.values.reduce((a, b) => a + b) / _ratings.length
      : 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_complete || _sending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await KosRepository.instance.submitReview(
        widget.kosId,
        ratings: Map.of(_ratings),
        comment: _comment.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Padding(
      // naikkan sheet saat keyboard muncul
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(editing ? 'Ubah ulasanmu' : 'Tulis ulasan',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(widget.kosName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 16),
            for (final (key, label) in kReviewAspects)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
                    _StarPicker(
                      value: _ratings[key]!,
                      enabled: !_sending,
                      onChanged: (v) => setState(() => _ratings[key] = v),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, size: 20, color: AppColors.marigold),
                  const SizedBox(width: 6),
                  Text(
                    _complete ? _overall.toStringAsFixed(1) : '-',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _complete
                          ? 'Rata-rata penilaianmu'
                          : 'Beri bintang untuk semua aspek',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _comment,
              enabled: !_sending,
              maxLines: 4,
              maxLength: _maxComment,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ceritakan pengalamanmu tinggal di sini (opsional)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              style: AppTheme.ctaStyle,
              onPressed: (_complete && !_sending) ? _submit : null,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.ink),
                    )
                  : Text(editing ? 'Simpan perubahan' : 'Kirim ulasan'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lima bintang yang bisa diketuk (nilai 1-5).
class _StarPicker extends StatelessWidget {
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  const _StarPicker({required this.value, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => onChanged(i.toDouble()) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              child: Icon(
                value >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 30,
                color: value >= i ? AppColors.marigold : AppColors.line,
              ),
            ),
          ),
      ],
    );
  }
}
