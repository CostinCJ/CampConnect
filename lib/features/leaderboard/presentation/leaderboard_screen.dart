import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/core/l10n/localized_team_names.dart';
import 'package:camp_connect/core/theme/team_colors.dart';
import 'package:camp_connect/core/utils/relative_time.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/core/theme/app_theme.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';
import '../domain/points_entry.dart';
import '../domain/team.dart';
import 'points_entry_details.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(leaderboardProvider);
    final historyAsync = ref.watch(pointsHistoryProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final userTeam = appUser?.team;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.leaderboard)),
      body: teamsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.somethingWentWrong),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(leaderboardProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (teams) {
          if (teams.isEmpty) {
            return EmptyState(icon: Icons.leaderboard, title: l10n.noTeamsYet);
          }

          return CustomScrollView(
            slivers: [
              // Team Rankings section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: SectionHeader(l10n.teamRankings),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _TeamRankCard(
                      team: teams[index],
                      rank: index + 1,
                      isUserTeam: teams[index].id == userTeam,
                    ),
                    childCount: teams.length,
                  ),
                ),
              ),

              // Recent Activity section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: SectionHeader(l10n.recentActivity),
                ),
              ),
              historyAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
                error: (_, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(l10n.somethingWentWrong),
                  ),
                ),
                data: (history) {
                  if (history.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 32,
                        ),
                        child: Center(
                          child: Text(
                            l10n.noPointsHistory,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _PointsHistoryTile(entry: history[index]),
                        childCount: history.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TeamRankCard extends StatelessWidget {
  final Team team;
  final int rank;
  final bool isUserTeam;

  const _TeamRankCard({
    required this.team,
    required this.rank,
    required this.isUserTeam,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final teamColor = team.color;

    final onTeamColor = HeroCard.onColor(teamColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: isUserTeam
              ? Color.alphaBlend(
                  teamColor.withValues(alpha: 0.12),
                  theme.cardTheme.color!,
                )
              : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: isUserTeam ? Border.all(color: teamColor, width: 2) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Rank in a team-colored squircle; #1 gets the trophy
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: teamColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: rank == 1
                    ? Icon(Icons.emoji_events, color: onTeamColor, size: 24)
                    : Text(
                        '$rank',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: onTeamColor,
                        ),
                      ),
              ),
              const SizedBox(width: 14),

              // Team name + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedTeamName(l10n, team.name),
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isUserTeam)
                      Text(
                        l10n.yourTeamBadge,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),

              // Points, in the team's color (contrast-guarded)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${team.points}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: TeamColors.emphasis(teamColor, theme.brightness),
                    ),
                  ),
                  Text(l10n.pts, style: theme.textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsHistoryTile extends StatelessWidget {
  final PointsEntry entry;

  const _PointsHistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final teamColor = TeamColors.forTeam(
      entry.team,
      entry.teamColorHex,
      entry.teamName,
    );
    final teamName = localizedTeamName(
      l10n,
      entry.teamName.isNotEmpty ? entry.teamName : entry.team,
    );
    final isPositive = entry.amount >= 0;

    final camp = theme.extension<CampColors>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showPointsEntryDetails(
            context,
            entry: entry,
            teamName: teamName,
            teamColor: teamColor,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Team color dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: teamColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),

                // Reason and team name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.reason.isNotEmpty ? entry.reason : '—',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '$teamName · ${relativeTime(l10n, entry.timestamp)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Points change: green family for gains, sunset orange for
                // deductions (red stays reserved for emergency UI)
                StatPill(
                  label: '${isPositive ? '+' : ''}${entry.amount}',
                  background: isPositive
                      ? theme.colorScheme.primaryContainer
                      : camp.sunsetSoft,
                  foreground: isPositive
                      ? theme.colorScheme.onPrimaryContainer
                      : camp.onSunsetSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
