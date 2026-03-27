import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final appUser = ref.watch(appUserProvider);

    ref.listen(appUserProvider, (previous, next) {
      if (next is AsyncData) {
        final user = next.value;
        if (user == null) {
          context.go('/role-selection');
        } else if (user.isGuide) {
          // Run session cleanup in the background for guides
          ref.read(campRepositoryProvider).cleanupExpiredSessions(user.uid);
          context.go('/guide');
        } else {
          context.go('/kid');
        }
      }
    });

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forest,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.appName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 48),
            if (appUser is AsyncLoading || appUser is! AsyncError)
              const CircularProgressIndicator(),
            if (appUser is AsyncError)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Text(
                      l10n.somethingWentWrong,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(appUserProvider),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
