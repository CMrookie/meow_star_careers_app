// 联调工具：验证状态变更后双方收到 interview-updated。
// 用法: dart run tool/ws_state_probe.dart <hrToken> <seekerToken> <interviewId(instant invited)>
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

Future<void> main(List<String> args) async {
  final hr = args[0];
  final sk = args[1];
  final ivId = args[2];
  final ch = (String token) =>
      IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:8080/ws?token=$token'));
  final a = ch(hr);
  final b = ch(sk);
  final seenB = <String>[];
  a.stream.listen((raw) => print('A<< $raw'));
  b.stream.listen((raw) { print('B<< $raw'); seenB.add(raw.toString()); });
  await Future<void>.delayed(const Duration(milliseconds: 700));

  // HR 通过 REST 开始面试（invited -> in_progress）
  final resp = await http.post(
    Uri.parse('http://127.0.0.1:8080/api/v1/interviews/$ivId/start'),
    headers: {'Authorization': 'Bearer $hr'},
  );
  print('start http=${resp.statusCode} ${resp.body.substring(0, resp.body.length > 120 ? 120 : resp.body.length)}');
  await Future<void>.delayed(const Duration(seconds: 2));
  final ok = seenB.any((r) => r.contains('interview-updated') && r.contains('in_progress'));
  print(ok ? 'STATE_PUSH_OK' : 'STATE_PUSH_FAIL');
  await a.sink.close();
  await b.sink.close();
  exit(ok ? 0 : 1);
}
