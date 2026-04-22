import 'package:flutter/widgets.dart';

import '../../shared/models/auth_session.dart';
import '../../shared/network/api_client.dart';

class AppController extends ChangeNotifier {
  final ApiClient api = ApiClient();

  AuthSession? _session;
  int? _selectedEventId;

  AuthSession? get session => _session;
  int? get selectedEventId => _selectedEventId;

  bool get isAuthenticated => _session != null;

  Future<void> login(String email, String password) async {
    _session = await api.login(email: email, password: password);
    notifyListeners();
  }

  Future<void> register(String name, String email, String password, UserRole role) async {
    _session = await api.register(name: name, email: email, password: password, role: role);
    notifyListeners();
  }

  void logout() {
    _session = null;
    _selectedEventId = null;
    notifyListeners();
  }

  void selectEvent(int eventId) {
    _selectedEventId = eventId;
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  AppScope({super.key, required super.child}) : super(notifier: AppController());

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing in widget tree');
    return scope!.notifier!;
  }
}
