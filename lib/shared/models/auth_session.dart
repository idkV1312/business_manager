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
      role: switch (json['role'] as String) {
        'admin' => UserRole.admin,
        'performer' => UserRole.performer,
        _ => UserRole.user,
      },
    );
  }
}
