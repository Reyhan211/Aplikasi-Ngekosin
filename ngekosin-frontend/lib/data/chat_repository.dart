import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../core/auth/auth_state.dart';
import '../core/config/api_config.dart';
import '../models/chat.dart';
import 'kos_repository.dart';

/// Akses data chat. Saat ApiConfig.useMock = true semuanya disimpan di memori
/// dan pemilik kos membalas otomatis, jadi UI bisa dites tanpa backend.
///
/// API:
///   GET  /chat/rooms                         daftar percakapan
///   POST /chat/rooms        {kos_id}         buat / ambil room untuk kos itu
///   GET  /chat/rooms/:id/messages?after_id=  pesan (polling)
///   POST /chat/rooms/:id/messages            multipart: body, image
class ChatRepository extends ChangeNotifier {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  /// id pengirim pesan pemilik pada mode mock.
  static const _mockOwnerId = 100;

  // cache room yang pernah dimuat, supaya halaman room bisa tampil header-nya
  final Map<int, ChatRoom> _known = {};
  ChatRoom? cached(int id) => _known[id];

  // ---- state mock ----
  final List<ChatRoom> _mockRooms = [];
  final Map<int, List<ChatMessage>> _mockMsgs = {};
  int _nextRoomId = 1;
  int _nextMsgId = 1;
  bool _seeded = false;

  static const _autoReplies = [
    'Halo, terima kasih sudah menghubungi. Ada yang bisa saya bantu?',
    'Kamarnya masih tersedia ya, silakan datang survei kapan saja.',
    'Untuk harga sudah termasuk listrik dan wifi.',
    'Boleh, nanti saya kirim fotonya ya.',
    'Baik, ditunggu kedatangannya 🙂',
  ];
  int _replyIdx = 0;

  Map<String, String> get _headers => {
        if (AuthState.instance.token != null)
          'Authorization': 'Bearer ${AuthState.instance.token}',
      };

  int get _myId => AuthState.instance.user?.id ?? 0;

  Never _fail(http.Response res) {
    String msg = 'Terjadi kesalahan (${res.statusCode})';
    try {
      msg = (jsonDecode(res.body) as Map<String, dynamic>)['message']?.toString() ?? msg;
    } catch (_) {}
    throw Exception(msg);
  }

  void _seed() {
    if (_seeded) return;
    _seeded = true;
    final now = DateTime.now();
    final room = ChatRoom(
      id: _nextRoomId++,
      kosId: 7,
      kosName: 'Kos Mawar Putri',
      otherName: 'Bu Sari',
      lastMessage: 'Kamarnya masih ada ya, silakan survei dulu 🙂',
      lastMessageAt: now.subtract(const Duration(hours: 2)),
      unread: 1,
    );
    _mockRooms.add(room);
    _mockMsgs[room.id] = [
      ChatMessage(
        id: _nextMsgId++,
        roomId: room.id,
        senderId: _myId,
        body: 'Halo Bu, kamar yang tipe standar masih kosong?',
        createdAt: now.subtract(const Duration(hours: 2, minutes: 5)),
      ),
      ChatMessage(
        id: _nextMsgId++,
        roomId: room.id,
        senderId: _mockOwnerId,
        body: room.lastMessage!,
        createdAt: room.lastMessageAt!,
      ),
    ];
  }

  void _touchRoom(int roomId, String preview, DateTime at, {int? unread}) {
    final i = _mockRooms.indexWhere((r) => r.id == roomId);
    if (i == -1) return;
    _mockRooms[i] = _mockRooms[i].copyWith(
      lastMessage: preview,
      lastMessageAt: at,
      unread: unread,
    );
    _known[roomId] = _mockRooms[i];
  }

  /// GET /chat/rooms
  Future<List<ChatRoom>> rooms() async {
    if (ApiConfig.useMock) {
      _seed();
      await Future.delayed(const Duration(milliseconds: 300));
      final list = [..._mockRooms]..sort((a, b) => (b.lastMessageAt ?? DateTime(2000))
          .compareTo(a.lastMessageAt ?? DateTime(2000)));
      for (final r in list) {
        _known[r.id] = r;
      }
      return list;
    }
    final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/chat/rooms'), headers: _headers);
    if (res.statusCode != 200) _fail(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (body['data'] as List)
        .map((e) => ChatRoom.fromJson(e as Map<String, dynamic>))
        .toList();
    for (final r in list) {
      _known[r.id] = r;
    }
    return list;
  }

  /// POST /chat/rooms {kos_id}. Kalau room untuk kos ini sudah ada, server
  /// mengembalikan room yang lama (bukan membuat duplikat).
  Future<ChatRoom> openRoom(int kosId) async {
    if (ApiConfig.useMock) {
      _seed();
      await Future.delayed(const Duration(milliseconds: 350));
      final existing = _mockRooms.where((r) => r.kosId == kosId).firstOrNull;
      if (existing != null) return existing;
      final kos = await KosRepository.instance.getById(kosId);
      final room = ChatRoom(
        id: _nextRoomId++,
        kosId: kosId,
        kosName: kos?.name ?? 'Kos',
        kosCoverUrl: kos?.coverUrl,
        otherName: 'Bu Sari',
      );
      _mockRooms.add(room);
      _mockMsgs[room.id] = [];
      _known[room.id] = room;
      return room;
    }
    final res = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/chat/rooms'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'kos_id': kosId}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) _fail(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final room = ChatRoom.fromJson(body['data'] as Map<String, dynamic>);
    _known[room.id] = room;
    return room;
  }

  /// GET /chat/rooms/:id/messages?after_id=
  /// Tanpa [afterId] = semua pesan; dengan [afterId] = hanya yang lebih baru.
  Future<List<ChatMessage>> messages(int roomId, {int? afterId}) async {
    if (ApiConfig.useMock) {
      _seed();
      final all = _mockMsgs[roomId] ?? const <ChatMessage>[];
      final res = afterId == null ? [...all] : all.where((m) => m.id > afterId).toList();
      if (res.isNotEmpty) {
        final i = _mockRooms.indexWhere((r) => r.id == roomId);
        if (i != -1 && _mockRooms[i].unread > 0) {
          _mockRooms[i] = _mockRooms[i].copyWith(unread: 0);
          _known[roomId] = _mockRooms[i];
        }
      }
      return res;
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/chat/rooms/$roomId/messages').replace(
      queryParameters: {if (afterId != null) 'after_id': '$afterId'},
    );
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) _fail(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List)
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /chat/rooms/:id/messages (multipart/form-data: body, image)
  Future<ChatMessage> send(int roomId, {String text = '', XFile? image}) async {
    final body = text.trim();
    if (body.isEmpty && image == null) throw Exception('Pesan kosong');

    if (ApiConfig.useMock) {
      _seed();
      await Future.delayed(const Duration(milliseconds: 250));
      final bytes = image == null ? null : await image.readAsBytes();
      final now = DateTime.now();
      final msg = ChatMessage(
        id: _nextMsgId++,
        roomId: roomId,
        senderId: _myId,
        body: body,
        localImage: bytes,
        createdAt: now,
      );
      (_mockMsgs[roomId] ??= []).add(msg);
      _touchRoom(roomId, body.isEmpty ? '📷 Foto' : body, now, unread: 0);
      _scheduleReply(roomId);
      return msg;
    }

    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/chat/rooms/$roomId/messages'),
    )..headers.addAll(_headers);
    if (body.isNotEmpty) req.fields['body'] = body;
    if (image != null) {
      // fromBytes (bukan fromPath) supaya juga jalan di Flutter Web
      req.files.add(http.MultipartFile.fromBytes(
        'image',
        await image.readAsBytes(),
        filename: image.name,
      ));
    }
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200 && res.statusCode != 201) _fail(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return ChatMessage.fromJson(json['data'] as Map<String, dynamic>);
  }

  /// Mock: pemilik membalas 2 detik kemudian, ikut terambil oleh polling.
  void _scheduleReply(int roomId) {
    Future.delayed(const Duration(seconds: 2), () {
      final text = _autoReplies[_replyIdx++ % _autoReplies.length];
      final now = DateTime.now();
      (_mockMsgs[roomId] ??= []).add(ChatMessage(
        id: _nextMsgId++,
        roomId: roomId,
        senderId: _mockOwnerId,
        body: text,
        createdAt: now,
      ));
      _touchRoom(roomId, text, now);
      notifyListeners();
    });
  }
}
