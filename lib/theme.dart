import 'package:flutter/material.dart';

/// Roboto Flex is bundled as a variable font (wght 200 to 700), so any weight in that range works.
TextStyle wattsText(
  double size, {
  double weight = 400,
  Color? color,
  double? letterSpacing,
  double? height,
}) {
  return TextStyle(
    fontFamily: 'RobotoFlex',
    fontSize: size,
    fontWeight: FontWeight.values[(weight / 100).round().clamp(1, 9) - 1],
    fontVariations: [FontVariation('wght', weight)],
    fontFeatures: const [FontFeature.tabularFigures()],
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

/// Colours for one screen. The "sky" gradient follows the charging state and the system brightness.
class WattsColors {
  const WattsColors({
    required this.skyTop,
    required this.skyMid,
    required this.skyBottom,
    required this.glow,
    required this.card,
    required this.edge,
    required this.on,
    required this.on2,
    required this.accent,
    required this.chip,
    required this.track,
    required this.fill1,
    required this.fill2,
    required this.thumb,
    required this.tempCool,
    required this.tempMid,
    required this.tempWarm,
    required this.warmText,
    required this.hotText,
  });

  final Color skyTop, skyMid, skyBottom, glow;
  final Color card, edge, on, on2, accent, chip, track;
  final Color fill1, fill2, thumb;
  final Color tempCool, tempMid, tempWarm, warmText, hotText;

  static WattsColors of(Brightness brightness, {required bool charging}) {
    final dark = brightness == Brightness.dark;
    if (charging) return dark ? _chargingDark : _chargingLight;
    return dark ? _batteryDark : _batteryLight;
  }

  Color statusColor(String status) => switch (status) {
    'Warm' => warmText,
    'Hot' => hotText,
    _ => accent,
  };

  static const _chargingLight = WattsColors(
    skyTop: Color(0xFFBFE5D2),
    skyMid: Color(0xFFDDF1E5),
    skyBottom: Color(0xFFF5FAF4),
    glow: Color(0xD9FFFFFF),
    card: Color(0xADFFFFFF),
    edge: Color(0xE6FFFFFF),
    on: Color(0xFF12261D),
    on2: Color(0xFF46594F),
    accent: Color(0xFF0B6B4A),
    chip: Color(0xFFD8EFE2),
    track: Color(0x1A12261D),
    fill1: Color(0xFF5CCB97),
    fill2: Color(0xFF0F9D6A),
    thumb: Color(0xFFFFFFFF),
    tempCool: Color(0xFF7CC4DE),
    tempMid: Color(0xFF8ED9AE),
    tempWarm: Color(0xFFF2B27A),
    warmText: Color(0xFF9A4F00),
    hotText: Color(0xFFB3261E),
  );

  static const _chargingDark = WattsColors(
    skyTop: Color(0xFF0E4A3B),
    skyMid: Color(0xFF0B2A22),
    skyBottom: Color(0xFF08130F),
    glow: Color(0x386EE0AC),
    card: Color(0x12FFFFFF),
    edge: Color(0x14FFFFFF),
    on: Color(0xFFE4F3EA),
    on2: Color(0xFFA6BDB1),
    accent: Color(0xFF6EE0AC),
    chip: Color(0x296EE0AC),
    track: Color(0x1FFFFFFF),
    fill1: Color(0xFF6EE0AC),
    fill2: Color(0xFF2FB985),
    thumb: Color(0xFF0B2A22),
    tempCool: Color(0xFF5FB0CB),
    tempMid: Color(0xFF6EE0AC),
    tempWarm: Color(0xFFF0A867),
    warmText: Color(0xFFFFB77C),
    hotText: Color(0xFFFFB4AB),
  );

  static const _batteryLight = WattsColors(
    skyTop: Color(0xFFC9DDE8),
    skyMid: Color(0xFFE3EEF4),
    skyBottom: Color(0xFFF5F9FB),
    glow: Color(0xD9FFFFFF),
    card: Color(0xB3FFFFFF),
    edge: Color(0xE6FFFFFF),
    on: Color(0xFF14232B),
    on2: Color(0xFF475963),
    accent: Color(0xFF1F6A85),
    chip: Color(0xFFDCEBF2),
    track: Color(0x1A14232B),
    fill1: Color(0xFF7FC3DB),
    fill2: Color(0xFF2E8FB3),
    thumb: Color(0xFFFFFFFF),
    tempCool: Color(0xFF7CC4DE),
    tempMid: Color(0xFF8ED9AE),
    tempWarm: Color(0xFFF2B27A),
    warmText: Color(0xFF9A4F00),
    hotText: Color(0xFFB3261E),
  );

  static const _batteryDark = WattsColors(
    skyTop: Color(0xFF123244),
    skyMid: Color(0xFF0B1C27),
    skyBottom: Color(0xFF081117),
    glow: Color(0x387FC8E3),
    card: Color(0x12FFFFFF),
    edge: Color(0x14FFFFFF),
    on: Color(0xFFE2EEF4),
    on2: Color(0xFFA6BCC8),
    accent: Color(0xFF7FC8E3),
    chip: Color(0x297FC8E3),
    track: Color(0x1FFFFFFF),
    fill1: Color(0xFF7FC8E3),
    fill2: Color(0xFF3A9BC0),
    thumb: Color(0xFF0B1C27),
    tempCool: Color(0xFF5FB0CB),
    tempMid: Color(0xFF6EE0AC),
    tempWarm: Color(0xFFF0A867),
    warmText: Color(0xFFFFB77C),
    hotText: Color(0xFFFFB4AB),
  );
}
