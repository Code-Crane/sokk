import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class ChatApi {
  const ChatApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ChatRoomDto>> listRooms() async {
    final list = await _apiClient.getList(ApiEndpoints.chatRooms);
    return list
        .whereType<Map>()
        .map((json) => ChatRoomDto.fromJson(json))
        .toList();
  }

  Future<List<ChatMessageDto>> listMessages(String roomId) async {
    final list = await _apiClient.getList(ApiEndpoints.chatMessages(roomId));
    return list
        .whereType<Map>()
        .map((json) => ChatMessageDto.fromJson(json))
        .toList();
  }

  Future<ChatMessageDto> sendMessage({
    required String roomId,
    required String text,
  }) async {
    final json = await _apiClient.postMap(
      ApiEndpoints.chatMessages(roomId),
      data: {'text': text},
    );
    return ChatMessageDto.fromJson(json);
  }
}

class ChatRoomDto {
  const ChatRoomDto({
    required this.id,
    required this.postId,
    required this.title,
    required this.participantIds,
    required this.status,
    required this.updatedAt,
  });

  factory ChatRoomDto.fromJson(Map<dynamic, dynamic> json) {
    return ChatRoomDto(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      title: json['title'] as String? ?? '채팅방',
      participantIds: (json['participantIds'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      status: json['status'] as String? ?? 'active',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  final String id;
  final String postId;
  final String title;
  final List<String> participantIds;
  final String status;
  final String updatedAt;
}

class ChatMessageDto {
  const ChatMessageDto({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessageDto.fromJson(Map<dynamic, dynamic> json) {
    return ChatMessageDto(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      text: json['text'] as String? ?? '',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  final String id;
  final String roomId;
  final String senderId;
  final String text;
  final String createdAt;
}
