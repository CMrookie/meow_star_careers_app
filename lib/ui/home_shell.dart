import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/realtime_chat.dart';
import '../state/session.dart';
import 'complaint_level.dart';
import 'complaint_rules_page.dart';
import 'theme.dart';
import 'widgets.dart';
import 'applications_pages.dart';
import 'chat/conversations_page.dart';
import 'jobs/jobs_page.dart';
import 'my_jobs_page.dart';
import 'profile_page.dart';
import 'resume_search_page.dart';
import 'saved_jobs_page.dart';

/// 主框架：根据角色提供底部 Tab（求职者 / 招聘者）。
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_maybeShowComplaintRule());
      _sub = AppScope.read(context).realtime.stream.listen((e) {
        if (!mounted) return;
        if (e.isInterviewUpdated && e.interview != null) {
          final iv = e.interview!;
          final msg = switch (iv.status) {
            'invited' => '收到新的视频面试邀请：${iv.jobTitle}',
            'in_progress' => '视频面试开始：${iv.jobTitle}',
            'finished' => '视频面试已结束：${iv.jobTitle}',
            'cancelled' => '视频面试已取消：${iv.jobTitle}',
            _ => '视频面试状态更新：${iv.jobTitle}',
          };
          showToast(context, msg);
        } else if (e.isApplicationUpdated && e.application != null) {
          final a = e.application!;
          showToast(context, '「${a.jobTitle}」投递状态更新：${applicationStatusLabel(a.status)}');
        } else if (e.isNewMessage) {
          showToast(context, '收到一条新消息');
        }
      });
    });
  }

  /// 首次进入 App 时提示投诉等级规则。
  ///
  /// 规则数字与版本都来自服务端（**单一来源**；取不到时用本地兜底），
  /// 「已看过」的键按**版本号**区分 —— 后端调整口径后会自动再提示一次。
  Future<void> _maybeShowComplaintRule() async {
    final session = AppScope.read(context);
    var rules = complaintRuleFallback;
    final token = session.token;
    if (!session.isDemo && token != null) {
      try {
        rules = await session.api.complaintRules(token);
      } catch (_) {
        // 拉不到规则时继续用兜底版本，不阻断进入 App
      }
    }
    final seenKey = complaintRuleSeenKeyFor(rules.version);
    final seen = await session.config.store.read(seenKey);
    if (seen == '1' || !mounted) return;
    await session.config.store.write(seenKey, '1');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => ComplaintRuleDialog(rules: rules),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  late final List<_TabDef> _tabs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = AppScope.of(context).user;
    final seeker = user?.isSeeker ?? true;
    _tabs = [
      if (seeker) ...[
        const _TabDef('职位', Icons.work_outline, Icons.work, JobsPage()),
        const _TabDef('收藏', Icons.star_border, Icons.star, SavedJobsPage()),
        const _TabDef('投递', Icons.assignment_outlined, Icons.assignment, MyApplicationsPage()),
      ] else ...[
        const _TabDef('职位管理', Icons.work_outline, Icons.work, MyJobsPage()),
        const _TabDef('收件箱', Icons.inbox_outlined, Icons.inbox, InboxPage()),
        const _TabDef('简历库', Icons.people_alt_outlined, Icons.people_alt, ResumeSearchPage()),
      ],
      const _TabDef('消息', Icons.chat_bubble_outline, Icons.chat_bubble, ConversationsPage()),
      const _TabDef('我的', Icons.person_outline, Icons.person, ProfilePage()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_index >= _tabs.length) _index = 0;
    return Scaffold(
      backgroundColor: bgPage,
      body: IndexedStack(index: _index, children: [for (final t in _tabs) t.page]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.activeIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final Widget page;
  const _TabDef(this.label, this.icon, this.activeIcon, this.page);
}
