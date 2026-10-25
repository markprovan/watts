import 'package:flutter_test/flutter_test.dart';
import 'package:watts/battery_stats.dart';

BatterySnapshot snapshot({
  int level = 50,
  bool charging = true,
  int voltageMv = 4000,
  int currentRaw = 2000000,
  int counterUah = 2500000,
  int tempTenths = 312,
  PlugType plug = PlugType.ac,
  int? status,
  int systemMs = -1,
}) => BatterySnapshot(
  levelPercent: level,
  isCharging: charging,
  status: status,
  voltageMv: voltageMv,
  currentRaw: currentRaw,
  chargeCounterUah: counterUah,
  temperatureTenthsC: tempTenths,
  plugType: plug,
  systemChargeTimeMs: systemMs,
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
      // 5000 mAh at 2000 mA: 1500 mAh to 80% is 45 minutes. The last 20%
      // would take 30 minutes at that rate; the slowdown makes it 48.
      expect(s.minutesTo80, closeTo(45, 1e-9));
      expect(s.minutesTo100, closeTo(93, 1e-9));
    });

    test('not charging hides charging fields', () {
      final s = computeStats(
        snapshot(charging: false, plug: PlugType.none),
        300,
      );
      expect(s.watts, isNull);
      expect(s.currentMa, isNull);
      expect(s.minutesTo80, isNull);
      expect(s.minutesTo100, isNull);
    });

    test('above 80% reports reached for 80%', () {
      final s = computeStats(snapshot(level: 90, counterUah: 4500000), 2000);
      expect(s.minutesTo80, 0);
      // The current has not dropped yet at 90%, so the slowdown is eased.
      expect(s.minutesTo100, closeTo(18.045, 0.001));
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

    test('steps above the current level, slowing after 80%', () {
      // 5000 mAh at 3000 mA: each 10% takes 10 minutes up to 80%, then
      // 14.2 minutes for 80 to 90% and 23.8 minutes for 90 to 100%.
      final steps = chargeForecast(
        levelPercent: 42,
        capacityMah: 5000,
        currentMa: 3000,
        now: now,
      );
      expect(steps.map((s) => s.percent), [50, 60, 70, 80, 90, 100]);
      expect(steps.first.eta, now.add(const Duration(minutes: 8)));
      expect(steps[3].eta, now.add(const Duration(minutes: 38)));
      expect(steps[4].eta, now.add(const Duration(seconds: 52 * 60 + 12)));
      expect(steps.last.eta, now.add(const Duration(minutes: 76)));
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
    expect(s.eta100, now.add(const Duration(minutes: 105)));
    expect(s.forecast.map((f) => f.percent), [50, 60, 70, 80, 90, 100]);
    expect(s.peakWatts, 8);
  });

  test('computeStats drops forecast and history when not charging', () {
    final s = computeStats(
      snapshot(charging: false, plug: PlugType.none),
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
        snapshot(charging: false, counterUah: 2500000, plug: PlugType.none),
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
        snapshot(charging: false, plug: PlugType.none),
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
          snapshot(charging: false, counterUah: 0, plug: PlugType.none),
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

  group('taper model', () {
    double average(double from, double strength) {
      var sum = 0.0;
      for (var i = 0; i < 10; i++) {
        sum += taperMultiplier(from + i + 0.5, strength);
      }
      return sum / 10;
    }

    test('no slowdown up to 80%', () {
      expect(taperMultiplier(50.5, 1), 1);
      expect(taperMultiplier(79.5, 1), 1);
    });

    test('averages match the typical curve at full strength', () {
      expect(average(80, 1), closeTo(1.7, 1e-9));
      expect(average(90, 1), closeTo(3.3, 1e-9));
    });

    test('a gentler charge slows down less', () {
      expect(average(90, 0.25), lessThan(average(90, 1)));
      expect(average(90, 0.25), closeTo(1 + 2.3 * 0.25, 1e-9));
    });

    test('strength follows charge rate against battery size, clamped', () {
      expect(taperStrength(5000, 500), 0.25);
      expect(taperStrength(5000, 2500), closeTo(0.5, 1e-9));
      expect(taperStrength(5000, 9000), 1);
    });

    test('is the plain estimate below 80%', () {
      expect(
        minutesToTarget(
          levelPercent: 20,
          targetPercent: 80,
          capacityMah: 5000,
          currentMa: 3000,
          plateauMa: 3000,
        ),
        closeTo(60, 1e-9),
      );
    });

    test('takes longer than a constant rate above 80%', () {
      final tapered = minutesToTarget(
        levelPercent: 80,
        targetPercent: 100,
        capacityMah: 5000,
        currentMa: 3000,
        plateauMa: 3000,
      )!;
      // 1000 mAh at 3000 mA is 20 minutes at a constant rate.
      expect(tapered, greaterThan(30));
    });

    test('uses a steeper slowdown once the current has dropped further', () {
      double at(double current) => minutesToTarget(
        levelPercent: 90,
        targetPercent: 100,
        capacityMah: 5000,
        currentMa: current,
        plateauMa: 3000,
      )!;
      expect(at(500), greaterThan(at(1500)));
      expect(at(1500), greaterThan(at(3000)));
    });

    test('is null without capacity or a usable current', () {
      expect(
        minutesToTarget(
          levelPercent: 85,
          targetPercent: 100,
          capacityMah: null,
          currentMa: 2000,
        ),
        isNull,
      );
      expect(
        minutesToTarget(
          levelPercent: 85,
          targetPercent: 100,
          capacityMah: 5000,
          currentMa: 10,
        ),
        isNull,
      );
    });
  });

  group('system estimate to full', () {
    final now = DateTime(2026, 1, 1, 9, 14);

    test('systemFullMinutes accepts plausible values only', () {
      expect(systemFullMinutes(-1), isNull);
      expect(systemFullMinutes(0), isNull);
      expect(systemFullMinutes(30000), isNull);
      expect(systemFullMinutes(45 * 60000), 45);
      expect(systemFullMinutes(25 * 60 * 60000), isNull);
    });

    test('replaces the 100% time and keeps the forecast in order', () {
      final steps = chargeForecast(
        levelPercent: 42,
        capacityMah: 5000,
        currentMa: 3000,
        now: now,
        systemMinutesToFull: 100,
      );
      final minutes = [
        for (final s in steps) s.eta.difference(now).inSeconds / 60,
      ];
      expect(minutes[3], closeTo(38, 0.02));
      expect(minutes.last, closeTo(100, 0.02));
      expect(minutes[4], greaterThan(minutes[3]));
      expect(minutes[4], lessThan(minutes.last));
      // 90% keeps its model share of the 80 to 100% span (14.2 of 38).
      expect(minutes[4], closeTo(38 + (100 - 38) * 14.2 / 38, 0.05));
    });

    test('computeStats uses it for 100% and says so', () {
      final s = computeStats(
        snapshot(level: 42, counterUah: 2100000, systemMs: 90 * 60000),
        2000,
        now: now,
        systemMinutesToFull: systemFullMinutes(90 * 60000),
      );
      expect(s.minutesTo80, closeTo(57, 1e-9));
      expect(s.minutesTo100, 90);
      expect(s.fullTimeFromSystem, isTrue);
    });

    test('never shows 100% sooner than 80%', () {
      final s = computeStats(
        snapshot(level: 42, counterUah: 2100000),
        2000,
        systemMinutesToFull: 20,
      );
      expect(s.minutesTo100, closeTo(57, 1e-9));
    });

    test('is ignored when absent', () {
      final s = computeStats(snapshot(), 2000);
      expect(s.fullTimeFromSystem, isFalse);
    });
  });

  group('plugged in but not charging', () {
    test('status not charging below 100% is a pause', () {
      final s = computeStats(
        snapshot(
          level: 80,
          charging: false,
          status: BatterySnapshot.statusNotCharging,
        ),
        10,
      );
      expect(s.chargeHeld, isTrue);
      expect(s.isCharging, isFalse);
      expect(s.isFull, isFalse);
      expect(s.isPlugged, isTrue);
      expect(s.watts, isNull);
      expect(s.forecast, isEmpty);
      expect(s.minutesTo100, isNull);
    });

    test('a long stall at low current is a pause', () {
      final s = computeStats(
        snapshot(level: 80, currentRaw: 5000),
        5,
        heldByCurrent: true,
      );
      expect(s.chargeHeld, isTrue);
      expect(s.isCharging, isFalse);
      expect(s.minutesTo80, isNull);
    });

    test('full status at 100% is full, not charging', () {
      final s = computeStats(
        snapshot(
          level: 100,
          charging: false,
          status: BatterySnapshot.statusFull,
        ),
        0,
      );
      expect(s.isFull, isTrue);
      expect(s.chargeHeld, isFalse);
      expect(s.isCharging, isFalse);
      expect(s.isPlugged, isTrue);
    });

    test('not charging at 100% counts as full', () {
      final s = computeStats(
        snapshot(
          level: 100,
          charging: false,
          status: BatterySnapshot.statusNotCharging,
        ),
        0,
      );
      expect(s.isFull, isTrue);
      expect(s.chargeHeld, isFalse);
    });

    test('no time left or drain while plugged in', () {
      final s = computeStats(
        snapshot(
          level: 80,
          charging: false,
          status: BatterySnapshot.statusNotCharging,
        ),
        10,
        drain: const DrainEstimate(250, minDrainSamples),
      );
      expect(s.minutesLeft, isNull);
      expect(s.drainMa, isNull);
      expect(s.estimatingTimeLeft, isFalse);
    });

    test('isHeldByCurrent needs time, a high level and almost no current', () {
      bool held({
        int level = 80,
        double current = 5,
        int samples = minHeldSamples,
      }) => isHeldByCurrent(
        levelPercent: level,
        smoothedCurrentMa: current,
        chargingSamples: samples,
      );
      expect(held(), isTrue);
      expect(held(samples: minHeldSamples - 1), isFalse);
      expect(held(level: 60), isFalse);
      expect(held(level: 100), isFalse);
      expect(held(current: 500), isFalse);
    });

    test('snapshot from the channel reads status and system estimate', () {
      final s = BatterySnapshot.fromMap({
        'levelPercent': 80,
        'status': 2,
        'voltageMv': 4300,
        'currentRaw': 1000000,
        'chargeCounterUah': 3000000,
        'temperatureTenthsC': 300,
        'plugged': 1,
        'systemChargeTimeMs': 1800000,
      });
      expect(s.isCharging, isTrue);
      expect(s.systemChargeTimeMs, 1800000);
      expect(s.isPlugged, isTrue);
      expect(s.pausedByPhone, isFalse);
    });
  });

  test('chargingLabel', () {
    BatteryStats stats({
      required bool charging,
      double? watts,
      PlugType plug = PlugType.ac,
      bool held = false,
      bool full = false,
    }) => BatteryStats(
      levelPercent: 50,
      isCharging: charging,
      chargeHeld: held,
      isFull: full,
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
    expect(chargingLabel(stats(charging: false, held: true)), 'Paused · AC');
    expect(chargingLabel(stats(charging: false, full: true)), 'Full · AC');
  });
}
