import 'package:flutter/material.dart';

import 'battery_stats.dart';
import 'theme.dart';

const _cardRadius = 28.0;

class WattsCard extends StatelessWidget {
  const WattsCard({
    super.key,
    required this.colors,
    required this.child,
    this.padding,
  });

  final WattsColors colors;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: colors.edge),
      ),
      child: child,
    );
  }
}

/// Small round icon followed by a label, the heading of every card.
class CardLabel extends StatelessWidget {
  const CardLabel(this.label, this.icon, {super.key, required this.colors});

  final String label;
  final IconData icon;
  final WattsColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: colors.chip, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: colors.accent),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            style: wattsText(13, weight: 500, color: colors.on2),
          ),
        ),
      ],
    );
  }
}

/// Large thin number with a small unit, scaled down if it does not fit.
class StatValue extends StatelessWidget {
  const StatValue(
    this.value,
    this.unit, {
    super.key,
    required this.colors,
    this.size = 44,
  });

  final String value;
  final String unit;
  final WattsColors colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: wattsText(
                size,
                weight: 300,
                color: colors.on,
                letterSpacing: -1,
                height: 1.1,
              ),
            ),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(unit, style: wattsText(15, color: colors.on2)),
            ],
          ],
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.colors,
    required this.label,
    required this.icon,
    required this.value,
    required this.unit,
    this.caption,
    this.size = 44,
  });

  final WattsColors colors;
  final String label;
  final IconData icon;
  final String value;
  final String unit;
  final String? caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    return WattsCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardLabel(label, icon, colors: colors),
          const SizedBox(height: 10),
          StatValue(value, unit, colors: colors, size: size),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(caption!, style: wattsText(13, color: colors.on2)),
          ],
        ],
      ),
    );
  }
}

/// Battery bar with an optional marker, like a slim progress track.
class LevelBar extends StatelessWidget {
  const LevelBar({
    super.key,
    required this.colors,
    required this.percent,
    this.markAt,
  });

  final WattsColors colors;
  final int percent;
  final int? markAt;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          return Column(
            children: [
              SizedBox(
                height: 12,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: colors.track,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (percent / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            colors: [colors.fill1, colors.fill2],
                          ),
                        ),
                      ),
                    ),
                    if (markAt != null)
                      Positioned(
                        left: width * markAt! / 100 - 1,
                        top: -3,
                        child: Container(
                          width: 2,
                          height: 18,
                          decoration: BoxDecoration(
                            color: colors.on,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (markAt != null) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 16,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        child: Text(
                          '0%',
                          style: wattsText(12, color: colors.on2),
                        ),
                      ),
                      Positioned(
                        left: width * markAt! / 100 - 20,
                        width: 40,
                        child: Text(
                          '$markAt%',
                          textAlign: TextAlign.center,
                          style: wattsText(12, weight: 500, color: colors.on),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        child: Text(
                          '100%',
                          style: wattsText(12, color: colors.on2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Row of small battery pills with an estimated clock time above each one.
class ForecastCard extends StatelessWidget {
  const ForecastCard({
    super.key,
    required this.colors,
    required this.stats,
    required this.use24h,
  });

  final WattsColors colors;
  final BatteryStats stats;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final columns = <Widget>[
      _ForecastColumn(colors: colors, time: 'Now', percent: stats.levelPercent),
      for (final step in stats.forecast)
        _ForecastColumn(
          colors: colors,
          time: formatClock(step.eta, use24h: use24h),
          percent: step.percent,
          highlight: step.percent == 80,
        ),
    ];
    return WattsCard(
      colors: colors,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: CardLabel(
              'Charge forecast',
              Icons.schedule_rounded,
              colors: colors,
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [for (final c in columns) Expanded(child: c)]),
        ],
      ),
    );
  }
}

class _ForecastColumn extends StatelessWidget {
  const _ForecastColumn({
    required this.colors,
    required this.time,
    required this.percent,
    this.highlight = false,
  });

  final WattsColors colors;
  final String time;
  final int percent;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final labelColor = highlight ? colors.accent : colors.on2;
    return Semantics(
      label: '$percent percent at $time',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: highlight ? colors.chip : null,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Text(
              time,
              style: wattsText(
                12,
                weight: highlight ? 500 : 400,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 30,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: highlight
                    ? colors.accent.withValues(alpha: 0.16)
                    : colors.track,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: (percent / 100).clamp(0.0, 1.0),
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [colors.fill2, colors.fill1],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$percent%',
              style: wattsText(
                13,
                weight: 500,
                color: highlight ? colors.accent : colors.on,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TemperatureCard extends StatelessWidget {
  const TemperatureCard({
    super.key,
    required this.colors,
    required this.celsius,
  });

  final WattsColors colors;
  final double celsius;

  @override
  Widget build(BuildContext context) {
    final status = tempStatus(celsius);
    return WattsCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CardLabel(
                'Battery temperature',
                Icons.thermostat_rounded,
                colors: colors,
              ),
              Text(
                status.label,
                style: wattsText(
                  13,
                  weight: 500,
                  color: colors.statusColor(status.label),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatValue(celsius.toStringAsFixed(1), '°C', colors: colors),
              const SizedBox(width: 18),
              Expanded(
                child: _TempBar(colors: colors, celsius: celsius),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TempBar extends StatelessWidget {
  const _TempBar({required this.colors, required this.celsius});

  final WattsColors colors;
  final double celsius;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final x = box.maxWidth * tempBarFraction(celsius);
        return Column(
          children: [
            SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 4,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          colors: [
                            colors.tempCool,
                            colors.tempMid,
                            colors.tempWarm,
                          ],
                          stops: const [0, 0.5, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: x - 8,
                    top: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors.thumb,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.on, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('15°', style: wattsText(12, color: colors.on2)),
                Text('45°', style: wattsText(12, color: colors.on2)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class PowerChartCard extends StatelessWidget {
  const PowerChartCard({super.key, required this.colors, required this.stats});

  final WattsColors colors;
  final BatteryStats stats;

  @override
  Widget build(BuildContext context) {
    final history = downsample(stats.powerHistory, 60);
    final peak = stats.peakWatts;
    return WattsCard(
      colors: colors,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Power, last 5 min',
                style: wattsText(13, weight: 500, color: colors.on2),
              ),
              if (peak != null)
                Text.rich(
                  TextSpan(
                    text: 'Peak ',
                    style: wattsText(13, color: colors.on2),
                    children: [
                      TextSpan(
                        text: '${formatPower(peak)} W',
                        style: wattsText(13, weight: 500, color: colors.on),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            width: double.infinity,
            child: history.length < 2
                ? Center(
                    child: Text(
                      'Collecting data…',
                      style: wattsText(13, color: colors.on2),
                    ),
                  )
                : Semantics(
                    label:
                        'Power over the last five minutes, peak ${formatPower(peak ?? 0)} watts',
                    child: CustomPaint(painter: _PowerPainter(colors, history)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PowerPainter extends CustomPainter {
  _PowerPainter(this.colors, this.values);

  final WattsColors colors;
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 6.0;
    final maxValue =
        values.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity) *
        1.05;
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          pad + (size.width - 2 * pad) * i / (values.length - 1),
          size.height - pad - (size.height - 2 * pad) * values[i] / maxValue,
        ),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final mid = (points[i - 1].dx + points[i].dx) / 2;
      line.cubicTo(
        mid,
        points[i - 1].dy,
        mid,
        points[i].dy,
        points[i].dx,
        points[i].dy,
      );
    }
    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colors.fill2.withValues(alpha: 0.32),
            colors.fill2.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = colors.fill2,
    );
    canvas.drawCircle(points.last, 5, Paint()..color = colors.thumb);
    canvas.drawCircle(
      points.last,
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = colors.fill2,
    );
  }

  @override
  bool shouldRepaint(_PowerPainter old) =>
      old.values != values || old.colors != colors;
}
