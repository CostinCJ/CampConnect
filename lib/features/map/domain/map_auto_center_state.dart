/// Pure precedence logic for the map's one-shot auto-centering (GPS fix vs.
/// marker-fit fallback), extracted from `_MapScreenState` so it's testable
/// without pumping the full `MapScreen` widget (which needs native
/// FMTC/ObjectBox tile-provider init and real network access).
///
/// GPS is authoritative: guides always get it, kids after their existing
/// opt-in. A GPS fix that arrives after the marker-fit fallback has already
/// been *scheduled* — or even applied — should still win. Because the
/// marker-fit's actual camera move is deferred (e.g. via
/// `addPostFrameCallback`, so it runs after the current frame), there is a
/// gap between "marker-fit scheduled" and "marker-fit applied" during which
/// a GPS fix can land. Callers MUST call [shouldApplyMarkerFit] again
/// immediately before actually moving the camera inside that deferred
/// callback — not just rely on the earlier [onMarkerFitAvailable] check —
/// or a late-scheduled marker-fit can silently overwrite a GPS center that
/// won in the meantime.
class MapAutoCenterState {
  bool _didCenterOnGps = false;
  bool _didScheduleMarkerFit = false;

  /// Whether a GPS fix has already centered the camera.
  bool get didCenterOnGps => _didCenterOnGps;

  /// Call when a GPS fix arrives. Returns true exactly once (on the first
  /// fix received) to signal the caller should move the camera to it. GPS
  /// always gets this chance, even if a marker-fit already ran.
  bool onGpsFix() {
    if (_didCenterOnGps) return false;
    _didCenterOnGps = true;
    return true;
  }

  /// Call when the session's markers become available. Returns true if a
  /// marker-fit should be *scheduled* (i.e. a deferred camera move queued).
  /// Only ever returns true once, and never once GPS has already centered
  /// the camera.
  bool onMarkerFitAvailable(bool hasLocations) {
    if (_didCenterOnGps || _didScheduleMarkerFit || !hasLocations) {
      return false;
    }
    _didScheduleMarkerFit = true;
    return true;
  }

  /// Call immediately before actually applying a previously-scheduled
  /// marker-fit (e.g. inside the `addPostFrameCallback` body), to
  /// re-validate that a GPS fix hasn't landed in the gap between scheduling
  /// and applying. Returns false if it has — the marker-fit must be
  /// dropped so it doesn't overwrite the GPS-centered camera.
  bool shouldApplyMarkerFit() => !_didCenterOnGps;
}
