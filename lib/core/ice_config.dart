/// WebRTC ICE 服务器配置。
///
/// 为什么不用 Google STUN：`stun.l.google.com` 在中国大陆基本不可达，
/// 每次收集候选都要等它超时，通话建立会明显变慢甚至失败。
///
/// 默认改用**大陆可直连的公共 STUN**（免费、无需注册）：
/// - stun.chat.bilibili.com:3478 B 站（百度云），北京 —— 实测可用
/// - stun.hitv.com:3478          芒果 TV，北京 —— 实测可用
/// - stun.miwifi.com:3478        小米，北京 —— 保留作冗余；实测在部分网络会超时
///   （放在末位：WebRTC 取第一个成功响应的结果，超时的那条只是稍慢一点）
///
/// 关于「阿里云」：阿里云**没有公开的免费 STUN 服务**，
/// `stun.aliyun.com` / `stun1.aliyun.com` / `stun.aliyuncs.com` 都无法解析
/// （网上流传的这些地址是无效的）。若确实想用阿里云，正确做法是在自己的
/// 阿里云 ECS 上部署 coturn（同时提供 STUN/TURN），然后：
///   - 运行时：把 turnUrl / turnUser / turnCred 写进设置（[AppConfig]），本函数会自动带上；
///   - 构建期：直接改下面的 [defaultTurnUrl] 等常量。
/// 公网 NAT 复杂（对称型 NAT）时只有 STUN 是不够的，必须配 TURN 才能保证连通。
library;

/// 默认 STUN 列表（大陆公共服务器）
const List<String> defaultStunServers = <String>[
  'stun:stun.miwifi.com:3478',
  'stun:stun.chat.bilibili.com:3478',
  'stun:stun.hitv.com:3478',
];

/// 自建 TURN（例如阿里云 ECS 上的 coturn）示例：
/// `turn:<ecs 公网 IP>:3478?transport=udp`
///
/// 默认 **null = 不启用 TURN**，只用上面的公共 STUN。
/// 运行时可在 App 内「设置 → 视频通话中继（TURN）」配置，无需重新打包。
const String? defaultTurnUrl = null;
const String? defaultTurnUser = null;
const String? defaultTurnCred = null;

/// 公开免费的测试用 TURN（Open Relay Project / Metered）。
///
/// ❌ **实测结论（2026-09，见 tool/turn_probe.py）：该服务已不再提供 TURN 中继。**
/// 对它发 TURN Allocate 会返回 `400 Bad Request`（RFC 5389 中「不支持该方法」的语义），
/// 也就是这个域名现在**只当 STUN 用**，拿不到 relay 地址 —— 对称 NAT 下依然打不通。
/// 因此设置页的「填入公开测试服」只作为占位/联调参考，**正式使用请自建 coturn**
/// （见 deploy/turn/README.md，一键脚本 + 排错清单）。
///
/// ⚠️ 即使它恢复可用，也**仅供开发与演示，不要用于正式环境**：
/// - 它是**公共共享**服务，稳定性、带宽、可用性都没有任何保证（随时可能失效）；
/// - 媒体流会**经过第三方服务器中转**，不要用于任何真实业务数据；
/// - 正式环境请在自己的服务器上部署 coturn，再把地址填进设置页。
///
/// 为什么**默认不启用**：公共中继意味着把通话内容交给第三方转发，
/// 不应该在用户不知情的情况下静默开启。设置页提供「填入公开测试服」一键填入。
///
/// 三个地址是有意给出的：UDP 80/443 优先，末位 `<...>?transport=tcp` 用于
/// 企业网 / 运营商封禁 UDP 时的兜底（TURN over TCP 通常能穿过这类网络）。
const List<String> publicTestTurnUrls = <String>[
  'turn:openrelay.metered.ca:80',
  'turn:openrelay.metered.ca:443',
  'turn:openrelay.metered.ca:443?transport=tcp',
];
const String publicTestTurnUser = 'openrelayproject';
const String publicTestTurnCred = 'openrelayproject';

/// 上面三个地址的逗号拼接串，供设置页「一键填入」使用。
const String publicTestTurnUrl = 'turn:openrelay.metered.ca:80,'
    'turn:openrelay.metered.ca:443,'
    'turn:openrelay.metered.ca:443?transport=tcp';

/// 从候选字符串解析类型：`host` / `srflx` / `prflx` / `relay`（其他返回 `unknown`）。
///
/// 用途：判断「TURN 是否真的生效」——只有出现 `relay` 候选才说明中继可用；
/// 双方都在对称 NAT 后面时若始终没有 relay，就是连不通的直接原因。
String iceCandidateKind(String? candidate) {
  final t = RegExp(r'\btyp\s+(\w+)')
          .firstMatch(candidate ?? '')
          ?.group(1)
          ?.toLowerCase() ??
      '';
  return switch (t) {
    'host' || 'srflx' || 'prflx' || 'relay' => t,
    _ => 'unknown',
  };
}

/// 组装 flutter_webrtc 需要的 `iceServers` 结构（STUN 列表 + 可选 TURN）。
///
/// [turnUrl] 为空（或只有空白）时只返回 STUN；否则追加一条带凭据的 turn 配置。
///
/// [turnUrl] **支持一次配置多个地址**，用英文逗号或换行分隔，例如：
/// `turn:h:3478?transport=udp,turn:h:443?transport=tcp`
/// 单地址时 `urls` 是 String，多地址时是 List&lt;String&gt;（两种 flutter_webrtc 都接受）。
List<Map<String, dynamic>> buildIceServers({
  List<String> stunServers = defaultStunServers,
  String? turnUrl = defaultTurnUrl,
  String? turnUser = defaultTurnUser,
  String? turnCred = defaultTurnCred,
}) {
  final servers = <Map<String, dynamic>>[
    for (final url in stunServers) <String, dynamic>{'urls': url},
  ];
  final turnUrls = (turnUrl ?? '')
      .split(RegExp(r'[,\n]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (turnUrls.isNotEmpty) {
    servers.add(<String, dynamic>{
      'urls': turnUrls.length == 1 ? turnUrls.first : turnUrls,
      if (turnUser != null && turnUser.isNotEmpty) 'username': turnUser,
      if (turnCred != null && turnCred.isNotEmpty) 'credential': turnCred,
    });
  }
  return servers;
}
