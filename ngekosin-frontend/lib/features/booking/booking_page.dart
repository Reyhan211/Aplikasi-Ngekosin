import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/auth/auth_state.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/booking_store.dart';
import '../../data/kos_repository.dart';
import '../../models/booking.dart';
import '../../models/kos_detail.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/kos_card.dart';
import '../kos/sections.dart';

/// Form "Ajukan Sewa": pilih tipe kamar, periode, tanggal masuk, data penyewa,
/// kode promo, lalu kirim lewat [BookingStore.create].
/// Rute: /kos/:id/booking (wajib login, dijaga di app_router.dart).
class BookingPage extends StatefulWidget {
  final int kosId;
  const BookingPage({super.key, required this.kosId});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  late Future<KosDetail?> _detail = KosRepository.instance.detail(widget.kosId);

  void _reload() =>
      setState(() => _detail = KosRepository.instance.detail(widget.kosId));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<KosDetail?>(
      future: _detail,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ajukan Sewa')),
            body: const Center(child: CircularProgressIndicator(color: AppColors.ink)),
          );
        }
        final d = snap.data;
        if (snap.hasError || d == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ajukan Sewa')),
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
        if (d.rooms.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ajukan Sewa')),
            body: const EmptyState(
              icon: Icons.meeting_room_outlined,
              title: 'Belum ada tipe kamar',
              message: 'Pemilik belum mengatur tipe kamar untuk kos ini.',
            ),
          );
        }
        return _BookingForm(detail: d);
      },
    );
  }
}

class _BookingForm extends StatefulWidget {
  final KosDetail detail;
  const _BookingForm({required this.detail});

  @override
  State<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<_BookingForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: AuthState.instance.user?.name ?? '');
  final _phone = TextEditingController();
  final _note = TextEditingController();
  final _promo = TextEditingController();

  static final _dateFmt = DateFormat('d MMM yyyy', 'id_ID');

  RoomType? _room;
  DurationUnit _unit = DurationUnit.bulanan;
  int _count = 1;
  int _occupants = 1;
  late DateTime _checkin;

  String? _promoCode; // kode yang sudah tervalidasi
  int _discount = 0;
  String? _promoMsg;
  bool _promoOk = false;
  bool _checkingPromo = false;
  bool _submitting = false;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _checkin = _today.add(const Duration(days: 1));
    // pilih tipe kamar pertama yang masih ada stoknya
    for (final r in widget.detail.rooms) {
      if (r.stock > 0) {
        _room = r;
        break;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    _promo.dispose();
    super.dispose();
  }

  List<DurationUnit> _unitsFor(RoomType r) =>
      DurationUnit.values.where((u) => u.priceOf(r) != null).toList();

  BookingPricing? get _pricing {
    final r = _room;
    if (r == null) return null;
    final price = _unit.priceOf(r) ?? r.priceMonthly;
    return BookingPricing(
      pricePerUnit: price,
      count: _count,
      deposit: r.deposit,
      discount: _discount,
    );
  }

  /// Harga berubah -> kode promo harus dicek ulang.
  void _resetPromo() {
    _promoCode = null;
    _discount = 0;
    _promoMsg = null;
    _promoOk = false;
  }

  void _pickRoom(RoomType r) {
    setState(() {
      _room = r;
      if (!_unitsFor(r).contains(_unit)) _unit = DurationUnit.bulanan;
      if (_count > _unit.maxCount) _count = _unit.maxCount;
      _resetPromo();
    });
  }

  void _pickUnit(DurationUnit u) {
    setState(() {
      _unit = u;
      if (_count > u.maxCount) _count = u.maxCount;
      _resetPromo();
    });
  }

  void _setCount(int v) {
    setState(() {
      _count = v;
      _resetPromo();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkin,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 120)),
      helpText: 'Tanggal masuk',
    );
    if (picked != null) setState(() => _checkin = picked);
  }

  String _errText(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _applyPromo() async {
    final code = _promo.text.trim();
    final p = _pricing;
    if (code.isEmpty || p == null) return;
    setState(() {
      _checkingPromo = true;
      _promoMsg = null;
    });
    try {
      final disc = await BookingStore.instance.validatePromo(
        code: code,
        kosId: widget.detail.kos.id,
        amount: p.subtotal,
      );
      if (!mounted) return;
      setState(() {
        _promoCode = code.toUpperCase();
        _discount = disc;
        _promoOk = true;
        _promoMsg = 'Kode dipakai, hemat ${rupiah(disc)}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _promoCode = null;
        _discount = 0;
        _promoOk = false;
        _promoMsg = _errText(e);
      });
    } finally {
      if (mounted) setState(() => _checkingPromo = false);
    }
  }

  void _removePromo() {
    setState(() {
      _promo.clear();
      _resetPromo();
    });
  }

  Future<void> _submit() async {
    final room = _room;
    if (room == null) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final note = _note.text.trim();
      final b = await BookingStore.instance.create(BookingDraft(
        kos: widget.detail.kos,
        room: room,
        checkin: _checkin,
        unit: _unit,
        count: _count,
        occupants: _occupants,
        tenantName: _name.text.trim(),
        tenantPhone: _phone.text.replaceAll(RegExp(r'[\s-]'), ''),
        note: note.isEmpty ? null : note,
        promoCode: _promoCode,
        discount: _discount,
      ));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 48),
          title: const Text('Pengajuan terkirim'),
          content: Text(
            'Kode pengajuan ${b.code}.\n\n'
            'Pemilik akan mengonfirmasi dalam 24 jam. Kamu belum perlu membayar '
            'apa pun sampai pengajuan disetujui.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Lihat di Kos Saya'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      context.go('/kos-saya?tab=${b.group.name}&t=${DateTime.now().millisecondsSinceEpoch}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_errText(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final kos = d.kos;
    final room = _room;
    final pricing = _pricing;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajukan Sewa')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            // ringkasan kos
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: KosCover(kos: kos, height: 64, width: 64),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TypeBadge(kos.type),
                          const SizedBox(height: 4),
                          Text(kos.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium),
                          Text(kos.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 1. tipe kamar
            DetailBlock(
              title: 'Pilih tipe kamar',
              child: Column(
                children: [
                  for (final r in d.rooms)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RoomOption(
                        room: r,
                        selected: _room?.id == r.id,
                        onTap: r.stock > 0 ? () => _pickRoom(r) : null,
                      ),
                    ),
                  if (room == null)
                    const Text('Semua tipe kamar sedang penuh.',
                        style: TextStyle(color: AppColors.danger)),
                ],
              ),
            ),

            if (room != null) ...[
              // 2. periode & durasi
              DetailBlock(
                title: 'Periode sewa',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final u in _unitsFor(room))
                          ChoiceChip(
                            label: Text('${u.label} · ${rupiah(u.priceOf(room)!)}'),
                            selected: _unit == u,
                            showCheckmark: false,
                            selectedColor: AppColors.marigoldSoft,
                            backgroundColor: Colors.white,
                            side: BorderSide(
                                color: _unit == u ? AppColors.ink : AppColors.line),
                            onSelected: (_) => _pickUnit(u),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _StepperRow(
                      label: 'Lama sewa',
                      value: '$_count ${_unit.noun}',
                      canDec: _count > 1,
                      canInc: _count < _unit.maxCount,
                      onDec: () => _setCount(_count - 1),
                      onInc: () => _setCount(_count + 1),
                    ),
                    const SizedBox(height: 12),
                    const Text('Tanggal masuk',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded,
                                size: 20, color: AppColors.ink),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_dateFmt.format(_checkin))),
                            const Icon(Icons.expand_more_rounded,
                                color: AppColors.textMuted),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sewa berakhir ${_dateFmt.format(_unit.endDate(_checkin, _count))}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    _StepperRow(
                      label: 'Jumlah penghuni',
                      value: '$_occupants orang',
                      canDec: _occupants > 1,
                      canInc: _occupants < 2,
                      onDec: () => setState(() => _occupants--),
                      onInc: () => setState(() => _occupants++),
                    ),
                  ],
                ),
              ),

              // 3. data penyewa
              DetailBlock(
                title: 'Data penyewa',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Nama lengkap'),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Isi nama lengkap'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Nomor HP / WhatsApp',
                        hintText: '08123456789',
                      ),
                      validator: (v) {
                        final s = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
                        return RegExp(r'^(\+62|62|0)8\d{7,11}$').hasMatch(s)
                            ? null
                            : 'Nomor HP tidak valid (mis. 08123456789)';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _note,
                      maxLines: 3,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Catatan untuk pemilik (opsional)',
                      ),
                    ),
                  ],
                ),
              ),

              // 4. promo
              DetailBlock(
                title: 'Kode promo',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promo,
                            enabled: _promoCode == null,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(hintText: 'Masukkan kode'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _checkingPromo
                              ? null
                              : (_promoCode == null ? _applyPromo : _removePromo),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(88, 52),
                          ),
                          child: _checkingPromo
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_promoCode == null ? 'Pakai' : 'Hapus'),
                        ),
                      ],
                    ),
                    if (_promoMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _promoMsg!,
                          style: TextStyle(
                            color: _promoOk ? AppColors.success : AppColors.danger,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 5. rincian biaya
              if (pricing != null)
                DetailBlock(
                  title: 'Rincian biaya',
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _PriceRow(
                            '${rupiah(pricing.pricePerUnit)} × ${pricing.count} ${_unit.noun}',
                            rupiah(pricing.subtotal),
                          ),
                          _PriceRow('Deposit (dikembalikan)', rupiah(pricing.deposit)),
                          _PriceRow('Biaya layanan', rupiah(BookingPricing.adminFee)),
                          if (pricing.discount > 0)
                            _PriceRow('Diskon promo', '-${rupiah(pricing.discount)}',
                                color: AppColors.success),
                          const Divider(height: 24),
                          _PriceRow('Total', rupiah(pricing.total), bold: true),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              const Text(
                'Ini estimasi; total final dihitung server. Kamu baru membayar '
                'setelah pemilik menyetujui pengajuan.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
              ),
            ],
          ],
        ),
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
                  const Text('Total estimasi',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text(pricing == null ? '-' : rupiah(pricing.total),
                      style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  style: AppTheme.ctaStyle,
                  onPressed: (room == null || _submitting) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: AppColors.ink),
                        )
                      : const Text('Ajukan Sewa'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu pilihan tipe kamar (kartu yang bisa dipilih).
class _RoomOption extends StatelessWidget {
  final RoomType room;
  final bool selected;
  final VoidCallback? onTap; // null = stok habis
  const _RoomOption({required this.room, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final full = room.stock == 0;
    return Opacity(
      opacity: full ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.marigoldSoft : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.ink : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (room.sizeLabel != null) '${room.sizeLabel} m',
                        full ? 'Penuh' : 'Sisa ${room.stock} kamar',
                      ].join(' · '),
                      style: TextStyle(
                        color: full ? AppColors.danger : AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${rupiah(room.priceMonthly)}/bln',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.ink : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Baris "label ... [-] nilai [+]".
class _StepperRow extends StatelessWidget {
  final String label;
  final String value;
  final bool canDec;
  final bool canInc;
  final VoidCallback onDec;
  final VoidCallback onInc;
  const _StepperRow({
    required this.label,
    required this.value,
    required this.canDec,
    required this.canInc,
    required this.onDec,
    required this.onInc,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        IconButton.outlined(
          onPressed: canDec ? onDec : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 96,
          child: Text(value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        IconButton.outlined(
          onPressed: canInc ? onInc : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _PriceRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 16 : 14,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
