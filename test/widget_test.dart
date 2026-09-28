import 'package:flutter_test/flutter_test.dart';
import 'package:rain/app/rain_app.dart';
import 'package:rain/core/services/sound_service.dart';

void main() {
  testWidgets('RAIN app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const RainApp());
    expect(find.byType(RainApp), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 1));
    SoundService().stopRain();
    SoundService().dispose();
  });
}
