import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/realtime_chat.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets.dart';

/// 一对一私聊页：REST 拉历史 + WS 实时收发（断线自动回退 REST）。
class ChatPage extends StatefulWidget {
  final String conversationId;
  final String peerName;
  const ChatPage({super.key, required this.conversationId, required this.peerName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messages = <Message>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<RealtimeEvent>? _sub;

  bool _loading = true;
  bool _loadingOlder = false;
  bool _hasMore = true;
  Object? _error;
  bool _sending = false;

  SessionController get _session => AppScope.read(context);

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _listen();
    _markRead();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _listen() {
    _sub = _session.realtime.stream.listen((event) {
      if (!mounted) return;
      if (event.type == 'error' && event.conversationId == widget.conversationId) {
        showToast(context, event.errorMessage ?? '消息发送失败', error: true);
        return;
      }
      if (event.isNewMessage && event.message!.conversationId == widget.conversationId) {
        _appendMessage(event.message!);
        _markRead();
      }
    });
  }

  void _appendMessage(Message m) {
    if (_messages.any((e) => e.id == m.id)) return;
    setState(() => _messages.add(m));
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _session.chat.messages(widget.conversationId, _session.token!);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _hasMore = list.length >= 50;
        _loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingOlder = true);
    try {
      final before = _messages.first.id;
      final older = await _session.chat.messages(
        widget.conversationId,
        _session.token!,
        limit: 50,
        before: before,
      );
      if (!mounted) return;
      setState(() {
        _messages.insertAll(0, older);
        _hasMore = older.length >= 50;
        _loadingOlder = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingOlder = false);
    }
  }

  Future<void> _markRead() async {
    try {
      await _session.chat.markRead(widget.conversationId, _session.token!);
    } catch (_) {
      // 忽略标记失败
    }
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    _input.clear();
    final sentViaWs = _session.realtime.connected.value &&
        _session.realtime.sendMessage(widget.conversationId, body);
    if (!sentViaWs) {
      // 离线回退 REST（若 WS 在线也会收到 echo，按 id 去重）
      try {
        final m = await _session.chat.send(widget.conversationId, body, _session.token!);
        if (mounted) _appendMessage(m);
      } catch (e) {
        if (mounted) {
          _input.text = body;
          showErrorSnack(context, e);
        }
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        title: Column(children: [
          Text(widget.peerName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ValueListenableBuilder<bool>(
            valueListenable: _session.realtime.connected,
            builder: (_, connected, _) => Text(
              connected ? '实时连接中' : '已离线（消息将通过服务器中转）',
              style: const TextStyle(fontSize: 10, color: textHint, fontWeight: FontWeight.w400),
            ),
          ),
        ]),
        actions: [
          IconButton(tooltip: '刷新', icon: const Icon(Icons.refresh, size: 20), onPressed: _loadInitial),
        ],
      ),
      body: Column(children: [
        Expanded(child: _buildList()),
        _buildInput(),
      ]),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    if (_error != null && _messages.isEmpty) {
      return ErrorView(error: _error!, onRetry: _loadInitial);
    }
    if (_messages.isEmpty) {
      return const EmptyView(icon: Icons.forum_outlined, title: '打个招呼开始聊天吧', subtitle: '消息通过 WebSocket 实时送达');
    }
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _messages.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _messages.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: _loadingOlder
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : GestureDetector(
                      onTap: _loadOlder,
                      child: const Text('加载更早消息', style: TextStyle(fontSize: 12, color: Color(0xFF8F959E))),
                    ),
            ),
          );
        }
        final msg = _messages[_messages.length - 1 - i];
        final showTime = i == _messages.length - 1 ||
            _messages[_messages.length - 2 - i].createdAt.difference(msg.createdAt).inMinutes > 10;
        return _MessageBubble(
          message: msg,
          mine: msg.senderId == _session.user?.id,
          showTime: showTime,
        );
      },
    );
  }

  Widget _buildInput() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: cardLine))),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 110),
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: '输入消息…',
                    isDense: true,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: brandColor, borderRadius: BorderRadius.circular(radiusPill)),
              child: IconButton(
                tooltip: '发送',
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool mine;
  final bool showTime;
  const _MessageBubble({required this.message, required this.mine, required this.showTime});

  @override
  Widget build(BuildContext context) {
    final time = fullTime(message.createdAt);
    return Column(
      crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showTime)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Center(child: Text(time, style: const TextStyle(fontSize: 10, color: Color(0xFFB8BCC4)))),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Row(
            mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mine) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(color: Color(0xFFDDE2EC), shape: BoxShape.circle),
                  child: const Icon(Icons.person, size: 20, color: Color(0xFF8F959E)),
                ),
                const SizedBox(width: 8),
              ] else
                const SizedBox(width: 44),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: mine ? brandColor : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(radiusControl + 2),
                      topRight: const Radius.circular(radiusControl + 2),
                      bottomLeft: Radius.circular(mine ? 6 : radiusControl + 2),
                      bottomRight: Radius.circular(mine ? radiusControl + 2 : 6),
                    ),
                    boxShadow: mine ? null : softShadow,
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(fontSize: 14, height: 1.4, color: mine ? Colors.white : textMain),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
