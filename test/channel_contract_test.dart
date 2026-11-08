import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:watts/battery_stats.dart';

/// MainActivity.kt can't run in these tests, so check that what it sends and
/// what the Dart side reads still line up.
void main() {
  final kotlin = File(
    'android/app/src/main/kotlin/com/markprovan/watts/MainActivity.kt',
  ).readAsStringSync();
  final reader = File('lib/battery_reader.dart').readAsStringSync();
  final stats = File('lib/battery_stats.dart').readAsStringSync();

  final sent = {
    for (final m in RegExp(r'"(\w+)"\s+to\s').allMatches(kotlin)) m[1]!,
  };
  final read = {
    for (final m in RegExp(r"map\['(\w+)'\]").allMatches(stats)) m[1]!,
  };

  test('Kotlin and Dart use the same channel and method', () {
    final kotlinChannel = RegExp(
      r'MethodChannel\([^,]+,\s*"([^"]+)"\)',
    ).firstMatch(kotlin)![1];
    final dartChannel = RegExp(
      r"MethodChannel\('([^']+)'\)",
    ).firstMatch(reader)![1];
    expect(kotlinChannel, dartChannel);
    expect(kotlin, contains('call.method == "snapshot"'));
    expect(reader, contains("'snapshot'"));
  });

  test('the Kotlin snapshot sends every key the Dart side reads', () {
    expect(read, isNotEmpty);
    expect(sent, containsAll(read));
  });

  test('the Kotlin snapshot sends nothing the Dart side ignores', () {
    expect(read, containsAll(sent));
  });

  test('a reply with exactly the Kotlin keys parses', () {
    final reply = <Object?, Object?>{for (final key in sent) key: 1};
    final s = BatterySnapshot.fromMap(reply);
    expect(s.levelPercent, 1);
  });
}
