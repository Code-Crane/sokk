class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String senderId;
  final String text;
  final DateTime createdAt;

  bool get isSystem => senderId == 'system';
}
