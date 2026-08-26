import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class NotificationApi {
  const NotificationApi(this._client);

  final ApiClient _client;

  Future<List<NotificationDto>> list({int limit = 50, int offset = 0}) async {
    final rows = await _client.getList(
      ApiEndpoints.notifications,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return rows.whereType<Map>().map(NotificationDto.fromJson).toList();
  }

  Future<int> unreadCount() async {
    final json = await _client.getMap(ApiEndpoints.notificationUnreadCount);
    return (json['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<NotificationDto> markRead(String notificationId) async {
    final json = await _client.patchMap(
      ApiEndpoints.notificationRead(notificationId),
    );
    return NotificationDto.fromJson(json);
  }
}

class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.restaurantId,
    this.matchingPostId,
    this.actorUserId,
    this.readAt,
  });

  factory NotificationDto.fromJson(Map<dynamic, dynamic> json) {
    return NotificationDto(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '알림',
      body: json['body'] as String? ?? '',
      restaurantId: json['restaurantId'] as String?,
      matchingPostId: json['matchingPostId'] as String?,
      actorUserId: json['actorUserId'] as String?,
      readAt: json['readAt'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  final String id;
  final String type;
  final String title;
  final String body;
  final String? restaurantId;
  final String? matchingPostId;
  final String? actorUserId;
  final String? readAt;
  final String createdAt;
}
