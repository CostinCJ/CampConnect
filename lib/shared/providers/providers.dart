import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/camp_repository.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/domain/camp_session.dart';
import '../services/fcm_service.dart';
import '../../features/announcements/data/announcements_repository.dart';
import '../../features/announcements/domain/announcement.dart';
import '../../features/emergency/data/emergency_repository.dart';
import '../../features/emergency/domain/emergency_alert.dart';
import '../../features/journal/data/journal_local_storage.dart';
import '../../features/journal/domain/journal_entry.dart';
import '../../features/leaderboard/data/leaderboard_repository.dart';
import '../../features/leaderboard/domain/points_entry.dart';
import '../../features/leaderboard/domain/team.dart';
import '../../features/map/data/location_cache_service.dart';
import '../../features/map/data/location_repository.dart';
import '../../features/map/data/session_location_repository.dart';
import '../../features/map/domain/location.dart';
import '../../features/map/domain/session_location.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/settings/domain/app_settings.dart';
import '../../shared/services/image_upload_service.dart';

// --- Infrastructure Providers ---

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

// --- FCM Service Provider ---

final fcmServiceProvider = Provider<FcmService>((ref) {
  return FcmService();
});

// --- Repository Providers ---

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

final campRepositoryProvider = Provider<CampRepository>((ref) {
  return CampRepository(firestore: ref.watch(firestoreProvider));
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(sharedPreferencesProvider));
});

// --- Auth State Providers ---

final firebaseUserProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final appUserProvider = FutureProvider<AppUser?>((ref) async {
  final firebaseUser = ref.watch(firebaseUserProvider).valueOrNull;
  if (firebaseUser == null) return null;

  try {
    return await ref.watch(authRepositoryProvider).getAppUser(firebaseUser.uid);
  } catch (_) {
    return null;
  }
});

// --- Camp Session Provider ---

final activeCampIdProvider = StateProvider<String?>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return user?.campId;
});

final activeCampSessionProvider = FutureProvider<CampSession?>((ref) async {
  final campId = ref.watch(activeCampIdProvider);
  if (campId == null) return null;
  return ref.watch(campRepositoryProvider).getCampSession(campId);
});

final guideCampSessionsProvider = StreamProvider<List<CampSession>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null || !user.isGuide) return Stream.value([]);
  return ref.watch(campRepositoryProvider).getAllCampSessions();
});

// --- Leaderboard Providers ---

final leaderboardRepositoryProvider = Provider<LeaderboardRepository>((ref) {
  return LeaderboardRepository(firestore: ref.watch(firestoreProvider));
});

final leaderboardProvider = StreamProvider<List<Team>>((ref) {
  final campId = ref.watch(activeCampIdProvider);
  if (campId == null) return Stream.value([]);
  return ref.watch(leaderboardRepositoryProvider).watchTeams(campId);
});

final pointsHistoryProvider = StreamProvider<List<PointsEntry>>((ref) {
  final campId = ref.watch(activeCampIdProvider);
  if (campId == null) return Stream.value([]);
  return ref.watch(leaderboardRepositoryProvider).watchPointsHistory(campId);
});

// --- Announcements Providers ---

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((ref) {
  return AnnouncementsRepository(firestore: ref.watch(firestoreProvider));
});

final announcementsProvider = StreamProvider<List<Announcement>>((ref) {
  final campId = ref.watch(activeCampIdProvider);
  if (campId == null) return Stream.value([]);
  return ref.watch(announcementsRepositoryProvider).watchAnnouncements(campId);
});

// --- Emergency Providers ---

final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  return EmergencyRepository(firestore: ref.watch(firestoreProvider));
});

final emergencyAlertsProvider = StreamProvider<List<EmergencyAlert>>((ref) {
  final campId = ref.watch(activeCampIdProvider);
  if (campId == null) return Stream.value([]);
  return ref.watch(emergencyRepositoryProvider).watchAlerts(campId);
});

// --- Local Kid Name Provider (GDPR: stored only on device) ---

final localKidNameProvider = StateNotifierProvider<LocalKidNameNotifier, String?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final user = ref.watch(appUserProvider).valueOrNull;
  return LocalKidNameNotifier(prefs, user?.uid);
});

class LocalKidNameNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  final String? _uid;

  LocalKidNameNotifier(this._prefs, this._uid)
      : super(_uid != null ? _prefs.getString('kid_name_$_uid') : null);

  Future<void> setName(String name) async {
    if (_uid == null) return;
    await _prefs.setString('kid_name_$_uid', name);
    state = name;
  }
}

// --- Settings Provider ---

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return SettingsNotifier(repo);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repo;

  SettingsNotifier(this._repo) : super(_repo.load());

  Future<void> setLanguage(String language) async {
    await _repo.setLanguage(language);
    state = state.copyWith(language: language);
  }

  Future<void> setTheme(String theme) async {
    await _repo.setTheme(theme);
    state = state.copyWith(theme: theme);
  }

  Future<void> toggleTheme() async {
    final newTheme = state.isDarkMode ? 'light' : 'dark';
    await setTheme(newTheme);
  }

  Future<void> setLlmEnabled(bool enabled) async {
    await _repo.setLlmEnabled(enabled);
    state = state.copyWith(llmEnabled: enabled);
  }

  Future<void> setLastCampId(String campId) async {
    await _repo.setLastCampId(campId);
    state = state.copyWith(lastCampId: campId);
  }
}

// --- Journal Providers (GDPR: all data stays on device) ---

final journalLocalStorageProvider = Provider<JournalLocalStorage>((ref) {
  return JournalLocalStorage();
});

final journalProvider =
    StateNotifierProvider<JournalNotifier, AsyncValue<List<JournalEntry>>>(
        (ref) {
  final storage = ref.watch(journalLocalStorageProvider);
  return JournalNotifier(storage);
});

class JournalNotifier extends StateNotifier<AsyncValue<List<JournalEntry>>> {
  final JournalLocalStorage _storage;

  JournalNotifier(this._storage) : super(const AsyncValue.loading()) {
    loadEntries();
  }

  Future<void> loadEntries() async {
    try {
      final entries = await _storage.getAllEntries();
      if (mounted) {
        state = AsyncValue.data(entries);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> saveEntry(JournalEntry entry) async {
    await _storage.saveEntry(entry);
    await loadEntries();
  }

  Future<void> deleteEntry(String id) async {
    await _storage.deleteEntry(id);
    await loadEntries();
  }

  Future<String> savePhoto(String sourcePath) async {
    return _storage.savePhoto(sourcePath);
  }

  Future<void> deletePhoto(String photoPath) async {
    return _storage.deletePhoto(photoPath);
  }

  Future<int> getEntryCount() async {
    return _storage.getEntryCount();
  }
}

// --- Map & Location Providers ---

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(firestore: ref.watch(firestoreProvider));
});

final sessionLocationRepositoryProvider = Provider<SessionLocationRepository>((ref) {
  return SessionLocationRepository(firestore: ref.watch(firestoreProvider));
});

final locationCacheServiceProvider = Provider<LocationCacheService>((ref) {
  return LocationCacheService();
});

final imageUploadServiceProvider = Provider<ImageUploadService>((ref) {
  return ImageUploadService(storage: ref.watch(firebaseStorageProvider));
});

/// All master locations (for guide settings / location picker).
final masterLocationsProvider = StreamProvider<List<Location>>((ref) {
  return ref.watch(locationRepositoryProvider).watchAllLocations();
});

/// Session locations for the active camp (join records with masterLocationId + photo).
final sessionLocationsProvider = StreamProvider<List<SessionLocation>>((ref) {
  final campId = ref.watch(activeCampIdProvider);
  if (campId == null) return Stream.value([]);
  return ref.watch(sessionLocationRepositoryProvider).watchSessionLocations(campId);
});

/// Resolved session locations: combines SessionLocation with master Location data.
final resolvedSessionLocationsProvider = FutureProvider<List<ResolvedSessionLocation>>((ref) async {
  final sessionLocations = ref.watch(sessionLocationsProvider).valueOrNull ?? [];
  if (sessionLocations.isEmpty) return [];

  final masterIds = sessionLocations.map((sl) => sl.masterLocationId).toSet().toList();
  final masterLocations = await ref.watch(locationRepositoryProvider).getLocationsByIds(masterIds);
  final masterMap = {for (final loc in masterLocations) loc.id: loc};

  return sessionLocations
      .where((sl) => masterMap.containsKey(sl.masterLocationId))
      .map((sl) => ResolvedSessionLocation(
            sessionLocation: sl,
            masterLocation: masterMap[sl.masterLocationId]!,
          ))
      .toList();
});

final locationCategoryFilterProvider = StateProvider<LocationCategory?>((ref) {
  return null; // null means "all categories"
});

final filteredSessionLocationsProvider = Provider<AsyncValue<List<ResolvedSessionLocation>>>((ref) {
  final resolvedAsync = ref.watch(resolvedSessionLocationsProvider);
  final filter = ref.watch(locationCategoryFilterProvider);

  return resolvedAsync.whenData((locations) {
    if (filter == null) return locations;
    return locations.where((rl) => rl.masterLocation.category == filter).toList();
  });
});

/// Combines a session location (photo, visitedAt) with its master location data.
class ResolvedSessionLocation {
  final SessionLocation sessionLocation;
  final Location masterLocation;

  const ResolvedSessionLocation({
    required this.sessionLocation,
    required this.masterLocation,
  });
}
