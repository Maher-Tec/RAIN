// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:rain/app/rain_app.dart';

void main() {
  testWidgets('RAIN app loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RainApp());

    // Verify the app loads (no assertions needed for this minimal test)
    expect(find.byType(RainApp), findsOneWidget);
  });
}
