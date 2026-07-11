import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/announcements/domain/announcement.dart';
import 'package:camp_connect/features/announcements/domain/prompt_utils.dart';

void main() {
  Announcement item(String type, DateTime ts, {String title = 't'}) =>
      Announcement(
        id: ts.toIso8601String(),
        title: title,
        body: '',
        type: type,
        pinned: false,
        createdBy: 'g',
        createdByName: 'Guide',
        timestamp: ts,
      );

  test('isPrompt only for type prompt', () {
    expect(item('prompt', DateTime(2026)).isPrompt, isTrue);
    expect(item('announcement', DateTime(2026)).isPrompt, isFalse);
    expect(item('schedule', DateTime(2026)).isPrompt, isFalse);
  });

  test('activePrompt returns the latest prompt posted today, else null', () {
    final now = DateTime(2026, 7, 10, 18, 0);
    final all = [
      item('prompt', DateTime(2026, 7, 10, 8, 0), title: 'morning'),
      item('prompt', DateTime(2026, 7, 10, 12, 0), title: 'noon'),
      item('prompt', DateTime(2026, 7, 9, 12, 0), title: 'yesterday'),
      item('announcement', DateTime(2026, 7, 10, 13, 0)),
    ];
    expect(activePrompt(all, now)!.title, 'noon');
    expect(activePrompt([all[2]], now), isNull);
    expect(activePrompt(const [], now), isNull);
  });
}
