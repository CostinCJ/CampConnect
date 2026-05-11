import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/llm/data/chat_cache_repository.dart';
import 'package:camp_connect/features/llm/domain/chat_message.dart';

void main() {
  late ChatCacheRepository repo;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('chat_cache_test_');
    repo = ChatCacheRepository(cacheDir: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ChatCacheRepository', () {
    test('saves and loads messages for a location', () async {
      final messages = [
        ChatMessage.user('Ce animale trăiesc aici?'),
        ChatMessage.assistant('Aici trăiesc urși bruni și cerbi.'),
      ];

      await repo.save('loc1', 'ro', messages);
      final loaded = await repo.load('loc1', 'ro');

      expect(loaded, hasLength(2));
      expect(loaded[0].role, ChatRole.user);
      expect(loaded[0].content, 'Ce animale trăiesc aici?');
      expect(loaded[1].role, ChatRole.assistant);
    });

    test('returns empty list for non-existent cache', () async {
      final loaded = await repo.load('nonexistent', 'ro');
      expect(loaded, isEmpty);
    });

    test('caches separately per language', () async {
      await repo.save('loc1', 'ro', [ChatMessage.user('Salut')]);
      await repo.save('loc1', 'hu', [ChatMessage.user('Szia')]);

      final ro = await repo.load('loc1', 'ro');
      final hu = await repo.load('loc1', 'hu');

      expect(ro[0].content, 'Salut');
      expect(hu[0].content, 'Szia');
    });

    test('clears cache for a specific location', () async {
      await repo.save('loc1', 'ro', [ChatMessage.user('Test')]);
      await repo.clear('loc1', 'ro');

      final loaded = await repo.load('loc1', 'ro');
      expect(loaded, isEmpty);
    });

    test('clearAll removes all cached conversations', () async {
      await repo.save('loc1', 'ro', [ChatMessage.user('A')]);
      await repo.save('loc2', 'hu', [ChatMessage.user('B')]);
      await repo.clearAll();

      expect(await repo.load('loc1', 'ro'), isEmpty);
      expect(await repo.load('loc2', 'hu'), isEmpty);
    });
  });
}
