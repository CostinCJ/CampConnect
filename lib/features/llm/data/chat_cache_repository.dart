import 'dart:convert';
import 'dart:io';

import 'package:camp_connect/features/llm/domain/chat_message.dart';

class ChatCacheRepository {
  final String cacheDir;

  ChatCacheRepository({required this.cacheDir});

  String _filePath(String locationId, String language) {
    return '$cacheDir/chat_${locationId}_$language.json';
  }

  Future<List<ChatMessage>> load(String locationId, String language) async {
    final file = File(_filePath(locationId, language));
    if (!file.existsSync()) return [];

    try {
      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(
    String locationId,
    String language,
    List<ChatMessage> messages,
  ) async {
    final file = File(_filePath(locationId, language));
    await file.parent.create(recursive: true);
    final jsonString = jsonEncode(messages.map((m) => m.toJson()).toList());
    await file.writeAsString(jsonString);
  }

  Future<void> clear(String locationId, String language) async {
    final file = File(_filePath(locationId, language));
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<void> clearAll() async {
    final dir = Directory(cacheDir);
    if (!dir.existsSync()) return;

    await for (final entity in dir.list()) {
      if (entity is File && entity.path.contains('chat_')) {
        await entity.delete();
      }
    }
  }
}
