class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.startAt,
    required this.endAt,
    required this.performerIds,
    required this.performerNames,
  });

  final int id;
  final String title;
  final String description;
  final String category;
  final DateTime startAt;
  final DateTime endAt;
  final List<int> performerIds;
  final List<String> performerNames;

  factory EventItem.fromJson(Map<String, dynamic> json) {
    return EventItem(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      startAt: DateTime.parse(json['start_at'] as String).toLocal(),
      endAt: DateTime.parse(json['end_at'] as String).toLocal(),
      performerIds: ((json['performer_ids'] as List?) ?? []).cast<int>(),
      performerNames: ((json['performer_names'] as List?) ?? []).cast<String>(),
    );
  }
}
