import 'package:flutter/foundation.dart';

/// Debug-only logging: swallowed entirely in release builds. Use this
/// instead of calling `debugPrint` directly so diagnostic noise never
/// ships to production (2026-07-13 critique finding: 23 unguarded
/// debugPrint calls previously executed in release builds).
void debugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
