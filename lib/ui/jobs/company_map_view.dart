import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../theme.dart';
import '../widgets.dart';

/// 地图服务 Key（后续接入内嵌地图时注入：
/// flutter build/run --dart-define=MAPS_API_KEY=xxx
/// 然后在下方 _embeddedMap 分支换成 google_maps_flutter 的 GoogleMap 即可）
const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

/// 职位详情的“公司位置”：展示企业 城市+详细地址，
/// 点击在系统/网页地图打开；内嵌地图留待配置 Key 后启用。
class CompanyMapView extends StatelessWidget {
  final Company company;
  final String title;
  const CompanyMapView({super.key, required this.company, this.title = '公司位置'});

  String get _place {
    final parts = <String>[
      company.name,
      if ((company.location ?? '').isNotEmpty) company.location!,
      if ((company.address ?? '').isNotEmpty) company.address!,
    ];
    return parts.join(' ');
  }

  Future<void> _openInMap(BuildContext context) async {
    final place = _place;
    if (place.isEmpty) {
      showToast(context, '该企业暂未填写详细地址');
      return;
    }
    final q = Uri.encodeQueryComponent(place);
    final Uri uri;
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        uri = Uri.parse('https://maps.apple.com/?q=$q');
        break;
      case TargetPlatform.android:
        uri = Uri.parse('geo:0,0?q=$q');
        break;
      default:
        uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$q');
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) showToast(context, '无法打开地图应用');
    } catch (_) {
      if (context.mounted) showToast(context, '无法打开地图应用', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = (company.location ?? '').isNotEmpty;
    final addr = (company.address ?? '').isNotEmpty;
    return SectionCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.place_outlined, size: 18, color: brandColor),
          const SizedBox(width: 6),
          const Expanded(
            child: SectionTitle('公司位置', trailing: SizedBox.shrink()),
          ),
        ]),
        KeyValueRow('所在城市', company.location ?? '未填写'),
        KeyValueRow('详细地址', company.address ?? '未填写'),
        const SizedBox(height: 6),
        // 地图展示区：预留内嵌地图插槽；未配置 Key 时给出可点击的地图占位
        Container(
          width: double.infinity,
          height: 130,
          decoration: BoxDecoration(
            color: const Color(0xFFEDF1FE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD5E0FF)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 内嵌地图插槽（启用方式见文件头注释）
              mapsApiKey.isNotEmpty ? const _PlaceholderMapSlot() : const SizedBox.shrink(),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.map_outlined, size: 34, color: brandColor),
                    const SizedBox(height: 6),
                    Text(
                      (loc || addr) ? _place : '该企业暂未填写位置信息',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: textSub),
                    ),
                  ]),
                ),
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    backgroundColor: Colors.white,
                    foregroundColor: brandColor,
                  ),
                  onPressed: () => _openInMap(context),
                  icon: const Icon(Icons.navigation_outlined, size: 15),
                  label: const Text('在地图中查看', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// 内嵌地图占位（接入 GoogleMap 后替换）
class _PlaceholderMapSlot extends StatelessWidget {
  const _PlaceholderMapSlot();
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
