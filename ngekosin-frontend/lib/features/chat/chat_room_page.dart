import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/auth/auth_state.dart';
import '../../core/config/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../../data/chat_repository.dart';
import '../../models/chat.dart';
import '../../shared/widgets/empty_state.dart';

/// Ruang chat. Pesan baru diambil dengan polling
/// GET /chat/rooms/:id/messages?after_id= tiap [_pollEvery].
class ChatRoomPage extends StatefulWidget {
  final int roomId;
  final ChatRoom? room; // dikirim lewat `extra`; null saat dibuka langsung
  const ChatRoomPage({super.key, required this.roomId, this.room});
  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  static const _pollEvery = Duration(seconds: 3);

  final _repo = ChatRepository.instance;
  final _input = TextEditingController();
  final _picker = ImagePicker();

  final List<ChatMessage> _messages = []; // urut lama -> baru
  Timer? _timer;
  bool _loading = true;
  bool _failed = false;
  bool _polling = false;
  bool _sending = false;
  XFile? _pending; // gambar yang dipilih, belum terkirim

  int get _myId => AuthState.instance.user?.id ?? 0;
  ChatRoom? get _room => widget.room ?? _repo.cached(widget.roomId);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final list = await _repo.messages(widget.roomId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _loading = false;
      });
      _timer?.cancel();
      _timer = Timer.periodic(_pollEvery, (_) => _poll());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _poll() async {
    if (_polling || _sending || !mounted) return;
    _polling = true;
    try {
      final after = _messages.isEmpty ? null : _messages.last.id;
      final fresh = await _repo.messages(widget.roomId, afterId: after);
      if (!mounted || fresh.isEmpty) return;
      setState(() => _addUnique(fresh));
    } catch (_) {
      // gagal sesaat (sinyal hilang): coba lagi di putaran berikutnya
    } finally {
      _polling = false;
    }
  }

  void _addUnique(Iterable<ChatMessage> items) {
    final ids = _messages.map((m) => m.id).toSet();
    for (final m in items) {
      if (ids.add(m.id)) _messages.add(m);
    }
    _messages.sort((a, b) => a.id.compareTo(b.id));
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final f = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (f != null && mounted) setState(() => _pending = f);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tidak bisa membuka galeri/kamera')));
    }
  }

  void _showPickerSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.ink),
              title: const Text('Pilih dari galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AppColors.ink),
              title: const Text('Ambil foto'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (_sending || (text.isEmpty && _pending == null)) return;
    setState(() => _sending = true);
    try {
      final msg = await _repo.send(widget.roomId, text: text, image: _pending);
      if (!mounted) return;
      setState(() {
        _addUnique([msg]);
        _input.clear();
        _pending = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: room == null ? null : () => context.push('/kos/${room.kosId}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(room?.otherName ?? 'Chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
              if (room != null)
                Text(room.kosName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w400)),
            ],
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages()),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.ink));
    }
    if (_failed) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Gagal memuat pesan',
        message: 'Periksa koneksi internet kamu lalu coba lagi.',
        actionLabel: 'Coba lagi',
        onAction: _loadAll,
      );
    }
    if (_messages.isEmpty) {
      return const EmptyState(
        icon: Icons.waving_hand_rounded,
        title: 'Mulai percakapan',
        message: 'Tanyakan ketersediaan kamar, harga, atau jadwal survei ke pemilik kos.',
      );
    }
    // reverse: pesan terbaru menempel di bawah & otomatis terlihat
    final n = _messages.length;
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: n,
      itemBuilder: (_, i) {
        final m = _messages[n - 1 - i];
        final older = n - 2 - i >= 0 ? _messages[n - 2 - i] : null;
        final newDay = older == null || !_sameDay(older.createdAt, m.createdAt);
        return Column(
          children: [
            if (newDay) _DayChip(date: m.createdAt),
            _Bubble(message: m, mine: m.senderId == _myId),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildComposer() {
    return Material(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_pending != null) _PendingPreview(
                file: _pending!,
                onRemove: _sending ? null : () => setState(() => _pending = null),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Kirim gambar',
                    onPressed: _sending ? null : _showPickerSheet,
                    icon: const Icon(Icons.image_rounded, color: AppColors.ink),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Tulis pesan…',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: IconButton.filled(
                      onPressed: _sending ? null : _send,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.marigold,
                        foregroundColor: AppColors.ink,
                      ),
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime date;
  const _DayChip({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(date.year, date.month, date.day)).inDays;
    final label = diff == 0
        ? 'Hari ini'
        : diff == 1
            ? 'Kemarin'
            : DateFormat('d MMMM y', 'id_ID').format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.line.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final m = message;
    final fg = mine ? Colors.white : AppColors.textPrimary;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: mine ? AppColors.ink : Colors.white,
            border: mine ? null : Border.all(color: AppColors.line),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.hasImage)
                GestureDetector(
                  onTap: () => _openImage(context, m),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: _image(m, BoxFit.cover),
                    ),
                  ),
                ),
              if (m.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(m.body, style: TextStyle(color: fg, height: 1.35)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                child: Text(
                  DateFormat('HH:mm').format(m.createdAt),
                  style: TextStyle(
                    color: mine ? Colors.white70 : AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _image(ChatMessage m, BoxFit fit) {
    if (m.localImage != null) return Image.memory(m.localImage!, fit: fit);
    final url = ApiConfig.fileUrl(m.imageUrl);
    return Image.network(
      url!,
      fit: fit,
      loadingBuilder: (_, child, p) => p == null
          ? child
          : const SizedBox(
              height: 140,
              width: 180,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
      errorBuilder: (_, __, ___) => const SizedBox(
        height: 100,
        width: 180,
        child: Center(child: Icon(Icons.broken_image_rounded, color: AppColors.textMuted)),
      ),
    );
  }

  static void _openImage(BuildContext context, ChatMessage m) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(child: Center(child: _image(m, BoxFit.contain))),
            ),
            SafeArea(
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pratinjau gambar yang akan dikirim.
class _PendingPreview extends StatefulWidget {
  final XFile file;
  final VoidCallback? onRemove;
  const _PendingPreview({required this.file, required this.onRemove});

  @override
  State<_PendingPreview> createState() => _PendingPreviewState();
}

class _PendingPreviewState extends State<_PendingPreview> {
  late final Future<Uint8List> _bytes = widget.file.readAsBytes();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FutureBuilder<Uint8List>(
                future: _bytes,
                builder: (_, snap) => Container(
                  width: 84,
                  height: 84,
                  color: AppColors.line,
                  child: snap.hasData
                      ? Image.memory(snap.data!, fit: BoxFit.cover)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: widget.onRemove,
                child: const CircleAvatar(
                  radius: 11,
                  backgroundColor: AppColors.ink,
                  child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
