import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/providers/auth_provider.dart';

final chatSafetyRepositoryProvider = Provider<ChatSafetyRepository>((ref) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return ChatSafetyRepository(ref.watch(appConfigProvider).usesApiData
      ? ref.watch(apiClientProvider)
      : null);
});

final chatBlockedUsersProvider = FutureProvider<Set<String>>((ref) {
  return ref.watch(chatSafetyRepositoryProvider).blockedUsers();
});

class ChatSafetyRepository {
  ChatSafetyRepository(this.client);
  final ApiClient? client;
  final Set<String> _mockBlocked = {};

  Future<Set<String>> blockedUsers() async {
    if (client == null) return {..._mockBlocked};
    final rows = await client!.getList('/api/blocks');
    final now = DateTime.now();
    return {
      for (final row in rows.whereType<Map>())
        if (row['revokedAt'] == null &&
            (row['scope'] == 'chat' || row['scope'] == 'all') &&
            (row['expiresAt'] == null ||
                (DateTime.tryParse('${row['expiresAt']}')?.isAfter(now) ??
                    false)) &&
            row['blockedId'] is String)
          row['blockedId'] as String,
    };
  }

  Future<void> block(String userId, {String? roomId}) async {
    if (client == null) {
      _mockBlocked.add(userId);
      return;
    }
    await client!.postMap('/api/blocks', data: {
      'blockedId': userId,
      'scope': 'all',
      if (roomId != null) 'reason': 'chat_room:$roomId',
    });
  }

  Future<void> unblock(String userId) async {
    if (client == null) {
      _mockBlocked.remove(userId);
      return;
    }
    await client!.deleteMap('/api/blocks/${Uri.encodeComponent(userId)}');
  }

  Future<void> report({
    required String roomId,
    required String userId,
    required String reason,
    String? messageId,
    String description = '',
  }) async {
    if (client == null) return;
    await client!.postMap('/api/reports', data: {
      'reportedUserId': userId,
      'targetType': messageId == null ? 'chat_room' : 'chat_message',
      'targetId': messageId ?? roomId,
      'chatRoomId': roomId,
      if (messageId != null) 'messageId': messageId,
      'reason': reason,
      if (description.trim().isNotEmpty) 'description': description.trim(),
    });
  }
}
