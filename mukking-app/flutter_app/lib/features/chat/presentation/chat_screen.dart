import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/app_routes.dart';
import '../../auth/providers/auth_provider.dart';
import '../../matching/providers/matching_provider.dart';
import '../data/chat_safety_repository.dart';
import '../domain/chat_message.dart';
import '../domain/chat_room.dart';
import '../providers/chat_provider.dart';
import 'chat_safety_dialog.dart';

String chatTime(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class ChatScreen extends ConsumerWidget {
  const ChatScreen({this.roomId, super.key});
  final String? roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: roomId == null
              ? const _RoomList()
              : _Room(
                  key:
                      ValueKey('$roomId:${ref.watch(currentUserProvider)?.id}'),
                  roomId: roomId!),
        ),
      ),
    );
  }
}

class _RoomList extends ConsumerWidget {
  const _RoomList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(chatRoomsProvider);
    return Column(children: [
      ListTile(
        title: Text('채팅', style: Theme.of(context).textTheme.headlineSmall),
        trailing: IconButton(
          tooltip: '채팅방 새로고침',
          onPressed: rooms.isLoading
              ? null
              : () {
                  ref.invalidate(chatRoomsProvider);
                  for (final room in rooms.valueOrNull ?? <ChatRoom>[]) {
                    ref.invalidate(chatMessagesProvider(room.id));
                  }
                },
          icon: const Icon(Icons.refresh),
        ),
      ),
      Expanded(
          child: rooms.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ChatFailure(
            error: error, retry: () => ref.invalidate(chatRoomsProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('아직 참여 중인 채팅이 없어요.'));
          }
          final sorted = [...items]
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, index) => _RoomTile(room: sorted[index]),
          );
        },
      )),
    ]);
  }
}

class _RoomTile extends ConsumerWidget {
  const _RoomTile({required this.room});
  final ChatRoom room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(visibleChatMessagesProvider(room.id));
    final values = messages.valueOrNull;
    final last = values == null || values.isEmpty ? null : values.last;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        key: ValueKey('room-${room.id}'),
        title: Text(room.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              messages.hasError
                  ? '메시지를 불러오지 못했어요.'
                  : last?.text ??
                      (messages.isLoading ? '메시지 불러오는 중…' : '첫 메시지를 보내보세요.'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          Text(
              '${room.participantIds.length}명 · ${chatTime(last?.createdAt ?? room.updatedAt)}'),
        ]),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(AppRoutes.chatPath(room.id)),
      ),
    );
  }
}

class _Room extends ConsumerStatefulWidget {
  const _Room({required this.roomId, super.key});
  final String roomId;
  @override
  ConsumerState<_Room> createState() => _RoomState();
}

class _RoomState extends ConsumerState<_Room> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _refreshing = false;
  bool _forbidden = false;
  String? _sendError;
  bool _initialScroll = true;
  bool _newMessages = false;
  String? _lastMessageId;
  List<ChatMessage> _lastMessages = [];

  @override
  void dispose() {
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
      if (_newMessages) setState(() => _newMessages = false);
    });
  }

  void _noticeMessages(List<ChatMessage> messages) {
    final latest = messages.isEmpty ? null : messages.last.id;
    if (!_initialScroll && latest == _lastMessageId) return;
    final nearBottom =
        !_scroll.hasClients || _scroll.position.extentAfter < 100;
    if (_initialScroll || nearBottom) {
      _scrollToLatest();
    } else {
      _newMessages = true;
    }
    _initialScroll = false;
    _lastMessageId = latest;
  }

  void _snack(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          error is ApiError ? error.userMessage : '요청을 완료하지 못했어요. 다시 시도해주세요.'),
    ));
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await Future.wait([
        ref.refresh(chatMessagesProvider(widget.roomId).future),
        ref.refresh(chatRoomsProvider.future),
        ref.refresh(chatBlockedUsersProvider.future),
      ]);
      if (mounted) setState(() => _forbidden = false);
    } catch (error) {
      _snack(error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _send() async {
    final text = _draft.text.trim();
    if (_sending || text.isEmpty || _forbidden) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    final originalDraft = _draft.text;
    final message = await ref
        .read(sendMessageControllerProvider.notifier)
        .send(roomId: widget.roomId, text: text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (message == null) {
      final error = ref.read(sendMessageControllerProvider).error;
      if (error is ApiError && error.kind == ApiErrorKind.forbidden) {
        setState(() => _forbidden = true);
      }
      setState(() => _sendError =
          error is ApiError ? error.userMessage : '메시지를 보내지 못했어요. 다시 전송해주세요.');
      return;
    }
    ref.read(confirmedChatMessagesProvider(widget.roomId).notifier).update(
          (items) => mergeChatMessages(items, [message]),
        );
    if (_draft.text == originalDraft) _draft.clear();
    ref.invalidate(chatRoomsProvider);
    _scrollToLatest();
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(chatRoomByIdProvider(widget.roomId));
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final blocked = ref.watch(chatBlockedUsersProvider);
    return Column(children: [
      ListTile(
        leading: IconButton(
            tooltip: '채팅방 목록',
            icon: const Icon(Icons.arrow_back),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.chat)),
        title: Text(roomState.valueOrNull?.title ?? '채팅',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
            tooltip: '메시지 새로고침',
            onPressed: _refreshing || _sending ? null : _refresh,
            icon: const Icon(Icons.refresh)),
      ),
      if (_refreshing) const LinearProgressIndicator(),
      Expanded(
          child: roomState.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ChatFailure(error: error, retry: _refresh),
        data: (room) {
          if (room == null) {
            return ChatFailure(
                error: const ApiError(
                    kind: ApiErrorKind.notFound,
                    userMessage: '채팅방을 찾을 수 없거나 참여 권한이 없어요.'),
                retry: _refresh);
          }
          final isBlocked = room.participantIds
              .any((id) => blocked.valueOrNull?.contains(id) ?? false);
          final disabled = isBlocked || _forbidden;
          final messages = ref.watch(visibleChatMessagesProvider(room.id));
          final values = messages.valueOrNull;
          if (values != null) _lastMessages = values;
          _noticeMessages(_lastMessages);
          return Column(children: [
            _PartyHeader(room: room),
            if (currentUserId != null &&
                room.participantIds.any((id) => id != currentUserId))
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final unblocked = await showChatSafetyDialog(context,
                          room: room, currentUserId: currentUserId);
                      if (mounted && unblocked == true) {
                        setState(() {
                          _forbidden = false;
                          _sendError = null;
                        });
                      }
                    },
                    icon: const Icon(Icons.more_horiz),
                    label: const Text('신고 / 차단'),
                  )),
            if (blocked.hasError) const Text('차단 상태를 확인하지 못했어요. 새로고침해주세요.'),
            if (messages.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Expanded(child: Text('메시지를 불러오지 못했어요.')),
                  TextButton(
                      onPressed: _refreshing ? null : _refresh,
                      child: const Text('다시 시도'))
                ]),
              ),
            Expanded(
                child: messages.isLoading && _lastMessages.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _lastMessages.isEmpty
                        ? messages.hasError
                            ? const SizedBox.shrink()
                            : const Center(child: Text('첫 메시지를 보내보세요.'))
                        : ListView.builder(
                            key: const ValueKey('chat-messages'),
                            controller: _scroll,
                            padding: const EdgeInsets.all(16),
                            itemCount: _lastMessages.length,
                            itemBuilder: (context, index) {
                              final message = _lastMessages[index];
                              final previous =
                                  index == 0 ? null : _lastMessages[index - 1];
                              final compact =
                                  previous?.senderId == message.senderId &&
                                      message.createdAt
                                              .difference(previous!.createdAt)
                                              .inMinutes <
                                          2;
                              return _MessageBubble(
                                  message: message,
                                  mine: message.senderId == currentUserId,
                                  compact: compact,
                                  onReport: message.isSystem ||
                                          message.senderId == currentUserId ||
                                          currentUserId == null
                                      ? null
                                      : () => showChatSafetyDialog(context,
                                          room: room,
                                          currentUserId: currentUserId,
                                          message: message));
                            },
                          )),
            if (_newMessages)
              TextButton(
                  onPressed: _scrollToLatest, child: const Text('새 메시지 보기')),
            if (_sendError != null)
              Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_sendError!, key: const ValueKey('send-error'))),
            if (disabled)
              const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('차단 또는 이용 제한으로 메시지를 보낼 수 없어요.')),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child:
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                      child: TextField(
                    key: const ValueKey('chat-draft'),
                    controller: _draft,
                    enabled: !disabled && !_sending,
                    minLines: 1,
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(hintText: '메시지 입력'),
                  )),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      tooltip: '메시지 전송',
                      onPressed:
                          disabled || _sending || _draft.text.trim().isEmpty
                              ? null
                              : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send)),
                ])),
          ]);
        },
      )),
    ]);
  }
}

class _PartyHeader extends ConsumerWidget {
  const _PartyHeader({required this.room});
  final ChatRoom room;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final party = ref.watch(partyByIdProvider(room.postId));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: party.when(
        loading: () => const Text('모임 정보 불러오는 중…'),
        error: (_, __) => const Text('모임 정보를 불러올 수 없어요.'),
        data: (value) => value == null
            ? const Text('모임 정보를 불러올 수 없어요.')
            : ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    value.restaurantName.isEmpty
                        ? room.title
                        : value.restaurantName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    '${value.scheduledLabel} · ${room.participantIds.length}명'),
                trailing: IconButton(
                    tooltip: '파티 상세로 이동',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () =>
                        context.push(AppRoutes.partyDetailPath(room.postId))),
              ),
      ),
    );
  }
}

class ChatFailure extends StatelessWidget {
  const ChatFailure({required this.error, required this.retry, super.key});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(error is ApiError
              ? (error as ApiError).userMessage
              : '채팅 정보를 불러오지 못했어요.'),
          TextButton(onPressed: retry, child: const Text('다시 시도')),
        ]),
      ));
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble(
      {required this.message,
      required this.mine,
      required this.compact,
      this.onReport});
  final ChatMessage message;
  final bool mine;
  final bool compact;
  final VoidCallback? onReport;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isSystem
          ? Alignment.center
          : mine
              ? Alignment.centerRight
              : Alignment.centerLeft,
      child: Container(
        key: ValueKey('message-${message.id}'),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width < 500 ? 290 : 480),
        margin: EdgeInsets.only(top: compact ? 2 : 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: message.isSystem
                ? colors.surfaceContainerHighest
                : mine
                    ? colors.primaryContainer
                    : colors.surface,
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!compact && !message.isSystem)
            Text(mine ? '나' : '참여자',
                style: Theme.of(context).textTheme.labelSmall),
          Text(message.text),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
                child: Text(chatTime(message.createdAt),
                    style: Theme.of(context).textTheme.labelSmall)),
            if (onReport != null)
              IconButton(
                  tooltip: '이 메시지 신고',
                  visualDensity: VisualDensity.compact,
                  onPressed: onReport,
                  icon: const Icon(Icons.flag_outlined, size: 16)),
          ]),
        ]),
      ),
    );
  }
}
