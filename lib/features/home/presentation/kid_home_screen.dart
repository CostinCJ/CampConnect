import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          child: Text(l10n.somethingWentWrong),
        ),
        data: (appUser) {
          if (appUser == null) {
            return Center(child: Text(l10n.noUserFound));
          }

          final teams = teamsAsync.valueOrNull ?? const [];
          final kidTeam =
              teams.where((t) => t.id == appUser.team).firstOrNull;
          final teamColor = kidTeam?.color ?? theme.colorScheme.secondary;
          final teamDisplayName = kidTeam?.name ?? l10n.noTeamsYet;
          final onTeamColor = HeroCard.onColor(teamColor);
          final rank = teams.indexWhere((t) => t.id == appUser.team) + 1;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome message (use local name for GDPR)
                  Text(
                    '${l10n.hey}, ${ref.watch(localKidNameProvider) ?? appUser.displayName}!',
                    style: theme.textTheme.headlineLarge,
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
                                label:
                                    '${kidTeam.points} ${l10n.pointsShort}',
                                background:
                                    onTeamColor.withValues(alpha: 0.16),
                                foreground: onTeamColor,
                              ),
                              if (rank > 0) ...[
                                const SizedBox(width: 8),
                                StatPill(
                                  icon: Icons.military_tech,
                                  label: '#$rank/${teams.length}',
                                  background:
                                      onTeamColor.withValues(alpha: 0.16),
                                  foreground: onTeamColor,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

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
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.book,
                            label: l10n.journalEntries,
                            value: ref.watch(journalProvider).whenOrNull(
                                      data: (entries) =>
                                          entries.length.toString(),
                                    ) ??
                                '0',
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
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

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconBubble(
              icon: icon,
              size: 40,
              background: color.withValues(alpha: 0.14),
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
    );
  }
}
