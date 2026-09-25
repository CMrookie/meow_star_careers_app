import 'package:flutter_test/flutter_test.dart';

import 'package:meow_star_careers_app/core/format.dart';
import 'package:meow_star_careers_app/models/models.dart';

void main() {
  group('模型 JSON 解析（与后端 camelCase 字段对齐）', () {
    test('User', () {
      final u = User.fromJson({
        'id': '11111111-1111-1111-1111-111111111111',
        'email': null,
        'phone': '13800138000',
        'name': 'Alice',
        'isActive': true,
        'role': 'recruiter',
        'companyId': '22222222-2222-2222-2222-222222222222',
        'createdAt': '2024-09-08T08:00:00Z',
        'updatedAt': '2024-09-08T08:00:00Z',
      });
      expect(u.name, 'Alice');
      expect(u.isRecruiter, isTrue);
      expect(u.phone, '13800138000');
      expect(u.email, isNull);
      expect(u.contactDisplay, '13800138000');
      expect(u.companyId, '22222222-2222-2222-2222-222222222222');
    });

    test('AuthResponse', () {
      final res = AuthResponse.fromJson({
        'token': 'tok-1',
        'user': {
          'id': '11111111-1111-1111-1111-111111111111',
          'email': 'a@x.com',
          'name': 'A',
          'isActive': true,
          'role': 'seeker',
          'createdAt': '2024-09-08T08:00:00Z',
          'updatedAt': '2024-09-08T08:00:00Z',
        },
      });
      expect(res.token, 'tok-1');
      expect(res.user.isSeeker, isTrue);
    });

    test('JobView 含可空薪资/要求', () {
      final j = JobView.fromJson({
        'id': '33333333-3333-3333-3333-333333333333',
        'companyId': '22222222-2222-2222-2222-222222222222',
        'companyName': '星河科技',
        'title': '后端工程师',
        'description': '云原生平台后端',
        'requirements': null,
        'location': '北京',
        'salaryMin': 20000,
        'salaryMax': 35000,
        'jobType': 'full_time',
        'experience': '3-5年',
        'education': null,
        'isActive': true,
        'createdBy': '11111111-1111-1111-1111-111111111111',
        'createdAt': '2024-09-08T08:00:00Z',
        'updatedAt': '2024-09-08T08:00:00Z',
      });
      expect(j.title, '后端工程师');
      expect(j.salaryMin, 20000);
      expect(j.jobType, 'full_time');
      expect(salaryText(j.salaryMin, j.salaryMax), '20K-35K');
      expect(salaryText(null, null), '薪资面议');
    });

    test('JobPage 分页解析', () {
      final page = Paged.fromJson({
        'items': [
          {
            'id': '33333333-3333-3333-3333-333333333333',
            'companyId': 'c',
            'companyName': '星河科技',
            'title': '后端工程师',
            'description': 'x',
            'jobType': 'full_time',
            'isActive': true,
            'createdAt': '2024-09-08T08:00:00Z',
            'updatedAt': '2024-09-08T08:00:00Z',
          },
        ],
        'total': 1,
        'page': 1,
        'pageSize': 20,
      }, JobView.fromJson);
      expect(page.items.length, 1);
      expect(page.total, 1);
    });

    test('ApplicationView 状态流转文案', () {
      final app = ApplicationView.fromJson({
        'id': 'a1',
        'jobId': 'j1',
        'jobTitle': 'Flutter 工程师',
        'companyId': 'c1',
        'companyName': '职聘科技',
        'seekerId': 's1',
        'seekerName': '张三',
        'seekerEmail': null,
        'seekerPhone': '13800138000',
        'coverLetter': '你好',
        'status': 'interviewing',
        'createdAt': '2024-09-08T08:00:00Z',
        'updatedAt': '2024-09-08T08:00:00Z',
      });
      expect(app.statusLabel, '面试中');
      expect(applicationStatusLabel('offered'), '已录用');
      expect(applicationStatuses.length, 6);
      expect(app.seekerContact, '13800138000');
    });

    test('会话与消息解析（含空 lastMessage）', () {
      final conv = ConversationSummary.fromJson({
        'id': 'c1',
        'peer': {'id': 'p1', 'name': 'HR'},
        'createdAt': '2024-09-08T08:00:00Z',
        'updatedAt': '2024-09-08T09:00:00Z',
        'lastMessage': null,
        'unreadCount': 3,
      });
      expect(conv.peer.name, 'HR');
      expect(conv.unreadCount, 3);
      expect(conv.lastMessage, isNull);

      final m = Message.fromJson({
        'id': 5,
        'conversationId': 'c1',
        'senderId': 'p1',
        'recipientId': 'me',
        'content': '约个面试时间？',
        'createdAt': '2024-09-08T09:00:00Z',
        'readAt': null,
      });
      expect(m.content, '约个面试时间？');
      expect(m.readAt, isNull);
    });

    test('简历/企业解析', () {
      final resume = Resume.fromJson({
        'id': 'r1',
        'userId': 'u1',
        'fullName': '张三',
        'title': 'Flutter 工程师',
        'phone': '13800138000',
        'years': 3,
        'education': '本科',
        'isPublic': true,
        'createdAt': '2024-09-08T08:00:00Z',
        'updatedAt': '2024-09-08T08:00:00Z',
      });
      expect(resume.fullName, '张三');
      expect(resume.years, 3);

      final company = Company.fromJson({
        'id': 'c1',
        'name': '星河科技',
        'industry': '互联网',
        'location': '北京',
        'isActive': true,
        'createdAt': '2024-09-08T08:00:00Z',
        'updatedAt': '2024-09-08T08:00:00Z',
      });
      expect(company.name, '星河科技');
    });

    test('InterviewView 解析、状态标签与预约文案', () {
      final iv = InterviewView.fromJson({
        'id': 'iv1',
        'applicationId': 'a1',
        'jobId': 'j1',
        'jobTitle': '后端工程师（Go）',
        'companyId': 'c1',
        'companyName': '星河科技',
        'interviewerId': 'hr-1',
        'interviewerName': '演示招聘官',
        'intervieweeId': 'sk-1',
        'intervieweeName': '演示求职者',
        'status': 'invited',
        'scheduledAt': '2025-01-20T10:00:00Z',
        'startedAt': null,
        'endedAt': null,
        'createdAt': '2025-01-18T08:00:00Z',
        'updatedAt': '2025-01-18T08:00:00Z',
      });
      expect(iv.statusLabel, '已邀请');
      expect(iv.peerNameOf('hr-1'), '演示求职者');
      expect(iv.modeText, contains('预约时间'));
      expect(interviewStatusLabel('in_progress'), '进行中');

      final instant = InterviewView.fromJson({
        'id': 'iv2',
        'applicationId': 'a1',
        'jobId': 'j1',
        'jobTitle': 't',
        'companyId': 'c1',
        'companyName': 'c',
        'interviewerId': 'hr-1',
        'interviewerName': 'A',
        'intervieweeId': 'sk-1',
        'intervieweeName': 'B',
        'status': 'invited',
        'scheduledAt': null,
        'createdAt': '2025-01-18T08:00:00Z',
        'updatedAt': '2025-01-18T08:00:00Z',
      });
      expect(instant.modeText, '即时面试');
      expect(instant.canJoin, isTrue);
    });
  });
}
