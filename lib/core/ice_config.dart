/// WebRTC ICE 服务器配置。
///
/// 为什么不用 Google STUN：`stun.l.google.com` 在中国大陆基本不可达，
/// 每次收集候选都要等它超时，通话建立会明显变慢甚至失败。
///
/// 默认改用**大陆可直连的公共 STUN**（免费、无需注册）：
/// - stun.miwifi.com:3478        小米，北京
/// - stun.chat.bilibili.com:3478 B 站（百度云），北京
/// - stun.hitv.com:3478          芒果 TV（备用，不同机房以便交叉验证 NAT 类型）
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
const String? defaultTurnUrl = null;
const String? defaultTurnUser = null;
const String? defaultTurnCred = null;

/// 组装 flutter_webrtc 需要的 `iceServers` 结构（STUN 列表 + 可选 TURN）。
///
/// [turnUrl] 为空时只返回 STUN；传入自建 TURN 后会追加一条带凭据的 turn 配置。
List<Map<String, dynamic>> buildIceServers({
  List<String> stunServers = defaultStunServers,
  String? turnUrl = defaultTurnUrl,
  String? turnUser = defaultTurnUser,
  String? turnCred = defaultTurnCred,
}) {
  final servers = <Map<String, dynamic>>[
    for (final url in stunServers) <String, dynamic>{'urls': url},
  ];
  if (turnUrl != null && turnUrl.isNotEmpty) {
    servers.add(<String, dynamic>{
      'urls': turnUrl,
      if (turnUser != null && turnUser.isNotEmpty) 'username': turnUser,
      if (turnCred != null && turnCred.isNotEmpty) 'credential': turnCred,
    });
  }
  return servers;
}
