import '../domain/app_notification.dart';
import 'notification_api.dart';

abstract class NotificationRepository {
  Future<List<AppNotification>> list({int limit = 50, int offset = 0});
  Future<int> unreadCount();
  Future<AppNotification> markRead(String notificationId);
}

class ApiNotificationRepository implements NotificationRepository {
  const ApiNotificationRepository(this._api);

  final NotificationApi _api;

  @override
  Future<List<AppNotification>> list({int limit = 50, int offset = 0}) async {
    return (await _api.list(limit: limit, offset: offset))
        .map(_toDomain)
        .toList();
  }

  @override
  Future<int> unreadCount() => _api.unreadCount();

  @override
  Future<AppNotification> markRead(String notificationId) async {
    return _toDomain(await _api.markRead(notificationId));
  }

  AppNotification _toDomain(NotificationDto dto) {
    return AppNotification(
      id: dto.id,
      type: dto.type,
      title: dto.title,
      body: dto.body,
      restaurantId: dto.restaurantId,
      matchingPostId: dto.matchingPostId,
      actorUserId: dto.actorUserId,
      chatRoomId: dto.chatRoomId,
      readAt: DateTime.tryParse(dto.readAt ?? '')?.toLocal(),
      createdAt: DateTime.tryParse(dto.createdAt)?.toLocal() ?? DateTime.now(),
    );
  }
}

class MockNotificationRepository implements NotificationRepository {
  MockNotificationRepository(List<AppNotification> notifications)
      : _notifications = [...notifications];

  final List<AppNotification> _notifications;

  @override
  Future<List<AppNotification>> list({int limit = 50, int offset = 0}) async {
    return _notifications.skip(offset).take(limit).toList();
  }

  @override
  Future<int> unreadCount() async {
    return _notifications.where((notification) => !notification.isRead).length;
  }

  @override
  Future<AppNotification> markRead(String notificationId) async {
    final index =
        _notifications.indexWhere((item) => item.id == notificationId);
    if (index < 0) throw StateError('Mock notification not found.');
    final updated = _notifications[index].copyWith(readAt: DateTime.now());
    _notifications[index] = updated;
    return updated;
  }
}
