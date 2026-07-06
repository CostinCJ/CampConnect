import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/journal_entry.dart';
import 'journal_encryption_key.dart';

class JournalLocalStorage {
  final String _uid;

  JournalLocalStorage({required String uid}) : _uid = uid;

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

  String get _boxName => 'journal_entries_$_uid';

  Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<String>(_boxName);
    }

    final key = await journalEncryptionKey(_uid);
    final cipher = HiveAesCipher(key);

    migratingLegacyJournalBox = true;
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
      return await Hive.openBox<String>(
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

      final encryptedBox = await Hive.openBox<String>(
        _boxName,
        encryptionCipher: cipher,
        crashRecovery: false,
      );
      await encryptedBox.putAll(entries);
      return encryptedBox;
    } finally {
      migratingLegacyJournalBox = false;
    }
  }

  /// Get the app-local directory for storing journal photos.
  Future<Directory> _photosDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/journal_photos/$_uid');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
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
