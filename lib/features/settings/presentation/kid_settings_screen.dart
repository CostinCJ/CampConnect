import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class KidSettingsScreen extends ConsumerWidget {
  const KidSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

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
                value: 'en',
                label: Text(l10n.english),
              ),
              ButtonSegment<String>(
                value: 'ro',
                label: Text(l10n.romanian),
              ),
              ButtonSegment<String>(
                value: 'hu',
                label: Text(l10n.hungarian),
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
              try {
                // Unsubscribe from FCM topics before signing out
                final campId = ref.read(activeCampIdProvider);
                final user = ref.read(appUserProvider).valueOrNull;
                if (campId != null) {
                  try {
                    await ref.read(fcmServiceProvider).unsubscribeFromTopics(campId, team: user?.team);
                  } catch (_) {
                    // FCM unsubscribe is best-effort; continue with logout
                  }
                }
                final authRepo = ref.read(authRepositoryProvider);
                await authRepo.signOut();
              } catch (e) {
                debugPrint('[Logout] signOut failed: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.somethingWentWrong)),
                  );
                }
              }
              // Always navigate away, even if signOut failed
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
