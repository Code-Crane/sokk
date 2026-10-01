import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/platform/external_url_launcher.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/brand_assets.dart';
import '../../../core/theme/theme_tokens.dart';
import 'discovery_visuals.dart';
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
const restaurantDetailBrowsePartiesKey =
    Key('restaurant-detail-browse-parties');
const restaurantDetailImageKey = Key('restaurant-detail-image');
const restaurantDetailImageFallbackKey =
    Key('restaurant-detail-image-fallback');

List<MatchingParty> _activeParties(List<MatchingParty> items) => items
    .where((party) =>
        party.status != MatchingPartyStatus.full && party.hasAvailableSeat)
    .toList();

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
    return DiscoveryTheme(
        child: ColoredBox(
      color: MukkingBrand.background,
      child: Builder(builder: (context) => _buildContent(context, ref)),
    ));
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(restaurantDetailProvider(restaurantId));

    return detail.when(
      loading: () => ListView(padding: const EdgeInsets.all(18), children: [
        Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
                tooltip: '뒤로가기',
                onPressed: () => _goBack(context),
                icon: const Icon(Icons.arrow_back_rounded))),
        const DiscoverySurface(
            child: Row(children: [
          SizedBox.square(
              dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Expanded(child: Text('식당 정보를 불러오고 있어요.')),
        ])),
      ]),
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

class _RestaurantDetailContent extends ConsumerStatefulWidget {
  const _RestaurantDetailContent({required this.restaurant});
  final Restaurant restaurant;
  @override
  ConsumerState<_RestaurantDetailContent> createState() =>
      _RestaurantDetailContentState();
}

class _RestaurantDetailContentState
    extends ConsumerState<_RestaurantDetailContent> {
  final _partiesKey = GlobalKey();
  Restaurant get restaurant => widget.restaurant;

  @override
  Widget build(BuildContext context) {
    final parties = ref.watch(partiesByRestaurantProvider(restaurant.id));
    final phone = restaurant.phone?.trim();
    final phoneUri =
        phone == null || phone.isEmpty ? null : Uri(scheme: 'tel', path: phone);
    final placeUri = restaurant.placeUri;
    final known = parties.hasValue && !parties.hasError && !parties.isLoading;
    final hasOpen = known && _activeParties(parties.requireValue).isNotEmpty;
    final text = Theme.of(context).textTheme;
    void createParty() =>
        context.go(AppRoutes.createPartyPath(restaurantId: restaurant.id));

    return ListView(
      key: restaurantDetailPageKey,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Stack(children: [
              _CategoryHeader(restaurant: restaurant),
              Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(children: [
                    IconButton.filledTonal(
                        onPressed: () => _goBack(context),
                        style: IconButton.styleFrom(
                            backgroundColor: MukkingBrand.surface,
                            foregroundColor: MukkingBrand.text,
                            side: const BorderSide(color: MukkingBrand.border)),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: '뒤로가기'),
                    const Spacer(),
                    IconButton.filledTonal(
                        key: restaurantDetailFavoriteButtonKey,
                        onPressed: () => _toggleFavorite(context, ref),
                        style: IconButton.styleFrom(
                            backgroundColor: MukkingBrand.surface,
                            side: const BorderSide(color: MukkingBrand.border)),
                        isSelected: restaurant.isFavorite,
                        icon: Icon(
                            restaurant.isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: restaurant.isFavorite
                                ? MukkingBrand.orange
                                : MukkingBrand.secondary),
                        tooltip: restaurant.isFavorite ? '찜 취소' : '가고 싶어요'),
                  ])),
            ]),
            const SizedBox(height: 16),
            Text(restaurant.name,
                style: text.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: MukkingBrand.text)),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 6, children: [
              if (restaurant.category.isNotEmpty)
                Text(restaurant.category, style: text.bodyMedium),
              if (restaurant.distanceMeters != null)
                Text(restaurant.distanceLabel,
                    style: text.bodyMedium?.copyWith(
                        color: MukkingBrand.green,
                        fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 14),
            if (restaurant.displayAddress.isNotEmpty)
              _InfoRow(
                  icon: Icons.place_outlined,
                  label: '주소',
                  value: restaurant.displayAddress),
            if (phoneUri != null)
              _InfoRow(icon: Icons.phone_outlined, label: '전화', value: phone!),
            if (phoneUri != null || placeUri != null)
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (phoneUri != null)
                  OutlinedButton.icon(
                      key: restaurantDetailPhoneButtonKey,
                      onPressed: () => _launchExternal(context, ref, phoneUri,
                          failureMessage: '전화 앱을 열지 못했어요.'),
                      icon: const Icon(Icons.phone_outlined, size: 18),
                      label: const Text('전화 걸기')),
                if (placeUri != null)
                  OutlinedButton.icon(
                      key: restaurantDetailPlaceButtonKey,
                      onPressed: () => _launchExternal(context, ref, placeUri,
                          failureMessage: '카카오맵을 열지 못했어요.'),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: const Text('카카오맵에서 보기')),
              ]),
            if (hasOpen) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                  key: restaurantDetailBrowsePartiesKey,
                  onPressed: () {
                    final target = _partiesKey.currentContext;
                    if (target != null) {
                      Scrollable.ensureVisible(target,
                          duration: const Duration(milliseconds: 240));
                    }
                  },
                  icon: const Icon(Icons.groups_2_outlined),
                  label: const Text('동행 보러가기')),
            ],
            const SizedBox(height: 24),
            _PartySection(
                key: _partiesKey,
                restaurantId: restaurant.id,
                parties: parties),
            const SizedBox(height: 14),
            if (known && !hasOpen)
              FilledButton.icon(
                  key: restaurantDetailCreatePartyButtonKey,
                  onPressed: createParty,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('동행 모집하기'))
            else
              OutlinedButton.icon(
                  key: restaurantDetailCreatePartyButtonKey,
                  onPressed: createParty,
                  style: OutlinedButton.styleFrom(
                      foregroundColor: MukkingBrand.green,
                      side: const BorderSide(color: MukkingBrand.green)),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('동행 모집하기')),
          ]),
        ))
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
    final uri = Uri.tryParse(restaurant.imageUrl.trim());
    const fallback = ColoredBox(
      key: restaurantDetailImageFallbackKey,
      color: MukkingBrand.mint,
      child: Center(
          child: Icon(Icons.restaurant_menu_rounded,
              size: 48, color: MukkingBrand.green)),
    );
    return LayoutBuilder(
        builder: (context, constraints) => ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: double.infinity,
                height: (constraints.maxWidth / 2.2).clamp(120, 190),
                child: uri != null &&
                        uri.hasAuthority &&
                        (uri.scheme == 'http' || uri.scheme == 'https')
                    ? Image.network(uri.toString(),
                        key: restaurantDetailImageKey,
                        fit: BoxFit.cover,
                        semanticLabel: '${restaurant.name} 식당 사진',
                        errorBuilder: (_, __, ___) => fallback,
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : fallback)
                    : fallback,
              ),
            ));
  }
}

class _PartySection extends ConsumerWidget {
  const _PartySection({
    required this.restaurantId,
    required this.parties,
    super.key,
  });

  final String restaurantId;
  final AsyncValue<List<MatchingParty>> parties;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '모집 중인 동행',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: MukkingBrand.text, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        parties.when(
          loading: () => const DiscoverySurface(
              child: Row(children: [
            SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Expanded(child: Text('모임을 확인하고 있어요.')),
          ])),
          error: (error, _) => DiscoverySurface(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(error is ApiError ? error.userMessage : '파티 정보를 불러오지 못했어요.'),
              TextButton(
                  onPressed: () =>
                      ref.invalidate(partiesByRestaurantProvider(restaurantId)),
                  child: const Text('모임 다시 불러오기')),
            ],
          )),
          data: (items) {
            final active = _activeParties(items);
            if (active.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MukkingBrand.mint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MukkingBrand.border),
                ),
                child: Row(children: [
                  const MukkingMascot(size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('아직 모집 중인 동행이 없어요',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('먼저 동행을 모집해볼까요?',
                            style: Theme.of(context).textTheme.bodySmall),
                      ])),
                ]),
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
                      context.go(
                        AppRoutes.partyDetailPath(
                          party.id,
                          returnTo: AppRoutes.restaurantDetailPath(
                            restaurantId,
                          ),
                        ),
                      );
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
    );
  }
}

class _RestaurantPartyCard extends StatelessWidget {
  const _RestaurantPartyCard({required this.party, required this.onTap});

  final MatchingParty party;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgent = party.status == MatchingPartyStatus.urgent;
    return InkWell(
      key: restaurantDetailPartyCardKey(party.id),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MukkingBrand.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MukkingBrand.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    party.scheduledLabel,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 16),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: urgent ? MukkingBrand.warm : MukkingBrand.mint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    party.status.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: urgent
                              ? MukkingBrand.orange
                              : MukkingBrand.darkGreen,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(party.title,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _CompactMeta(
                  icon: Icons.people_alt_rounded,
                  label: party.memberLabel,
                ),
                _CompactMeta(
                  icon: Icons.event_seat_outlined,
                  label:
                      '남은 자리 ${(party.maxMembers - party.currentMembers).clamp(0, party.maxMembers)}',
                ),
                if (party.hostName.isNotEmpty)
                  _CompactMeta(
                    icon: Icons.person_outline_rounded,
                    label: party.hostName,
                  ),
              ],
            ),
            if (party.description.trim().isNotEmpty &&
                party.description.trim() != party.title.trim()) ...[
              const SizedBox(height: 10),
              Text(
                party.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '모임 상세 보기',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: MukkingBrand.green,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: MukkingBrand.green,
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
        Flexible(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontSize: 12))),
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
          Expanded(
            child: Semantics(
                label: label,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                )),
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
      padding: const EdgeInsets.all(18),
      children: [
        Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
                tooltip: '뒤로가기',
                onPressed: () => _goBack(context),
                icon: const Icon(Icons.arrow_back_rounded))),
        DiscoverySurface(
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
      padding: const EdgeInsets.all(18),
      children: [
        Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
                tooltip: '뒤로가기',
                onPressed: () => _goBack(context),
                icon: const Icon(Icons.arrow_back_rounded))),
        const DiscoverySurface(child: Text('식당을 찾을 수 없어요.')),
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
