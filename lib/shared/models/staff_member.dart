class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.isApproved,
    required this.workPointId,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String email;
  final String password;
  final bool isApproved;
  final int? workPointId;
  final DateTime createdAt;

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      password: json['password'] as String? ?? '',
      isApproved: json['is_approved'] as bool? ?? false,
      workPointId: json['work_point_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
