import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/features/organization/domain/organization.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class GuideSettingsScreen extends ConsumerWidget {
  const GuideSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Organisation info
          if (appUser?.orgId != null) ...[
            _OrganizationSection(orgId: appUser!.orgId!, uid: appUser.uid),
            const SizedBox(height: 24),
          ],

          // Guide-specific management links
          Text(
            l10n.campManagement,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(l10n.campSessionManagement),
                  subtitle: Text(l10n.campSessionManagementSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/guide/camp-sessions'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.qr_code),
                  title: Text(l10n.codeManagement),
                  subtitle: Text(l10n.codeManagementSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/guide/codes'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.map),
                  title: Text(l10n.mapLocations),
                  subtitle: Text(l10n.mapLocationsSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/guide/settings/locations'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.groups),
                  title: Text(l10n.teams),
                  subtitle: Text(l10n.teamsManagementSubtitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/guide/settings/teams'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

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
                if (campId != null) {
                  try {
                    await ref.read(fcmServiceProvider).unsubscribeFromTopics(campId);
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

class _OrganizationSection extends ConsumerWidget {
  final String orgId;
  final String uid;

  const _OrganizationSection({required this.orgId, required this.uid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<Organization?>(
      future: ref.read(organizationRepositoryProvider).getOrganization(orgId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final org = snapshot.data;
        if (org == null) {
          return const SizedBox.shrink();
        }

        final isOwner = org.ownerUid == uid;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              org.name,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.business_outlined),
                    title: Text(org.name),
                  ),
                  if (isOwner) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.vpn_key_outlined),
                      title: Text(l10n.organizationInviteCode),
                      subtitle: Text(org.inviteCode),
                      trailing: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: org.inviteCode),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.inviteCodeCopied)),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
