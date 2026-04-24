import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import '../models/chat_message_item.dart';
import '../models/chat_participant_item.dart';
import '../models/event_item.dart';
import '../models/performer_item.dart';
import '../models/pending_staff_member.dart';
import '../models/product.dart';
import '../models/service_type.dart';
import '../models/staff_member.dart';
import '../models/work_point.dart';

class PendingApprovalException implements Exception {
  const PendingApprovalException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? _resolveBaseUrl();

  final String baseUrl;

  static String _resolveBaseUrl() {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    return 'http://45.93.138.73';
  }

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
        'role': switch (role) {
          UserRole.admin => 'admin',
          UserRole.performer => 'performer',
          UserRole.user => 'user',
        },
      }),
    );
    if (response.statusCode == 202) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw PendingApprovalException(
        (data['detail'] as String?) ?? 'Ожидает подтверждения администратором',
      );
    }
    _throwIfError(response);
    return AuthSession.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    _throwIfError(response);
    return AuthSession.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<EventItem>> getEvents(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/events'),
      headers: _headers(token),
    );
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => EventItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<PerformerItem>> getPerformers(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/performers'),
      headers: _headers(token),
    );
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => PerformerItem.fromJson(item as Map<String, dynamic>))
        .toList();
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
    return PerformerItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
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
    return EventItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> bookEvent(String token, int eventId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/events/$eventId/book'),
      headers: _headers(token),
    );
    _throwIfError(response);
  }

  Future<List<ChatMessageItem>> getChatMessages(
    String token,
    int eventId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/events/$eventId/chat'),
      headers: _headers(token),
    );
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => ChatMessageItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessageItem> sendChatMessage(
    String token,
    int eventId,
    String text,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/events/$eventId/chat'),
      headers: _headers(token),
      body: jsonEncode({'text': text}),
    );
    _throwIfError(response);
    return ChatMessageItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<ChatParticipantItem>> getEventBookedUsers(
    String token,
    int eventId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/events/$eventId/booked-users'),
      headers: _headers(token),
    );
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map(
          (item) => ChatParticipantItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<ChatMessageItem>> getDirectChatMessages(
    String token,
    int eventId, {
    int? userId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/events/$eventId/direct-chat',
    ).replace(queryParameters: userId == null ? null : {'user_id': '$userId'});
    final response = await http.get(uri, headers: _headers(token));
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => ChatMessageItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ChatMessageItem> sendDirectChatMessage(
    String token,
    int eventId,
    String text, {
    int? userId,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/events/$eventId/direct-chat',
    ).replace(queryParameters: userId == null ? null : {'user_id': '$userId'});
    final response = await http.post(
      uri,
      headers: _headers(token),
      body: jsonEncode({'text': text}),
    );
    _throwIfError(response);
    return ChatMessageItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<Product>> getProducts(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/products'),
      headers: _headers(token),
    );
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Product> createProduct(
    String token, {
    required String title,
    required String category,
    required int stock,
    required int price,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/products'),
      headers: _headers(token),
      body: jsonEncode({
        'title': title,
        'category': category,
        'stock': stock,
        'price': price,
      }),
    );
    _throwIfError(response);
    return Product.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<ServiceTypeItem>> getServices(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/services'),
      headers: _headers(token),
    );
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => ServiceTypeItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ServiceTypeItem> createService(
    String token, {
    required String title,
    required String category,
    required int price,
    required int durationMinutes,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/services'),
      headers: _headers(token),
      body: jsonEncode({
        'title': title,
        'category': category,
        'price': price,
        'duration_minutes': durationMinutes,
      }),
    );
    _throwIfError(response);
    return ServiceTypeItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<WorkPointItem>> getWorkPoints(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/work-points'),
      headers: _headers(token),
    );
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => WorkPointItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WorkPointItem> createWorkPoint(
    String token, {
    required String title,
    required String address,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/work-points'),
      headers: _headers(token),
      body: jsonEncode({'title': title, 'address': address}),
    );
    _throwIfError(response);
    return WorkPointItem.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<PendingStaffMember>> getPendingStaff(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/staff/pending'),
      headers: _headers(token),
    );
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map(
          (item) => PendingStaffMember.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> approveStaff(
    String token, {
    required int userId,
    required int workPointId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/staff/$userId/approve'),
      headers: _headers(token),
      body: jsonEncode({'work_point_id': workPointId}),
    );
    _throwIfError(response);
  }

  Future<List<StaffMember>> getStaff(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/staff'),
      headers: _headers(token),
    );
    _throwIfError(response);
    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => StaffMember.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body;
      throw Exception(body.isEmpty ? 'HTTP ${response.statusCode}' : body);
    }
  }
}
