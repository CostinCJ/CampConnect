import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/map/domain/location.dart';

void main() {
  test('QuizQuestion map round-trip', () {
    const q = QuizQuestion(
      question: 'Ce vezi aici?',
      options: ['Un lac', 'Un munte', 'O cetate'],
      correctIndex: 2,
    );
    final restored = QuizQuestion.fromMap(q.toMap());
    expect(restored.question, 'Ce vezi aici?');
    expect(restored.options, hasLength(3));
    expect(restored.correctIndex, 2);
  });

  test('KnowledgeBase serializes quiz and counts it in isEmpty', () {
    const kb = KnowledgeBase(
      quiz: [
        QuizQuestion(question: 'Q', options: ['a', 'b'], correctIndex: 0),
      ],
    );
    expect(kb.isEmpty, isFalse);

    final restored = KnowledgeBase.fromMap(kb.toMap());
    expect(restored.quiz, hasLength(1));
    expect(restored.quiz.first.options, ['a', 'b']);
  });

  test('KnowledgeBase without quiz still parses legacy maps', () {
    final restored = KnowledgeBase.fromMap({'description': 'x'});
    expect(restored.quiz, isEmpty);
  });
}
