import '../../announcements/domain/announcement.dart';
import 'journal_entry.dart';

/// Whether a local journal entry already answers [prompt]: same adopted
/// prompt title, written on the prompt's calendar day. Local-only by
/// design (the journal never leaves the device), so "answered" is
/// per-device, which matches how kids use one device each.
bool hasAnsweredPrompt(List<JournalEntry> entries, Announcement prompt) {
  final d = prompt.timestamp;
  for (final e in entries) {
    if (e.prompt != prompt.title) continue;
    if (e.date.year == d.year && e.date.month == d.month && e.date.day == d.day) {
      return true;
    }
  }
  return false;
}
