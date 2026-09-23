// 联调：验证 投递状态变更 → 求职者实时收到 application-updated
// 用法: dart run tool/ws_app_probe.dart <hrToken> <seekerToken> <applicationId>
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

Future<void> main(List<String> args) async {
  final hr = args[0];
  final sk = args[1];
  final appId = args[2];
  final b = IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:8080/ws?token=$sk'));
  final seen = <String>[];
  b.stream.listen((raw) {
    print('B<< $raw');
    seen.add(raw.toString());
  });
  await Future<void>.delayed(const Duration(milliseconds: 700));
  final resp = await http.post(
    Uri.parse('http://127.0.0.1:8080/api/v1/applications/$appId/status'),
    headers: {'Authorization': 'Bearer $hr', 'content-type': 'application/json'},
    body: '{"status":"viewed"}',
  );
  print('status http=${resp.statusCode}');
  await Future<void>.delayed(const Duration(seconds: 2));
  final ok = seen.any((r) => r.contains('application-updated') && r.contains(appId));
  print(ok ? 'APP_UPDATE_PUSH_OK' : 'APP_UPDATE_PUSH_FAIL');
  await b.sink.close();
  exit(ok ? 0 : 1);
}
