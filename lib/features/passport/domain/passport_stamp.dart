/// A device-local record that this kid visited a camp map location.
/// GDPR: contains only public camp-location facts + a timestamp; never
/// uploaded.
class PassportStamp {
  final String locationId;
  final DateTime visitedAt;

  /// Location name, denormalized at check-in time. Resolving the name live
  /// requires a signed-in session with camp access, which a kid can lose
  /// permanently (expired code after camp end) — the stamp must outlive
  /// that. Null only for stamps created before this field existed.
  final String? locationName;

  /// `LocationCategory.name` at check-in time, for the same reason.
  final String? categoryName;

  const PassportStamp({
    required this.locationId,
    required this.visitedAt,
    this.locationName,
    this.categoryName,
  });

  factory PassportStamp.fromJson(Map<String, dynamic> json) => PassportStamp(
        locationId: json['locationId'] as String,
        visitedAt: DateTime.parse(json['visitedAt'] as String),
        locationName: json['locationName'] as String?,
        categoryName: json['categoryName'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'locationId': locationId,
        'visitedAt': visitedAt.toIso8601String(),
        if (locationName != null) 'locationName': locationName,
        if (categoryName != null) 'categoryName': categoryName,
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
