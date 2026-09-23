import '../models/models.dart';
import 'api_client.dart';

/// 私聊 REST 接口。
class ChatService {
  final ApiClient api;
  ChatService(this.api);

  Future<List<ConversationSummary>> conversations(String token) async {
    final data = await api.request('GET', '/conversations', token: token);
    return (data as List<dynamic>)
        .map((e) => ConversationSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ConversationSummary> start(String userId, String token) async {
    final data =
        await api.request('POST', '/conversations', token: token, body: {'userId': userId});
    return ConversationSummary.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Message>> messages(
    String conversationId,
    String token, {
    int limit = 50,
    int? before,
  }) async {
    final data = await api.request('GET', '/conversations/$conversationId/messages',
        token: token, query: {'limit': limit, 'before': ?before});
    return (data as List<dynamic>).map((e) => Message.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Message> send(String conversationId, String body, String token) async {
    final data = await api.request('POST', '/conversations/$conversationId/messages',
        token: token, body: {'body': body});
    return Message.fromJson(data as Map<String, dynamic>);
  }

  Future<void> markRead(String conversationId, String token) async {
    await api.request('POST', '/conversations/$conversationId/read', token: token);
  }
}
