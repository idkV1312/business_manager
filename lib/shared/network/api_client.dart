import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import '../models/chat_message_item.dart';
import '../models/event_item.dart';
import '../models/performer_item.dart';

class ApiClient {
  ApiClient({String? baseUrl})
    : baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000');

  final String baseUrl;

  Map<String, String> _headers([String? token]) => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role == UserRole.admin ? 'admin' : 'user',
      }),
    );
    _throwIfError(response);
    return AuthSession.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AuthSession> login({required String email, required String password}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    _throwIfError(response);
    return AuthSession.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<EventItem>> getEvents(String token) async {
    final response = await http.get(Uri.parse('$baseUrl/events'), headers: _headers(token));
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => EventItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<PerformerItem>> getPerformers(String token) async {
    final response = await http.get(Uri.parse('$baseUrl/performers'), headers: _headers(token));
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => PerformerItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<PerformerItem> createPerformer(
    String token, {
    required String name,
    required String specialization,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/performers'),
      headers: _headers(token),
      body: jsonEncode({'name': name, 'specialization': specialization}),
    );
    _throwIfError(response);
    return PerformerItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<EventItem> createEvent(
    String token, {
    required String title,
    required String description,
    required String category,
    required DateTime startAt,
    required DateTime endAt,
    required List<int> performerIds,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/events'),
      headers: _headers(token),
      body: jsonEncode({
        'title': title,
        'description': description,
        'category': category,
        'start_at': startAt.toUtc().toIso8601String(),
        'end_at': endAt.toUtc().toIso8601String(),
        'performer_ids': performerIds,
      }),
    );
    _throwIfError(response);
    return EventItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> bookEvent(String token, int eventId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/events/$eventId/book'),
      headers: _headers(token),
    );
    _throwIfError(response);
  }

  Future<List<ChatMessageItem>> getChatMessages(String token, int eventId) async {
    final response = await http.get(Uri.parse('$baseUrl/events/$eventId/chat'), headers: _headers(token));
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data.map((item) => ChatMessageItem.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ChatMessageItem> sendChatMessage(String token, int eventId, String text) async {
    final response = await http.post(
      Uri.parse('$baseUrl/events/$eventId/chat'),
      headers: _headers(token),
      body: jsonEncode({'text': text}),
    );
    _throwIfError(response);
    return ChatMessageItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body;
      throw Exception(body.isEmpty ? 'HTTP ${response.statusCode}' : body);
    }
  }
}
