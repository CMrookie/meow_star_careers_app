import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:just_a_work_app/app.dart';
import 'package:just_a_work_app/core/app_config.dart';
import 'package:just_a_work_app/models/models.dart';
import 'package:just_a_work_app/state/session.dart';
import 'package:just_a_work_app/ui/complaint_level.dart';
import 'package:just_a_work_app/ui/jobs/job_open_transition.dart';
import 'package:just_a_work_app/ui/paged_list_view.dart';
import 'package:just_a_work_app/ui/theme.dart';
import 'package:just_a_work_app/ui/widgets.dart';

JobView _job({
  String title = '资深 Flutter 工程师',
  String companyName = '示例科技',
  String description = '负责跨端 App 的架构与体验优化，与产品、设计紧密协作。',
  String jobType = 'full_time',
  int complaintCount = 0,
  int? salaryMin = 25000,
  int? salaryMax = 40000,
  bool isActive = true,
}) =>
    JobView(
      id: 'job-1',
      companyId: 'company-1',
      companyName: companyName,
      title: title,
      description: description,
      location: '广东 · 深圳市',
      salaryMin: salaryMin,
      salaryMax: salaryMax,
      jobType: jobType,
      experience: '3-5 年',
      education: '本科',
      isActive: isActive,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now(),
      complaintCount: complaintCount,
    );

Future<void> _pumpCard(WidgetTester tester, Widget card, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    home: Scaffold(body: ListView(children: [card])),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('职位卡片：卡面信息 + 白色薪资栏 + 槽口里的「查看」胶囊', (tester) async {
    var tapped = false;
    await _pumpCard(tester, JobCard(job: _job(), onTap: () => tapped = true));

    expect(find.text('资深 Flutter 工程师'), findsOneWidget);
    expect(find.text('示例科技'), findsOneWidget);
    expect(find.text('广东 · 深圳市'), findsOneWidget);
    expect(find.text('全职'), findsOneWidget);
    expect(find.textContaining('发布于'), findsOneWidget);
    expect(find.text('25K-40K'), findsOneWidget);
    expect(find.text('查看'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_outward), findsOneWidget);

    // 凹口裁剪器：凹弧与胶囊同心等距、拐点落在胶囊中线附近
    final shape = tester.widget<PhysicalShape>(find.byType(PhysicalShape));
    final clipper = shape.clipper as SmoothNotchClipper;
    expect(clipper.filletRadius, notchFillet);
    expect(clipper.capRadius, notchPillHeight / 2);
    expect(clipper.gap, notchGap);
    expect(clipper.notchArcRadius, notchPillHeight / 2 + notchGap, reason: '凹弧半径 = 圆帽半径 + 间距');
    expect(clipper.cornerRadius, jobCardRadius);
    expect(clipper.fill, 0);
    expect(shape.clipBehavior, Clip.antiAlias);
    expect(shape.elevation, greaterThan(0));

    final cardRect = tester.getRect(find.byType(PhysicalShape));
    final size = Size(cardRect.width, cardRect.height);
    final pillRect = tester.getRect(
      find.ancestor(of: find.text('查看'), matching: find.byType(Container)).first,
    );
    expect(pillRect.right, closeTo(cardRect.right - notchPillRightInset, 0.01));
    expect(pillRect.top, closeTo(cardRect.top + notchPillTop, 0.01));

    // 顶边结束点 = 墙 - 外凸圆角；贴合自胶囊纵向中线开始
    final wall = clipper.wallInset(size);
    expect(clipper.topEdgeInset(size), closeTo(wall + notchFillet, 0.01),
        reason: '顶边结束点比「墙」再往左一个圆角半径');
    expect(wall - (notchPillRightInset + notchPillWidth), closeTo(notchGap, 0.01),
        reason: '胶囊左侧应留出与下方一致的间距');

    // 纵向中线以上是「墙」（直边），中线以下才转成贴胶囊的内凹弧
    final path = clipper.getClip(size);
    final cy = clipper.capCenterTop;
    final xw = size.width - wall;
    expect(path.contains(Offset(xw - 3, cy - 8)), isTrue, reason: '中线上方墙左侧是卡面');
    expect(path.contains(Offset(xw + 5, cy - 8)), isFalse, reason: '中线上方墙右侧是凹口');
    expect(path.contains(Offset(xw + 1, cy + 12)), isTrue, reason: '中线以下凹弧向右收，卡面回到墙右侧');
    expect(path.contains(Offset(xw + 6, cy + 12)), isFalse, reason: '凹弧内侧仍是凹口');
    // 胶囊本体（圆帽圆心、右端）都在凹口内
    expect(path.contains(Offset(size.width - clipper.capCenterInset, cy)), isFalse,
        reason: '胶囊左端圆帽处应处于凹口内');
    expect(path.contains(Offset(size.width - notchPillRightInset - 2, cy)), isFalse,
        reason: '胶囊右端应处于凹口内');

    await tester.tap(find.text('资深 Flutter 工程师'));
    expect(tapped, isTrue);
  });

  testWidgets('职位卡片：极窄屏 + 超长文案不溢出', (tester) async {
    await _pumpCard(
      tester,
      JobCard(
        job: _job(
          title: '超长职位名称超长职位名称超长职位名称超长职位名称超长职位名称',
          companyName: '某某某（中国）互联网科技集团股份有限公司某某某分公司',
          description: '这是一段非常长的职位描述，' * 8,
        ),
      ),
      size: const Size(320, 720),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('查看'), findsOneWidget);
  });

  testWidgets('职位卡片：投诉次数 / 下架状态 / 招聘者自定义操作', (tester) async {
    await _pumpCard(tester, JobCard(job: _job(complaintCount: 3, isActive: false)));
    expect(find.text('投诉 3 次 · 预警'), findsOneWidget, reason: '卡面徽标应带投诉等级');
    expect(find.text('已下架'), findsOneWidget);

    await _pumpCard(
      tester,
      JobCard(job: _job(), trailing: const Icon(Icons.more_vert, color: notchPillFg)),
    );
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.text('查看'), findsNothing);
  });

  test('凹口裁剪器：自胶囊纵向中线起贴合、凹弧与胶囊同心等距、可填平', () {
    const clipper = SmoothNotchClipper();
    const size = Size(336, 300);
    final path = clipper.getClip(size);
    final w = size.width;
    final h = size.height;
    final rf = clipper.filletRadius;
    final r = clipper.notchArcRadius;
    final cy = clipper.capCenterTop;
    final cx = w - clipper.capCenterInset;
    final xw = w - clipper.wallInset(size);
    final bottomY = cy + r;

    // 1) 顶边 → 外凸圆角：顶边止于墙 - rf
    expect(path.contains(Offset(xw - rf - 4, 1)), isTrue, reason: '顶边结束点左侧是卡面');
    expect(path.contains(Offset(xw - rf + 8, 1)), isFalse, reason: '顶边结束点之后已进入圆角');
    // 2) 墙：纵向中线以上是竖直直边
    expect(path.contains(Offset(xw - 3, cy - 10)), isTrue, reason: '墙左侧是卡面');
    expect(path.contains(Offset(xw + 4, cy - 10)), isFalse, reason: '墙右侧是凹口');
    // 3) 纵向中线 = 贴合起点：中线以下凹弧向右收（卡面重新出现在墙右侧）
    expect(path.contains(Offset(xw + 2, cy + 14)), isTrue, reason: '中线以下卡面回到墙右侧');
    expect(path.contains(Offset(xw + 9, cy + 14)), isFalse, reason: '凹弧内侧仍是凹口');
    // 4) 凹弧与胶囊同心等距 → 圆帽圆心与右端都在凹口内，弧外一圈是卡面
    expect(path.contains(Offset(cx, cy)), isFalse, reason: '胶囊圆帽圆心应在凹口内');
    expect(path.contains(Offset(cx - r - 4, cy)), isTrue, reason: '凹弧外（左侧）是卡面');
    expect(path.contains(Offset(cx, bottomY - 3)), isFalse, reason: '底线之上仍是凹口');
    expect(path.contains(Offset(cx, bottomY + 3)), isTrue, reason: '底线之下是卡面');
    // 5) 右缘侧外凸圆角与卡片圆角
    expect(path.contains(Offset(w - 2, bottomY - 2)), isFalse);
    expect(path.contains(Offset(w - 2, bottomY + rf + 3)), isTrue);
    expect(path.contains(const Offset(2, 2)), isFalse);
    expect(path.contains(Offset(w - 2, h - 2)), isFalse);
    expect(path.contains(Offset(w / 2, h / 2)), isTrue);
    // 6) 参数关系
    expect(clipper.gap, notchGap);
    expect(r, notchPillHeight / 2 + notchGap);
    expect(clipper.wallInset(size) - (notchPillRightInset + notchPillWidth), closeTo(notchGap, 0.01));

    // 填充方式：自内凹角向外扫过 —— 半程时近处已填、远处（右上角）仍是缺口
    const half = SmoothNotchClipper(fill: 0.5);
    final halfPath = half.getClip(size);
    expect(halfPath.contains(Offset(w - 84, 13)), isTrue,
        reason: '内凹角附近（缺口内 8px 处）应已被填上');
    expect(halfPath.contains(Offset(w - 6, 6)), isFalse,
        reason: '远处的右上角缺口应还没填到');
    // 缺口轮廓没被缩放：凹弧半径仍是胶囊圆帽半径 + gap，墙的位置也不变
    expect(half.notchArcRadius, clipper.notchArcRadius, reason: '凹弧半径不随填充变化（胶囊效果沿用）');
    expect(half.wallInset(size), clipper.wallInset(size));
    expect(half.capCenterTop, clipper.capCenterTop);

    // 填平后：凹口消失、右上角变成普通圆角
    const filled = SmoothNotchClipper(fill: 1);
    final flat = filled.getClip(size);
    expect(flat.contains(Offset(w - 20, 30)), isTrue, reason: '填平后原凹口位置应是卡面');
    expect(flat.contains(Offset(w - 4, 4)), isFalse, reason: '填平后右上角是圆角');
  });

  test('职位卡片主色：按用工类型区分色相，投诉越多越暗淡', () {
    expect(jobAccentColor('full_time', 0), brandColor);
    expect(jobAccentColor('part_time', 0), warmOrange);
    expect(jobAccentColor('contract', 0), accentViolet);
    expect(jobAccentColor('intern', 0), accentGreen);

    final clean = jobAccentColor('full_time', 0);
    final complained = jobAccentColor('full_time', 10);
    expect(complained, isNot(clean));
    expect(complained.computeLuminance(), lessThan(clean.computeLuminance()));
  });

  testWidgets('打开动画：飞行层首尾与卡片/详情页头部严丝合缝（无跳动）', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 44);
    addTearDown(tester.view.reset);

    final config = AppConfig(MemorySettingsStore());
    await config.store.write(complaintRuleSeenKey, '1'); // 跳过首次规则提示
    final session = SessionController(config: config);
    await session.init();
    await tester.pumpWidget(AppScope(controller: session, child: const JustWorkApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('求职者演示账号'));
    await tester.pumpAndSettle();

    final cardFinder = find.byWidgetPredicate((w) => w is JobCardSurface && w.notchFill == 0);
    expect(cardFinder, findsWidgets);
    final cardRect = tester.getRect(cardFinder.first);
    final title = tester.widget<JobCardSurface>(cardFinder.first).job.title;

    await tester.tap(cardFinder.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1)); // t≈0：飞行层应贴合列表卡面
    final flight = find.byKey(jobFlightKey);
    expect(flight, findsOneWidget);
    expect(tester.getRect(flight).left, closeTo(cardRect.left, 1.5));
    expect(tester.getRect(flight).top, closeTo(cardRect.top, 1.5));
    expect(tester.getRect(flight).width, closeTo(cardRect.width, 1.5));

    // 接近结束：标题的纵向位置
    await tester.pump(const Duration(milliseconds: 440));
    final nearEndDy = tester
        .getTopLeft(find.descendant(of: find.byKey(jobFlightKey), matching: find.text(title)))
        .dy;

    await tester.pumpAndSettle();
    final header = find.byWidgetPredicate(
        (w) => w is JobCardSurface && w.notchFill == 1 && w.key != jobFlightKey);
    expect(header, findsOneWidget);
    final headerRect = tester.getRect(header);
    expect(headerRect.left, 0);
    expect(headerRect.top, 0);
    expect(headerRect.width, 390);
    expect(headerRect.height, closeTo(cardRect.height + 44, 1), reason: '头部高度 = 卡面高 + 状态栏');
    final settledDy = tester
        .getTopLeft(find.descendant(of: header, matching: find.text(title)))
        .dy;

    // 落点连续 → 打开时没有跳动
    expect(settledDy, closeTo(nearEndDy, 2));
    expect(tester.takeException(), isNull);

    session.dispose();
  });

  testWidgets('详情页：返回按钮可见（不被 logo 压住）且左缘可侧滑返回', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 44);
    addTearDown(tester.view.reset);

    final config = AppConfig(MemorySettingsStore());
    await config.store.write(complaintRuleSeenKey, '1'); // 跳过首次规则提示
    final session = SessionController(config: config);
    await session.init();
    await tester.pumpWidget(AppScope(controller: session, child: const JustWorkApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('求职者演示账号'));
    await tester.pumpAndSettle();

    final listCards = find.byWidgetPredicate((w) => w is JobCardSurface && w.notchFill == 0);
    await tester.tap(listCards.first);
    await tester.pumpAndSettle();

    // 1) 返回按钮存在，且不与头部 logo 方块重叠（之前被白色方块盖住导致看不见）
    final backIcon = find.byIcon(Icons.arrow_back);
    expect(backIcon, findsWidgets);
    final backRect = tester.getRect(backIcon.first);
    final header = find.byWidgetPredicate(
        (w) => w is JobCardSurface && w.notchFill == 1 && w.key != jobFlightKey);
    final logoRect = tester.getRect(find.descendant(of: header, matching: find.byType(Container)).first);
    expect(backRect.bottom, lessThanOrEqualTo(logoRect.top + 2), reason: '返回按钮应在头部内容上方');
    expect(backRect.left, greaterThanOrEqualTo(0));
    expect(backRect.top, greaterThanOrEqualTo(0));

    // 按钮可点：点击后回到列表页
    await tester.tap(backIcon.first);
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is JobCardSurface && w.notchFill == 1 && w.key != jobFlightKey), findsNothing);

    // 2) 左缘侧滑返回
    await tester.tap(listCards.first);
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is JobCardSurface && w.notchFill == 1 && w.key != jobFlightKey), findsOneWidget);
    final g = await tester.startGesture(const Offset(2, 400));
    await g.moveBy(const Offset(260, 0));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is JobCardSurface && w.notchFill == 1 && w.key != jobFlightKey), findsNothing,
        reason: '左缘侧滑应返回列表页');

    session.dispose();
  });

  testWidgets('点击「查看」胶囊同样打开职位详情', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 44);
    addTearDown(tester.view.reset);

    final config = AppConfig(MemorySettingsStore());
    await config.store.write(complaintRuleSeenKey, '1'); // 跳过首次规则提示
    final session = SessionController(config: config);
    await session.init();
    await tester.pumpWidget(AppScope(controller: session, child: const JustWorkApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('求职者演示账号'));
    await tester.pumpAndSettle();

    final header = find.byWidgetPredicate(
        (w) => w is JobCardSurface && w.notchFill == 1 && w.key != jobFlightKey);
    expect(header, findsNothing);

    // 列表里每张卡都有一个「查看」胶囊，点它应当打开对应的详情页
    final viewPill = find.text('查看');
    expect(viewPill, findsWidgets);
    await tester.tap(viewPill.first);
    await tester.pumpAndSettle();
    expect(header, findsOneWidget, reason: '点击「查看」应打开职位详情页');
    expect(find.byIcon(Icons.arrow_back), findsWidgets);

    session.dispose();
  });
}

// 追加：详情页返回按钮可见性 + 左缘侧滑返回
