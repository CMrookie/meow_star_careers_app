import 'package:flutter/material.dart';

import '../core/format.dart';
import '../models/models.dart';
import 'theme.dart';
import 'widgets.dart';

/// 投递列表卡片（求职者视角显示公司，招聘者视角显示候选人）
///
/// 与职位卡片同一套视觉语言：白底大圆角 + 柔和投影 + 头像色块 + 胶囊状态标签。
class ApplicationCard extends StatelessWidget {
  final ApplicationView app;
  final bool showSeeker;
  final VoidCallback? onTap;
  const ApplicationCard({super.key, required this.app, this.showSeeker = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = statusColor(app.status);
    final title = showSeeker ? app.seekerName : app.jobTitle;
    final subtitle = showSeeker
        ? '投递了「${app.jobTitle}」 · ${relativeTime(app.createdAt)}'
        : '${app.companyName} · ${relativeTime(app.createdAt)}';
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(radiusInner),
          ),
          alignment: Alignment.center,
          child: Text(
            title.isEmpty ? '投' : title.characters.first,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: accent),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textMain),
                  ),
                ),
                const SizedBox(width: 8),
                StatusTag(app.status),
              ]),
              const SizedBox(height: 5),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: textHint)),
              if (app.coverLetter != null && app.coverLetter!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('附言：${app.coverLetter}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: textSub)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: Color(0xFFC0C4CC)),
      ]),
    );
  }
}
