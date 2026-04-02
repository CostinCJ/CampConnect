import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/journal_entry.dart';

class JournalLocalStorage {
  static const String _boxName = 'journal_entries';

  Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<String>(_boxName);
    }
    return Hive.openBox<String>(_boxName);
  }

  /// Get the app-local directory for storing journal photos.
  Future<Directory> _photosDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/journal_photos');
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
}
