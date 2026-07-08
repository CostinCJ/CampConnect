import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/journal_entry.dart';
import 'journal_encryption_key.dart';

class JournalLocalStorage {
  /// Stable, device-scoped identifier the journal is actually keyed by (see
  /// [deviceJournalIdProvider] in providers.dart). Deliberately NOT the
  /// signed-in kid's Firebase uid, which changes every time they claim a new
  /// code (e.g. after losing/being re-issued an account) — keying by uid
  /// would silently orphan their journal on every re-registration.
  final String _storageKey;

  /// The currently signed-in kid's Firebase uid, if any. Used only once, on
  /// the first open, to migrate a pre-existing per-uid box/photos (from
  /// before storage became device-scoped) into the new device-keyed one —
  /// never read again afterwards.
  final String? _legacyUid;

  JournalLocalStorage({required String storageKey, String? legacyUid})
      : _storageKey = storageKey,
        _legacyUid = legacyUid;

  /// True only while the first `Hive.openBox` attempt below (the one that
  /// deliberately risks a cipher-mismatch HiveError) is in flight. Hive's own
  /// internal error handling does an unawaited `box.close()` inside its catch
  /// block when that open throws, which leaks a second, detached copy of the
  /// same "Wrong checksum in hive file" error to
  /// `PlatformDispatcher.onError` shortly after. main.dart checks this flag
  /// so it only suppresses that specific, expected, one-time leak -- not any
  /// "Wrong checksum" error from any Hive box, at any time (see
  /// docs/superpowers/plans/r7-decision-log.md).
  static bool migratingLegacyJournalBox = false;

  String get _boxName => 'journal_entries_$_storageKey';
  static String _boxNameFor(String key) => 'journal_entries_$key';

  Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<String>(_boxName);
    }

    final key = await journalEncryptionKey(_storageKey);
    final cipher = HiveAesCipher(key);

    migratingLegacyJournalBox = true;
    Box<String> box;
    try {
      // `crashRecovery: false` is essential here: with the default
      // `crashRecovery: true`, Hive treats a cipher/CRC mismatch (i.e. an
      // existing *unencrypted* box on disk from before this change) as
      // "corruption" and silently truncates the box file to the point of
      // mismatch -- which for a plaintext box is byte 0, destroying all
      // existing entries with no exception thrown at all. Passing
      // `crashRecovery: false` makes Hive throw a HiveError instead of
      // truncating, which is what lets us detect "this box predates
      // encryption" and migrate it safely below instead of silently losing
      // the user's journal.
      box = await Hive.openBox<String>(
        _boxName,
        encryptionCipher: cipher,
        crashRecovery: false,
      );
    } on HiveError {
      // Existing unencrypted box on disk from before this change. Re-open it
      // with no cipher (safe: this reads the plaintext frames correctly),
      // copy its entries out, delete it from disk, then recreate it as an
      // encrypted box and restore the entries into it.
      final legacyBox = await Hive.openBox<String>(_boxName);
      final entries = Map<String, String>.from(legacyBox.toMap());
      await legacyBox.deleteFromDisk();

      box = await Hive.openBox<String>(
        _boxName,
        encryptionCipher: cipher,
        crashRecovery: false,
      );
      await box.putAll(entries);
    } finally {
      migratingLegacyJournalBox = false;
    }

    // One-time migration from the legacy per-uid box (pre device-scoped
    // storage): only attempted while the device box is still empty, and only
    // if a legacy box actually exists on disk, so this is a cheap no-op on
    // every launch once migrated (or for a kid who never had one).
    if (_legacyUid != null &&
        box.isEmpty &&
        await _legacyBoxExistsOnDisk(_legacyUid)) {
      await _migrateLegacyUidData(box, _legacyUid);
    }

    return box;
  }

  Future<bool> _legacyBoxExistsOnDisk(String uid) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/${_boxNameFor(uid)}.hive');
    return file.exists();
  }

  /// Copies every entry (and its photo files) from the legacy per-uid box
  /// into [newBox]/[_photosDir], rewriting each entry's photo paths to point
  /// at their new location, then removes the legacy box and photos directory
  /// so there's a single source of truth going forward.
  Future<void> _migrateLegacyUidData(Box<String> newBox, String uid) async {
    final legacyBoxName = _boxNameFor(uid);
    Box<String> legacyBox;
    try {
      final legacyKey = await journalEncryptionKey(uid);
      legacyBox = await Hive.openBox<String>(
        legacyBoxName,
        encryptionCipher: HiveAesCipher(legacyKey),
        crashRecovery: false,
      );
    } on HiveError {
      // The legacy box predates encryption too (installed before both this
      // change and the earlier cipher migration) -- same plaintext fallback.
      legacyBox = await Hive.openBox<String>(legacyBoxName);
    }

    final newPhotosDir = await _photosDir();
    final legacyPhotosDir = await _legacyPhotosDir(uid);

    for (final entryKey in legacyBox.keys) {
      final raw = legacyBox.get(entryKey);
      if (raw == null) continue;
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        final photos = List<String>.from(json['photos'] as List? ?? []);
        final movedPhotos = <String>[];
        for (final oldPath in photos) {
          final file = File(oldPath);
          if (await file.exists()) {
            final fileName = oldPath.split('/').last.split('\\').last;
            final newPath = '${newPhotosDir.path}/$fileName';
            await file.rename(newPath);
            movedPhotos.add(newPath);
          }
        }
        json['photos'] = movedPhotos;
        await newBox.put(entryKey as String, jsonEncode(json));
      } catch (_) {
        // Skip an entry that fails to parse/migrate rather than aborting the
        // whole migration -- the rest still lands.
      }
    }

    await legacyBox.deleteFromDisk();
    if (await legacyPhotosDir.exists()) {
      await legacyPhotosDir.delete(recursive: true);
    }
  }

  /// Get the app-local directory for storing journal photos.
  Future<Directory> _photosDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/journal_photos/$_storageKey');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _legacyPhotosDir(String uid) async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/journal_photos/$uid');
  }

  /// Copy a photo to the app's local storage and return the new path.
  Future<String> savePhoto(String sourcePath) async {
    final dir = await _photosDir();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${sourcePath.split('/').last.split('\\').last}';
    final destPath = '${dir.path}/$fileName';
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  /// Delete a locally stored photo.
  Future<void> deletePhoto(String photoPath) async {
    final file = File(photoPath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Get all journal entries sorted by date descending (newest first).
  Future<List<JournalEntry>> getAllEntries() async {
    final box = await _openBox();
    final entries = <JournalEntry>[];
    for (final value in box.values) {
      try {
        final json = jsonDecode(value) as Map<String, dynamic>;
        entries.add(JournalEntry.fromJson(json));
      } catch (_) {
        // Skip corrupted entries
      }
    }
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  /// Get a single journal entry by ID.
  Future<JournalEntry?> getEntry(String id) async {
    final box = await _openBox();
    final value = box.get(id);
    if (value == null) return null;
    try {
      final json = jsonDecode(value) as Map<String, dynamic>;
      return JournalEntry.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Create or update a journal entry.
  Future<void> saveEntry(JournalEntry entry) async {
    final box = await _openBox();
    await box.put(entry.id, jsonEncode(entry.toJson()));
  }

  /// Delete a journal entry and its associated photos.
  Future<void> deleteEntry(String id) async {
    final box = await _openBox();
    final value = box.get(id);
    if (value != null) {
      try {
        final json = jsonDecode(value) as Map<String, dynamic>;
        final entry = JournalEntry.fromJson(json);
        for (final photo in entry.photos) {
          await deletePhoto(photo);
        }
      } catch (_) {
        // Proceed with deletion even if photo cleanup fails
      }
    }
    await box.delete(id);
  }

  /// Get total entry count (for dashboard stats).
  Future<int> getEntryCount() async {
    final box = await _openBox();
    return box.length;
  }

  /// Deletes every entry (and its photos) and clears the box. Used by the
  /// kid "delete my data" consent-revocation flow.
  Future<void> clearAll() async {
    final entries = await getAllEntries();
    for (final entry in entries) {
      for (final photo in entry.photos) {
        await deletePhoto(photo);
      }
    }
    final box = await _openBox();
    await box.clear();
  }
}
