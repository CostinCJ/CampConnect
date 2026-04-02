import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/core/theme/team_colors.dart';

class KidHomeScreen extends ConsumerWidget {
  const KidHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(appUserProvider);
    final campSessionAsync = ref.watch(activeCampSessionProvider);
    final teamsAsync = ref.watch(leaderboardProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

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

          final teamColor = TeamColors.getColor(appUser.team ?? 'blue');
          final lang = ref.watch(settingsProvider).language;
          final teamDisplayName = TeamColors.localizedName(appUser.team ?? 'blue', lang);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome message (use local name for GDPR)
                  Text(
                    '${l10n.hey}, ${ref.watch(localKidNameProvider) ?? appUser.displayName}!',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Camp session name
                  campSessionAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (session) {
                      if (session == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          session.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Team card
                  Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            teamColor,
                            teamColor.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.shield,
                                color: Colors.white.withValues(alpha: 0.9),
                                size: 28,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                l10n.yourTeam,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            teamDisplayName,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Stats
                  Text(
                    l10n.quickStats,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Icons.emoji_events,
                          label: l10n.teamPoints,
                          value: teamsAsync.whenOrNull(
                                data: (teams) {
                                  final userTeamData = teams
                                      .where((t) => t.color == appUser.team)
                                      .firstOrNull;
                                  return userTeamData?.points.toString();
                                },
                              ) ??
                              '--',
                          color: teamColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Icons.military_tech,
                          label: l10n.teamRank,
                          value: teamsAsync.whenOrNull(
                                data: (teams) {
                                  if (teams.isEmpty) return '--';
                                  final rank = teams.indexWhere(
                                          (t) => t.color == appUser.team) +
                                      1;
                                  return rank > 0
                                      ? '#$rank/${teams.length}'
                                      : '--';
                                },
                              ) ??
                              '--',
                          color: theme.colorScheme.secondary,
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
