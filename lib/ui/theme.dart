import 'package:flutter/material.dart';

import 'complaint_level.dart';

/// 品牌色：招聘蓝（作为 M3 种子色，主题内其余颜色均由 colorScheme 派生）
const brandColor = Color(0xFF3B6CF6);
const brandDeep = Color(0xFF2A4FD6);
const accentGreen = Color(0xFF07C160);
const warmOrange = Color(0xFFFF8F1F);
const accentViolet = Color(0xFF7A5AF8);
const accentRed = Color(0xFFE5484D);

/// 轻量中性色（兼容旧页面硬编码场景；新代码优先取 colorScheme 语义色）
const textMain = Color(0xFF1C1B1F);
const textSub = Color(0xFF5F6368);
const textHint = Color(0xFF8B9199);
const bgPage = Color(0xFFF1F4FA);
const cardLine = Color(0xFFE6E8EC);

// ---------- 设计令牌（对齐「彩色大圆角卡片」视觉语言） ----------

/// 卡片 / 弹层圆角
const double radiusCard = 24;

/// 输入框 / 次级面板圆角
const double radiusControl = 16;

/// 卡片内部小块（logo、图标底）圆角
const double radiusInner = 12;

/// 胶囊标签 / 胶囊按钮（全圆角）
const double radiusPill = 999;

/// 白卡柔和投影
const List<BoxShadow> softShadow = <BoxShadow>[
  BoxShadow(color: Color(0x14202A44), blurRadius: 18, offset: Offset(0, 8)),
  BoxShadow(color: Color(0x0A202A44), blurRadius: 4, offset: Offset(0, 2)),
];

/// 彩色卡片投影：与卡片同色，营造"浮起"的层次
List<BoxShadow> tintedShadow(
  Color color, {
  double alpha = 0.30,
  double blur = 15,
  Offset offset = const Offset(0, 8),
}) =>
    <BoxShadow>[BoxShadow(color: color.withValues(alpha: alpha), blurRadius: blur, offset: offset)];

/// 通用面板装饰：白底大圆角 + 柔和投影
BoxDecoration surfaceDecoration({
  Color color = Colors.white,
  bool shadow = true,
  double radius = radiusCard,
  BoxBorder? border,
}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border,
      boxShadow: shadow ? softShadow : null,
    );

// ---------- 缺口凹槽几何（裁剪器与胶囊必须共用同一组常量，凹槽才能与胶囊等距同心） ----------

/// 「查看」胶囊距卡顶：0 = 胶囊顶与卡片顶边齐平
const double notchPillTop = 0;

/// 「查看」胶囊距卡面右缘
const double notchPillRightInset = 12;

/// 「查看」胶囊宽度（固定尺寸，保证凹槽与胶囊严格同步）
const double notchPillWidth = 72;

/// 「查看」胶囊高度（圆帽半径 = 高度 / 2；加高后胶囊更饱满）
const double notchPillHeight = 42;

/// 凹口与胶囊之间的等距间距（凹弧半径 = 胶囊圆帽半径 + 本值 → 与胶囊同心等距，
/// 胶囊四周（左侧与下方）留白完全一致）
const double notchGap = 8;

/// 缺口两端外凸过渡弧半径：顶边侧与右缘侧取同一值，两处圆角观感一致
const double notchFillet = 16;

/// 「查看」胶囊水平中线距卡面右缘（顶边过渡进内凹弧的拐点应落在这条线附近）
const double notchSlotInset = notchPillRightInset + notchPillWidth / 2;

/// 凹口底线距卡面顶边 = 胶囊底边 + 间距
const double notchSlotDepth = notchPillTop + notchPillHeight + notchGap;

/// 内凹弧半径 = 胶囊圆帽半径 → 内凹弧与「查看」曲率一致
const double notchNotchRadius = notchPillHeight / 2;

/// 职位卡自身圆角
const double jobCardRadius = 20;

/// 卡面内容右侧内缩量（避让槽口，留 6px 余量）
const double notchContentInset = notchSlotInset + 6;

/// 卡面内容右侧内缩量（避让凹槽，留 6px 余量）

/// 缺口里的浅色胶囊（缺口处露出页面底色，用浅蓝底 + 深蓝字保证可读）
const notchPillBg = Color(0xFFC4D0FF);
const notchPillFg = Color(0xFF1A2B6B);

// ---------- 职位卡片配色 ----------

/// 职位卡片主色：**按投诉等级取色系**（优劣一眼可辨）
/// 优秀=绿系 / 轻微=蓝系 / 预警=琥珀系 / 警告=橙红系 / 严重=红系。
/// [level] 由调用方用 [assessmentForJob] 取（**服务端下发的等级优先**）；
/// 不传时退回本地口径计算（演示模式 / 老后端）。
/// 用工类型（全职、兼职、项目、实习）与远程等分类不再影响颜色，改为卡内标签标识。
Color jobAccentColor(int complaintCount, {int? staffSize, ComplaintLevel? level}) =>
    (level ?? assessComplaints(complaints: complaintCount, staffSize: staffSize).level).surface;

/// 卡面渐变的深色端（同样优先用服务端等级）
Color jobAccentDeep(int complaintCount, {int? staffSize, ComplaintLevel? level}) =>
    (level ?? assessComplaints(complaints: complaintCount, staffSize: staffSize).level)
        .surfaceDeep;

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandColor,
    primary: brandColor,
    // 轻微偏冷的表面，贴近默认 M3 light surface
    brightness: Brightness.light,
  ).copyWith(surface: Colors.white);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bgPage,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: textMain,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: textMain),
    ),
    dividerTheme: const DividerThemeData(color: cardLine, thickness: 1, space: 1),
    // Material 3 底部导航（NavigationBar）：胶囊选中态
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: Colors.white,
      indicatorColor: brandColor.withValues(alpha: 0.12),
      indicatorShape: const StadiumBorder(),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textSub),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: brandColor);
        }
        return const IconThemeData(color: textHint);
      }),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 3,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x1A26314D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      // 白底 + 细描边：在白色 AppBar / 白卡与浅灰页面上都能区分为「输入框」
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: textHint, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: const BorderSide(color: cardLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: const BorderSide(color: cardLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusControl),
        borderSide: const BorderSide(color: brandColor, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandColor,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: brandColor,
        side: const BorderSide(color: brandColor, width: 1.4),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: brandColor,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: brandColor,
      shape: StadiumBorder(),
      side: BorderSide.none,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textMain),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
      titleTextStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textMain),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF323539),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusControl)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(radiusCard + 4)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: brandColor),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: brandColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusControl + 2)),
    ),
  );
}
