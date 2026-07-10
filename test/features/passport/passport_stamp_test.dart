import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/passport/domain/passport_stamp.dart';

void main() {
  test('PassportStamp json round-trip', () {
    final stamp = PassportStamp(
      locationId: 'loc1',
      visitedAt: DateTime(2026, 7, 10, 14, 30),
    );
    final restored = PassportStamp.fromJson(stamp.toJson());
    expect(restored.locationId, 'loc1');
    expect(restored.visitedAt, DateTime(2026, 7, 10, 14, 30));
  });

  test('QuizResult json round-trip and isPerfect', () {
    final result = QuizResult(
      locationId: 'loc1',
      correct: 3,
      total: 3,
      completedAt: DateTime(2026, 7, 10),
    );
    final restored = QuizResult.fromJson(result.toJson());
    expect(restored.isPerfect, isTrue);
    expect(
      QuizResult(
        locationId: 'loc1',
        correct: 2,
        total: 3,
        completedAt: DateTime(2026, 7, 10),
      ).isPerfect,
      isFalse,
    );
  });
}
