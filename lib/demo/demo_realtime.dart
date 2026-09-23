import 'dart:async';

import '../models/models.dart';
import '../services/realtime_chat.dart';
import 'demo_store.dart';

/// 演示模式的实时通道：不建真实 WebSocket。
/// - `connect` 直接把状态置为在线；
/// - `sendMessage` 把消息写入演示仓库，并模拟「服务器回声」+ 对端演示账号自动回复。
class DemoRealtime extends RealtimeChat {
  final DemoBackend backend;
  final _events = StreamController<RealtimeEvent>.broadcast();

  @override
  Stream<RealtimeEvent> get stream => _events.stream;

  String? _token;

  DemoRealtime(super.config, this.backend);

  @override
  void connect(String token) {
    _token = token;
    connected.value = true;
  }

  @override
  bool sendMessage(String conversationId, String body) {
    final meId = backend.ownerId(_token);
    if (meId == null || !backend.hasConversation(conversationId)) return false;
    final senderId = meId;

    // 回声：模拟服务器把这条消息推回给发送方
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      final msg = backend.persistMessage(conversationId, senderId, body);
      _events.add(RealtimeEvent(
        type: 'message',
        conversationId: conversationId,
        message: Message.fromJson(msg),
      ));
    });

    // 对端若为演示账号，稍后自动回复一条
    final peerId = backend.peerOf(conversationId, senderId);
    final reply = peerId == null ? null : backend.botReplyFor(conversationId, senderId);
    if (peerId != null && reply != null) {
      final targetPeer = peerId;
      final canned = reply;
      Future<void>.delayed(const Duration(milliseconds: 1300), () {
        final msg = backend.persistMessage(conversationId, targetPeer, canned);
        _events.add(RealtimeEvent(
          type: 'message',
          conversationId: conversationId,
          message: Message.fromJson(msg),
        ));
      });
    }
    return true;
  }

  @override
  void disconnect() {
    connected.value = false;
  }

  @override
  void dispose() {
    disconnect();
    _events.close();
    super.dispose();
  }
}
