class AppConstants {
  AppConstants._();

  static const String appName = 'CampConnect';
  static const String appVersion = '1.0.0';

  // Camp code format: CAMP-XXXX (4 alphanumeric chars)
  static const String codePrefix = 'CAMP';
  static const int codeLength = 4;
  static final RegExp codeRegex = RegExp(r'^CAMP-[A-Z0-9]{4}$');

  // Code generation charset
  static const String codeCharset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // Default teams
  static const List<String> defaultTeams = ['red', 'blue', 'green', 'yellow'];

  // Firestore collection paths
  static const String usersCollection = 'users';
  static const String campsCollection = 'camps';
  static const String teamsSubcollection = 'teams';
  static const String pointsHistorySubcollection = 'pointsHistory';
  static const String locationsSubcollection = 'locations';
  static const String announcementsSubcollection = 'announcements';
  static const String emergencyAlertsSubcollection = 'emergencyAlerts';
  static const String codesSubcollection = 'codes';

  // Default camp location (Apuseni Mountains)
  static const double defaultCampLatitude = 46.47675086248586;
  static const double defaultCampLongitude = 22.749784950344342;
  static const double defaultMapZoom = 14.0;

  // User roles
  static const String roleGuide = 'guide';
  static const String roleKid = 'kid';

  // Settings keys
  static const String keyLanguage = 'language';
  static const String keyTheme = 'theme';
  static const String keyLlmEnabled = 'llmEnabled';
  static const String keyLastCampId = 'lastCampId';

  // Supported languages
  static const String languageRomanian = 'ro';
  static const String languageHungarian = 'hu';
}
