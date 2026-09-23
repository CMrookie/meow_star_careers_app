import 'package:flutter/foundation.dart';

import 'api_exception.dart';

/// 简易键值存储抽象：真实设备用文件（见 settings_io.dart），测试用内存实现。
abstract class SettingsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class MemorySettingsStore implements SettingsStore {
  final Map<String, String> _data = {};
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<void> remove(String key) async => _data.remove(key);
}

/// 应用级配置（当前会话中可变，token / base URL 等）。
class AppConfig {
  /// 平台默认后端地址：Android 模拟器经 10.0.2.2 访问宿主机，其余默认本机。
  static String get defaultBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  final SettingsStore store;

  /// 后端 base URL（http(s)://host:port，不带尾部斜杠）
  String baseUrl;

  /// 登录令牌（仅内存缓存；持久化由外部经 [store] 完成）
  String? token;

  AppConfig(this.store, {String? baseUrl, this.token})
      : baseUrl = baseUrl ?? AppConfig.defaultBaseUrl;

  String get apiBase => '$baseUrl/api/v1';

  Future<void> load() async {
    baseUrl = await store.read('baseUrl') ?? AppConfig.defaultBaseUrl;
    token = await store.read('token');
  }

  Future<void> saveBaseUrl(String url) async {
    baseUrl = url;
    await store.write('baseUrl', url);
  }

  Future<void> saveToken(String? value) async {
    token = value;
    if (value == null) {
      await store.remove('token');
    } else {
      await store.write('token', value);
    }
  }

  /// 由 http base url 推导 websocket base url（ws:// 或 wss://）
  String get wsBase {
    final u = Uri.parse(baseUrl);
    final scheme = u.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${u.host}:${u.hasPort ? u.port : 80}';
  }

  @override
  String toString() => 'AppConfig(baseUrl: $baseUrl)';
}

/// 安全地把运行期错误转成可展示文案（跨平台，不依赖 dart:io）。
String friendlyError(Object error) {
  if (error is ApiException) {
    return '${error.message}（${error.code}）';
  }
  if (error is NetworkException) return error.message;
  return error.toString();
}

/// 通用占位：开发调试时可在此观察配置变化。
void debugLog(String tag, String msg) {
  debugPrint('[$tag] $msg');
}
