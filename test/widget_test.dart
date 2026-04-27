import 'package:flutter_test/flutter_test.dart';
import 'package:tmassist/app.dart';

void main() {
  testWidgets('App starts with login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    // Let widgets build
    await tester.pumpAndSettle();

    // Verify login screen
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('TM Assist Pro'), findsOneWidget);
  });
}
