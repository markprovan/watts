import 'package:flutter_test/flutter_test.dart';
import 'package:watts/battery_stats.dart';
import 'package:watts/main.dart';

void main() {
  testWidgets('shows charging stats', (tester) async {
    const stats = BatteryStats(
      levelPercent: 42,
      isCharging: true,
      plugType: PlugType.ac,
      watts: 18.5,
      currentMa: 3000,
      voltageV: 4.1,
      temperatureC: 33.4,
      minutesTo80: 25,
      minutesTo100: 70,
    );
    await tester.pumpWidget(WattsApp(stats: Stream.value(stats)));
    await tester.pump();

    expect(find.text('42%'), findsOneWidget);
    expect(find.text('Charging · AC'), findsOneWidget);
    expect(find.text('18.5 W'), findsOneWidget);
    expect(find.text('25 min'), findsOneWidget);
    expect(find.text('1 h 10 min'), findsOneWidget);
    expect(find.text('33.4 °C'), findsOneWidget);
  });

  testWidgets('shows placeholders when not charging', (tester) async {
    const stats = BatteryStats(
      levelPercent: 80,
      isCharging: false,
      plugType: PlugType.none,
      watts: null,
      currentMa: null,
      voltageV: 3.9,
      temperatureC: 30,
      minutesTo80: null,
      minutesTo100: null,
    );
    await tester.pumpWidget(WattsApp(stats: Stream.value(stats)));
    await tester.pump();

    expect(find.text('Not charging'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(4));
  });
}
