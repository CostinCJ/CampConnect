import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/llm/domain/prompt_templates.dart';
import 'package:camp_connect/features/llm/domain/chat_message.dart';
import 'package:camp_connect/features/map/domain/location.dart';

void main() {
  final testKb = KnowledgeBase(
    description: 'O poiană frumoasă în munți.',
    facts: 'Aici cresc flori rare de munte.',
    funFact: 'Ursul brun a fost văzut aici în 2023!',
  );

  group('PromptTemplates', () {
    test('builds Romanian system prompt with knowledge base', () {
      final prompt = PromptTemplates.buildSystemPrompt(
        locationName: 'Poiana Mare',
        knowledgeBase: testKb,
        language: 'ro',
      );

      expect(prompt, contains('ghid distractiv'));
      expect(prompt, contains('Poiana Mare'));
      expect(prompt, contains('O poiană frumoasă'));
      expect(prompt, contains('flori rare'));
      expect(prompt, contains('Ursul brun'));
    });

    test('builds Hungarian system prompt', () {
      final prompt = PromptTemplates.buildSystemPrompt(
        locationName: 'Poiana Mare',
        knowledgeBase: testKb,
        language: 'hu',
      );

      expect(prompt, contains('tábori vezető'));
      expect(prompt, contains('Poiana Mare'));
    });

    test('builds full prompt with conversation history', () {
      final messages = [
        ChatMessage.user('Ce animale trăiesc aici?'),
        ChatMessage.assistant('În această zonă poți întâlni urși bruni.'),
      ];

      final fullPrompt = PromptTemplates.buildFullPrompt(
        locationName: 'Poiana Mare',
        knowledgeBase: testKb,
        language: 'ro',
        messages: messages,
      );

      expect(fullPrompt, contains('ghid distractiv'));
      expect(fullPrompt, contains('Copil: Ce animale'));
      expect(fullPrompt, contains('Ghid: În această zonă'));
      expect(fullPrompt, endsWith('Ghid:'));
    });

    test('uses Gyerek/Vezető labels for Hungarian', () {
      final messages = [ChatMessage.user('Milyen állatok élnek itt?')];

      final fullPrompt = PromptTemplates.buildFullPrompt(
        locationName: 'Poiana Mare',
        knowledgeBase: testKb,
        language: 'hu',
        messages: messages,
      );

      expect(fullPrompt, contains('Gyerek: Milyen'));
      expect(fullPrompt, endsWith('Vezető:'));
    });
  });
}
