import 'package:flutter/material.dart';

import 'battery_reader.dart';
import 'battery_stats.dart';

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
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
        useMaterial3: true,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Watts')),
      body: StreamBuilder<BatteryStats>(
        stream: stats,
        builder: (context, snapshot) {
          final s = snapshot.data;
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not read battery: ${snapshot.error}'),
            );
          }
          if (s == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return _StatsList(stats: s);
        },
      ),
    );
  }
}

class _StatsList extends StatelessWidget {
  const _StatsList({required this.stats});

  final BatteryStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('${stats.levelPercent}%', style: theme.textTheme.displayLarge),
        Text(
          stats.isCharging
              ? 'Charging · ${stats.plugType.label}'
              : 'Not charging',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        _StatCard(
          'Charging power',
          stats.watts == null ? '—' : '${stats.watts!.toStringAsFixed(1)} W',
        ),
        _StatCard('Time to 80%', formatDuration(stats.minutesTo80)),
        _StatCard('Time to 100%', formatDuration(stats.minutesTo100)),
        _StatCard(
          'Battery temperature',
          '${stats.temperatureC.toStringAsFixed(1)} °C',
        ),
        _StatCard(
          'Current',
          stats.currentMa == null
              ? '—'
              : '${stats.currentMa!.toStringAsFixed(0)} mA',
        ),
        _StatCard('Voltage', '${stats.voltageV.toStringAsFixed(2)} V'),
        const SizedBox(height: 8),
        Text(
          'Time estimates assume the current charging rate stays constant. '
          'Charging usually slows above 80%, so time to 100% is optimistic.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodyLarge),
            Text(value, style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
