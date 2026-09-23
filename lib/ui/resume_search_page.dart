import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/session.dart';
import 'paged_list_view.dart';
import 'resumes/resumes_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// 招聘者：检索公开简历
class ResumeSearchPage extends StatefulWidget {
  const ResumeSearchPage({super.key});

  @override
  State<ResumeSearchPage> createState() => _ResumeSearchPageState();
}

class _ResumeSearchPageState extends State<ResumeSearchPage> {
  final _search = TextEditingController();
  String _keyword = '';
  int _token = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: const Text('简历库')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) {
              setState(() {
                _keyword = v.trim();
                _token++;
              });
            },
            decoration: InputDecoration(
              hintText: '按姓名 / 期望职位 / 技能搜索公开简历',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _search.clear();
                        setState(() {
                          _keyword = '';
                          _token++;
                        });
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: PagedListView<Resume>(
            key: ValueKey('resumes-$_token'),
            loadPage: (page) => session.api.searchResumes(session.token!, keyword: _keyword, page: page),
            emptyBuilder: () => const EmptyView(
              icon: Icons.manage_search,
              title: '没有找到匹配的简历',
              subtitle: '试试更宽泛的关键词，例如职位名称或技能',
            ),
            itemBuilder: (context, r) => ResumeCard(
              resume: r,
              onTap: () => showResumeDetail(context, r),
            ),
          ),
        ),
      ]),
    );
  }
}
