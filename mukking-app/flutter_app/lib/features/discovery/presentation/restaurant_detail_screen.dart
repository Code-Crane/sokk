import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/platform/external_url_launcher.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../../matching/domain/matching_party.dart';
import '../../matching/providers/matching_provider.dart';
import '../domain/restaurant.dart';
import '../providers/discovery_provider.dart';

const restaurantDetailPageKey = Key('restaurant-detail-page');
const restaurantDetailFavoriteButtonKey =
    Key('restaurant-detail-favorite-button');
const restaurantDetailPhoneButtonKey = Key('restaurant-detail-phone-button');
const restaurantDetailPlaceButtonKey = Key('restaurant-detail-place-button');
const restaurantDetailCreatePartyButtonKey =
    Key('restaurant-detail-create-party-button');
const restaurantDetailRetryButtonKey = Key('restaurant-detail-retry-button');

Key restaurantDetailPartyCardKey(String partyId) =>
    ValueKey('restaurant-detail-party-$partyId');

class RestaurantDetailScreen extends ConsumerWidget {
  const RestaurantDetailScreen({
    required this.restaurantId,
    super.key,
  });

  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(restaurantDetailProvider(restaurantId));

    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _DetailError(
        error: error,
        onRetry: () {
          ref.invalidate(restaurantDetailSourceProvider(restaurantId));
          ref.invalidate(partiesByRestaurantProvider(restaurantId));
        },
      ),
      data: (restaurant) {
        if (restaurant == null) {
          return const _DetailEmpty();
        }
        return _RestaurantDetailContent(restaurant: restaurant);
      },
    );
  }
}

class _RestaurantDetailContent extends ConsumerWidget {
  const _RestaurantDetailContent({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final parties = ref.watch(partiesByRestaurantProvider(restaurant.id));
    final phone = restaurant.phone?.trim();
    final phoneUri =
        phone == null || phone.isEmpty ? null : Uri(scheme: 'tel', path: phone);
    final placeUri = restaurant.placeUri;

    return ListView(
      key: restaurantDetailPageKey,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _goBack(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: '뒤로가기',
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      key: restaurantDetailFavoriteButtonKey,
                      onPressed: () => _toggleFavorite(context, ref),
                      icon: Icon(
                        restaurant.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: restaurant.isFavorite
                            ? tokens.favorite
                            : tokens.textSecondary,
                      ),
                      tooltip: restaurant.isFavorite ? '찜 취소' : '가고 싶어요',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _CategoryHeader(restaurant: restaurant),
                const SizedBox(height: 16),
                MukkingCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '식당 기본정보',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.restaurant_menu_rounded,
                        label: '카테고리',
                        value: restaurant.category,
                      ),
                      if (restaurant.distanceMeters != null)
                        _InfoRow(
                          icon: Icons.near_me_rounded,
                          label: '거리',
                          value: restaurant.distanceLabel,
                        ),
                      if (restaurant.displayAddress.isNotEmpty)
                        _InfoRow(
                          icon: Icons.place_outlined,
                          label: '주소',
                          value: restaurant.displayAddress,
                        ),
                      if (phoneUri != null)
                        _InfoRow(
                          icon: Icons.phone_outlined,
                          label: '전화',
                          value: phone!,
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          if (phoneUri != null)
                            OutlinedButton.icon(
                              key: restaurantDetailPhoneButtonKey,
                              onPressed: () => _launchExternal(
                                context,
                                ref,
                                phoneUri,
                                failureMessage: '전화 앱을 열지 못했어요.',
                              ),
                              icon: const Icon(Icons.phone_rounded),
                              label: const Text('전화 걸기'),
                            ),
                          if (placeUri != null)
                            OutlinedButton.icon(
                              key: restaurantDetailPlaceButtonKey,
                              onPressed: () => _launchExternal(
                                context,
                                ref,
                                placeUri,
                                failureMessage: '카카오맵을 열지 못했어요.',
                              ),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('카카오맵에서 보기'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _PartySection(parties: parties),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: restaurantDetailCreatePartyButtonKey,
                  onPressed: () => context.go(
                    AppRoutes.createPartyPath(restaurantId: restaurant.id),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('이 식당에서 파티 만들기'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(favoriteOverridesProvider.notifier).toggle(restaurant);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('찜 상태를 변경하지 못했어요.')),
      );
    }
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      height: 190,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [
            tokens.secondary.withValues(alpha: 0.72),
            tokens.primary.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            bottom: -22,
            child: Icon(
              Icons.restaurant_rounded,
              size: 150,
              color: tokens.surface.withValues(alpha: 0.16),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '카테고리 안내',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: tokens.surface.withValues(alpha: 0.82),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  restaurant.category,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: tokens.surface,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartySection extends ConsumerWidget {
  const _PartySection({required this.parties});

  final AsyncValue<List<MatchingParty>> parties;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MukkingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이 식당에서 같이 먹어요',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 14),
          parties.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text(
              error is ApiError ? error.userMessage : '파티 정보를 불러오지 못했어요.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            data: (items) {
              final active = items
                  .where((party) => party.status != MatchingPartyStatus.full)
                  .toList();
              if (active.isEmpty) {
                return Text(
                  '아직 모집 중인 파티가 없어요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '현재 모집 중 ${active.length}개',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  for (final party in active) ...[
                    _RestaurantPartyCard(
                      party: party,
                      onTap: () {
                        context.go(AppRoutes.partyDetailPath(party.id));
                        ref.read(selectedPartyIdProvider.notifier).state =
                            party.id;
                      },
                    ),
                    if (party != active.last) const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RestaurantPartyCard extends StatelessWidget {
  const _RestaurantPartyCard({required this.party, required this.onTap});

  final MatchingParty party;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      key: restaurantDetailPartyCardKey(party.id),
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tokens.primary.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    party.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  party.status.label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: tokens.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _CompactMeta(
                  icon: Icons.schedule_rounded,
                  label: party.scheduledLabel,
                ),
                _CompactMeta(
                  icon: Icons.people_alt_rounded,
                  label: party.memberLabel,
                ),
                if (party.hostName.isNotEmpty)
                  _CompactMeta(
                    icon: Icons.person_outline_rounded,
                    label: party.hostName,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMeta extends StatelessWidget {
  const _CompactMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: tokens.textSecondary),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
          Icon(icon, size: 20, color: tokens.primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 68,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiError
        ? (error as ApiError).userMessage
        : '식당 정보를 불러오지 못했어요.';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        MukkingCard(
          child: Column(
            children: [
              Text(message),
              const SizedBox(height: 12),
              OutlinedButton(
                key: restaurantDetailRetryButtonKey,
                onPressed: onRetry,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailEmpty extends StatelessWidget {
  const _DetailEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        MukkingCard(child: Text('식당을 찾을 수 없어요.')),
      ],
    );
  }
}

Future<void> _launchExternal(
  BuildContext context,
  WidgetRef ref,
  Uri uri, {
  required String failureMessage,
}) async {
  try {
    final launched = await ref.read(externalUrlLauncherProvider)(uri);
    if (launched || !context.mounted) return;
  } catch (_) {
    if (!context.mounted) return;
  }
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(failureMessage)),
  );
}

void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(AppRoutes.discovery);
  }
}
