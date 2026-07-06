import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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
    Hive.init('${tempDir.path}/hive');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    // The journal box is now encrypted (R7 Task 8) via a key resolved
    // through FlutterSecureStorage, which normally talks to a real platform
    // channel that doesn't exist in a plain flutter_test VM run.
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    storage = JournalLocalStorage(uid: uid);
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
}
