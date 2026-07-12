import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_user.dart';
import '../domain/camp_session.dart';
import '../../../shared/providers/providers.dart';

/// For a guide with no selected camp whose org has a session running right
/// now (startDate < now < endDate), selects it: in-memory immediately and
/// persisted on the profile. Returns the selected session, or null when
/// nothing applies. Never throws: this is a login-time convenience and
/// must not block sign-in.
Future<CampSession?> autoSelectActiveSession(WidgetRef ref, AppUser user) async {
  if (!user.isGuide || user.campId != null || user.orgId == null) return null;
  try {
    final sessions = await ref
        .read(campRepositoryProvider)
        .fetchCampSessionsForOrg(user.orgId!);
    // fetch... returns newest-start first, so overlapping sessions resolve
    // to the most recently started one.
    final active = sessions.where((s) => s.isActive()).firstOrNull;
    if (active == null) return null;
    await ref
        .read(authRepositoryProvider)
        .updateUserCampId(user.uid, active.id);
    ref.read(activeCampIdProvider.notifier).select(active.id);
    return active;
  } catch (_) {
    return null;
  }
}
