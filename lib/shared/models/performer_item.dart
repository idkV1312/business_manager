class PerformerItem {
  const PerformerItem({required this.id, required this.name, required this.specialization});

  final int id;
  final String name;
  final String specialization;

  factory PerformerItem.fromJson(Map<String, dynamic> json) {
    return PerformerItem(
      id: json['id'] as int,
      name: json['name'] as String,
      specialization: json['specialization'] as String,
    );
  }
}
