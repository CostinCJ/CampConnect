import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// Day-0 onboarding for a fresh org owner: create a session, invite guides,
/// generate kid codes. Steps derive from live data (never persisted); the
/// card hides itself for non-owners, when everything is done, or when
/// manually dismissed (dismissal stored locally per uid).
class Day0ChecklistCard extends ConsumerStatefulWidget {
  const Day0ChecklistCard({super.key});

  @override
  ConsumerState<Day0ChecklistCard> createState() => _Day0ChecklistCardState();
}

class _Day0ChecklistCardState extends ConsumerState<Day0ChecklistCard> {
  String _dismissKey(String uid) => 'day0_dismissed_$uid';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final org = ref.watch(currentOrganizationProvider).valueOrNull;
    if (user == null || org == null || org.ownerUid != user.uid) {
      return const SizedBox.shrink();
    }

    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs.getBool(_dismissKey(user.uid)) ?? false) {
      return const SizedBox.shrink();
    }

    final sessions = ref.watch(guideCampSessionsProvider).valueOrNull ?? [];
    final members = ref.watch(orgMembersProvider).valueOrNull ?? [];
    final codes = ref.watch(codesForActiveCampProvider).valueOrNull ?? [];

    final hasSession = sessions.isNotEmpty;
    final hasGuides = members.length >= 2;
    final hasCodes = codes.isNotEmpty;
    if (hasSession && hasGuides && hasCodes) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    // Bottom gap lives inside the widget so it collapses with the card in the
    // hidden states above (non-owner / all done / dismissed).
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.day0Title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.dismiss,
                    onPressed: () async {
                      await prefs.setBool(_dismissKey(user.uid), true);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
              _StepRow(
                done: hasSession,
                label: l10n.stepCreateSession,
                onTap: () => context.push('/guide/camp-sessions'),
              ),
              _StepRow(
                done: hasGuides,
                label: l10n.stepInviteGuides,
                onTap: () => SharePlus.instance.share(
                  ShareParams(
                    text: l10n.shareInviteMessage(org.name, org.inviteCode),
                  ),
                ),
              ),
              _StepRow(
                done: hasCodes,
                label: l10n.stepGenerateCodes,
                onTap: () => context.go('/guide/codes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.done,
    required this.label,
    required this.onTap,
  });

  final bool done;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          decoration: done ? TextDecoration.lineThrough : null,
        ),
      ),
      trailing: done ? null : const Icon(Icons.arrow_forward_rounded, size: 18),
      onTap: done ? null : onTap,
    );
  }
}
