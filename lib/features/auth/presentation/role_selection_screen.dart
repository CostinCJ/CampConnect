import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Icon(
                Icons.forest,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.appName,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.roleSelectionTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(flex: 2),
              _RoleCard(
                icon: Icons.school,
                label: l10n.imAGuide,
                description: l10n.guideDescription,
                color: colorScheme.primaryContainer,
                onColor: colorScheme.onPrimaryContainer,
                onTap: () => context.go('/guide-login'),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                icon: Icons.child_care,
                label: l10n.imAKid,
                description: l10n.kidDescription,
                color: colorScheme.secondaryContainer,
                onColor: colorScheme.onSecondaryContainer,
                onTap: () => context.go('/kid-login'),
              ),
              const Spacer(flex: 3),
            ],
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
    return Card(
      elevation: 0,
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Row(
            children: [
              Icon(icon, size: 48, color: onColor),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: onColor,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: onColor.withValues(alpha: 0.8),
                              ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: onColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
