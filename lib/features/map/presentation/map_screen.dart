// lib/features/map/presentation/map_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:camp_connect/core/constants/app_constants.dart';
import 'package:camp_connect/core/l10n/app_localizations.dart';
import 'package:camp_connect/features/map/domain/location.dart';
import 'package:camp_connect/shared/providers/providers.dart';

import 'widgets/location_detail_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _guidePosition;

  @override
  void initState() {
    super.initState();
    _initGuideTracking();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initGuideTracking() async {
    final appUser = ref.read(appUserProvider).valueOrNull;
    if (appUser == null || !appUser.isGuide) return;

    final permission = await Geolocator.checkPermission();
    LocationPermission granted = permission;
    if (granted == LocationPermission.denied) {
      granted = await Geolocator.requestPermission();
    }

    if (granted == LocationPermission.denied ||
        granted == LocationPermission.deniedForever) {
      return;
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) {
      if (mounted) {
        setState(() {
          _guidePosition = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  void _goToMyLocation() {
    if (_guidePosition != null) {
      _mapController.move(_guidePosition!, 16.0);
    }
  }

  void _onMarkerTap(Location location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocationDetailSheet(location: location),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locationsAsync = ref.watch(filteredLocationsProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final isGuide = appUser?.isGuide ?? false;
    final activeFilter = ref.watch(locationCategoryFilterProvider);

    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                AppConstants.defaultCampLatitude,
                AppConstants.defaultCampLongitude,
              ),
              initialZoom: AppConstants.defaultMapZoom,
              minZoom: 6,
              maxZoom: 18,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(43.5, 20.2),  // SW Romania
                  const LatLng(48.3, 30.0),  // NE Romania
                ),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.campconnect.app',
                tileProvider: const FMTCStore('mapTiles').getTileProvider(),
              ),
              // Location markers
              locationsAsync.when(
                loading: () => const MarkerLayer(markers: []),
                error: (_, _) => const MarkerLayer(markers: []),
                data: (locations) => MarkerLayer(
                  markers: locations.map((location) {
                    return Marker(
                      point: LatLng(location.latitude, location.longitude),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _onMarkerTap(location),
                        child: Icon(
                          location.category.icon,
                          color: location.category.color,
                          size: 36,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Guide real-time position marker
              if (_guidePosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _guidePosition!,
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Filter chips at top
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: l10n.categoryAll,
                    icon: Icons.layers,
                    selected: activeFilter == null,
                    onTap: () => ref.read(locationCategoryFilterProvider.notifier).state = null,
                  ),
                  const SizedBox(width: 6),
                  ...LocationCategory.values.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: _categoryLabel(l10n, cat),
                      icon: cat.icon,
                      color: cat.color,
                      selected: activeFilter == cat,
                      onTap: () => ref.read(locationCategoryFilterProvider.notifier).state = cat,
                    ),
                  )),
                ],
              ),
            ),
          ),

          // My Location button (guide only)
          if (isGuide)
            Positioned(
              bottom: 96,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'myLocation',
                onPressed: _goToMyLocation,
                child: const Icon(Icons.my_location),
              ),
            ),
        ],
      ),

      // Add Location FAB (guide only)
      floatingActionButton: isGuide
          ? FloatingActionButton.extended(
              heroTag: 'addLocation',
              onPressed: () => context.push('/guide/map/add'),
              icon: const Icon(Icons.add_location_alt),
              label: Text(l10n.addLocation),
            )
          : null,
    );
  }

  String _categoryLabel(AppLocalizations l10n, LocationCategory cat) {
    switch (cat) {
      case LocationCategory.nature:
        return l10n.categoryNature;
      case LocationCategory.historical:
        return l10n.categoryHistorical;
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: selected
          ? (color ?? theme.colorScheme.primary)
          : theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? Colors.white
                    : (color ?? theme.colorScheme.onSurface),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
