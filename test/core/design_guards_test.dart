import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Design-system guard tests ("Trail Adventure", DESIGN.md).
///
/// These scan feature source files for patterns DESIGN.md bans. They fail
/// with the offending file:line list, so drift is caught in CI instead of
/// in a design review. Extend the allowlists ONLY with a comment explaining
/// why the exception is sanctioned.
void main() {
  final featureFiles = <File>[
    ...Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart')),
    ...Directory('lib/shared')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart')),
  ];

  List<String> violations(RegExp pattern, {bool Function(String path)? skip}) {
    final hits = <String>[];
    for (final file in featureFiles) {
      final path = file.path.replaceAll('\\', '/');
      if (skip != null && skip(path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          hits.add('$path:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    return hits;
  }

  test('inputs use the themed filled style — no per-field OutlineInputBorder',
      () {
    final hits = violations(RegExp(r'OutlineInputBorder'));
    expect(hits, isEmpty,
        reason: 'DESIGN.md: "Inputs: 14, filled style (no outline box)". '
            'Delete the border: override; inputDecorationTheme handles it.\n'
            '${hits.join('\n')}');
  });

  test('red is reserved for the emergency feature', () {
    final hits = violations(
      RegExp(r'colorScheme\.(error|onError|errorContainer|onErrorContainer)'),
      skip: (path) =>
          path.contains('lib/features/emergency/') ||
          // The single sanctioned exception: the emergency tile on the
          // guide home quick-action grid IS an emergency entry point.
          path.endsWith('guide_home_screen.dart'),
    );
    expect(hits, isEmpty,
        reason: 'DESIGN.md ban: "Red outside emergency". Use '
            'destructiveFilledStyle / onSurfaceVariant instead.\n'
            '${hits.join('\n')}');
  });
}
