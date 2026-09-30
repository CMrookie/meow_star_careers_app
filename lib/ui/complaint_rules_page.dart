import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/session.dart';
import 'complaint_level.dart';
import 'theme.dart';
import 'widgets.dart';

/// 投诉等级规则页：等级表 + 定级依据。
///
/// 页面上的**数字**来自服务端 `GET /api/v1/complaint-rules`（单一来源）：
/// 率阈值与次数阈值都由接口下发，客户端不维护第二份；
/// 离线 / 演示模式（无后端 / 未登录）时退回 [complaintRuleFallback]（与后端 v2 同值）。
class ComplaintRulesPage extends StatefulWidget {
  const ComplaintRulesPage({super.key});

  @override
  State<ComplaintRulesPage> createState() => _ComplaintRulesPageState();
}

class _ComplaintRulesPageState extends State<ComplaintRulesPage> {
  ComplaintRuleSet _rules = complaintRuleFallback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRules());
  }

  Future<void> _loadRules() async {
    final session = AppScope.maybeRead(context);
    final token = session?.token;
    if (session == null || session.isDemo || token == null) return;
    try {
      final rules = await session.api.complaintRules(token);
      if (mounted) setState(() => _rules = rules);
    } catch (_) {
      // 取不到就继续用兜底规则，页面照常可读
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = _rules;
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(title: const Text('投诉等级规则')),
      body: ListView(
        padding: const EdgeInsets.only(top: 6, bottom: 24),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('这套等级是干什么的'),
                const Text(
                  '招聘信息本身看不出用工口碑。平台把用人单位的投诉情况'
                  '划分为五个等级，做成直觉色标签显示在职位卡上，'
                  '让你在投递前就能把被广泛厌恶的单位挑出去。',
                  style: TextStyle(fontSize: 13, color: textSub, height: 1.6),
                ),
                const SizedBox(height: 10),
                Text('定级口径（规则 ${rules.version}）',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: textMain)),
                const SizedBox(height: 4),
                Text(
                  '有规模：企业申报员工数 ≥ ${rules.minStaffSizeForRate} 人时，按每百人投诉率定级 —— '
                  '${rules.rateRange(1)} 轻微 / ${rules.rateRange(2)} 预警 / '
                  '${rules.rateRange(3)} 警告 / ${rules.rateRange(4)} 严重。\n'
                  '未申报规模或不足 ${rules.minStaffSizeForRate} 人：退回投诉次数定级 —— '
                  '${rules.countRange(1)} 轻微 / ${rules.countRange(2)} 预警 / '
                  '${rules.countRange(3)} 警告 / ${rules.countRange(4)} 严重。',
                  style: const TextStyle(fontSize: 12.5, color: textHint, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text('五个等级',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: textMain)),
          ),
          for (final level in ComplaintLevel.values) _LevelCard(level: level, rules: rules),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle('定级依据'),
                  for (var i = 0; i < complaintLevelReasons.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 5),
                          width: 16,
                          height: 16,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: brandColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(radiusPill),
                          ),
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 10, fontWeight: FontWeight.w700, color: brandDeep)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(complaintLevelReasons[i],
                              style: const TextStyle(fontSize: 13, color: textSub, height: 1.6)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final ComplaintLevel level;
  final ComplaintRuleSet rules;
  const _LevelCard({required this.level, required this.rules});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: level.color,
              borderRadius: BorderRadius.circular(radiusInner),
            ),
            child: Icon(level.icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(level.label,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800, color: level.color)),
                  const SizedBox(width: 8),
                  TagChip(rules.rateRange(level.index), color: level.color),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  TagChip(rules.countRange(level.index), color: textHint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '规模不足 ${rules.minStaffSizeForRate} 人时按次数',
                      style: const TextStyle(fontSize: 11.5, color: textHint),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(level.meaning,
                    style: const TextStyle(fontSize: 12.5, color: textSub, height: 1.55)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 首次进入 App 时的规则提示（可跳到完整规则页）
class ComplaintRuleDialog extends StatelessWidget {
  /// 规则数字来自服务端（单一来源）；缺省用本地兜底（测试 / 离线）
  final ComplaintRuleSet rules;
  const ComplaintRuleDialog({super.key, this.rules = complaintRuleFallback});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('投递前，先看一眼投诉等级'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '平台把用人单位的投诉情况分成五档，用颜色标在职位卡上，'
              '帮你把被广泛厌恶的单位提前挑掉：',
              style: TextStyle(fontSize: 13, color: textSub, height: 1.55),
            ),
            const SizedBox(height: 12),
            for (final level in ComplaintLevel.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: level.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text(level.label,
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700, color: level.color)),
                  ),
                  SizedBox(
                    width: 58,
                    child: Text(rules.rateRange(level.index),
                        style: const TextStyle(fontSize: 12, color: textMain)),
                  ),
                  SizedBox(
                    width: 74,
                    child: Text(rules.countRange(level.index),
                        style: const TextStyle(fontSize: 12, color: textHint)),
                  ),
                  Expanded(
                    child: Text(
                      switch (level) {
                        ComplaintLevel.excellent => '无投诉',
                        ComplaintLevel.minor => '偶发摩擦',
                        ComplaintLevel.alert => '问题重复出现',
                        ComplaintLevel.warning => '系统性问题',
                        ComplaintLevel.severe => '建议规避',
                      },
                      style: const TextStyle(fontSize: 12, color: textSub),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 10),
            Text(
              '有规模按每百人投诉率（${rules.rateRange(1)} / ${rules.rateRange(2)} / '
              '${rules.rateRange(3)}），规模不足 ${rules.minStaffSizeForRate} 人按投诉次数；'
              '只统计经平台审核通过的有效投诉。',
              style: const TextStyle(fontSize: 12, color: textHint, height: 1.5),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ComplaintRulesPage()),
            );
          },
          child: const Text('查看完整规则'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 42)),
          onPressed: () => Navigator.pop(context),
          child: const Text('我知道了'),
        ),
      ],
    );
  }
}
