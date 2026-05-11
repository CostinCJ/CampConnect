import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/constants/app_constants.dart';
import 'features/llm/domain/device_capability.dart';
import 'features/settings/data/settings_repository.dart';
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

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize Hive for local caching (locations, journal)
  await Hive.initFlutter();

  // Initialize FMTC for offline map tile caching
  await FMTCObjectBoxBackend().initialise();
  await const FMTCStore('mapTiles').manage.create();

  final sharedPreferences = await SharedPreferences.getInstance();

  final settingsRepo = SettingsRepository(sharedPreferences);

  // Check device capability for LLM (CPU / RAM checks — no native dependency)
  final isCapable = await DeviceCapability.isCapable();
  await settingsRepo.setDeviceCapable(isCapable);

  // Check if model file exists (plain file check — no native dependency)
  final docsDir = await getApplicationDocumentsDirectory();
  final modelFile = File('${docsDir.path}/${AppConstants.llmModelFileName}');
  await settingsRepo.setModelDownloaded(modelFile.existsSync());

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const CampConnectApp(),
    ),
  );
}
