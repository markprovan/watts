import 'package:flutter_test/flutter_test.dart';
import 'package:watts/battery_stats.dart';

BatterySnapshot snapshot({
  int level = 50,
  bool charging = true,
  int voltageMv = 4000,
  int currentRaw = 2000000,
  int counterUah = 2500000,
  int tempTenths = 312,
}) => BatterySnapshot(
  levelPercent: level,
  isCharging: charging,
  voltageMv: voltageMv,
  currentRaw: currentRaw,
  chargeCounterUah: counterUah,
  temperatureTenthsC: tempTenths,
  plugType: PlugType.ac,
);

void main() {
  group('currentMa', () {
    test('converts microamps', () => expect(currentMa(2000000), 2000));
    test('keeps milliamps', () => expect(currentMa(1500), 1500));
    test('ignores sign', () => expect(currentMa(-2000000), 2000));
  });

  test(
    'watts is voltage times current',
    () => expect(watts(4000, 2000), closeTo(8, 1e-9)),
  );

  group('capacityMah', () {
    test(
      'derived from counter and level',
      () => expect(capacityMah(2500000, 50), closeTo(5000, 1e-9)),
    );
    test('null when unsupported', () {
      expect(capacityMah(0, 50), isNull);
      expect(capacityMah(2500000, 0), isNull);
    });
  });

  group('minutesToTarget', () {
    test('constant current', () {
      // 5000 mAh, 50% -> 80% is 1500 mAh; at 3000 mA that is 30 minutes.
      expect(
        minutesToTarget(
          levelPercent: 50,
          targetPercent: 80,
          capacityMah: 5000,
          currentMa: 3000,
        ),
        closeTo(30, 1e-9),
      );
    });
    test('zero when already reached', () {
      expect(
        minutesToTarget(
          levelPercent: 85,
          targetPercent: 80,
          capacityMah: null,
          currentMa: 0,
        ),
        0,
      );
    });
    test('null without capacity or usable current', () {
      expect(
        minutesToTarget(
          levelPercent: 50,
          targetPercent: 80,
          capacityMah: null,
          currentMa: 3000,
        ),
        isNull,
      );
      expect(
        minutesToTarget(
          levelPercent: 50,
          targetPercent: 80,
          capacityMah: 5000,
          currentMa: 10,
        ),
        isNull,
      );
    });
  });

  test('smooth starts with first sample then blends', () {
    expect(smooth(null, 100), 100);
    expect(smooth(100, 200, alpha: 0.3), closeTo(130, 1e-9));
  });

  group('computeStats', () {
    test('while charging', () {
      final s = computeStats(snapshot(), 2000);
      expect(s.watts, closeTo(8, 1e-9));
      expect(s.temperatureC, closeTo(31.2, 1e-9));
      expect(s.voltageV, closeTo(4, 1e-9));
      // 5000 mAh: 1500 mAh to 80% and 2500 mAh to 100% at 2000 mA.
      expect(s.minutesTo80, closeTo(45, 1e-9));
      expect(s.minutesTo100, closeTo(75, 1e-9));
    });

    test('not charging hides charging fields', () {
      final s = computeStats(snapshot(charging: false), 300);
      expect(s.watts, isNull);
      expect(s.currentMa, isNull);
      expect(s.minutesTo80, isNull);
      expect(s.minutesTo100, isNull);
    });

    test('above 80% reports reached for 80%', () {
      final s = computeStats(snapshot(level: 90, counterUah: 4500000), 2000);
      expect(s.minutesTo80, 0);
      expect(s.minutesTo100, closeTo(15, 1e-9));
    });
  });

  test('PlugType.fromAndroid', () {
    expect(PlugType.fromAndroid(0), PlugType.none);
    expect(PlugType.fromAndroid(1), PlugType.ac);
    expect(PlugType.fromAndroid(2), PlugType.usb);
    expect(PlugType.fromAndroid(4), PlugType.wireless);
  });

  group('chargeForecast', () {
    final now = DateTime(2026, 1, 1, 9, 14);

    test('steps above the current level, at constant current', () {
      // 5000 mAh at 3000 mA: each 10% takes 10 minutes.
      final steps = chargeForecast(
        levelPercent: 42,
        capacityMah: 5000,
        currentMa: 3000,
        now: now,
      );
      expect(steps.map((s) => s.percent), [50, 60, 70, 80, 90, 100]);
      expect(steps.first.eta, now.add(const Duration(minutes: 8)));
      expect(steps[3].eta, now.add(const Duration(minutes: 38)));
      expect(steps.last.eta, now.add(const Duration(minutes: 58)));
    });

    test('skips steps already reached', () {
      final steps = chargeForecast(
        levelPercent: 85,
        capacityMah: 5000,
        currentMa: 3000,
        now: now,
      );
      expect(steps.map((s) => s.percent), [90, 100]);
    });

    test('empty when capacity or current is unknown', () {
      expect(
        chargeForecast(
          levelPercent: 42,
          capacityMah: null,
          currentMa: 3000,
          now: now,
        ),
        isEmpty,
      );
      expect(
        chargeForecast(
          levelPercent: 42,
          capacityMah: 5000,
          currentMa: 10,
          now: now,
        ),
        isEmpty,
      );
    });

    test('empty when full', () {
      expect(
        chargeForecast(
          levelPercent: 100,
          capacityMah: 5000,
          currentMa: 3000,
          now: now,
        ),
        isEmpty,
      );
    });
  });

  test('computeStats exposes finish times, forecast and history', () {
    final now = DateTime(2026, 1, 1, 9, 14);
    // 42% on 2.1 Ah is a 5 Ah battery: 50 mAh per percent, 2000 mA.
    final s = computeStats(
      snapshot(level: 42, counterUah: 2100000),
      2000,
      now: now,
      powerHistory: [4, 8, 6],
    );
    expect(s.updatedAt, now);
    expect(s.eta80, now.add(const Duration(minutes: 57)));
    expect(s.eta100, now.add(const Duration(minutes: 87)));
    expect(s.forecast.map((f) => f.percent), [50, 60, 70, 80, 90, 100]);
    expect(s.peakWatts, 8);
  });

  test('computeStats drops forecast and history when not charging', () {
    final s = computeStats(
      snapshot(charging: false),
      300,
      powerHistory: [4, 8],
    );
    expect(s.forecast, isEmpty);
    expect(s.powerHistory, isEmpty);
    expect(s.eta80, isNull);
    expect(s.peakWatts, isNull);
  });

  test('tempStatus thresholds', () {
    expect(tempStatus(37.9), TempStatus.normal);
    expect(tempStatus(38), TempStatus.warm);
    expect(tempStatus(41.9), TempStatus.warm);
    expect(tempStatus(42), TempStatus.hot);
  });

  test('tempBarFraction is clamped to the 15 to 45 range', () {
    expect(tempBarFraction(10), 0);
    expect(tempBarFraction(30), closeTo(0.5, 1e-9));
    expect(tempBarFraction(50), 1);
  });

  test('downsample averages neighbours down to the maximum', () {
    expect(downsample([1, 2, 3], 5), [1, 2, 3]);
    expect(downsample([1, 3, 5, 7], 2), [2, 6]);
    expect(downsample(List.filled(150, 4.0), 60), hasLength(60));
  });

  group('time left on battery', () {
    test('divides remaining charge by drain', () {
      // 2.5 Ah left at 250 mA is 10 hours.
      expect(
        minutesLeft(chargeCounterUah: 2500000, drainMa: 250),
        closeTo(600, 1e-9),
      );
    });

    test('no estimate without a charge counter or with negligible drain', () {
      expect(minutesLeft(chargeCounterUah: 0, drainMa: 250), isNull);
      expect(minutesLeft(chargeCounterUah: 2500000, drainMa: 5), isNull);
    });

    test('drainAlpha is a plain average at first, then settles', () {
      expect(drainAlpha(1), 1);
      expect(drainAlpha(2), 0.5);
      expect(drainAlpha(10), closeTo(0.1, 1e-9));
      expect(drainAlpha(500), 0.02);
    });

    test('computeStats gives time left once enough readings are in', () {
      final now = DateTime(2026, 1, 1, 12);
      final s = computeStats(
        snapshot(charging: false, counterUah: 2500000),
        300,
        now: now,
        drain: const DrainEstimate(250, minDrainSamples),
      );
      expect(s.minutesLeft, closeTo(600, 1e-9));
      expect(s.drainMa, 250);
      expect(s.emptyAt, now.add(const Duration(hours: 10)));
      expect(s.estimatingTimeLeft, isFalse);
    });

    test('computeStats says estimating while readings are few', () {
      final s = computeStats(
        snapshot(charging: false),
        300,
        drain: const DrainEstimate(250, minDrainSamples - 1),
      );
      expect(s.minutesLeft, isNull);
      expect(s.drainMa, isNull);
      expect(s.estimatingTimeLeft, isTrue);
    });

    test(
      'computeStats gives nothing when the charge counter is unsupported',
      () {
        final s = computeStats(
          snapshot(charging: false, counterUah: 0),
          300,
          drain: const DrainEstimate(250, minDrainSamples),
        );
        expect(s.minutesLeft, isNull);
        expect(s.estimatingTimeLeft, isFalse);
      },
    );

    test('computeStats ignores drain while charging', () {
      final s = computeStats(
        snapshot(),
        2000,
        drain: const DrainEstimate(250, 100),
      );
      expect(s.minutesLeft, isNull);
      expect(s.drainMa, isNull);
      expect(s.estimatingTimeLeft, isFalse);
    });

    test('timeLeftParts and timeLeftLabel', () {
      expect(timeLeftParts(680), ('11 h 20', 'min'));
      expect(timeLeftParts(45), ('45', 'min'));
      expect(timeLeftParts(3000), ('2+', 'days'));
      expect(timeLeftLabel(680), 'About 11 h 20 min left');
      expect(timeLeftLabel(45), 'About 45 min left');
      expect(timeLeftLabel(0.4), 'Under 1 min left');
      expect(timeLeftLabel(3000), 'More than 2 days left');
    });
  });

  test('durationParts', () {
    expect(durationParts(null), ('—', ''));
    expect(durationParts(0), ('Reached', ''));
    expect(durationParts(0.5), ('<1', 'min'));
    expect(durationParts(42.9), ('42', 'min'));
    expect(durationParts(65), ('1 h 05', 'min'));
  });

  test('formatClock', () {
    expect(formatClock(DateTime(2026, 1, 1, 9, 5), use24h: false), '9:05');
    expect(formatClock(DateTime(2026, 1, 1, 0, 30), use24h: false), '12:30');
    expect(formatClock(DateTime(2026, 1, 1, 21, 41), use24h: false), '9:41');
    expect(
      formatClock(DateTime(2026, 1, 1, 21, 41), use24h: false, suffix: true),
      '9:41 PM',
    );
    expect(
      formatClock(DateTime(2026, 1, 1, 0, 30), use24h: false, suffix: true),
      '12:30 AM',
    );
    expect(
      formatClock(DateTime(2026, 1, 1, 21, 41), use24h: true, suffix: true),
      '21:41',
    );
    expect(formatClock(DateTime(2026, 1, 1, 9, 5), use24h: true), '09:05');
    expect(formatClock(DateTime(2026, 1, 1, 21, 41), use24h: true), '21:41');
  });

  test('number formatting', () {
    expect(formatPower(15.84), '15.8');
    expect(formatPower(120.4), '120');
    expect(formatMa(3800), '3,800');
    expect(formatMa(950.4), '950');
    expect(formatMa(1234567), '1,234,567');
  });

  test('chargingLabel', () {
    BatteryStats stats({
      required bool charging,
      double? watts,
      PlugType plug = PlugType.ac,
    }) => BatteryStats(
      levelPercent: 50,
      isCharging: charging,
      plugType: plug,
      watts: watts,
      currentMa: null,
      voltageV: 4,
      temperatureC: 30,
      minutesTo80: null,
      minutesTo100: null,
      updatedAt: DateTime(2026),
    );
    expect(chargingLabel(stats(charging: false)), 'On battery');
    expect(
      chargingLabel(stats(charging: true, watts: 18)),
      'Fast charging · AC',
    );
    expect(
      chargingLabel(stats(charging: true, watts: 5, plug: PlugType.usb)),
      'Charging · USB',
    );
    expect(
      chargingLabel(stats(charging: true, watts: 5, plug: PlugType.unknown)),
      'Charging',
    );
  });
}
