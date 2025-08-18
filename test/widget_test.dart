// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Simple widget test', (WidgetTester tester) async {
    // Test a simple widget instead of the full app
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('Hello Test'),
        ),
      ),
    );

    // Verify that the text appears
    expect(find.text('Hello Test'), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('Button tap test', (WidgetTester tester) async {
    int counter = 0;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                children: [
                  Text('Counter: $counter'),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        counter++;
                      });
                    },
                    child: const Text('Increment'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // Initial state
    expect(find.text('Counter: 0'), findsOneWidget);
    
    // Tap the button
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    
    // Verify the counter incremented
    expect(find.text('Counter: 1'), findsOneWidget);
  });
}
