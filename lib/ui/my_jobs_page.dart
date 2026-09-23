import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/session.dart';
import 'applications_pages.dart';
import 'jobs/job_edit_page.dart';
import 'jobs/jobs_page.dart';
import 'paged_list_view.dart';
import 'theme.dart';
import 'widgets.dart';

/// 招聘者：我的职位（本企业）
class MyJobsPage extends StatelessWidget {
  const MyJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        return Scaffold(
          backgroundColor: bgPage,
          appBar: AppBar(
            title: const Text('职位管理'),
            actions: [
              IconButton(
                tooltip: '浏览全站职位',
                icon: const Icon(Icons.explore_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const JobsPage()),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: brandColor,
            foregroundColor: Colors.white,
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const JobEditPage()),
              );
              if (created == true && context.mounted) {
                // 列表页通过 key 刷新
                _PublishNotifier.instance.bump();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('发布职位'),
          ),
          body: _JobsListBody(),
        );
      },
    );
  }
}

/// 简单跨页刷新通知：发布新职位后让列表重载
class _PublishNotifier {
  _PublishNotifier._();
  static final instance = _PublishNotifier._();
  final listeners = <VoidCallback>{};
  void add(VoidCallback cb) => listeners.add(cb);
  void remove(VoidCallback cb) => listeners.remove(cb);
  void bump() {
    for (final cb in listeners.toList()) {
      cb();
    }
  }
}

class _JobsListBody extends StatefulWidget {
  @override
  State<_JobsListBody> createState() => _JobsListBodyState();
}

class _JobsListBodyState extends State<_JobsListBody> {
  final _listKey = GlobalKey<PagedListViewState<JobView>>();

  @override
  void initState() {
    super.initState();
    _PublishNotifier.instance.add(_refresh);
  }

  @override
  void dispose() {
    _PublishNotifier.instance.remove(_refresh);
    super.dispose();
  }

  void _refresh() => _listKey.currentState?.refresh();

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return PagedListView<JobView>(
      key: _listKey,
      loadPage: (page) => session.api.myJobs(session.token!, page: page),
      emptyBuilder: () => const EmptyView(
        icon: Icons.work_off_outlined,
        title: '还没有发布过职位',
        subtitle: '点击右下角「发布职位」，开始招人吧',
      ),
      itemBuilder: (context, job) => JobCard(
        job: job,
        onClosed: _refresh,
        trailing: PopupMenuButton<String>(
          tooltip: '更多操作',
          icon: const Icon(Icons.more_vert, size: 18, color: notchPillFg),
          iconSize: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          onSelected: (v) => _onMenu(context, job, v),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'applications', child: Text('查看投递')),
            const PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(value: 'toggle', child: Text(job.isActive ? '下架' : '上架')),
            const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, JobView job, String action) async {
    final session = AppScope.of(context);
    switch (action) {
      case 'applications':
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => InboxPage(initialJobId: job.id, initialJobTitle: job.title),
        ));
        _refresh();
        break;
      case 'edit':
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => JobEditPage(job: job)),
        );
        if (changed == true) _refresh();
        break;
      case 'toggle':
        try {
          await runAction(context, () async {
            await session.api.setJobActive(job.id, !job.isActive, session.token!);
          });
          if (!context.mounted) return;
          showToast(context, job.isActive ? '职位已下架' : '职位已上架');
          _refresh();
        } catch (_) {}
        break;
      case 'delete':
        final ok = await confirmDialog(
          context,
          title: '删除职位',
          message: '删除后不可恢复，且候选人无法再投递该职位。确定删除「${job.title}」吗？',
        );
        if (ok && context.mounted) {
          try {
            await runAction(context, () async {
              await session.api.deleteJob(job.id, session.token!);
            });
            if (!context.mounted) return;
            showToast(context, '职位已删除');
            _refresh();
          } catch (_) {}
        }
        break;
    }
  }
}
