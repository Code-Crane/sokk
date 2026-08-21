import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/chat_message.dart';
import '../domain/chat_room.dart';
import 'chat_api.dart';

abstract class ChatRepository {
  Future<List<ChatRoom>> listRooms();
  Future<List<ChatMessage>> listMessages(String roomId);
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String text,
  });
}

final chatApiProvider = Provider<ChatApi>((ref) {
  return ChatApi(ref.watch(apiClientProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final config = ref.watch(appConfigProvider);

  if (config.usesApiData) {
    return ApiChatRepository(ref.watch(chatApiProvider));
  }

  return const MockChatRepository();
});

class MockChatRepository implements ChatRepository {
  const MockChatRepository();

  @override
  Future<List<ChatRoom>> listRooms() async {
    return [
      ChatRoom(
        id: 'mock-room-ramen',
        postId: 'party-ramen-001',
        title: '멘야 하쿠 라멘 파티',
        participantIds: const ['mock-user', 'mock-host'],
        status: 'active',
        updatedAt: DateTime(2026, 8, 22, 19, 10),
      ),
    ];
  }

  @override
  Future<List<ChatMessage>> listMessages(String roomId) async {
    return [
      ChatMessage(
        id: 'mock-system',
        roomId: roomId,
        senderId: 'system',
        text: '매칭이 성사되어 채팅방이 열렸습니다.',
        createdAt: DateTime(2026, 8, 22, 19),
      ),
      ChatMessage(
        id: 'mock-1',
        roomId: roomId,
        senderId: 'mock-host',
        text: '저는 7시 20분쯤 도착할 것 같아요!',
        createdAt: DateTime(2026, 8, 22, 19, 5),
      ),
      ChatMessage(
        id: 'mock-2',
        roomId: roomId,
        senderId: 'mock-user',
        text: '좋아요. 도착하면 입구에서 만나요.',
        createdAt: DateTime(2026, 8, 22, 19, 6),
      ),
    ];
  }

  @override
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String text,
  }) async {
    return ChatMessage(
      id: 'mock-sent',
      roomId: roomId,
      senderId: 'mock-user',
      text: text,
      createdAt: DateTime.now(),
    );
  }
}

class ApiChatRepository implements ChatRepository {
  const ApiChatRepository(this._api);

  final ChatApi _api;

  @override
  Future<List<ChatRoom>> listRooms() async {
    return (await _api.listRooms()).map(_roomFromDto).toList();
  }

  @override
  Future<List<ChatMessage>> listMessages(String roomId) async {
    return (await _api.listMessages(roomId)).map(_messageFromDto).toList();
  }

  @override
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String text,
  }) async {
    return _messageFromDto(
      await _api.sendMessage(roomId: roomId, text: text),
    );
  }

  ChatRoom _roomFromDto(ChatRoomDto dto) {
    return ChatRoom(
      id: dto.id,
      postId: dto.postId,
      title: dto.title,
      participantIds: dto.participantIds,
      status: dto.status,
      updatedAt: DateTime.tryParse(dto.updatedAt)?.toLocal() ?? DateTime.now(),
    );
  }

  ChatMessage _messageFromDto(ChatMessageDto dto) {
    return ChatMessage(
      id: dto.id,
      roomId: dto.roomId,
      senderId: dto.senderId,
      text: dto.text,
      createdAt: DateTime.tryParse(dto.createdAt)?.toLocal() ?? DateTime.now(),
    );
  }
}
