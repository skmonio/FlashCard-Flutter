import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal_trek_dutch/components/text_context_menu.dart';

void main() {
  group('TextContextMenu', () {
    testWidgets('should display selected text preview', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextContextMenu(
              selectedText: 'test word',
            ),
          ),
        ),
      );

      expect(find.text('test word'), findsOneWidget);
    });

    testWidgets('should display copy option', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextContextMenu(
              selectedText: 'test word',
            ),
          ),
        ),
      );

      expect(find.text('Copy'), findsOneWidget);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('should display translate option', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextContextMenu(
              selectedText: 'test word',
            ),
          ),
        ),
      );

      expect(find.text('Translate'), findsOneWidget);
      expect(find.byIcon(Icons.translate), findsOneWidget);
    });

    testWidgets('should display add to deck option by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextContextMenu(
              selectedText: 'test word',
            ),
          ),
        ),
      );

      expect(find.text('Add to Deck'), findsOneWidget);
      expect(find.byIcon(Icons.add_card), findsOneWidget);
    });

    testWidgets('should hide add to deck option when showAddToDeck is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextContextMenu(
              selectedText: 'test word',
              showAddToDeck: false,
            ),
          ),
        ),
      );

      expect(find.text('Add to Deck'), findsNothing);
      expect(find.byIcon(Icons.add_card), findsNothing);
    });

    testWidgets('should display search option by default', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextContextMenu(
              selectedText: 'test word',
            ),
          ),
        ),
      );

      expect(find.text('Search'), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('should hide search option when showSearch is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextContextMenu(
              selectedText: 'test word',
              showSearch: false,
            ),
          ),
        ),
      );

      expect(find.text('Search'), findsNothing);
      expect(find.byIcon(Icons.search), findsNothing);
    });

    testWidgets('should call onCopy callback when copy is tapped', (WidgetTester tester) async {
      bool copyCalled = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextContextMenu(
              selectedText: 'test word',
              onCopy: () {
                copyCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Copy'));
      await tester.pump();

      expect(copyCalled, isTrue);
    });

    testWidgets('should call onTranslate callback when translate is tapped', (WidgetTester tester) async {
      bool translateCalled = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextContextMenu(
              selectedText: 'test word',
              onTranslate: () {
                translateCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Translate'));
      await tester.pump();

      expect(translateCalled, isTrue);
    });
  });
}
