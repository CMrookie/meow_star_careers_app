import 'package:flutter/material.dart';

import '../../core/format.dart';
import 'region_picker_page.dart';
import '../../models/models.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets.dart';
import '../paged_list_view.dart';

/// 职位搜索参数
class JobFilters {
  String keyword;

  /// 查询用地区词（三级地区选择器产出：精确到已选最深层）
  String? location;

  /// 展示用地区文案（如「广东 · 深圳市 · 南山区」；为空则回退 location）
  String? locationLabel;
  String? jobType;
  int? salaryMin;
  int? salaryMax;

  JobFilters({
    this.keyword = '',
    this.location,
    this.locationLabel,
    this.jobType,
    this.salaryMin,
    this.salaryMax,
  });

  bool get hasActiveFilter =>
      (location?.isNotEmpty ?? false) || jobType != null || salaryMin != null || salaryMax != null;

  String get filterSummary {
    final parts = <String>[];
    final loc = (locationLabel != null && locationLabel!.isNotEmpty)
        ? locationLabel
        : location;
    if (loc != null && loc.isNotEmpty) parts.add(loc);
    if (jobType != null) parts.add(jobTypeLabel(jobType!));
    if (salaryMin != null || salaryMax != null) parts.add(salaryText(salaryMin, salaryMax));
    return parts.join(' · ');
  }
}

class JobsPage extends StatefulWidget {
  const JobsPage({super.key});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final _searchController = TextEditingController();
  JobFilters _filters = JobFilters();
  int _reloadToken = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String kw) {
    setState(() {
      _filters.keyword = kw.trim();
      _reloadToken++;
    });
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<JobFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard + 4)),
      ),
      builder: (_) => _FilterSheet(initial: _filters),
    );
    if (result != null) {
      setState(() {
        _filters = result;
        _reloadToken++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(children: [
          const Text('找工作', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
          const Spacer(),
          TextButton.icon(
            onPressed: _openFilters,
            icon: const Icon(Icons.tune, size: 19),
            label: const Text('筛选'),
          ),
        ]),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _search,
                  decoration: InputDecoration(
                    hintText: '搜索职位 / 关键词',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _search('');
                            },
                          ),
                  ),
                ),
              ),
            ]),
          ),
          if (_filters.hasActiveFilter)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                TagChip(_filters.filterSummary, color: brandColor, filled: true),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _filters = JobFilters(keyword: _filters.keyword);
                      _reloadToken++;
                    });
                  },
                  child: const Text('清除筛选', style: TextStyle(fontSize: 12, color: textHint)),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: PagedListView<JobView>(
              key: ValueKey('jobs-$_reloadToken'),
              loadPage: (page) => session.api.searchJobs(
                session.token!,
                keyword: _filters.keyword,
                location: _filters.location,
                jobType: _filters.jobType,
                salaryMin: _filters.salaryMin,
                salaryMax: _filters.salaryMax,
                page: page,
              ),
              itemSorter: compareJobsByComplaintLevel,
              emptyBuilder: () => const EmptyView(
                icon: Icons.search_off,
                title: '没有找到合适的职位',
                subtitle: '换个关键词或放宽筛选条件试试',
              ),
              // 打开动画由 JobCard 内部统一处理（容器变换到详情页头部）
              itemBuilder: (context, job) => JobCard(job: job),
            ),
          ),
        ],
      ),
    );
  }
}

/// 筛选面板
class _FilterSheet extends StatefulWidget {
  final JobFilters initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  RegionSelection? _region;
  late String? _jobType;
  late (int?, int?) _salary;

  static const _salaryBands = <(String, int?, int?)>[
    ('薪资不限', null, null),
    ('10K 以下', null, 10000),
    ('10K - 15K', 10000, 15000),
    ('15K - 20K', 15000, 20000),
    ('20K - 30K', 20000, 30000),
    ('30K - 50K', 30000, 50000),
    ('50K 以上', 50000, null),
  ];

  @override
  void initState() {
    super.initState();
    _jobType = widget.initial.jobType;
    final s = (widget.initial.salaryMin, widget.initial.salaryMax);
    _salary = _salaryBands.any((b) => b.$2 == s.$1 && b.$3 == s.$2) ? s : (null, null);
    final loc = widget.initial.location;
    if (loc != null && loc.isNotEmpty && widget.initial.locationLabel == null) {
      _region = RegionSelection(city: loc);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(children: [
                const Text('筛选职位', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(onPressed: _reset, child: const Text('重置')),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('所在地区'),
                    InkWell(
                      onTap: _pickRegion,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          hintText: '选择省份 / 城市 / 区县',
                          isDense: true,
                          prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                          suffixIcon: null,
                        ),
                        isEmpty: _region == null || _region!.isEmpty,
                        child: _region != null && !_region!.isEmpty
                            ? Row(children: [
                                Expanded(
                                  child: Text(
                                    _region!.fullLabel,
                                    style: const TextStyle(fontSize: 14, color: textMain),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _region = null),
                                  child: const Icon(Icons.close, size: 16, color: textHint),
                                ),
                              ])
                            : const Text('如：广东 · 深圳市 · 南山区',
                                style: TextStyle(fontSize: 14, color: textHint)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _label('工作性质'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _choiceChip('不限', _jobType == null, () => setState(() => _jobType = null)),
                        for (final t in jobTypes)
                          _choiceChip(jobTypeLabel(t), _jobType == t, () => setState(() => _jobType = t)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _label('期望月薪'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final b in _salaryBands)
                          _choiceChip(
                            b.$1,
                            _salary.$1 == b.$2 && _salary.$2 == b.$3,
                            () => setState(() => _salary = (b.$2, b.$3)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: () {
                        final region = _region;
                        Navigator.pop(
                          context,
                          JobFilters(
                            keyword: widget.initial.keyword,
                            location: region == null || region.isEmpty ? null : region.query,
                            locationLabel: region == null || region.isEmpty ? null : region.fullLabel,
                            jobType: _jobType,
                            salaryMin: _salary.$1,
                            salaryMax: _salary.$2,
                          ),
                        );
                      },
                      child: const Text('查看结果'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSub)),
      );

  Widget _choiceChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: brandColor,
      backgroundColor: const Color(0xFFF1F4FA),
      labelStyle: TextStyle(
        fontSize: 13,
        color: selected ? Colors.white : textSub,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    );
  }

  Future<void> _pickRegion() async {
    final picked = await Navigator.of(context).push<RegionSelection>(
      MaterialPageRoute(builder: (_) => RegionPickerPage(initial: _region ?? const RegionSelection())),
    );
    if (picked != null && mounted) setState(() => _region = picked);
  }

  void _reset() {
    setState(() {
      _region = null;
      _jobType = null;
      _salary = (null, null);
    });
  }
}
