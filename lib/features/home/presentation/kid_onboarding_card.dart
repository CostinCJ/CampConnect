import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// First-run explainer for a kid's very first visit to the home screen:
/// what points and the Explorer Passport are. Dismissal is stored locally
/// per uid (GDPR: no server write) and the card never reappears after that
/// (2026-07-13 critique finding: zero onboarding existed before this).
class KidOnboardingCard extends ConsumerStatefulWidget {
  const KidOnboardingCard({super.key});

  @override
  ConsumerState<KidOnboardingCard> createState() => _KidOnboardingCardState();
}

class _KidOnboardingCardState extends ConsumerState<KidOnboardingCard> {
  String _dismissKey(String uid) => 'kid_onboarding_dismissed_$uid';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs.getBool(_dismissKey(user.uid)) ?? false) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.onboardingTitle,
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
              Text(l10n.onboardingBody, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
