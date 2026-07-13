import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/core/utils/debug_log.dart';

void main() {
  test('debugLog forwards to debugPrint (kDebugMode is true under flutter test)',
      () {
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = original);

    debugLog('hello world');

    expect(messages, contains('hello world'));
  });
}
