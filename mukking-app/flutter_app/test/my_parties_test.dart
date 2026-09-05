import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mukking_flutter_app/core/router/app_routes.dart';
import 'package:mukking_flutter_app/core/theme/app_theme.dart';
import 'package:mukking_flutter_app/core/theme/theme_tokens.dart';
import 'package:mukking_flutter_app/features/auth/domain/auth_user.dart';
import 'package:mukking_flutter_app/features/auth/providers/auth_provider.dart';
import 'package:mukking_flutter_app/features/matching/data/matching_repository.dart';
import 'package:mukking_flutter_app/features/matching/domain/matching_party.dart';
import 'package:mukking_flutter_app/features/matching/providers/matching_provider.dart';
import 'package:mukking_flutter_app/features/profile/presentation/my_screen.dart';

void main() {
  test('my party overview separates authored and confirmed parties', () async {
    final authored = _party(id: 'authored', hostUserId: 'me');
    final confirmed = _party(
      id: 'confirmed',
      hostUserId: 'other',
      participantIds: const ['me'],
    );
    final unrelated = _party(id: 'unrelated', hostUserId: 'other');
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(_user('me')),
        matchingRepositoryProvider.overrideWithValue(
          _Repository([authored, confirmed, unrelated]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final overview = await container.read(myPartyOverviewProvider.future);

    expect(overview.authored.map((party) => party.id), ['authored']);
    expect(overview.confirmed.map((party) => party.id), ['confirmed']);
  });

  testWidgets('my parties entry renders groups and opens party detail',
      (tester) async {
    final authored = _party(id: 'authored', hostUserId: 'me');
    final confirmed = _party(
      id: 'confirmed',
      hostUserId: 'other',
      participantIds: const ['me'],
    );
    final router = GoRouter(
      initialLocation: '/test-my-parties',
      routes: [
        GoRoute(
          path: '/test-my-parties',
          builder: (_, __) => Scaffold(
            body: SingleChildScrollView(
              child: MyPartiesSection(
                parties: AsyncValue.data(
                  MyPartyOverview(
                    authored: [authored],
                    confirmed: [confirmed],
                  ),
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.partyDetail,
          builder: (_, state) =>
              Text('party:${state.pathParameters['partyId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.build(MukkingThemeId.violet),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(myPartiesCardKey), findsOneWidget);
    expect(find.text('내가 만든 모임'), findsOneWidget);
    expect(find.text('참여 확정'), findsOneWidget);
    expect(find.byKey(myAuthoredPartyKey('authored')), findsOneWidget);
    expect(find.byKey(myConfirmedPartyKey('confirmed')), findsOneWidget);

    await tester.tap(find.byKey(myAuthoredPartyKey('authored')));
    await tester.pumpAndSettle();
    expect(find.text('party:authored'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(myPartiesCardKey), findsOneWidget);
  });

  testWidgets('my parties empty state leads with a create affordance',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(MukkingThemeId.violet),
        home: const Scaffold(
          body: MyPartiesSection(
            parties: AsyncValue.data(
              MyPartyOverview(authored: [], confirmed: []),
            ),
          ),
        ),
      ),
    );

    expect(find.text('첫 모임을 만들어보세요.'), findsOneWidget);
    expect(find.byKey(myPartiesCreateButtonKey), findsOneWidget);
  });
}

AuthUser _user(String id) => AuthUser(
      id: id,
      nickname: id,
      email: '$id@example.com',
      verificationStatus: VerificationStatus.verified,
      mannerScore: 36.5,
      mannerGrade: MannerGrade.regular,
      pendingEvaluationCount: 0,
      createdAt: DateTime(2026),
    );

MatchingParty _party({
  required String id,
  required String hostUserId,
  List<String> participantIds = const [],
}) {
  return MatchingParty(
    id: id,
    hostUserId: hostUserId,
    restaurantId: 'restaurant-$id',
    title: '모임 $id',
    scheduledAt: DateTime(2026, 9, 10, 19, 30),
    currentMembers: participantIds.length + 1,
    maxMembers: 4,
    distanceKm: 0,
    rewardXp: 80,
    rewardPoints: 400,
    status: MatchingPartyStatus.open,
    hostName: hostUserId,
    memberNames: [hostUserId],
    tags: const [],
    description: '테스트 모임',
    participantIds: participantIds,
  );
}

class _Repository implements MatchingRepository {
  const _Repository(this.parties);

  final List<MatchingParty> parties;

  @override
  Future<MatchingFeed> listFeed() async =>
      MatchingFeed(parties: parties, restaurants: const []);

  @override
  Future<MatchingParty?> findPartyById(String partyId) async => null;

  @override
  Future<MatchingParty> createParty(CreatePartyInput input) =>
      throw UnimplementedError();

  @override
  Future<JoinRequestResult> createJoinRequest(String partyId) =>
      throw UnimplementedError();

  @override
  Future<PartyJoinRequest?> findMyJoinRequest(String partyId) async => null;

  @override
  Future<List<PartyJoinRequest>> listJoinRequests(String partyId) async =>
      const [];

  @override
  Future<RespondJoinRequestResult> respondJoinRequest({
    required String requestId,
    required String decision,
  }) =>
      throw UnimplementedError();
}
