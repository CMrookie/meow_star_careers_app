import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/session.dart';
import 'paged_list_view.dart';
import 'theme.dart';
import 'widgets.dart';

/// 求职者：我的收藏
class SavedJobsPage extends StatelessWidget {
  const SavedJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: const Text('我的收藏')),
      body: PagedListView<JobView>(
        loadPage: (page) => session.api.savedJobs(session.token!, page: page),
        emptyBuilder: () => const EmptyView(
          icon: Icons.star_border,
          title: '还没有收藏的职位',
          subtitle: '在职位详情里点星星即可收藏，方便随时查看',
        ),
        // 打开动画由 JobCard 内部统一处理
        itemBuilder: (context, job) => JobCard(job: job),
      ),
    );
  }
}
