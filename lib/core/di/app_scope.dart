import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/auth_session.dart';
import '../../shared/network/api_client.dart';

class AppController extends ChangeNotifier {
  static const _sessionStorageKey = 'auth_session';

  AppController();

  final ApiClient api = ApiClient();

  SharedPreferences? _prefs;
  AuthSession? _session;
  int? _selectedEventId;
  bool _initialized = false;

  AuthSession? get session => _session;
  int? get selectedEventId => _selectedEventId;
  bool get isInitialized => _initialized;

  bool get isAuthenticated => _session != null;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    final rawSession = _prefs!.getString(_sessionStorageKey);
    if (rawSession != null && rawSession.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSession) as Map<String, dynamic>;
        _session = AuthSession.fromJson(decoded);
      } catch (_) {
        await _prefs!.remove(_sessionStorageKey);
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    _session = await api.login(email: email, password: password);
    await _saveSession();
    notifyListeners();
  }

  Future<void> register(String name, String email, String password, UserRole role) async {
    _session = await api.register(name: name, email: email, password: password, role: role);
    await _saveSession();
    notifyListeners();
  }

  void logout() {
    _session = null;
    _selectedEventId = null;
    _prefs?.remove(_sessionStorageKey);
    notifyListeners();
  }

  void selectEvent(int eventId) {
    _selectedEventId = eventId;
    notifyListeners();
  }

  Future<void> _saveSession() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final rawSession = jsonEncode(_session!.toJson());
    await prefs.setString(_sessionStorageKey, rawSession);
  }
}

class AppScope extends InheritedNotifier<AppController> {
  AppScope({super.key, required AppController controller, required super.child})
    : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing in widget tree');
    return scope!.notifier!;
  }
}
