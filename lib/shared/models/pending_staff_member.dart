class PendingStaffMember {
  const PendingStaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final String password;
  final DateTime createdAt;

  factory PendingStaffMember.fromJson(Map<String, dynamic> json) {
    return PendingStaffMember(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      password: json['password'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
