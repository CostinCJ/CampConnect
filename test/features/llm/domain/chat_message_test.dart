import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/llm/domain/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('creates a user message', () {
      final msg = ChatMessage.user('Hello');
      expect(msg.role, ChatRole.user);
      expect(msg.content, 'Hello');
      expect(msg.timestamp, isNotNull);
    });

    test('creates an assistant message', () {
      final msg = ChatMessage.assistant('Hi there!');
      expect(msg.role, ChatRole.assistant);
      expect(msg.content, 'Hi there!');
    });

    test('serializes to JSON and back', () {
      final msg = ChatMessage.user('Test message');
      final json = msg.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.role, msg.role);
      expect(restored.content, msg.content);
    });

    test('estimates token count roughly', () {
      final msg = ChatMessage.user('Aceasta este o propoziție de test pentru estimarea tokenilor.');
      expect(msg.estimatedTokens, greaterThan(10));
      expect(msg.estimatedTokens, lessThan(30));
    });
  });
}
