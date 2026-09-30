import 'package:flutter_test/flutter_test.dart';

import 'package:meow_star_careers_app/core/ice_config.dart';

void main() {
  test('ICE 配置：不再使用 Google STUN，默认走大陆公共 STUN', () {
    final servers = buildIceServers();
    final urls = servers.map((s) => s['urls'] as String).toList();

    expect(urls.length, greaterThanOrEqualTo(2), reason: '至少两个 STUN，便于交叉验证 NAT 类型');
    expect(urls.every((u) => u.startsWith('stun:')), isTrue);
    expect(urls.any((u) => u.contains('l.google.com')), isFalse, reason: '墙内不可达，必须移除');
    expect(urls.any((u) => u.contains('aliyun')), isFalse,
        reason: '阿里云没有公开免费 STUN（stun.aliyun.com 无法解析），不应写入');
    expect(urls, contains('stun:stun.miwifi.com:3478'));
    expect(urls, contains('stun:stun.chat.bilibili.com:3478'));
    // 每条都必须是 flutter_webrtc 认识的结构
    expect(servers.every((s) => s.containsKey('urls')), isTrue);
  });

  test('ICE 配置：配置了自建 TURN（如阿里云 coturn）时会带上凭据', () {
    final servers = buildIceServers(
      turnUrl: 'turn:1.2.3.4:3478?transport=udp',
      turnUser: 'meow',
      turnCred: 'secret',
    );
    final turn = servers.last;
    expect(turn['urls'], 'turn:1.2.3.4:3478?transport=udp');
    expect(turn['username'], 'meow');
    expect(turn['credential'], 'secret');
    // 未配置时不应出现 turn
    expect(buildIceServers().any((s) => (s['urls'] as String).startsWith('turn:')), isFalse);
    // 允许整体替换 STUN 列表
    final custom = buildIceServers(stunServers: const ['stun:example.com:3478']);
    expect(custom.length, 1);
    expect(custom.first['urls'], 'stun:example.com:3478');
  });

  test('TURN：单地址返回 String，多地址（逗号分隔）返回 List', () {
    final one = buildIceServers(turnUrl: 'turn:1.2.3.4:3478');
    expect(one.last['urls'], isA<String>());

    final many = buildIceServers(
      turnUrl: 'turn:a.com:80, turn:a.com:443?transport=tcp',
      turnUser: 'u',
      turnCred: 'c',
    );
    expect(many.last['urls'], isA<List<String>>());
    final list = many.last['urls'] as List<String>;
    expect(list.length, 2);
    expect(list.first, 'turn:a.com:80');
    expect(list.last, 'turn:a.com:443?transport=tcp');
    // 换行分隔也支持
    expect(buildIceServers(turnUrl: 'turn:a.com:80\nturn:b.com:80').last['urls'],
        isA<List<String>>());
  });

  test('TURN：空白 / 只有逗号时不应产生空的 turn 条目', () {
    expect(buildIceServers(turnUrl: '').length, defaultStunServers.length);
    expect(buildIceServers(turnUrl: '   ').length, defaultStunServers.length);
    expect(buildIceServers(turnUrl: ' , ,  ').length, defaultStunServers.length);
    expect(buildIceServers(turnUrl: null).length, defaultStunServers.length);
  });

  test('公开测试服预设：3 个地址 + 官方凭据，且默认不启用', () {
    expect(publicTestTurnUrls.length, 3);
    expect(publicTestTurnUrls, contains('turn:openrelay.metered.ca:80'));
    expect(publicTestTurnUrls.last, contains('transport=tcp'),
        reason: 'UDP 被封时要有 TCP 兜底');
    expect(publicTestTurnUrl.split(',').length, 3, reason: '一键填入串应与列表一致');
    expect(publicTestTurnUser, isNotEmpty);
    expect(publicTestTurnCred, isNotEmpty);

    // 默认（未配置）绝不能带 turn —— 公共中继不应静默开启
    expect(
      buildIceServers().any((s) => (s['urls'] as String).startsWith('turn:')),
      isFalse,
    );
  });

  test('候选类型解析：用于判断 TURN 是否真的生效（是否拿到 relay）', () {
    expect(iceCandidateKind('candidate:1 1 udp 2122260223 192.168.1.5 54321 typ host'), 'host');
    expect(iceCandidateKind('candidate:2 1 udp 1686052607 1.2.3.4 54321 typ srflx raddr 0.0.0.0 rport 0'), 'srflx');
    expect(iceCandidateKind('candidate:3 1 udp 41885439 5.6.7.8 60000 typ relay raddr 1.2.3.4 rport 54321'), 'relay');
    expect(iceCandidateKind('garbage'), 'unknown');
    expect(iceCandidateKind(''), 'unknown');
  });

  test('自建 coturn 的典型配置能组装成合法 iceServers', () {
    // 与 deploy/turn/README.md 中给出的填法一致
    final servers = buildIceServers(
      turnUrl: 'turn:203.0.113.10:3478?transport=udp,turn:203.0.113.10:3478?transport=tcp',
      turnUser: 'meowapp',
      turnCred: 'strong-password',
    );
    expect(servers.first['urls'], isA<String>()); // 第一条是 STUN
    final turn = servers.last;
    expect(turn['urls'], isA<List<String>>());
    expect((turn['urls'] as List).length, 2, reason: 'UDP + TCP 两条都要带上');
    expect(turn['username'], 'meowapp');
    expect(turn['credential'], 'strong-password');
    // 换行分隔同样支持（服务器地址列表从配置文件粘贴过来时）
    final multi = buildIceServers(turnUrl: 'turn:a:3478\nturn:b:443?transport=tcp');
    expect((multi.last['urls'] as List).length, 2);
  });
}
