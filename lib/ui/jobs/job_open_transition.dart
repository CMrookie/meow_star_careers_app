import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../paged_list_view.dart';
import '../theme.dart';
import 'job_detail_page.dart';

/// 职位卡 → 详情页的「容器变换」打开动画：
/// 「查看」胶囊缩小淡出 → 卡面缺口（槽口）填平 → 卡面放大到屏幕宽度并移动到页面顶端。
///
/// 首尾一致是关键：飞行层用的就是列表里的同一个 [JobCardSurface]，
/// 起点矩形取自卡面实际位置，终点矩形 = 详情页头部（0, 0, 屏宽, 卡面高 + 状态栏高），
/// 因此 t=0 与列表卡片像素级重合、t=1 与详情页头部像素级重合，全程没有跳动。
Future<void> openJobDetailFrom(
  BuildContext cardContext,
  JobView job, {
  VoidCallback? onClosed,
}) {
  final box = cardContext.findRenderObject() as RenderBox?;
  final from = box == null
      ? Rect.fromLTWH(0, 0, MediaQuery.sizeOf(cardContext).width, 180)
      : box.localToGlobal(Offset.zero) & box.size;
  return Navigator.of(cardContext)
      .push(JobDetailRoute(job: job, from: from))
      .then((_) => onClosed?.call());
}

/// 飞行层（供测试与调试定位）
const jobFlightKey = ValueKey('job-open-flight');

class JobDetailRoute extends PageRouteBuilder<void> {
  final JobView job;
  final Rect from;

  /// 终点矩形 = 详情页头部：铺满宽度、高度 = 卡面高 + 状态栏高。
  /// 注意要用路由层的 MediaQuery 取顶部安全区——列表页里那个 Scaffold 带 AppBar，
  /// 它的 body 上下文里 padding.top 已被吞掉（会变 0）。
  static Rect targetRectFor(BuildContext context, Rect from) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Rect.fromLTWH(0, 0, MediaQuery.sizeOf(context).width, from.height + topPad);
  }

  JobDetailRoute({required this.job, required this.from})
      : super(
          opaque: false,
          barrierColor: null,
          transitionDuration: const Duration(milliseconds: 460),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          pageBuilder: (context, animation, secondaryAnimation) => JobDetailPage(
            jobId: job.id,
            initialJob: job,
            headerHeight: targetRectFor(context, from).height,
          ),
        );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final t = Curves.easeOutCubic.transform(animation.value);
    final to = targetRectFor(context, from);
    final rect = Rect.lerp(from, to, t)!;
    final accent = jobAccentColor(job.complaintCount);
    final topPad = to.height - from.height;
    return _EdgeSwipeBack(
      controller: controller!,
      navigator: navigator!,
      child: Stack(
        children: [
          // 详情页本体：后段淡入（页面内容不与飞行层抢视觉）
          Opacity(
            opacity: Interval(0.5, 1.0, curve: Curves.easeOut).transform(animation.value),
            child: child,
          ),
          // 飞行卡面
          Positioned.fromRect(
            rect: rect,
            child: IgnorePointer(
              child: JobCardSurface(
                key: jobFlightKey,
                job: job,
                accent: accent,
                accentDeep: jobAccentDeep(job.complaintCount),
                topInset: topPad * t,
                notchFill: t,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 左缘侧滑返回：自定义 PageRouteBuilder 不带 Cupertino 的边缘手势，这里自己实现——
/// 手指从屏幕左缘（24px 内）横向拖动时直接驱动本路由的动画控制器，
/// 于是「卡片展开动画」会跟着手指倒放；松手超过阈值就 pop，否则弹回。
class _EdgeSwipeBack extends StatefulWidget {
  final AnimationController controller;
  final NavigatorState navigator;
  final Widget child;
  const _EdgeSwipeBack({required this.controller, required this.navigator, required this.child});

  @override
  State<_EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<_EdgeSwipeBack> {
  static const double _edge = 24; // 起手热区（屏幕左缘 24px）
  bool _dragging = false;
  double _startX = 0;

  void _down(PointerDownEvent e) {
    if (e.position.dx > _edge) return;
    _dragging = true;
    _startX = e.position.dx;
    widget.controller.stop();
  }

  void _move(PointerMoveEvent e) {
    if (!_dragging) return;
    final width = context.size?.width ?? 1;
    final dx = (e.position.dx - _startX).clamp(0.0, width);
    widget.controller.value = (1 - dx / width).clamp(0.0, 1.0);
  }

  void _up(PointerEvent e) {
    if (!_dragging) return;
    _dragging = false;
    if (widget.controller.value < 0.7) {
      widget.navigator.maybePop(); // 触发反向动画并移除路由
    } else {
      widget.controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: widget.child,
    );
  }
}
