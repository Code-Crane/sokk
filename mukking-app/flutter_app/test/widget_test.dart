import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
}
