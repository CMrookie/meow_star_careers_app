import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets.dart';

/// 学历表述关键词 -> 学历（供一致性校验）
const _eduKeywords = ['博士', '硕士', '本科', '大专', '中专', '研究生'];

/// 校验“职位内容中提及的学历”与所选“学历要求”是否一致。
/// 一致返回 null；不一致返回给用户的提示文案。
/// 说明：学历要求为「不限」时，内容里出现任何具体学历表述也视为不一致。
String? educationConsistencyHint(String? education, List<String> texts) {
  final joined = texts.join('\n');
  final mentions = _eduKeywords.where(joined.contains).toList();
  if (mentions.isEmpty) return null;

  final target =
      (education == null || education.isEmpty || education == '学历不限') ? null : education;
  if (target == null) {
    return '学历要求为「学历不限」，但职位内容中提到了「${mentions.join('、')}」。'
        '请选择对应学历要求，或删除内容中的学历表述';
  }
  final bad = mentions.where((m) => m != target).toList();
  if (bad.isNotEmpty) {
    return '职位内容中提到的学历「${bad.join('、')}」与所选学历要求「$target」不一致，'
        '请调整内容表述或修改学历要求';
  }
  return null;
}

/// 职位编辑（新建 / 修改），仅招聘者使用。
class JobEditPage extends StatefulWidget {
  final JobView? job;
  const JobEditPage({super.key, this.job});

  bool get isEdit => job != null;

  @override
  State<JobEditPage> createState() => _JobEditPageState();
}

class _JobEditPageState extends State<JobEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _requirements;
  late final TextEditingController _location;
  late final TextEditingController _salaryMin;
  late final TextEditingController _salaryMax;
  late String _jobType;
  String? _experience;
  String? _education;
  bool _submitting = false;

  static const _experiences = ['在校生', '应届生', '1年以内', '1-3年', '3-5年', '5-10年', '10年以上'];
  static const _educations = ['学历不限', '大专', '本科', '硕士', '博士'];

  @override
  void initState() {
    super.initState();
    final j = widget.job;
    _title = TextEditingController(text: j?.title ?? '');
    _description = TextEditingController(text: j?.description ?? '');
    _requirements = TextEditingController(text: j?.requirements ?? '');
    _location = TextEditingController(text: j?.location ?? '');
    _salaryMin = TextEditingController(text: j?.salaryMin == null ? '' : '${j!.salaryMin}');
    _salaryMax = TextEditingController(text: j?.salaryMax == null ? '' : '${j!.salaryMax}');
    _jobType = j?.jobType ?? 'full_time';
    _experience = j?.experience;
    _education = j?.education;
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _requirements, _location, _salaryMin, _salaryMax]) {
      c.dispose();
    }
    super.dispose();
  }

  JobWrite _buildWrite() {
    int? parse(String s) {
      final v = int.tryParse(s.trim());
      return (v == null || v <= 0) ? null : v;
    }

    return JobWrite(
      title: _title.text.trim(),
      description: _description.text.trim(),
      requirements: _requirements.text.trim().isEmpty ? null : _requirements.text.trim(),
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      salaryMin: parse(_salaryMin.text),
      salaryMax: parse(_salaryMax.text),
      jobType: _jobType,
      experience: _experience,
      education: _education,
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final write = _buildWrite();
    final sm = write.salaryMin;
    final mx = write.salaryMax;
    if (sm != null && mx != null && sm > mx) {
      showToast(context, '最低薪资不能高于最高薪资');
      return;
    }
    // 职位内容中提及的学历必须与“学历要求”一致
    final hint = educationConsistencyHint(_education, [
      write.title,
      write.description,
      write.requirements ?? '',
    ]);
    if (hint != null) {
      showToast(context, hint, error: true);
      return;
    }
    final session = AppScope.of(context);
    setState(() => _submitting = true);
    try {
      if (widget.isEdit) {
        await session.api.updateJob(widget.job!.id, write, session.token!);
      } else {
        await session.api.createJob(write, session.token!);
      }
      if (!mounted) return;
      showToast(context, widget.isEdit ? '职位已更新' : '职位发布成功');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context);
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: Text(widget.isEdit ? '编辑职位' : '发布职位')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SectionCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('基本信息'),
                TextFormField(
                  controller: _title,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: '职位名称 *', hintText: '如：后端工程师'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '请填写职位名称' : null,
                ),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMin,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: '最低月薪(元)', hintText: '如 15000'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _salaryMax,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: '最高月薪(元)', hintText: '如 25000'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _location,
                  maxLength: 20,
                  decoration: const InputDecoration(labelText: '工作城市', hintText: '如：北京'),
                ),
                const SizedBox(height: 8),
                const Text('工作性质', style: TextStyle(fontSize: 13, color: textSub)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in jobTypes)
                      ChoiceChip(
                        label: Text(jobTypeLabel(t)),
                        selected: _jobType == t,
                        onSelected: (_) => setState(() => _jobType = t),
                        showCheckmark: false,
                        selectedColor: const Color(0xFFE4EBFE),
                        backgroundColor: const Color(0xFFF2F3F5),
                        labelStyle: TextStyle(
                          fontSize: 13,
                          color: _jobType == t ? brandDeep : textMain,
                          fontWeight: _jobType == t ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _experience,
                      decoration: const InputDecoration(labelText: '经验要求'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('不限')),
                        for (final e in _experiences)
                          DropdownMenuItem<String?>(value: e, child: Text(e)),
                      ],
                      onChanged: (v) => setState(() => _experience = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      initialValue: _education,
                      decoration: const InputDecoration(labelText: '学历要求'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('不限')),
                        for (final e in _educations)
                          DropdownMenuItem<String?>(value: e, child: Text(e)),
                      ],
                      onChanged: (v) => setState(() => _education = v),
                    ),
                  ),
                ]),
              ]),
            ),
            SectionCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('职位介绍'),
                TextFormField(
                  controller: _description,
                  minLines: 5,
                  maxLines: 12,
                  maxLength: 10000,
                  decoration: const InputDecoration(
                    hintText: '岗位职责、工作内容等 *',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? '请填写职位描述' : null,
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _requirements,
                  minLines: 4,
                  maxLines: 10,
                  maxLength: 5000,
                  decoration: const InputDecoration(
                    hintText: '任职要求（技术栈、经验、学历等，选填）',
                    alignLabelWithHint: true,
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.isEdit ? '保存修改' : '立即发布'),
              ),
            ),
            if (!widget.isEdit)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Text('将以「${session.user?.name ?? ''}」所在企业名义发布',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFB8BCC4))),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
