import 'dart:math' as math;

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
    required this.updatedAt,
    this.forecast = const [],
    this.powerHistory = const [],
    this.minutesLeft,
    this.drainMa,
    this.estimatingTimeLeft = false,
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

  /// When the values above were read; estimated finish times count from here.
  final DateTime updatedAt;

  /// Estimated time of each 10% step above the current level, empty if unknown.
  final List<ForecastStep> forecast;

  /// Recent charging power in watts, oldest first.
  final List<double> powerHistory;

  /// Minutes of battery life left at the recent drain, when unplugged and known.
  final double? minutesLeft;

  /// Recent average drain in milliamps, when unplugged and known.
  final double? drainMa;

  /// Unplugged and still collecting enough readings for [minutesLeft].
  final bool estimatingTimeLeft;

  DateTime? get eta80 => _eta(minutesTo80);
  DateTime? get eta100 => _eta(minutesTo100);

  /// When the battery runs out at the recent drain.
  DateTime? get emptyAt => _eta(minutesLeft);

  double? get peakWatts =>
      powerHistory.isEmpty ? null : powerHistory.reduce(math.max);

  DateTime? _eta(double? minutes) => minutes == null || minutes <= 0
      ? null
      : updatedAt.add(Duration(seconds: (minutes * 60).round()));
}

/// Estimated time at which the battery reaches [percent].
class ForecastStep {
  const ForecastStep(this.percent, this.eta);

  final int percent;
  final DateTime eta;
}

/// Above this charging power the app calls it "fast charging".
const double fastChargeWatts = 15;

const List<int> forecastTargets = [50, 60, 70, 80, 90, 100];

enum TempStatus {
  normal('Normal'),
  warm('Warm'),
  hot('Hot');

  const TempStatus(this.label);
  final String label;
}

TempStatus tempStatus(double celsius) {
  if (celsius >= 42) return TempStatus.hot;
  if (celsius >= 38) return TempStatus.warm;
  return TempStatus.normal;
}

/// Position of [celsius] on the 15 to 45 degree temperature bar, 0 to 1.
double tempBarFraction(double celsius) => ((celsius - 15) / 30).clamp(0.0, 1.0);

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

/// Estimated time for each step in [forecastTargets] above [levelPercent].
/// Empty when the rate or capacity is unknown.
List<ForecastStep> chargeForecast({
  required int levelPercent,
  required double? capacityMah,
  required double currentMa,
  required DateTime now,
}) {
  final steps = <ForecastStep>[];
  for (final target in forecastTargets) {
    if (target <= levelPercent) continue;
    final minutes = minutesToTarget(
      levelPercent: levelPercent,
      targetPercent: target,
      capacityMah: capacityMah,
      currentMa: currentMa,
    );
    if (minutes == null) return const [];
    steps.add(
      ForecastStep(target, now.add(Duration(seconds: (minutes * 60).round()))),
    );
  }
  return steps;
}

/// Running average of the discharge current while unplugged.
class DrainEstimate {
  const DrainEstimate(this.averageMa, this.samples);

  final double averageMa;
  final int samples;

  bool get isReady => samples >= minDrainSamples;
}

/// Readings (2 seconds apart) needed before showing time left, about 30 seconds.
const int minDrainSamples = 15;

/// Drain below this is treated as noise and gives no estimate.
const double minDrainMa = 20;

/// Weight of a new drain reading: a plain average at first, then a moving
/// average that settles to roughly the last two minutes.
double drainAlpha(int samples) => math.max(1 / samples, 0.02);

/// Minutes until empty at a constant [drainMa], or null if it cannot be estimated.
double? minutesLeft({required int chargeCounterUah, required double drainMa}) {
  if (chargeCounterUah <= 0 || drainMa < minDrainMa) return null;
  return chargeCounterUah / 1000 / drainMa * 60;
}

BatteryStats computeStats(
  BatterySnapshot s,
  double smoothedCurrentMa, {
  DateTime? now,
  List<double> powerHistory = const [],
  DrainEstimate? drain,
}) {
  final time = now ?? DateTime.now();
  final charging = s.isCharging;
  final capacity = capacityMah(s.chargeCounterUah, s.levelPercent);
  final readyDrain = !charging && drain != null && drain.isReady ? drain : null;
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
    updatedAt: time,
    forecast: charging
        ? chargeForecast(
            levelPercent: s.levelPercent,
            capacityMah: capacity,
            currentMa: smoothedCurrentMa,
            now: time,
          )
        : const [],
    powerHistory: charging ? powerHistory : const [],
    minutesLeft: readyDrain == null
        ? null
        : minutesLeft(
            chargeCounterUah: s.chargeCounterUah,
            drainMa: readyDrain.averageMa,
          ),
    drainMa: readyDrain != null && readyDrain.averageMa >= minDrainMa
        ? readyDrain.averageMa
        : null,
    estimatingTimeLeft:
        !charging && drain != null && !drain.isReady && s.chargeCounterUah > 0,
  );
}

/// Keeps at most [maxPoints] values by averaging neighbours, so a long
/// history draws as a short smooth line.
List<double> downsample(List<double> values, int maxPoints) {
  if (values.length <= maxPoints) return values;
  final result = <double>[];
  for (var i = 0; i < maxPoints; i++) {
    final start = i * values.length ~/ maxPoints;
    final end = math.max(start + 1, (i + 1) * values.length ~/ maxPoints);
    final chunk = values.sublist(start, end);
    result.add(chunk.reduce((a, b) => a + b) / chunk.length);
  }
  return result;
}

/// Number and unit for a duration tile, e.g. ("27", "min") or ("Reached", "").
(String, String) durationParts(double? minutes) {
  if (minutes == null) return ('—', '');
  if (minutes <= 0) return ('Reached', '');
  if (minutes < 1) return ('<1', 'min');
  final total = minutes.toInt();
  if (total < 60) return ('$total', 'min');
  return ('${total ~/ 60} h ${(total % 60).toString().padLeft(2, '0')}', 'min');
}

/// Clock time for finish estimates. The 12-hour form leaves out am/pm to stay
/// compact unless [suffix] is set, which is needed when the time can be many hours away.
String formatClock(DateTime t, {required bool use24h, bool suffix = false}) {
  final minute = t.minute.toString().padLeft(2, '0');
  if (use24h) return '${t.hour.toString().padLeft(2, '0')}:$minute';
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final period = suffix ? (t.hour < 12 ? ' AM' : ' PM') : '';
  return '$hour:$minute$period';
}

String formatPower(double watts) =>
    watts >= 100 ? watts.toStringAsFixed(0) : watts.toStringAsFixed(1);

/// Whole milliamps with a thousands separator, e.g. 3,800.
String formatMa(double ma) => ma.round().toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

String chargingLabel(BatteryStats stats) {
  if (!stats.isCharging) return 'On battery';
  final speed = (stats.watts ?? 0) >= fastChargeWatts
      ? 'Fast charging'
      : 'Charging';
  return switch (stats.plugType) {
    PlugType.none || PlugType.unknown => speed,
    final plug => '$speed · ${plug.label}',
  };
}

/// Number and unit for the time-left tile; very long estimates are capped.
(String, String) timeLeftParts(double? minutes) {
  if (minutes != null && minutes >= _maxTimeLeftMinutes) return ('2+', 'days');
  return durationParts(minutes);
}

/// Sentence for the hero line, e.g. "About 11 h 20 min left".
String timeLeftLabel(double minutes) {
  if (minutes >= _maxTimeLeftMinutes) return 'More than 2 days left';
  if (minutes < 1) return 'Under 1 min left';
  final (value, unit) = durationParts(minutes);
  return 'About $value $unit left';
}

const double _maxTimeLeftMinutes = 2 * 24 * 60;
