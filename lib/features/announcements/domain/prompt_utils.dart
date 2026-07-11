import 'announcement.dart';

/// The "question of the day": the most recently posted `type: 'prompt'`
/// announcement from today (device-local calendar day). Null when no prompt
/// was posted today — yesterday's question is stale by design.
Announcement? activePrompt(List<Announcement> all, DateTime now) {
  Announcement? latest;
  for (final a in all) {
    if (!a.isPrompt) continue;
    final t = a.timestamp;
    if (t.year != now.year || t.month != now.month || t.day != now.day) {
      continue;
    }
    if (latest == null || t.isAfter(latest.timestamp)) latest = a;
  }
  return latest;
}
