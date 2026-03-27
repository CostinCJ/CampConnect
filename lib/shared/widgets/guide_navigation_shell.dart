import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';

class GuideNavigationShell extends StatelessWidget {
  final Widget child;
  final GoRouterState state;

  const GuideNavigationShell({
    super.key,
    required this.child,
    required this.state,
  });

  int _selectedIndex(String location) {
    if (location.startsWith('/guide/leaderboard')) return 1;
    if (location.startsWith('/guide/map')) return 2;
    if (location.startsWith('/guide/announcements')) return 3;
    if (location.startsWith('/guide/codes')) return 4;
    if (location.startsWith('/guide/emergency')) return 5;
    if (location.startsWith('/guide/settings')) return 6;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = state.uri.toString();
    final currentIndex = _selectedIndex(location);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/guide');
            case 1:
              context.go('/guide/leaderboard');
            case 2:
              context.go('/guide/map');
            case 3:
              context.go('/guide/announcements');
            case 4:
              context.go('/guide/codes');
            case 5:
              context.go('/guide/emergency');
            case 6:
              context.go('/guide/settings');
          }
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home),
            label: l10n.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.leaderboard),
            label: l10n.leaderboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map),
            label: l10n.map,
          ),
          NavigationDestination(
            icon: const Icon(Icons.campaign),
            label: l10n.announcements,
          ),
          NavigationDestination(
            icon: const Icon(Icons.qr_code),
            label: l10n.codes,
          ),
          NavigationDestination(
            icon: const Icon(Icons.emergency),
            label: l10n.emergency,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
