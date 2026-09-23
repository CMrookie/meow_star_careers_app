import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'resume_edit_page.dart';

/// 简历卡片
class ResumeCard extends StatelessWidget {
  final Resume resume;
  final VoidCallback? onTap;
  final Widget? trailing;
  const ResumeCard({super.key, required this.resume, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Avatar(name: resume.fullName, size: 44, color: const Color(0xFFEDF1FE)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(resume.fullName, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain)),
                  ),
                  const SizedBox(width: 8),
                  TagChip(resume.isPublic ? '公开' : '私密',
                      color: resume.isPublic ? const Color(0xFF07C160) : const Color(0xFF9AA0A8), filled: true),
                ]),
                const SizedBox(height: 4),
                Text('期望：${resume.title}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: textSub)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  if (resume.years != null) TagChip('${resume.years} 年经验'),
                  if (resume.education != null && resume.education!.isNotEmpty) TagChip(resume.education!),
                ]),
                const SizedBox(height: 6),
                Text('更新于 ${relativeTime(resume.updatedAt)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFFB8BCC4))),
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ]),
        ),
      ),
    );
  }
}

/// 简历只读详情（底部弹出）
void showResumeDetail(BuildContext context, Resume resume) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard + 4))),
    builder: (ctx) => SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(children: [
              Avatar(name: resume.fullName, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${resume.fullName} · ${resume.title}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('更新于 ${fullTime(resume.updatedAt)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFB8BCC4))),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 10),
            KeyValueRow('手机', resume.phone ?? '未填写'),
            KeyValueRow('邮箱', resume.email ?? '未填写'),
            KeyValueRow('工作年限', resume.years == null ? '未填写' : '${resume.years} 年'),
            KeyValueRow('学历', resume.education ?? '未填写'),
            if (resume.skills != null && resume.skills!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const SectionTitle('技能与经历'),
              Text(resume.skills!, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF3A3F45))),
            ],
            if (resume.summary != null && resume.summary!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const SectionTitle('自我评价'),
              Text(resume.summary!, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF3A3F45))),
            ],
          ],
        ),
      ),
    ),
  );
}

/// 求职者：我的简历管理
class ResumesPage extends StatefulWidget {
  const ResumesPage({super.key});

  @override
  State<ResumesPage> createState() => _ResumesPageState();
}

class _ResumesPageState extends State<ResumesPage> {
  List<Resume>? _items;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = AppScope.read(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await session.api.myResumes(session.token!);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _openEdit([Resume? resume]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ResumeEditPage(resume: resume)),
    );
    if (mounted) _load();
  }

  Future<void> _delete(Resume resume) async {
    final ok = await confirmDialog(
      context,
      title: '删除简历',
      message: '确定删除「${resume.fullName} · ${resume.title}」这份简历吗？',
      confirmText: '删除',
    );
    if (!ok || !mounted) return;
    final session = AppScope.of(context);
    try {
      await runAction(context, () async {
        await session.api.deleteResume(resume.id, session.token!);
      });
      if (!mounted) return;
      showToast(context, '简历已删除');
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: const Text('我的简历')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: brandColor,
        foregroundColor: Colors.white,
        onPressed: () => _openEdit(),
        icon: const Icon(Icons.add),
        label: const Text('新建简历'),
      ),
      body: _loading && items == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : _error != null
              ? ErrorView(error: _error!, onRetry: _load)
              : items == null || items.isEmpty
                  ? const EmptyView(
                      icon: Icons.description_outlined,
                      title: '还没有简历',
                      subtitle: '创建一份简历，让招聘者更了解你',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (context, i) {
                          final r = items[i];
                          return ResumeCard(
                            resume: r,
                            onTap: () => showResumeDetail(context, r),
                            trailing: PopupMenuButton<String>(
                              tooltip: '操作',
                              icon: const Icon(Icons.more_vert, size: 20, color: textHint),
                              onSelected: (v) {
                                if (v == 'edit') _openEdit(r);
                                if (v == 'delete') _delete(r);
                                if (v == 'view') showResumeDetail(context, r);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'view', child: Text('查看')),
                                PopupMenuItem(value: 'edit', child: Text('编辑')),
                                PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
