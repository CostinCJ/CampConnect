import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/core/theme/team_colors.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import '../domain/points_entry.dart';
import '../domain/team.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamsAsync = ref.watch(leaderboardProvider);
    final historyAsync = ref.watch(pointsHistoryProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final userTeam = appUser?.team;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.leaderboard),
      ),
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
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.leaderboard,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noTeamsYet,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              // Team Rankings section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Text(
                    l10n.teamRankings,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _TeamRankCard(
                      team: teams[index],
                      rank: index + 1,
                      isUserTeam: teams[index].color == userTeam,
                    ),
                    childCount: teams.length,
                  ),
                ),
              ),

              // Recent Activity section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Text(
                    l10n.recentActivity,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
    final l10n = AppLocalizations.of(context);
    final teamColor = TeamColors.getColor(team.color);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: isUserTeam ? 2 : 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isUserTeam ? teamColor : theme.colorScheme.outlineVariant,
            width: isUserTeam ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Rank number
              SizedBox(
                width: 36,
                child: Text(
                  '#$rank',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: rank <= 3
                        ? teamColor
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              // Team color indicator
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: teamColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: rank == 1
                    ? const Icon(Icons.emoji_events, color: Colors.white, size: 22)
                    : null,
              ),
              const SizedBox(width: 14),

              // Team name + badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      TeamColors.displayName(team.color),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isUserTeam)
                      Text(
                        l10n.yourTeamBadge,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: teamColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),

              // Points
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${team.points}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: teamColor,
                    ),
                  ),
                  Text(
                    l10n.pts,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
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
    final l10n = AppLocalizations.of(context);
    final teamColor = TeamColors.getColor(entry.team);
    final isPositive = entry.amount >= 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
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
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${TeamColors.displayName(entry.team)} · ${l10n.relativeTime(entry.timestamp)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Points change
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${isPositive ? '+' : ''}${entry.amount}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
