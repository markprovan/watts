import 'package:flutter/services.dart';

import 'battery_stats.dart';

const _channel = MethodChannel('watts/battery');

/// Emits fresh stats every couple of seconds; current changes far more often than the level.
Stream<BatteryStats> batteryStatsStream({
  Duration interval = const Duration(seconds: 2),
}) async* {
  double? smoothedCurrentMa;
  while (true) {
    final map = await _channel.invokeMapMethod<Object?, Object?>('snapshot');
    if (map != null) {
      final snapshot = BatterySnapshot.fromMap(map);
      smoothedCurrentMa = smooth(
        smoothedCurrentMa,
        currentMa(snapshot.currentRaw),
      );
      yield computeStats(snapshot, smoothedCurrentMa);
    }
    await Future<void>.delayed(interval);
  }
}
