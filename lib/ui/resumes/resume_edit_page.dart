import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets.dart';

/// 简历创建 / 编辑（求职者）
class ResumeEditPage extends StatefulWidget {
  final Resume? resume;
  const ResumeEditPage({super.key, this.resume});

  bool get isEdit => resume != null;

  @override
  State<ResumeEditPage> createState() => _ResumeEditPageState();
}

class _ResumeEditPageState extends State<ResumeEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _title;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _years;
  late final TextEditingController _education;
  late final TextEditingController _skills;
  late final TextEditingController _summary;
  late bool _isPublic;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final r = widget.resume;
    _name = TextEditingController(text: r?.fullName ?? '');
    _title = TextEditingController(text: r?.title ?? '');
    _phone = TextEditingController(text: r?.phone ?? '');
    _email = TextEditingController(text: r?.email ?? '');
    _years = TextEditingController(text: r?.years == null ? '' : '${r!.years}');
    _education = TextEditingController(text: r?.education ?? '');
    _skills = TextEditingController(text: r?.skills ?? '');
    _summary = TextEditingController(text: r?.summary ?? '');
    _isPublic = r?.isPublic ?? true;
  }

  @override
  void dispose() {
    for (final c in [_name, _title, _phone, _email, _years, _education, _skills, _summary]) {
      c.dispose();
    }
    super.dispose();
  }

  ResumeWrite _collect() {
    final years = int.tryParse(_years.text.trim());
    String? nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();
    return ResumeWrite(
      fullName: _name.text.trim(),
      title: _title.text.trim(),
      phone: nullIfEmpty(_phone.text),
      email: nullIfEmpty(_email.text),
      years: (years == null || years <= 0) ? null : years,
      education: nullIfEmpty(_education.text),
      skills: nullIfEmpty(_skills.text),
      summary: nullIfEmpty(_summary.text),
      isPublic: _isPublic,
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final session = AppScope.of(context);
    setState(() => _submitting = true);
    try {
      if (widget.isEdit) {
        await session.api.updateResume(widget.resume!.id, _collect(), session.token!);
      } else {
        await session.api.createResume(_collect(), session.token!);
      }
      if (!mounted) return;
      showToast(context, widget.isEdit ? '简历已保存' : '简历创建成功');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: Text(widget.isEdit ? '编辑简历' : '新建简历')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            SectionCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('基本信息'),
                TextFormField(
                  controller: _name,
                  maxLength: 20,
                  decoration: const InputDecoration(labelText: '姓名 *', hintText: '你的真实姓名'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '请填写姓名' : null,
                ),
                TextFormField(
                  controller: _title,
                  maxLength: 40,
                  decoration: const InputDecoration(labelText: '期望职位 *', hintText: '如：Flutter 开发工程师'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '请填写期望职位' : null,
                ),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: '手机号'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _years,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: '工作年限(年)'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: '联系邮箱'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _education,
                  decoration: const InputDecoration(labelText: '最高学历', hintText: '如：本科 / 硕士'),
                ),
              ]),
            ),
            SectionCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('技能与经历'),
                TextFormField(
                  controller: _skills,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: const InputDecoration(hintText: '专业技能、项目经历等', alignLabelWithHint: true),
                ),
                TextFormField(
                  controller: _summary,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: const InputDecoration(hintText: '自我评价（选填）', alignLabelWithHint: true),
                ),
              ]),
            ),
            SectionCard(
              child: SwitchListTile(
                value: _isPublic,
                onChanged: (v) => setState(() => _isPublic = v),
                title: const Text('公开简历', style: TextStyle(fontSize: 15)),
                subtitle: const Text('公开后招聘者可检索到你的简历（建议开启）', style: TextStyle(fontSize: 12, color: textHint)),
                activeTrackColor: brandColor,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.isEdit ? '保存' : '创建简历'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
