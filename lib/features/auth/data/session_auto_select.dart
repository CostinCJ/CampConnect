import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/core/utils/debug_log.dart';

import '../domain/app_user.dart';
import '../domain/camp_session.dart';
import '../../../shared/providers/providers.dart';

/// For a guide with no selected camp whose org has EXACTLY ONE session
/// running right now (startDate < now < endDate), selects it: in-memory
/// immediately and persisted on the profile. Returns the selected session,
/// or null when nothing applies. If two or more sessions are active at
/// once (e.g. two age groups running concurrently), auto-select is
/// deliberately skipped rather than guessing which one the guide meant —
/// they fall back to the manual "select session" picker instead. Never
/// throws: this is a login-time convenience and must not block sign-in.
Future<CampSession?> autoSelectActiveSession(WidgetRef ref, AppUser user) async {
  if (!user.isGuide || user.campId != null || user.orgId == null) return null;
  try {
    final sessions = await ref
        .read(campRepositoryProvider)
        .fetchCampSessionsForOrg(user.orgId!);
    final activeSessions = sessions.where((s) => s.isActive()).toList();
    if (activeSessions.length != 1) return null;
    final active = activeSessions.single;
    await ref
        .read(authRepositoryProvider)
        .updateUserCampId(user.uid, active.id);
    ref.read(activeCampIdProvider.notifier).select(active.id);
    return active;
  } catch (e) {
    debugLog('[AUTO_SELECT] autoSelectActiveSession failed (non-fatal): $e');
    return null;
  }
}
