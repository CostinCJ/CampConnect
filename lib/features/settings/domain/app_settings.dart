class AppSettings {
  final String language; // 'en', 'ro', or 'hu'
  final String theme; // 'light' or 'dark'

  const AppSettings({
    this.language = 'ro',
    this.theme = 'light',
  });

  bool get isDarkMode => theme == 'dark';

  AppSettings copyWith({
    String? language,
    String? theme,
  }) {
    return AppSettings(
      language: language ?? this.language,
      theme: theme ?? this.theme,
    );
  }
}
