import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:messenger/core/services/supabase_service.dart';
import 'package:messenger/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TelegramMessengerApp()));
    expect(find.byType(TelegramMessengerApp), findsOneWidget);
  });

  testWidgets(
    'AuthGate displays fallback UI when Supabase is not initialized',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [isSupabaseInitializedProvider.overrideWithValue(false)],
          child: const TelegramMessengerApp(),
        ),
      );
      await tester.pump();

      expect(find.text('Supabase Not Initialized'), findsOneWidget);
    },
  );
}
