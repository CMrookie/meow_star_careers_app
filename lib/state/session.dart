import 'package:flutter/widgets.dart';

import '../core/api_exception.dart';
import '../core/app_config.dart';
import '../demo/demo_api_client.dart';
import '../demo/demo_realtime.dart';
import '../demo/demo_store.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/api_services.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/realtime_chat.dart';

enum SessionStatus { loading, anonymous, authenticated }

/// 会话状态机：负责启动恢复、登录/注册/登出、token 持久化与实时通道生命周期。
/// 支持「演示模式」：不依赖后端，登录演示账号后切换到内存数据仓库。
class SessionController extends ChangeNotifier {
  final AppConfig config;
  AuthService auth;
  ApiServices api;
  ChatService chat;
  RealtimeChat realtime;

  SessionStatus _status = SessionStatus.loading;
  User? _user;
  String? _bootError;
  bool _demo = false;

  SessionController({
    required this.config,
    ApiClient? apiClient,
  })  : auth = AuthService(apiClient ?? ApiClient(config)),
        api = ApiServices(apiClient ?? ApiClient(config)),
        chat = ChatService(apiClient ?? ApiClient(config)),
        realtime = RealtimeChat(config);

  SessionStatus get status => _status;
  User? get user => _user;
  String? get token => config.token;
  String? get bootError => _bootError;
  bool get isAuthenticated => _status == SessionStatus.authenticated && _user != null;
  bool get isDemo => _demo;

  /// 应用启动：恢复 token 并尝试拉取当前用户。
  Future<void> init() async {
    _status = SessionStatus.loading;
    notifyListeners();
    try {
      await config.load();
    } catch (_) {}
    final t = config.token;
    if (t == null || t.isEmpty) {
      _goAnonymous();
      return;
    }
    try {
      final me = await auth.me(t);
      _user = me;
      _status = SessionStatus.authenticated;
      _bootError = null;
      realtime.connect(t);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await config.saveToken(null);
        _bootError = '登录已失效，请重新登录';
      } else {
        _bootError = friendlyError(e);
      }
      _goAnonymous();
    } catch (e) {
      _bootError = '无法连接服务器：$e';
      _goAnonymous();
    }
    notifyListeners();
  }

  void _goAnonymous() {
    _user = null;
    _status = SessionStatus.anonymous;
  }

  Future<void> login({required String phone, required String password}) async {
    final res = await auth.login(phone: phone, password: password);
    await _onAuthed(res);
  }

  Future<void> register({
    required String phone,
    required String name,
    required String password,
    String role = 'seeker',
    NewCompany? company,
  }) async {
    final res = await auth.register(
      phone: phone,
      name: name,
      password: password,
      role: role,
      company: company,
    );
    await _onAuthed(res);
  }

  /// 进入开发演示模式：以演示账号登录（不连后端、不落盘 token）。
  Future<void> enterDemo({required String phone}) async {
    if (_demo && _user != null) return;
    final store = DemoBackend();
    final client = DemoApiClient(config, store);
    final res = AuthResponse.fromJson((await client.request('POST', '/auth/login',
        body: {'phone': phone, 'password': 'demo-dummy'})) as Map<String, dynamic>);

    realtime.disconnect();
    auth = AuthService(client);
    api = ApiServices(client);
    chat = ChatService(client);
    realtime = DemoRealtime(config, store);
    config.token = res.token; // 仅内存，不写入持久化设置
    _user = res.user;
    _status = SessionStatus.authenticated;
    _bootError = null;
    _demo = true;
    realtime.connect(res.token);
    notifyListeners();
  }

  Future<void> _onAuthed(AuthResponse res) async {
    await config.saveToken(res.token);
    _demo = false;
    _user = res.user;
    _status = SessionStatus.authenticated;
    _bootError = null;
    realtime.connect(res.token);
    notifyListeners();
  }

  Future<void> refreshUser() async {
    final t = token;
    if (t == null) return;
    final me = await auth.me(t);
    _user = me;
    notifyListeners();
  }

  Future<void> logout() async {
    final t = token;
    final wasDemo = _demo;
    if (t != null && !wasDemo) {
      try {
        await auth.logout(t);
      } catch (_) {
        // 忽略登出接口错误，本地一律清空
      }
    }
    realtime.disconnect();
    await config.saveToken(null);
    if (wasDemo) {
      // 复位回真实服务（下一轮可用手机号+密码登录真后端）
      auth = AuthService(ApiClient(config));
      api = ApiServices(ApiClient(config));
      chat = ChatService(ApiClient(config));
      realtime = RealtimeChat(config);
    }
    _demo = false;
    _goAnonymous();
    notifyListeners();
  }

  @override
  void dispose() {
    realtime.disconnect();
    super.dispose();
  }
}

/// InheritedNotifier：向整棵树暴露 SessionController。
class AppScope extends InheritedNotifier<SessionController> {
  const AppScope({super.key, required SessionController controller, required super.child})
      : super(notifier: controller);

  static SessionController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 未挂载');
    return scope!.notifier!;
  }

  /// 只读取值：可在 initState 等不允许注册依赖的阶段使用（不建立依赖关系）。
  static SessionController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope 未挂载');
    return scope!.notifier!;
  }
}
