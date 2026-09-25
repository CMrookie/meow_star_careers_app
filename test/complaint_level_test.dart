import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:meow_star_careers_app/app.dart';
import 'package:meow_star_careers_app/core/app_config.dart';
import 'package:meow_star_careers_app/state/session.dart';
import 'package:meow_star_careers_app/models/models.dart';
import 'package:meow_star_careers_app/ui/complaint_level.dart';
import 'package:meow_star_careers_app/ui/paged_list_view.dart';
import 'package:meow_star_careers_app/ui/complaint_rules_page.dart';
import 'package:meow_star_careers_app/ui/theme.dart';

void main() {
  test('投诉次数 → 等级：阈值 0 / 1 / 3 / 6 / 10', () {
    expect(complaintLevelOf(0), ComplaintLevel.excellent);
    expect(complaintLevelOf(-1), ComplaintLevel.excellent);
    expect(complaintLevelOf(1), ComplaintLevel.minor);
    expect(complaintLevelOf(2), ComplaintLevel.minor);
    expect(complaintLevelOf(3), ComplaintLevel.alert);
    expect(complaintLevelOf(5), ComplaintLevel.alert);
    expect(complaintLevelOf(6), ComplaintLevel.warning);
    expect(complaintLevelOf(9), ComplaintLevel.warning);
    expect(complaintLevelOf(10), ComplaintLevel.severe);
    expect(complaintLevelOf(99), ComplaintLevel.severe);
    // 阈值表与判定函数一致
    expect(complaintLevelThresholds, <int>[0, 1, 3, 6, 10]);
    for (final level in ComplaintLevel.values) {
      expect(complaintLevelOf(complaintLevelThresholds[level.index]), level);
    }
  });

  test('五个等级：名称、颜色互不相同且严重度递增（绿→蓝→橙黄→橙红→红）', () {
    expect(ComplaintLevel.values.map((l) => l.label).toList(), <String>[
      '优秀',
      '轻微',
      '预警',
      '警告',
      '严重',
    ]);
    final colors = ComplaintLevel.values.map((l) => l.color).toSet();
    expect(colors.length, ComplaintLevel.values.length, reason: '五个等级颜色应各不相同');
    // 直觉色：绿色通道递减、红色通道递增
    int r(ComplaintLevel l) => (l.color.r * 255).round();
    int g(ComplaintLevel l) => (l.color.g * 255).round();
    expect(r(ComplaintLevel.excellent), lessThan(r(ComplaintLevel.severe)));
    expect(g(ComplaintLevel.excellent), greaterThan(g(ComplaintLevel.severe)));
    // 降饱和系数随等级单调不减
    for (var i = 1; i < ComplaintLevel.values.length; i++) {
      expect(
        ComplaintLevel.values[i].dimFactor,
        greaterThanOrEqualTo(ComplaintLevel.values[i - 1].dimFactor),
      );
    }
    // 卡面主色：投诉越多越暗
    expect(
      jobAccentColor('full_time', 20).computeLuminance(),
      lessThan(jobAccentColor('full_time', 0).computeLuminance()),
    );
  });

  testWidgets('规则页展示五个等级与定级依据', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const ComplaintRulesPage()),
    );
    await tester.pumpAndSettle();

    for (final level in ComplaintLevel.values) {
      expect(
        find.text(level.label),
        findsWidgets,
        reason: '缺少等级 ${level.label}',
      );
      expect(
        find.text(level.range),
        findsWidgets,
        reason: '缺少区间 ${level.range}',
      );
    }
    expect(find.text('定级依据'), findsWidgets);
    expect(find.textContaining('只统计经平台审核通过的投诉'), findsOneWidget);
    expect(find.textContaining('局限与校准'), findsOneWidget);
  });

  testWidgets('首次提示弹窗：列出五档并可跳到完整规则页', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(body: Center(child: ComplaintRuleDialog())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('投递前，先看一眼投诉等级'), findsOneWidget);
    for (final level in ComplaintLevel.values) {
      expect(find.text(level.label), findsWidgets);
      expect(find.text(level.range), findsWidgets);
    }
    await tester.tap(find.text('查看完整规则'));
    await tester.pumpAndSettle();
    expect(find.text('投诉等级规则'), findsWidgets);
  });

  testWidgets('首次进入 App 弹出规则提示，看过之后不再弹', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final config = AppConfig(MemorySettingsStore());
    final session = SessionController(config: config);
    await session.init();
    await tester.pumpWidget(
      AppScope(controller: session, child: const JustWorkApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('求职者演示账号'));
    await tester.pumpAndSettle();

    // 首次进入：提示出现，并列出五档
    expect(find.text('投递前，先看一眼投诉等级'), findsOneWidget);
    for (final level in ComplaintLevel.values) {
      expect(find.text(level.label), findsWidgets);
    }
    await tester.tap(find.text('我知道了'));
    await tester.pumpAndSettle();
    expect(find.text('投递前，先看一眼投诉等级'), findsNothing);
    // 本地已记录
    expect(await config.store.read(complaintRuleSeenKey), '1');

    session.dispose();
  });

  test('职位列表排序：按等级由优到劣，同级按次数、最后按时间', () {
    JobView job(int complaints, int daysAgo) => JobView(
      id: 'j$complaints-$daysAgo',
      companyId: 'c',
      companyName: '公司',
      title: '职位',
      description: '',
      jobType: 'full_time',
      isActive: true,
      createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
      updatedAt: DateTime.now(),
      complaintCount: complaints,
    );

    final list = [
      job(20, 1), // 严重
      job(0, 5), // 优秀
      job(3, 2), // 预警
      job(1, 1), // 轻微
      job(6, 3), // 警告
      job(0, 1), // 优秀（更新）
    ]..sort(compareJobsByComplaintLevel);

    expect(list.map((j) => j.complaintCount).toList(), <int>[
      0,
      0,
      1,
      3,
      6,
      20,
    ], reason: '应先优秀、再轻微/预警/警告/严重');
    // 同为优秀时，更新时间更近的排前面
    expect(list.first.createdAt.isAfter(list[1].createdAt), isTrue);
    // 等级分组与阈值一致
    expect(
      list.map((j) => complaintLevelOf(j.complaintCount).label).toList(),
      <String>['优秀', '优秀', '轻微', '预警', '警告', '严重'],
    );
  });

  testWidgets('职位列表页：最优等级排在最前（演示数据）', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final config = AppConfig(MemorySettingsStore());
    await config.store.write(complaintRuleSeenKey, '1');
    final session = SessionController(config: config);
    await session.init();
    await tester.pumpWidget(
      AppScope(controller: session, child: const JustWorkApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('求职者演示账号'));
    await tester.pumpAndSettle();

    final cards = find.byWidgetPredicate(
      (w) => w is JobCardSurface && w.notchFill == 0,
    );
    final counts = cards
        .evaluate()
        .map((e) => (e.widget as JobCardSurface).job.complaintCount)
        .toList();
    expect(counts, isNotEmpty);
    expect(
      counts,
      orderedEquals(List<int>.of(counts)..sort()),
      reason: '列表应按投诉等级（次数）由优到劣排列，实际顺序：$counts',
    );
    expect(counts.first, 0, reason: '最前面应是零投诉的「优秀」单位');

    session.dispose();
  });
}
