import '../../auth/domain/app_user.dart';
import '../../settings/domain/app_settings.dart';

/// Whether the map should run the on-device position stream for this user.
/// Guides always track (existing behavior); kids only after the explicit
/// opt-in stored in [AppSettings.kidLocationEnabled]. Position never leaves
/// the device either way.
bool shouldTrackSelfLocation(AppUser? user, AppSettings settings) {
  if (user == null) return false;
  if (user.isGuide) return true;
  return settings.kidLocationEnabled;
}
