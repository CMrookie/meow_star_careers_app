import '../models/models.dart';
import 'api_client.dart';

/// 认证相关接口（公开，无需 token）。账号体系：手机号 + 密码。
class AuthService {
  final ApiClient api;
  AuthService(this.api);

  Future<AuthResponse> register({
    required String phone,
    required String name,
    required String password,
    String role = 'seeker',
    NewCompany? company,
  }) async {
    final data = await api.request('POST', '/auth/register', body: {
      'phone': phone,
      'name': name.trim(),
      'password': password,
      'role': role,
      if (company != null) 'company': company.toJson(),
    });
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthResponse> login({required String phone, required String password}) async {
    final data = await api.request('POST', '/auth/login', body: {
      'phone': phone,
      'password': password,
    });
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<User> me(String token) async {
    final data = await api.request('GET', '/auth/me', token: token);
    return User.fromJson(data as Map<String, dynamic>);
  }

  Future<void> logout(String token) async {
    await api.request('POST', '/auth/logout', token: token);
  }
}
