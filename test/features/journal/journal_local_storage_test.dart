import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:camp_connect/features/journal/data/journal_encryption_key.dart';
import 'package:camp_connect/features/journal/data/journal_local_storage.dart';
import 'package:camp_connect/features/journal/domain/journal_entry.dart';

/// Fake path_provider implementation so `getApplicationDocumentsDirectory()`
/// resolves inside our temp test directory instead of hitting a platform
/// channel (which doesn't exist in the plain `flutter_test` environment).
class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

JournalEntry _buildEntry({
  required String id,
  List<String> photos = const [],
}) {
  final now = DateTime(2026, 7, 1);
  return JournalEntry(
    id: id,
    date: now,
    title: 'Test entry $id',
    body: 'Body for $id',
    photos: photos,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late JournalLocalStorage storage;
  const uid = 'test-uid';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('journal_test_');
    // Matches production: main.dart calls Hive.initFlutter() with no subDir,
    // which stores box files directly under getApplicationDocumentsDirectory
    // -- the same path _FakePathProviderPlatform reports below. Needed so
    // JournalLocalStorage's on-disk legacy-box existence check (a plain File
    // under that same directory) actually finds what Hive writes.
    Hive.init(tempDir.path);
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    // The journal box is now encrypted (R7 Task 8) via a key resolved
    // through FlutterSecureStorage, which normally talks to a real platform
    // channel that doesn't exist in a plain flutter_test VM run.
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    storage = JournalLocalStorage(storageKey: uid);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('getAllEntries skips a corrupted entry but returns all valid ones',
      () async {
    await storage.saveEntry(_buildEntry(id: 'valid-1'));

    final box = await Hive.openBox<String>('journal_entries_$uid');
    await box.put('corrupted-key', 'not valid json{{{');

    final entries = await storage.getAllEntries();

    expect(entries.length, 1);
    expect(entries.single.id, 'valid-1');
  });

  test('clearAll deletes every entry and every photo file on disk', () async {
    final photoPath = '${tempDir.path}/photo1.jpg';
    await File(photoPath).writeAsBytes([0, 1, 2]);
    await storage.saveEntry(
      _buildEntry(id: 'with-photo', photos: [photoPath]),
    );

    await storage.clearAll();

    final box = await Hive.openBox<String>('journal_entries_$uid');
    expect(box.length, 0);
    expect(File(photoPath).existsSync(), isFalse);
  });

  test('deleteEntry removes the entry even if its photo file is already missing',
      () async {
    final missingPhotoPath = '${tempDir.path}/already-gone.jpg';
    await storage.saveEntry(
      _buildEntry(id: 'missing-photo', photos: [missingPhotoPath]),
    );

    await expectLater(storage.deleteEntry('missing-photo'), completes);

    final remaining = await storage.getEntry('missing-photo');
    expect(remaining, isNull);
  });

  group('legacy per-uid migration (device-scoped storage rollout)', () {
    // A kid's Firebase uid changes every time they claim a new code (e.g.
    // after losing/being re-issued an account), which would silently orphan
    // a journal keyed by uid. JournalLocalStorage now keys by a stable
    // device id instead, but must pull forward any pre-existing per-uid data
    // the first time it opens -- these tests prove that migration actually
    // moves the data (not just doesn't crash).
    const legacyUid = 'legacy-kid-uid';
    const deviceKey = 'device-abc';

    Future<String> seedLegacyBox() async {
      final legacyKey = await journalEncryptionKey(legacyUid);
      final legacyBox = await Hive.openBox<String>(
        'journal_entries_$legacyUid',
        encryptionCipher: HiveAesCipher(legacyKey),
      );
      final legacyPhotoDir =
          Directory('${tempDir.path}/journal_photos/$legacyUid')
            ..createSync(recursive: true);
      final legacyPhotoPath = '${legacyPhotoDir.path}/photo1.jpg';
      await File(legacyPhotoPath).writeAsBytes([1, 2, 3]);
      final legacyEntry =
          _buildEntry(id: 'legacy-1', photos: [legacyPhotoPath]);
      await legacyBox.put(legacyEntry.id, jsonEncode(legacyEntry.toJson()));
      await legacyBox.close();
      return legacyPhotoPath;
    }

    test(
        'a legacy per-uid box and its photo migrate into device-scoped '
        'storage on first open, and the legacy data is removed from disk',
        () async {
      await seedLegacyBox();

      final deviceStorage =
          JournalLocalStorage(storageKey: deviceKey, legacyUid: legacyUid);
      final entries = await deviceStorage.getAllEntries();

      expect(entries, hasLength(1));
      expect(entries.single.id, 'legacy-1');
      // The migrated entry's photo path must point into the NEW
      // device-scoped photos directory, and the file must actually be there.
      expect(
        entries.single.photos.single,
        contains('journal_photos/$deviceKey'),
      );
      expect(File(entries.single.photos.single).existsSync(), isTrue);

      // Single source of truth after migration: the legacy box file and
      // photos directory are both gone.
      expect(
        File('${tempDir.path}/journal_entries_$legacyUid.hive').existsSync(),
        isFalse,
      );
      expect(
        Directory('${tempDir.path}/journal_photos/$legacyUid').existsSync(),
        isFalse,
      );
    });

    test(
        'a second open (simulating an app restart) does not re-migrate or '
        'duplicate entries', () async {
      await seedLegacyBox();

      final first =
          JournalLocalStorage(storageKey: deviceKey, legacyUid: legacyUid);
      await first.getAllEntries();

      if (Hive.isBoxOpen('journal_entries_$deviceKey')) {
        await Hive.box<String>('journal_entries_$deviceKey').close();
      }
      final second =
          JournalLocalStorage(storageKey: deviceKey, legacyUid: legacyUid);
      final entriesAfterRestart = await second.getAllEntries();

      expect(entriesAfterRestart, hasLength(1));
      expect(entriesAfterRestart.single.id, 'legacy-1');
    });

    test(
        'a kid with no legacy data opens device-scoped storage cleanly (no '
        'migration attempted)', () async {
      final deviceStorage = JournalLocalStorage(
        storageKey: deviceKey,
        legacyUid: 'never-had-a-journal',
      );

      final entries = await deviceStorage.getAllEntries();
      expect(entries, isEmpty);
    });
  });
}
