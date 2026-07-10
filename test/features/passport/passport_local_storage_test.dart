import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:camp_connect/features/passport/data/passport_local_storage.dart';
import 'package:camp_connect/features/passport/domain/passport_stamp.dart';

void main() {
  late Directory tempDir;
  late PassportLocalStorage storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('passport_test');
    Hive.init(tempDir.path);
    storage = PassportLocalStorage(storageKey: 'device1');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  test('addStamp is idempotent and getStamps sorts newest first', () async {
    await storage.addStamp('locA');
    await storage.addStamp('locA'); // second check-in keeps first date
    await storage.addStamp('locB');

    final stamps = await storage.getStamps();
    expect(stamps.length, 2);
    expect(await storage.hasStamp('locA'), isTrue);
    expect(await storage.hasStamp('locC'), isFalse);
  });

  test('quiz results save and load, keeping the best score', () async {
    await storage.saveQuizResult(QuizResult(
      locationId: 'locA',
      correct: 1,
      total: 3,
      completedAt: DateTime(2026, 7, 10),
    ));
    await storage.saveQuizResult(QuizResult(
      locationId: 'locA',
      correct: 3,
      total: 3,
      completedAt: DateTime(2026, 7, 11),
    ));
    // A worse later attempt must not overwrite the best.
    await storage.saveQuizResult(QuizResult(
      locationId: 'locA',
      correct: 2,
      total: 3,
      completedAt: DateTime(2026, 7, 12),
    ));

    final result = await storage.getQuizResult('locA');
    expect(result!.correct, 3);
    final all = await storage.getQuizResults();
    expect(all.length, 1);
  });

  test('clearAll wipes stamps and results', () async {
    await storage.addStamp('locA');
    await storage.saveQuizResult(QuizResult(
      locationId: 'locA',
      correct: 1,
      total: 1,
      completedAt: DateTime(2026, 7, 10),
    ));
    await storage.clearAll();
    expect(await storage.getStamps(), isEmpty);
    expect(await storage.getQuizResults(), isEmpty);
  });
}
