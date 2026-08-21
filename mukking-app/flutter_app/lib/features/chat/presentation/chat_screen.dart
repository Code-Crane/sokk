import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../domain/chat_message.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final rooms = ref.watch(chatRoomsProvider);
    final selectedRoom = ref.watch(selectedChatRoomProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '채팅',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz_rounded),
                tooltip: '신고/차단 메뉴',
              ),
            ],
          ),
        ),
        Expanded(
          child: rooms.when(
            data: (items) {
              if (items.isEmpty) {
                return _ChatEmptyState(tokens: tokens);
              }

              return selectedRoom.when(
                data: (room) {
                  if (room == null) {
                    return _ChatEmptyState(tokens: tokens);
                  }

                  final messages = ref.watch(chatMessagesProvider(room.id));
                  return messages.when(
                    data: (items) => _ChatMessages(
                      roomTitle: room.title,
                      messages: items,
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => _ChatError(error: error),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ChatError(error: error),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ChatError(error: error),
          ),
        ),
        selectedRoom.when(
          data: (room) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: room != null,
                    decoration: InputDecoration(
                      hintText: room == null ? '채팅방이 없어요' : '메시지 입력',
                      prefixIcon: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: room == null
                      ? null
                      : () async {
                          final message = await ref
                              .read(sendMessageControllerProvider.notifier)
                              .send(
                                roomId: room.id,
                                text: _messageController.text,
                              );

                          if (!context.mounted) {
                            return;
                          }

                          if (message != null) {
                            _messageController.clear();
                            ref.invalidate(chatMessagesProvider(room.id));
                            return;
                          }

                          final error =
                              ref.read(sendMessageControllerProvider).error;
                          final messageText = error is ApiError
                              ? error.userMessage
                              : '메시지를 보내지 못했어요.';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(messageText)),
                          );
                        },
                  child: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ChatMessages extends StatelessWidget {
  const _ChatMessages({
    required this.roomTitle,
    required this.messages,
  });

  final String roomTitle;
  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: tokens.secondary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'HTTP 채팅 · 실시간 연결 전',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: 14),
        MukkingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('약속/파티 카드', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(roomTitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final message in messages)
          _MessageBubble(
            text: message.text,
            isMine: message.senderId == 'mock-user',
            isSystemHint: message.isSystem,
          ),
      ],
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.tokens});

  final MukkingThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        MukkingCard(
          child: Text(
            '열린 채팅방이 아직 없어요. 참가 요청이 승인되면 채팅방이 생성됩니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _ChatError extends StatelessWidget {
  const _ChatError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiError
        ? (error as ApiError).userMessage
        : '채팅 정보를 불러오지 못했어요.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      children: [
        MukkingCard(
          child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isMine,
    this.isSystemHint = false,
  });

  final String text;
  final bool isMine;
  final bool isSystemHint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSystemHint
              ? tokens.warning.withValues(alpha: 0.14)
              : isMine
                  ? tokens.primary
                  : tokens.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isMine ? tokens.surface : tokens.textPrimary,
              ),
        ),
      ),
    );
  }
}
