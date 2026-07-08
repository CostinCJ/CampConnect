import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'features/journal/data/journal_local_storage.dart';
import 'firebase_options.dart';
import 'shared/providers/providers.dart';

/// Top-level background message handler (must be a top-level function).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background messages are handled by the OS notification tray.
  // The onMessageOpenedApp handler in the app routes the user on tap.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Debug-only: point the app at local Firebase emulators when launched
  // with --dart-define=USE_EMULATORS=true. Inert in release builds.
  const bool useEmulators = bool.fromEnvironment('USE_EMULATORS');

  await FirebaseAppCheck.instance.activate(
    androidProvider: useEmulators
        ? AndroidProvider.debug
        : AndroidProvider.playIntegrity,
    appleProvider:
        useEmulators ? AppleProvider.debug : AppleProvider.appAttest,
  );

  if (useEmulators) {
    final host = defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    // Repositories resolve a region-scoped FirebaseFunctions instance
    // (AppConstants.functionsRegion), not the bare us-central1 default —
    // useFunctionsEmulator must be called on that same instance or callables
    // in debug builds will try to reach production instead of the emulator.
    FirebaseFunctions.instanceFor(region: AppConstants.functionsRegion)
        .useFunctionsEmulator(host, 5001);
  }

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Route crashes to Crashlytics. Collection itself is disabled by default
  // and only enabled for signed-in guides (see app.dart) — never for
  // anonymous kid users, to honor the mixed-audience/child-data stance.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    // The journal Hive box's one-time plaintext-to-encrypted migration
    // (journal_local_storage.dart) deliberately opens the legacy box with
    // crashRecovery: false so a cipher mismatch throws instead of silently
    // truncating the file. Hive's own internal error path then does an
    // unawaited box.close() in its catch block, which itself throws a
    // second, detached copy of the same benign "Wrong checksum" error --
    // expected exactly once per guide with pre-existing journal data on
    // their first post-upgrade launch, not a real crash. Scoped to
    // migratingLegacyJournalBox (rather than matching the message alone)
    // so a genuinely corrupted box -- this one after migration, or any
    // future crashRecovery:false box -- still reports as fatal instead of
    // being silently swallowed. Reported non-fatal, not dropped entirely,
    // so field data can still confirm migrations are completing.
    if (JournalLocalStorage.migratingLegacyJournalBox &&
        error is HiveError &&
        error.message.contains('Wrong checksum in hive file')) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
      return true;
    }
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Initialize Hive for local caching (locations, journal)
  await Hive.initFlutter();

  // Initialize FMTC for offline map tile caching
  await FMTCObjectBoxBackend().initialise();
  await const FMTCStore('mapTiles').manage.create();

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const CampConnectApp(),
    ),
  );
}
