import 'package:camp_connect/l10n/app_localizations.g.dart';

String relativeTime(AppL10n l10n, DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.hoursAgo(diff.inHours);
  return l10n.daysAgo(diff.inDays);
}
