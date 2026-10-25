import 'dart:math' as math;

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
  double? drainAverage;
  var drainSamples = 0;
  double? plateauMa;
  var chargingSamples = 0;
  while (true) {
    final map = await _channel.invokeMapMethod<Object?, Object?>('snapshot');
    if (map != null) {
      final snapshot = BatterySnapshot.fromMap(map);
      smoothedCurrentMa = smooth(
        smoothedCurrentMa,
        currentMa(snapshot.currentRaw),
      );
      if (snapshot.isCharging) {
        chargingSamples++;
        plateauMa = math.max(plateauMa ?? 0, smoothedCurrentMa);
        history.add(watts(snapshot.voltageMv, smoothedCurrentMa));
        if (history.length > _maxHistory) history.removeAt(0);
      } else {
        chargingSamples = 0;
        plateauMa = null;
        history.clear();
      }
      DrainEstimate? drain;
      if (snapshot.isPlugged) {
        drainAverage = null;
        drainSamples = 0;
      } else {
        drainSamples++;
        drainAverage = smooth(
          drainAverage,
          currentMa(snapshot.currentRaw),
          alpha: drainAlpha(drainSamples),
        );
        drain = DrainEstimate(drainAverage, drainSamples);
      }
      yield computeStats(
        snapshot,
        smoothedCurrentMa,
        powerHistory: List.of(history),
        drain: drain,
        plateauMa: plateauMa,
        systemMinutesToFull: systemFullMinutes(snapshot.systemChargeTimeMs),
        heldByCurrent: isHeldByCurrent(
          levelPercent: snapshot.levelPercent,
          smoothedCurrentMa: smoothedCurrentMa,
          chargingSamples: chargingSamples,
        ),
      );
    }
    await Future<void>.delayed(interval);
  }
}
