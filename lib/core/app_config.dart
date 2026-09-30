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

  /// 自建 TURN（如阿里云 ECS 上的 coturn）；为空表示只用公共 STUN
  String? turnUrl;
  String? turnUser;
  String? turnCred;

  AppConfig(this.store, {String? baseUrl, this.token})
      : baseUrl = baseUrl ?? AppConfig.defaultBaseUrl;

  String get apiBase => '$baseUrl/api/v1';

  Future<void> load() async {
    baseUrl = await store.read('baseUrl') ?? AppConfig.defaultBaseUrl;
    token = await store.read('token');
    turnUrl = await store.read('turnUrl');
    turnUser = await store.read('turnUser');
    turnCred = await store.read('turnCred');
  }

  Future<void> saveBaseUrl(String url) async {
    baseUrl = url;
    await store.write('baseUrl', url);
  }

  Future<void> saveToken(String? value) async {
    token = value;
    await _writeOrRemove('token', value);
  }

  /// 保存 TURN 配置（视频通话中继）。任一项留空/只有空白 = 清空该字段。
  ///
  /// 三项全空时等价于 [clearTurn]，回到「只用公共 STUN」。
  Future<void> saveTurn({String? url, String? user, String? cred}) async {
    turnUrl = _norm(url);
    turnUser = _norm(user);
    turnCred = _norm(cred);
    await _writeOrRemove('turnUrl', turnUrl);
    await _writeOrRemove('turnUser', turnUser);
    await _writeOrRemove('turnCred', turnCred);
  }

  /// 清空 TURN 配置（回到只用公共 STUN）。
  Future<void> clearTurn() => saveTurn();

  /// 当前是否配置了 TURN。
  bool get hasTurn => turnUrl != null && turnUrl!.trim().isNotEmpty;

  static String? _norm(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Future<void> _writeOrRemove(String key, String? value) async {
    if (value == null) {
      await store.remove(key);
    } else {
      await store.write(key, value);
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
