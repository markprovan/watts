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

  test('formatDuration', () {
    expect(formatDuration(null), '—');
    expect(formatDuration(0), 'Reached');
    expect(formatDuration(0.5), '<1 min');
    expect(formatDuration(42.9), '42 min');
    expect(formatDuration(65), '1 h 05 min');
  });
}
