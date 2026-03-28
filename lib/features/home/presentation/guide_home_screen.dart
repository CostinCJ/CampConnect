import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class GuideHomeScreen extends ConsumerWidget {
  const GuideHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(appUserProvider);
    final campSessionAsync = ref.watch(activeCampSessionProvider);
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

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome message
                  Text(
                    '${l10n.welcome}, ${appUser.displayName}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.guideDashboard,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Session overview
                  campSessionAsync.when(
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (session) {
                      if (session == null) {
                        return _NoSessionCard(
                          onCreatePressed: () =>
                              context.go('/guide/camp-sessions'),
                        );
                      }
                      return _SessionOverviewCard(
                        campName: session.name,
                        startDate: session.startDate,
                        endDate: session.endDate,
                        teamCount: session.teams.length,
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Quick Actions
                  Text(
                    l10n.quickActions,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _ActionCard(
                        icon: Icons.add_circle_outline,
                        label: l10n.addPoints,
                        color: theme.colorScheme.primary,
                        onTap: () => context.go('/guide/leaderboard'),
                      ),
                      _ActionCard(
                        icon: Icons.campaign,
                        label: l10n.postAnnouncement,
                        color: theme.colorScheme.secondary,
                        onTap: () => context.go('/guide/announcements'),
                      ),
                      _ActionCard(
                        icon: Icons.emergency,
                        label: l10n.emergencyAlert,
                        color: Colors.red,
                        onTap: () => context.go('/guide/emergency'),
                      ),
                      _ActionCard(
                        icon: Icons.qr_code,
                        label: l10n.manageCodes,
                        color: theme.colorScheme.tertiary,
                        onTap: () => context.go('/guide/codes'),
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

class _SessionOverviewCard extends StatelessWidget {
  final String campName;
  final DateTime startDate;
  final DateTime endDate;
  final int teamCount;

  const _SessionOverviewCard({
    required this.campName,
    required this.startDate,
    required this.endDate,
    required this.teamCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String formatDate(DateTime date) {
      return '${date.month}/${date.day}/${date.year}';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).activeSession,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              campName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${formatDate(startDate)} - ${formatDate(endDate)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppLocalizations.of(context).teamsCount(teamCount),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSessionCard extends StatelessWidget {
  final VoidCallback onCreatePressed;

  const _NoSessionCard({required this.onCreatePressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.event_busy,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).noActiveSession,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).createSessionPrompt,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context).createSession),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 10),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
