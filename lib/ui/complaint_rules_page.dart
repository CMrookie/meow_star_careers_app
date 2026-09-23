import 'package:flutter/material.dart';

import 'complaint_level.dart';
import 'theme.dart';
import 'widgets.dart';

/// 投诉等级规则页：等级表 + 定级依据
class ComplaintRulesPage extends StatelessWidget {
  const ComplaintRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
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
                Text(
                  '招聘信息本身看不出用工口碑。平台把用人单位**经审核的有效投诉次数**'
                  '划分为五个等级，做成直觉色标签显示在职位卡上，'
                  '让你在投递前就能把被广泛厌恶的单位挑出去。',
                  style: const TextStyle(fontSize: 13, color: textSub, height: 1.6)
                      .copyWith(color: textSub),
                ),
                const SizedBox(height: 10),
                const Text('次数口径',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textMain)),
                const SizedBox(height: 4),
                const Text(
                  '统计该单位累计、且经平台审核通过的投诉条数（投诉需已与实际沟通过、证据 ≥20 字）。',
                  style: TextStyle(fontSize: 12.5, color: textHint, height: 1.6),
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
          for (final level in ComplaintLevel.values)
            _LevelCard(level: level, low: complaintLevelThresholds[level.index]),
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
  final int low;
  const _LevelCard({required this.level, required this.low});

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
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: level.color)),
                  const SizedBox(width: 8),
                  TagChip(level.range, color: level.color),
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
  const ComplaintRuleDialog({super.key});

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
              '平台把用人单位「经审核的有效投诉次数」分成五档，用颜色标在职位卡上，'
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
                    width: 84,
                    child: Text(level.range,
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
            const Text(
              '只统计经平台审核通过的有效投诉，1–2 次只作中性提示，10 次及以上建议直接规避。',
              style: TextStyle(fontSize: 12, color: textHint, height: 1.5),
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
