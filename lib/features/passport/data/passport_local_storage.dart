import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/passport_stamp.dart';

/// Device-local passport storage (stamps + quiz results), keyed by the same
/// stable device id as the journal (`deviceJournalIdProvider`). Plain box:
/// values are location ids and timestamps only — nothing personal, so no
/// cipher (unlike the journal, which holds free text).
class PassportLocalStorage {
  final String storageKey;

  PassportLocalStorage({required this.storageKey});

  String get _boxName => 'passport_$storageKey';

  static String _stampKey(String locationId) => 'stamp_$locationId';
  static String _quizKey(String locationId) => 'quiz_$locationId';

  Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<String>(_boxName);
    return Hive.openBox<String>(_boxName);
  }

  /// Records a visit. Idempotent: a repeat check-in keeps the original date.
  /// A repeat check-in does backfill [locationName]/[categoryName] onto a
  /// stamp from before those fields existed, so old stamps heal themselves.
  Future<void> addStamp(
    String locationId, {
    String? locationName,
    String? categoryName,
  }) async {
    final box = await _openBox();
    final key = _stampKey(locationId);
    final existingRaw = box.get(key);
    if (existingRaw != null) {
      try {
        final existing =
            PassportStamp.fromJson(jsonDecode(existingRaw) as Map<String, dynamic>);
        if (existing.locationName != null || locationName == null) return;
        final healed = PassportStamp(
          locationId: existing.locationId,
          visitedAt: existing.visitedAt,
          locationName: locationName,
          categoryName: categoryName,
        );
        await box.put(key, jsonEncode(healed.toJson()));
        return;
      } catch (_) {
        // Corrupted value: fall through and overwrite with a fresh stamp.
      }
    }
    final stamp = PassportStamp(
      locationId: locationId,
      visitedAt: DateTime.now(),
      locationName: locationName,
      categoryName: categoryName,
    );
    await box.put(key, jsonEncode(stamp.toJson()));
  }

  Future<bool> hasStamp(String locationId) async {
    final box = await _openBox();
    return box.containsKey(_stampKey(locationId));
  }

  /// All stamps, newest first.
  Future<List<PassportStamp>> getStamps() async {
    final box = await _openBox();
    final stamps = <PassportStamp>[];
    for (final key in box.keys) {
      if (key is! String || !key.startsWith('stamp_')) continue;
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        stamps.add(
          PassportStamp.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip corrupted entries, like journal storage does.
      }
    }
    stamps.sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
    return stamps;
  }

  /// Saves a quiz result, keeping only the best score per location.
  Future<void> saveQuizResult(QuizResult result) async {
    final box = await _openBox();
    final key = _quizKey(result.locationId);
    final existingRaw = box.get(key);
    if (existingRaw != null) {
      try {
        final existing =
            QuizResult.fromJson(jsonDecode(existingRaw) as Map<String, dynamic>);
        if (existing.correct >= result.correct) return;
      } catch (_) {
        // Fall through and overwrite a corrupted value.
      }
    }
    await box.put(key, jsonEncode(result.toJson()));
  }

  Future<QuizResult?> getQuizResult(String locationId) async {
    final box = await _openBox();
    final raw = box.get(_quizKey(locationId));
    if (raw == null) return null;
    try {
      return QuizResult.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<QuizResult>> getQuizResults() async {
    final box = await _openBox();
    final results = <QuizResult>[];
    for (final key in box.keys) {
      if (key is! String || !key.startsWith('quiz_')) continue;
      final raw = box.get(key);
      if (raw == null) continue;
      try {
        results.add(
          QuizResult.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
      } catch (_) {
        // Skip corrupted entries.
      }
    }
    return results;
  }

  /// Used by the kid "delete my data" flow (alongside journal clearAll).
  Future<void> clearAll() async {
    final box = await _openBox();
    await box.clear();
  }
}
