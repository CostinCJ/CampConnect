import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/announcements/domain/announcement.dart';
import 'package:camp_connect/features/journal/domain/journal_entry.dart';
import 'package:camp_connect/features/journal/domain/prompt_answer.dart';

Announcement _prompt(String title, DateTime ts) => Announcement(
      id: 'p1',
      title: title,
      body: '',
      type: 'prompt',
      pinned: false,
      createdBy: 'g1',
      createdByName: 'Guide',
      timestamp: ts,
    );

JournalEntry _entry({String? prompt, required DateTime date}) => JournalEntry(
      id: 'e1',
      date: date,
      title: 't',
      body: 'b',
      prompt: prompt,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  final day = DateTime(2026, 7, 12, 9);

  test('answered when an entry adopted the prompt on the same day', () {
    final entries = [
      _entry(prompt: 'How was the hike?', date: DateTime(2026, 7, 12, 20))
    ];
    expect(hasAnsweredPrompt(entries, _prompt('How was the hike?', day)), isTrue);
  });

  test('not answered by an entry from another day', () {
    final entries = [
      _entry(prompt: 'How was the hike?', date: DateTime(2026, 7, 11))
    ];
    expect(hasAnsweredPrompt(entries, _prompt('How was the hike?', day)), isFalse);
  });

  test('not answered by entries without that prompt', () {
    final entries = [_entry(prompt: null, date: day)];
    expect(hasAnsweredPrompt(entries, _prompt('How was the hike?', day)), isFalse);
  });
}
