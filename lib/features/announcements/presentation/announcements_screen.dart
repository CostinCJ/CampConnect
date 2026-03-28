import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/features/announcements/domain/announcement.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// Kid view: tabbed — announcements feed + program/schedule view.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final announcementsAsync = ref.watch(announcementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.announcementsFeed),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.announcements),
            Tab(text: l10n.program),
          ],
        ),
      ),
      body: announcementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.somethingWentWrong)),
        data: (all) {
          final announcements = all.where((a) => !a.isSchedule).toList();
          final scheduleItems = all.where((a) => a.isSchedule).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _AnnouncementFeed(announcements: announcements),
              _KidScheduleView(scheduleItems: scheduleItems),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// ANNOUNCEMENTS TAB (kid read-only)
// =============================================================================

class _AnnouncementFeed extends StatelessWidget {
  final List<Announcement> announcements;

  const _AnnouncementFeed({required this.announcements});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.campaign_outlined,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(l10n.noAnnouncementsYet,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: announcements.length,
      itemBuilder: (context, index) =>
          _AnnouncementCard(announcement: announcements[index]),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;

  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: announcement.pinned
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant,
          width: announcement.pinned ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (announcement.pinned) ...[
                  Icon(Icons.push_pin, size: 16,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(l10n.pinned,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                ],
                const Spacer(),
                Text(l10n.relativeTime(announcement.timestamp),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 12),
            Text(announcement.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (announcement.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(announcement.body, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            Text('${l10n.postedBy} ${announcement.createdByName}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PROGRAM / SCHEDULE TAB (kid read-only)
// =============================================================================

class _KidScheduleView extends StatelessWidget {
  final List<Announcement> scheduleItems;

  const _KidScheduleView({required this.scheduleItems});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (scheduleItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(l10n.noScheduleEntries,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    // Group by scheduledDate, sorted ascending
    final grouped = <DateTime, List<Announcement>>{};
    for (final item in scheduleItems) {
      final date = item.scheduledDate ?? item.timestamp;
      final dayKey = DateTime(date.year, date.month, date.day);
      grouped.putIfAbsent(dayKey, () => []).add(item);
    }

    for (final entries in grouped.values) {
      entries.sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));
    }

    final sortedDays = grouped.keys.toList()..sort();
    final dateFormat = DateFormat('EEEE, d MMMM yyyy');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final entries = grouped[day]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: EdgeInsets.only(bottom: 8, top: index == 0 ? 0 : 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                dateFormat.format(day),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),

            // Timeline entries
            ...entries.map((item) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Time column
                        Container(
                          width: 72,
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                item.startTime ?? '--:--',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      theme.colorScheme.onTertiaryContainer,
                                ),
                              ),
                              if (item.endTime != null) ...[
                                Text('|',
                                    style: TextStyle(
                                        color: theme
                                            .colorScheme.onTertiaryContainer
                                            .withValues(alpha: 0.4))),
                                Text(
                                  item.endTime!,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        theme.colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              if (item.body.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(item.body,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}
