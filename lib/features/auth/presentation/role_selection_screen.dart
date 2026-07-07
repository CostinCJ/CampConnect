import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/core/theme/app_theme.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final camp = theme.extension<CampColors>()!;
    final l10n = AppL10n.of(context);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Icon(
                          Icons.forest,
                          size: 48,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.appName,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.roleSelectionTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(flex: 2),
                      _RoleCard(
                        icon: Icons.child_care,
                        label: l10n.imAKid,
                        description: l10n.kidDescription,
                        color: camp.sunsetSoft,
                        onColor: camp.onSunsetSoft,
                        onTap: () => context.go('/kid-login'),
                      ),
                      const SizedBox(height: 16),
                      _RoleCard(
                        icon: Icons.school,
                        label: l10n.imAGuide,
                        description: l10n.guideDescription,
                        color: colorScheme.primaryContainer,
                        onColor: colorScheme.onPrimaryContainer,
                        onTap: () => context.go('/guide-login?mode=join-org'),
                      ),
                      const SizedBox(height: 16),
                      _RoleCard(
                        icon: Icons.add_business_outlined,
                        label: l10n.setupCampTile,
                        description: l10n.setupCampDescription,
                        color: colorScheme.secondaryContainer,
                        onColor: colorScheme.onSecondaryContainer,
                        onTap: () => context.go('/guide-login?mode=create-org'),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.onColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: onColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 30, color: onColor),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: onColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: onColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
