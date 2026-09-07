import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/app_routes.dart';
import '../../auth/providers/auth_provider.dart';
import '../../matching/providers/matching_provider.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../domain/app_notification.dart';
import '../providers/notification_provider.dart';
import 'notification_card.dart';
import '../../chat/providers/chat_provider.dart';

Future<void> openNotification(
    BuildContext context, WidgetRef ref, AppNotification notification) async {
  final identity = ref.read(currentUserProvider)?.id;
  bool valid() =>
      context.mounted && ref.read(currentUserProvider)?.id == identity;
  if (ref.read(markNotificationReadProvider).isLoading) return;
  if (!notification.isRead) {
    final read = await ref
        .read(markNotificationReadProvider.notifier)
        .markRead(notification.id);
    if (!context.mounted || !valid()) return;
    if (read == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('읽음 처리에 실패했어요. 알림 목록에서 다시 시도해주세요.'),
      ));
    }
  }
  if (!context.mounted || !valid()) return;
  try {
    if (notification.type == 'chat_message_created') {
      final roomId = notification.chatRoomId;
      if (roomId != null && roomId.isNotEmpty) {
        final rooms = await ref.refresh(chatRoomsProvider.future);
        if (!context.mounted || !valid()) return;
        if (rooms.any((room) => room.id == roomId)) {
          await context.push(AppRoutes.chatPath(roomId));
          return;
        }
      }
    } else if (const {
      'favorite_restaurant_party_created',
      'join_request_received',
      'join_request_accepted',
      'join_request_rejected'
    }.contains(notification.type)) {
      final postId = notification.matchingPostId;
      if (postId != null && postId.isNotEmpty) {
        final party = await ref.refresh(partyByIdProvider(postId).future);
        if (!context.mounted || !valid()) return;
        if (party != null) {
          await context.push(AppRoutes.partyDetailPath(postId));
          return;
        }
      } else if (notification.type == 'favorite_restaurant_party_created') {
        final id = notification.restaurantId;
        if (id != null && id.isNotEmpty) {
          final restaurant =
              await ref.refresh(restaurantDetailSourceProvider(id).future);
          if (!context.mounted || !valid()) return;
          if (restaurant != null) {
            await context.push(AppRoutes.restaurantDetailPath(id));
            return;
          }
        }
      }
    }
    if (context.mounted && valid()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('대상을 찾을 수 없어요.')));
    }
  } catch (error) {
    if (!context.mounted || !valid()) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
      error is ApiError && error.kind != ApiErrorKind.notFound
          ? error.userMessage
          : '대상을 찾을 수 없어요.',
    )));
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = ref.watch(currentUserProvider)?.id;
    return _NotificationList(
      key: ValueKey(id),
    );
  }
}

class _NotificationList extends ConsumerStatefulWidget {
  const _NotificationList({super.key});
  @override
  ConsumerState<_NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends ConsumerState<_NotificationList> {
  bool _opening = false;
  Future<void> _refresh() async {
    try {
      await Future.wait([
        ref.refresh(notificationsProvider.future),
        ref.refresh(unreadNotificationCountProvider.future),
      ]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('알림을 새로고침하지 못했어요. 다시 시도해주세요.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final marking = ref.watch(markNotificationReadProvider).isLoading;
    return Center(
        child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: Column(children: [
        ListTile(
          leading: IconButton(
              tooltip: '뒤로가기',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.home)),
          title: const Text('알림'),
          trailing: IconButton(
              tooltip: '알림 새로고침',
              icon: const Icon(Icons.refresh),
              onPressed: notifications.isLoading ? null : _refresh),
        ),
        if (_opening || marking) const LinearProgressIndicator(),
        Expanded(
            child: notifications.when(
          skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('알림을 불러오지 못했어요.'),
            TextButton(onPressed: _refresh, child: const Text('다시 시도')),
          ])),
          data: (items) => RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (items.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('아직 새로운 알림이 없어요.')),
                  for (final item in items)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(children: [
                          NotificationCard(
                              notification: item,
                              onTap: () async {
                                if (_opening || marking) return;
                                setState(() => _opening = true);
                                try {
                                  await openNotification(context, ref, item);
                                } finally {
                                  if (mounted) setState(() => _opening = false);
                                }
                              }),
                          if (!item.isRead)
                            Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                    onPressed: marking || _opening
                                        ? null
                                        : () async {
                                            final result = await ref
                                                .read(
                                                    markNotificationReadProvider
                                                        .notifier)
                                                .markRead(item.id);
                                            if (context.mounted &&
                                                result == null) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          '읽음 처리에 실패했어요. 다시 시도해주세요.')));
                                            }
                                          },
                                    child: const Text('읽음 처리'))),
                        ])),
                  if (items.length == 50) const Text('최근 알림 50개를 표시하고 있어요.'),
                ],
              )),
        )),
      ]),
    ));
  }
}
