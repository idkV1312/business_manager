enum UserRole { user, performer, admin }

class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.name,
    required this.role,
  });

  final String token;
  final int userId;
  final String name;
  final UserRole role;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      userId: json['user_id'] as int,
      name: json['name'] as String,
      role: _roleFromString(json['role'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'token': token,
    'user_id': userId,
    'name': name,
    'role': _roleToString(role),
  };

  static UserRole _roleFromString(String value) {
    return switch (value) {
      'admin' => UserRole.admin,
      'performer' => UserRole.performer,
      _ => UserRole.user,
    };
  }

  static String _roleToString(UserRole role) {
    return switch (role) {
      UserRole.admin => 'admin',
      UserRole.performer => 'performer',
      UserRole.user => 'user',
    };
  }
}
