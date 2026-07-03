import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/announcements/domain/announcement.dart';

void main() {
  test('copyWith can clear endTime via a sentinel', () {
    final a = Announcement(
      id: '1', title: 't', body: 'b', type: 'schedule', pinned: false,
      createdBy: 'g', createdByName: 'G', timestamp: DateTime(2026),
      startTime: '09:00', endTime: '10:00',
    );
    final cleared = a.copyWith(clearEndTime: true);
    expect(cleared.endTime, isNull);
    // Unrelated fields preserved.
    expect(cleared.startTime, '09:00');
    // Without the flag, endTime is preserved.
    expect(a.copyWith(title: 'x').endTime, '10:00');
  });
}
