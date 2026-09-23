import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../state/session.dart';
import 'auth/login_page.dart';
import 'camera_check_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// 设置：服务器地址 / 连接测试 / 关于 / 退出登录
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _testConnection(BuildContext context) async {
    final session = AppScope.of(context);
    final url = session.config.baseUrl;
    try {
      final resp = await http
          .get(Uri.parse('$url/healthz'))
          .timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        String detail = '';
        try {
          final body = jsonDecode(utf8.decode(resp.bodyBytes));
          if (body is Map && body['status'] != null) detail = '（${body['status']}）';
        } catch (_) {}
        if (context.mounted) showToast(context, '连接成功 $detail');
      } else {
        if (context.mounted) showToast(context, '服务器返回 HTTP ${resp.statusCode}', error: true);
      }
    } catch (_) {
      if (context.mounted) showToast(context, '无法连接到 $url，请检查地址与后端是否启动', error: true);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final ok = await confirmDialog(context, title: '退出登录', message: '确定要退出当前账号吗？', confirmText: '退出');
    if (!ok || !context.mounted) return;
    final session = AppScope.of(context);
    try {
      await session.logout();
    } catch (_) {}
    if (context.mounted) {
      // 回到登录页
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 32),
        children: [
          ListGroup(children: [
            ListItem(
              leading: const Icon(Icons.dns_outlined, color: Color(0xFF3B6CF6)),
              title: '服务器地址',
              subtitle: session.config.baseUrl,
              trailing: const Icon(Icons.chevron_right, color: Color(0xFFC0C4CC)),
              onTap: () => showBaseUrlDialog(context),
            ),
            ListItem(
              leading: const Icon(Icons.wifi_tethering, color: Color(0xFF07C160)),
              title: '测试连接',
              subtitle: '检查后端服务是否可达',
              trailing: const Icon(Icons.chevron_right, color: Color(0xFFC0C4CC)),
              onTap: () => _testConnection(context),
            ),
            ListItem(
              leading: const Icon(Icons.videocam_outlined, color: Color(0xFF7A5AF8)),
              title: '摄像头 / 麦克风自检',
              subtitle: '开发用：验证本机视频采集与授权（无需对端）',
              trailing: const Icon(Icons.chevron_right, color: Color(0xFFC0C4CC)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CameraCheckPage()),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          ListGroup(children: [
            ListItem(
              leading: const Icon(Icons.info_outline, color: Color(0xFF8F959E)),
              title: '关于职聘',
              subtitle: '求职招聘客户端 v1.0.0 · 对接 just-a-work 服务端',
            ),
          ]),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE5484D)),
              onPressed: () => _logout(context),
              child: const Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }
}
