import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/api_exception.dart';
import '../core/app_config.dart';

/// 统一的 REST 客户端：拼 base url、携带 token、解析统一错误。
class ApiClient {
  final AppConfig config;
  final http.Client _inner;
  static const _timeout = Duration(seconds: 15);

  ApiClient(this.config, {http.Client? client}) : _inner = client ?? http.Client();

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(config.apiBase);
    var u = Uri.parse(path);
    var uri = base.replace(
      path: '${base.path}/${u.path}'.replaceAll(RegExp(r'/+'), '/'),
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
    return uri;
  }

  /// 发起请求并返回解码后的 JSON（204/空响应返回 null）。
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    String? token,
  }) async {
    final uri = _uri(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    http.Response resp;
    try {
      final future = switch (method) {
        'GET' => _inner.get(uri, headers: headers),
        'POST' => _inner.post(uri, headers: headers, body: body == null ? null : jsonEncode(body)),
        'PUT' => _inner.put(uri, headers: headers, body: body == null ? null : jsonEncode(body)),
        'DELETE' => _inner.delete(uri, headers: headers),
        _ => throw ArgumentError('unsupported method $method'),
      };
      resp = await future.timeout(_timeout);
    } on TimeoutException {
      throw NetworkException('请求超时，请检查服务器是否可达');
    } on http.ClientException catch (e) {
      throw NetworkException('网络连接失败：${e.message}');
    }

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.body.isEmpty) return null;
      return jsonDecode(utf8.decode(resp.bodyBytes));
    }

    String code = 'http_${resp.statusCode}';
    String message = '请求失败（HTTP ${resp.statusCode}）';
    try {
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is Map) {
        code = decoded['code']?.toString() ?? code;
        message = decoded['message']?.toString() ?? message;
      }
    } catch (_) {
      // 非 JSON 错误体，保留默认信息
    }
    throw ApiException(resp.statusCode, code, message);
  }
}
