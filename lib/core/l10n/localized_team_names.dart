import 'package:camp_connect/l10n/app_localizations.g.dart';

/// Team names are stored data, so switching the app language cannot rename
/// them server-side. For teams that still carry a recognized default color
/// name (in any supported language), display it in the current app language.
/// Custom names ("Dragons") pass through untouched.
String localizedTeamName(AppL10n l10n, String name) {
  switch (name.trim().toLowerCase()) {
    case 'red':
    case 'roșu':
    case 'rosu':
    case 'piros':
      return l10n.defaultTeamRed;
    case 'blue':
    case 'albastru':
    case 'kék':
    case 'kek':
      return l10n.defaultTeamBlue;
    case 'green':
    case 'verde':
    case 'zöld':
    case 'zold':
      return l10n.defaultTeamGreen;
    case 'yellow':
    case 'galben':
    case 'sárga':
    case 'sarga':
      return l10n.defaultTeamYellow;
    case 'pink':
    case 'roz':
    case 'rózsaszín':
    case 'rozsaszin':
      return l10n.teamColorPink;
    case 'purple':
    case 'mov':
    case 'violet':
    case 'lila':
      return l10n.teamColorPurple;
    case 'indigo':
    case 'indigó':
      return l10n.teamColorIndigo;
    case 'cyan':
    case 'cian':
    case 'cián':
      return l10n.teamColorCyan;
    case 'teal':
    case 'turcoaz':
    case 'türkiz':
    case 'turkiz':
      return l10n.teamColorTeal;
    case 'lime':
      return l10n.teamColorLime;
    case 'orange':
    case 'portocaliu':
    case 'narancs':
      return l10n.teamColorOrange;
    case 'brown':
    case 'maro':
    case 'barna':
      return l10n.teamColorBrown;
    case 'grey':
    case 'gray':
    case 'gri':
    case 'szürke':
    case 'szurke':
      return l10n.teamColorGrey;
    default:
      return name;
  }
}

/// The localized display name for a preset palette colour, keyed by its hex.
/// Used to auto-fill a team's name field when a guide picks a colour, so the
/// default name follows the app language. Returns '' for non-preset hexes.
String localizedColorNameForHex(AppL10n l10n, String hex) {
  switch (hex.trim().toUpperCase()) {
    case '#E53935':
      return l10n.defaultTeamRed;
    case '#1E88E5':
      return l10n.defaultTeamBlue;
    case '#43A047':
      return l10n.defaultTeamGreen;
    case '#FDD835':
      return l10n.defaultTeamYellow;
    case '#D81B60':
      return l10n.teamColorPink;
    case '#8E24AA':
      return l10n.teamColorPurple;
    case '#3949AB':
      return l10n.teamColorIndigo;
    case '#00ACC1':
      return l10n.teamColorCyan;
    case '#00897B':
      return l10n.teamColorTeal;
    case '#C0CA33':
      return l10n.teamColorLime;
    case '#FB8C00':
      return l10n.teamColorOrange;
    case '#6D4C41':
      return l10n.teamColorBrown;
    case '#757575':
      return l10n.teamColorGrey;
    default:
      return '';
  }
}
