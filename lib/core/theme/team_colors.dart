import 'package:flutter/material.dart';

/// Preset colors offered when creating/editing a team. Teams now store their own
/// `colorHex`, so this is only the palette + hex helpers — no name maps.
class TeamColors {
  TeamColors._();

  /// Ordered preset palette (hex strings) shown in the team color picker.
  static const List<String> presetHexes = [
    '#E53935', // red
    '#1E88E5', // blue
    '#43A047', // green
    '#FDD835', // yellow
    '#FB8C00', // orange
    '#8E24AA', // purple
    '#D81B60', // pink
    '#00897B', // teal
  ];

  static Color colorFromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF9E9E9E);
  }

  static String hexFromColor(Color color) {
    // toARGB32 gives 0xAARRGGBB; drop alpha.
    return '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color onColor(Color color) =>
      color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
