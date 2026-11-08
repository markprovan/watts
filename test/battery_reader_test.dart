import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watts/battery_reader.dart';
import 'package:watts/battery_stats.dart';

const _channel = MethodChannel('watts/battery');

/// A channel reply shaped like the one MainActivity.kt sends.
Map<String, Object?> _reply({
  int level = 50,
  int status = 2,
  int voltageMv = 4000,
  int current = 2000000,
  int counterUah = 2500000,
  int tempTenths = 300,
  int plugged = 1,
  int systemMs = -1,
}) => {
  'levelPercent': level,
  'status': status,
  'voltageMv': voltageMv,
  'currentRaw': current,
  'chargeCounterUah': counterUah,
  'temperatureTenthsC': tempTenths,
  'plugged': plugged,
  'systemChargeTimeMs': systemMs,
};

Map<String, Object?> _discharging({int current = -500000, int level = 50}) =>
    _reply(level: level, status: 3, current: current, plugged: 0);

/// Serves [replies] in order, then repeats the last one forever.
void _serve(List<Object?> replies) {
  var i = 0;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async {
        expect(call.method, 'snapshot');
        final reply = replies[i < replies.length ? i : replies.length - 1];
        i++;
        if (reply is Exception) throw reply;
        return reply;
      });
}

Future<List<BatteryStats>> _take(int count) =>
    batteryStatsStream(interval: Duration.zero).take(count).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('turns a channel reply into display stats', () async {
    _serve([_reply(level: 42, tempTenths: 334, voltageMv: 4150)]);
    final s = (await _take(1)).single;
    expect(s.levelPercent, 42);
    expect(s.isCharging, isTrue);
    expect(s.plugType, PlugType.ac);
    expect(s.currentMa, 2000);
    expect(s.watts, closeTo(8.3, 1e-9));
    expect(s.voltageV, 4.15);
    expect(s.temperatureC, 33.4);
  });

  test('smooths the current between readings', () async {
    _serve([_reply(current: 1000000), _reply(current: 2000000)]);
    final stats = await _take(2);
    expect(stats[0].currentMa, 1000);
    // 1000 + 0.3 * (2000 - 1000)
    expect(stats[1].currentMa, closeTo(1300, 1e-9));
  });

  test('skips a reply with no data and carries on', () async {
    _serve([null, _reply(level: 61)]);
    final stats = await _take(1);
    expect(stats.single.levelPercent, 61);
  });

  test('passes a channel error to the listener', () async {
    _serve([PlatformException(code: 'unavailable')]);
    await expectLater(
      batteryStatsStream(interval: Duration.zero),
      emitsError(isA<PlatformException>()),
    );
  });

  group('power history', () {
    test('grows by one reading each time while charging', () async {
      _serve([_reply()]);
      final stats = await _take(4);
      expect([for (final s in stats) s.powerHistory.length], [1, 2, 3, 4]);
      expect(stats.last.powerHistory, everyElement(closeTo(8, 1e-9)));
    });

    test('keeps only the latest 150 readings', () async {
      _serve([_reply()]);
      final stats = await _take(155);
      expect(stats.last.powerHistory, hasLength(150));
    });

    test('starts again after unplugging', () async {
      _serve([_reply(), _reply(), _discharging(), _reply()]);
      final stats = await _take(4);
      expect(stats[1].powerHistory, hasLength(2));
      expect(stats[2].powerHistory, isEmpty);
      expect(stats[3].powerHistory, hasLength(1));
    });
  });

  group('time left on battery', () {
    test('estimates only after enough readings', () async {
      _serve([_discharging()]);
      final stats = await _take(minDrainSamples);
      for (final s in stats.take(minDrainSamples - 1)) {
        expect(s.estimatingTimeLeft, isTrue);
        expect(s.minutesLeft, isNull);
      }
      expect(stats.last.estimatingTimeLeft, isFalse);
      expect(stats.last.drainMa, closeTo(500, 1e-9));
      // 2.5 Ah at 500 mA is 5 hours.
      expect(stats.last.minutesLeft, closeTo(300, 1e-9));
    });

    test('starts over after plugging in', () async {
      _serve([
        for (var i = 0; i < minDrainSamples; i++) _discharging(),
        _reply(),
        _discharging(),
      ]);
      final stats = await _take(minDrainSamples + 2);
      expect(stats[minDrainSamples - 1].minutesLeft, isNotNull);
      expect(stats[minDrainSamples].minutesLeft, isNull);
      expect(stats.last.minutesLeft, isNull);
      expect(stats.last.estimatingTimeLeft, isTrue);
    });

    test('is not shown while plugged in', () async {
      _serve([_reply()]);
      final stats = await _take(minDrainSamples);
      expect(stats.last.minutesLeft, isNull);
      expect(stats.last.estimatingTimeLeft, isFalse);
    });
  });

  group('charge held by the phone', () {
    // Level 90 at 10 mA while the phone still says "charging".
    final stalled = _reply(level: 90, current: 10);

    test('is flagged after about 30 seconds of almost no current', () async {
      _serve([stalled]);
      final stats = await _take(minHeldSamples);
      for (final s in stats.take(minHeldSamples - 1)) {
        expect(s.isCharging, isTrue);
        expect(s.chargeHeld, isFalse);
      }
      expect(stats.last.chargeHeld, isTrue);
      expect(stats.last.isCharging, isFalse);
    });

    test('is cleared when the current comes back', () async {
      _serve([
        for (var i = 0; i < minHeldSamples; i++) stalled,
        _reply(level: 90, current: 3000000),
      ]);
      final stats = await _take(minHeldSamples + 1);
      expect(stats[minHeldSamples - 1].chargeHeld, isTrue);
      expect(stats.last.chargeHeld, isFalse);
      expect(stats.last.isCharging, isTrue);
    });

    test('counting restarts after unplugging', () async {
      _serve([
        for (var i = 0; i < minHeldSamples - 1; i++) stalled,
        _discharging(level: 90),
        for (var i = 0; i < minHeldSamples - 1; i++) stalled,
      ]);
      final stats = await _take(2 * minHeldSamples - 1);
      expect(stats.last.chargeHeld, isFalse);
    });
  });

  group('levels', () {
    test('reaching 80% is reported as reached', () async {
      _serve([_reply(level: 79), _reply(level: 80)]);
      final stats = await _take(2);
      expect(stats[0].minutesTo80, greaterThan(0));
      expect(stats[1].minutesTo80, 0);
    });

    test('a level jump moves the forecast with it', () async {
      _serve([_reply(level: 50), _reply(level: 95)]);
      final stats = await _take(2);
      expect(stats[0].forecast.first.percent, 60);
      expect(stats[1].levelPercent, 95);
      expect([for (final f in stats[1].forecast) f.percent], [100]);
    });

    test('full at 100% shows as full with no power', () async {
      _serve([_reply(level: 100, status: BatterySnapshot.statusFull)]);
      final s = (await _take(1)).single;
      expect(s.isFull, isTrue);
      expect(s.isCharging, isFalse);
      expect(s.watts, isNull);
      expect(s.forecast, isEmpty);
    });

    test('the phone pausing below 100% shows as held', () async {
      _serve([_reply(level: 85, status: BatterySnapshot.statusNotCharging)]);
      final s = (await _take(1)).single;
      expect(s.chargeHeld, isTrue);
      expect(s.isCharging, isFalse);
    });
  });

  group('odd readings', () {
    test('a milliamp reading is not scaled', () async {
      _serve([_reply(current: 1500)]);
      expect((await _take(1)).single.currentMa, 1500);
    });

    test('a negative charging current is read as positive', () async {
      _serve([_reply(current: -2000000)]);
      expect((await _take(1)).single.currentMa, 2000);
    });

    test('zero current gives no time estimates', () async {
      _serve([_reply(current: 0)]);
      final s = (await _take(1)).single;
      expect(s.watts, 0);
      expect(s.minutesTo80, isNull);
      expect(s.minutesTo100, isNull);
      expect(s.forecast, isEmpty);
    });

    test('an unsupported charge counter gives no estimates', () async {
      _serve([_reply(counterUah: 0)]);
      final s = (await _take(1)).single;
      expect(s.minutesTo80, isNull);
      expect(s.forecast, isEmpty);
    });

    test('the system estimate is used for the 100% time', () async {
      _serve([_reply(level: 50, systemMs: 3600000)]);
      final s = (await _take(1)).single;
      expect(s.fullTimeFromSystem, isTrue);
      expect(s.minutesTo100, 60);
    });
  });
}
