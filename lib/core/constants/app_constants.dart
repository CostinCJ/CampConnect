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

  // Default teams pre-filled when creating a camp (name + colorHex). Guides can
  // rename, recolor, add, or remove them before creating the session.
  static const List<({String name, String colorHex})> defaultTeams = [
    (name: 'Roșu', colorHex: '#E53935'),
    (name: 'Albastru', colorHex: '#1E88E5'),
    (name: 'Verde', colorHex: '#43A047'),
    (name: 'Galben', colorHex: '#FDD835'),
  ];

  // Firestore collection paths
  static const String usersCollection = 'users';
  static const String campsCollection = 'camps';
  static const String teamsSubcollection = 'teams';
  static const String pointsHistorySubcollection = 'pointsHistory';
  static const String locationsCollection = 'locations';
  static const String sessionLocationsSubcollection = 'sessionLocations';
  static const String announcementsSubcollection = 'announcements';
  static const String emergencyAlertsSubcollection = 'emergencyAlerts';
  static const String codesSubcollection = 'codes';

  // Map tiles — keyed provider (OSM public tiles forbid app distribution + caching).
  // Provide via --dart-define=MAPTILER_KEY=xxxx so the key is not committed.
  // The /256/ path serves 256px tiles, matching flutter_map's default tile size.
  static const String maptilerKey =
      String.fromEnvironment('MAPTILER_KEY', defaultValue: '');
  static const String tileUrlTemplate =
      'https://api.maptiler.com/maps/outdoor-v2/256/{z}/{x}/{y}.png?key=$maptilerKey';

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
  static const String keyLastCampId = 'lastCampId';

  // Supported languages
  static const String languageRomanian = 'ro';
  static const String languageHungarian = 'hu';
}
