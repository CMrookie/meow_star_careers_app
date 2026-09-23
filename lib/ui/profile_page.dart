import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/session.dart';
import 'company_page.dart';
import 'complaint_rules_page.dart';
import 'complaints_page.dart';
import 'interviews/interview_list_page.dart';
import 'resumes/resumes_page.dart';
import 'settings_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// 「我的」页（双角色共用，按角色展示入口）
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final user = session.user;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      backgroundColor: bgPage,
      // 本页没有 AppBar，必须自行避让状态栏 / 刘海，否则内容会被设备顶部遮挡。
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            _header(user, demo: session.isDemo),
            const SizedBox(height: 8),
            if (user.isRecruiter) ...[
              ListGroup(children: [
                ListItem(
                  leading: _iconBox(Icons.business_outlined, const Color(0xFF3B6CF6)),
                  title: '我的企业',
                  subtitle: '查看并管理企业主页信息',
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFC0C4CC)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CompanyPage()),
                  ),
                ),
              ]),
            ] else ...[
              ListGroup(children: [
                ListItem(
                  leading: _iconBox(Icons.description_outlined, const Color(0xFF07C160)),
                  title: '我的简历',
                  subtitle: '编辑简历、控制公开状态',
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFC0C4CC)),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ResumesPage()),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 8),
            ListGroup(children: [
              ListItem(
                leading: _iconBox(Icons.rate_review_outlined, const Color(0xFFE5484D)),
                title: '投诉记录',
                subtitle: '我的投诉 / 企业投诉 / 管理员审核',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFC0C4CC)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ComplaintsPage()),
                ),
              ),
              ListItem(
                leading: _iconBox(Icons.shield_outlined, const Color(0xFFFFA726)),
                title: '投诉等级规则',
                subtitle: '五档等级、对应颜色与定级依据',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFC0C4CC)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ComplaintRulesPage()),
                ),
              ),
              ListItem(
                leading: _iconBox(Icons.videocam_outlined, const Color(0xFF7A5AF8)),
                title: '视频面试',
                subtitle: '即时 / 预约 · 在线视频房间',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFC0C4CC)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InterviewsPage()),
                ),
              ),
              ListItem(
                leading: _iconBox(Icons.settings_outlined, const Color(0xFF8F959E)),
                title: '设置',
                subtitle: '服务器地址、账号与登出',
                trailing: const Icon(Icons.chevron_right, color: Color(0xFFC0C4CC)),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _header(User user, {required bool demo}) {
    final accent = user.isRecruiter ? accentViolet : brandColor;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent, Color.lerp(accent, Colors.black, 0.22)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radiusCard),
        boxShadow: tintedShadow(accent),
      ),
      child: Row(children: [
        Avatar(name: user.name, size: 60, color: Colors.white),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(user.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 8),
              GlassPill(user.roleLabel, backgroundAlpha: 0.22),
              if (demo) ...[
                const SizedBox(width: 6),
                const GlassPill('演示', backgroundAlpha: 0.34),
              ],
            ]),
            const SizedBox(height: 6),
            Text(user.contactDisplay.isEmpty ? '暂无联系方式' : user.contactDisplay,
                style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
          ]),
        ),
      ]),
    );
  }

  Widget _iconBox(IconData icon, Color color) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(radiusInner)),
        child: Icon(icon, size: 20, color: color),
      );
}
