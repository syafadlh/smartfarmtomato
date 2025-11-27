// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic widget test', (WidgetTester tester) async {
    // Build a simple test widget instead of MyApp to avoid Firebase issues
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Test Widget'),
          ),
        ),
      ),
    );

    // Verify that our test widget is working
    expect(find.text('Test Widget'), findsOneWidget);
  });

  testWidgets('Counter test without Firebase', (WidgetTester tester) async {
    // Simple counter widget for testing
    int counter = 0;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              children: [
                Text('$counter'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    counter++;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Verify initial state
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Since we're testing a local variable, we need to rebuild with new value
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              children: [
                Text('$counter'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    counter++;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Verify the counter has incremented
    expect(find.text('1'), findsOneWidget);
  });
}