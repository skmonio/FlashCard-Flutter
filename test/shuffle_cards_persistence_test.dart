import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:taal_trek_dutch/providers/flashcard_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taal_trek_dutch/views/shuffle_cards_view.dart';

Widget _buildTestApp() {
  return ChangeNotifierProvider(
    create: (_) => FlashcardProvider(),
    child: const MaterialApp(home: ShuffleCardsView()),
  );
}

void main() {
  group('ShuffleCardsView Persistence', () {
    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance().then((prefs) => prefs.clear());
    });

    testWidgets('should load default enabled modes when no settings saved', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());

      // Wait for the widget to initialize
      await tester.pumpAndSettle();

      // The default state should have all modes enabled
      // We can verify this by checking if the "All Types Enabled" chip is shown
      expect(find.text('All Types Enabled'), findsOneWidget);
    });

    testWidgets('should save and load custom enabled modes', (
      WidgetTester tester,
    ) async {
      // First, set some custom preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('shuffle_mode_multiple_choice', false);
      await prefs.setBool('shuffle_mode_memory_game', false);

      await tester.pumpWidget(_buildTestApp());

      // Wait for the widget to initialize
      await tester.pumpAndSettle();

      // Should show "5 of 7 Types" since we disabled 2 modes
      expect(find.text('5 of 7 Types'), findsOneWidget);
    });

    testWidgets('should show settings dialog with correct toggle states', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());

      await tester.pumpAndSettle();

      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();

      // Check that the dialog appears
      expect(find.text('Customize Exercise Types'), findsOneWidget);
      expect(find.text('Test Your Cards'), findsOneWidget);
      expect(find.text('Remember Your Cards'), findsOneWidget);
      expect(find.text('Pick Your Card'), findsOneWidget);
    });

    testWidgets('should update toggle state when switched', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_buildTestApp());

      await tester.pumpAndSettle();

      await tester.tap(find.text('Customize'));
      await tester.pumpAndSettle();

      // Find the Multiple Choice toggle and tap it
      final multipleChoiceToggle = find.ancestor(
        of: find.text('Test Your Cards'),
        matching: find.byType(SwitchListTile),
      );

      expect(multipleChoiceToggle, findsOneWidget);

      // Tap the toggle
      await tester.tap(multipleChoiceToggle);
      await tester.pumpAndSettle();

      // The toggle should now be off (we can't easily test the visual state in unit tests,
      // but we can verify the callback was called by checking if settings were saved)

      // Close the dialog
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Check that the main view shows the updated count
      expect(find.text('6 of 7 Types'), findsOneWidget);
    });
  });
}
