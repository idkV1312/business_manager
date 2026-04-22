class ChatParticipantItem {
  const ChatParticipantItem({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory ChatParticipantItem.fromJson(Map<String, dynamic> json) {
    return ChatParticipantItem(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}
