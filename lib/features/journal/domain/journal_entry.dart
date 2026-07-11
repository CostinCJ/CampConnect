class JournalEntry {
  final String id;
  final DateTime date;
  final String title;
  final String body;
  final List<String> photos; // local file paths
  final String? prompt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const JournalEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.body,
    this.photos = const [],
    this.prompt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      photos: List<String>.from(json['photos'] as List? ?? []),
      prompt: json['prompt'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'body': body,
      'photos': photos,
      'prompt': prompt,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  JournalEntry copyWith({
    String? id,
    DateTime? date,
    String? title,
    String? body,
    List<String>? photos,
    String? prompt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JournalEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      body: body ?? this.body,
      photos: photos ?? this.photos,
      prompt: prompt ?? this.prompt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
