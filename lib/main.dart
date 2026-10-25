import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'battery_reader.dart';
import 'battery_stats.dart';
import 'theme.dart';
import 'widgets.dart';

void main() {
  runApp(WattsApp(stats: batteryStatsStream()));
}

class WattsApp extends StatelessWidget {
  const WattsApp({super.key, required this.stats});

  final Stream<BatteryStats> stats;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Watts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'RobotoFlex',
        colorSchemeSeed: Colors.green,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'RobotoFlex',
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
      ),
      // Large system text sizes are honoured up to 1.3x, beyond which the forecast row would not fit.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1,
        maxScaleFactor: 1.3,
        child: child!,
      ),
      home: BatteryScreen(stats: stats),
    );
  }
}

class BatteryScreen extends StatelessWidget {
  const BatteryScreen({super.key, required this.stats});

  final Stream<BatteryStats> stats;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BatteryStats>(
      stream: stats,
      builder: (context, snapshot) {
        final s = snapshot.data;
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text('Could not read battery: ${snapshot.error}'),
            ),
          );
        }
        if (s == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _Sky(stats: s);
      },
    );
  }
}

/// Full-screen gradient background plus the scrolling content.
class _Sky extends StatelessWidget {
  const _Sky({required this.stats});

  final BatteryStats stats;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final colors = WattsColors.of(brightness, charging: stats.isPlugged);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.skyBottom,
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [colors.skyTop, colors.skyMid, colors.skyBottom],
              stops: const [0, 0.34, 0.7],
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: _children(context, colors),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _children(BuildContext context, WattsColors colors) {
    final s = stats;
    final use24h = MediaQuery.alwaysUse24HourFormatOf(context);
    String? eta(DateTime? t, String prefix, {bool suffix = false}) => t == null
        ? null
        : '$prefix ${formatClock(t, use24h: use24h, suffix: suffix)}';
    final (v80, u80) = durationParts(s.minutesTo80);
    final (v100, u100) = durationParts(s.minutesTo100);

    final tempVoltage = Row(
      children: [
        Expanded(
          child: StatTile(
            colors: colors,
            label: 'Temperature',
            icon: Icons.thermostat_rounded,
            value: s.temperatureC.toStringAsFixed(1),
            unit: '°C',
            size: 32,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            colors: colors,
            label: 'Voltage',
            icon: Icons.battery_full_rounded,
            value: s.voltageV.toStringAsFixed(2),
            unit: 'V',
            size: 32,
          ),
        ),
      ],
    );

    final items = <Widget>[
      _Header(colors: colors, stats: s),
      _Hero(colors: colors, stats: s, use24h: use24h),
      if (s.isCharging) ...[
        if (s.forecast.isNotEmpty)
          ForecastCard(colors: colors, stats: s, use24h: use24h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatTile(
                colors: colors,
                label: 'Time to 80%',
                icon: Icons.schedule_rounded,
                value: v80,
                unit: u80,
                caption: eta(s.eta80, 'Ready about'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                colors: colors,
                label: 'Time to 100%',
                icon: Icons.schedule_rounded,
                value: v100,
                unit: u100,
                caption: eta(s.eta100, 'Full about'),
              ),
            ),
          ],
        ),
        TemperatureCard(colors: colors, celsius: s.temperatureC),
        Row(
          children: [
            Expanded(
              child: StatTile(
                colors: colors,
                label: 'Current',
                icon: Icons.show_chart_rounded,
                value: formatMa(s.currentMa ?? 0),
                unit: 'mA',
                size: 32,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                colors: colors,
                label: 'Voltage',
                icon: Icons.battery_full_rounded,
                value: s.voltageV.toStringAsFixed(2),
                unit: 'V',
                size: 32,
              ),
            ),
          ],
        ),
        PowerChartCard(colors: colors, stats: s),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            s.fullTimeFromSystem
                ? 'Time to 100% comes from your phone. Charging slows above 80%.'
                : 'Times above 80% use a typical charging curve, so they are approximate.',
            style: wattsText(12, color: colors.on2, height: 1.5),
          ),
        ),
      ] else if (s.isPlugged) ...[
        _NoticeCard(
          colors: colors,
          icon: s.isFull ? Icons.battery_full_rounded : Icons.pause_rounded,
          title: s.isFull ? 'Fully charged' : 'Charging is paused',
          body: s.isFull ? 'You can unplug.' : 'Your phone is holding the charge, often to protect the battery.',
        ),
        tempVoltage,
      ] else ...[
        if (s.minutesLeft != null && s.drainMa != null)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatTile(
                    colors: colors,
                    label: 'Time left',
                    icon: Icons.hourglass_bottom_rounded,
                    value: timeLeftParts(s.minutesLeft).$1,
                    unit: timeLeftParts(s.minutesLeft).$2,
                    caption: eta(s.emptyAt, 'Empty about', suffix: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    colors: colors,
                    label: 'Drain',
                    icon: Icons.trending_down_rounded,
                    value: formatMa(s.drainMa!),
                    unit: 'mA',
                    caption: 'Recent average',
                  ),
                ),
              ],
            ),
          ),
        _NoticeCard(
          colors: colors,
          icon: Icons.bolt_rounded,
          title: 'Plug in to start',
          body:
              'Power, current and time to 80% and 100% appear while charging.',
        ),
        tempVoltage,
        if (s.minutesLeft != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Time left assumes you keep using your phone the way you are now, '
              'so it changes as you use it.',
              style: wattsText(12, color: colors.on2, height: 1.5),
            ),
          ),
      ],
    ];
    return [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) SizedBox(height: i == 1 ? 4 : 12),
        items[i],
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.colors, required this.stats});

  final WattsColors colors;
  final BatteryStats stats;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Watts', style: wattsText(17, weight: 500, color: colors.on)),
          Row(
            children: [
              if (stats.isCharging) ...[
                Icon(Icons.bolt_rounded, size: 18, color: colors.accent),
                const SizedBox(width: 4),
              ],
              Text(
                chargingLabel(stats),
                style: wattsText(
                  13,
                  weight: 500,
                  color: stats.isCharging ? colors.accent : colors.on2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.colors,
    required this.stats,
    required this.use24h,
  });

  final WattsColors colors;
  final BatteryStats stats;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final charging = stats.isCharging;
    final number = charging
        ? formatPower(stats.watts ?? 0)
        : '${stats.levelPercent}';
    final unit = charging ? 'W' : '%';
    final eta100 = stats.eta100;
    final left = stats.minutesLeft;
    final String meta;
    if (stats.isFull) {
      meta = 'Fully charged';
    } else if (stats.chargeHeld) {
      meta = 'Charging paused';
    } else if (!charging) {
      meta = left != null
          ? timeLeftLabel(left)
          : stats.estimatingTimeLeft
          ? 'Not charging · estimating time left…'
          : 'Not charging';
    } else if (stats.levelPercent >= 100) {
      meta = 'Fully charged';
    } else if (eta100 == null) {
      meta = '${stats.levelPercent}%';
    } else {
      meta =
          '${stats.levelPercent}% · full about ${formatClock(eta100, use24h: use24h)}';
    }
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: -10,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [colors.glow, colors.glow.withValues(alpha: 0)],
                stops: const [0, 0.68],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: wattsText(
                        132,
                        weight: 200,
                        color: colors.on,
                        letterSpacing: -5,
                        height: 1.05,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 18, left: 4),
                      child: Text(
                        unit,
                        style: wattsText(40, weight: 300, color: colors.accent),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                charging ? 'Charging power' : 'Battery level',
                style: wattsText(19, color: colors.on),
              ),
              const SizedBox(height: 4),
              Text(meta, style: wattsText(14, color: colors.on2)),
              const SizedBox(height: 20),
              LevelBar(
                colors: colors,
                percent: stats.levelPercent,
                markAt: charging ? 80 : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.body,
  });

  final WattsColors colors;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return WattsCard(
      colors: colors,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.chip,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: colors.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: wattsText(17, weight: 500, color: colors.on),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: wattsText(13, color: colors.on2, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
