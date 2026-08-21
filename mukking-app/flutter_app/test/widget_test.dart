import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mukking_flutter_app/features/discovery/providers/discovery_provider.dart';
import 'package:mukking_flutter_app/features/home/providers/home_provider.dart';
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

  test('favorite restaurant updates home parties and notifications', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(favoriteRestaurantPartiesProvider), isEmpty);
    expect(container.read(mockNotificationsProvider), isEmpty);

    container
        .read(favoriteRestaurantIdsProvider.notifier)
        .toggle('restaurant-001');

    expect(container.read(favoriteRestaurantPartiesProvider), hasLength(2));
    expect(container.read(mockNotificationsProvider), hasLength(2));
  });
}
