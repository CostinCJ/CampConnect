import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/core/utils/relative_time.dart';
import 'package:camp_connect/features/announcements/domain/announcement.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';

/// Kid view: tabbed — announcements feed + program/schedule view.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  /// Which tab to open on: 0 = Announcements feed, 1 = Program/schedule.
  final int initialTab;

  const AnnouncementsScreen({super.key, this.initialTab = 0});

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
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void didUpdateWidget(covariant AnnouncementsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The route can rebuild this same mounted screen with a different ?tab=
    // (initState won't rerun), e.g. nav-bar "news" after a program deep link.
    if (widget.initialTab != oldWidget.initialTab) {
      _tabController.animateTo(widget.initialTab.clamp(0, 1));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
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

// ANNOUNCEMENTS TAB (kid read-only)

class _AnnouncementFeed extends StatelessWidget {
  final List<Announcement> announcements;

  const _AnnouncementFeed({required this.announcements});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    if (announcements.isEmpty) {
      return EmptyState(
        icon: Icons.campaign_outlined,
        title: l10n.noAnnouncementsYet,
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
    final l10n = AppL10n.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: announcement.pinned
          ? theme.colorScheme.primaryContainer
          : theme.cardTheme.color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showAnnouncementDetails(context, announcement),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (announcement.pinned)
                    StatPill(
                      icon: Icons.push_pin,
                      label: l10n.pinned,
                      background: theme.colorScheme.primary,
                      foreground: theme.colorScheme.onPrimary,
                    ),
                  const Spacer(),
                  Text(
                    relativeTime(l10n, announcement.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: announcement.pinned
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                announcement.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: announcement.pinned
                      ? theme.colorScheme.onPrimaryContainer
                      : null,
                ),
              ),
              if (announcement.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  announcement.body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: announcement.pinned
                        ? theme.colorScheme.onPrimaryContainer
                        : null,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '${l10n.postedBy} ${announcement.createdByName}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: announcement.pinned
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet with the full announcement, for cards whose body gets
/// ellipsized in the feed (and schedule items truncated to two lines).
void showAnnouncementDetails(BuildContext context, Announcement announcement) {
  final theme = Theme.of(context);
  final l10n = AppL10n.of(context);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      builder: (ctx, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (announcement.pinned) ...[
                  StatPill(
                    icon: Icons.push_pin,
                    label: l10n.pinned,
                    background: theme.colorScheme.primary,
                    foreground: theme.colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 8),
                ],
                if (announcement.isSchedule && announcement.startTime != null)
                  StatPill(
                    icon: Icons.schedule,
                    label: announcement.endTime != null
                        ? '${announcement.startTime} – ${announcement.endTime}'
                        : announcement.startTime!,
                    background: theme.colorScheme.tertiaryContainer,
                    foreground: theme.colorScheme.onTertiaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(announcement.title, style: theme.textTheme.headlineSmall),
            if (announcement.body.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(announcement.body, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: 20),
            Text(
              '${l10n.postedBy} ${announcement.createdByName} · '
              '${relativeTime(l10n, announcement.timestamp)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}

// PROGRAM / SCHEDULE TAB (kid read-only)

class _KidScheduleView extends StatelessWidget {
  final List<Announcement> scheduleItems;

  const _KidScheduleView({required this.scheduleItems});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    if (scheduleItems.isEmpty) {
      return EmptyState(
        icon: Icons.calendar_month_outlined,
        title: l10n.noScheduleEntries,
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
    final dateFormat = DateFormat(
      'EEEE, d MMMM yyyy',
      Localizations.localeOf(context).toString(),
    );

    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDays.length,
      itemBuilder: (context, index) {
        final day = sortedDays[index];
        final entries = grouped[day]!;
        final isToday = day == todayKey;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day header — today gets a solid primary fill and a "Today"
            // badge so kids can find "what's happening now" without reading
            // every date.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: EdgeInsets.only(bottom: 10, top: index == 0 ? 0 : 16),
              decoration: BoxDecoration(
                color: isToday
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (isToday) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onPrimary.withValues(
                          alpha: 0.18,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        l10n.todayLabel.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      dateFormat.format(day),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isToday
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Timeline entries
            ...entries.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => showAnnouncementDetails(context, item),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // Time column
                        Container(
                          width: 72,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
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
                                  color: theme.colorScheme.onTertiaryContainer,
                                ),
                              ),
                              if (item.endTime != null) ...[
                                Text(
                                  '|',
                                  style: TextStyle(
                                    color: theme.colorScheme.onTertiaryContainer
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
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
                              Text(
                                item.title,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (item.body.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  item.body,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
