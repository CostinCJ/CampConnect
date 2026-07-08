class AppConstants {
  AppConstants._();

  static const String appName = 'CampConnect';
  static const String appVersion = '1.0.0';

  // Camp code format: PREFIX-XXXX, where PREFIX is the organiser's prefix
  // (2–8 alphanumerics, e.g. CAMP or MURES) and XXXX is 4 random chars.
  static const String codePrefix = 'CAMP'; // fallback default prefix
  static const int codeLength = 4;
  static final RegExp codeRegex = RegExp(r'^[A-Z0-9]{2,8}-[A-Z0-9]{4}$');

  // Code generation charset
  static const String codeCharset = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // Upper bound enforced both by the UI cap and the repository itself, so the
  // two can never drift apart (see CampRepository.generateBulkCodes).
  static const int maxBulkCodeGeneration = 200;

  // Default team colors pre-filled when creating a camp. The matching names
  // come from l10n (defaultTeamRed..defaultTeamYellow) so they follow the
  // guide's app language. Guides can rename, recolor, add, or remove them
  // before creating the session.
  static const List<String> defaultTeamColorHexes = [
    '#E53935',
    '#1E88E5',
    '#43A047',
    '#FDD835',
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

  // Storage folder for session group photos. Org-scoped (not camp-scoped) so
  // the Storage rule can authorise via the guide's orgId claim directly —
  // matching the master-location photo rule — instead of a cross-service
  // Firestore lookup of the camp's org.
  static const String sessionPhotosStorageFolder = 'sessionPhotos';

  // Map tiles — keyed provider (OSM public tiles forbid app distribution + caching).
  // Provide via --dart-define=MAPTILER_KEY=xxxx so the key is not committed.
  // The /256/ path serves 256px tiles, matching flutter_map's default tile size.
  // Satellite imagery is served as JPEG (not PNG) — better for photographic
  // aerial tiles used to spot trails, clearings, and terrain around the camp.
  static const String maptilerKey =
      String.fromEnvironment('MAPTILER_KEY', defaultValue: '');
  static const String tileUrlTemplate =
      'https://api.maptiler.com/maps/satellite/256/{z}/{x}/{y}.jpg?key=$maptilerKey';

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

  // Supported languages
  static const String languageRomanian = 'ro';
  static const String languageHungarian = 'hu';

  // Legal
  static const String privacyPolicyUrl =
      'https://costincj.github.io/CampConnect/privacy-policy';
}
