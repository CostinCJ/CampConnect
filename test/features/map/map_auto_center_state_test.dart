// test/features/map/map_auto_center_state_test.dart
//
// Unit tests for the pure GPS-vs-marker-fit auto-centering precedence
// logic, extracted from map_screen.dart's _MapScreenState specifically so
// this async-ordering behavior can be exercised without pumping the full
// MapScreen widget (which needs native FMTC/ObjectBox tile-provider init
// and real network access — see map_marker_test.dart's note on the same
// limitation).
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/map/domain/map_auto_center_state.dart';

void main() {
  group('MapAutoCenterState', () {
    test('marker-fit is applied when it is scheduled and GPS never arrives',
        () {
      final state = MapAutoCenterState();

      expect(state.onMarkerFitAvailable(true), isTrue);
      // Simulates the deferred camera-move step re-checking precedence.
      expect(state.shouldApplyMarkerFit(), isTrue);
    });

    test('GPS fix after marker-fit was scheduled still wins', () {
      final state = MapAutoCenterState();

      // Markers resolve first and the fallback is scheduled...
      expect(state.onMarkerFitAvailable(true), isTrue);
      // ...but before the deferred camera move actually runs, a GPS fix
      // lands (the race the reviewer found: marker-fit's postFrameCallback
      // fires after GPS already centered the camera).
      expect(state.onGpsFix(), isTrue);

      // The marker-fit's deferred callback must now refuse to apply,
      // otherwise it would silently overwrite the GPS-centered camera.
      expect(state.shouldApplyMarkerFit(), isFalse);
    });

    test('marker-fit is suppressed entirely when GPS already won', () {
      final state = MapAutoCenterState();

      expect(state.onGpsFix(), isTrue);
      // Markers resolving afterwards should not even schedule a fit.
      expect(state.onMarkerFitAvailable(true), isFalse);
    });

    test('GPS fix only centers the camera once', () {
      final state = MapAutoCenterState();

      expect(state.onGpsFix(), isTrue);
      expect(state.onGpsFix(), isFalse);
      expect(state.onGpsFix(), isFalse);
      expect(state.didCenterOnGps, isTrue);
    });

    test('marker-fit is only scheduled once even with repeated resolves',
        () {
      final state = MapAutoCenterState();

      expect(state.onMarkerFitAvailable(true), isTrue);
      // e.g. the provider re-resolving with an updated (still non-empty)
      // location list should not reschedule another fit.
      expect(state.onMarkerFitAvailable(true), isFalse);
    });

    test('an empty location list never schedules a marker-fit', () {
      final state = MapAutoCenterState();

      expect(state.onMarkerFitAvailable(false), isFalse);
      // Once locations do arrive, it should still be free to schedule.
      expect(state.onMarkerFitAvailable(true), isTrue);
    });
  });
}
