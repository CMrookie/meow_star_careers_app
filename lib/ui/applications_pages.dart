import 'dart:async';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/realtime_chat.dart';
import '../state/session.dart';
import 'application_card.dart';
import 'application_detail_page.dart';
import 'paged_list_view.dart';
import 'theme.dart';
import 'widgets.dart';

/// 求职者：我的投递
class MyApplicationsPage extends StatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  State<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends State<MyApplicationsPage> {
  String? _status;
  final _listKey = GlobalKey<PagedListViewState<ApplicationView>>();
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AppScope.read(context).realtime.stream.listen((e) {
      if (mounted && (e.isApplicationUpdated || e.isInterviewUpdated)) {
        _listKey.currentState?.refresh();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: const Text('我的投递')),
      body: Column(children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _chip('全部', _status == null, () => setState(() => _status = null)),
              for (final s in applicationStatuses)
                _chip(applicationStatusLabel(s), _status == s, () => setState(() => _status = s)),
            ],
          ),
        ),
        Expanded(
          child: PagedListView<ApplicationView>(
            key: _listKey,
            loadPage: (page) => session.api.listApplications(
              session.token!,
              status: _status,
              page: page,
            ),
            emptyBuilder: () => const EmptyView(
              icon: Icons.send_outlined,
              title: '还没有投递记录',
              subtitle: '去职位列表挑一个心仪的岗位投递吧',
            ),
            itemBuilder: (context, app) => ApplicationCard(
              app: app,
              showSeeker: false,
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ApplicationDetailPage(applicationId: app.id),
                ));
                _listKey.currentState?.refresh();
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: brandColor,
        backgroundColor: Colors.white,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontSize: 13,
          color: selected ? Colors.white : textSub,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// 招聘者：投递收件箱
class InboxPage extends StatefulWidget {
  final String? initialJobId;
  final String? initialJobTitle;
  const InboxPage({super.key, this.initialJobId, this.initialJobTitle});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  String? _status;
  final _listKey = GlobalKey<PagedListViewState<ApplicationView>>();
  StreamSubscription<RealtimeEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = AppScope.read(context).realtime.stream.listen((e) {
      if (mounted && (e.isApplicationUpdated || e.isInterviewUpdated)) {
        _listKey.currentState?.refresh();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        title: Text(widget.initialJobTitle == null ? '投递收件箱' : '「${widget.initialJobTitle}」的投递'),
        leading: widget.initialJobId == null
            ? null
            : BackButton(
                onPressed: () => Navigator.of(context).maybePop(),
              ),
      ),
      body: Column(children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              _chip('全部', _status == null, () => setState(() => _status = null)),
              for (final s in ['pending', ...recruiterTransitions, 'withdrawn'])
                _chip(applicationStatusLabel(s), _status == s, () => setState(() => _status = s)),
            ],
          ),
        ),
        Expanded(
          child: PagedListView<ApplicationView>(
            key: _listKey,
            loadPage: (page) => session.api.listApplications(
              session.token!,
              jobId: widget.initialJobId,
              status: _status,
              page: page,
            ),
            emptyBuilder: () => const EmptyView(
              icon: Icons.inbox_outlined,
              title: '暂无投递',
              subtitle: '候选人投递后会第一时间出现在这里',
            ),
            itemBuilder: (context, app) => ApplicationCard(
              app: app,
              showSeeker: true,
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ApplicationDetailPage(applicationId: app.id),
                ));
                _listKey.currentState?.refresh();
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        selectedColor: brandColor,
        backgroundColor: Colors.white,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontSize: 13,
          color: selected ? Colors.white : textSub,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}
