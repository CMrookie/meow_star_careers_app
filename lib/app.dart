import 'package:flutter/material.dart';

import 'state/session.dart';
import 'ui/auth/login_page.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

/// 根 Widget：监听会话状态，在 启动页 / 登录页 / 主框架 间切换。
class JustWorkApp extends StatelessWidget {
  const JustWorkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 开发阶段启用路由调试，方便直接跳转到指定页面。
      // initialRoute: '/',
      // routes: {
      //   '/login': (context) => const LoginPage(),
      //   '/home': (context) => const HomeShell(),
      // },
      title: '职聘',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        switch (session.status) {
          case SessionStatus.loading:
            return const _SplashPage();
          case SessionStatus.authenticated:
            return const HomeShell();
          case SessionStatus.anonymous:
            return const LoginPage();
        }
      },
    );
  }
}

class _SplashPage extends StatelessWidget {
  const _SplashPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 16),
            Text(
              '职聘加载中…',
              style: TextStyle(fontSize: 13, color: Color(0xFF8F959E)),
            ),
          ],
        ),
      ),
    );
  }
}
