import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/core/l10n/app_localizations.dart';

class KidNavigationShell extends StatelessWidget {
  final Widget child;
  final GoRouterState state;

  const KidNavigationShell({
    super.key,
    required this.child,
    required this.state,
  });

  int _selectedIndex(String location) {
    if (location.startsWith('/kid/leaderboard')) return 1;
    if (location.startsWith('/kid/map')) return 2;
    if (location.startsWith('/kid/journal')) return 3;
    if (location.startsWith('/kid/news')) return 4;
    if (location.startsWith('/kid/settings')) return 5;
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
              context.go('/kid');
            case 1:
              context.go('/kid/leaderboard');
            case 2:
              context.go('/kid/map');
            case 3:
              context.go('/kid/journal');
            case 4:
              context.go('/kid/news');
            case 5:
              context.go('/kid/settings');
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
            icon: const Icon(Icons.book),
            label: l10n.journal,
          ),
          NavigationDestination(
            icon: const Icon(Icons.newspaper),
            label: l10n.news,
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
