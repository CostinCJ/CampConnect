// lib/features/map/data/location_cache_service.dart
import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/location.dart';

class LocationCacheService {
  static const String _boxName = 'cached_locations';

  /// Open the Hive box (call once before use).
  Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box<String>(_boxName);
    }
    return Hive.openBox<String>(_boxName);
  }

  /// Cache a list of locations (replaces previous cache).
  Future<void> cacheLocations(List<Location> locations) async {
    final box = await _openBox();
    await box.clear();
    for (final location in locations) {
      await box.put(location.id, jsonEncode(location.toJson()));
    }
  }

  /// Retrieve cached locations.
  Future<List<Location>> getCachedLocations() async {
    final box = await _openBox();
    final locations = <Location>[];
    for (final value in box.values) {
      try {
        final json = jsonDecode(value) as Map<String, dynamic>;
        locations.add(Location.fromJson(json));
      } catch (_) {
        // Skip corrupted entries
      }
    }
    return locations;
  }

  /// Clear the cache.
  Future<void> clearCache() async {
    final box = await _openBox();
    await box.clear();
  }
}
