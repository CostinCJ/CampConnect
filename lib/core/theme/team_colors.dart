import 'package:flutter/material.dart';

/// Preset colors offered when creating/editing a team. Teams now store their own
/// `colorHex`, so this is only the palette + hex helpers — no name maps.
class TeamColors {
  TeamColors._();

  /// Ordered preset palette (hex strings) shown in the team color picker.
  /// A broad set of popular colours so guides can pick whatever fits a camp;
  /// each has a translatable name (see [hexForColorName] / localizedColorName).
  static const List<String> presetHexes = [
    '#E53935', // red
    '#D81B60', // pink
    '#8E24AA', // purple
    '#3949AB', // indigo
    '#1E88E5', // blue
    '#00ACC1', // cyan
    '#00897B', // teal
    '#43A047', // green
    '#C0CA33', // lime
    '#FDD835', // yellow
    '#FB8C00', // orange
    '#6D4C41', // brown
    '#757575', // grey
  ];

  /// First preset color not already used by another team, so every new team
  /// starts visually distinct. Falls back to cycling through the palette by
  /// [fallbackIndex] once all presets are taken.
  static String firstUnusedPresetHex(Iterable<String> usedHexes,
      {int fallbackIndex = 0}) {
    final used = usedHexes.map((h) => h.toUpperCase()).toSet();
    for (final hex in presetHexes) {
      if (!used.contains(hex.toUpperCase())) return hex;
    }
    return presetHexes[fallbackIndex % presetHexes.length];
  }

  static Color colorFromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF9E9E9E);
  }

  /// The grey the app once wrote as a read-side default for teams that had
  /// no color. The pickers only offer [presetHexes], so a stored grey can
  /// only be legacy data — never a deliberate choice.
  static const int _legacyGreyArgb = 0xFF9E9E9E;

  /// Maps a color-word team name (en/ro/hu) to its preset hex, so legacy
  /// teams named "Green"/"Verde"/"Zöld" heal to the color they are named
  /// after rather than an arbitrary one.
  static String? hexForColorName(String name) {
    switch (name.trim().toLowerCase()) {
      case 'red':
      case 'roșu':
      case 'rosu':
      case 'piros':
        return '#E53935';
      case 'blue':
      case 'albastru':
      case 'kék':
      case 'kek':
        return '#1E88E5';
      case 'green':
      case 'verde':
      case 'zöld':
      case 'zold':
        return '#43A047';
      case 'yellow':
      case 'galben':
      case 'sárga':
      case 'sarga':
        return '#FDD835';
      case 'orange':
      case 'portocaliu':
      case 'narancs':
        return '#FB8C00';
      case 'purple':
      case 'mov':
      case 'violet':
      case 'lila':
        return '#8E24AA';
      case 'pink':
      case 'roz':
      case 'rózsaszín':
      case 'rozsaszin':
        return '#D81B60';
      case 'teal':
      case 'turcoaz':
      case 'türkiz':
      case 'turkiz':
        return '#00897B';
      case 'indigo':
      case 'indigó':
        return '#3949AB';
      case 'cyan':
      case 'cian':
      case 'cián':
        return '#00ACC1';
      case 'lime':
        return '#C0CA33';
      case 'brown':
      case 'maro':
      case 'barna':
        return '#6D4C41';
      case 'grey':
      case 'gray':
      case 'gri':
      case 'szürke':
      case 'szurke':
        return '#757575';
      default:
        return null;
    }
  }

  /// Resolves a team's color: parses [colorHex] when valid; otherwise infers
  /// it from a color-word [name] (or [teamId]); otherwise derives a stable
  /// preset from [teamId] — so legacy teams saved without a colorHex (or
  /// with the legacy grey default) always get a sensible vivid color.
  static Color forTeam(String teamId, String colorHex, [String name = '']) {
    final h = colorHex.replaceFirst('#', '');
    final parsed = int.tryParse('FF$h', radix: 16);
    if (parsed != null && h.length == 6 && parsed != _legacyGreyArgb) {
      return Color(parsed);
    }
    final named = hexForColorName(name) ?? hexForColorName(teamId);
    if (named != null) return colorFromHex(named);
    var hash = 0;
    for (final unit in teamId.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    return colorFromHex(presetHexes[hash % presetHexes.length]);
  }

  static String hexFromColor(Color color) {
    // toARGB32 gives 0xAARRGGBB; drop alpha.
    return '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  static Color onColor(Color color) =>
      color.computeLuminance() > 0.5 ? Colors.black : Colors.white;

  /// A readable variant of [color] for use as TEXT on the app's surfaces:
  /// light team colors (yellow) get darkened in light mode, dark ones get
  /// lightened in dark mode, so the hue stays recognizable but legible.
  static Color emphasis(Color color, Brightness brightness) {
    final hsl = HSLColor.fromColor(color);
    if (brightness == Brightness.light && hsl.lightness > 0.45) {
      return hsl.withLightness(0.38).toColor();
    }
    if (brightness == Brightness.dark && hsl.lightness < 0.55) {
      return hsl.withLightness(0.65).toColor();
    }
    return color;
  }
}
