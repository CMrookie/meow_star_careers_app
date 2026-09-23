import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../demo/demo_store.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets.dart';
import 'register_page.dart';

final _phonePattern = RegExp(r'^1\d{10}$');

/// 修改后端地址的小弹窗（登录页与设置页共用）
Future<void> showBaseUrlDialog(BuildContext context) async {
  final session = AppScope.of(context);
  final controller = TextEditingController(text: session.config.baseUrl);
  await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('服务器地址'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '修改后端 base URL（例如 http://192.168.1.10:8080）',
            style: TextStyle(fontSize: 12, color: textHint),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'http://127.0.0.1:8080',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 40)),
          onPressed: () async {
            final url = controller.text.trim().replaceAll(RegExp(r'/+$'), '');
            if (url.isEmpty) return;
            await session.config.saveBaseUrl(url);
            if (ctx.mounted) Navigator.pop(ctx, true);
            if (context.mounted) showToast(context, '服务器地址已更新');
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  bool _demoBusy = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _enterDemo(String phone) async {
    setState(() => _demoBusy = true);
    try {
      final session = AppScope.of(context);
      await session.enterDemo(phone: phone);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _demoBusy = false);
    }
  }

  Future<void> _submit() async {
    final session = AppScope.of(context);
    final phone = _phone.text.trim();
    final password = _password.text;
    if (!_phonePattern.hasMatch(phone)) {
      showToast(context, '请输入正确的 11 位手机号');
      return;
    }
    if (password.isEmpty) {
      showToast(context, '请输入密码');
      return;
    }
    setState(() => _submitting = true);
    try {
      await session.login(phone: phone, password: password);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    final bootError = session.bootError;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '服务器地址',
            icon: const Icon(Icons.dns_outlined),
            onPressed: () => showBaseUrlDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B8DEF), brandDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(radiusControl + 4),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.work_outline,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '职聘',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: textMain,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '好工作，值得认真找',
                style: TextStyle(fontSize: 14, color: textSub),
              ),
              const SizedBox(height: 36),
              if (bootError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(radiusControl),
                    border: Border.all(color: const Color(0xFFFFD9A0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: warmOrange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          bootError,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A5A00),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '手机号',
                  prefixIcon: Icon(Icons.smartphone),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _password,
                obscureText: true,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  hintText: '密码',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('登 录'),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '还没有账号？',
                    style: TextStyle(fontSize: 13, color: textHint),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      );
                    },
                    child: const Text(
                      '立即注册',
                      style: TextStyle(fontSize: 13, color: brandColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _DemoEntry(onEnter: _enterDemo, busy: _demoBusy),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  session.config.baseUrl,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB8BCC4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 开发演示模式入口：一键以演示账号登录（不依赖后端）。
class _DemoEntry extends StatelessWidget {
  final Future<void> Function(String phone) onEnter;
  final bool busy;
  const _DemoEntry({required this.onEnter, required this.busy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(radiusControl),
        border: Border.all(color: const Color(0xFFD5E0FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, size: 16, color: brandColor),
              const SizedBox(width: 6),
              const Text(
                '开发演示模式',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: brandDeep,
                ),
              ),
              const Spacer(),
              const Text(
                '内置示例数据 · 无需后端',
                style: TextStyle(fontSize: 10, color: textHint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    backgroundColor: const Color(0xFFE4EBFE),
                    foregroundColor: brandDeep,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: busy
                      ? null
                      : () => onEnter(DemoAccount.seekerPhone),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_search_outlined, size: 18),
                      SizedBox(width: 6),
                      Flexible(child: Text('求职者演示账号', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    backgroundColor: const Color(0xFFE4EBFE),
                    foregroundColor: brandDeep,
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: busy
                      ? null
                      : () => onEnter(DemoAccount.recruiterPhone),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.business_outlined, size: 18),
                      SizedBox(width: 6),
                      Flexible(child: Text('招聘者演示账号', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
