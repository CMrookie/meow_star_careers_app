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
    // 卡面主色：按等级取色系（优劣一眼可辨），五档互不相同
    for (final level in ComplaintLevel.values) {
      expect(jobAccentColor(complaintLevelThresholds[level.index]), level.surface);
    }
    expect(ComplaintLevel.values.map((l) => l.surface).toSet().length, 5);
  });

  test('服务端下发的等级/口径/率优先于本地计算（单一来源）', () {
    final server = JobView.fromJson({
      'id': 't1',
      'companyId': 'c1',
      'companyName': '测试公司',
      'title': '测试职位',
      'description': 'd',
      'jobType': 'full_time',
      'isActive': true,
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
      'complaintsCount': 1,
      'companyStaffSize': 2000,
      // 服务端说「严重」（例如后端换了阈值）——客户端必须听服务端的
      'complaintLevel': 'severe',
      'complaintBasis': 'count',
      'complaintRatePercent': null,
    });
    final a = assessmentForJob(server);
    expect(a.level, ComplaintLevel.severe);
    expect(a.basis, ComplaintBasis.count);
    expect(a.badge, '投诉 1 次 · 严重');
    expect(
      jobAccentColor(server.complaintCount,
          staffSize: server.companyStaffSize, level: a.level),
      ComplaintLevel.severe.surface,
    );

    // 老后端 / 演示数据缺字段时，退回本地口径（1 次 / 2000 人 = 0.05% -> 轻微）
    final legacy = JobView.fromJson({
      'id': 't2',
      'companyId': 'c1',
      'companyName': '测试公司',
      'title': '测试职位',
      'description': 'd',
      'jobType': 'full_time',
      'isActive': true,
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
      'complaintsCount': 1,
      'companyStaffSize': 2000,
    });
    expect(assessmentForJob(legacy).level, ComplaintLevel.minor);
    expect(assessmentForJob(legacy).ratePercent, isNotNull);
    // 排序键同样优先用服务端等级
    final a2 = assessmentForJob(server);
    expect(jobSortKeyForJob(server).$1, a2.level.index);
  });

  test('规则文案由服务端阈值渲染（本地不存第二份数字）', () {
    const rules = ComplaintRuleSet(
      version: 'v9',
      levels: ['excellent', 'minor', 'alert', 'warning', 'severe'],
      minStaffSizeForRate: 100,
      rateThresholds: [1.0, 2.0, 4.0],
      countThresholds: [0, 2, 4, 8, 12],
    );
    expect(rules.countRange(1), '2 \u2013 3 次');
    expect(rules.countRange(4), '12 次及以上');
    expect(rules.rateRange(1), '\u2264 1.0%');
    expect(rules.rateRange(4), '> 4.0%');
    // 兜底规则与后端 v2 同值（区间文案与旧 range 一致）
    for (final level in ComplaintLevel.values) {
      expect(complaintRuleFallback.countRange(level.index), level.range);
    }
    expect(complaintRuleFallback.rateRange(1), '\u2264 0.5%');
  });

  testWidgets('规则页展示五个等级与定级依据', (tester) async {
    // 规则页现在每档有两枚徽标（率口径 + 次数兜底），内容更高；
    // 用更高的视口让 ListView 一次性建出全部五档，断言才拿得到「严重」。
    tester.view.physicalSize = const Size(390, 1800);
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
    // 新口径：分母是公司规模 + 小样本退回次数
    expect(find.textContaining('分母是公司规模'), findsOneWidget);
    expect(find.textContaining('只统计经平台审核通过的投诉'), findsOneWidget);
    expect(find.textContaining('小样本退回次数'), findsOneWidget);
    expect(find.textContaining('后续校准'), findsOneWidget);
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
    expect(await config.store.read(complaintRuleSeenKeyFor('v2')), '1');

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
    await config.store.write(complaintRuleSeenKeyFor('v2'), '1');
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

  test('按公司规模折算：同一次数在大公司是优秀/轻微，在小公司可以是严重', () {
    // 20 起投诉：2000 人 → 1.0% → 预警；60 人 → 33% → 严重
    final big = assessComplaints(complaints: 20, staffSize: 2000);
    expect(big.basis, ComplaintBasis.rate);
    expect(big.ratePercent, closeTo(1.0, 0.01));
    expect(big.level, ComplaintLevel.alert);

    final small = assessComplaints(complaints: 20, staffSize: 60);
    expect(small.level, ComplaintLevel.severe);

    // 规模越大越宽松：同样 3 起投诉
    expect(assessComplaints(complaints: 3, staffSize: 5000).level, ComplaintLevel.minor); // 0.06%
    expect(assessComplaints(complaints: 3, staffSize: 200).level, ComplaintLevel.alert); // 1.5% → 预警（含边界）
    expect(assessComplaints(complaints: 3, staffSize: 60).level, ComplaintLevel.severe); // 5%
  });

  test('率阈值边界：0.5% / 1.5% / 3%', () {
    // 1000 人规模下：5 起=0.5% 轻微；6 起=0.6% 预警；15 起=1.5% 预警；16 起=1.6% 警告；
    // 30 起=3.0% 警告；31 起=3.1% 严重
    expect(assessComplaints(complaints: 5, staffSize: 1000).level, ComplaintLevel.minor);
    expect(assessComplaints(complaints: 6, staffSize: 1000).level, ComplaintLevel.alert);
    expect(assessComplaints(complaints: 15, staffSize: 1000).level, ComplaintLevel.alert);
    expect(assessComplaints(complaints: 16, staffSize: 1000).level, ComplaintLevel.warning);
    expect(assessComplaints(complaints: 30, staffSize: 1000).level, ComplaintLevel.warning);
    expect(assessComplaints(complaints: 31, staffSize: 1000).level, ComplaintLevel.severe);
  });

  test('小样本 / 规模未知退回次数口径，并在徽标里标明口径', () {
    final unknown = assessComplaints(complaints: 3);
    expect(unknown.basis, ComplaintBasis.count);
    expect(unknown.ratePercent, isNull);
    expect(unknown.level, ComplaintLevel.alert); // 次数口径：3–5 → 预警
    expect(unknown.badge, '投诉 3 次 · 预警');
    expect(unknown.basisNote, contains('未申报规模'));

    final tiny = assessComplaints(complaints: 1, staffSize: 20);
    expect(tiny.basis, ComplaintBasis.count, reason: '不足 $minStaffSizeForRate 人时率不稳定，退回次数');
    expect(tiny.level, ComplaintLevel.minor);
    expect(tiny.basisNote, contains('小样本'));

    final rated = assessComplaints(complaints: 20, staffSize: 2000);
    expect(rated.badge, '投诉率 1.0% · 预警');
    expect(rated.basisNote, contains('每百人'));

    expect(assessComplaints(complaints: 0, staffSize: 2000).badge, '无投诉 · 优秀');
  });

  test('排序：先按等级（率口径），同级内有规模折算的排前面、率更小者靠前', () {
    JobView job(int c, int? staff, int daysAgo) => JobView(
          id: 'j$c-$staff-$daysAgo',
          companyId: 'c',
          companyName: '公司',
          title: '职位',
          description: '',
          jobType: 'full_time',
          isActive: true,
          createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
          updatedAt: DateTime.now(),
          complaintCount: c,
          companyStaffSize: staff,
        );
    final list = [
      job(20, 60, 1), // 33% → 严重
      job(20, 2000, 1), // 1.0% → 预警
      job(3, 200, 1), // 1.5% → 预警（与上一条同级，率更大）
      job(3, null, 1), // 次数口径 → 预警，但无规模 → 排在有规模的后面
      job(0, null, 5), // 优秀
    ]..sort(compareJobsByComplaintLevel);
    expect(list.map((j) => complaintLevelOf(j.complaintCount).label).toList(), isNotEmpty);
    expect(assessComplaints(complaints: list.first.complaintCount, staffSize: list.first.companyStaffSize).level,
        ComplaintLevel.excellent);
    expect(assessComplaints(complaints: list.last.complaintCount, staffSize: list.last.companyStaffSize).level,
        ComplaintLevel.severe);
    // 同为「预警」的三条：有规模的（1.0%）在前，没规模的（次数口径）在后
    final alerts = list.where((j) =>
        assessComplaints(complaints: j.complaintCount, staffSize: j.companyStaffSize).level ==
        ComplaintLevel.alert).toList();
    expect(alerts.length, 3);
    expect(alerts.first.companyStaffSize, isNotNull);
    expect(alerts.last.companyStaffSize, isNull);
  });
}
