import 'package:flutter/material.dart' show ThemeMode;

class AppSettings {
  final String language; // 'en', 'ro', or 'hu'
  final String theme; // 'light', 'dark' or 'system'

  /// Kid-only: show the kid's own position on the camp map. Device-local
  /// opt-in — the position is never uploaded anywhere (GDPR-neutral).
  final bool kidLocationEnabled;

  const AppSettings({
    this.language = 'ro',
    this.theme = 'light',
    this.kidLocationEnabled = false,
  });

  bool get isDarkMode => theme == 'dark';

  ThemeMode get themeMode => switch (theme) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };

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
