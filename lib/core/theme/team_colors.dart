import 'package:flutter/material.dart';

class TeamColors {
  TeamColors._();

  static const Map<String, Color> colors = {
    'red': Color(0xFFE53935),
    'blue': Color(0xFF1E88E5),
    'green': Color(0xFF43A047),
    'yellow': Color(0xFFFDD835),
    'orange': Color(0xFFFB8C00),
    'purple': Color(0xFF8E24AA),
    'pink': Color(0xFFD81B60),
    'teal': Color(0xFF00897B),
  };

  static const Map<String, Map<String, String>> _localizedNames = {
    'ro': {
      'red': 'Rosu',
      'blue': 'Albastru',
      'green': 'Verde',
      'yellow': 'Galben',
      'orange': 'Portocaliu',
      'purple': 'Mov',
      'pink': 'Roz',
      'teal': 'Turcoaz',
    },
    'hu': {
      'red': 'Piros',
      'blue': 'Kek',
      'green': 'Zold',
      'yellow': 'Sarga',
      'orange': 'Narancs',
      'purple': 'Lila',
      'pink': 'Rozsaszin',
      'teal': 'Turkiz',
    },
  };

  static Color getColor(String team) {
    return colors[team.toLowerCase()] ?? Colors.grey;
  }

  static Color getOnColor(String team) {
    final color = getColor(team);
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  static List<String> get defaultTeams => const ['red', 'blue', 'green', 'yellow'];

  /// Returns the localized team display name for the given language.
  static String localizedName(String team, String language) {
    final names = _localizedNames[language] ?? _localizedNames['ro']!;
    return names[team.toLowerCase()] ?? team;
  }

  /// Fallback display name (English-style) — avoid using this in UI.
  static String displayName(String team) {
    return '${team[0].toUpperCase()}${team.substring(1)}';
  }
}
