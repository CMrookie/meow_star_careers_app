import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/china_regions.dart';
import '../theme.dart';

class RegionSelection {
  final String province; // 省（如 广东）
  final String city; // 市（如 深圳市；空=省级）
  final String district; // 区县（如 南山区；空=市级）

  const RegionSelection({this.province = '', this.city = '', this.district = ''});

  bool get isEmpty => province.isEmpty;
  String get fullLabel =>
      [province, city, district].where((s) => s.isNotEmpty).join(' · ');

  /// 用于后端 location 查询：精确到已选最深层
  String get query => district.isNotEmpty ? district : (city.isNotEmpty ? city : province);
}

/// 省 → 市 → 区 三级地区选择（开发演示数据见 china_regions.dart）
class RegionPickerPage extends StatefulWidget {
  final RegionSelection initial;
  const RegionPickerPage({super.key, this.initial = const RegionSelection()});

  @override
  State<RegionPickerPage> createState() => _RegionPickerPageState();
}

class _RegionPickerPageState extends State<RegionPickerPage> {
  late String _province;
  late String? _city;
  late String? _district;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _province = widget.initial.province;
    _city = widget.initial.city.isEmpty ? null : widget.initial.city;
    _district = widget.initial.district.isEmpty ? null : widget.initial.district;
    if (_province.isEmpty) _locateAndPreload();
  }

  /// 无已选地区时：尝试用当前定位预填 省/市/区（失败则手动选择，不打扰）
  Future<void> _locateAndPreload() async {
    setState(() => _locating = true);
    try {
      final sel = await _locateRegion();
      if (!mounted) return;
      setState(() {
        final city = sel?.city ?? '';
        final district = sel?.district ?? '';
        _province = sel?.province ?? '';
        _city = city.isEmpty ? null : city;
        _district = district.isEmpty ? null : district;
      });
    } catch (_) {
      // 忽略定位失败
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  static String _norm(String s) => s.replaceAll(RegExp(r'[省市区县]$'), '').trim();

  /// 当前坐标 -> 反地理编码 -> 匹配内置地区数据
  Future<RegionSelection?> _locateRegion() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    );
    final marks = await Geocoding()
        .placemarkFromCoordinates(pos.latitude, pos.longitude);
    if (marks.isEmpty) return null;
    final p = marks.first;

    // 省
    final pAdm = p.administrativeArea ?? '';
    String? provinceKey;
    for (final key in chinaRegions.keys) {
      final nk = _norm(key);
      if (nk.isNotEmpty && (pAdm.contains(nk) || _norm(pAdm) == nk)) {
        provinceKey = key;
        break;
      }
    }
    if (provinceKey == null) return null;
    final cities = chinaRegions[provinceKey]!;

    // 市：逐候选取首个命中
    String? cityKey;
    final cands = <String>[
      if ((p.locality ?? '').isNotEmpty) p.locality!,
      if ((p.subAdministrativeArea ?? '').isNotEmpty) p.subAdministrativeArea!,
    ];
    for (final cand in cands) {
      final n = _norm(cand);
      if (n.isEmpty) continue;
      cityKey = cities.keys.where((c) {
        final nc = _norm(c);
        return nc == n || c.contains(n);
      }).firstOrNull;
      if (cityKey != null) break;
    }
    if (cityKey == null) return RegionSelection(province: provinceKey);

    // 区
    final districts = cities[cityKey] ?? const <String>[];
    String? district;
    final cand = p.subLocality ?? '';
    if (cand.isNotEmpty && districts.isNotEmpty) {
      for (final d in districts) {
        if (d == cand || _norm(d) == _norm(cand) || d.contains(cand) || cand.contains(d)) {
          district = d;
          break;
        }
      }
    }
    return RegionSelection(province: provinceKey, city: cityKey, district: district ?? '');
  }

  List<String> get _cities {
    final m = chinaRegions[_province];
    return m == null ? const [] : m.keys.toList();
  }

  List<String> get _districts {
    if (_province.isEmpty || _city == null) return const [];
    final m = chinaRegions[_province];
    return m?[_city] ?? const [];
  }

  void _pickProvince(String p) {
    setState(() {
      _province = p;
      _city = null;
      _district = null;
    });
  }

  void _pickCity(String c) {
    setState(() {
      _city = c;
      _district = null;
    });
  }

  void _done() {
    Navigator.of(context).pop(RegionSelection(
      province: _province,
      city: _city ?? '',
      district: _district ?? '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('选择地区'),
        actions: [
          TextButton(onPressed: _done, child: const Text('完成')),
        ],
      ),
      body: Column(
        children: [
          if (_locating) const LinearProgressIndicator(minHeight: 2),
          // 当前路径
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF7F8FA),
            child: Row(children: [
              Expanded(
                child: Text(
                  _province.isEmpty
                      ? '请选择：省 → 市 → 区'
                      : RegionSelection(province: _province, city: _city ?? '', district: _district ?? '')
                          .fullLabel,
                  style: const TextStyle(fontSize: 14, color: textMain),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_province.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    _province = '';
                    _city = null;
                    _district = null;
                  }),
                  child: const Row(children: [
                    Icon(Icons.refresh, size: 14, color: textHint),
                    SizedBox(width: 2),
                    Text('重置', style: TextStyle(fontSize: 12, color: textHint)),
                  ]),
                ),
            ]),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 省
                _column(
                  chinaRegions.keys.toList(),
                  _province,
                  (v) {
                    _pickProvince(v);
                    // 若省下无市（理论不会）直接当省级选择返回
                    if (_cities.isEmpty) _done();
                  },
                ),
                // 市
                if (_province.isNotEmpty)
                  _column(
                    ['不限（全省）', ..._cities],
                    _city,
                    (v) => v.startsWith('不限')
                        ? Navigator.of(context).pop(RegionSelection(province: _province))
                        : _pickCity(v),
                  ),
                // 区
                if (_province.isNotEmpty && _city != null && _districts.isNotEmpty)
                  _column(
                    ['不限（全市）', ..._districts],
                    _district,
                    (v) {
                      if (v.startsWith('不限')) {
                        Navigator.of(context)
                            .pop(RegionSelection(province: _province, city: _city!));
                        return;
                      }
                      setState(() => _district = v);
                      _done();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _column(List<String> items, String? selected, ValueChanged<String> onTap) {
    return Expanded(
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final active = item == selected;
          return InkWell(
            onTap: () => onTap(item),
            child: Container(
              color: active ? const Color(0xFFEAF0FF) : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Text(
                    item,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: active ? brandDeep : textMain,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (active) const Icon(Icons.check, size: 16, color: brandColor),
              ]),
            ),
          );
        },
      ),
    );
  }
}
