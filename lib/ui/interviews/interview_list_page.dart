import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/realtime_chat.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'interview_room_page.dart';

Color interviewStatusColor(String status) {
  switch (status) {
    case 'invited':
      return brandColor;
    case 'in_progress':
      return accentGreen;
    case 'finished':
      return textHint;
    case 'cancelled':
      return const Color(0xFFE5484D);
    default:
      return textHint;
  }
}

/// 演示模式不提供真实视频面试
bool ensureNotDemo(BuildContext context) {
  if (AppScope.of(context).isDemo) {
    showToast(context, '演示模式不含视频面试，请连接真实后端体验', error: true);
    return false;
  }
  return true;
}

/// 我的线上面试（求职者/招聘者共用）
class InterviewsPage extends StatefulWidget {
  const InterviewsPage({super.key});

  @override
  State<InterviewsPage> createState() => _InterviewsPageState();
}

class _InterviewsPageState extends State<InterviewsPage> {
  List<InterviewView>? _items;
  Object? _error;
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AppScope.read(context).realtime.stream.listen((e) {
      if (mounted &&
          (e.isInterviewUpdated || e.isInterviewSignal || e.isApplicationUpdated)) {
        _load();
      }
    });
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final session = AppScope.read(context);
    if (_items == null) {
      setState(() {
        _items = null;
        _error = null;
      });
    }
    try {
      final list = await session.api.myInterviews(session.token!);
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _open(InterviewView iv) async {
    if (!ensureNotDemo(context)) return;
    if (!iv.canJoin && iv.status != 'in_progress') {
      if (iv.status == 'invited') {
        showToast(context, '未到预约时间，暂不能进入');
      }
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => InterviewRoomPage(interviewId: iv.id, initial: iv),
    ));
    if (mounted) _load();
  }

  Future<void> _cancel(InterviewView iv) async {
    final ok = await confirmDialog(
      context,
      title: '取消视频面试',
      message: '确定取消这场面试吗？',
      confirmText: '取消面试',
    );
    if (!ok || !mounted) return;
    final session = AppScope.of(context);
    try {
      await runAction(context, () async {
        await session.api.cancelInterview(iv.id, session.token!);
      });
      if (!mounted) return;
      showToast(context, '面试已取消');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final me = AppScope.of(context).user;
    final items = _items;
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: const Text('视频面试')),
      body: _error != null && items == null
          ? ErrorView(error: _error!, onRetry: _load)
          : items == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
              : items.isEmpty
                  ? const EmptyView(
                      icon: Icons.videocam_outlined,
                      title: '暂无视频面试',
                      subtitle: '招聘者可对投递发起即时或预约的视频面试',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, i) =>
                            _card(context, me, items[i]),
                      ),
                    ),
    );
  }

  Widget _card(BuildContext context, User? me, InterviewView iv) {
    final peer = iv.peerNameOf(me?.id ?? '');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(iv),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(iv.jobTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: interviewStatusColor(iv.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(radiusPill),
                  ),
                  child: Text(
                    interviewStatusLabel(iv.status),
                    style: TextStyle(fontSize: 11, color: interviewStatusColor(iv.status)),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text('${iv.companyName} · 对方：$peer',
                  style: const TextStyle(fontSize: 12, color: textHint)),
              const SizedBox(height: 4),
              Text(iv.modeText, style: const TextStyle(fontSize: 12, color: textSub)),
              if (!iv.isCancelledOrFinished) ...[
                const SizedBox(height: 10),
                Row(children: [
                  if (iv.status == 'invited')
                    TextButton(
                      onPressed: () => _cancel(iv),
                      child: const Text('取消'),
                    ),
                  const Spacer(),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                    onPressed: () => _open(iv),
                    icon: const Icon(Icons.videocam_outlined, size: 18),
                    label: Text(iv.status == 'invited' ? '进入面试' : '继续'),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
