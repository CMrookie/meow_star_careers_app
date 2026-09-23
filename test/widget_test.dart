import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:just_a_work_app/app.dart';
import 'package:just_a_work_app/core/app_config.dart';
import 'package:just_a_work_app/services/api_client.dart';
import 'package:just_a_work_app/state/session.dart';
import 'package:just_a_work_app/ui/complaint_level.dart';
import 'package:just_a_work_app/ui/profile_page.dart';
import 'package:just_a_work_app/ui/widgets.dart';

http.Response _json(Object body, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), code,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  testWidgets('未登录时展示登录页', (tester) async {
    final config = AppConfig(MemorySettingsStore());
    await config.store.write(complaintRuleSeenKey, '1'); // 跳过首次规则提示
    final session = SessionController(config: config);
    await session.init();

    await tester.pumpWidget(AppScope(controller: session, child: const JustWorkApp()));
    await tester.pumpAndSettle();

    expect(find.text('登 录'), findsOneWidget);
    expect(find.text('立即注册'), findsOneWidget);
    expect(find.byIcon(Icons.work_outline), findsOneWidget);

    session.dispose();
  });

  testWidgets('设置页可进入服务器地址弹窗', (tester) async {
    final config = AppConfig(MemorySettingsStore());
    await config.store.write(complaintRuleSeenKey, '1'); // 跳过首次规则提示
    final session = SessionController(config: config);
    await session.init();

    await tester.pumpWidget(AppScope(controller: session, child: const JustWorkApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('服务器地址'));
    await tester.pumpAndSettle();
    expect(find.text('修改后端 base URL（例如 http://192.168.1.10:8080）'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);

    session.dispose();
  });

  testWidgets('注册成功后提示并自动进入主框架', (tester) async {
    const uuid = '11111111-1111-1111-1111-111111111111';
    const phone = '13800138000';
    final client = MockClient((req) async {
      if (req.method == 'POST' && req.url.path.endsWith('/auth/register')) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['role'], 'seeker');
        expect(body['phone'], phone);
        return _json({
          'token': 'reg-token',
          'user': {
            'id': uuid, 'email': null, 'phone': phone, 'name': body['name'], 'isActive': true,
            'role': 'seeker', 'createdAt': '2024-09-08T08:00:00Z', 'updatedAt': '2024-09-08T08:00:00Z',
          },
        }, 201);
      }
      // 主框架各 Tab 的首屏数据：均返回空
      if (req.url.path.endsWith('/jobs') ||
          req.url.path.endsWith('/saved-jobs') ||
          req.url.path.endsWith('/applications')) {
        return _json({'items': <Object>[], 'total': 0, 'page': 1, 'pageSize': 20});
      }
      if (req.url.path.endsWith('/conversations')) return _json(<Object>[]);
      fail('unexpected ${req.method} ${req.url.path}');
    });
    final config = AppConfig(MemorySettingsStore());
    final session = SessionController(config: config, apiClient: ApiClient(config, client: client));
    await session.init();

    await tester.pumpWidget(AppScope(controller: session, child: const JustWorkApp()));
    await tester.pumpAndSettle();
    expect(find.text('登 录'), findsOneWidget);

    await tester.tap(find.text('立即注册'));
    await tester.pumpAndSettle();
    expect(find.text('注 册'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), phone);
    await tester.enterText(find.byType(TextField).at(1), 'Alice');
    await tester.enterText(find.byType(TextField).at(2), 'secret123');
    await tester.enterText(find.byType(TextField).at(3), 'secret123');
    await tester.ensureVisible(find.text('注 册'));
    await tester.tap(find.text('注 册'));
    await tester.pumpAndSettle();

    // 成功提示
    expect(find.text('注册成功，欢迎使用职聘！'), findsOneWidget);
    // 不再停留在注册页，主框架可见
    expect(find.text('注 册'), findsNothing);
    expect(find.text('找工作'), findsOneWidget);
    expect(find.text('消息'), findsWidgets);

    session.dispose();
  });

  testWidgets('演示模式：一键进入求职者并展示内置数据', (tester) async {
    final config = AppConfig(MemorySettingsStore());
    await config.store.write(complaintRuleSeenKey, '1'); // 跳过首次规则提示
    final session = SessionController(config: config);
    await session.init();

    await tester.pumpWidget(AppScope(controller: session, child: const JustWorkApp()));
    await tester.pumpAndSettle();
    expect(find.text('求职者演示账号'), findsOneWidget);

    await tester.ensureVisible(find.text('求职者演示账号'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('求职者演示账号'));
    await tester.pumpAndSettle();

    expect(session.isDemo, isTrue);
    expect(find.text('找工作'), findsOneWidget);
    // 内置职位数据已渲染（卡片底部“发布于 …”）
    expect(find.text('没有找到合适的职位'), findsNothing);
    expect(find.textContaining('发布于'), findsWidgets);

    session.dispose();
  });

  testWidgets('「我的」页内容避让设备顶部安全区', (tester) async {
    // 模拟带状态栏 / 刘海的设备：顶部安全区 47 逻辑像素
    const statusBar = 47.0;
    tester.view.padding = FakeViewPadding(top: statusBar * tester.view.devicePixelRatio);
    addTearDown(tester.view.reset);

    final config = AppConfig(MemorySettingsStore());
    await config.store.write(complaintRuleSeenKey, '1'); // 跳过首次规则提示
    final session = SessionController(config: config);
    await session.init();

    await tester.pumpWidget(AppScope(controller: session, child: const JustWorkApp()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('求职者演示账号'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('求职者演示账号'));
    await tester.pumpAndSettle();

    // 切到「我的」Tab
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    // 头部信息卡（头像与昵称）必须整体落在状态栏下方
    final avatar = find.descendant(of: find.byType(ProfilePage), matching: find.byType(Avatar));
    expect(avatar, findsOneWidget);
    expect(tester.getTopLeft(avatar).dy, greaterThanOrEqualTo(statusBar));
    expect(tester.getTopLeft(find.text('演示求职者')).dy, greaterThanOrEqualTo(statusBar));

    // 页面首个功能入口同样不被遮挡
    expect(tester.getTopLeft(find.text('我的简历')).dy, greaterThanOrEqualTo(statusBar));

    session.dispose();
  });
}
