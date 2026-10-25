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
    int? status,
    this.systemChargeTimeMs = -1,
  }) : status = status ?? (isCharging ? statusCharging : statusDischarging);

  factory BatterySnapshot.fromMap(Map<Object?, Object?> map) {
    final status = map['status'] as int;
    return BatterySnapshot(
      levelPercent: map['levelPercent'] as int,
      isCharging: status == statusCharging,
      status: status,
      voltageMv: map['voltageMv'] as int,
      currentRaw: map['currentRaw'] as int,
      chargeCounterUah: map['chargeCounterUah'] as int,
      temperatureTenthsC: map['temperatureTenthsC'] as int,
      plugType: PlugType.fromAndroid(map['plugged'] as int),
      systemChargeTimeMs: map['systemChargeTimeMs'] as int,
    );
  }

  /// BatteryManager status values.
  static const int statusCharging = 2;
  static const int statusDischarging = 3;
  static const int statusNotCharging = 4;
  static const int statusFull = 5;

  final int levelPercent;

  /// The phone says it is actively charging.
  final bool isCharging;

  /// BatteryManager.EXTRA_STATUS.
  final int status;

  /// The system's own estimate of time to full in milliseconds, or -1.
  final int systemChargeTimeMs;

  bool get isPlugged => plugType != PlugType.none;

  /// Plugged in at 100%.
  bool get isFullState =>
      isPlugged &&
      (status == statusFull ||
          (status == statusNotCharging && levelPercent >= 100));

  /// Plugged in but the phone has stopped charging below 100%, usually to
  /// protect the battery.
  bool get pausedByPhone =>
      isPlugged && status == statusNotCharging && levelPercent < 100;

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
    this.chargeHeld = false,
    this.isFull = false,
    this.fullTimeFromSystem = false,
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

  /// Plugged in, but the phone has paused charging below 100%.
  final bool chargeHeld;

  /// Plugged in at 100%.
  final bool isFull;

  /// [minutesTo100] and the 90% and 100% forecast come from the system's estimate.
  final bool fullTimeFromSystem;

  bool get isPlugged =>
      isCharging || chargeHeld || isFull || plugType != PlugType.none;

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

/// Time multiplier for the 1% step centred on [midLevel], compared with
/// charging at the full rate. Phones hold their top current to about 80%, then
/// slow down, slowly to 90% and steeply to 100%. At [strength] 1 the average
/// multiplier is 1.7 for 80 to 90% and 3.3 for 90 to 100%, which matches typical
/// fast-charging curves; a gentler charger gets a gentler slowdown.
double taperMultiplier(double midLevel, double strength) {
  if (midLevel <= 80) return 1;
  if (midLevel <= 90) return 1 + 1.4 * strength * (midLevel - 80) / 10;
  return 1 + strength * (1.4 + 1.8 * (midLevel - 90) / 10);
}

/// How hard the slowdown above 80% hits: stronger the higher the charge rate
/// is compared with the battery size (1 is a 1C charge or faster).
double taperStrength(double capacityMah, double rateMa) =>
    (rateMa / capacityMah).clamp(0.25, 1.0);

/// Minutes to reach [targetPercent], allowing for charging to slow above 80%.
/// Below 80% this is the charge still needed divided by [currentMa]. Above 80%
/// it uses a typical slowdown curve scaled by [plateauMa], the highest current
/// seen in this charge, and by how far the current has already dropped.
/// Returns 0 if already there, null if it cannot be estimated.
double? minutesToTarget({
  required int levelPercent,
  required int targetPercent,
  required double? capacityMah,
  required double currentMa,
  double? plateauMa,
}) {
  if (levelPercent >= targetPercent) return 0;
  if (capacityMah == null || currentMa < _minUsableCurrentMa) return null;
  final atTaper = levelPercent >= 80;
  final base = atTaper
      ? math.max(plateauMa ?? currentMa, currentMa)
      : currentMa;
  final strength = taperStrength(capacityMah, base);
  var observedScale = 1.0;
  if (atTaper) {
    final modelNow = taperMultiplier(levelPercent + 0.5, strength);
    observedScale = ((base / currentMa) / modelNow).clamp(0.6, 2.0);
  }
  final minutesPerStep = capacityMah / 100 / base * 60;
  var total = 0.0;
  for (var level = levelPercent; level < targetPercent; level++) {
    var multiplier = taperMultiplier(level + 0.5, strength);
    if (level >= 80) multiplier *= observedScale;
    total += minutesPerStep * multiplier;
  }
  return total;
}

/// Exponential moving average; the first sample is returned unchanged.
double smooth(double? previous, double sample, {double alpha = 0.3}) =>
    previous == null ? sample : previous + alpha * (sample - previous);

/// Estimated time for each step in [forecastTargets] above [levelPercent].
/// Empty when the rate or capacity is unknown. When the system's own estimate
/// to full ([systemMinutesToFull]) is given, the 100% time is that estimate and
/// the 90% time keeps its share of the way from 80% to 100%.
List<ForecastStep> chargeForecast({
  required int levelPercent,
  required double? capacityMah,
  required double currentMa,
  required DateTime now,
  double? plateauMa,
  double? systemMinutesToFull,
}) {
  double? model(int target) => minutesToTarget(
    levelPercent: levelPercent,
    targetPercent: target,
    capacityMah: capacityMah,
    currentMa: currentMa,
    plateauMa: plateauMa,
  );
  final steps = <ForecastStep>[];
  final model80 = levelPercent < 80 ? model(80) : 0.0;
  final model100 = model(100);
  for (final target in forecastTargets) {
    if (target <= levelPercent) continue;
    var minutes = model(target);
    if (minutes == null || model80 == null || model100 == null) {
      return const [];
    }
    if (systemMinutesToFull != null && target > 80) {
      final total = math.max(systemMinutesToFull, model80);
      final span = model100 - model80;
      final share = span > 0 ? (minutes - model80) / span : 1.0;
      minutes = model80 + share * (total - model80);
    }
    steps.add(
      ForecastStep(target, now.add(Duration(seconds: (minutes * 60).round()))),
    );
  }
  return steps;
}

/// The system's estimate to full charge in minutes, or null when the phone does
/// not give one (it reports -1) or the value is implausible.
double? systemFullMinutes(int milliseconds) {
  if (milliseconds <= 0 || milliseconds > 24 * 60 * 60 * 1000) return null;
  final minutes = milliseconds / 60000;
  return minutes < 1 ? null : minutes;
}

/// Readings (2 seconds apart) of near-zero current while the phone says it is
/// charging, needed before treating it as a pause, about 30 seconds.
const int minHeldSamples = 15;

/// Below this current, in milliamps, a charge counts as stalled.
const double heldCurrentMa = 30;

/// Charging status but almost no current for a while between 75% and 100%:
/// the phone is holding the charge, as with adaptive charging.
bool isHeldByCurrent({
  required int levelPercent,
  required double smoothedCurrentMa,
  required int chargingSamples,
}) =>
    chargingSamples >= minHeldSamples &&
    levelPercent >= 75 &&
    levelPercent < 100 &&
    smoothedCurrentMa < heldCurrentMa;

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
  double? plateauMa,
  double? systemMinutesToFull,
  bool heldByCurrent = false,
}) {
  final time = now ?? DateTime.now();
  final full = s.isFullState;
  final held = !full && (s.pausedByPhone || (s.isCharging && heldByCurrent));
  final charging = s.isCharging && !held && !full;
  final capacity = capacityMah(s.chargeCounterUah, s.levelPercent);
  final readyDrain = !s.isPlugged && drain != null && drain.isReady
      ? drain
      : null;
  double? model(int target) => charging
      ? minutesToTarget(
          levelPercent: s.levelPercent,
          targetPercent: target,
          capacityMah: capacity,
          currentMa: smoothedCurrentMa,
          plateauMa: plateauMa,
        )
      : null;
  final minutes80 = model(80);
  var minutes100 = model(100);
  var fromSystem = false;
  if (charging && systemMinutesToFull != null && s.levelPercent < 100) {
    minutes100 = math.max(systemMinutesToFull, minutes80 ?? 0);
    fromSystem = true;
  }
  return BatteryStats(
    levelPercent: s.levelPercent,
    isCharging: charging,
    plugType: s.plugType,
    watts: charging ? watts(s.voltageMv, smoothedCurrentMa) : null,
    currentMa: charging ? smoothedCurrentMa : null,
    voltageV: s.voltageMv / 1000,
    temperatureC: s.temperatureTenthsC / 10,
    minutesTo80: minutes80,
    minutesTo100: minutes100,
    updatedAt: time,
    forecast: charging
        ? chargeForecast(
            levelPercent: s.levelPercent,
            capacityMah: capacity,
            currentMa: smoothedCurrentMa,
            now: time,
            plateauMa: plateauMa,
            systemMinutesToFull: systemMinutesToFull,
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
        !s.isPlugged &&
        drain != null &&
        !drain.isReady &&
        s.chargeCounterUah > 0,
    chargeHeld: held,
    isFull: full,
    fullTimeFromSystem: fromSystem,
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
  final String state;
  if (stats.isFull) {
    state = 'Full';
  } else if (stats.chargeHeld) {
    state = 'Paused';
  } else if (stats.isCharging) {
    state = (stats.watts ?? 0) >= fastChargeWatts
        ? 'Fast charging'
        : 'Charging';
  } else {
    return 'On battery';
  }
  return switch (stats.plugType) {
    PlugType.none || PlugType.unknown => state,
    final plug => '$state · ${plug.label}',
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
