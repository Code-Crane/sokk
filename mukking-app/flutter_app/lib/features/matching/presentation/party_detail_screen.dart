import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/brand_assets.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../discovery/presentation/discovery_visuals.dart';
import '../../discovery/domain/discovery_party_filter.dart';
import '../../discovery/domain/restaurant.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/providers/chat_provider.dart';
import '../data/matching_repository.dart';
import '../domain/matching_party.dart';
import '../providers/matching_provider.dart';

const partyDetailPageKey = Key('party-detail-page');
const partyDetailRetryKey = Key('party-detail-retry');
const partyJoinButtonKey = Key('party-join-button');
const partyPendingButtonKey = Key('party-pending-button');
const partyChatButtonKey = Key('party-chat-button');
const partyRequestManagementKey = Key('party-request-management');
const partyRequestEmptyKey = Key('party-request-empty');
const partyManageRequestsButtonKey = Key('party-manage-requests-button');
const partyRestaurantButtonKey = Key('party-restaurant-button');

Key approveJoinRequestKey(String requestId) =>
    ValueKey('approve-join-request-$requestId');

Key rejectJoinRequestKey(String requestId) =>
    ValueKey('reject-join-request-$requestId');

class PartyDetailScreen extends ConsumerWidget {
  const PartyDetailScreen({
    required this.partyId,
    this.returnPath,
    super.key,
  });

  final String partyId;
  final String? returnPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DiscoveryTheme(child: Builder(builder: (context) {
      final theme = Theme.of(context);
      return Theme(
          data: theme.copyWith(
              filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                minimumSize: const Size(44, 52),
                textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
          )),
          child: ColoredBox(
              color: MukkingBrand.background,
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Builder(builder: (context) => _content(context, ref)),
              ))));
    }));
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(returnPath ?? AppRoutes.home);
    }
  }

  Widget _content(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final partyAsync = ref.watch(partyByIdProvider(partyId));

    return partyAsync.when(
      data: (party) {
        if (party == null) {
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Align(
                  alignment: Alignment.centerLeft,
                  child: BackButton(onPressed: () => _back(context))),
              DiscoverySurface(
                child: Column(
                  children: [
                    Text(
                      '파티를 찾을 수 없어요.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: partyDetailRetryKey,
                      onPressed: () =>
                          ref.invalidate(partyByIdProvider(partyId)),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        final joinState = ref.watch(joinPartyControllerProvider(party.id));
        final currentUser = ref.watch(currentUserProvider);
        final myRequestKey =
            currentUser == null || currentUser.id == party.hostUserId
                ? null
                : (partyId: party.id, userId: currentUser.id);
        final recoveredRequest = myRequestKey == null
            ? null
            : ref.watch(myJoinRequestProvider(myRequestKey));
        final requestStatus = joinState.valueOrNull?.status ??
            recoveredRequest?.valueOrNull?.status;
        final viewerRole = resolvePartyViewerRole(
          party: party,
          currentUserId: currentUser?.id,
          localRequestStatus: requestStatus,
        );
        final isHost = viewerRole == PartyViewerRole.author;
        final restaurant = hasLinkedRestaurant(party)
            ? ref.watch(restaurantByIdProvider(party.restaurantId))
            : null;

        return ListView(
          key: partyDetailPageKey,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            Row(children: [
              BackButton(
                  color: tokens.textPrimary, onPressed: () => _back(context)),
              const SizedBox(width: 4),
              Expanded(
                  child: Text('모임 상세',
                      style: Theme.of(context).textTheme.titleMedium)),
            ]),
            const SizedBox(height: 12),
            _RestaurantContext(party: party, restaurant: restaurant),
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _StatusPill(status: party.status),
              if (isHost)
                const Chip(
                    label: Text('내가 만든 모임'),
                    backgroundColor: MukkingBrand.warm,
                    side: BorderSide.none),
            ]),
            const SizedBox(height: 12),
            Text(party.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            DiscoverySurface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  _DetailRow(
                      icon: Icons.schedule_rounded,
                      label: '날짜/시간',
                      value: party.scheduledLabel),
                  _DetailRow(
                      icon: Icons.people_alt_outlined,
                      label: '모집 인원',
                      value: party.memberLabel),
                  _DetailRow(
                      icon: Icons.event_seat_outlined,
                      label: '남은 자리',
                      value:
                          '${(party.maxMembers - party.currentMembers).clamp(0, party.maxMembers)}자리'),
                  if (party.distanceKm > 0)
                    _DetailRow(
                        icon: Icons.near_me_outlined,
                        label: '거리',
                        value: party.distanceLabel),
                ])),
            if ((party.description.trim().isNotEmpty &&
                    party.description.trim() != party.title.trim()) ||
                (party.hostName.trim().isNotEmpty &&
                    party.hostName.trim() != '파티장')) ...[
              const SizedBox(height: 16),
              DiscoverySurface(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    if (party.description.trim().isNotEmpty &&
                        party.description.trim() != party.title.trim()) ...[
                      Text('모임 소개',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(party.description,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    // The API mapper's generic '파티장' is not a real nickname.
                    if (party.hostName.trim().isNotEmpty &&
                        party.hostName.trim() != '파티장') ...[
                      const SizedBox(height: 14),
                      _DetailRow(
                          icon: Icons.person_outline_rounded,
                          label: '방장',
                          value: party.hostName),
                    ],
                  ])),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _viewerStatusSurface(viewerRole),
                border: Border.all(color: MukkingBrand.border),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _DetailRow(
                        icon: Icons.person_outline_rounded,
                        label: '내 상태',
                        value: recoveredRequest?.isLoading == true &&
                                joinState.valueOrNull == null
                            ? '확인 중'
                            : recoveredRequest?.hasError == true &&
                                    joinState.valueOrNull == null
                                ? '확인 필요'
                                : _viewerRoleLabel(viewerRole)),
                    _PartyPrimaryAction(
                      party: party,
                      viewerRole: viewerRole,
                      myRequestKey: myRequestKey,
                      requestRecoveryLoading:
                          recoveredRequest?.isLoading == true &&
                              joinState.valueOrNull == null,
                      requestRecoveryError:
                          recoveredRequest?.hasError == true &&
                              joinState.valueOrNull == null,
                    ),
                  ]),
            ),
            if (party.memberNames.isNotEmpty ||
                party.rewardXp > 0 ||
                party.rewardPoints > 0) ...[
              const SizedBox(height: 16),
              DiscoverySurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (party.memberNames.isNotEmpty)
                      _DetailRow(
                          icon: Icons.group_outlined,
                          label: '참여자',
                          value: party.memberNames.join(' · ')),
                    if (party.rewardXp > 0 || party.rewardPoints > 0)
                      _DetailRow(
                        icon: Icons.stars_outlined,
                        label: '참여 보상',
                        value: [
                          if (party.rewardXp > 0) '+${party.rewardXp} XP',
                          if (party.rewardPoints > 0) '+${party.rewardPoints}P',
                        ].join(' · '),
                      ),
                  ],
                ),
              ),
            ],
            if (isHost) ...[
              const SizedBox(height: 18),
              _JoinRequestManagementCard(party: party),
            ],
          ],
        );
      },
      loading: () => ListView(padding: const EdgeInsets.all(18), children: [
        Align(
            alignment: Alignment.centerLeft,
            child: BackButton(onPressed: () => _back(context))),
        const DiscoverySurface(
            child: Row(children: [
          SizedBox.square(
              dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Expanded(child: Text('모임 정보를 불러오고 있어요.')),
        ])),
      ]),
      error: (error, _) {
        final message =
            error is ApiError ? error.userMessage : '파티 상세 정보를 불러오지 못했어요.';

        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Align(
                alignment: Alignment.centerLeft,
                child: BackButton(onPressed: () => _back(context))),
            DiscoverySurface(
              child: Column(
                children: [
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: partyDetailRetryKey,
                    onPressed: () => ref.invalidate(partyByIdProvider(partyId)),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RestaurantContext extends StatelessWidget {
  const _RestaurantContext({required this.party, required this.restaurant});

  final MatchingParty party;
  final Restaurant? restaurant;

  @override
  Widget build(BuildContext context) {
    final restaurantName = party.restaurantName.trim().isNotEmpty
        ? party.restaurantName.trim()
        : restaurant?.name;
    final address = party.address.trim().isNotEmpty
        ? party.address.trim()
        : restaurant?.displayAddress ?? '';

    return DiscoverySurface(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (restaurant != null)
          DiscoveryRestaurantImage(restaurant: restaurant!, size: 60)
        else
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: MukkingBrand.mint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                color: MukkingBrand.green),
          ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                restaurantName?.isNotEmpty == true
                    ? restaurantName!
                    : '연결된 식당 정보가 없어요.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: MukkingBrand.text, fontWeight: FontWeight.w800)),
            if (restaurant?.category.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(restaurant!.category,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (hasLinkedRestaurant(party))
              TextButton.icon(
                key: partyRestaurantButtonKey,
                onPressed: () => context
                    .push(AppRoutes.restaurantDetailPath(party.restaurantId)),
                icon: const Icon(Icons.place_outlined, size: 18),
                label: const Text('식당 보기'),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _PartyPrimaryAction extends ConsumerWidget {
  const _PartyPrimaryAction({
    required this.party,
    required this.viewerRole,
    required this.myRequestKey,
    required this.requestRecoveryLoading,
    required this.requestRecoveryError,
  });

  final MatchingParty party;
  final PartyViewerRole viewerRole;
  final MyJoinRequestKey? myRequestKey;
  final bool requestRecoveryLoading;
  final bool requestRecoveryError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (viewerRole == PartyViewerRole.author) {
      final room = ref.watch(chatRoomForPartyProvider(party.id));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            key: partyManageRequestsButtonKey,
            style: room.valueOrNull == null
                ? OutlinedButton.styleFrom(
                    backgroundColor: MukkingBrand.orange,
                    foregroundColor: MukkingBrand.surface,
                    minimumSize: const Size(44, 52),
                  )
                : null,
            onPressed: () =>
                ref.invalidate(partyJoinRequestsProvider(party.id)),
            icon: const Icon(Icons.manage_accounts_rounded),
            label: const Text('참여 신청 관리'),
          ),
          room.maybeWhen(
            data: (chatRoom) => chatRoom == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: FilledButton.icon(
                      key: partyChatButtonKey,
                      onPressed: () =>
                          context.go(AppRoutes.chatPath(chatRoom.id)),
                      icon: const Icon(Icons.chat_bubble_rounded),
                      label: const Text('채팅방 들어가기'),
                    ),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      );
    }

    if (viewerRole == PartyViewerRole.approved) {
      final room = ref.watch(chatRoomForPartyProvider(party.id));
      return room.when(
        data: (chatRoom) {
          if (chatRoom == null) {
            return OutlinedButton.icon(
              onPressed: () => ref.invalidate(chatRoomsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('채팅방 다시 확인'),
            );
          }
          return FilledButton.icon(
            key: partyChatButtonKey,
            onPressed: () => context.go(AppRoutes.chatPath(chatRoom.id)),
            icon: const Icon(Icons.chat_bubble_rounded),
            label: const Text('채팅방 들어가기'),
          );
        },
        loading: () => OutlinedButton.icon(
          onPressed: null,
          icon: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          label: const Text('채팅방 확인 중'),
        ),
        error: (_, __) => OutlinedButton.icon(
          onPressed: () => ref.invalidate(chatRoomsProvider),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('채팅방 다시 확인'),
        ),
      );
    }

    if (viewerRole == PartyViewerRole.pending) {
      return FilledButton.icon(
        key: partyPendingButtonKey,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: MukkingBrand.warm,
          disabledForegroundColor: MukkingBrand.text,
        ),
        onPressed: null,
        icon: const Icon(Icons.hourglass_top_rounded),
        label: const Text('참여 신청 중'),
      );
    }

    if (viewerRole == PartyViewerRole.unavailable) {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          disabledBackgroundColor: MukkingBrand.border,
          disabledForegroundColor: MukkingBrand.secondary,
        ),
        onPressed: null,
        icon: const Icon(Icons.event_busy_rounded),
        label: const Text('모집이 마감됐어요'),
      );
    }

    if (requestRecoveryLoading) {
      return FilledButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('참여 상태 확인 중'),
      );
    }

    if (requestRecoveryError) {
      return OutlinedButton.icon(
        onPressed: myRequestKey == null
            ? null
            : () => ref.invalidate(myJoinRequestProvider(myRequestKey!)),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('참여 상태 다시 확인'),
      );
    }

    final joinState = ref.watch(joinPartyControllerProvider(party.id));
    return FilledButton.icon(
      key: partyJoinButtonKey,
      onPressed: joinState.isLoading ? null : () => _join(context, ref),
      icon: joinState.isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.how_to_reg_rounded),
      label: Text(joinState.isLoading ? '신청 중' : '같이 가요'),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(joinPartyControllerProvider(party.id).notifier)
        .join(party.id);
    if (!context.mounted) return;

    final error = ref.read(joinPartyControllerProvider(party.id)).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == null ? matchingActionErrorMessage(error) : '참여 신청을 보냈어요',
        ),
      ),
    );
  }
}

class _JoinRequestManagementCard extends ConsumerWidget {
  const _JoinRequestManagementCard({required this.party});

  final MatchingParty party;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(partyJoinRequestsProvider(party.id));
    final tokens = context.tokens;

    return DiscoverySurface(
      key: partyRequestManagementKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.manage_accounts_rounded,
                  color: MukkingBrand.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '참여 신청 관리',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          requests.when(
            data: (items) {
              final pendingCount = items
                  .where((request) =>
                      request.status == MatchingJoinRequestStatus.pending)
                  .length;
              final approvedCount = party.participantIds.length;
              final summary = '참여 신청 $pendingCount명 · 승인된 참가자 $approvedCount명';

              if (items.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '아직 참여 신청이 없어요.',
                      key: partyRequestEmptyKey,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final request in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _JoinRequestTile(
                        partyId: party.id,
                        request: request,
                      ),
                    ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(
              error is ApiError ? error.userMessage : '참가 요청을 불러오지 못했어요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.danger,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinRequestTile extends ConsumerWidget {
  const _JoinRequestTile({required this.partyId, required this.request});

  final String partyId;
  final PartyJoinRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final key = (partyId: partyId, requestId: request.id);
    final action = ref.watch(respondJoinRequestControllerProvider(key));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MukkingBrand.surface,
        border: Border.all(color: MukkingBrand.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.requesterLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            request.status.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: switch (request.status) {
                    MatchingJoinRequestStatus.pending => MukkingBrand.orange,
                    MatchingJoinRequestStatus.accepted => MukkingBrand.green,
                    MatchingJoinRequestStatus.rejected => tokens.danger,
                    MatchingJoinRequestStatus.cancelled =>
                      MukkingBrand.secondary,
                  },
                ),
          ),
          if (request.isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: rejectJoinRequestKey(request.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.danger,
                    ),
                    onPressed: action.isLoading
                        ? null
                        : () => _respond(context, ref, key, 'rejected'),
                    child: const Text('거절'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    key: approveJoinRequestKey(request.id),
                    onPressed: action.isLoading
                        ? null
                        : () => _respond(context, ref, key, 'accepted'),
                    child: action.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('승인'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _respond(
    BuildContext context,
    WidgetRef ref,
    RespondJoinRequestKey key,
    String decision,
  ) async {
    final result = await ref
        .read(respondJoinRequestControllerProvider(key).notifier)
        .respond(requestId: request.id, decision: decision);
    if (!context.mounted) return;

    final error = ref.read(respondJoinRequestControllerProvider(key)).error;
    final message = result == null
        ? matchingActionErrorMessage(error)
        : decision == 'accepted'
            ? '참가 요청을 승인했어요.'
            : '참가 요청을 거절했어요.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final MatchingPartyStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = switch (status) {
      MatchingPartyStatus.hot => MukkingBrand.green,
      MatchingPartyStatus.urgent => MukkingBrand.orange,
      MatchingPartyStatus.full => tokens.textSecondary,
      MatchingPartyStatus.open => MukkingBrand.green,
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status.label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      ),
    );
  }
}

Color _viewerStatusSurface(PartyViewerRole role) => switch (role) {
      PartyViewerRole.pending => MukkingBrand.warm,
      PartyViewerRole.approved => MukkingBrand.mint,
      PartyViewerRole.author => MukkingBrand.mint,
      PartyViewerRole.unavailable => MukkingBrand.background,
      PartyViewerRole.rejected => MukkingBrand.background,
      PartyViewerRole.cancelled => MukkingBrand.background,
      PartyViewerRole.available => MukkingBrand.surface,
    };

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tokens.primary, size: 20),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _viewerRoleLabel(PartyViewerRole role) {
  return switch (role) {
    PartyViewerRole.author => '작성자',
    PartyViewerRole.pending => '참여 신청 중',
    PartyViewerRole.approved => '참여 승인됨',
    PartyViewerRole.rejected => '참여 신청 거절됨',
    PartyViewerRole.cancelled => '참여 신청 취소됨',
    PartyViewerRole.unavailable => '모집 마감',
    PartyViewerRole.available => '신청 가능',
  };
}

String matchingActionErrorMessage(Object? error) {
  if (error is! ApiError) return '요청을 처리하지 못했어요.';

  final serverMessage = error.serverMessage?.toLowerCase() ?? '';
  if (serverMessage.contains('pending join request')) {
    return '이미 참여 신청한 모임이에요.';
  }
  if (serverMessage.contains('already accepted')) {
    return '이미 참여 중인 모임이에요.';
  }
  if (serverMessage.contains('own post')) {
    return '내가 만든 모임에는 참여 신청할 수 없어요.';
  }
  if (serverMessage.contains('not open')) {
    return '모집이 마감된 모임이에요.';
  }
  if (serverMessage.contains('verification is required')) {
    return '본인인증 후 이용할 수 있어요.';
  }
  if (serverMessage.contains('pending meeting evaluations')) {
    return '먼저 미완료 평가를 제출해주세요.';
  }
  if (serverMessage.contains('restricted from matching')) {
    return '현재 모임 참여가 제한된 상태예요.';
  }
  if (serverMessage.contains('blocked by a user block')) {
    return '차단 관계로 인해 참여할 수 없어요.';
  }
  return error.userMessage;
}
