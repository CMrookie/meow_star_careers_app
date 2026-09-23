// 联调工具：双 WebSocket 验证「signal」信令转发。
// 用法: dart run tool/ws_signal_probe.dart <tokenA> <tokenB> <interviewId>
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

Future<void> main(List<String> args) async {
  final tokA = args[0];
  final tokB = args[1];
  final ivId = args[2];
  final ws = (String token) =>
      IOWebSocketChannel.connect(Uri.parse('ws://127.0.0.1:8080/ws?token=$token'));

  final a = ws(tokA);
  final b = ws(tokB);
  final seen = <String>[];
  b.stream.listen((raw) {
    print('B<< $raw');
    seen.add(raw.toString());
  });
  a.stream.listen((raw) => print('A<< $raw'));

  await Future<void>.delayed(const Duration(milliseconds: 800));
  a.sink.add(jsonEncode({
    'type': 'signal',
    'interviewId': ivId,
    'payload': {'kind': 'joined', 'tag': 'probe-from-A'},
  }));
  await Future<void>.delayed(const Duration(seconds: 2));

  final ok = seen.any((r) =>
      r.contains('interview-signal') &&
      r.contains(ivId) &&
      r.contains('probe-from-A'));
  print(ok ? 'SIGNAL_FORWARD_OK' : 'SIGNAL_FORWARD_FAIL');
  await a.sink.close();
  await b.sink.close();
  exit(ok ? 0 : 1);
}
