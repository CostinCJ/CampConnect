class AppSettings {
  final String language; // 'en', 'ro', or 'hu'
  final String theme; // 'light' or 'dark'

  /// Kid-only: show the kid's own position on the camp map. Device-local
  /// opt-in — the position is never uploaded anywhere (GDPR-neutral).
  final bool kidLocationEnabled;

  const AppSettings({
    this.language = 'ro',
    this.theme = 'light',
    this.kidLocationEnabled = false,
  });

  bool get isDarkMode => theme == 'dark';

  AppSettings copyWith({
    String? language,
    String? theme,
    bool? kidLocationEnabled,
  }) {
    return AppSettings(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      kidLocationEnabled: kidLocationEnabled ?? this.kidLocationEnabled,
    );
  }
}
