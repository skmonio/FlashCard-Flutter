import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flashcard_app/views/shuffle_cards_view.dart';

void main() {
  group('ShuffleCardsView Persistence', () {
    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
      await SharedPreferences.getInstance().then((prefs) => prefs.clear());
    });

    testWidgets('should load default enabled modes when no settings saved', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ShuffleCardsView(),
        ),
      );

      // Wait for the widget to initialize
      await tester.pumpAndSettle();

      // The default state should have all modes enabled
      // We can verify this by checking if the "All Types Enabled" chip is shown
      expect(find.text('All Types Enabled'), findsOneWidget);
    });

    testWidgets('should save and load custom enabled modes', (WidgetTester tester) async {
      // First, set some custom preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('shuffle_mode_multiple_choice', false);
      await prefs.setBool('shuffle_mode_memory_game', false);

      await tester.pumpWidget(
        MaterialApp(
          home: const ShuffleCardsView(),
        ),
      );

      // Wait for the widget to initialize
      await tester.pumpAndSettle();

      // Should show "4 of 6 Types" since we disabled 2 modes
      expect(find.text('4 of 6 Types'), findsOneWidget);
    });

    testWidgets('should show settings dialog with correct toggle states', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ShuffleCardsView(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the settings button in the app bar (more specific)
      await tester.tap(find.byWidgetPredicate(
        (widget) => widget is IconButton && 
                    widget.icon is Icon && 
                    (widget.icon as Icon).icon == Icons.settings,
      ));
      await tester.pumpAndSettle();

      // Check that the dialog appears
      expect(find.text('Customize Exercise Types'), findsOneWidget);
      expect(find.text('Multiple Choice'), findsOneWidget);
      expect(find.text('Memory Game'), findsOneWidget);
      expect(find.text('Dutch Exercises'), findsOneWidget);
    });

    testWidgets('should update toggle state when switched', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const ShuffleCardsView(),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the settings button in the app bar (more specific)
      await tester.tap(find.byWidgetPredicate(
        (widget) => widget is IconButton && 
                    widget.icon is Icon && 
                    (widget.icon as Icon).icon == Icons.settings,
      ));
      await tester.pumpAndSettle();

      // Find the Multiple Choice toggle and tap it
      final multipleChoiceToggle = find.byWidgetPredicate(
        (widget) => widget is SwitchListTile && 
                    widget.title is Row && 
                    (widget.title as Row).children.any((child) => 
                      child is Text && (child as Text).data == 'Multiple Choice'
                    ),
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
      expect(find.text('5 of 6 Types'), findsOneWidget);
    });
  });
}
