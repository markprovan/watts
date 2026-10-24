/// How the device is being charged.
enum PlugType {
  none('Not plugged in'),
  ac('AC'),
  usb('USB'),
  wireless('Wireless'),
  unknown('Unknown');

  const PlugType(this.label);
  final String label;

  /// Maps Android's BatteryManager.EXTRA_PLUGGED bitmask.
  static PlugType fromAndroid(int plugged) {
    if (plugged == 0) return none;
    if (plugged & 1 != 0) return ac;
    if (plugged & 2 != 0) return usb;
    if (plugged & 4 != 0) return wireless;
    return unknown;
  }
}

/// Raw values read from the system, before any calculation.
class BatterySnapshot {
  const BatterySnapshot({
    required this.levelPercent,
    required this.isCharging,
    required this.voltageMv,
    required this.currentRaw,
    required this.chargeCounterUah,
    required this.temperatureTenthsC,
    required this.plugType,
  });

  factory BatterySnapshot.fromMap(Map<Object?, Object?> map) => BatterySnapshot(
    levelPercent: map['levelPercent'] as int,
    isCharging: map['isCharging'] as bool,
    voltageMv: map['voltageMv'] as int,
    currentRaw: map['currentRaw'] as int,
    chargeCounterUah: map['chargeCounterUah'] as int,
    temperatureTenthsC: map['temperatureTenthsC'] as int,
    plugType: PlugType.fromAndroid(map['plugged'] as int),
  );

  final int levelPercent;
  final bool isCharging;
  final int voltageMv;

  /// Raw CURRENT_NOW; unit and sign vary by device.
  final int currentRaw;

  /// CHARGE_COUNTER in microamp-hours, 0 if unsupported.
  final int chargeCounterUah;
  final int temperatureTenthsC;
  final PlugType plugType;
}

/// Values ready for display. Null means "not available".
class BatteryStats {
  const BatteryStats({
    required this.levelPercent,
    required this.isCharging,
    required this.plugType,
    required this.watts,
    required this.currentMa,
    required this.voltageV,
    required this.temperatureC,
    required this.minutesTo80,
    required this.minutesTo100,
  });

  final int levelPercent;
  final bool isCharging;
  final PlugType plugType;
  final double? watts;
  final double? currentMa;
  final double voltageV;
  final double temperatureC;
  final double? minutesTo80;
  final double? minutesTo100;
}

const double _minUsableCurrentMa = 50;

/// Devices disagree on the unit of CURRENT_NOW: most report microamps, some
/// milliamps. No phone charges above 20 A, so anything >= 20000 is microamps.
double currentMa(int raw) {
  final magnitude = raw.abs().toDouble();
  return magnitude >= 20000 ? magnitude / 1000 : magnitude;
}

double watts(int voltageMv, double currentMa) =>
    (voltageMv / 1000) * (currentMa / 1000);

/// Full-charge capacity implied by the charge counter and level, or null if unknown.
double? capacityMah(int chargeCounterUah, int levelPercent) {
  if (chargeCounterUah <= 0 || levelPercent <= 0) return null;
  return chargeCounterUah / 1000 / (levelPercent / 100);
}

/// Minutes to reach [targetPercent] at a constant [currentMa].
/// Returns 0 if already there, null if it cannot be estimated.
/// Real charging slows near full, so the 100% figure is optimistic.
double? minutesToTarget({
  required int levelPercent,
  required int targetPercent,
  required double? capacityMah,
  required double currentMa,
}) {
  if (levelPercent >= targetPercent) return 0;
  if (capacityMah == null || currentMa < _minUsableCurrentMa) return null;
  final remainingMah = capacityMah * (targetPercent - levelPercent) / 100;
  return remainingMah / currentMa * 60;
}

/// Exponential moving average; the first sample is returned unchanged.
double smooth(double? previous, double sample, {double alpha = 0.3}) =>
    previous == null ? sample : previous + alpha * (sample - previous);

BatteryStats computeStats(BatterySnapshot s, double smoothedCurrentMa) {
  final charging = s.isCharging;
  final capacity = capacityMah(s.chargeCounterUah, s.levelPercent);
  double? eta(int target) => charging
      ? minutesToTarget(
          levelPercent: s.levelPercent,
          targetPercent: target,
          capacityMah: capacity,
          currentMa: smoothedCurrentMa,
        )
      : null;
  return BatteryStats(
    levelPercent: s.levelPercent,
    isCharging: charging,
    plugType: s.plugType,
    watts: charging ? watts(s.voltageMv, smoothedCurrentMa) : null,
    currentMa: charging ? smoothedCurrentMa : null,
    voltageV: s.voltageMv / 1000,
    temperatureC: s.temperatureTenthsC / 10,
    minutesTo80: eta(80),
    minutesTo100: eta(100),
  );
}

String formatDuration(double? minutes) {
  if (minutes == null) return '—';
  if (minutes <= 0) return 'Reached';
  if (minutes < 1) return '<1 min';
  final total = minutes.toInt();
  if (total < 60) return '$total min';
  return '${total ~/ 60} h ${(total % 60).toString().padLeft(2, '0')} min';
}
