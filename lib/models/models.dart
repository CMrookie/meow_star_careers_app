// 数据模型：与 just-a-work 后端 JSON（camelCase）一一对应。
// 全部采用手写 fromJson，避免对 Dart 版本敏感的代码生成依赖。

DateTime _dt(dynamic v) => DateTime.parse(v as String).toLocal();

String? _str(Map<String, dynamic> j, String key) {
  final v = j[key];
  return v == null ? null : v as String;
}

int? _int(Map<String, dynamic> j, String key) {
  final v = j[key];
  return v == null ? null : v is int ? v : (v as num).toInt();
}

bool _bool(Map<String, dynamic> j, String key, [bool fallback = false]) {
  final v = j[key];
  return v == null ? fallback : v as bool;
}

/// ---------- 用户 / 认证 ----------

class User {
  final String id;
  final String? email;
  final String name;
  final bool isActive;
  final String role; // seeker | recruiter
  final String? companyId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? phone;

  User({
    required this.id,
    this.email,
    required this.name,
    required this.isActive,
    required this.role,
    this.companyId,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
  });

  bool get isRecruiter => role == 'recruiter';
  bool get isSeeker => role == 'seeker';
  String get roleLabel => isRecruiter ? '招聘者' : '求职者';
  /// 展示用联系方式：优先手机号，其次邮箱
  String get contactDisplay => phone ?? email ?? '';

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as String,
        email: _str(j, 'email'),
        name: j['name'] as String,
        isActive: _bool(j, 'isActive', true),
        role: j['role'] as String? ?? 'seeker',
        companyId: _str(j, 'companyId'),
        createdAt: _dt(j['createdAt']),
        updatedAt: _dt(j['updatedAt']),
        phone: _str(j, 'phone'),
      );
}

class UserPublic {
  final String id;
  final String name;
  UserPublic({required this.id, required this.name});
  factory UserPublic.fromJson(Map<String, dynamic> j) =>
      UserPublic(id: j['id'] as String, name: j['name'] as String);
}

class AuthResponse {
  final String token;
  final User user;
  AuthResponse({required this.token, required this.user});
  factory AuthResponse.fromJson(Map<String, dynamic> j) =>
      AuthResponse(token: j['token'] as String, user: User.fromJson(j['user'] as Map<String, dynamic>));
}

/// ---------- 企业 ----------

class Company {
  final String id;
  final String name;
  final String? industry;
  final String? description;
  final String? location;
  final String? address;
  final String? website;
  final String? logoUrl;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Company({
    required this.id,
    required this.name,
    this.industry,
    this.description,
    this.location,
    this.address,
    this.website,
    this.logoUrl,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Company.fromJson(Map<String, dynamic> j) => Company(
        id: j['id'] as String,
        name: j['name'] as String,
        industry: _str(j, 'industry'),
        description: _str(j, 'description'),
        location: _str(j, 'location'),
        address: _str(j, 'address'),
        website: _str(j, 'website'),
        logoUrl: _str(j, 'logoUrl'),
        isActive: _bool(j, 'isActive', true),
        createdBy: _str(j, 'createdBy'),
        createdAt: _dt(j['createdAt']),
        updatedAt: _dt(j['updatedAt']),
      );
}

/// ---------- 职位 ----------

const jobTypes = ['full_time', 'part_time', 'contract', 'intern'];

String jobTypeLabel(String t) {
  switch (t) {
    case 'full_time':
      return '全职';
    case 'part_time':
      return '兼职';
    case 'contract':
      return '项目/合同';
    case 'intern':
      return '实习';
    default:
      return t;
  }
}

class JobView {
  final String id;
  final String companyId;
  final String companyName;
  final String title;
  final String description;
  final String? requirements;
  final String? location;
  final int? salaryMin;
  final int? salaryMax;
  final String jobType;
  final String? experience;
  final String? education;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int complaintCount;

  JobView({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.title,
    required this.description,
    this.requirements,
    this.location,
    this.salaryMin,
    this.salaryMax,
    required this.jobType,
    this.experience,
    this.education,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.complaintCount = 0,
  });

  String get typeLabel => jobTypeLabel(jobType);

  /// 是否远程岗位：数据模型暂无独立字段，先按地区/描述/要求文本里的关键词识别。
  /// 后端补上 remote 字段后应改为直接读取该字段。
  bool get isRemote {
    final blob = '${location ?? ''} $description ${requirements ?? ''}'.toLowerCase();
    return blob.contains('远程') ||
        blob.contains('remote') ||
        blob.contains('居家') ||
        blob.contains('在家办公');
  }

  factory JobView.fromJson(Map<String, dynamic> j) => JobView(
        id: j['id'] as String,
        companyId: j['companyId'] as String,
        companyName: j['companyName'] as String,
        title: j['title'] as String,
        description: j['description'] as String,
        requirements: _str(j, 'requirements'),
        location: _str(j, 'location'),
        salaryMin: _int(j, 'salaryMin'),
        salaryMax: _int(j, 'salaryMax'),
        jobType: j['jobType'] as String? ?? 'full_time',
        experience: _str(j, 'experience'),
        education: _str(j, 'education'),
        isActive: _bool(j, 'isActive', true),
        createdBy: _str(j, 'createdBy'),
        createdAt: _dt(j['createdAt']),
        updatedAt: _dt(j['updatedAt']),
        complaintCount: _int(j, 'complaintsCount') ?? 0,
      );
}

/// 职位创建 / 编辑共用载荷
class JobWrite {
  final String title;
  final String description;
  final String? requirements;
  final String? location;
  final int? salaryMin;
  final int? salaryMax;
  final String jobType;
  final String? experience;
  final String? education;

  JobWrite({
    required this.title,
    required this.description,
    this.requirements,
    this.location,
    this.salaryMin,
    this.salaryMax,
    this.jobType = 'full_time',
    this.experience,
    this.education,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'requirements': requirements,
        'location': location,
        'salaryMin': salaryMin,
        'salaryMax': salaryMax,
        'jobType': jobType,
        'experience': experience,
        'education': education,
      };
}

/// 职位列表分页
class Paged<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  Paged({required this.items, required this.total, required this.page, required this.pageSize});

  factory Paged.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) itemFromJson,
  ) =>
      Paged(
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => itemFromJson(e as Map<String, dynamic>))
            .toList(),
        total: (j['total'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
        pageSize: (j['pageSize'] as num?)?.toInt() ?? 0,
      );
}

/// ---------- 简历 ----------

class Resume {
  final String id;
  final String userId;
  final String fullName;
  final String title;
  final String? phone;
  final String? email;
  final int? years;
  final String? education;
  final String? skills;
  final String? summary;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  Resume({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.title,
    this.phone,
    this.email,
    this.years,
    this.education,
    this.skills,
    this.summary,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Resume.fromJson(Map<String, dynamic> j) => Resume(
        id: j['id'] as String,
        userId: j['userId'] as String,
        fullName: j['fullName'] as String,
        title: j['title'] as String,
        phone: _str(j, 'phone'),
        email: _str(j, 'email'),
        years: _int(j, 'years'),
        education: _str(j, 'education'),
        skills: _str(j, 'skills'),
        summary: _str(j, 'summary'),
        isPublic: _bool(j, 'isPublic'),
        createdAt: _dt(j['createdAt']),
        updatedAt: _dt(j['updatedAt']),
      );
}

class ResumeWrite {
  final String fullName;
  final String title;
  final String? phone;
  final String? email;
  final int? years;
  final String? education;
  final String? skills;
  final String? summary;
  final bool isPublic;

  ResumeWrite({
    required this.fullName,
    required this.title,
    this.phone,
    this.email,
    this.years,
    this.education,
    this.skills,
    this.summary,
    this.isPublic = true,
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'title': title,
        'phone': phone,
        'email': email,
        'years': years,
        'education': education,
        'skills': skills,
        'summary': summary,
        'isPublic': isPublic,
      };
}

/// ---------- 投递 ----------

const applicationStatuses = [
  'pending',
  'viewed',
  'interviewing',
  'offered',
  'rejected',
  'withdrawn',
];

const recruiterTransitions = ['viewed', 'interviewing', 'offered', 'rejected'];

String applicationStatusLabel(String s) {
  switch (s) {
    case 'pending':
      return '待处理';
    case 'viewed':
      return '已查看';
    case 'interviewing':
      return '面试中';
    case 'offered':
      return '已录用';
    case 'rejected':
      return '不合适';
    case 'withdrawn':
      return '已撤回';
    default:
      return s;
  }
}

class ApplicationView {
  final String id;
  final String jobId;
  final String jobTitle;
  final String companyId;
  final String companyName;
  final String seekerId;
  final String seekerName;
  final String? seekerEmail;
  final String? seekerPhone;
  final String? resumeId;
  final String? coverLetter;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  ApplicationView({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.companyId,
    required this.companyName,
    required this.seekerId,
    required this.seekerName,
    this.seekerEmail,
    this.seekerPhone,
    this.resumeId,
    this.coverLetter,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  String get statusLabel => applicationStatusLabel(status);
  /// 招聘者查看候选人联系方式：优先手机号
  String get seekerContact => seekerPhone ?? seekerEmail ?? '未提供联系方式';

  factory ApplicationView.fromJson(Map<String, dynamic> j) => ApplicationView(
        id: j['id'] as String,
        jobId: j['jobId'] as String,
        jobTitle: j['jobTitle'] as String,
        companyId: j['companyId'] as String,
        companyName: j['companyName'] as String,
        seekerId: j['seekerId'] as String,
        seekerName: j['seekerName'] as String,
        seekerEmail: _str(j, 'seekerEmail'),
        seekerPhone: _str(j, 'seekerPhone'),
        resumeId: _str(j, 'resumeId'),
        coverLetter: _str(j, 'coverLetter'),
        status: j['status'] as String? ?? 'pending',
        createdAt: _dt(j['createdAt']),
        updatedAt: _dt(j['updatedAt']),
      );
}

/// ---------- 私聊 ----------

class Message {
  final int id;
  final String conversationId;
  final String senderId;
  final String recipientId;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.createdAt,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: (j['id'] as num).toInt(),
        conversationId: j['conversationId'] as String,
        senderId: j['senderId'] as String,
        recipientId: j['recipientId'] as String,
        content: j['content'] as String,
        createdAt: _dt(j['createdAt']),
        readAt: j['readAt'] == null ? null : _dt(j['readAt']),
      );
}

class ConversationSummary {
  final String id;
  final UserPublic peer;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Message? lastMessage;
  final int unreadCount;

  ConversationSummary({
    required this.id,
    required this.peer,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> j) => ConversationSummary(
        id: j['id'] as String,
        peer: UserPublic.fromJson(j['peer'] as Map<String, dynamic>),
        createdAt: _dt(j['createdAt']),
        updatedAt: _dt(j['updatedAt']),
        lastMessage: j['lastMessage'] == null
            ? null
            : Message.fromJson(j['lastMessage'] as Map<String, dynamic>),
        unreadCount: (j['unreadCount'] as num?)?.toInt() ?? 0,
      );
}

/// ---------- 注册载荷（含企业信息） ----------

class NewCompany {
  final String name;
  final String? industry;
  final String? description;
  final String? location;
  final String? address;
  final String? website;
  NewCompany({
    required this.name,
    this.industry,
    this.description,
    this.location,
    this.address,
    this.website,
  });
  Map<String, dynamic> toJson() => {
        'name': name,
        'industry': industry,
        'description': description,
        'location': location,
        'address': address,
        'website': website,
      };
}

/// ---------- 线上面试 ----------

const interviewStatuses = ['invited', 'in_progress', 'finished', 'cancelled'];

String interviewStatusLabel(String s) {
  switch (s) {
    case 'invited':
      return '已邀请';
    case 'in_progress':
      return '进行中';
    case 'finished':
      return '已结束';
    case 'cancelled':
      return '已取消';
    default:
      return s;
  }
}

class InterviewView {
  final String id;
  final String applicationId;
  final String jobId;
  final String jobTitle;
  final String companyId;
  final String companyName;
  final String interviewerId;
  final String interviewerName;
  final String intervieweeId;
  final String intervieweeName;
  final String status;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  InterviewView({
    required this.id,
    required this.applicationId,
    required this.jobId,
    required this.jobTitle,
    required this.companyId,
    required this.companyName,
    required this.interviewerId,
    required this.interviewerName,
    required this.intervieweeId,
    required this.intervieweeName,
    required this.status,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  String get statusLabel => interviewStatusLabel(status);
  bool get canJoin =>
      status == 'invited' && (scheduledAt == null || !scheduledAt!.isAfter(DateTime.now()));
  String get modeText => scheduledAt == null ? '即时面试' : '预约时间 ${_fullTime(scheduledAt!)}';
  /// 对端名称（对方）
  String peerNameOf(String meId) =>
      interviewerId == meId ? intervieweeName : interviewerName;
  bool get isCancelledOrFinished =>
      status == 'finished' || status == 'cancelled';

  factory InterviewView.fromJson(Map<String, dynamic> j) => InterviewView(
        id: j['id'] as String,
        applicationId: j['applicationId'] as String,
        jobId: j['jobId'] as String,
        jobTitle: j['jobTitle'] as String,
        companyId: j['companyId'] as String,
        companyName: j['companyName'] as String,
        interviewerId: j['interviewerId'] as String,
        interviewerName: j['interviewerName'] as String,
        intervieweeId: j['intervieweeId'] as String,
        intervieweeName: j['intervieweeName'] as String,
        status: j['status'] as String? ?? 'invited',
        scheduledAt: j['scheduledAt'] == null ? null : _dt(j['scheduledAt']),
        startedAt: j['startedAt'] == null ? null : _dt(j['startedAt']),
        endedAt: j['endedAt'] == null ? null : _dt(j['endedAt']),
        createdAt: _dt(j['createdAt']),
        updatedAt: _dt(j['updatedAt']),
      );
}

String _two(int n) => n.toString().padLeft(2, '0');

String _fullTime(DateTime t) {
  final l = t.toLocal();
  return '${l.year}-${_two(l.month)}-${_two(l.day)} ${_two(l.hour)}:${_two(l.minute)}';
}


/// ---------- 投诉 ----------

String complaintStatusLabel(String s) {
  switch (s) {
    case 'pending':
      return '待审核';
    case 'approved':
      return '已通过（生效）';
    case 'rejected':
      return '已驳回';
    default:
      return s;
  }
}

class ComplaintView {
  final String id;
  final String companyId;
  final String companyName;
  final String complainantId;
  final String complainantName;
  final String evidence;
  final String status;
  final String? reviewNote;
  final String? reviewedBy;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final DateTime updatedAt;

  ComplaintView({
    required this.id,
    required this.companyId,
    required this.companyName,
    required this.complainantId,
    required this.complainantName,
    required this.evidence,
    required this.status,
    this.reviewNote,
    this.reviewedBy,
    required this.createdAt,
    this.reviewedAt,
    required this.updatedAt,
  });

  String get statusLabel => complaintStatusLabel(status);
  bool get pending => status == 'pending';

  factory ComplaintView.fromJson(Map<String, dynamic> j) => ComplaintView(
        id: j['id'] as String,
        companyId: j['companyId'] as String,
        companyName: j['companyName'] as String,
        complainantId: j['complainantId'] as String,
        complainantName: j['complainantName'] as String,
        evidence: j['evidence'] as String,
        status: j['status'] as String? ?? 'pending',
        reviewNote: _str(j, 'reviewNote'),
        reviewedBy: _str(j, 'reviewedBy'),
        createdAt: _dt(j['createdAt']),
        reviewedAt: j['reviewedAt'] == null ? null : _dt(j['reviewedAt']),
        updatedAt: _dt(j['updatedAt']),
      );
}
