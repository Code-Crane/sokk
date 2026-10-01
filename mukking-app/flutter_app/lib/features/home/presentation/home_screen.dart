import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_error.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/brand_assets.dart';
import '../../discovery/domain/discovery_party_filter.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../matching/domain/matching_party.dart';
import '../../matching/providers/matching_provider.dart';
import '../../notifications/providers/notification_provider.dart';

List<MatchingParty> homeUpcomingParties(
        List<MatchingParty> source, DateTime now) =>
    source
        .where((p) =>
            p.scheduledAt.isAfter(now) &&
            !p.tags.contains('completed') &&
            !p.tags.contains('cancelled'))
        .toList()
      ..sort((a, b) {
        final time = a.scheduledAt.compareTo(b.scheduledAt);
        return time == 0 ? a.id.compareTo(b.id) : time;
      });

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  PartyDateFilter _date = PartyDateFilter.all;
  void _discover({String? query, bool? favoritesOnly}) {
    final controller = ref.read(discoveryFilterProvider.notifier);
    if (query != null) controller.updateQuery(query);
    if (favoritesOnly != null &&
        ref.read(discoveryFilterProvider).favoritesOnly != favoritesOnly) {
      controller.toggleFavoritesOnly();
    }
    context.go(AppRoutes.discovery);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchingPartiesProvider);
    final unread = ref.watch(unreadNotificationCountProvider).valueOrNull ?? 0;
    final open = homeUpcomingParties(state.valueOrNull ?? [], DateTime.now())
        .where(
            (p) => p.status != MatchingPartyStatus.full && p.hasAvailableSeat)
        .toList();
    final visible =
        filterDiscoveryParties(open, DiscoveryPartyFilterState(date: _date));
    final base = Theme.of(context);
    return Theme(
        data: base.copyWith(
          colorScheme: base.colorScheme.copyWith(
              primary: MukkingBrand.green,
              onPrimary: Colors.white,
              secondary: MukkingBrand.orange,
              surface: MukkingBrand.surface),
          textTheme: base.textTheme.apply(
              bodyColor: MukkingBrand.text, displayColor: MukkingBrand.text),
          inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: MukkingBrand.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: MukkingBrand.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: MukkingBrand.green))),
        ),
        child: Builder(
            builder: (context) => ColoredBox(
                color: MukkingBrand.background,
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth: MukkingBrand.contentWidth),
                        child: ListView(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                            children: [
                              Row(children: [
                                SizedBox(
                                    width: 88,
                                    child: TextButton(
                                        onPressed: () => _discover(),
                                        child: const Text('지역 탐색',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis))),
                                Expanded(
                                    child: Image.asset(BrandAssets.logo,
                                        height: 70,
                                        fit: BoxFit.contain,
                                        semanticLabel: '먹킹')),
                                SizedBox(
                                    width: 88,
                                    child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Badge(
                                            isLabelVisible: unread > 0,
                                            label: Text('$unread'),
                                            backgroundColor:
                                                MukkingBrand.orange,
                                            child: IconButton(
                                                tooltip: '알림 목록',
                                                onPressed: () => context.push(
                                                    AppRoutes.notifications),
                                                icon: const Icon(Icons
                                                    .notifications_none_rounded))))),
                              ]),
                              const SizedBox(height: 12),
                              const HomeReferenceHero(),
                              const SizedBox(height: 18),
                              TextField(
                                  key: const Key('home-search'),
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (value) =>
                                      _discover(query: value),
                                  decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.search),
                                      hintText: '식당 이름이나 메뉴를 검색해보세요',
                                      hintMaxLines: 2)),
                              const SizedBox(height: 14),
                              LayoutBuilder(builder: (context, box) {
                                final liked = _ActionCard(
                                    title: '가고싶어요',
                                    subtitle: '찜한 식당 보기',
                                    icon: Icons.edit_note_rounded,
                                    color: MukkingBrand.mint,
                                    onTap: () =>
                                        _discover(favoritesOnly: true));
                                final nearby = _ActionCard(
                                    title: '근처 동행 찾기',
                                    subtitle: '지도에서 모임 탐색',
                                    icon: Icons.people_outline_rounded,
                                    color: MukkingBrand.warm,
                                    onTap: () => _discover());
                                if (MediaQuery.textScalerOf(context).scale(14) >
                                    20) {
                                  return Column(children: [
                                    liked,
                                    const SizedBox(height: 10),
                                    nearby
                                  ]);
                                }
                                return IntrinsicHeight(
                                    child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                      Expanded(child: liked),
                                      const SizedBox(width: 10),
                                      Expanded(child: nearby)
                                    ]));
                              }),
                              const SizedBox(height: 24),
                              Row(children: [
                                const Expanded(
                                    child: Text('지금 근처 모집',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: MukkingBrand.text))),
                                TextButton(
                                    onPressed: () => _discover(),
                                    child: const Text('전체보기'))
                              ]),
                              const Text('현재 불러온 모임 · 지도에서 주변 지역을 확인하세요',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: MukkingBrand.secondary)),
                              const SizedBox(height: 10),
                              Wrap(spacing: 8, runSpacing: 6, children: [
                                for (final date in PartyDateFilter.values)
                                  ChoiceChip(
                                      label: Text(date.label),
                                      selected: _date == date,
                                      selectedColor: MukkingBrand.green,
                                      showCheckmark: false,
                                      shape: const StadiumBorder(),
                                      labelStyle: TextStyle(
                                          color: _date == date
                                              ? Colors.white
                                              : MukkingBrand.text),
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(
                                          color: MukkingBrand.border),
                                      onSelected: (_) =>
                                          setState(() => _date = date))
                              ]),
                              const SizedBox(height: 12),
                              state.when(
                                  skipLoadingOnRefresh: false,
                                  loading: () => const HomeLoadingSection(),
                                  error: (error, _) => _Surface(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(error is ApiError
                                                ? error.userMessage
                                                : '모임 정보를 불러오지 못했어요.'),
                                            TextButton(
                                                onPressed: () {
                                                  ref.invalidate(
                                                      matchingFeedProvider);
                                                  ref.invalidate(
                                                      matchingPartiesProvider);
                                                },
                                                child: const Text('다시 시도'))
                                          ])),
                                  data: (_) => visible.isEmpty
                                      ? const _Surface(
                                          child:
                                              Text('현재 조건에 맞는 모집 중인 모임이 없어요.'))
                                      : Column(children: [
                                          for (final party in visible.take(5))
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 10),
                                                child: HomeDiningPartyCard(
                                                    party: party))
                                        ])),
                              const SizedBox(height: 18),
                              _Surface(
                                  color: MukkingBrand.mint,
                                  child: Row(children: [
                                    const MukkingMascot(
                                        asset: BrandAssets.cheer, size: 64),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          const Text('함께 먹을 모임을 열어보세요',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 4),
                                          const Text('원하는 식당과 시간을 정해보세요.',
                                              style: TextStyle(fontSize: 12)),
                                          TextButton.icon(
                                              key: const Key(
                                                  'home-create-party'),
                                              onPressed: () => context
                                                  .go(AppRoutes.createParty),
                                              icon: const Icon(Icons.add),
                                              label: const Text('모임 만들기'))
                                        ]))
                                  ])),
                            ]))))));
  }
}

class HomeReferenceHero extends StatelessWidget {
  const HomeReferenceHero({super.key});
  @override
  Widget build(BuildContext context) {
    const copy =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('오늘 뭐 먹지?',
          style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: MukkingBrand.text)),
      SizedBox(height: 10),
      Text('혼밥하기 아쉬울 때,\n같이 먹을 사람을 찾아보세요!',
          style: TextStyle(fontSize: 14, height: 1.5, color: MukkingBrand.text))
    ]);
    const mascot = MukkingMascot(
        key: ValueKey('home-hero-mascot'), asset: BrandAssets.food, size: 138);
    if (MediaQuery.textScalerOf(context).scale(14) > 20) {
      return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            copy,
            Align(alignment: Alignment.centerRight, child: mascot)
          ]);
    }
    return const Row(
        children: [Expanded(child: copy), SizedBox(width: 8), mascot]);
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Icon(icon,
                    color: color == MukkingBrand.warm
                        ? MukkingBrand.orange
                        : MukkingBrand.green,
                    size: 28),
                const SizedBox(width: 8),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: MukkingBrand.text))
                    ])),
                const Icon(Icons.chevron_right_rounded,
                    size: 12, color: MukkingBrand.secondary),
              ]))));
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.color = MukkingBrand.surface});
  final Widget child;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: color,
          border: Border.all(color: MukkingBrand.border),
          borderRadius: BorderRadius.circular(16)),
      child: child);
}

class HomeDiningPartyCard extends ConsumerWidget {
  const HomeDiningPartyCard(
      {required this.party, this.active = false, super.key});
  final MatchingParty party;
  final bool active;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = ref.watch(restaurantByIdProvider(party.restaurantId));
    final liked =
        ref.watch(favoriteRestaurantIdsProvider).contains(party.restaurantId);
    final uri = Uri.tryParse(restaurant?.imageUrl ?? '');
    final image = uri != null &&
        uri.hasAuthority &&
        ['http', 'https'].contains(uri.scheme);
    const fallback = ColoredBox(
        color: MukkingBrand.mint,
        child: Center(
            child: Icon(Icons.restaurant_outlined, color: MukkingBrand.green)));
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
          width: largeText ? 64 : 92,
          height: largeText ? 84 : 144,
          child: image
              ? Image.network(uri.toString(),
                  fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
              : fallback),
    );
    return Material(
      color: MukkingBrand.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: MukkingBrand.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(selectedPartyIdProvider.notifier).state = party.id;
          context.push(AppRoutes.partyDetailPath(party.id));
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            thumbnail,
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Text(
                            party.title.isEmpty
                                ? party.restaurantName
                                : party.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: MukkingBrand.text))),
                    const SizedBox(width: 4),
                    Semantics(
                        label: liked ? '찜한 식당' : '찜하지 않은 식당',
                        child: Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            size: 19,
                            color: liked
                                ? MukkingBrand.orange
                                : MukkingBrand.text)),
                  ]),
                  const SizedBox(height: 5),
                  if (party.restaurantName.isNotEmpty)
                    Text(party.restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: MukkingBrand.secondary)),
                  if (party.address.isNotEmpty)
                    Text(party.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: MukkingBrand.secondary)),
                  if (restaurant?.distanceMeters != null)
                    Text(restaurant!.distanceLabel,
                        style: const TextStyle(
                            fontSize: 11, color: MukkingBrand.secondary)),
                  const SizedBox(height: 6),
                  Text(
                      '${party.scheduledLabel} · ${party.currentMembers}/${party.maxMembers}명',
                      style: const TextStyle(
                          fontSize: 12, color: MukkingBrand.secondary)),
                  if (party.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                            color: MukkingBrand.mint,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(party.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: MukkingBrand.green))),
                  ],
                  const SizedBox(height: 9),
                  Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (party.hostName.trim().isNotEmpty &&
                            party.hostName != '파티장')
                          Text('방장 ${party.hostName}',
                              style: const TextStyle(
                                  fontSize: 11, color: MukkingBrand.secondary)),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                                color: MukkingBrand.green,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Text('같이 가요!',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800))),
                      ]),
                ])),
          ]),
        ),
      ),
    );
  }
}

class HomeLoadingSection extends StatelessWidget {
  const HomeLoadingSection({super.key});
  @override
  Widget build(BuildContext context) =>
      const _Surface(child: Text('모임을 불러오는 중이에요.'));
}
