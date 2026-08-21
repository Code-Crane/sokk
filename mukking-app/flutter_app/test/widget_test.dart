import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mukking_flutter_app/core/network/api_error.dart';
import 'package:mukking_flutter_app/features/auth/data/auth_repository.dart';
import 'package:mukking_flutter_app/features/chat/providers/chat_provider.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_provider.dart';
import 'package:mukking_flutter_app/features/home/providers/home_provider.dart';
import 'package:mukking_flutter_app/features/matching/providers/matching_provider.dart';
import 'package:mukking_flutter_app/features/notifications/providers/mock_notifications_provider.dart';
import 'package:mukking_flutter_app/main.dart';

void main() {
  testWidgets('renders mukking home shell', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MukkingApp(),
      ),
    );

    expect(find.text('먹킹'), findsWidgets);
    expect(find.text('홈'), findsOneWidget);
    expect(find.text('발견'), findsOneWidget);
  });

  test('favorite restaurant updates home parties and notifications', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(favoriteRestaurantPartiesProvider), isEmpty);
    expect(await container.read(mockNotificationsProvider.future), isEmpty);

    await container.read(matchingPartiesProvider.future);

    container
        .read(favoriteRestaurantIdsProvider.notifier)
        .toggle('restaurant-001');

    expect(container.read(favoriteRestaurantPartiesProvider), hasLength(2));
    expect(
        await container.read(mockNotificationsProvider.future), hasLength(2));
  });

  test('mock matching fallback supports join request', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final parties = await container.read(matchingPartiesProvider.future);
    expect(parties, isNotEmpty);

    final result = await container
        .read(joinPartyControllerProvider.notifier)
        .join(parties.first.id);

    expect(result?.status, 'pending');
  });

  test('mock chat fallback exposes rooms and messages', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final rooms = await container.read(chatRoomsProvider.future);
    expect(rooms, hasLength(1));

    final messages =
        await container.read(chatMessagesProvider(rooms.first.id).future);
    expect(
      messages.map((message) => message.text),
      contains('좋아요. 도착하면 입구에서 만나요.'),
    );
  });

  test('auth state is unauthenticated without supabase config', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = await container.read(authRepositoryProvider).currentState();
    expect(state.isAuthenticated, isFalse);
  });

  test('api error mapping hides server details from user message', () {
    final unauthorized = ApiError.fromStatusCode(
      401,
      serverMessage: 'Invalid or expired Supabase JWT.',
    );
    final forbidden = ApiError.fromStatusCode(403);
    final conflict = ApiError.fromStatusCode(409);
    final rateLimited = ApiError.fromStatusCode(429);
    final server = ApiError.fromStatusCode(500);

    expect(unauthorized.userMessage, '로그인이 필요해요.');
    expect(forbidden.userMessage, contains('권한'));
    expect(conflict.userMessage, contains('중복'));
    expect(rateLimited.userMessage, contains('잠시 후'));
    expect(server.userMessage, contains('서버 오류'));
    expect(unauthorized.userMessage, isNot(contains('JWT')));
  });
}
