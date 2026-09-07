class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.restaurantId,
    this.matchingPostId,
    this.actorUserId,
    this.chatRoomId,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? restaurantId;
  final String? matchingPostId;
  final String? actorUserId;
  final String? chatRoomId;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      restaurantId: restaurantId,
      matchingPostId: matchingPostId,
      actorUserId: actorUserId,
      chatRoomId: chatRoomId,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }
}
