import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/brand_assets.dart';
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
    return _ChatTheme(
      child: Builder(
        builder: (context) => ColoredBox(
          color: MukkingBrand.background,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: MukkingBrand.contentWidth),
                child: roomId == null
                    ? const _RoomList()
                    : _Room(
                        key: ValueKey(
                            '$roomId:${ref.watch(currentUserProvider)?.id}'),
                        roomId: roomId!),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTheme extends StatelessWidget {
  const _ChatTheme({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: MukkingBrand.border),
    );
    return Theme(
      data: base.copyWith(
        scaffoldBackgroundColor: MukkingBrand.background,
        colorScheme: base.colorScheme.copyWith(
          primary: MukkingBrand.green,
          onPrimary: Colors.white,
          secondary: MukkingBrand.orange,
          surface: MukkingBrand.surface,
          onSurface: MukkingBrand.text,
          outline: MukkingBrand.border,
          surfaceTint: Colors.transparent,
        ),
        textTheme: base.textTheme.apply(
          bodyColor: MukkingBrand.text,
          displayColor: MukkingBrand.text,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: MukkingBrand.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(
              color: MukkingBrand.green,
              width: 1.5,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: MukkingBrand.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: MukkingBrand.surface,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      child: child,
    );
  }
}

class _RoomList extends ConsumerWidget {
  const _RoomList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(chatRoomsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
          child: Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Image.asset(BrandAssets.logo,
                    height: 70, fit: BoxFit.contain, semanticLabel: '먹킹'),
              ),
              IconButton(
                tooltip: '채팅방 새로고침',
                onPressed: rooms.isLoading
                    ? null
                    : () {
                        ref.invalidate(chatRoomsProvider);
                        for (final room in rooms.valueOrNull ?? <ChatRoom>[]) {
                          ref.invalidate(chatMessagesProvider(room.id));
                        }
                      },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18),
          child: _ChatIntroBanner(),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: rooms.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => ChatFailure(
              error: error,
              retry: () => ref.invalidate(chatRoomsProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const _ChatEmptyState(
                  title: '아직 참여 중인 채팅이 없어요.',
                  message: '모임 참여가 확정되면 여기에서 대화를 시작할 수 있어요.',
                );
              }
              final sorted = [...items]
                ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const Divider(
                    height: 1, indent: 82, color: MukkingBrand.border),
                itemBuilder: (context, index) => _RoomTile(room: sorted[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ChatIntroBanner extends StatelessWidget {
  const _ChatIntroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('채팅',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: MukkingBrand.text)),
              const SizedBox(height: 8),
              Text('약속 전 필요한 이야기를 나눠보세요.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: MukkingBrand.secondary, height: 1.5)),
            ]),
          ),
          const SizedBox(width: 8),
          const MukkingMascot(asset: BrandAssets.speech, size: 130),
        ],
      ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MukkingMascot(asset: BrandAssets.speech, size: 72),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MukkingBrand.secondary,
                  ),
            ),
          ],
        ),
      ),
    );
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
    final party = ref.watch(partyByIdProvider(room.postId)).valueOrNull;
    return Material(
      color: MukkingBrand.surface,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        key: ValueKey('room-${room.id}'),
        borderRadius: BorderRadius.circular(17),
        onTap: () => context.push(AppRoutes.chatPath(room.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: MukkingBrand.mint,
                  borderRadius: BorderRadius.circular(27),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: MukkingBrand.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (party != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (party.restaurantName.isNotEmpty)
                            party.restaurantName,
                          party.scheduledLabel,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: MukkingBrand.green,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      messages.hasError
                          ? '메시지를 불러오지 못했어요.'
                          : last?.text ??
                              (messages.isLoading
                                  ? '메시지 불러오는 중…'
                                  : '첫 메시지를 보내보세요.'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: MukkingBrand.secondary,
                          ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${room.participantIds.length}명 · ${chatTime(last?.createdAt ?? room.updatedAt)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: MukkingBrand.secondary,
                          ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: MukkingBrand.secondary,
                ),
              ),
            ],
          ),
        ),
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

  Future<void> _openSafety(ChatRoom room, String currentUserId) async {
    final unblocked = await showChatSafetyDialog(
      context,
      room: room,
      currentUserId: currentUserId,
    );
    if (mounted && unblocked == true) {
      setState(() {
        _forbidden = false;
        _sendError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(chatRoomByIdProvider(widget.roomId));
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final blocked = ref.watch(chatBlockedUsersProvider);
    final currentRoom = roomState.valueOrNull;
    final canOpenSafety = currentRoom != null &&
        currentUserId != null &&
        currentRoom.participantIds.any((id) => id != currentUserId);
    return Column(children: [
      Container(
        color: MukkingBrand.surface,
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Row(
          children: [
            IconButton(
                tooltip: '채팅방 목록',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(AppRoutes.chat)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentRoom?.title ?? '채팅',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (currentRoom != null)
                    Text(
                      '${currentRoom.participantIds.length}명이 함께하는 대화',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: MukkingBrand.secondary,
                          ),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: '메시지 새로고침',
              onPressed: _refreshing || _sending ? null : _refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
            if (canOpenSafety)
              IconButton(
                tooltip: '신고 / 차단',
                onPressed: () => _openSafety(currentRoom, currentUserId),
                icon: const Icon(Icons.more_horiz_rounded),
              ),
          ],
        ),
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
            if (blocked.hasError)
              const _ChatNotice(
                message: '차단 상태를 확인하지 못했어요. 새로고침해주세요.',
                danger: true,
              ),
            if (messages.hasError)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
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
                            : const _ChatEmptyState(
                                title: '아직 대화가 없어요.',
                                message: '첫 메시지를 보내보세요.',
                              )
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
              _ChatNotice(
                key: const ValueKey('send-error'),
                message: _sendError!,
                danger: true,
              ),
            if (disabled)
              const _ChatNotice(
                message: '차단 또는 이용 제한으로 메시지를 보낼 수 없어요.',
              ),
            Container(
                decoration: const BoxDecoration(
                  color: MukkingBrand.surface,
                  border: Border(
                    top: BorderSide(color: MukkingBrand.border),
                  ),
                ),
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
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요',
                    ),
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
                          : const Icon(Icons.send_rounded)),
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
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: party.when(
        loading: () => const _PartyContextSurface(
          child: Text('모임 정보 불러오는 중…'),
        ),
        error: (_, __) => const _PartyContextSurface(
          child: Text('모임 정보를 불러올 수 없어요.'),
        ),
        data: (value) => value == null
            ? const _PartyContextSurface(
                child: Text('모임 정보를 불러올 수 없어요.'),
              )
            : _PartyContextSurface(
                child: Row(
                  children: [
                    const Icon(
                      Icons.restaurant_rounded,
                      color: MukkingBrand.green,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value.restaurantName.isEmpty
                                ? room.title
                                : value.restaurantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${value.scheduledLabel} · ${room.participantIds.length}명',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: MukkingBrand.secondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '파티 상세로 이동',
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () =>
                          context.push(AppRoutes.partyDetailPath(room.postId)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PartyContextSurface extends StatelessWidget {
  const _PartyContextSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MukkingBrand.mint,
        borderRadius: BorderRadius.circular(15),
      ),
      child: child,
    );
  }
}

class _ChatNotice extends StatelessWidget {
  const _ChatNotice({
    required this.message,
    this.danger = false,
    super.key,
  });

  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? MukkingBrand.orange : MukkingBrand.green;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(18, 6, 18, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: danger ? MukkingBrand.warm : MukkingBrand.mint,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(
            danger ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: MukkingBrand.text,
                  ),
            ),
          ),
        ],
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
          const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 34,
            color: MukkingBrand.green,
          ),
          const SizedBox(height: 12),
          Text(
              error is ApiError
                  ? (error as ApiError).userMessage
                  : '채팅 정보를 불러오지 못했어요.',
              textAlign: TextAlign.center),
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
    final maxWidth = MediaQuery.sizeOf(context).width < 500
        ? MediaQuery.sizeOf(context).width * .76
        : 480.0;
    return Align(
      alignment: message.isSystem
          ? Alignment.center
          : mine
              ? Alignment.centerRight
              : Alignment.centerLeft,
      child: Container(
        key: ValueKey('message-${message.id}'),
        constraints: BoxConstraints(maxWidth: maxWidth),
        margin: EdgeInsets.only(top: compact ? 2 : 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isSystem
              ? MukkingBrand.neutralSurface
              : mine
                  ? MukkingBrand.green
                  : MukkingBrand.mint,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: Radius.circular(mine ? 15 : 5),
            bottomRight: Radius.circular(mine ? 5 : 15),
          ),
          border: !mine && !message.isSystem
              ? Border.all(color: MukkingBrand.border)
              : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!compact && !message.isSystem)
            Text(mine ? '나' : '참여자',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: mine ? Colors.white70 : MukkingBrand.green,
                      fontWeight: FontWeight.w700,
                    )),
          Text(
            message.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: mine ? Colors.white : MukkingBrand.text,
                ),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(
                child: Text(chatTime(message.createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: mine ? Colors.white70 : MukkingBrand.secondary,
                        ))),
            if (onReport != null)
              IconButton(
                  tooltip: '이 메시지 신고',
                  visualDensity: VisualDensity.compact,
                  color: mine ? Colors.white70 : MukkingBrand.secondary,
                  onPressed: onReport,
                  icon: const Icon(Icons.flag_outlined, size: 16)),
          ]),
        ]),
      ),
    );
  }
}
