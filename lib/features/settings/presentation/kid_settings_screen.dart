import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/core/constants/app_constants.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/widgets/camp_ui.dart';

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
          SectionHeader(l10n.language),
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
          Card(
            child: SwitchListTile(
              title: Text(l10n.darkMode),
              subtitle: Text(settings.isDarkMode
                  ? l10n.darkThemeActive
                  : l10n.lightThemeActive),
              secondary: IconBubble(
                icon:
                    settings.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              ),
              value: settings.isDarkMode,
              onChanged: (_) {
                settingsNotifier.toggleTheme();
              },
            ),
          ),
          const SizedBox(height: 24),

          // Privacy policy
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.privacyPolicy),
              onTap: () => launchUrl(Uri.parse(AppConstants.privacyPolicyUrl)),
            ),
          ),
          const SizedBox(height: 32),

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
          const SizedBox(height: 12),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            icon: const Icon(Icons.delete_forever),
            label: Text(l10n.deleteMyData),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l10n.deleteMyData),
                  content: Text(l10n.deleteAccountWarning),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l10n.cancel)),
                    FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(l10n.delete)),
                  ],
                ),
              );
              if (ok != true) return;
              final uid = ref.read(appUserProvider).valueOrNull?.uid;
              try {
                await ref.read(journalProvider.notifier).clearAll();
                if (uid != null) {
                  await ref.read(localKidNameProvider.notifier).clear(uid);
                }
                await ref.read(authRepositoryProvider).deleteMyAccount();
                if (context.mounted) context.go('/role-selection');
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.somethingWentWrong)),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
