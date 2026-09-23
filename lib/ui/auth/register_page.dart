import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets.dart';

final _phonePattern = RegExp(r'^1\d{10}$');

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _recruiter = false;
  bool _submitting = false;
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  // 招聘者：企业信息
  final _companyName = TextEditingController();
  final _companyIndustry = TextEditingController();
  final _companyLocation = TextEditingController();
  final _companyAddress = TextEditingController();
  final _companyWebsite = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _phone, _name, _password, _confirm,
      _companyName, _companyIndustry, _companyLocation, _companyAddress, _companyWebsite,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final name = _name.text.trim();
    final password = _password.text;
    final confirm = _confirm.text;
    if (!_phonePattern.hasMatch(phone)) {
      showToast(context, '请输入正确的 11 位手机号');
      return;
    }
    if (name.isEmpty) {
      showToast(context, '请填写姓名');
      return;
    }
    if (password.length < 8) {
      showToast(context, '密码至少 8 位');
      return;
    }
    if (password != confirm) {
      showToast(context, '两次输入的密码不一致');
      return;
    }
    NewCompany? company;
    if (_recruiter) {
      final cn = _companyName.text.trim();
      if (cn.isEmpty) {
        showToast(context, '招聘者注册需要填写企业名称');
        return;
      }
      company = NewCompany(
        name: cn,
        industry: _companyIndustry.text.trim().isEmpty ? null : _companyIndustry.text.trim(),
        location: _companyLocation.text.trim().isEmpty ? null : _companyLocation.text.trim(),
        address: _companyAddress.text.trim().isEmpty ? null : _companyAddress.text.trim(),
        website: _companyWebsite.text.trim().isEmpty ? null : _companyWebsite.text.trim(),
      );
    }

    setState(() => _submitting = true);
    try {
      final session = AppScope.of(context);
      await session.register(
        phone: phone,
        name: name,
        password: password,
        role: _recruiter ? 'recruiter' : 'seeker',
        company: company,
      );
      if (!mounted) return;
      showToast(context, '注册成功，欢迎使用职聘！');
      // 注册页是 push 出的路由：登出栈顶，底层 home 已由 AuthGate 切换为主框架
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(hintText: hint, prefixIcon: Icon(icon), suffixIcon: suffix);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('注册账号')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('我是求职者'), icon: Icon(Icons.person_search_outlined)),
                  ButtonSegment(value: true, label: Text('我是招聘者'), icon: Icon(Icons.business_outlined)),
                ],
                selected: {_recruiter},
                onSelectionChanged: (s) => setState(() => _recruiter = s.first),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2F3F5),
                  foregroundColor: textMain,
                  selectedBackgroundColor: const Color(0xFFE8EEFE),
                  selectedForegroundColor: brandDeep,
                  minimumSize: const Size(0, 44),
                ),
              ),
              const SizedBox(height: 26),
              const Text('基本信息', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textHint)),
              const SizedBox(height: 10),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '手机号 *',
                  prefixIcon: Icon(Icons.smartphone),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 4),
              TextField(
                controller: _name,
                decoration: _dec('姓名 / 昵称', Icons.person_outline),
              ),
              const SizedBox(height: 12),
              TextField(controller: _password, obscureText: true, decoration: _dec('密码（至少 8 位）', Icons.lock_outline)),
              const SizedBox(height: 12),
              TextField(controller: _confirm, obscureText: true, decoration: _dec('确认密码', Icons.lock_outline)),
              if (_recruiter) ...[
                const SizedBox(height: 24),
                const Text('企业信息（招聘者）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textHint)),
                const SizedBox(height: 10),
                TextField(controller: _companyName, decoration: _dec('企业名称 *', Icons.business_outlined)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(controller: _companyIndustry, decoration: _dec('行业', Icons.category_outlined)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(controller: _companyLocation, decoration: _dec('所在城市', Icons.location_on_outlined)),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: _companyAddress,
                  decoration: _dec('办公详细地址（可选，用于职位地图定位）', Icons.location_on_outlined),
                ),
                const SizedBox(height: 12),
                TextField(controller: _companyWebsite, keyboardType: TextInputType.url, decoration: _dec('官网（可选）', Icons.link)),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('注 册'),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _recruiter ? '注册成功后即可发布职位、查看投递' : '注册成功后即可浏览职位、在线投递',
                  style: const TextStyle(fontSize: 12, color: textHint),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
