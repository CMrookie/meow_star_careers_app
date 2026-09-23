import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../services/realtime_chat.dart';
import '../models/models.dart';
import '../state/session.dart';
import 'chat/chat_page.dart';
import 'interviews/interview_list_page.dart';
import 'interviews/interview_room_page.dart';
import 'jobs/job_detail_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// 投递详情：求职者视角（查看进度/撤回）与招聘者视角（推进状态/联系候选人）共用。
class ApplicationDetailPage extends StatefulWidget {
  final String applicationId;
  const ApplicationDetailPage({super.key, required this.applicationId});

  @override
  State<ApplicationDetailPage> createState() => _ApplicationDetailPageState();
}

class _ApplicationDetailPageState extends State<ApplicationDetailPage> {
  ApplicationView? _app;
  List<InterviewView> _interviews = const [];
  Object? _error;
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AppScope.read(context).realtime.stream.listen(_onPush);
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// 对端操作投递/面试时实时同步
  void _onPush(RealtimeEvent e) {
    if (!mounted) return;
    if (e.isApplicationUpdated && e.application?.id == widget.applicationId) {
      final prev = _app?.status;
      setState(() => _app = e.application);
      if (prev != null && prev != e.application!.status) {
        showToast(context, '投递状态已更新为「${applicationStatusLabel(e.application!.status)}」');
      }
      _refreshInterviews();
      return;
    }
    if (e.isInterviewUpdated || e.isInterviewSignal) {
      _refreshInterviews();
    }
  }

  Future<void> _refreshInterviews() async {
    final session = AppScope.read(context);
    try {
      final all = await session.api.myInterviews(session.token!);
      if (!mounted) return;
      setState(() {
        _interviews = all.where((i) => i.applicationId == widget.applicationId).toList();
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    final session = AppScope.read(context);
    setState(() {
      _error = null;
      _app = null;
    });
    try {
      final app = await session.api.getApplication(widget.applicationId, session.token!);
      // 该投递的视频面试（参与双方可见；无则空）
      List<InterviewView> interviews = const [];
      try {
        final all = await session.api.myInterviews(session.token!);
        interviews = all.where((i) => i.applicationId == widget.applicationId).toList();
      } catch (_) {
        // 忽略：面试信息不是必填
      }
      if (!mounted) return;
      setState(() {
        _app = app;
        _interviews = interviews;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _setStatus(String status) async {
    final session = AppScope.of(context);
    final app = _app;
    if (app == null || app.status == status) return;
    final label = applicationStatusLabel(status);
    final ok = await confirmDialog(context, title: '将投递状态置为「$label」？');
    if (!ok || !mounted) return;
    try {
      final updated = await session.api.setApplicationStatus(widget.applicationId, status, session.token!);
      if (!mounted) return;
      setState(() => _app = updated);
      showToast(context, '状态已更新为「${applicationStatusLabel(status)}」');
    } catch (e) {
      showErrorSnack(context, e);
    }
  }

  Future<void> _withdraw() async {
    final ok = await confirmDialog(
      context,
      title: '撤回投递',
      message: '撤回后将无法恢复，确定撤回对该职位的投递吗？',
      confirmText: '撤回',
    );
    if (!ok || !mounted) return;
    final session = AppScope.of(context);
    try {
      final updated = await session.api.setApplicationStatus(widget.applicationId, 'withdrawn', session.token!);
      if (!mounted) return;
      setState(() => _app = updated);
      showToast(context, '已撤回投递');
    } catch (e) {
      showErrorSnack(context, e);
    }
  }

  Future<void> _openChatWith(String peerUserId, String? fallbackName) async {
    final session = AppScope.of(context);
    try {
      final conv = await session.chat.start(peerUserId, session.token!);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatPage(conversationId: conv.id, peerName: conv.peer.name),
      ));
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  /// 求职者联系该职位的招聘者（createdBy）
  Future<void> _contactHrOfJob(ApplicationView app) async {
    final session = AppScope.of(context);
    try {
      final job = await session.api.getJob(app.jobId, session.token!);
      if (job.createdBy == null) {
        if (!mounted) return;
        showToast(context, '该职位暂未开放联系入口');
        return;
      }
      await _openChatWith(job.createdBy!, null);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final app = _app;
    final isRecruiter = session.user?.isRecruiter ?? false;
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: const Text('投递详情')),
      body: _error != null
          ? ErrorView(error: _error!, onRetry: _load)
          : app == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
              : _body(app),
      bottomNavigationBar: app == null
          ? null
          : isRecruiter
              ? _recruiterBar(app)
              : _seekerBar(app),
    );
  }

  Widget _body(ApplicationView app) {
    final session = AppScope.of(context);
    final isRecruiter = session.user?.isRecruiter ?? false;
    final statusIdx = applicationStatuses.indexOf(app.status);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SectionCard(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('投递进度', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              StatusTag(app.status),
            ]),
            const SizedBox(height: 14),
            _progressLine(statusIdx),
            const SizedBox(height: 8),
            Text('投递于 ${fullTime(app.createdAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFFB8BCC4))),
            if (app.updatedAt != app.createdAt)
              Text('最近更新 ${fullTime(app.updatedAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFFB8BCC4))),
          ]),
        ),
        SectionCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('职位信息'),
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => JobDetailPage(jobId: app.jobId)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(app.jobTitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(app.companyName, style: const TextStyle(fontSize: 12, color: textHint)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFFC0C4CC)),
                ]),
              ),
            ),
          ]),
        ),
        if (app.coverLetter != null && app.coverLetter!.isNotEmpty)
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('求职信 / 附言'),
              Text(app.coverLetter!, style: const TextStyle(fontSize: 14, color: Color(0xFF3A3F45), height: 1.6)),
            ]),
          ),
        if (isRecruiter)
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('候选人'),
              Row(children: [
                Avatar(name: app.seekerName, size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(app.seekerName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(app.seekerContact, style: const TextStyle(fontSize: 13, color: textSub)),
                    if (app.resumeId != null)
                      const Text('已附简历', style: TextStyle(fontSize: 12, color: accentGreen)),
                  ]),
                ),
              ]),
            ]),
          ),
        _interviewSection(app),
      ],
    );
  }

  /// 视频面试区块：展示本投递的面试，招聘者无面试时可发起
  Widget _interviewSection(ApplicationView app) {
    final session = AppScope.of(context);
    final isRecruiter = session.user?.isRecruiter ?? false;
    final terminal = app.status == 'withdrawn' || app.status == 'rejected';
    final iv = _interviews.isEmpty ? null : _interviews.first;
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle('视频面试'),
        if (iv == null)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              isRecruiter
                  ? '可对候选人发起即时或预约的线上面试，双方凭 WS 实时信令进入房间。'
                  : '招聘者发起视频面试后，可从这里直接进入。',
              style: const TextStyle(fontSize: 13, color: textSub, height: 1.5),
            ),
            if (isRecruiter && !terminal) ...[
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () => _createInterview(app),
                icon: const Icon(Icons.video_call_outlined, size: 18),
                label: const Text('发起视频面试'),
              ),
            ],
          ])
        else
          _interviewTile(app, iv),
      ]),
    );
  }

  Widget _interviewTile(ApplicationView app, InterviewView iv) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
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
        const Spacer(),
        Text(iv.modeText, style: const TextStyle(fontSize: 12, color: textHint)),
      ]),
      const SizedBox(height: 10),
      if (iv.isCancelledOrFinished)
        Text('本场面试${iv.status == 'finished' ? '已结束' : '已取消'}',
            style: const TextStyle(fontSize: 13, color: textSub))
      else
        Row(children: [
          if (iv.status == 'invited')
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 42), foregroundColor: const Color(0xFFE5484D),
                  side: const BorderSide(color: Color(0xFFE5484D))),
              onPressed: () => _cancelInterview(iv),
              child: const Text('取消面试'),
            ),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
            onPressed: () => _enterInterview(iv),
            icon: const Icon(Icons.videocam_outlined, size: 18),
            label: Text(iv.status == 'invited' ? '进入面试' : '进入房间'),
          ),
        ]),
    ]);
  }

  Future<void> _enterInterview(InterviewView iv) async {
    if (!ensureNotDemo(context)) return;
    if (iv.status == 'invited' && !iv.canJoin) {
      showToast(context, '未到预约时间，暂不能进入');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => InterviewRoomPage(interviewId: iv.id, initial: iv),
    ));
    if (mounted) _load();
  }

  Future<void> _cancelInterview(InterviewView iv) async {
    final ok = await confirmDialog(context, title: '取消面试', message: '确定取消这场视频面试吗？', confirmText: '取消');
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

  Future<void> _createInterview(ApplicationView app) async {
    if (!ensureNotDemo(context)) return;
    final session = AppScope.of(context);
    bool instant = true;
    DateTime? scheduled;
    final scheduledCtl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          Future<void> pickDateTime() async {
            final now = DateTime.now();
            final day = await showDatePicker(
              context: ctx,
              initialDate: now.add(const Duration(days: 1)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 90)),
            );
            if (day == null) return;
            if (!ctx.mounted) return;
            final time = await showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 10, minute: 0));
            if (time == null) return;
            scheduled = DateTime(day.year, day.month, day.day, time.hour, time.minute);
            scheduledCtl.text =
                '${scheduled!.year}-${scheduled!.month.toString().padLeft(2, '0')}-${scheduled!.day.toString().padLeft(2, '0')} '
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
            setSheet(() {});
          }

          Widget radio(String label, String desc, bool selected, VoidCallback onTap) {
            return InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: selected ? brandColor : const Color(0xFFC0C4CC), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Text(desc, style: const TextStyle(fontSize: 11, color: textHint)),
                    ]),
                  ),
                ]),
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('发起视频面试',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text('对「${app.seekerName}」的投递（${app.jobTitle}）',
                        style: const TextStyle(fontSize: 12, color: textHint)),
                    const SizedBox(height: 8),
                    radio('即时面试', '双方在线即可立即进入房间', instant,
                        () => setSheet(() {
                              instant = true;
                              scheduled = null;
                              scheduledCtl.clear();
                            })),
                    radio('预约时间', '到点后可进入房间（双方将收到面试提醒）', !instant, () => setSheet(() => instant = false)),
                    if (!instant) ...[
                      InkWell(
                        onTap: pickDateTime,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: '预约时间',
                            prefixIcon: const Icon(Icons.schedule, size: 18),
                          ),
                          child: Text(scheduledCtl.text.isEmpty ? '选择日期与时间' : scheduledCtl.text,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: scheduledCtl.text.isEmpty ? textHint : textMain)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        if (!instant && scheduled == null) {
                          showToast(ctx, '请先选择预约时间');
                          return;
                        }
                        try {
                          await runAction(ctx, () async {
                            await session.api.createInterview(
                              applicationId: widget.applicationId,
                              scheduledAt: instant ? null : scheduled,
                              token: session.token!,
                            );
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            showToast(context, '已发起视频面试');
                            _load();
                          }
                        } catch (_) {
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      },
                      child: const Text('确认发起'),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _progressLine(int idx) {
    const steps = ['投递', '查看', '面试', '录用'];
    final colors = [
      statusColor('pending'),
      statusColor('viewed'),
      statusColor('interviewing'),
      statusColor('offered'),
    ];
    int reached = 0;
    if (idx <= 0) reached = 1; // pending -> 投递已点亮
    if (idx == 1) reached = 2;
    if (idx == 2) reached = 3;
    if (idx == 3) reached = 4;
    if (idx == 4 || idx == 5) reached = 0; // rejected / withdrawn：不展示为通过
    final row = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final done = i < reached;
      row.add(Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: done ? colors[i] : const Color(0xFFE9EBF0),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, size: 15, color: Colors.white)
              : Text('${i + 1}', style: const TextStyle(fontSize: 12, color: Color(0xFF8F959E))),
        ),
        const SizedBox(height: 4),
        Text(steps[i], style: TextStyle(fontSize: 11, color: done ? colors[i] : textHint)),
      ]));
      if (i < steps.length - 1) {
        row.add(Expanded(
          child: Container(height: 2, margin: const EdgeInsets.only(bottom: 16), color: i < reached - 1 ? colors[i] : const Color(0xFFE9EBF0)),
        ));
      }
    }
    return Row(children: row);
  }

  Widget _seekerBar(ApplicationView app) {
    final withdrawn = app.status == 'withdrawn';
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: cardLine))),
        child: Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                foregroundColor: brandColor,
                side: const BorderSide(color: brandColor),
              ),
              onPressed: () => _contactHrOfJob(app),
              child: const Text('联系招聘者'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 46),
                backgroundColor: const Color(0xFFE5484D),
              ),
              onPressed: withdrawn ? null : _withdraw,
              child: Text(withdrawn ? '已撤回' : '撤回投递'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _recruiterBar(ApplicationView app) {
    final current = app.status;
    final options = recruiterTransitions;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: cardLine))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('推进状态', style: TextStyle(fontSize: 12, color: textHint)),
            ),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: brandColor,
                  ),
                  onPressed: () => _openChatWith(app.seekerId, app.seekerName),
                  child: const Text('私聊候选人'),
                ),
              ),
              const SizedBox(width: 8),
              for (final s in options)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      foregroundColor: current == s ? Colors.white : statusColor(s),
                      backgroundColor: current == s ? statusColor(s) : Colors.white,
                      side: BorderSide(color: current == s ? statusColor(s) : statusColor(s).withAlpha(153)),
                      disabledForegroundColor: const Color(0xFFB8BCC4),
                    ),
                    onPressed: current == s ? null : () => _setStatus(s),
                    child: Text(applicationStatusLabel(s), style: const TextStyle(fontSize: 13)),
                  ),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
