import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'shared/providers/providers.dart';

class CampConnectApp extends ConsumerStatefulWidget {
  const CampConnectApp({super.key});

  @override
  ConsumerState<CampConnectApp> createState() => _CampConnectAppState();
}

class _CampConnectAppState extends ConsumerState<CampConnectApp> {
  @override
  void initState() {
    super.initState();
    _setupFcm();
  }

  Future<void> _setupFcm() async {
    final fcm = ref.read(fcmServiceProvider);

    // Request notification permissions
    await fcm.requestPermission();

    // Handle notification tap when app is in background
    fcm.onMessageOpenedApp((message) {
      _handleNotificationTap(message);
    });

    // Check if app was opened from a notification (cold start)
    final initialMessage = await fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'] as String?;
    final router = ref.read(routerProvider);

    if (type == 'emergency') {
      router.go('/guide/emergency');
    } else if (type == 'announcement') {
      final user = ref.read(appUserProvider).valueOrNull;
      if (user?.isGuide == true) {
        router.go('/guide/announcements');
      } else {
        router.go('/kid/news');
      }
    } else if (type == 'points') {
      final user = ref.read(appUserProvider).valueOrNull;
      if (user?.isGuide == true) {
        router.go('/guide/leaderboard');
      } else {
        router.go('/kid/leaderboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CampConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(settings.language),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
