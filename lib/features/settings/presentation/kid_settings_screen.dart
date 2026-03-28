import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class KidSettingsScreen extends ConsumerWidget {
  const KidSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Language selector
          Text(
            l10n.language,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment<String>(
                value: 'ro',
                label: Text(l10n.romanian),
                icon: const Icon(Icons.language),
              ),
              ButtonSegment<String>(
                value: 'hu',
                label: Text(l10n.hungarian),
                icon: const Icon(Icons.language),
              ),
            ],
            selected: {settings.language},
            onSelectionChanged: (selected) {
              settingsNotifier.setLanguage(selected.first);
            },
          ),
          const SizedBox(height: 24),

          // Dark/Light mode toggle
          SwitchListTile(
            title: Text(l10n.darkMode),
            subtitle: Text(settings.isDarkMode ? l10n.darkThemeActive : l10n.lightThemeActive),
            secondary: Icon(
              settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            ),
            value: settings.isDarkMode,
            onChanged: (_) {
              settingsNotifier.toggleTheme();
            },
          ),
          const Divider(),
          const SizedBox(height: 24),

          // Logout button
          FilledButton.tonalIcon(
            onPressed: () async {
              // Unsubscribe from FCM topics before signing out
              final campId = ref.read(activeCampIdProvider);
              final user = ref.read(appUserProvider).valueOrNull;
              if (campId != null) {
                await ref.read(fcmServiceProvider).unsubscribeFromTopics(campId, team: user?.team);
              }
              final authRepo = ref.read(authRepositoryProvider);
              await authRepo.signOut();
              if (context.mounted) {
                context.go('/role-selection');
              }
            },
            icon: const Icon(Icons.logout),
            label: Text(l10n.logout),
          ),
        ],
      ),
    );
  }
}
