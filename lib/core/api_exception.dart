/// 统一 API 异常：携带 HTTP 状态码与后端 {code,message} 错误码。
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;

  ApiException(this.statusCode, this.code, this.message);

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// 网络不可达等底层错误
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => message;
}
