import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:camp_connect/features/home/presentation/day0_checklist_card.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';

class GuideHomeScreen extends ConsumerWidget {
  const GuideHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUserAsync = ref.watch(appUserProvider);
    final campSessionAsync = ref.watch(activeCampSessionProvider);
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return Scaffold(
      body: appUserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(l10n.somethingWentWrong)),
        data: (appUser) {
          if (appUser == null) {
            return Center(child: Text(l10n.noUserFound));
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome message
                  Text(
                    '${l10n.welcome}, ${appUser.displayName}',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.guideDashboard,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Day0ChecklistCard(),

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
                              context.push('/guide/camp-sessions'),
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
                  SectionHeader(l10n.quickActions),

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
                        color: theme.colorScheme.error,
                        onTap: () => context.go('/guide/emergency'),
                      ),
                      _ActionCard(
                        icon: Icons.qr_code,
                        label: l10n.manageCodes,
                        color: theme.colorScheme.tertiary,
                        onTap: () => context.go('/guide/codes'),
                      ),
                      _ActionCard(
                        icon: Icons.groups_outlined,
                        label: l10n.myOrganization,
                        color: theme.colorScheme.secondary,
                        onTap: () => context.push('/guide/organization'),
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
      return DateFormat.yMd(
        Localizations.localeOf(context).toString(),
      ).format(date);
    }

    final onPrimary = theme.colorScheme.onPrimary;

    return HeroCard(
      color: theme.colorScheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event,
                size: 20,
                color: onPrimary.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Text(
                AppL10n.of(context).activeSession,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: onPrimary.withValues(alpha: 0.85),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            campName,
            style: theme.textTheme.headlineSmall?.copyWith(color: onPrimary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatPill(
                icon: Icons.calendar_month,
                label: '${formatDate(startDate)} – ${formatDate(endDate)}',
                background: onPrimary.withValues(alpha: 0.16),
                foreground: onPrimary,
              ),
              const SizedBox(width: 8),
              StatPill(
                icon: Icons.groups,
                label: AppL10n.of(context).teamsCount(teamCount),
                background: onPrimary.withValues(alpha: 0.16),
                foreground: onPrimary,
              ),
            ],
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const IconBubble(icon: Icons.event_busy, size: 64),
            const SizedBox(height: 14),
            Text(
              AppL10n.of(context).noActiveSession,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppL10n.of(context).createSessionPrompt,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add),
              label: Text(AppL10n.of(context).createSession),
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
      color: Color.alphaBlend(
        color.withValues(alpha: 0.10),
        theme.cardTheme.color!,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconBubble(
                icon: icon,
                size: 44,
                background: color.withValues(alpha: 0.16),
                foreground: color,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
