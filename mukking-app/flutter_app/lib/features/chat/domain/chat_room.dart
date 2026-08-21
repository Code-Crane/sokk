class ChatRoom {
  const ChatRoom({
    required this.id,
    required this.postId,
    required this.title,
    required this.participantIds,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String postId;
  final String title;
  final List<String> participantIds;
  final String status;
  final DateTime updatedAt;
}
