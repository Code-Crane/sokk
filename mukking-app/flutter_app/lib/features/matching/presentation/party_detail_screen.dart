import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
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
    final tokens = context.tokens;
    final partyAsync = ref.watch(partyByIdProvider(partyId));

    return partyAsync.when(
      data: (party) {
        if (party == null) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              MukkingCard(
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
        final restaurantName = party.restaurantName.trim().isEmpty
            ? party.title
            : party.restaurantName.trim();

        return ListView(
          key: partyDetailPageKey,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          children: [
            Row(
              children: [
                BackButton(
                  color: tokens.textPrimary,
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(returnPath ?? AppRoutes.home);
                    }
                  },
                ),
                Expanded(
                  child: Text(
                    '파티 상세',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz_rounded),
                  tooltip: '신고/차단 메뉴',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  colors: [
                    tokens.secondary.withValues(alpha: 0.94),
                    tokens.primary.withValues(alpha: 0.84),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -26,
                    bottom: -28,
                    child: Icon(
                      Icons.restaurant_rounded,
                      color: tokens.surface.withValues(alpha: 0.16),
                      size: 160,
                    ),
                  ),
                  Positioned(
                    left: 22,
                    bottom: 22,
                    right: 22,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurantName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: tokens.surface,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          party.address.trim().isEmpty
                              ? party.title
                              : party.address,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: tokens.surface.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            MukkingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isHost) ...[
                    Chip(
                      avatar: Icon(
                        Icons.person_rounded,
                        color: tokens.primary,
                        size: 18,
                      ),
                      label: const Text('내가 만든 모임'),
                      backgroundColor: tokens.accent.withValues(alpha: 0.45),
                      side: BorderSide.none,
                    ),
                    const SizedBox(height: 10),
                  ],
                  _StatusPill(status: party.status),
                  const SizedBox(height: 12),
                  Text(
                    party.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  if (party.address.trim().isNotEmpty) ...[
                    Text(
                      party.address,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _DetailRow(
                    icon: Icons.schedule_rounded,
                    label: '날짜/시간',
                    value: party.scheduledLabel,
                  ),
                  if (party.distanceKm > 0)
                    _DetailRow(
                      icon: Icons.place_rounded,
                      label: '거리',
                      value: party.distanceLabel,
                    ),
                  _DetailRow(
                    icon: Icons.people_alt_rounded,
                    label: '모집 인원',
                    value: party.memberLabel,
                  ),
                  _DetailRow(
                    icon: Icons.person_rounded,
                    label: '파티장',
                    value: party.hostName,
                  ),
                  _DetailRow(
                    icon: Icons.verified_user_outlined,
                    label: '참여 상태',
                    value: recoveredRequest?.isLoading == true &&
                            joinState.valueOrNull == null
                        ? '확인 중'
                        : recoveredRequest?.hasError == true &&
                                joinState.valueOrNull == null
                            ? '확인 필요'
                            : _viewerRoleLabel(viewerRole),
                  ),
                  _DetailRow(
                    icon: Icons.event_seat_outlined,
                    label: '남은 자리',
                    value:
                        '${(party.maxMembers - party.currentMembers).clamp(0, party.maxMembers)}자리',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MukkingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('획득 가능한 보상',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _RewardPanel(
                        icon: Icons.bolt_rounded,
                        label: '+${party.rewardXp} XP',
                        color: tokens.rewardXp,
                      ),
                      const SizedBox(width: 10),
                      _RewardPanel(
                        icon: Icons.toll_rounded,
                        label: '+${party.rewardPoints}P',
                        color: tokens.rewardPoint,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MukkingCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('참여자', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final member in party.memberNames)
                        Chip(
                          avatar: Icon(
                            Icons.face_rounded,
                            color: tokens.primary,
                            size: 18,
                          ),
                          label: Text(member),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('태그', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in party.tags)
                        Chip(
                          label: Text('#$tag'),
                          backgroundColor:
                              tokens.accent.withValues(alpha: 0.55),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            MukkingCard(
              backgroundColor: tokens.background,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('파티 소개', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(party.description,
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      '신고/차단 메뉴 placeholder · 실제 기능은 다음 단계에서 연결',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: tokens.danger,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (isHost) _JoinRequestManagementCard(party: party),
            if (isHost) const SizedBox(height: 12),
            _PartyPrimaryAction(
              party: party,
              viewerRole: viewerRole,
              myRequestKey: myRequestKey,
              requestRecoveryLoading: recoveredRequest?.isLoading == true &&
                  joinState.valueOrNull == null,
              requestRecoveryError: recoveredRequest?.hasError == true &&
                  joinState.valueOrNull == null,
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) {
        final message =
            error is ApiError ? error.userMessage : '파티 상세 정보를 불러오지 못했어요.';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            MukkingCard(
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
        onPressed: null,
        icon: const Icon(Icons.hourglass_top_rounded),
        label: const Text('참여 신청 중'),
      );
    }

    if (viewerRole == PartyViewerRole.unavailable) {
      return FilledButton.icon(
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

    return MukkingCard(
      key: partyRequestManagementKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.manage_accounts_rounded, color: tokens.primary),
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
        color: tokens.background,
        borderRadius: BorderRadius.circular(18),
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
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (request.isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: rejectJoinRequestKey(request.id),
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
      MatchingPartyStatus.hot => tokens.partyHot,
      MatchingPartyStatus.urgent => tokens.partyUrgent,
      MatchingPartyStatus.full => tokens.textSecondary,
      MatchingPartyStatus.open => tokens.success,
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

class _RewardPanel extends StatelessWidget {
  const _RewardPanel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

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
        children: [
          Icon(icon, color: tokens.primary, size: 20),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
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
