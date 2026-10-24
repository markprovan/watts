import 'package:flutter/services.dart';

import 'battery_stats.dart';

const _channel = MethodChannel('watts/battery');

/// 5 minutes of history at one reading every 2 seconds.
const _maxHistory = 150;

/// Emits fresh stats every couple of seconds; current changes far more often than the level.
Stream<BatteryStats> batteryStatsStream({
  Duration interval = const Duration(seconds: 2),
}) async* {
  double? smoothedCurrentMa;
  final history = <double>[];
  while (true) {
    final map = await _channel.invokeMapMethod<Object?, Object?>('snapshot');
    if (map != null) {
      final snapshot = BatterySnapshot.fromMap(map);
      smoothedCurrentMa = smooth(
        smoothedCurrentMa,
        currentMa(snapshot.currentRaw),
      );
      if (snapshot.isCharging) {
        history.add(watts(snapshot.voltageMv, smoothedCurrentMa));
        if (history.length > _maxHistory) history.removeAt(0);
      } else {
        history.clear();
      }
      yield computeStats(
        snapshot,
        smoothedCurrentMa,
        powerHistory: List.of(history),
      );
    }
    await Future<void>.delayed(interval);
  }
}
