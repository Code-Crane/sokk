import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';

import '../data/chat_repository.dart';
import '../domain/chat_message.dart';
import '../domain/chat_room.dart';

final selectedChatRoomIdProvider = StateProvider<String?>((ref) => null);

final chatRoomsProvider = FutureProvider<List<ChatRoom>>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.id));
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
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ref.watch(chatRepositoryProvider).listMessages(roomId);
});

// Server-confirmed sends survive a stale refresh; never synthesize message IDs.
final confirmedChatMessagesProvider =
    StateProvider.family<List<ChatMessage>, String>((ref, roomId) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return [];
});

List<ChatMessage> mergeChatMessages(
    List<ChatMessage> fetched, List<ChatMessage> confirmed) {
  final byId = {for (final message in confirmed) message.id: message};
  for (final message in fetched) {
    byId[message.id] = message;
  }
  return byId.values.toList()
    ..sort((a, b) {
      final order = a.createdAt.compareTo(b.createdAt);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
}

final visibleChatMessagesProvider =
    Provider.family<AsyncValue<List<ChatMessage>>, String>((ref, roomId) {
  final confirmed = ref.watch(confirmedChatMessagesProvider(roomId));
  return ref.watch(chatMessagesProvider(roomId)).whenData(
        (items) => mergeChatMessages(items, confirmed),
      );
});

final sendMessageControllerProvider =
    StateNotifierProvider<SendMessageController, AsyncValue<ChatMessage?>>(
        (ref) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return SendMessageController(ref.watch(chatRepositoryProvider));
});

class SendMessageController extends StateNotifier<AsyncValue<ChatMessage?>> {
  SendMessageController(this._repository) : super(const AsyncValue.data(null));

  final ChatRepository _repository;

  Future<ChatMessage?> send({
    required String roomId,
    required String text,
  }) async {
    if (state.isLoading || text.trim().isEmpty) {
      return null;
    }

    state = const AsyncValue.loading();
    try {
      final message = await _repository.sendMessage(
        roomId: roomId,
        text: text.trim(),
      );
      if (mounted) state = AsyncValue.data(message);
      return message;
    } catch (error, stackTrace) {
      if (mounted) state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }
}
