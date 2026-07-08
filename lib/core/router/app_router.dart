import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/announcements/presentation/announcements_screen.dart';
import '../../features/announcements/presentation/announcement_management_screen.dart';
import '../../features/announcements/presentation/announcement_templates_screen.dart';
import '../../features/auth/presentation/camp_session_screen.dart';
import '../../features/auth/presentation/code_management_screen.dart';
import '../../features/auth/presentation/guide_login_screen.dart';
import '../../features/auth/presentation/kid_name_screen.dart';
import '../../features/auth/presentation/kid_login_screen.dart';
import '../../features/auth/presentation/role_selection_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/emergency/presentation/emergency_screen.dart';
import '../../features/home/presentation/guide_home_screen.dart';
import '../../features/home/presentation/kid_home_screen.dart';
import '../../features/journal/presentation/journal_detail_screen.dart';
import '../../features/journal/presentation/journal_editor_screen.dart';
import '../../features/journal/presentation/journal_export_screen.dart';
import '../../features/journal/presentation/journal_screen.dart';
import '../../features/journal/domain/journal_entry.dart';
import '../../features/leaderboard/presentation/leaderboard_screen.dart';
import '../../features/leaderboard/presentation/points_management_screen.dart';
import '../../features/leaderboard/presentation/teams_management_screen.dart';
import '../../features/map/domain/location.dart';
import '../../features/map/presentation/add_session_location_screen.dart';
import '../../features/map/presentation/knowledge_base_editor_screen.dart';
import '../../features/map/presentation/location_detail_page.dart';
import '../../features/map/presentation/location_form_screen.dart';
import '../../features/map/presentation/map_screen.dart';
import '../../features/map/presentation/master_locations_screen.dart';
import '../../features/organization/presentation/join_organization_screen.dart';
import '../../features/organization/presentation/organization_screen.dart';
import '../../features/settings/presentation/guide_settings_screen.dart';
import '../../features/settings/presentation/kid_settings_screen.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/guide_navigation_shell.dart';
import '../../shared/widgets/kid_navigation_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final path = state.matchedLocation;
      final publicRoutes = [
        '/splash',
        '/role-selection',
        '/guide-login',
        '/kid-login',
        '/kid-name',
      ];
      if (publicRoutes.contains(path)) return null;

      final appUser = ref.read(appUserProvider).valueOrNull;
      if (appUser == null) return '/splash';

      // Prevent kids from accessing guide routes and vice versa
      if (appUser.isKid && path.startsWith('/guide')) return '/kid';
      if (appUser.isGuide && path.startsWith('/kid')) return '/guide';

      // A guide with no org was removed by their owner (removeMember cleared
      // orgId). Send them to the join screen; they can re-join with a code.
      if (appUser.isGuide && appUser.orgId == null && path.startsWith('/guide')) {
        return '/join-organization';
      }

      return null;
    },
    routes: [
      // Auth Routes
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/guide-login',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          return GuideLoginScreen(
            initialMode: mode == 'create-org'
                ? GuideLoginMode.createOrg
                : GuideLoginMode.joinOrg,
          );
        },
      ),
      GoRoute(
        path: '/kid-login',
        builder: (context, state) => const KidLoginScreen(),
      ),
      GoRoute(
        path: '/kid-name',
        builder: (context, state) => const KidNameScreen(),
      ),
      GoRoute(
        path: '/join-organization',
        builder: (context, state) => const JoinOrganizationScreen(),
      ),

      // Kid Shell
      ShellRoute(
        builder: (context, state, child) =>
            KidNavigationShell(state: state, child: child),
        routes: [
          GoRoute(
            path: '/kid',
            builder: (context, state) => const KidHomeScreen(),
          ),
          GoRoute(
            path: '/kid/leaderboard',
            builder: (context, state) => const LeaderboardScreen(),
          ),
          GoRoute(
            path: '/kid/map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/kid/journal',
            builder: (context, state) => const JournalScreen(),
          ),
          GoRoute(
            path: '/kid/news',
            builder: (context, state) => AnnouncementsScreen(
              initialTab:
                  state.uri.queryParameters['tab'] == 'program' ? 1 : 0,
            ),
          ),
          GoRoute(
            path: '/kid/settings',
            builder: (context, state) => const KidSettingsScreen(),
          ),
        ],
      ),

      // Guide Shell
      ShellRoute(
        builder: (context, state, child) =>
            GuideNavigationShell(state: state, child: child),
        routes: [
          GoRoute(
            path: '/guide',
            builder: (context, state) => const GuideHomeScreen(),
          ),
          GoRoute(
            path: '/guide/leaderboard',
            builder: (context, state) => const PointsManagementScreen(),
          ),
          GoRoute(
            path: '/guide/map',
            builder: (context, state) => const MapScreen(),
          ),
          GoRoute(
            path: '/guide/announcements',
            builder: (context, state) => const AnnouncementManagementScreen(),
          ),
          GoRoute(
            path: '/guide/codes',
            builder: (context, state) => const CodeManagementScreen(),
          ),
          GoRoute(
            path: '/guide/emergency',
            builder: (context, state) => const EmergencyScreen(),
          ),
          GoRoute(
            path: '/guide/settings',
            builder: (context, state) => const GuideSettingsScreen(),
          ),
        ],
      ),

      // Journal routes (pushed on top of kid shell)
      GoRoute(
        path: '/kid/journal/new',
        builder: (context, state) => const JournalEditorScreen(),
      ),
      GoRoute(
        path: '/kid/journal/view',
        builder: (context, state) {
          final entry = state.extra;
          if (entry is! JournalEntry) return const JournalScreen();
          return JournalDetailScreen(entry: entry);
        },
      ),
      GoRoute(
        path: '/kid/journal/edit',
        builder: (context, state) {
          final entry = state.extra;
          if (entry is! JournalEntry) return const JournalScreen();
          return JournalEditorScreen(existingEntry: entry);
        },
      ),
      GoRoute(
        path: '/kid/journal/export',
        builder: (context, state) => const JournalExportScreen(),
      ),

      // Guide management routes (pushed on top of shell)
      GoRoute(
        path: '/guide/camp-sessions',
        builder: (context, state) => const CampSessionScreen(),
      ),
      GoRoute(
        path: '/guide/organization',
        builder: (context, state) => const OrganizationScreen(),
      ),
      // Guide map: add location to session
      GoRoute(
        path: '/guide/map/add-to-session',
        builder: (context, state) => const AddSessionLocationScreen(),
      ),

      // Guide settings: master locations management
      GoRoute(
        path: '/guide/settings/locations',
        builder: (context, state) => const MasterLocationsScreen(),
      ),
      GoRoute(
        path: '/guide/settings/locations/add',
        builder: (context, state) => const LocationFormScreen(),
      ),
      GoRoute(
        path: '/guide/settings/locations/edit',
        builder: (context, state) {
          final location = state.extra as Location;
          return LocationFormScreen(existingLocation: location);
        },
      ),
      GoRoute(
        path: '/guide/settings/locations/knowledge',
        builder: (context, state) {
          final location = state.extra as Location;
          return KnowledgeBaseEditorScreen(location: location);
        },
      ),
      GoRoute(
        path: '/guide/settings/teams',
        builder: (context, state) => const TeamsManagementScreen(),
      ),
      GoRoute(
        path: '/guide/settings/templates',
        builder: (context, state) => const AnnouncementTemplatesScreen(),
      ),

      // Location detail page (both guide and kid)
      GoRoute(
        path: '/location-detail',
        builder: (context, state) {
          final resolved = state.extra as ResolvedSessionLocation;
          return LocationDetailPage(
            masterLocation: resolved.masterLocation,
            groupPhotoUrl: resolved.sessionLocation.photoUrl,
          );
        },
      ),
    ],
  );
});
