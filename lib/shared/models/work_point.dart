class WorkPointItem {
  const WorkPointItem({
    required this.id,
    required this.title,
    required this.address,
  });

  final int id;
  final String title;
  final String address;

  factory WorkPointItem.fromJson(Map<String, dynamic> json) {
    return WorkPointItem(
      id: json['id'] as int,
      title: json['title'] as String,
      address: json['address'] as String,
    );
  }
}
