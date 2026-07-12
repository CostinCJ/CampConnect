import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/features/auth/data/session_auto_select.dart';
import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/services/logo_cache_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _routed = false;

  Future<void> _route(AppUser? user) async {
    if (_routed || !mounted) return;
    _routed = true;
    if (user == null) {
      context.go('/role-selection');
      return;
    }

    // The user is signed in, so it's now in-context (and, for returning users,
    // the right moment) to ask for notification permission — never at cold
    // start before login.
    ref.read(fcmServiceProvider).requestPermission();

    if (user.isGuide) {
      // Session cleanup runs server-side on a schedule (cleanupExpiredCamps).
      var campId = user.campId;
      if (campId == null) {
        // New guide in an org with a running session: select it for them
        // instead of dropping them on an empty dashboard.
        final auto = await autoSelectActiveSession(ref, user);
        campId = auto?.id;
      }
      if (campId != null) {
        ref.read(fcmServiceProvider).subscribeToTopics(
              campId: campId,
              role: user.role,
            );
      }
      if (!mounted) return;
      context.go('/guide');
    } else {
      // Subscribe to FCM topics for kid (including team)
      if (user.campId != null) {
        ref.read(fcmServiceProvider).subscribeToTopics(
              campId: user.campId!,
              role: user.role,
              team: user.team,
            );
      }
      // Refresh the cached org logo (fire-and-forget) so the PDF export
      // works offline even if the logo was updated since the last login.
      LogoCacheService.fetchAndCache();
      context.go('/kid');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final appUser = ref.watch(appUserProvider);

    ref.listen(appUserProvider, (previous, next) {
      if (next is AsyncData<AppUser?>) _route(next.value);
    });

    // Handle the value being ALREADY resolved when this screen builds
    // (no change event fires for the listener above in that case).
    if (appUser is AsyncData<AppUser?>) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _route(appUser.value));
    }

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(34),
              ),
              child: Icon(
                Icons.forest,
                size: 56,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.appName,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
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
                      onPressed: () {
                        _routed = false;
                        ref.invalidate(appUserProvider);
                      },
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
