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
    default:
      return name;
  }
}
