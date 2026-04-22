class PerformerItem {
  const PerformerItem({
    required this.id,
    required this.name,
    required this.specialization,
    required this.userId,
  });

  final int id;
  final String name;
  final String specialization;
  final int? userId;

  factory PerformerItem.fromJson(Map<String, dynamic> json) {
    return PerformerItem(
      id: json['id'] as int,
      name: json['name'] as String,
      specialization: json['specialization'] as String,
      userId: json['user_id'] as int?,
    );
  }
}
