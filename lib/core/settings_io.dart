import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app_config.dart';

/// 基于单个 JSON 文件的持久化存储（token、base URL 等少量设置）。
/// 仅支持 IO 平台（移动 / 桌面）。
class FileSettingsStore implements SettingsStore {
  Map<String, String>? _cache;
  File? _file;

  Future<File> _settingsFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/app_settings.json');
    return _file!;
  }

  Future<Map<String, String>> _load() async {
    if (_cache != null) return _cache!;
    try {
      final f = await _settingsFile();
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString());
        if (raw is Map) {
          _cache = raw.map((k, v) => MapEntry(k.toString(), v.toString()));
          return _cache!;
        }
      }
    } catch (_) {
      // 文件损坏则视为空
    }
    _cache = {};
    return _cache!;
  }

  Future<void> _persist() async {
    final f = await _settingsFile();
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(_cache ?? {}));
  }

  @override
  Future<String?> read(String key) async => (await _load())[key];

  @override
  Future<void> write(String key, String value) async {
    final m = await _load();
    m[key] = value;
    await _persist();
  }

  @override
  Future<void> remove(String key) async {
    final m = await _load();
    m.remove(key);
    await _persist();
  }
}

/// IO 平台的存储工厂
SettingsStore createSettingsStore() => FileSettingsStore();
