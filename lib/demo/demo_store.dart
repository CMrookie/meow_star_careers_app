// 开发阶段演示数据仓库：在内存中模拟 just-a-work 后端的核心 REST 行为，
// 使客户端可在不启动后端的情况下完整体验（数据可交互：收藏/投递/推进状态/发消息会真实变化）。
// 仅用于开发/演示，不接网络、不落盘。

import '../core/api_exception.dart';
import '../ui/complaint_level.dart';

Map<String, dynamic> _m(String id, String name) => {'id': id, 'name': name};

String _nowIso([DateTime? t]) => (t ?? DateTime.now()).toUtc().toIso8601String();

int _n(Map<String, dynamic> j, String key) => (j[key] as num?)?.toInt() ?? 0;

int _page(Map<String, dynamic>? q, String key, int fallback) {
  final v = q?[key];
  return v is num ? v.toInt() : fallback;
}

String? _q(Map<String, dynamic>? q, String key) {
  final v = q?[key];
  return v == null ? null : '$v';
}

/// 演示账号
class DemoAccount {
  static const seekerPhone = '13800000001';
  static const recruiterPhone = '13800000002';
  static const seekerName = '演示求职者';
  static const recruiterName = '演示招聘官';
  static const seekerId = 'demo-seeker-0001-0000-000000000001';
  static const recruiterId = 'demo-recruiter-0001-0000-000000000002';
}

class DemoBackend {
  /// 认证令牌 -> 用户（含角色/企业）
  final Map<String, Map<String, dynamic>> _tokens = {};

  /// 全部“用户”行（含演示二人与动态注册者）
  final List<Map<String, dynamic>> _users = [];

  /// 企业行
  final List<Map<String, dynamic>> _companies = [];

  /// 职位行（JobView 形状）
  final List<Map<String, dynamic>> _jobs = [];

  /// 简历行（Resume 形状）
  final List<Map<String, dynamic>> _resumes = [];

  /// 投递行（ApplicationView 形状）
  final List<Map<String, dynamic>> _applications = [];

  /// 收藏：(userId -> [jobId...])
  final Map<String, List<String>> _savedByUser = {};

  /// 会话与消息
  final List<Map<String, dynamic>> _conversations = [];
  final List<Map<String, dynamic>> _messages = [];
  int _messageSeq = 0;
  int _idSeq = 100;

  String _freshId() => 'demo-id-${_idSeq++}';

  DemoBackend() {
    _seed();
  }

  // ------------------------------------------------------------------ 种子数据

  void _seed() {
    final seekerAt = _nowIso(DateTime.now().subtract(const Duration(days: 30)));
    final uSeeker = <String, dynamic>{
      'id': DemoAccount.seekerId,
      'email': null,
      'phone': DemoAccount.seekerPhone,
      'name': DemoAccount.seekerName,
      'isActive': true,
      'role': 'seeker',
      'companyId': null,
      'createdAt': seekerAt,
      'updatedAt': seekerAt,
    };
    final uHr = <String, dynamic>{
      'id': DemoAccount.recruiterId,
      'email': null,
      'phone': DemoAccount.recruiterPhone,
      'name': DemoAccount.recruiterName,
      'isActive': true,
      'role': 'recruiter',
      'companyId': 'demo-company-star',
      'createdAt': seekerAt,
      'updatedAt': seekerAt,
    };
    _users.addAll([uSeeker, uHr]);

    _companies.add({
      'id': 'demo-company-star',
      'name': '星河科技',
      'industry': '互联网 / SaaS',
      'description': '专注企业级协作平台与云原生产品，研发团队 200+，氛围开放，鼓励技术分享。',
      'location': '北京 · 中关村',
      'website': 'https://example.com',
      'logoUrl': null,
      'isActive': true,
      'createdBy': DemoAccount.recruiterId,
      'createdAt': seekerAt,
      'updatedAt': seekerAt,
    });

    void addJob({
      required String id,
      required String title,
      required String desc,
      String? req,
      required String location,
      int? lo,
      int? hi,
      String type = 'full_time',
      String? exp,
      String? edu,
      String? createdBy,
      bool active = true,
      DateTime? at,
      String? companyId,
      String? companyName,
      int complaints = 0,
    }) {
      final t = at ?? DateTime.now().subtract(Duration(days: _idSeq ~/ 7));
      _jobs.add({
        'id': id,
        'companyId': companyId ?? 'demo-company-star',
        'companyName': companyName ?? '星河科技',
        'complaintsCount': complaints,
        'title': title,
        'description': desc,
        'requirements': req,
        'location': location,
        'salaryMin': lo,
        'salaryMax': hi,
        'jobType': type,
        'experience': exp,
        'education': edu,
        'isActive': active,
        'createdBy': createdBy ?? DemoAccount.recruiterId,
        'createdAt': _nowIso(t),
        'updatedAt': _nowIso(t),
      });
    }

    addJob(
      id: 'demo-job-001',
      title: '后端工程师（Go）',
      desc: '负责云原生协作平台的网关、消息与数据服务设计与开发；与产品、前端紧密配合完成迭代。',
      req: '3 年以上 Go/Java 后端经验；熟悉 PostgreSQL、Redis、消息队列；有分布式系统实践经验优先。',
      location: '北京',
      lo: 25000, hi: 40000,
      exp: '3-5年', edu: '本科',
    );
    addJob(
      id: 'demo-job-002',
      title: 'Flutter 客户端工程师',
      desc: '负责职聘类 App 的 Flutter 端开发与性能优化，参与组件库建设。',
      req: '2 年以上 Flutter/Dart 经验；熟悉状态管理与自定义组件；有移动端上架经验更佳。',
      location: '深圳',
      lo: 20000, hi: 35000,
      exp: '3-5年', edu: '本科',
    );
    addJob(
      id: 'demo-job-003',
      title: '产品经理（B 端）',
      desc: '负责企业招聘/协同类 B 端产品的需求分析与方案设计，跟进研发与上线。',
      req: '有 B 端产品经验，能独立完成 PRD 与数据复盘；沟通与文档能力强。',
      location: '北京',
      lo: 15000, hi: 25000,
      exp: '1-3年', edu: '本科',
    );
    addJob(
      id: 'demo-job-004',
      title: 'UI 设计师（兼职远程）',
      desc: '按项目制完成客户端界面与设计规范维护，远程协作，按件计酬。',
      req: '精通 Figma，有移动端设计作品集；每周可投入 10 小时以上。',
      location: '上海',
      lo: 8000, hi: 12000,
      type: 'part_time',
      exp: '1-3年', edu: '大专',
    );
    addJob(
      id: 'demo-job-005',
      title: '后端开发实习生',
      desc: '参与内部工具与开放平台开发，含导师带教与转正通道。',
      req: '在校生，熟悉任意一门服务端语言；每周出勤 ≥4 天。',
      location: '北京',
      lo: 4000, hi: 6000,
      type: 'intern',
      exp: '在校生', edu: '学历不限',
    );
    addJob(
      id: 'demo-job-006',
      title: '测试开发工程师',
      desc: '搭建自动化测试体系，保障核心业务回归质量，推进持续集成。',
      req: '5 年以上测试/测开经验，熟悉 Python/Go 与 CI 流程。',
      location: '广州',
      lo: 18000, hi: 28000,
      type: 'contract',
      exp: '5-10年', edu: '大专',
    );
    // 投诉次数差异示例：投诉越多职位越暗淡
    _companies.add({
      'id': 'demo-company-cloud',
      'name': '观云网络',
      'industry': '互联网',
      'description': '示例企业：被投诉 3 次（中等信誉）。',
      'location': '杭州',
      'website': null,
      'logoUrl': null,
      'isActive': true,
      'createdBy': DemoAccount.recruiterId,
      'createdAt': seekerAt,
      'updatedAt': seekerAt,
    });
    _companies.add({
      'id': 'demo-company-old',
      'name': '恒久信息',
      'industry': '信息服务',
      'description': '示例企业：被投诉 9 次（偏低信誉）。',
      'location': '成都',
      'website': null,
      'logoUrl': null,
      'isActive': true,
      'createdBy': DemoAccount.recruiterId,
      'createdAt': seekerAt,
      'updatedAt': seekerAt,
    });
    _companies.add({
      'id': 'demo-company-dim',
      'name': '顺风咨询',
      'industry': '咨询',
      'description': '示例企业：被投诉 20 次（最低信誉，显示最暗淡）。',
      'location': '武汉',
      'website': null,
      'logoUrl': null,
      'isActive': true,
      'createdBy': DemoAccount.recruiterId,
      'createdAt': seekerAt,
      'updatedAt': seekerAt,
    });
    addJob(
      id: 'demo-job-007',
      title: '前端开发工程师',
      desc: '负责 Web/移动端页面开发与体验优化。',
      req: '熟悉 React/Vue 任一框架，2 年以上经验。',
      location: '杭州',
      lo: 15000, hi: 25000,
      exp: '3-5年', edu: '本科',
      companyId: 'demo-company-cloud',
      companyName: '观云网络',
      complaints: 3,
    );
    addJob(
      id: 'demo-job-008',
      title: '运营专员',
      desc: '负责新媒体内容与社群运营。',
      req: '有内容/社群运营经验优先。',
      location: '成都',
      lo: 8000, hi: 12000,
      exp: '1-3年', edu: '大专',
      companyId: 'demo-company-old',
      companyName: '恒久信息',
      complaints: 9,
    );
    addJob(
      id: 'demo-job-009',
      title: '电话客服（储备主管）',
      desc: '负责客户回访与投诉跟进。',
      req: '普通话标准，沟通能力强。',
      location: '武汉',
      lo: 5000, hi: 8000,
      type: 'full_time',
      exp: '经验不限', edu: '学历不限',
      companyId: 'demo-company-dim',
      companyName: '顺风咨询',
      complaints: 20,
    );

    void addResume({
      required String id,
      required String name,
      required String title,
      String? phone,
      int? years,
      String? edu,
      String? skills,
      String? summary,
      required bool pub,
    }) {
      final t = DateTime.now().subtract(const Duration(days: 6));
      _resumes.add({
        'id': id,
        'userId': DemoAccount.seekerId,
        'fullName': name,
        'title': title,
        'phone': phone,
        'email': null,
        'years': years,
        'education': edu,
        'skills': skills,
        'summary': summary,
        'isPublic': pub,
        'createdAt': _nowIso(t),
        'updatedAt': _nowIso(t),
      });
    }

    addResume(
      id: 'demo-resume-001',
      name: '张伟',
      title: '后端工程师',
      phone: '13800000001',
      years: 4,
      edu: '本科 · 计算机科学',
      skills: 'Go / Java / PostgreSQL / Redis / 消息队列；参与过高并发网关与数据中台建设。',
      summary: '4 年后端研发经验，重视工程质量与文档，能独立负责核心模块。',
      pub: true,
    );
    addResume(
      id: 'demo-resume-002',
      name: '张伟',
      title: '全栈工程师',
      years: 4,
      edu: '本科 · 计算机科学',
      skills: 'React / Flutter / Node.js',
      summary: '侧重工程效率与体验，欢迎交流全栈方向机会。',
      pub: false,
    );

    // 投递（供求职者“我的投递”与招聘者“收件箱”演示）
    final appAt = DateTime.now().subtract(const Duration(days: 3));
    _applications.add({
      'id': 'demo-app-001',
      'jobId': 'demo-job-001',
      'jobTitle': '后端工程师（Go）',
      'companyId': 'demo-company-star',
      'companyName': '星河科技',
      'seekerId': DemoAccount.seekerId,
      'seekerName': DemoAccount.seekerName,
      'seekerEmail': null,
      'seekerPhone': DemoAccount.seekerPhone,
      'resumeId': 'demo-resume-001',
      'coverLetter': '您好，我对云原生平台方向很感兴趣，附上简历，期待进一步沟通。',
      'status': 'interviewing',
      'createdAt': _nowIso(appAt),
      'updatedAt': _nowIso(DateTime.now().subtract(const Duration(days: 1))),
    });
    _applications.add({
      'id': 'demo-app-002',
      'jobId': 'demo-job-003',
      'jobTitle': '产品经理（B 端）',
      'companyId': 'demo-company-star',
      'companyName': '星河科技',
      'seekerId': DemoAccount.seekerId,
      'seekerName': DemoAccount.seekerName,
      'seekerEmail': null,
      'seekerPhone': DemoAccount.seekerPhone,
      'resumeId': 'demo-resume-002',
      'coverLetter': null,
      'status': 'pending',
      'createdAt': _nowIso(DateTime.now().subtract(const Duration(hours: 5))),
      'updatedAt': _nowIso(DateTime.now().subtract(const Duration(hours: 5))),
    });
    _savedByUser[DemoAccount.seekerId] = ['demo-job-002', 'demo-job-005'];

    // 预置一段会话（求职者发、招聘者未读）
    _conversations.add({
      'id': 'demo-conv-001',
      'userLo': DemoAccount.seekerId,
      'userHi': DemoAccount.recruiterId,
      'createdAt': _nowIso(DateTime.now().subtract(const Duration(days: 1))),
      'updatedAt': _nowIso(DateTime.now().subtract(const Duration(minutes: 10))),
    });
    _messageSeq += 2;
    _messages.add({
      'id': 1,
      'conversationId': 'demo-conv-001',
      'senderId': DemoAccount.seekerId,
      'recipientId': DemoAccount.recruiterId,
      'content': '您好！已投递贵司「后端工程师（Go）」岗位，请问何时方便沟通？',
      'createdAt': _nowIso(DateTime.now().subtract(const Duration(minutes: 20))),
      'readAt': null,
    });
    _messages.add({
      'id': 2,
      'conversationId': 'demo-conv-001',
      'senderId': DemoAccount.recruiterId,
      'recipientId': DemoAccount.seekerId,
      'content': '你好，简历已收到，我们计划明天上午电话初筛，方便吗？',
      'createdAt': _nowIso(DateTime.now().subtract(const Duration(minutes: 10))),
      'readAt': null,
    });
  }

  // ------------------------------------------------------------------ 工具

  Map<String, dynamic>? _userById(String id) {
    for (final u in _users) {
      if (u['id'] == id) return u;
    }
    return null;
  }

  Map<String, dynamic>? _userByPhone(String phone) {
    for (final u in _users) {
      if (u['phone'] == phone) return u;
    }
    return null;
  }

  Map<String, dynamic>? _companyById(String id) {
    for (final c in _companies) {
      if (c['id'] == id) return c;
    }
    return null;
  }

  /// 解析当前登录用户；token 无效抛 401
  Map<String, dynamic> _requireUser(String? token) {
    final u = _tokens[token];
    if (u == null) {
      throw ApiException(401, 'unauthorized', '无效或已过期的 token');
    }
    return u;
  }

  Map<String, dynamic>? _jobById(String id) {
    for (final j in _jobs) {
      if (j['id'] == id) return j;
    }
    return null;
  }

  Map<String, dynamic>? _findOne(Iterable<Map<String, dynamic>> list, String id) {
    for (final e in list) {
      if (e['id'] == id) return e;
    }
    return null;
  }

  bool _ownsJob(Map<String, dynamic> job, Map<String, dynamic> me) =>
      job['createdBy'] == me['id'];

  /// 两个用户之间（有序）的唯一会话
  Map<String, dynamic>? _conversationOf(String aId, String bId) {
    for (final c in _conversations) {
      final lo = c['userLo'] as String;
      final hi = c['userHi'] as String;
      if ((lo == aId && hi == bId) || (lo == bId && hi == aId)) return c;
    }
    return null;
  }

  List<Map<String, dynamic>> _conversationMessages(String convId) {
    return _messages.where((m) => m['conversationId'] == convId).toList();
  }

  int _unreadOf(Map<String, dynamic> conv, String meId) {
    final other = conv['userLo'] == meId ? conv['userHi'] : conv['userLo'];
    return _conversationMessages(conv['id'] as String)
        .where((m) => m['senderId'] == other && m['readAt'] == null)
        .length;
  }

  Map<String, dynamic> _summaryOf(Map<String, dynamic> conv, String meId) {
    final peerId = conv['userLo'] == meId ? conv['userHi'] : conv['userLo'];
    final peer = _userById(peerId as String)!;
    final msgs = _conversationMessages(conv['id'] as String);
    return {
      'id': conv['id'],
      'peer': _m(peer['id'] as String, peer['name'] as String),
      'createdAt': conv['createdAt'],
      'updatedAt': conv['updatedAt'],
      'lastMessage': msgs.isEmpty ? null : msgs.last,
      'unreadCount': _unreadOf(conv, meId),
    };
  }

  // ------------------------------------------------------------------ 实时通道（供 DemoRealtime 调用）

  bool hasConversation(String convId) =>
      _conversations.any((c) => c['id'] == convId);

  /// 令牌对应的用户 id（DemoRealtime 用）
  String? ownerId(String? token) => _tokens[token]?['id'] as String?;

  /// 会话内 userId 的对端（DemoRealtime 自动回复用）
  String? peerOf(String convId, String userId) => _otherOf(convId, userId);

  /// 在会话里写入一条消息并返回；供 REST send 与实时 send 共用
  Map<String, dynamic> persistMessage(
    String convId,
    String senderId,
    String content,
  ) {
    _messageSeq += 1;
    final msg = <String, dynamic>{
      'id': _messageSeq,
      'conversationId': convId,
      'senderId': senderId,
      'recipientId': _otherOf(convId, senderId),
      'content': content,
      'createdAt': _nowIso(),
      'readAt': null,
    };
    _messages.add(msg);
    for (final c in _conversations) {
      if (c['id'] == convId) c['updatedAt'] = _nowIso();
    }
    return msg;
  }

  String? _otherOf(String convId, String userId) {
    for (final c in _conversations) {
      if (c['id'] != convId) continue;
      return c['userLo'] == userId ? c['userHi'] as String : c['userLo'] as String;
    }
    return null;
  }

  /// 演示自动回复内容（对端为演示账号时触发）
  String? botReplyFor(String convId, String senderId) {
    final peer = _otherOf(convId, senderId);
    if (peer == null) return null;
    final peerUser = _userById(peer);
    if (peerUser == null) return null;
    if (peer != DemoAccount.recruiterId && peer != DemoAccount.seekerId) return null;
    return '你好，我是${peerUser['name']}（演示账号）。消息已收到，感谢联系～';
  }

  Map<String, dynamic> get defaultRecruiter =>
      _userById(DemoAccount.recruiterId)!;

  // ------------------------------------------------------------------ 路由

  /// 模拟 REST：method/path/query/body/token 语义与后端一致
  Future<dynamic> handle(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    String? token,
  }) async {
    final b = body is Map<String, dynamic> ? body : <String, dynamic>{};
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();

    // ---- 认证（公开）----
    if (method == 'POST' && path == '/auth/register') {
      final phone = '${b['phone'] ?? ''}'.trim();
      if (!RegExp(r'^1\d{10}$').hasMatch(phone)) {
        throw ApiException(400, 'bad_request', '手机号必须为 11 位数字（1 开头）');
      }
      if (_userByPhone(phone) != null) {
        throw ApiException(409, 'conflict', '手机号已被注册');
      }
      final role = b['role'] ?? 'seeker';
      String? companyId;
      final u = <String, dynamic>{
        'id': _freshId(),
        'email': null,
        'phone': phone,
        'name': '${b['name'] ?? ''}',
        'isActive': true,
        'role': role,
        'companyId': null,
        'createdAt': _nowIso(),
        'updatedAt': _nowIso(),
      };
      if (role == 'recruiter') {
        final comp = (b['company'] as Map?) ?? const {};
        final c = <String, dynamic>{
          'id': _freshId(),
          'name': comp['name'] ?? '未命名企业',
          'industry': comp['industry'],
          'description': comp['description'],
          'location': comp['location'],
          'website': comp['website'],
          'logoUrl': null,
          'isActive': true,
          'createdBy': u['id'],
          'createdAt': _nowIso(),
          'updatedAt': _nowIso(),
        };
        _companies.add(c);
        companyId = c['id'] as String;
        u['companyId'] = companyId;
      }
      _users.add(u);
      final token = _issue(u);
      return {'token': token, 'user': u};
    }

    if (method == 'POST' && path == '/auth/login') {
      final phone = '${b['phone'] ?? ''}'.trim();
      final u = _userByPhone(phone);
      if (u == null) {
        throw ApiException(401, 'unauthorized', '手机号或密码错误');
      }
      final token = _issue(u);
      return {'token': token, 'user': u};
    }

    // ---- 需认证接口 ----
    final me = _requireUser(token);

    if (method == 'POST' && path == '/auth/logout') {
      _tokens.remove(token);
      return null;
    }
    if (method == 'GET' && path == '/auth/me') {
      return me;
    }

    // 企业
    if (method == 'GET' && path == '/companies/mine') {
      final cid = me['companyId'];
      if (cid == null) throw ApiException(404, 'not_found', '该账号未绑定企业');
      return _companyById(cid as String) ??
          (throw ApiException(404, 'not_found', '企业不存在'));
    }
    if (method == 'GET' && seg.length == 2 && seg[0] == 'companies') {
      final c = _companyById(seg[1]);
      if (c == null) throw ApiException(404, 'not_found', '企业不存在');
      return c;
    }

    // 职位列表 / 搜索
    if (method == 'GET' && path == '/jobs') {
      String? s(String k) {
        final v = _q(query, k);
        if (v == null || v.isEmpty) return null;
        return v;
      }

      final kw = s('keyword')?.toLowerCase();
      final loc = s('location');
      final type = s('jobType');
      final minS = _page(query, 'salaryMin', 0);
      final maxS = _page(query, 'salaryMax', 0);

      var list = _jobs.where((j) {
        if (j['isActive'] != true) return false;
        if (loc != null && !('${j['location']}'.contains(loc))) return false;
        if (type != null && j['jobType'] != type) return false;
        if (minS > 0 && (_n(j, 'salaryMax') == 0 || _n(j, 'salaryMax') < minS)) return false;
        if (maxS > 0 && _n(j, 'salaryMin') > maxS) return false;
        if (kw != null && kw.isNotEmpty) {
          final blob =
              '${j['title']} ${j['description']} ${j['requirements'] ?? ''}'.toLowerCase();
          if (!blob.contains(kw)) return false;
        }
        return true;
      }).toList();
      // 与客户端一致：投诉等级由优到劣 → 次数由少到多 → 更新时间由新到旧
      list.sort(_byComplaintLevel);
      return _pageOf(list, query);
    }

    // 我的（本企业）职位
    if (method == 'GET' && path == '/jobs/my') {
      final list = _jobs
          .where((j) => j['companyId'] == me['companyId'])
          .toList()
        ..sort(_byComplaintLevel);
      return _pageOf(list, query);
    }

    // 收藏列表
    if (method == 'GET' && path == '/saved-jobs') {
      final ids = _savedByUser[me['id']] ?? <String>[];
      final list = ids
          .map(_jobById)
          .whereType<Map<String, dynamic>>()
          .toList()
        ..sort(_byComplaintLevel);
      return _pageOf(list, query);
    }

    // 发布职位
    if (method == 'POST' && path == '/jobs') {
      if (me['role'] != 'recruiter' || me['companyId'] == null) {
        throw ApiException(403, 'forbidden', '仅招聘者可发布职位');
      }
      final job = <String, dynamic>{
        'id': _freshId(),
        'companyId': me['companyId'],
        'companyName': (_companyById(me['companyId'] as String) ?? const {})['name'] ?? '',
        'title': '${b['title'] ?? ''}',
        'description': '${b['description'] ?? ''}',
        'requirements': b['requirements'],
        'location': b['location'],
        'salaryMin': b['salaryMin'],
        'salaryMax': b['salaryMax'],
        'jobType': b['jobType'] ?? 'full_time',
        'experience': b['experience'],
        'education': b['education'],
        'isActive': true,
        'createdBy': me['id'],
        'createdAt': _nowIso(),
        'updatedAt': _nowIso(),
      };
      _jobs.add(job);
      return job;
    }

    // 职位详情/编辑/删除/上下架/收藏/投递（带 :id）
    if (seg.isNotEmpty && seg[0] == 'jobs') {
      final jobId = seg[1];
      final job = _jobById(jobId);
      if (job == null) throw ApiException(404, 'not_found', '职位不存在');

      if (method == 'GET' && seg.length == 2) {
        final owner = _ownsJob(job, me);
        if (job['isActive'] != true && !owner) {
          throw ApiException(404, 'not_found', '职位不存在');
        }
        return job;
      }
      if (method == 'PUT' && seg.length == 2) {
        _checkOwner(job, me);
        for (final k in [
          'title', 'description', 'requirements', 'location', 'jobType', 'experience', 'education',
        ]) {
          if (b.containsKey(k)) job[k] = b[k];
        }
        if (b.containsKey('salaryMin')) job['salaryMin'] = b['salaryMin'];
        if (b.containsKey('salaryMax')) job['salaryMax'] = b['salaryMax'];
        job['updatedAt'] = _nowIso();
        return job;
      }
      if (method == 'DELETE' && seg.length == 2) {
        _checkOwner(job, me);
        _jobs.removeWhere((j) => j['id'] == jobId);
        return null;
      }
      if (method == 'POST' && seg.length == 3 && seg[2] == 'active') {
        _checkOwner(job, me);
        job['isActive'] = b['isActive'] ?? true;
        job['updatedAt'] = _nowIso();
        return job;
      }
      if (method == 'POST' && seg.length == 3 && seg[2] == 'save') {
        (_savedByUser[me['id']] ??= <String>[]).add(jobId);
        return null;
      }
      if (method == 'POST' && seg.length == 3 && seg[2] == 'unsave') {
        _savedByUser[me['id']]?.remove(jobId);
        return null;
      }
      if (method == 'POST' && seg.length == 3 && seg[2] == 'apply') {
        if (me['role'] != 'seeker') {
          throw ApiException(403, 'forbidden', '仅求职者可投递');
        }
        if (job['isActive'] != true) throw ApiException(400, 'bad_request', '职位已下架');
        final exists = _applications.any(
            (a) => a['jobId'] == jobId && a['seekerId'] == me['id']);
        if (exists) {
          throw ApiException(409, 'conflict', '你已投递过该职位');
        }
        return _apply(job, me, b['resumeId'], b['coverLetter']);
      }
    }

    // 简历
    if (method == 'GET' && path == '/resumes') {
      return _resumes.where((r) => r['userId'] == me['id']).toList();
    }
    if (method == 'POST' && path == '/resumes') {
      if (me['role'] != 'seeker') {
        throw ApiException(403, 'forbidden', '仅求职者可维护简历');
      }
      final r = <String, dynamic>{
        'id': _freshId(),
        'userId': me['id'],
        'fullName': b['fullName'] ?? '',
        'title': b['title'] ?? '',
        'phone': b['phone'],
        'email': b['email'],
        'years': b['years'],
        'education': b['education'],
        'skills': b['skills'],
        'summary': b['summary'],
        'isPublic': b['isPublic'] ?? true,
        'createdAt': _nowIso(),
        'updatedAt': _nowIso(),
      };
      _resumes.add(r);
      return r;
    }
    if (method == 'GET' && path == '/resumes/search') {
      final kw = (_q(query, 'keyword') ?? '').trim().toLowerCase();
      final list = _resumes.where((r) {
        if (r['isPublic'] != true) return false;
        if (kw.isEmpty) return true;
        final blob = '${r['fullName']} ${r['title']} ${r['skills'] ?? ''} ${r['summary'] ?? ''}'
            .toLowerCase();
        return blob.contains(kw);
      }).toList();
      return _pageOf(list, query);
    }
    if (seg.length >= 2 && seg[0] == 'resumes') {
      final rid = seg[1];
      final r = _findOne(_resumes, rid);
      if (r == null) throw ApiException(404, 'not_found', '简历不存在');
      final isMine = r['userId'] == me['id'];
      final isRecruiter = me['role'] == 'recruiter';
      if (method == 'GET' && (isMine || (isRecruiter && r['isPublic'] == true))) {
        return r;
      }
      if (method == 'GET') throw ApiException(404, 'not_found', '简历不存在');
      if (!isMine) throw ApiException(403, 'forbidden', '无权操作该简历');
      if (method == 'PUT') {
        for (final k in [
          'fullName', 'title', 'phone', 'email', 'education', 'skills', 'summary',
        ]) {
          if (b.containsKey(k)) r[k] = b[k];
        }
        if (b.containsKey('years')) r['years'] = b['years'];
        if (b.containsKey('isPublic')) r['isPublic'] = b['isPublic'];
        r['updatedAt'] = _nowIso();
        return r;
      }
      if (method == 'DELETE') {
        _resumes.removeWhere((x) => x['id'] == rid);
        return null;
      }
    }

    // 投递列表/详情/状态
    if (method == 'GET' && path == '/applications') {
      final role = me['role'];
      var list = _applications.where((a) {
        if (role == 'seeker') return a['seekerId'] == me['id'];
        return a['companyId'] == me['companyId'];
      }).toList();
      final jobId = _q(query, 'jobId');
      final status = _q(query, 'status');
      if (jobId != null) list = list.where((a) => a['jobId'] == jobId).toList();
      if (status != null && status.isNotEmpty) {
        list = list.where((a) => a['status'] == status).toList();
      }
      list.sort((a, b) => (b['createdAt'] as String).compareTo(a['createdAt'] as String));
      return _pageOf(list, query);
    }
    if (seg.length == 2 && seg[0] == 'applications') {
      final app = _findOne(_applications, seg[1]);
      if (app == null) throw ApiException(404, 'not_found', '投递不存在');
      if (method == 'GET') {
        if (app['seekerId'] != me['id'] && app['companyId'] != me['companyId']) {
          throw ApiException(403, 'forbidden', '无权查看该投递');
        }
        return app;
      }
      if (method == 'POST' && seg.length == 3 && seg[2] == 'status') {
        final status = b['status'];
        final meRole = me['role'];
        if (meRole == 'seeker') {
          if (app['seekerId'] != me['id']) {
            throw ApiException(403, 'forbidden', '无权操作该投递');
          }
          if (status != 'withdrawn') {
            throw ApiException(403, 'forbidden', '求职者仅可撤回（withdrawn）');
          }
        } else {
          if (app['companyId'] != me['companyId']) {
            throw ApiException(403, 'forbidden', '仅可操作本企业收到的投递');
          }
          if (!['viewed', 'interviewing', 'offered', 'rejected'].contains(status)) {
            throw ApiException(403, 'forbidden', '招聘者可设置的状态: viewed / interviewing / offered / rejected');
          }
        }
        app['status'] = status;
        app['updatedAt'] = _nowIso();
        return app;
      }
    }

    // 会话
    if (method == 'GET' && path == '/conversations') {
      final list = _conversations
          .where((c) => c['userLo'] == me['id'] || c['userHi'] == me['id'])
          .map((c) => _summaryOf(c, me['id'] as String))
          .toList()
        ..sort((a, b) => (b['updatedAt'] as String).compareTo(a['updatedAt'] as String));
      return list;
    }
    if (method == 'POST' && path == '/conversations') {
      final peerId = '${b['userId'] ?? ''}';
      if (peerId == me['id']) throw ApiException(400, 'bad_request', '不能与自己聊天');
      final peer = _userById(peerId);
      if (peer == null) throw ApiException(404, 'not_found', '对方不存在');
      var conv = _conversationOf(me['id'] as String, peerId);
      if (conv == null) {
        conv = {
          'id': _freshId(),
          'userLo': me['id'],
          'userHi': peerId,
          'createdAt': _nowIso(),
          'updatedAt': _nowIso(),
        };
        _conversations.add(conv);
      }
      return _summaryOf(conv, me['id'] as String);
    }
    if (seg.length >= 2 && seg[0] == 'conversations') {
      final convId = seg[1];
      final conv = _findOne(_conversations, convId);
      if (conv == null) {
        throw ApiException(403, 'forbidden', 'conversation 不存在或不属于当前用户');
      }
      if (conv['userLo'] != me['id'] && conv['userHi'] != me['id']) {
        throw ApiException(403, 'forbidden', '非会话成员');
      }
      if (method == 'GET' && seg.length == 2) return conv;
      if (seg.length == 3 && seg[2] == 'messages') {
        if (method == 'GET') {
          final limit = _page(query, 'limit', 50).clamp(1, 200);
          final before = _page(query, 'before', 0);
          var msgs = _conversationMessages(convId);
          if (before > 0) msgs = msgs.where((m) => _n(m, 'id') < before).toList();
          msgs.sort((a, b) => _n(a, 'id').compareTo(_n(b, 'id')));
          return msgs.length > limit ? msgs.sublist(msgs.length - limit) : msgs;
        }
        if (method == 'POST') {
          final content = '${b['body'] ?? ''}'.trim();
          if (content.isEmpty || content.length > 2000) {
            throw ApiException(400, 'bad_request', 'body 不能为空且不超过 2000 字符');
          }
          return persistMessage(convId, me['id'] as String, content);
        }
      }
      if (method == 'POST' && seg.length == 3 && seg[2] == 'read') {
        final other = conv['userLo'] == me['id'] ? conv['userHi'] : conv['userLo'];
        final now = _nowIso();
        for (final m in _messages) {
          if (m['conversationId'] == convId &&
              m['senderId'] == other &&
              m['readAt'] == null) {
            m['readAt'] = now;
          }
        }
        return null;
      }
    }

    throw ApiException(404, 'not_found', '接口不存在（演示模式）：$method $path');
  }

  // ------------------------------------------------------------------ 私有工具

  String _issue(Map<String, dynamic> user) {
    final token = 'demo-token-${user['phone']}-${DateTime.now().microsecondsSinceEpoch}';
    _tokens[token] = user;
    return token;
  }

  void _checkOwner(Map<String, dynamic> job, Map<String, dynamic> me) {
    if (!_ownsJob(job, me)) {
      throw ApiException(403, 'forbidden', '仅可操作本企业发布的职位');
    }
  }

  Map<String, dynamic> _apply(
    Map<String, dynamic> job,
    Map<String, dynamic> me,
    Object? resumeId,
    Object? coverLetter,
  ) {
    final app = <String, dynamic>{
      'id': _freshId(),
      'jobId': job['id'],
      'jobTitle': job['title'],
      'companyId': job['companyId'],
      'companyName': job['companyName'],
      'seekerId': me['id'],
      'seekerName': me['name'],
      'seekerEmail': me['email'],
      'seekerPhone': me['phone'],
      'resumeId': resumeId,
      'coverLetter': coverLetter,
      'status': 'pending',
      'createdAt': _nowIso(),
      'updatedAt': _nowIso(),
    };
    _applications.add(app);
    return app;
  }

  /// 职位排序：投诉等级由优到劣（优秀 → 严重），同级按次数、最后按更新时间。
  static int _byComplaintLevel(Map<String, dynamic> a, Map<String, dynamic> b) {
    final ka = (complaintLevelOf(_n(a, 'complaintsCount')).index, _n(a, 'complaintsCount'));
    final kb = (complaintLevelOf(_n(b, 'complaintsCount')).index, _n(b, 'complaintsCount'));
    final c0 = ka.$1.compareTo(kb.$1);
    if (c0 != 0) return c0;
    final c1 = ka.$2.compareTo(kb.$2);
    if (c1 != 0) return c1;
    return '${b['updatedAt']}'.compareTo('${a['updatedAt']}');
  }

  Map<String, dynamic> _pageOf(List<Map<String, dynamic>> list, Map<String, dynamic>? query) {
    final pageSize = _page(query, 'pageSize', 20).clamp(1, 100);
    final page = _page(query, 'page', 1) < 1 ? 1 : _page(query, 'page', 1);
    final start = (page - 1) * pageSize;
    final items = start >= list.length ? <Map<String, dynamic>>[] : list.sublist(start, (start + pageSize).clamp(0, list.length));
    return {'items': items, 'total': list.length, 'page': page, 'pageSize': pageSize};
  }
}
