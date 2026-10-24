import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watts/battery_stats.dart';
import 'package:watts/main.dart';

final _now = DateTime(2026, 1, 1, 9, 14);

BatteryStats _charging({List<double> history = const [6, 12, 16, 15.8]}) =>
    BatteryStats(
      levelPercent: 42,
      isCharging: true,
      plugType: PlugType.ac,
      watts: 15.8,
      currentMa: 3800,
      voltageV: 4.15,
      temperatureC: 33.4,
      minutesTo80: 27,
      minutesTo100: 41,
      updatedAt: _now,
      forecast: [
        for (final (percent, minutes) in [
          (50, 6),
          (60, 13),
          (70, 20),
          (80, 27),
          (90, 34),
          (100, 41),
        ])
          ForecastStep(percent, _now.add(Duration(minutes: minutes))),
      ],
      powerHistory: history,
    );

BatteryStats _onBattery({
  double? minutesLeft,
  double? drainMa,
  bool estimating = false,
}) => BatteryStats(
  levelPercent: 83,
  isCharging: false,
  plugType: PlugType.none,
  watts: null,
  currentMa: null,
  voltageV: 4.01,
  temperatureC: 29.1,
  minutesTo80: null,
  minutesTo100: null,
  updatedAt: _now,
  minutesLeft: minutesLeft,
  drainMa: drainMa,
  estimatingTimeLeft: estimating,
);

Future<void> _pump(
  WidgetTester tester,
  BatteryStats stats, {
  Brightness? brightness,
}) async {
  tester.view.physicalSize = const Size(390, 1300);
  tester.view.devicePixelRatio = 1;
  if (brightness != null) {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
  }
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
  });
  await tester.pumpWidget(WattsApp(stats: Stream.value(stats)));
  await tester.pump();
}

void main() {
  testWidgets('charging screen shows power, forecast and detail tiles', (
    tester,
  ) async {
    await _pump(tester, _charging());

    expect(find.text('15.8'), findsOneWidget);
    expect(find.text('Charging power'), findsOneWidget);
    expect(find.text('Fast charging · AC'), findsOneWidget);
    expect(find.text('42% · full about 9:55'), findsOneWidget);

    expect(find.text('Charge forecast'), findsOneWidget);
    expect(find.text('Now'), findsOneWidget);
    for (final label in ['50%', '60%', '70%', '90%', '100%']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('9:41'), findsOneWidget);

    expect(find.text('Time to 80%'), findsOneWidget);
    expect(find.text('27'), findsOneWidget);
    expect(find.text('Ready about 9:41'), findsOneWidget);
    expect(find.text('Time to 100%'), findsOneWidget);
    expect(find.text('41'), findsOneWidget);
    expect(find.text('Full about 9:55'), findsOneWidget);

    expect(find.text('33.4'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('3,800'), findsOneWidget);
    expect(find.text('4.15'), findsOneWidget);
    expect(find.text('Peak 16.0 W'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart shows a placeholder until there is history', (
    tester,
  ) async {
    await _pump(tester, _charging(history: const [6]));
    expect(find.text('Collecting data…'), findsOneWidget);
  });

  testWidgets('warm battery shows a warm status', (tester) async {
    final hot = _charging();
    await _pump(
      tester,
      BatteryStats(
        levelPercent: hot.levelPercent,
        isCharging: true,
        plugType: hot.plugType,
        watts: hot.watts,
        currentMa: hot.currentMa,
        voltageV: hot.voltageV,
        temperatureC: 40.2,
        minutesTo80: hot.minutesTo80,
        minutesTo100: hot.minutesTo100,
        updatedAt: _now,
        forecast: hot.forecast,
        powerHistory: hot.powerHistory,
      ),
    );
    expect(find.text('Warm'), findsOneWidget);
  });

  testWidgets('on battery shows level and a prompt to plug in', (tester) async {
    await _pump(tester, _onBattery());

    expect(find.text('83'), findsOneWidget);
    expect(find.text('Battery level'), findsOneWidget);
    expect(find.text('Not charging'), findsOneWidget);
    expect(find.text('On battery'), findsOneWidget);
    expect(find.text('Plug in to start'), findsOneWidget);
    expect(find.text('29.1'), findsOneWidget);
    expect(find.text('Charge forecast'), findsNothing);
    expect(find.text('Time to 80%'), findsNothing);
    expect(find.text('Time left'), findsNothing);
  });

  testWidgets('on battery shows time left and drain once known', (
    tester,
  ) async {
    // 680 minutes after 9:14 is 20:34.
    await _pump(tester, _onBattery(minutesLeft: 680, drainMa: 240));

    expect(find.text('About 11 h 20 min left'), findsOneWidget);
    expect(find.text('Time left'), findsOneWidget);
    expect(find.text('11 h 20'), findsOneWidget);
    expect(find.text('Empty about 8:34 PM'), findsOneWidget);
    expect(find.text('Drain'), findsOneWidget);
    expect(find.text('240'), findsOneWidget);
    expect(find.textContaining('Time left assumes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on battery says estimating while readings are collected', (
    tester,
  ) async {
    await _pump(tester, _onBattery(estimating: true));
    expect(find.text('Not charging · estimating time left…'), findsOneWidget);
    expect(find.text('Time left'), findsNothing);
  });

  testWidgets('on battery with time left at 2x text size does not overflow', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, _onBattery(minutesLeft: 680, drainMa: 1240));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark mode renders without errors', (tester) async {
    await _pump(tester, _charging(), brightness: Brightness.dark);
    expect(find.text('15.8'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('largest supported text size does not overflow', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, _charging());
    expect(tester.takeException(), isNull);
  });
}
