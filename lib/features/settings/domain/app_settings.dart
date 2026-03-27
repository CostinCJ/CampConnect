class AppSettings {
  final String language; // 'ro' or 'hu'
  final String theme; // 'light' or 'dark'
  final bool llmEnabled;
  final String? lastCampId;

  const AppSettings({
    this.language = 'ro',
    this.theme = 'light',
    this.llmEnabled = true,
    this.lastCampId,
  });

  bool get isDarkMode => theme == 'dark';

  AppSettings copyWith({
    String? language,
    String? theme,
    bool? llmEnabled,
    String? lastCampId,
  }) {
    return AppSettings(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      llmEnabled: llmEnabled ?? this.llmEnabled,
      lastCampId: lastCampId ?? this.lastCampId,
    );
  }
}
