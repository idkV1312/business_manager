class ServiceTypeItem {
  const ServiceTypeItem({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    required this.durationMinutes,
  });

  final int id;
  final String title;
  final String category;
  final int price;
  final int durationMinutes;

  factory ServiceTypeItem.fromJson(Map<String, dynamic> json) {
    return ServiceTypeItem(
      id: json['id'] as int,
      title: json['title'] as String,
      category: json['category'] as String,
      price: json['price'] as int,
      durationMinutes: json['duration_minutes'] as int,
    );
  }
}
