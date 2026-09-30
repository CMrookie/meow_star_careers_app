import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/app_config.dart';
import '../core/ice_config.dart';
import '../state/session.dart';
import 'auth/login_page.dart';
import 'camera_check_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// 设置：服务器地址 / 视频通话中继(TURN) / 连接测试 / 关于 / 退出登录
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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

  /// 设置页副标题只显示主机名，避免超长 URL 撑破列表行。
  String _turnLabel(AppConfig cfg) {
    if (!cfg.hasTurn) return '未配置（仅用公共 STUN）';
    final parts = cfg.turnUrl!.split(RegExp(r'[,\n]')).where((e) => e.trim().isNotEmpty).toList();
    final first = parts.first.trim();
    final host = first
        .replaceFirst(RegExp(r'^turns?:'), '')
        .replaceFirst(RegExp(r'^//'), '')
        .split(':')
        .first;
    return parts.length > 1 ? '已配置 · $host 等 ${parts.length} 个地址' : '已配置 · $host';
  }

  Future<void> _editTurn() async {
    final session = AppScope.of(context);
    final cfg = session.config;
    final urlCtl = TextEditingController(text: cfg.turnUrl ?? '');
    final userCtl = TextEditingController(text: cfg.turnUser ?? '');
    final credCtl = TextEditingController(text: cfg.turnCred ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('视频通话中继（TURN）'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '默认只用公共 STUN，同网段和多数家用宽带可直接 P2P 打通。\n'
                '当双方都在对称 NAT（企业网 / 部分 4G / 严格防火墙）后面时，'
                'P2P 打不通，必须经 TURN 中继。留空 = 不使用 TURN。',
                style: TextStyle(fontSize: 12, color: textHint),
              ),
              const SizedBox(height: 8),
              const Text(
                '多个地址用英文逗号分隔；UDP 被封时补一条 TCP 443 通常能通。',
                style: TextStyle(fontSize: 12, color: textHint),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: urlCtl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'TURN 地址',
                  hintText: 'turn:your-host:3478?transport=udp',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: userCtl,
                decoration: const InputDecoration(labelText: '用户名（可选）'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: credCtl,
                decoration: const InputDecoration(labelText: '密码（可选）'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  urlCtl.text = publicTestTurnUrl;
                  userCtl.text = publicTestTurnUser;
                  credCtl.text = publicTestTurnCred;
                },
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('填入公开测试服（实测已失效）'),
              ),
              const SizedBox(height: 8),
              const Text(
                '❌ 实测（2026-09）：该公开中继已不再提供 TURN —— 对它的 Allocate 请求返回 '
                '400，只相当于一个 STUN 服务器，对称 NAT 下仍打不通。此处仅作占位。\n'
                '正式使用请自建 coturn：见仓库 deploy/turn/README.md（含一键命令、'
                '安全组端口、external-ip 这个最常见的坑，以及 ./verify.sh 验证脚本）。',
                style: TextStyle(fontSize: 11, color: Color(0xFFB26B00)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await session.config.clearTurn();
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('清空'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 40)),
            onPressed: () async {
              await session.config.saveTurn(
                url: urlCtl.text,
                user: userCtl.text,
                cred: credCtl.text,
              );
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    urlCtl.dispose();
    userCtl.dispose();
    credCtl.dispose();

    if (saved == true && mounted) {
      setState(() {}); // 刷新副标题
      showToast(context, 'TURN 配置已更新，下次进入视频房间生效');
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
              onTap: () async {
                await showBaseUrlDialog(context);
                if (mounted) setState(() {});
              },
            ),
            ListItem(
              leading: const Icon(Icons.wifi_tethering, color: Color(0xFF07C160)),
              title: '测试连接',
              subtitle: '检查后端服务是否可达',
              trailing: const Icon(Icons.chevron_right, color: Color(0xFFC0C4CC)),
              onTap: () => _testConnection(context),
            ),
            ListItem(
              leading: const Icon(Icons.swap_horiz, color: Color(0xFF0E9F6E)),
              title: '视频通话中继（TURN）',
              subtitle: _turnLabel(session.config),
              trailing: const Icon(Icons.chevron_right, color: Color(0xFFC0C4CC)),
              onTap: _editTurn,
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
