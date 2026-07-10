/// A device-local record that this kid visited a camp map location.
/// GDPR: contains only a location id + timestamp; never uploaded.
class PassportStamp {
  final String locationId;
  final DateTime visitedAt;

  const PassportStamp({required this.locationId, required this.visitedAt});

  factory PassportStamp.fromJson(Map<String, dynamic> json) => PassportStamp(
        locationId: json['locationId'] as String,
        visitedAt: DateTime.parse(json['visitedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'locationId': locationId,
        'visitedAt': visitedAt.toIso8601String(),
      };
}

/// Device-local best quiz result for one location (a later task writes
/// these; stored alongside stamps in the same box).
class QuizResult {
  final String locationId;
  final int correct;
  final int total;
  final DateTime completedAt;

  const QuizResult({
    required this.locationId,
    required this.correct,
    required this.total,
    required this.completedAt,
  });

  bool get isPerfect => total > 0 && correct == total;

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
        locationId: json['locationId'] as String,
        correct: (json['correct'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        completedAt: DateTime.parse(json['completedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'locationId': locationId,
        'correct': correct,
        'total': total,
        'completedAt': completedAt.toIso8601String(),
      };
}
