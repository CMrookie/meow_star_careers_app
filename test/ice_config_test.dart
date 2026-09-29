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
}
