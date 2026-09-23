import '../services/api_client.dart';
import 'demo_store.dart';

/// 演示模式下的 HTTP 客户端：不联网，把请求路由到内存 DemoBackend。
class DemoApiClient extends ApiClient {
  final DemoBackend backend;

  DemoApiClient(super.config, this.backend);

  @override
  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    String? token,
  }) async {
    // 模拟网络延迟，便于观察 loading 态
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return backend.handle(method, path, query: query, body: body, token: token);
  }
}
