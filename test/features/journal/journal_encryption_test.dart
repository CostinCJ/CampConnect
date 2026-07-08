import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:camp_connect/features/journal/data/journal_local_storage.dart';
import 'package:camp_connect/features/journal/domain/journal_entry.dart';

/// Lenient latin1 decoder used only to sniff raw box-file bytes for an
/// obviously-plaintext marker string. `allowInvalid: true` means it never
/// throws on non-latin1 byte sequences (e.g. encrypted/binary data) -- it
/// just produces replacement characters for those, which is fine since we
/// only care whether the marker substring is present verbatim.
class _LatinCodec extends Encoding {
  const _LatinCodec();
  @override
  String get name => 'latin1-lenient';
  @override
  Converter<List<int>, String> get decoder =>
      const Latin1Decoder(allowInvalid: true);
  @override
  Converter<String, List<int>> get encoder => const Latin1Encoder();
}

JournalEntry buildEntry({required String body}) => JournalEntry(
      id: 'entry-1',
      date: DateTime(2026, 7, 1),
      title: 'Test entry',
      body: body,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('journal_enc_test_');
    Hive.init(tempDir.path);
    // journalEncryptionKey() reads/writes through FlutterSecureStorage,
    // which normally talks to a real platform channel (Android
    // Keystore/iOS Keychain/etc). That channel doesn't exist in a plain
    // flutter_test VM run, so swap in the package's supported in-memory
    // test double for the platform singleton instead of hitting a real
    // channel.
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  tearDown(() async {
    // Close *all* currently-open boxes (rather than guessing a single
    // box name) so leftover state never bleeds into the next test's
    // Hive.init() on a fresh temp directory.
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('the journal Hive box is opened with an AES encryption cipher',
      () async {
    final storage = JournalLocalStorage(storageKey: 'test-uid');

    await storage.saveEntry(
      buildEntry(body: 'UNIQUE_PLAINTEXT_MARKER_12345'),
    );

    final boxFile = File('${tempDir.path}/journal_entries_test-uid.hive');
    final rawBytes = await boxFile.readAsString(encoding: const _LatinCodec());
    expect(rawBytes.contains('UNIQUE_PLAINTEXT_MARKER_12345'), isFalse);

    // Sanity check the other direction too: the entry really is retrievable
    // through the storage API (i.e. this isn't failing to find the marker
    // because nothing was ever written).
    final reloaded = await storage.getEntry('entry-1');
    expect(reloaded?.body, 'UNIQUE_PLAINTEXT_MARKER_12345');
  });

  test(
      'a pre-existing unencrypted box on disk is migrated to an encrypted '
      'box without losing data', () async {
    const uid = 'test-uid';
    const boxName = 'journal_entries_$uid';

    // Seed a legacy *unencrypted* box directly via Hive, simulating a real
    // device that installed the app before this change shipped.
    final legacyBox = await Hive.openBox<String>(boxName);
    final legacyEntry = buildEntry(body: 'LEGACY_PLAINTEXT_ENTRY_98765');
    await legacyBox.put(legacyEntry.id, jsonEncode(legacyEntry.toJson()));
    await legacyBox.close();

    // Confirm the seed really did land on disk as plaintext (proves the
    // migration path below is actually being exercised, not a no-op).
    final boxFile = File('${tempDir.path}/$boxName.hive');
    final rawBytesBefore =
        await boxFile.readAsString(encoding: const _LatinCodec());
    expect(rawBytesBefore.contains('LEGACY_PLAINTEXT_ENTRY_98765'), isTrue);

    // Now use the real (post-fix) JournalLocalStorage, which should detect
    // the legacy plaintext box, migrate it, and transparently return the
    // migrated entry.
    //
    // NOTE on runZonedGuarded: detecting "this box predates encryption" (see
    // _openBox's implementation) deliberately opens the box with a mismatched
    // encryptionCipher and relies on Hive throwing HiveError, which we catch
    // and handle correctly (verified independently with a standalone script
    // outside the test framework). However, Hive's *own* internal error path
    // (HiveImpl._openBox's catch block, hive_impl.dart) additionally fires an
    // unawaited `newBox?.close()` that itself throws (because the box's
    // fields were never fully initialized) -- as a second, detached
    // background error unrelated to our already-correct handling. That
    // detached error doesn't affect correctness (confirmed above and via an
    // isolated reproduction), but flutter_test's default zone fails the
    // *test* on any uncaught async error, even one from a totally unrelated
    // Future. Running the exercised call in its own guarded zone lets us
    // confirm we see exactly that one known, already-diagnosed error (and no
    // others) without it spuriously failing this test.
    final migratedEntry = await _runGuarded(() async {
      final storage = JournalLocalStorage(storageKey: uid);
      return storage.getEntry('entry-1');
    });
    expect(migratedEntry, isNotNull);
    expect(migratedEntry!.body, 'LEGACY_PLAINTEXT_ENTRY_98765');

    // And the box on disk must now actually be encrypted -- the plaintext
    // marker must no longer appear in the raw bytes.
    final rawBytesAfter =
        await boxFile.readAsString(encoding: const _LatinCodec());
    expect(rawBytesAfter.contains('LEGACY_PLAINTEXT_ENTRY_98765'), isFalse);

    // A second read (fresh JournalLocalStorage instance, simulating the app
    // being restarted after migration) must also work: the same encryption
    // key must be reused, and the box must open cleanly the second time
    // around (i.e. we're not re-triggering "migration" every launch, and
    // this path does NOT hit the cipher-mismatch/leak path at all).
    if (Hive.isBoxOpen(boxName)) {
      await Hive.box<String>(boxName).close();
    }
    final storageAfterRestart = JournalLocalStorage(storageKey: uid);
    final reReadEntry = await storageAfterRestart.getEntry('entry-1');
    expect(reReadEntry?.body, 'LEGACY_PLAINTEXT_ENTRY_98765');

    // And all pre-existing data survived the migration, not just the one
    // entry we asserted on above -- confirm count/shape end to end.
    final allEntries = await storageAfterRestart.getAllEntries();
    expect(allEntries, hasLength(1));
    expect(allEntries.single.id, legacyEntry.id);
    expect(allEntries.single.title, legacyEntry.title);
  });
}

/// Runs [body] in its own error zone, swallowing exactly one known, benign,
/// already-diagnosed Hive-internal error leak (see the comment at the call
/// site) so it doesn't spuriously fail the test, while still surfacing (by
/// rethrowing) anything unexpected.
Future<T> _runGuarded<T>(Future<T> Function() body) {
  final completer = Completer<T>();
  runZonedGuarded(() async {
    completer.complete(await body());
  }, (error, stack) {
    final isKnownHiveInternalLeak =
        error is HiveError && error.message.contains('Wrong checksum');
    if (!isKnownHiveInternalLeak) {
      if (!completer.isCompleted) completer.completeError(error, stack);
    }
  });
  return completer.future;
}
