import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/brand_assets.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../discovery/presentation/discovery_visuals.dart';
import '../../pet/presentation/pet_widgets.dart';
import '../../pet/domain/pet.dart';
import '../../pet/providers/pet_provider.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/presentation/auth_placeholder_screen.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../matching/domain/matching_party.dart';
import '../../matching/providers/matching_provider.dart';
import '../../settings/presentation/theme_selector.dart';
import '../domain/profile_summary.dart';
import '../providers/profile_provider.dart';
import '../providers/verification_action_provider.dart';

const myPartiesCardKey = Key('my-parties-card');
const myPartiesCreateButtonKey = Key('my-parties-create-button');

Key myAuthoredPartyKey(String partyId) =>
    ValueKey('my-authored-party-$partyId');

Key myConfirmedPartyKey(String partyId) =>
    ValueKey('my-confirmed-party-$partyId');

class MyScreen extends ConsumerStatefulWidget {
  const MyScreen({super.key});

  @override
  ConsumerState<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends ConsumerState<MyScreen> {
  final _scrollController = ScrollController();
  final _partiesKey = GlobalKey();
  final _favoritesKey = GlobalKey();
  final _settingsKey = GlobalKey();
  bool _showThemeSelector = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollTo(GlobalKey key) async {
    if (key.currentContext == null && _scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    final target = key.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) => DiscoveryTheme(
        child: Builder(
            builder: (context) => ColoredBox(
                  color: MukkingBrand.background,
                  child: Center(
                      child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth: MukkingBrand.contentWidth),
                    child: _content(context, ref),
                  )),
                )),
      );

  Widget _content(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final auth = ref.watch(authControllerProvider);
    final config = ref.watch(appConfigProvider);
    final verificationAction = ref.watch(verificationActionProvider);
    if (!auth.isAuthenticated) {
      return ListView(padding: const EdgeInsets.all(18), children: [
        Text('MY', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        const AuthPlaceholderScreen(),
        const SizedBox(height: 16),
        const ThemeSelector(),
      ]);
    }
    final favorites = ref.watch(favoriteRestaurantsProvider);
    final feed = ref.watch(restaurantFeedProvider);
    final profile = ref.watch(profileSummaryProvider);
    final myParties = ref.watch(myPartyOverviewProvider);
    final pet = ref.watch(myPetProvider);
    return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          SizedBox(
            height: 70,
            child: Stack(alignment: Alignment.center, children: [
              Image.asset(BrandAssets.logo,
                  width: 96,
                  height: 70,
                  fit: BoxFit.contain,
                  semanticLabel: '먹킹'),
              Align(
                alignment: Alignment.centerRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: '설정으로 이동',
                    onPressed: () => _scrollTo(_settingsKey),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                  IconButton(
                    tooltip: '알림',
                    onPressed: () => context.push(AppRoutes.notifications),
                    icon: const Icon(Icons.notifications_none_rounded),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          Text('MY',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: MukkingBrand.text)),
          const SizedBox(height: 2),
          Text('맛있는 사람들과, 더 특별한 식사를!',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: MukkingBrand.secondary, fontSize: 14)),
          const SizedBox(height: 14),
          profile.when(
            data: (summary) => _ProfileHeader(
              summary: summary,
              usesDevelopmentVerification: config.enableMockVerification,
              authMessage: auth.message,
              pet: pet.valueOrNull,
              overview: myParties.valueOrNull,
              favoriteCount: favorites.length,
              hasFavoriteData: favorites.isNotEmpty || feed.hasValue,
            ),
            loading: () => const Column(children: [
              DiscoverySurface(child: Text('프로필을 불러오는 중이에요.')),
              SizedBox(height: 12),
              MyPetCard(),
            ]),
            error: (error, _) => Column(children: [
              _ProfileErrorCard(error: error),
              const SizedBox(height: 12),
              const MyPetCard(),
            ]),
          ),
          if (config.enableMockVerification) ...[
            profile.when(
              data: (summary) {
                if (summary.verification?.status ==
                    VerificationStatus.verified) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: DiscoverySurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_user_outlined,
                                color: tokens.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '개발용 본인 인증',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '현재 서버의 Mock 인증으로 채팅과 매칭을 테스트합니다. 실제 개인정보는 입력하지 않습니다.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (verificationAction.hasError) ...[
                          const SizedBox(height: 8),
                          Text(
                            verificationAction.error is ApiError
                                ? (verificationAction.error as ApiError)
                                    .userMessage
                                : '인증 처리에 실패했어요.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: tokens.danger,
                                    ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('development_verification_button'),
                            onPressed: verificationAction.isLoading
                                ? null
                                : () => _completeDevelopmentVerification(
                                      context,
                                      ref,
                                    ),
                            icon: const Icon(Icons.science_outlined),
                            label: Text(
                              verificationAction.isLoading
                                  ? '인증 처리 중...'
                                  : '테스트 인증 완료하기',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
          const SizedBox(height: 22),
          const _SectionTitle(title: '내 활동'),
          const SizedBox(height: 10),
          _ActivityMenu(
            onCreated: () => _scrollTo(_partiesKey),
            onJoined: () => _scrollTo(_partiesKey),
            onFavorites: () => _scrollTo(_favoritesKey),
          ),
          const SizedBox(height: 22),
          _SectionTitle(key: _settingsKey, title: '설정'),
          const SizedBox(height: 10),
          DiscoverySurface(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(children: [
                _ActivityLink(
                  icon: Icons.notifications_none_rounded,
                  title: '알림',
                  subtitle: '알림 내역을 확인해보세요',
                  onTap: () => context.push(AppRoutes.notifications),
                ),
                const Divider(height: 1, color: MukkingBrand.border),
                _ActivityLink(
                  icon: Icons.palette_outlined,
                  title: '화면 테마',
                  subtitle: '기존 색상 프리셋을 선택할 수 있어요',
                  onTap: () =>
                      setState(() => _showThemeSelector = !_showThemeSelector),
                ),
                if (_showThemeSelector) const ThemeSelector(),
                const Divider(height: 1, color: MukkingBrand.border),
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('logout_button'),
                      onPressed: auth.isLoading
                          ? null
                          : () => _confirmLogout(context, ref),
                      style: TextButton.styleFrom(
                          foregroundColor: tokens.textSecondary),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('로그아웃'),
                    )),
              ])),
          const SizedBox(height: 22),
          KeyedSubtree(
            key: _partiesKey,
            child: MyPartiesSection(
                parties: myParties,
                onRetry: () => ref.invalidate(matchingFeedProvider)),
          ),
          const SizedBox(height: 22),
          _SectionTitle(key: _favoritesKey, title: '찜한 식당'),
          const SizedBox(height: 10),
          if (favorites.isNotEmpty)
            for (final restaurant in favorites)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    key: ValueKey('my-favorite-${restaurant.id}'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => context
                        .push(AppRoutes.restaurantDetailPath(restaurant.id)),
                    child: DiscoverySurface(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          DiscoveryRestaurantImage(restaurant: restaurant),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(restaurant.name,
                                    style:
                                        Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Text(restaurant.category),
                                Text('모집 중 ${restaurant.activePartyCount}개',
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ])),
                          const Icon(Icons.chevron_right, size: 20),
                        ])),
                  ))
          else if (feed.isLoading)
            const DiscoverySurface(child: Text('찜한 식당을 불러오는 중이에요.'))
          else if (feed.hasError)
            DiscoverySurface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('찜한 식당을 불러오지 못했어요.'),
                  TextButton(
                      onPressed: () => ref.invalidate(restaurantFeedProvider),
                      child: const Text('다시 시도')),
                ]))
          else
            const DiscoverySurface(child: Text('아직 찜한 식당이 없어요')),
        ]);
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text('다시 이용하려면 이메일과 비밀번호로 로그인해야 해요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  Future<void> _completeDevelopmentVerification(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final completed = await ref
        .read(verificationActionProvider.notifier)
        .completeDevelopmentVerification();

    if (completed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('테스트 인증이 완료됐어요.')),
      );
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.summary,
    required this.usesDevelopmentVerification,
    required this.pet,
    required this.overview,
    required this.favoriteCount,
    required this.hasFavoriteData,
    this.authMessage,
  });

  final ProfileSummary summary;
  final bool usesDevelopmentVerification;
  final Pet? pet;
  final MyPartyOverview? overview;
  final int favoriteCount;
  final bool hasFavoriteData;
  final String? authMessage;

  @override
  Widget build(BuildContext context) {
    final verification =
        summary.verification?.status ?? summary.user.verificationStatus;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final avatar = CircleAvatar(
      radius: 30,
      backgroundColor: MukkingBrand.surface,
      child: const Icon(Icons.person_outline_rounded,
          size: 35, color: MukkingBrand.green),
    );
    final mascot = pet == null
        ? const MukkingMascot(asset: BrandAssets.heart, size: 110)
        : PetImage(
            type: pet!.type,
            stage: pet!.growthStage,
            mascotAsset: BrandAssets.heart,
            size: 110);
    final mascotEntry = pet == null
        ? mascot
        : Tooltip(
            message: '펫 보러가기',
            child: InkWell(
              key: const Key('my-pet-entry'),
              borderRadius: BorderRadius.circular(38),
              onTap: () => context.push(AppRoutes.pet),
              child: mascot,
            ),
          );
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary.user.nickname,
            maxLines: largeText ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: MukkingBrand.text)),
        if (pet != null) ...[
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.workspace_premium_rounded,
                size: 16, color: MukkingBrand.orange),
            const SizedBox(width: 3),
            Text('Lv.${pet!.level}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: MukkingBrand.orange, fontWeight: FontWeight.w800)),
          ]),
        ],
        const SizedBox(height: 5),
        Text('오늘도 맛있는 만남을 찾아요!',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: MukkingBrand.secondary)),
      ],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: MukkingBrand.mint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MukkingBrand.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (largeText) ...[
          Row(children: [avatar, const Spacer(), mascotEntry]),
          const SizedBox(height: 10),
          identity,
        ] else
          Row(children: [
            avatar,
            const SizedBox(width: 12),
            Expanded(child: identity),
            const SizedBox(width: 4),
            mascotEntry,
          ]),
        if (pet == null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: MyPetCard(embedded: true),
          ),
        const SizedBox(height: 10),
        _ActivitySummary(
          overview: overview,
          favoriteCount: favoriteCount,
          hasFavoriteData: hasFavoriteData,
          mannerScore: summary.user.mannerScore,
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 7, runSpacing: 7, children: [
          _ProfileBadge(
              icon: Icons.eco_outlined, label: summary.user.mannerGrade.label),
          _ProfileBadge(
            icon: verification == VerificationStatus.verified
                ? Icons.verified_user_rounded
                : Icons.shield_outlined,
            label: usesDevelopmentVerification &&
                    verification == VerificationStatus.verified
                ? '개발용 인증'
                : verification.label,
            emphasized: verification == VerificationStatus.verified,
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          usesDevelopmentVerification
              ? '개발용 인증 상태입니다. 실제 본인확인으로 표시하지 않아요.'
              : '서버에 저장된 계정 인증 상태를 표시하고 있어요.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: MukkingBrand.secondary),
        ),
        if (summary.pendingEvaluationCount > 0) ...[
          const SizedBox(height: 7),
          Text('대기 평가 ${summary.pendingEvaluationCount}건',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: MukkingBrand.orange)),
        ],
        if (authMessage != null) ...[
          const SizedBox(height: 7),
          Text(authMessage!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ]),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: emphasized ? MukkingBrand.mint : MukkingBrand.neutralSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: MukkingBrand.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 14,
              color: emphasized ? MukkingBrand.green : MukkingBrand.secondary),
          const SizedBox(width: 4),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color:
                      emphasized ? MukkingBrand.darkGreen : MukkingBrand.text,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Text(title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontSize: 18, fontWeight: FontWeight.w800));
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({
    required this.overview,
    required this.favoriteCount,
    required this.hasFavoriteData,
    required this.mannerScore,
  });

  final MyPartyOverview? overview;
  final int favoriteCount;
  final bool hasFavoriteData;
  final double mannerScore;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final columns = largeText ? 2 : 4;
          final width = (constraints.maxWidth - 12) / columns;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(
              color: MukkingBrand.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Wrap(alignment: WrapAlignment.center, children: [
              SizedBox(
                  width: width,
                  child: _ActivityStat(
                    icon: Icons.local_fire_department_outlined,
                    label: '매너',
                    value:
                        mannerScore == 0 ? '—' : mannerScore.toStringAsFixed(1),
                  )),
              SizedBox(
                  width: width,
                  child: _ActivityStat(
                    icon: Icons.edit_calendar_outlined,
                    label: '만든 모임',
                    value:
                        overview == null ? '—' : '${overview!.authored.length}',
                  )),
              SizedBox(
                  width: width,
                  child: _ActivityStat(
                    icon: Icons.groups_2_outlined,
                    label: '참여 확정',
                    value: overview == null
                        ? '—'
                        : '${overview!.confirmed.length}',
                  )),
              SizedBox(
                  width: width,
                  child: _ActivityStat(
                    icon: Icons.favorite_border_rounded,
                    label: '찜한 식당',
                    value: hasFavoriteData ? '$favoriteCount' : '—',
                  )),
            ]),
          );
        },
      );
}

class _ActivityStat extends StatelessWidget {
  const _ActivityStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: MukkingBrand.text)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: MukkingBrand.green),
            const SizedBox(width: 4),
            Flexible(
                child: Text(value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: MukkingBrand.darkGreen,
                        fontWeight: FontWeight.w800))),
          ]),
        ]),
      );
}

class _ActivityMenu extends StatelessWidget {
  const _ActivityMenu({
    required this.onCreated,
    required this.onJoined,
    required this.onFavorites,
  });

  final VoidCallback onCreated;
  final VoidCallback onJoined;
  final VoidCallback onFavorites;

  @override
  Widget build(BuildContext context) => DiscoverySurface(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: [
          _ActivityLink(
            icon: Icons.article_outlined,
            title: '내 모집글',
            subtitle: '내가 올린 동행 모집글을 확인해보세요',
            onTap: onCreated,
          ),
          const Divider(height: 1, color: MukkingBrand.border),
          _ActivityLink(
            icon: Icons.groups_2_outlined,
            title: '참여 내역',
            subtitle: '참여가 확정된 모임을 확인해보세요',
            onTap: onJoined,
          ),
          const Divider(height: 1, color: MukkingBrand.border),
          _ActivityLink(
            icon: Icons.favorite_border_rounded,
            title: '찜한 맛집',
            subtitle: '찜한 식당을 모아보세요',
            onTap: onFavorites,
          ),
        ]),
      );
}

class _ActivityLink extends StatelessWidget {
  const _ActivityLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Icon(icon, size: 23, color: MukkingBrand.text),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: MukkingBrand.secondary)),
              ],
            )),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: MukkingBrand.secondary),
          ]),
        ),
      );
}

class MyPartiesSection extends StatelessWidget {
  const MyPartiesSection({required this.parties, this.onRetry, super.key});
  final VoidCallback? onRetry;

  final AsyncValue<MyPartyOverview> parties;

  @override
  Widget build(BuildContext context) {
    return DiscoverySurface(
      key: myPartiesCardKey,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.calendar_month_outlined,
                size: 20, color: MukkingBrand.green),
            const SizedBox(width: 8),
            Expanded(
                child: Text('내 모임',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 12),
          parties.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('내 모임을 불러오지 못했어요.'),
              if (onRetry != null)
                TextButton(
                    key: const Key('my-parties-retry'),
                    onPressed: onRetry,
                    child: const Text('다시 시도')),
            ]),
            data: (overview) {
              if (overview.authored.isEmpty && overview.confirmed.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '아직 만든 모임이나 참여하는 모임이 없어요.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('첫 모임을 만들어보세요.',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      key: myPartiesCreateButtonKey,
                      onPressed: () => context.go(AppRoutes.createParty),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('모임 만들기'),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...[
                    Text('내가 만든 모임',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: MukkingBrand.darkGreen,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    if (overview.authored.isEmpty) const Text('아직 만든 모임이 없어요.'),
                    for (final party in overview.authored)
                      _MyPartyRow(
                        key: myAuthoredPartyKey(party.id),
                        party: party,
                      ),
                  ],
                  const SizedBox(height: 16),
                  ...[
                    Text('참여하는 모임',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: MukkingBrand.darkGreen,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    if (overview.confirmed.isEmpty)
                      const Text('아직 참여 확정된 모임이 없어요.'),
                    for (final party in overview.confirmed)
                      _MyPartyRow(
                        key: myConfirmedPartyKey(party.id),
                        party: party,
                      ),
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

class _MyPartyRow extends StatelessWidget {
  const _MyPartyRow({required this.party, super.key});

  final MatchingParty party;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(AppRoutes.partyDetailPath(party.id)),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: [
            Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: MukkingBrand.mint,
                    borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.groups_2_outlined,
                    color: MukkingBrand.green, size: 19)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    party.restaurantName.isEmpty
                        ? party.title
                        : party.restaurantName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${party.scheduledLabel} · ${party.memberLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                              color: party.status == MatchingPartyStatus.full
                                  ? MukkingBrand.neutralSurface
                                  : MukkingBrand.mint,
                              borderRadius: BorderRadius.circular(999)),
                          child: Text(
                              party.status == MatchingPartyStatus.hot
                                  ? '모집 중'
                                  : party.status.label,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                      color: party.status ==
                                              MatchingPartyStatus.full
                                          ? MukkingBrand.secondary
                                          : MukkingBrand.green,
                                      fontWeight: FontWeight.w700)))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ProfileErrorCard extends ConsumerWidget {
  const _ProfileErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message =
        error is ApiError ? (error as ApiError).userMessage : '프로필을 불러오지 못했어요.';

    return DiscoverySurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        TextButton(
            key: const Key('my-profile-retry'),
            onPressed: () => ref.invalidate(profileSummaryProvider),
            child: const Text('다시 시도')),
      ]),
    );
  }
}
