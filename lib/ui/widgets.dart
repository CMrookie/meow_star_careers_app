import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/format.dart';
import '../models/models.dart';
import 'theme.dart';

/// 通用小组件与弹窗。

Widget loadingView({String? text}) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(strokeWidth: 2.5),
          if (text != null) ...[
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(color: textHint, fontSize: 13)),
          ],
        ],
      ),
    );

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyView({super.key, this.icon = Icons.inbox_outlined, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: const Color(0xFFD5D9E0)),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: textSub)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: textHint)),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 56, color: Color(0xFFD5D9E0)),
            const SizedBox(height: 12),
            Text(friendlyError(error), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: textSub)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重试'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(140, 40)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 通用卡片：白底（或自定义底色/渐变）+ 大圆角 + 柔和投影，可点击。
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color color;
  final Gradient? gradient;
  final List<BoxShadow>? shadow;
  final double radius;
  final BoxBorder? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color = Colors.white,
    this.gradient,
    this.shadow,
    this.radius = radiusCard,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: shadow ?? (gradient == null && color == Colors.white ? softShadow : null),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 职位卡右上角的「胶囊凹口」裁剪器。
///
/// 轮廓（由相切圆弧 + 一段直边构成，连续无折角）：
/// 1. 顶边平直 → **外凸圆角**（[filletRadius]）拐下；
/// 2. 竖直「墙」：位于胶囊左缘外 [gap] 处，一直下到**胶囊纵向中线**；
/// 3. 从纵向中线开始才是**内凹弧**（圆心 = 胶囊圆帽圆心、半径 = 圆帽半径 + [gap]）——
///    即在胶囊纵向中位开始与胶囊左侧贴合，绕过圆帽下半圈收进底线；
/// 4. 水平底线（= 胶囊底边 + gap）→ 右缘侧**外凸圆角**收进卡面右缘。
///
/// 因为凹弧与胶囊同心等距，胶囊左侧与下方的留白完全一致（各 [gap]），胶囊有充足容身位置。
///
/// [fill] 用于打开动画：0 = 完整凹口，1 = 凹口被填平（退化成普通圆角矩形）。
class SmoothNotchClipper extends CustomClipper<Path> {
  /// 两端外凸圆角半径（顶边侧与右缘侧一致）
  final double filletRadius;

  /// 胶囊左端圆帽半径（凹弧半径 = 本值 + [gap]）
  final double capRadius;

  /// 凹口与胶囊的等距间距
  final double gap;

  /// 凹口底线距卡面顶边（= 胶囊底边 + gap）
  final double slotDepth;

  /// 胶囊左端圆帽圆心距卡面右缘
  final double capCenterInset;

  /// 胶囊左端圆帽圆心距卡面顶边
  final double capCenterTop;

  /// 卡片圆角
  final double cornerRadius;

  /// 凹口填充进度（0 = 打开，1 = 填平）
  final double fill;

  const SmoothNotchClipper({
    this.filletRadius = notchFillet,
    this.capRadius = notchPillHeight / 2,
    this.gap = notchGap,
    this.slotDepth = notchSlotDepth,
    this.capCenterInset = notchPillRightInset + notchPillWidth - notchPillHeight / 2,
    this.capCenterTop = notchPillTop + notchPillHeight / 2,
    this.cornerRadius = jobCardRadius,
    this.fill = 0,
  });

  /// 凹弧半径（与胶囊圆帽同心等距）
  double get notchArcRadius => capRadius + gap;

  /// 凹口左侧「墙」距卡面右缘的距离 = 胶囊左缘 + gap（= 凹弧最左处，位于胶囊纵向中线上）
  double wallInset(Size size) => capCenterInset + notchArcRadius;

  /// 顶边结束点距卡面右缘的距离（= 墙 + 外凸圆角半径，顶边在墙左侧收住）
  double topEdgeInset(Size size) => wallInset(size) + filletRadius;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final k = (1 - fill).clamp(0.0, 1.0);
    final path = Path();

    path.moveTo(0, cornerRadius);
    path.arcToPoint(Offset(cornerRadius, 0), radius: Radius.circular(cornerRadius));

    if (k <= 0.02) {
      // 凹口已填平：普通圆角矩形（详情页头部形态）
      path.lineTo(w - cornerRadius, 0);
      path.arcToPoint(Offset(w, cornerRadius), radius: Radius.circular(cornerRadius));
    } else {
      final rf = filletRadius * k;
      final r = notchArcRadius * k;
      final cy = capCenterTop;            // 胶囊纵向中线（= 凹弧圆心 y）
      final cx = w - capCenterInset;      // 胶囊圆帽圆心 x
      final xw = w - (capCenterInset + notchArcRadius) * k; // 左侧「墙」：与胶囊左缘等距
      final bottomY = cy + r;             // 凹口底线（= 胶囊底 + gap）

      // 顶边 → 外凸圆角（与顶边、与「墙」都相切）
      path.lineTo(xw - rf, 0);
      path.arcToPoint(Offset(xw, rf), radius: Radius.circular(rf));
      // 「墙」直边向下到胶囊纵向中线
      path.lineTo(xw, cy);
      // 内凹弧：自纵向中线起（与墙相切、切点即最左处）绕过胶囊帽下半圈到底线
      path.arcToPoint(
        Offset(cx, bottomY),
        radius: Radius.circular(r),
        clockwise: false,
      );
      // 底线 → 右缘侧外凸圆角
      path.lineTo(w - rf, bottomY);
      path.arcToPoint(Offset(w, bottomY + rf), radius: Radius.circular(rf));
    }

    path.lineTo(w, h - cornerRadius);
    path.arcToPoint(Offset(w - cornerRadius, h), radius: Radius.circular(cornerRadius));
    path.lineTo(cornerRadius, h);
    path.arcToPoint(Offset(0, h - cornerRadius), radius: Radius.circular(cornerRadius));
    path.lineTo(0, cornerRadius);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant SmoothNotchClipper oldClipper) =>
      oldClipper.filletRadius != filletRadius ||
      oldClipper.capRadius != capRadius ||
      oldClipper.gap != gap ||
      oldClipper.slotDepth != slotDepth ||
      oldClipper.capCenterInset != capCenterInset ||
      oldClipper.capCenterTop != capCenterTop ||
      oldClipper.cornerRadius != cornerRadius ||
      oldClipper.fill != fill;
}

/// 带「槽口轮廓」的卡片容器：用 [PhysicalShape] 按 clipper 裁剪卡面，
/// 阴影由 Skia 沿裁剪路径绘制（因此会完美跟随缺口形状），
/// overlay 中的元素（通常用 Positioned）悬浮在缺口上方、不参与裁剪。
class NotchedSurface extends StatelessWidget {
  final CustomClipper<Path> clipper;
  final Color color;
  final Widget child;

  /// 悬浮层（缺口里的胶囊按钮等），需自行定位
  final List<Widget> overlay;

  /// 阴影高度（越大越"浮起"）
  final double elevation;

  /// 阴影颜色（缺省为同色系发光）
  final Color? shadowColor;

  const NotchedSurface({
    super.key,
    required this.clipper,
    required this.color,
    required this.child,
    this.overlay = const <Widget>[],
    this.elevation = 15,
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      // 阴影需要溢出卡片边界，故不裁剪
      clipBehavior: Clip.none,
      children: [
        PhysicalShape(
          clipper: clipper,
          color: color,
          elevation: elevation,
          shadowColor: shadowColor ?? color.withValues(alpha: 0.4),
          // 注意：PhysicalShape 默认 clipBehavior 是 Clip.none，
          // 那样只有形状层自己按路径上色、子节点（如白色薪资栏）会溢出成直角。
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        ...overlay,
      ],
    );
  }
}

/// 圆形首字头像（默认品牌蓝底白字；传入浅色底时自动改用深色字）
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const Avatar({super.key, required this.name, this.size = 40, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? brandColor;
    final fg = color == null
        ? Colors.white
        : (ThemeData.estimateBrightnessForColor(c) == Brightness.dark ? Colors.white : brandDeep);
    final letter = name.isEmpty ? '?' : name.characters.first;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(letter,
          style: TextStyle(color: fg, fontSize: size * 0.42, fontWeight: FontWeight.w700)),
    );
  }
}

/// 彩色胶囊标签（filled=实心彩色；否则为同色淡底）
class TagChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;
  final IconData? icon;
  const TagChip(this.label, {super.key, this.color = brandColor, this.filled = false, this.icon});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: icon == null ? 10 : 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: fg), const SizedBox(width: 4)],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡片内使用的半透明胶囊（用于彩色卡片上的白字标签）
class GlassPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final double backgroundAlpha;
  const GlassPill(this.label, {super.key, this.icon, this.color = Colors.white, this.backgroundAlpha = 0.15});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundAlpha),
        borderRadius: BorderRadius.circular(radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SectionCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: padding,
      child: child,
    );
  }
}

/// 标题栏（区块标题）
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 18,
            decoration: BoxDecoration(color: brandColor, borderRadius: BorderRadius.circular(radiusPill)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textMain)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 关键值-标签行
class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const KeyValueRow(this.label, this.value, {super.key, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 84, child: Text(label, style: const TextStyle(fontSize: 14, color: textSub))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: highlight ? brandColor : textMain,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 列表项
class ListItem extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const ListItem({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(radiusControl),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textMain)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: const TextStyle(fontSize: 12, color: textHint)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// 通用内容列表容器：白底大圆角 + 柔和投影，内含若干 ListItem，行间带分割线。
class ListGroup extends StatelessWidget {
  final List<Widget> children;
  const ListGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: surfaceDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: children[i]),
          ],
        ],
      ),
    );
  }
}

// ---------- 弹窗/提示工具 ----------

Future<bool> confirmDialog(BuildContext context, {required String title, String? message, String confirmText = '确定', Color? confirmColor}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText, style: TextStyle(color: confirmColor ?? Colors.red)),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? const Color(0xFFE5484D) : const Color(0xFF323539),
      duration: const Duration(seconds: 2),
    ));
}

void showErrorSnack(BuildContext context, Object error) {
  showToast(context, friendlyError(error), error: true);
}

/// 执行异步动作，自动带 loading 与错误提示。
Future<void> runAction(
  BuildContext context,
  Future<void> Function() action, {
  String? loadingText,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    duration: const Duration(days: 1),
    backgroundColor: const Color(0xFF323539),
    content: Row(children: [
      const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
      const SizedBox(width: 16),
      Expanded(child: Text(loadingText ?? '处理中…', style: const TextStyle(fontSize: 14))),
    ]),
  ));
  try {
    await action();
  } catch (e) {
    messenger.hideCurrentSnackBar();
    if (context.mounted) showErrorSnack(context, e);
    rethrow;
  } finally {
    messenger.hideCurrentSnackBar();
  }
}

/// 薪资文案（复用 format 语义，供组件直接使用）
String fmtSalary(JobView job) => salaryText(job.salaryMin, job.salaryMax);

/// 状态色
Color statusColor(String status) {
  switch (status) {
    case 'pending':
      return warmOrange;
    case 'viewed':
      return const Color(0xFF5B8DEF);
    case 'interviewing':
      return brandColor;
    case 'offered':
      return accentGreen;
    case 'rejected':
      return const Color(0xFFE5484D);
    case 'withdrawn':
      return textHint;
    default:
      return textHint;
  }
}

/// 状态标签 chip（投递用）
class StatusTag extends StatelessWidget {
  final String status;
  const StatusTag(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    return TagChip(applicationStatusLabel(status), color: statusColor(status), filled: true);
  }
}
