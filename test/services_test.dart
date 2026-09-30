import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:meow_star_careers_app/core/api_exception.dart';
import 'package:meow_star_careers_app/core/app_config.dart';
import 'package:meow_star_careers_app/models/models.dart';
import 'package:meow_star_careers_app/services/api_client.dart';
import 'package:meow_star_careers_app/services/api_services.dart';
import 'package:meow_star_careers_app/services/auth_service.dart';
import 'package:meow_star_careers_app/services/chat_service.dart';

const _uuid1 = '11111111-1111-1111-1111-111111111111';
const _uuid2 = '22222222-2222-2222-2222-222222222222';

http.Response _json(Object body, [int code = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  code,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  late AppConfig config;

  setUp(() {
    config = AppConfig(MemorySettingsStore());
    config.token = 'test-token';
  });

  group('AuthService', () {
    test('register 正确序列化招聘者企业载荷', () async {
      const phone = '13900000001';
      final client = MockClient((req) async {
        expect(req.url.path, '/api/v1/auth/register');
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['role'], 'recruiter');
        expect(body['phone'], phone);
        expect((body['company'] as Map)['name'], '星河科技');
        expect(body['company'], contains('industry'));
        expect(body.containsKey('email'), isFalse);
        return _json({
          'token': 'tok',
          'user': {
            'id': _uuid1,
            'email': null,
            'phone': phone,
            'name': 'HR',
            'isActive': true,
            'role': 'recruiter',
            'companyId': _uuid2,
            'createdAt': '2024-09-08T08:00:00Z',
            'updatedAt': '2024-09-08T08:00:00Z',
          },
        }, 201);
      });
      final auth = AuthService(ApiClient(config, client: client));
      final res = await auth.register(
        phone: phone,
        name: 'HR',
        password: 'secret123',
        role: 'recruiter',
        company: NewCompany(name: '星河科技', industry: '互联网', location: '北京'),
      );
      expect(res.user.role, 'recruiter');
      expect(res.user.phone, phone);
      expect(res.user.email, isNull);
    });

    test('login 携带 Authorization 之前的公开请求与解析', () async {
      const phone = '13800138000';
      final client = MockClient((req) async {
        expect(req.url.path, '/api/v1/auth/login');
        expect(req.headers['authorization'], isNull);
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        expect(body['password'], 'secret123');
        expect(body['phone'], phone);
        return _json({
          'token': 'tok-2',
          'user': {
            'id': _uuid1,
            'email': null,
            'phone': phone,
            'name': 'A',
            'isActive': true,
            'role': 'seeker',
            'createdAt': '2024-09-08T08:00:00Z',
            'updatedAt': '2024-09-08T08:00:00Z',
          },
        });
      });
      final auth = AuthService(ApiClient(config, client: client));
      final res = await auth.login(phone: phone, password: 'secret123');
      expect(res.token, 'tok-2');
      expect(res.user.phone, phone);
    });

    test('统一错误体 -> ApiException', () async {
      final client = MockClient((req) async {
        return _json({'code': 'unauthorized', 'message': '无效或已过期的 token'}, 401);
      });
      final auth = AuthService(ApiClient(config, client: client));
      await expectLater(
        auth.me('bad'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 401)
              .having((e) => e.code, 'code', 'unauthorized')
              .having((e) => e.message, 'message', '无效或已过期的 token'),
        ),
      );
    });
  });

  group('ApiServices', () {
    test('搜索职位拼接查询参数并解析分页', () async {
      late Uri captured;
      late Map<String, String> headers;
      final client = MockClient((req) async {
        captured = req.url;
        headers = req.headers;
        return _json({
          'items': [
            {
              'id': _uuid1,
              'companyId': _uuid2,
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
        });
      });
      final api = ApiServices(ApiClient(config, client: client));
      final page = await api.searchJobs(
        config.token!,
        keyword: '后端',
        location: '北京',
        page: 1,
      );
      expect(captured.path, '/api/v1/jobs');
      expect(captured.queryParameters['keyword'], '后端');
      expect(captured.queryParameters['location'], '北京');
      expect(captured.queryParameters['page'], '1');
      expect(captured.queryParameters['salaryMin'], isNull);
      expect(headers['authorization'], 'Bearer test-token');
      expect(page.items.first.title, '后端工程师');
    });

    test('投递/状态推进请求体', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/apply')) {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['resumeId'], _uuid1);
          expect(body['coverLetter'], '你好');
          return _json({
            'id': 'a1',
            'jobId': _uuid1,
            'jobTitle': '后端',
            'companyId': _uuid2,
            'companyName': '星河科技',
            'seekerId': _uuid1,
            'seekerName': '张三',
            'seekerEmail': 'z@x.com',
            'status': 'pending',
            'createdAt': '2024-09-08T08:00:00Z',
            'updatedAt': '2024-09-08T08:00:00Z',
          }, 201);
        }
        if (req.url.path.endsWith('/status')) {
          expect(jsonDecode(req.body), {'status': 'interviewing'});
          return _json({
            'id': 'a1',
            'jobId': _uuid1,
            'jobTitle': '后端',
            'companyId': _uuid2,
            'companyName': '星河科技',
            'seekerId': _uuid1,
            'seekerName': '张三',
            'seekerEmail': 'z@x.com',
            'status': 'interviewing',
            'createdAt': '2024-09-08T08:00:00Z',
            'updatedAt': '2024-09-08T08:00:00Z',
          });
        }
        fail('unexpected path ${req.url.path}');
      });
      final api = ApiServices(ApiClient(config, client: client));
      final app = await api.applyJob(
        _uuid1,
        config.token!,
        resumeId: _uuid1,
        coverLetter: '你好',
      );
      expect(app.status, 'pending');
      await api.setApplicationStatus('a1', 'interviewing', config.token!);
    });

    test('简历列表为裸数组解析', () async {
      final client = MockClient((req) async {
        return _json([
          {
            'id': _uuid1,
            'userId': _uuid2,
            'fullName': '张三',
            'title': 'Flutter 工程师',
            'years': 3,
            'education': '本科',
            'isPublic': true,
            'createdAt': '2024-09-08T08:00:00Z',
            'updatedAt': '2024-09-08T08:00:00Z',
          },
        ]);
      });
      final api = ApiServices(ApiClient(config, client: client));
      final list = await api.myResumes(config.token!);
      expect(list.length, 1);
      expect(list.first.fullName, '张三');
    });
  });

  group('ChatService', () {
    test('历史消息 cursor 分页参数', () async {
      late Uri captured;
      final client = MockClient((req) async {
        captured = req.url;
        return _json([
          {
            'id': 9,
            'conversationId': 'c1',
            'senderId': 'p1',
            'recipientId': 'me',
            'content': 'hi',
            'createdAt': '2024-09-08T08:00:00Z',
            'readAt': null,
          },
        ]);
      });
      final chat = ChatService(ApiClient(config, client: client));
      final msgs = await chat.messages(
        'c1',
        config.token!,
        limit: 50,
        before: 100,
      );
      expect(captured.path, '/api/v1/conversations/c1/messages');
      expect(captured.queryParameters['before'], '100');
      expect(captured.queryParameters['limit'], '50');
      expect(msgs.single.id, 9);
    });
  });

  group('ApiServices interviews', () {
    Map<String, dynamic> ivJson(String status) => {
      'id': 'iv1',
      'applicationId': 'a1',
      'jobId': 'j1',
      'jobTitle': '后端工程师（Go）',
      'companyId': 'c1',
      'companyName': '星河科技',
      'interviewerId': _uuid1,
      'interviewerName': 'HR',
      'intervieweeId': _uuid2,
      'intervieweeName': '张三',
      'status': status,
      'scheduledAt': null,
      'startedAt': null,
      'endedAt': null,
      'createdAt': '2025-01-18T08:00:00Z',
      'updatedAt': '2025-01-18T08:00:00Z',
    };

    test('createInterview 请求体（预约时间 UTC）', () async {
      late Map<String, dynamic> body;
      final client = MockClient((req) async {
        expect(req.url.path, '/api/v1/interviews');
        body = jsonDecode(req.body) as Map<String, dynamic>;
        return _json(ivJson('invited'), 201);
      });
      final api = ApiServices(ApiClient(config, client: client));
      final iv = await api.createInterview(
        applicationId: 'a1',
        scheduledAt: DateTime.utc(2025, 1, 20, 10),
        token: config.token!,
      );
      expect(body['applicationId'], 'a1');
      expect(body['scheduledAt'], '2025-01-20T10:00:00.000Z');
      expect(iv.status, 'invited');
    });

    test('start/finish/cancel 路由与解析', () async {
      final client = MockClient((req) async {
        if (req.method == 'POST' && req.url.path.endsWith('/start')) {
          return _json(ivJson('in_progress'));
        }
        if (req.method == 'POST' && req.url.path.endsWith('/finish')) {
          return _json(ivJson('finished'));
        }
        if (req.method == 'POST' && req.url.path.endsWith('/cancel')) {
          return _json(ivJson('cancelled'));
        }
        fail('unexpected ${req.method} ${req.url.path}');
      });
      final api = ApiServices(ApiClient(config, client: client));
      expect(
        (await api.startInterview('iv1', config.token!)).status,
        'in_progress',
      );
      expect(
        (await api.finishInterview('iv1', config.token!)).status,
        'finished',
      );
      expect(
        (await api.cancelInterview('iv1', config.token!)).status,
        'cancelled',
      );
    });
  });

  group('AppConfig · TURN 配置持久化', () {
    test('未配置时 hasTurn 为 false，且重启后仍为空', () async {
      final store = MemorySettingsStore();
      final cfg = AppConfig(store);
      await cfg.load();
      expect(cfg.hasTurn, isFalse);
      expect(cfg.turnUrl, isNull);

      // 模拟重启：新实例读同一个 store
      final again = AppConfig(store);
      await again.load();
      expect(again.hasTurn, isFalse);
    });

    test('saveTurn 会写入 store，重启后能读回', () async {
      final store = MemorySettingsStore();
      final cfg = AppConfig(store);
      await cfg.saveTurn(
        url: 'turn:1.2.3.4:3478?transport=udp',
        user: 'meow',
        cred: 'secret',
      );
      expect(cfg.hasTurn, isTrue);

      final again = AppConfig(store);
      await again.load();
      expect(again.turnUrl, 'turn:1.2.3.4:3478?transport=udp');
      expect(again.turnUser, 'meow');
      expect(again.turnCred, 'secret');
    });

    test('空白与首尾空格会被规整：空串等于清空，非空会 trim', () async {
      final store = MemorySettingsStore();
      final cfg = AppConfig(store);

      await cfg.saveTurn(url: '  turn:a.com:80  ', user: '  ', cred: '\n');
      expect(cfg.turnUrl, 'turn:a.com:80', reason: '首尾空格应被去掉');
      expect(cfg.turnUser, isNull, reason: '只有空白等于未填');
      expect(cfg.turnCred, isNull);

      await cfg.saveTurn(url: '   ', user: 'u', cred: 'c');
      expect(cfg.hasTurn, isFalse, reason: '空白地址等于不使用 TURN');
      expect(cfg.turnUrl, isNull);
    });

    test('clearTurn 会把三个字段从 store 中移除', () async {
      final store = MemorySettingsStore();
      final cfg = AppConfig(store);
      await cfg.saveTurn(url: 'turn:a.com:80', user: 'u', cred: 'c');
      await cfg.clearTurn();

      expect(cfg.hasTurn, isFalse);
      expect(await store.read('turnUrl'), isNull,
          reason: '应删除而不是写入空串，避免下次读出 ""');
      expect(await store.read('turnUser'), isNull);
      expect(await store.read('turnCred'), isNull);
    });
  });
}
