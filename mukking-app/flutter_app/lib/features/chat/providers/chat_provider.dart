import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../domain/chat_message.dart';
import '../domain/chat_room.dart';

final selectedChatRoomIdProvider = StateProvider<String?>((ref) => null);

final chatRoomsProvider = FutureProvider<List<ChatRoom>>((ref) {
  return ref.watch(chatRepositoryProvider).listRooms();
});

final selectedChatRoomProvider = FutureProvider<ChatRoom?>((ref) async {
  final rooms = await ref.watch(chatRoomsProvider.future);
  if (rooms.isEmpty) {
    return null;
  }

  final selectedId = ref.watch(selectedChatRoomIdProvider);
  return rooms.firstWhere(
    (room) => room.id == selectedId,
    orElse: () => rooms.first,
  );
});

final chatRoomByIdProvider =
    FutureProvider.family<ChatRoom?, String>((ref, roomId) async {
  final rooms = await ref.watch(chatRoomsProvider.future);
  for (final room in rooms) {
    if (room.id == roomId) return room;
  }
  return null;
});

final chatMessagesProvider =
    FutureProvider.family<List<ChatMessage>, String>((ref, roomId) {
  return ref.watch(chatRepositoryProvider).listMessages(roomId);
});

final sendMessageControllerProvider =
    StateNotifierProvider<SendMessageController, AsyncValue<ChatMessage?>>(
        (ref) {
  return SendMessageController(ref.watch(chatRepositoryProvider));
});

class SendMessageController extends StateNotifier<AsyncValue<ChatMessage?>> {
  SendMessageController(this._repository) : super(const AsyncValue.data(null));

  final ChatRepository _repository;

  Future<ChatMessage?> send({
    required String roomId,
    required String text,
  }) async {
    if (text.trim().isEmpty) {
      return null;
    }

    state = const AsyncValue.loading();
    try {
      final message = await _repository.sendMessage(
        roomId: roomId,
        text: text.trim(),
      );
      state = AsyncValue.data(message);
      return message;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }
}
