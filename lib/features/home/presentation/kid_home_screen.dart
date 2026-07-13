import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camp_connect/core/l10n/localized_team_names.dart';
import 'package:camp_connect/features/announcements/domain/announcement.dart';
import 'package:camp_connect/features/announcements/presentation/announcements_screen.dart'
    show showAnnouncementDetails;
import 'package:camp_connect/features/leaderboard/domain/celebration.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';

class KidHomeScreen extends ConsumerWidget {
  const KidHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(appUserProvider);
    final campSessionAsync = ref.watch(activeCampSessionProvider);
    final teamsAsync = ref.watch(leaderboardProvider);
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return Scaffold(
      body: appUserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.somethingWentWrong),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(appUserProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (appUser) {
          if (appUser == null) {
            return Center(child: Text(l10n.noUserFound));
          }

          final teams = teamsAsync.valueOrNull ?? const [];
          final kidTeam = teams.where((t) => t.id == appUser.team).firstOrNull;
          final teamColor = kidTeam?.color ?? theme.colorScheme.secondary;
          final teamDisplayName = kidTeam != null
              ? localizedTeamName(l10n, kidTeam.name)
              : l10n.noTeamsYet;
          final onTeamColor = HeroCard.onColor(teamColor);
          final rank = teams.indexWhere((t) => t.id == appUser.team) + 1;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome message (use local name for GDPR)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${l10n.hey}, ${ref.watch(localKidNameProvider) ?? appUser.displayName}!',
                          style: theme.textTheme.headlineLarge,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined),
                        tooltip: l10n.settings,
                        onPressed: () => context.go('/kid/settings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  campSessionAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (session) {
                      if (session == null) return const SizedBox.shrink();
                      return Row(
                        children: [
                          Icon(
                            Icons.forest,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              session.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  HeroCard(
                    color: teamColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.shield,
                              color: onTeamColor.withValues(alpha: 0.9),
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.yourTeam,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: onTeamColor.withValues(alpha: 0.85),
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          teamDisplayName,
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: onTeamColor,
                          ),
                        ),
                        if (kidTeam != null) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              StatPill(
                                icon: Icons.emoji_events,
                                label: '${kidTeam.points} ${l10n.pointsShort}',
                                background: onTeamColor.withValues(alpha: 0.16),
                                foreground: onTeamColor,
                              ),
                              if (rank > 0) ...[
                                const SizedBox(width: 8),
                                StatPill(
                                  icon: Icons.military_tech,
                                  label: '#$rank/${teams.length}',
                                  background: onTeamColor.withValues(
                                    alpha: 0.16,
                                  ),
                                  foreground: onTeamColor,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  _TodayPointsCard(teamId: appUser.team, teamColor: teamColor),

                  const _UpNextCard(),

                  SectionHeader(l10n.quickStats),

                  // IntrinsicHeight + stretch keeps all three cards equal-height
                  // even when one label fits on a single line in some locales
                  // (e.g. English "Team rank") while siblings wrap to two.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.emoji_events,
                            label: l10n.teamPoints,
                            value: kidTeam?.points.toString() ?? '--',
                            color: teamColor,
                            onTap: () => context.go('/kid/leaderboard'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.military_tech,
                            label: l10n.teamRank,
                            value: teams.isEmpty
                                ? '--'
                                : rank > 0
                                ? '#$rank/${teams.length}'
                                : '--',
                            color: theme.colorScheme.primary,
                            onTap: () => context.go('/kid/leaderboard'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.book,
                            label: l10n.journalEntries,
                            value:
                                ref
                                    .watch(journalProvider)
                                    .whenOrNull(
                                      data: (entries) =>
                                          entries.length.toString(),
                                    ) ??
                                '0',
                            color: theme.colorScheme.tertiary,
                            onTap: () => context.go('/kid/journal'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _PassportTile(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: Color.alphaBlend(
        color.withValues(alpha: 0.12),
        theme.cardTheme.color!,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconBubble(
                icon: icon,
                size: 40,
                background: color.withValues(alpha: 0.18),
                foreground: color,
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Surfaces the single most relevant "what's happening" item on the kid
/// home screen: the next upcoming schedule entry, or failing that the most
/// recently pinned announcement. Renders as a spacer-only [SizedBox] when
/// there's nothing to show, so the layout gap before "Quick Stats" is
/// preserved either way.
class _UpNextCard extends ConsumerWidget {
  const _UpNextCard();

  /// Minutes since midnight for a "HH:mm" string, or 0 if unparseable —
  /// schedule entries without a valid time sort to the start of their day.
  int _minutesOf(String? time) {
    if (time == null) return 0;
    final parts = time.split(':');
    if (parts.length != 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final announcements =
        ref.watch(announcementsProvider).valueOrNull ?? const <Announcement>[];
    final now = DateTime.now();

    Announcement? nextScheduleItem;
    DateTime? nextScheduleAt;
    for (final item in announcements) {
      if (!item.isSchedule || item.scheduledDate == null) continue;
      final date = item.scheduledDate!;
      final minutes = _minutesOf(item.startTime);
      final at = DateTime(date.year, date.month, date.day)
          .add(Duration(minutes: minutes));
      if (at.isBefore(now)) continue;
      if (nextScheduleAt == null || at.isBefore(nextScheduleAt)) {
        nextScheduleAt = at;
        nextScheduleItem = item;
      }
    }

    if (nextScheduleItem != null) {
      final item = nextScheduleItem;
      return Padding(
        padding: const EdgeInsets.only(top: 28),
        child: _UpNextTile(
          icon: Icons.event_available,
          label: l10n.upNext,
          title: item.title,
          subtitle: item.timeRange,
          accentColor: theme.colorScheme.tertiary,
          // A schedule item lives on the Program tab, not the Announcements
          // feed — deep-link straight to it.
          onTap: () => context.go('/kid/news?tab=program'),
        ),
      );
    }

    final pinned =
        announcements.where((a) => !a.isSchedule && a.pinned).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (pinned.isNotEmpty) {
      final item = pinned.first;
      return Padding(
        padding: const EdgeInsets.only(top: 28),
        child: _UpNextTile(
          icon: Icons.push_pin,
          label: l10n.pinned,
          title: item.title,
          subtitle: item.body,
          accentColor: theme.colorScheme.primary,
          onTap: () => showAnnouncementDetails(context, item),
        ),
      );
    }

    return const SizedBox(height: 28);
  }
}

class _UpNextTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _UpNextTile({
    required this.icon,
    required this.label,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconBubble(
                icon: icon,
                background: accentColor.withValues(alpha: 0.16),
                foreground: accentColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Today for your team: +X points" digest. Hidden entirely when nothing
/// was earned today, so the home layout stays identical on quiet days.
class _TodayPointsCard extends ConsumerWidget {
  final String? teamId;
  final Color teamColor;

  const _TodayPointsCard({required this.teamId, required this.teamColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final history = ref.watch(pointsHistoryProvider).valueOrNull ?? const [];
    final earned = pointsEarnedToday(history, teamId, DateTime.now());
    if (earned <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/kid/leaderboard'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                IconBubble(
                  icon: Icons.trending_up,
                  background: teamColor.withValues(alpha: 0.16),
                  foreground: teamColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.todayForYourTeam,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                StatPill(
                  label: l10n.pointsTodayValue(earned),
                  background: teamColor.withValues(alpha: 0.16),
                  foreground: teamColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PassportTile extends ConsumerWidget {
  const _PassportTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final stamps = ref.watch(passportProvider).valueOrNull ?? const [];
    final total =
        ref.watch(resolvedSessionLocationsProvider).valueOrNull?.length ?? 0;
    if (total == 0) return const SizedBox.shrink();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/kid/passport'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconBubble(
                icon: Icons.approval,
                background:
                    theme.colorScheme.tertiary.withValues(alpha: 0.16),
                foreground: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.explorerPassport,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              StatPill(
                label: l10n.stampsProgress(
                  stamps.length > total ? total : stamps.length,
                  total,
                ),
                background:
                    theme.colorScheme.tertiary.withValues(alpha: 0.16),
                foreground: theme.colorScheme.tertiary,
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
