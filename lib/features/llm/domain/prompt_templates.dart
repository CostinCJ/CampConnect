import 'package:camp_connect/features/llm/domain/chat_message.dart';
import 'package:camp_connect/features/map/domain/location.dart';

class PromptTemplates {
  PromptTemplates._();

  static String buildSystemPrompt({
    required String locationName,
    required KnowledgeBase knowledgeBase,
    required String language,
  }) {
    if (language == 'hu') {
      return _buildHungarianSystemPrompt(locationName, knowledgeBase);
    }
    return _buildRomanianSystemPrompt(locationName, knowledgeBase);
  }

  static String buildFullPrompt({
    required String locationName,
    required KnowledgeBase knowledgeBase,
    required String language,
    required List<ChatMessage> messages,
  }) {
    final systemPrompt = buildSystemPrompt(
      locationName: locationName,
      knowledgeBase: knowledgeBase,
      language: language,
    );

    final userLabel = language == 'hu' ? 'Gyerek' : 'Copil';
    final assistantLabel = language == 'hu' ? 'Vezető' : 'Ghid';

    final buffer = StringBuffer(systemPrompt);
    buffer.writeln();

    for (final msg in messages) {
      if (msg.role == ChatRole.user) {
        buffer.writeln('$userLabel: ${msg.content}');
      } else if (msg.role == ChatRole.assistant) {
        buffer.writeln('$assistantLabel: ${msg.content}');
      }
    }

    buffer.write('$assistantLabel:');
    return buffer.toString();
  }

  static String _buildRomanianSystemPrompt(
    String locationName,
    KnowledgeBase kb,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Răspunde folosind DOAR informațiile de mai jos. Fii prietenos și scurt.');
    buffer.writeln();
    buffer.writeln('Locație: $locationName');
    if (kb.description.isNotEmpty) {
      buffer.writeln('Descriere: ${kb.description}');
    }
    if (kb.facts.isNotEmpty) {
      buffer.writeln('Fapte: ${kb.facts}');
    }
    if (kb.funFact.isNotEmpty) {
      buffer.writeln('Fapt amuzant: ${kb.funFact}');
    }
    buffer.writeln();
    return buffer.toString();
  }

  static String _buildHungarianSystemPrompt(
    String locationName,
    KnowledgeBase kb,
  ) {
    final buffer = StringBuffer();
    if (kb.isEmpty) {
      buffer.writeln('Te egy tábori vezető vagy. A(z) "$locationName" helyszínhez még nincs információ hozzáadva. Mondd a gyereknek, hogy kérje meg a vezetőt, hogy adjon hozzá információkat erről a helyről.');
      return buffer.toString();
    }
    buffer.writeln('Válaszolj CSAK az alábbi információk alapján. Légy barátságos és rövid.');
    buffer.writeln();
    buffer.writeln('Helyszín: $locationName');
    if (kb.description.isNotEmpty) {
      buffer.writeln('Leírás: ${kb.description}');
    }
    if (kb.facts.isNotEmpty) {
      buffer.writeln('Tények: ${kb.facts}');
    }
    if (kb.funFact.isNotEmpty) {
      buffer.writeln('Érdekes tény: ${kb.funFact}');
    }
    buffer.writeln();
    return buffer.toString();
  }
}
