import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/camp_repository.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/auth/domain/camp_session.dart';
import '../../features/settings/data/settings_repository.dart';
import '../../features/settings/domain/app_settings.dart';

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
