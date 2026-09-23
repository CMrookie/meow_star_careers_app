import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/models.dart';
import '../state/session.dart';
import 'theme.dart';
import 'widgets.dart';
import 'complaint_level.dart';
import 'jobs/job_open_transition.dart';

/// 通用「分页 + 下拉刷新 + 上拉加载 + 空态/错误态」列表。
class PagedListView<T> extends StatefulWidget {
  final Future<Paged<T>> Function(int page) loadPage;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget? emptyWidget;
  final Widget Function()? emptyBuilder;

  /// 控制是否允许加载更多
  final bool Function(int page, int total)? canLoadMore;

  /// 每页数据入库前的排序器（职位列表用它做「按投诉等级由优到劣」）。
  /// 注意：分页列表只能做「页内有序」，要全局有序需要后端按同一规则排序返回。
  final Comparator<T>? itemSorter;

  const PagedListView({
    super.key,
    required this.loadPage,
    required this.itemBuilder,
    this.emptyWidget,
    this.emptyBuilder,
    this.canLoadMore,
    this.itemSorter,
  });

  @override
  State<PagedListView<T>> createState() => PagedListViewState<T>();
}

class PagedListViewState<T> extends State<PagedListView<T>> {
  final _items = <T>[];
  final _scroll = ScrollController();
  int _page = 1;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _error = false;
  Object? _errorObj;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMoreIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= 0 ||
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  bool get _hasMore => _items.length < _total;

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final res = await widget.loadPage(1);
      if (!mounted) return;
      setState(() {
        _items.clear();
        _items.addAll(_sorted(res.items));
        _total = res.total;
        _page = 1;
        _loading = false;
      });
      _loadMoreIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
        _errorObj = e;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final can = widget.canLoadMore?.call(_page, _total) ?? _hasMore;
    if (!can) return;
    setState(() => _loadingMore = true);
    try {
      final res = await widget.loadPage(_page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(_sorted(res.items));
        _total = res.total;
        _page += 1;
        _loadingMore = false;
      });
      _loadMoreIfNeeded();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  List<T> _sorted(List<T> items) {
    final sorter = widget.itemSorter;
    if (sorter == null) return items;
    return List<T>.of(items)..sort(sorter);
  }

  /// 供外部（如详情页操作后）触发刷新
  void refresh() => _reload();

  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (_error && _items.isEmpty) {
      return ErrorView(error: _errorObj ?? '', onRetry: _reload);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: widget.emptyWidget ??
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(height: constraints.maxHeight, child: widget.emptyBuilder?.call() ?? const EmptyView(title: '暂无数据')),
              ),
            ),
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(vertical: 10),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            if (_loadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              );
            }
            if (!_hasMore && _items.length > 3) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(child: Text('— 没有更多了 —', style: TextStyle(fontSize: 12, color: Color(0xFFB8BCC4)))),
              );
            }
            return const SizedBox(height: 10);
          }
          return widget.itemBuilder(context, _items[index]);
        },
      ),
    );
  }
}

/// 职位卡片（列表通用）
///
/// 视觉语言：整块彩色卡面 + 24 大圆角 + 同色投影，右上角用 [SmoothNotchClipper]
/// 挖出平滑 S 型内凹缺口，缺口里悬浮浅色「查看」胶囊；
/// 上半部分是职位信息与半透明胶囊标签，下半部分是白色底栏（发布时间 + 薪资）。
/// 职位列表统一排序：投诉等级由优到劣（优秀 → 严重），
/// 同级按次数由少到多，最后按发布时间由新到旧。
int compareJobsByComplaintLevel(JobView a, JobView b) {
  final ka = jobSortKey(a.complaintCount, a.createdAt);
  final kb = jobSortKey(b.complaintCount, b.createdAt);
  final c0 = ka.$1.compareTo(kb.$1);
  if (c0 != 0) return c0;
  final c1 = ka.$2.compareTo(kb.$2);
  if (c1 != 0) return c1;
  return ka.$3.compareTo(kb.$3);
}

/// 职位卡卡面。
///
/// 列表卡片、打开动画的飞行层、详情页头部**共用这一个组件**，
/// 因此动画首尾两端与真实卡面完全一致，打开时没有任何跳动。
/// 布局刻意做成「与宽度无关的确定高度」：标签是固定高的单行横向滚动、
/// 描述是固定高的两行盒子，所以卡面高度在任何宽度下都相同。
class JobCardSurface extends StatelessWidget {
  final JobView job;
  final Color accent;

  /// 顶部额外内边距（详情页头部让开状态栏）
  final double topInset;

  /// 槽口填充进度：0 = 列表卡片形态，1 = 槽口填平（详情页头部）
  final double notchFill;

  /// 槽口里的操作（招聘者「更多」菜单）；为空则显示「查看」胶囊
  final Widget? trailing;

  final VoidCallback? onTap;

  const JobCardSurface({
    super.key,
    required this.job,
    required this.accent,
    this.topInset = 0,
    this.notchFill = 0,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final clipper = SmoothNotchClipper(fill: notchFill);
    final pillOpacity = (1 - notchFill).clamp(0.0, 1.0);
    final tags = <Widget>[
      if (job.complaintCount > 0)
        _ComplaintBadge(complaints: job.complaintCount),
      if (!job.isActive) GlassPill('已下架', icon: Icons.visibility_off_outlined, backgroundAlpha: 0.30),
      if (job.location != null && job.location!.isNotEmpty)
        GlassPill(job.location!, icon: Icons.location_on_outlined),
      GlassPill(job.typeLabel, icon: Icons.access_time),
      if (job.experience != null && job.experience!.isNotEmpty)
        GlassPill(job.experience!, icon: Icons.work_outline),
      if (job.education != null && job.education!.isNotEmpty)
        GlassPill(job.education!, icon: Icons.school_outlined),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        PhysicalShape(
          clipper: clipper,
          color: Colors.transparent,
          // 卡片自己的同色投影（展开到详情页头部时随槽口一起淡出）
          elevation: 12 * (1 - notchFill),
          shadowColor: accent.withValues(alpha: 0.35),
          // 默认是 Clip.none，不裁剪会让白色薪资栏溢出、底部圆角丢失
          clipBehavior: Clip.antiAlias,
          child: ColoredBox(
            color: accent,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 16 + topInset, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 标题行（右侧让开槽口）
                          Padding(
                            padding: const EdgeInsets.only(right: notchContentInset),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(radiusInner - 2),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    job.companyName.isEmpty ? '企' : job.companyName.characters.first,
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: accent),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        job.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        job.companyName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // 标签：固定高单行（可横向滚动），保证任一宽度下高度一致
                          SizedBox(
                            height: 24,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              child: Row(
                                children: [
                                  for (var i = 0; i < tags.length; i++) ...[
                                    if (i > 0) const SizedBox(width: 6),
                                    tags[i],
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // 描述：固定高两行
                          SizedBox(
                            height: 32,
                            width: double.infinity,
                            child: Text(
                              job.description.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 白色薪资栏（底部圆角由槽口裁剪器一并保证）
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: Color(0xFF9AA1AE)),
                              const SizedBox(width: 5),
                              Text(
                                '发布于 ${relativeTime(job.createdAt)}',
                                style: const TextStyle(color: Color(0xFF8B9199), fontSize: 12),
                              ),
                            ],
                          ),
                          Text(
                            salaryText(job.salaryMin, job.salaryMax),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: textMain),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 槽口里的「查看」胶囊（在裁剪之外，缩小时淡出）
        if (pillOpacity > 0.001)
          Positioned(
            top: notchPillTop + topInset,
            right: notchPillRightInset,
            child: Opacity(
              opacity: pillOpacity,
              child: Transform.scale(
                scale: pillOpacity,
                // 胶囊自己在缺口里、不在卡面裁剪区内，自带底色又会吃掉点击，
                // 所以必须给它单独接上同一个打开动作（trailing 菜单则用它自己的手势）
                child: trailing != null
                    ? _NotchAction(child: trailing!)
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onTap,
                        child: const _NotchAction(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('查看',
                                  style: TextStyle(
                                      color: notchPillFg, fontSize: 13, fontWeight: FontWeight.w700)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_outward, color: notchPillFg, size: 14),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 职位卡片（列表通用）
class JobCard extends StatelessWidget {
  final JobView job;

  /// 覆盖默认的打开动画（一般不需要）
  final VoidCallback? onTap;

  /// 详情页返回后的回调（如招聘者列表刷新）
  final VoidCallback? onClosed;

  /// 槽口里的自定义操作（如招聘者的「更多」菜单）
  final Widget? trailing;

  const JobCard({super.key, required this.job, this.onTap, this.onClosed, this.trailing});

  @override
  Widget build(BuildContext context) {
    final accent = jobAccentColor(job.jobType, job.complaintCount);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Opacity(
        opacity: job.isActive ? 1 : 0.62,
        child: Builder(
          builder: (cardContext) => JobCardSurface(
            job: job,
            accent: accent,
            trailing: trailing,
            onTap: onTap ?? () => openJobDetailFrom(cardContext, job, onClosed: onClosed),
          ),
        ),
      ),
    );
  }
}

/// 投诉等级徽标：白底 + 等级色，任何卡面主色上都清晰
class _ComplaintBadge extends StatelessWidget {
  final int complaints;
  const _ComplaintBadge({required this.complaints});

  @override
  Widget build(BuildContext context) {
    final level = complaintLevelOf(complaints);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(level.icon, size: 12, color: level.color),
          const SizedBox(width: 4),
          Text(level.badge(complaints),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: level.color)),
        ],
      ),
    );
  }
}

/// 缺口里的胶囊外观（浅蓝底 + 深蓝字，在缺口露出的页面底色上也清晰可读）
class _NotchAction extends StatelessWidget {
  final Widget child;
  const _NotchAction({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: notchPillWidth,
      height: notchPillHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: notchPillBg,
        borderRadius: BorderRadius.circular(radiusPill),
        // 胶囊自己的阴影（深色近距），与卡面的同色投影区分开
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 便捷：以职位为入口发起与招聘者(Hiring user)的私聊，返回会话 id。
Future<String?> startChatWithUser(
  BuildContext context, {
  required String peerUserId,
  String? peerName,
}) async {
  final session = AppScope.of(context);
  try {
    final conv = await session.chat.start(peerUserId, session.token!);
    return conv.id;
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
    return null;
  }
}
