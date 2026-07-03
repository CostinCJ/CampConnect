class AppSettings {
  final String language; // 'en', 'ro', or 'hu'
  final String theme; // 'light' or 'dark'
  final String? lastCampId;

  const AppSettings({
    this.language = 'ro',
    this.theme = 'light',
    this.lastCampId,
  });

  bool get isDarkMode => theme == 'dark';

  AppSettings copyWith({
    String? language,
    String? theme,
    String? lastCampId,
  }) {
    return AppSettings(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      lastCampId: lastCampId ?? this.lastCampId,
    );
  }
}
