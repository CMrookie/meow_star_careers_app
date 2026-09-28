import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../chat/chat_page.dart';
import '../resumes/resume_edit_page.dart';
import '../paged_list_view.dart';
import '../theme.dart';
import '../widgets.dart';
import 'company_map_view.dart';
import 'job_edit_page.dart';

class JobDetailPage extends StatefulWidget {
  final String jobId;

  /// 打开动画带来的首屏数据：先按它渲染（保证接得上，不出现 loading 跳动），再后台刷新
  final JobView? initialJob;

  /// 详情页头部高度（= 卡面高 + 状态栏高），由打开动画给定，保证与飞行层严丝合缝
  final double? headerHeight;

  const JobDetailPage({super.key, required this.jobId, this.initialJob, this.headerHeight});

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  JobView? _job;
  Company? _company;
  Object? _error;
  bool _saved = false;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    _job = widget.initialJob;
    _load();
  }

  Future<void> _load() async {
    final session = AppScope.read(context);
    setState(() {
      _error = null;
      // 已有首屏数据（来自打开动画）时保留，避免头部闪一下
      _job ??= widget.initialJob;
    });
    try {
      final job = await session.api.getJob(widget.jobId, session.token!);
      // 收藏状态：从“我的收藏”里查找（分页取前 200 条足够日常使用）
      var saved = false;
      try {
        final page = await session.api.savedJobs(session.token!, pageSize: 100);
        saved = page.items.any((e) => e.id == widget.jobId);
      } on ApiException {
        // 非求职者可能无权，忽略
      }
      // 企业信息（用于公司位置地图）
      Company? company;
      try {
        company = await session.api.getCompany(job.companyId, session.token!);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _job = job;
        _company = company;
        _saved = saved;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  bool get _isOwner {
    final session = AppScope.of(context);
    final u = session.user;
    return _job != null && u != null && _job!.createdBy == u.id;
  }

  Future<void> _toggleSave() async {
    final session = AppScope.of(context);
    try {
      if (_saved) {
        await session.api.unsaveJob(widget.jobId, session.token!);
      } else {
        await session.api.saveJob(widget.jobId, session.token!);
      }
      if (!mounted) return;
      setState(() => _saved = !_saved);
      showToast(context, _saved ? '已收藏' : '已取消收藏');
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _contactHr() async {
    final session = AppScope.of(context);
    final job = _job;
    if (job == null || job.createdBy == null) {
      showToast(context, '该职位暂未开放联系入口');
      return;
    }
    try {
      final conv = await session.chat.start(job.createdBy!, session.token!);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatPage(conversationId: conv.id, peerName: conv.peer.name),
      ));
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    }
  }

  Future<void> _apply() async {
    final session = AppScope.of(context);
    final job = _job;
    if (job == null) return;

    // 1) 简历准备
    List<Resume> resumes;
    try {
      resumes = await session.api.myResumes(session.token!);
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
      return;
    }
    if (!mounted) return;
    if (resumes.isEmpty) {
      final go = await confirmDialog(
        context,
        title: '还没有简历',
        message: '投递职位前需要先创建一份简历，现在去创建吗？',
        confirmText: '去创建',
        confirmColor: brandColor,
      );
      if (go && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const ResumeEditPage(),
        ));
        if (!mounted) return;
        try {
          resumes = await session.api.myResumes(session.token!);
        } catch (_) {
          return;
        }
      }
      if (resumes.isEmpty) return;
    }

    if (!mounted) return;
    String? resumeId = resumes.length == 1 ? resumes.first.id : null;
    final cover = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard + 4))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('投递「${job.title}」', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('${job.companyName} · ${salaryText(job.salaryMin, job.salaryMax)}',
                      style: const TextStyle(fontSize: 12, color: textHint)),
                  const SizedBox(height: 16),
                  const Text('使用简历', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  for (final r in resumes)
                    InkWell(
                      onTap: () => setSheet(() => resumeId = r.id),
                      borderRadius: BorderRadius.circular(radiusControl),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Icon(
                            resumeId == r.id ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 20,
                            color: resumeId == r.id ? brandColor : const Color(0xFFC0C4CC),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${r.fullName} · ${r.title}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text(
                                '${r.years != null ? '${r.years}年经验 · ' : ''}${r.education ?? '学历未填'}',
                                style: const TextStyle(fontSize: 12, color: textHint),
                              ),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: cover,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                      hintText: '附言 / 求职信（选填，向招聘者介绍一下自己）',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('确认投递'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await runAction(
        context,
        () async {
          await session.api.applyJob(
            widget.jobId,
            session.token!,
            resumeId: resumeId,
            coverLetter: cover.text,
          );
        },
        loadingText: '正在投递…',
      );
      if (!mounted) return;
      setState(() => _applied = true);
      showToast(context, '投递成功，祝你好运！');
    } catch (_) {
      // runAction 已提示
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    final topPad = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: bgPage,
      body: _error != null && job == null
          ? ErrorView(error: _error!, onRetry: _load)
          : job == null
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
              : Stack(children: [
                  _buildBody(job, topPad),
                  // 返回按钮：放在状态栏安全区带内（头部内容从 topPad + 16 才开始，
                  // 放在 topPad 附近既能避开白色 logo 方块、又不会被它盖住）
                  Positioned(
                    left: 8,
                    top: ((topPad - 36) / 2 + 2).clamp(2.0, 40.0),
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.18),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ]),
      bottomNavigationBar: _job == null ? null : _buildActions(context),
    );
  }

  Widget _buildBody(JobView job, double topPad) {
    final isSeeker = AppScope.of(context).user?.isSeeker ?? true;
    final header = JobCardSurface(
      job: job,
      accent: jobAccentColor(job.complaintCount),
      accentDeep: jobAccentDeep(job.complaintCount),
      topInset: topPad,
      notchFill: 1, // 缺口填平
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        // 头部：与列表卡片同一个组件，打开动画落点就是它
        if (widget.headerHeight != null)
          SizedBox(height: widget.headerHeight!, child: header)
        else
          header,
        // 标题 / 薪资 / 标签已在头部（卡面）中，这里只留单位信息
        SectionCard(
          child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: brandColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(radiusInner),
                  ),
                  child: const Icon(Icons.business_outlined, size: 18, color: brandDeep),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(job.companyName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textMain)),
                ),
              Text('更新于 ${relativeTime(job.updatedAt)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFB8BCC4))),
          ]),
        ),
        if (_company != null) CompanyMapView(company: _company!),
        if (isSeeker) _complainEntry(job),
        if (job.description.isNotEmpty)
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('职位描述'),
              Text(job.description, style: const TextStyle(fontSize: 14, color: Color(0xFF3A3F45), height: 1.65)),
            ]),
          ),
        if (job.requirements != null && job.requirements!.isNotEmpty)
          SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SectionTitle('任职要求'),
              Text(job.requirements!, style: const TextStyle(fontSize: 14, color: Color(0xFF3A3F45), height: 1.65)),
            ]),
          ),
        SectionCard(
          child: Column(children: [
            if (!_applied && isSeeker && !_isOwner)
              InkWell(
                onTap: _contactHr,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    const Icon(Icons.chat_bubble_outline, size: 18, color: brandColor),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('对该职位感兴趣？先和招聘者聊聊',
                          style: TextStyle(fontSize: 13, color: textSub)),
                    ),
                    const Icon(Icons.chevron_right, size: 18, color: Color(0xFFC0C4CC)),
                  ]),
                ),
              ),
          ]),
        ),
      ],
    );
  }


  /// 求职者投诉入口（需已与该用人单位实际沟通，证据 >=20 字，提交后等待平台审核）
  Widget _complainEntry(JobView job) {
    return SectionCard(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _fileComplaint(job),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Icon(Icons.rate_review_outlined, size: 18, color: Color(0xFFE5484D)),
            SizedBox(width: 8),
            Expanded(child: Text('对该用人单位发起投诉', style: TextStyle(fontSize: 13, color: textSub))),
            Icon(Icons.chevron_right, size: 18, color: Color(0xFFC0C4CC)),
          ]),
        ),
      ),
    );
  }

  Future<void> _fileComplaint(JobView job) async {
    final evidence = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('投诉该用人单位'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('投诉条件：你需已与该用人单位有过实际沟通（发起过会话并发送过消息）；投诉经平台审核通过后才会生效。',
              style: TextStyle(fontSize: 12, color: textSub)),
          const SizedBox(height: 12),
          TextField(
            controller: evidence,
            maxLines: 4,
            maxLength: 5000,
            decoration: const InputDecoration(hintText: '请填写有效证据（≥20 字，如沟通事实、截图描述、时间等）'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('提交投诉'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final text = evidence.text.trim();
    if (text.length < 20) {
      showToast(context, '请填写至少 20 字的有效证据', error: true);
      return;
    }
    final session = AppScope.of(context);
    try {
      await runAction(context, () async {
        await session.api.createComplaint(companyId: job.companyId, evidence: text, token: session.token!);
      });
      if (!mounted) return;
      showToast(context, '投诉已提交，等待平台审核');
    } catch (_) {}
  }

  Widget _buildActions(BuildContext context) {
    final session = AppScope.of(context);
    final job = _job!;
    final user = session.user;
    final isOwnerRecruiter = user?.isRecruiter == true && _isOwner;
    final isSeeker = user?.isSeeker ?? false;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: cardLine))),
        child: Row(children: [
          if (isOwnerRecruiter) ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                foregroundColor: job.isActive ? const Color(0xFFE5484D) : accentGreen,
                side: BorderSide(color: job.isActive ? const Color(0xFFE5484D) : accentGreen),
              ),
              onPressed: () => _toggleActive(job),
              child: Text(job.isActive ? '下架' : '上架'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => JobEditPage(job: job),
                  ));
                  if (mounted) _load();
                },
                child: const Text('编辑职位'),
              ),
            ),
          ] else if (isSeeker) ...[
            IconButton(
              tooltip: _saved ? '取消收藏' : '收藏',
              onPressed: _toggleSave,
              icon: Icon(_saved ? Icons.star : Icons.star_border, color: _saved ? warmOrange : textHint, size: 26),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: '和招聘者聊聊',
              onPressed: job.createdBy == null ? null : _contactHr,
              icon: const Icon(Icons.chat_bubble_outline, size: 25, color: brandColor),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: _applied
                    ? null
                    : () async {
                        await _apply();
                      },
                child: Text(_applied ? '已投递' : '立即投递'),
              ),
            ),
          ] else ...[
            IconButton(
              tooltip: _saved ? '取消收藏' : '收藏',
              onPressed: _toggleSave,
              icon: Icon(_saved ? Icons.star : Icons.star_border, color: _saved ? warmOrange : textHint, size: 26),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(onPressed: _contactHr, child: const Text('和招聘者聊聊')),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _toggleActive(JobView job) async {
    final session = AppScope.of(context);
    try {
      await runAction(context, () async {
        await session.api.setJobActive(job.id, !job.isActive, session.token!);
      }, loadingText: job.isActive ? '下架中…' : '上架中…');
      if (mounted) {
        showToast(context, job.isActive ? '职位已下架' : '职位已上架');
        _load();
      }
    } catch (_) {}
  }
}
