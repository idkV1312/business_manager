class ChatMessageItem {
  const ChatMessageItem({
    required this.id,
    required this.eventId,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final int id;
  final int eventId;
  final int authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatMessageItem(
      id: json['id'] as int,
      eventId: json['event_id'] as int,
      authorId: json['author_id'] as int,
      authorName: json['author_name'] as String,
      text: json['text'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
