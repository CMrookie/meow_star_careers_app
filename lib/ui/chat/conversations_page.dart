import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/realtime_chat.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'chat_page.dart';

/// 会话列表（消息 Tab）
class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  List<ConversationSummary>? _items;
  Object? _error;
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    final session = AppScope.read(context);
    _sub = session.realtime.stream.listen((event) {
      if (event.isNewMessage || event.isConversationRead) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    final session = AppScope.read(context);
    if (!quiet) {
      setState(() {
        _items = null;
        _error = null;
      });
    }
    try {
      final list = await session.chat.conversations(session.token!);
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      if (quiet) return;
      setState(() => _error = e);
    }
  }

  Future<void> _open(ConversationSummary c) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatPage(conversationId: c.id, peerName: c.peer.name),
    ));
    if (mounted) _load(quiet: true);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: const Text('消息')),
      body: _error != null && items == null
          ? ErrorView(error: _error!, onRetry: _load)
          : items == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
              : items.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 160),
                          EmptyView(
                            icon: Icons.chat_bubble_outline,
                            title: '暂无会话',
                            subtitle: '在职位详情或投递记录里点「聊聊」，即可与对方沟通',
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _tile(items[i]),
                      ),
                    ),
    );
  }

  Widget _tile(ConversationSummary c) {
    final last = c.lastMessage;
    final mine = last != null && last.senderId == AppScope.of(context).user?.id;
    final preview = last == null
        ? '你们开始聊天吧'
        : '${mine ? '我：' : ''}${last.content}';
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () => _open(c),
      child: Row(children: [
        Avatar(name: c.peer.name, size: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(c.peer.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textMain)),
              ),
              const SizedBox(width: 8),
              Text(
                last == null ? '' : relativeTime(last.createdAt),
                style: const TextStyle(fontSize: 11, color: Color(0xFFB8BCC4)),
              ),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(
                child: Text(preview,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.unreadCount > 0 ? textMain : textHint,
                      fontWeight: c.unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
                    )),
              ),
              if (c.unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: const BoxDecoration(color: accentRed, borderRadius: BorderRadius.all(Radius.circular(radiusPill))),
                  constraints: const BoxConstraints(minWidth: 18),
                  child: Text(
                    c.unreadCount > 99 ? '99+' : '${c.unreadCount}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.white, height: 1.4),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}
