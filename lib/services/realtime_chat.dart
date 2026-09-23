import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/app_config.dart';
import '../models/models.dart';

/// 实时事件（下行/回执/错误/面试信令）
class RealtimeEvent {
  final String type; // message | ack | error | pong | interview-signal | interview-updated
  final String? conversationId;
  final Message? message;
  final String? code;
  final String? errorMessage;
  final String? interviewId;
  final String? fromId;
  final Map<String, dynamic>? payload;
  final InterviewView? interview;
  final ApplicationView? application;

  RealtimeEvent({
    required this.type,
    this.conversationId,
    this.message,
    this.code,
    this.errorMessage,
    this.interviewId,
    this.fromId,
    this.payload,
    this.interview,
    this.application,
  });

  bool get isNewMessage => type == 'message' && message != null;
  bool get isInterviewSignal => type == 'interview-signal';
  bool get isInterviewUpdated => type == 'interview-updated';
  bool get isApplicationUpdated => type == 'application-updated' && application != null;
  bool get isConversationRead => type == 'conversation-read';
}

/// 全局 WebSocket 通道：登录后建立、断线自动重连、心跳保活。
/// 服务器下行事件经 [stream] 广播（REST 发送同样会收到自己消息的回声，
/// 业务方需按消息 id 去重）。
class RealtimeChat {
  final AppConfig config;
  final _eventController = StreamController<RealtimeEvent>.broadcast();
  Stream<RealtimeEvent> get stream => _eventController.stream;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _heartbeat;
  Timer? _retryTimer;
  bool _enabled = false;
  bool _connecting = false;
  String? _token;

  /// 连接状态（true=在线）
  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);

  RealtimeChat(this.config);

  void connect(String token) {
    _enabled = true;
    _token = token;
    _open();
  }

  void _open() {
    if (!_enabled || _connecting || _channel != null) return;
    _connecting = true;
    try {
      final url = '${config.wsBase}/ws?token=${Uri.encodeQueryComponent(_token!)}';
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _sub = _channel!.stream.listen(
        _onData,
        onError: (_) => _onClosed(),
        onDone: _onClosed,
        cancelOnError: true,
      );
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) => _sendPing());
    } catch (_) {
      _onClosed();
    }
  }

  void _sendPing() {
    _channel?.sink.add('{"type":"ping"}');
  }

  void _onData(dynamic raw) {
    if (raw is! String) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final type = map['type'] as String? ?? '';
      switch (type) {
        case 'pong':
          connected.value = true;
          _eventController.add(RealtimeEvent(type: type));
          break;
        case 'message':
          connected.value = true;
          _eventController.add(RealtimeEvent(
            type: type,
            conversationId: map['conversationId'] as String?,
            message: Message.fromJson(map['message'] as Map<String, dynamic>),
          ));
          break;
        case 'ack':
          connected.value = true;
          _eventController.add(RealtimeEvent(
            type: type,
            conversationId: map['conversationId'] as String?,
          ));
          break;
        case 'error':
          _eventController.add(RealtimeEvent(
            type: type,
            code: map['code'] as String?,
            errorMessage: map['message'] as String?,
          ));
          break;
        case 'interview-signal':
          _eventController.add(RealtimeEvent(
            type: type,
            interviewId: map['interviewId'] as String?,
            fromId: map['from']?.toString(),
            payload: map['payload'] is Map
                ? (map['payload'] as Map).map((k, v) => MapEntry('$k', v))
                : null,
          ));
          break;
        case 'application-updated':
          final rawApp = map['application'];
          _eventController.add(RealtimeEvent(
            type: type,
            application: rawApp is Map
                ? ApplicationView.fromJson(rawApp.map((k, v) => MapEntry('$k', v)))
                : null,
          ));
          break;
        case 'conversation-read':
          _eventController.add(RealtimeEvent(
            type: type,
            conversationId: map['conversationId'] as String?,
            fromId: map['userId']?.toString(),
          ));
          break;
        case 'interview-updated':
          final raw = map['interview'];
          _eventController.add(RealtimeEvent(
            type: type,
            interview: raw is Map
                ? InterviewView.fromJson(raw.map((k, v) => MapEntry('$k', v)))
                : null,
          ));
          break;
      }
    } catch (_) {
      // 忽略无法解析的帧
    }
  }

  void _onClosed() {
    connected.value = false;
    _teardownChannel();
    if (_enabled) {
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 3), _open);
    }
  }

  void _teardownChannel() {
    _heartbeat?.cancel();
    _heartbeat = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    _connecting = false;
  }

  /// 通过 WS 发送私聊消息；返回是否已投递到通道（失败请回退 REST）。
  bool sendMessage(String conversationId, String body) {
    final ch = _channel;
    if (ch == null) return false;
    ch.sink.add(jsonEncode({
      'type': 'send',
      'conversationId': conversationId,
      'body': body,
    }));
    return true;
  }

  /// 发送视频面试信令（offer/answer/ice/joined），由服务端转发给对端。
  bool sendSignal(String interviewId, Map<String, dynamic> payload) {
    debugPrint('[rt-signal] send $interviewId kind=${payload['kind']}');
    final ch = _channel;
    if (ch == null) return false;
    ch.sink.add(jsonEncode({
      'type': 'signal',
      'interviewId': interviewId,
      'payload': payload,
    }));
    return true;
  }

  void disconnect() {
    _enabled = false;
    _retryTimer?.cancel();
    _retryTimer = null;
    connected.value = false;
    _teardownChannel();
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
