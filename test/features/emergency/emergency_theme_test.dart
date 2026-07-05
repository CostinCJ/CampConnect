import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emergency screens contain no hardcoded Colors.red — use colorScheme.error instead', () {
    final files = [
      'lib/features/emergency/presentation/emergency_screen.dart',
      'lib/features/emergency/presentation/emergency_overlay.dart',
      'lib/features/auth/presentation/camp_session_screen.dart',
    ];
    for (final path in files) {
      final content = File(path).readAsStringSync();
      expect(
        content.contains('Colors.red'),
        isFalse,
        reason: '$path still contains a hardcoded Colors.red reference',
      );
    }
  });
}
