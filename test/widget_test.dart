// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:tmassist/app.dart';
import 'package:provider/provider.dart';
import 'package:tmassist/data/in_memory_store.dart';

void main() {
  testWidgets('App starts with login screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => InMemoryStore(),
        child: const App(),
      ),
    );

    // Verify that login screen is shown.
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('TM Assist Pro'), findsOneWidget);
  });
}
