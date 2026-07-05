// test/features/map/map_marker_test.dart
//
// NOTE on approach: the plan's original snippet pumps the full MapScreen
// (via a `locationsProvider` override) and looks up the marker by key/label
// in that tree. That isn't tractable here: MapScreen renders a real
// FlutterMap with a FMTCStore('mapTiles').getTileProvider() tile provider,
// which requires FMTCObjectBoxBackend().initialise() (native ObjectBox
// bindings, ordinarily done once in main()) and performs real network tile
// requests. Pumping MapScreen directly in a plain flutter_test widget test
// throws/hangs before ever reaching the marker layer.
//
// The marker rendering (48dp touch target, Semantics label, tap feedback)
// was extracted into a standalone `MapMarker` widget in map_screen.dart,
// which MapScreen's MarkerLayer now delegates to. This test pumps that real
// `MapMarker` widget directly — the same widget and the same
// ResolvedSessionLocation/Location/SessionLocation model classes actually
// used in production — without needing FlutterMap, FMTC, or network access.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:camp_connect/features/map/presentation/map_screen.dart';
import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/features/map/domain/session_location.dart';
import 'package:camp_connect/shared/providers/providers.dart';

void main() {
  final testMasterLocation = Location(
    id: 'loc-1',
    name: 'Campfire',
    latitude: 45.0,
    longitude: 25.0,
    description: 'The main campfire circle',
    category: LocationCategory.nature,
    createdBy: 'guide-1',
    timestamp: DateTime(2026, 1, 1),
  );

  final testSessionLocation = SessionLocation(
    id: 'session-loc-1',
    masterLocationId: testMasterLocation.id,
    addedBy: 'guide-1',
    visitedAt: DateTime(2026, 1, 1),
  );

  final testResolved = ResolvedSessionLocation(
    sessionLocation: testSessionLocation,
    masterLocation: testMasterLocation,
  );

  Widget buildTestable() => MaterialApp(
        home: Scaffold(
          body: MapMarker(
            resolved: testResolved,
            onTap: () {},
          ),
        ),
      );

  testWidgets('map markers meet the 48dp minimum touch target', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    final markerFinder =
        find.byKey(ValueKey('map-marker-${testMasterLocation.id}'));
    expect(markerFinder, findsOneWidget);
    final size = tester.getSize(markerFinder);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('map markers have a semantic label matching the location name', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(testMasterLocation.name), findsOneWidget);
  });

  testWidgets('tapping a map marker invokes the provided onTap handler', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MapMarker(
          resolved: testResolved,
          onTap: () => tapped = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('map-marker-${testMasterLocation.id}')));
    await tester.pump();

    expect(tapped, isTrue);
  });
}
