class AppSettings {
  final String language; // 'ro' or 'hu'
  final String theme; // 'light' or 'dark'
  final bool llmEnabled;
  final bool deviceCapable;
  final bool modelDownloaded;
  final String? lastCampId;

  const AppSettings({
    this.language = 'ro',
    this.theme = 'light',
    this.llmEnabled = true,
    this.deviceCapable = true,
    this.modelDownloaded = false,
    this.lastCampId,
  });

  bool get isDarkMode => theme == 'dark';

  /// LLM chat should be available: device is capable, user toggled it on, and model is downloaded.
  bool get llmReady => deviceCapable && llmEnabled && modelDownloaded;

  /// LLM can be started: device is capable and user toggled it on (model may still need download).
  bool get llmAvailable => deviceCapable && llmEnabled;

  AppSettings copyWith({
    String? language,
    String? theme,
    bool? llmEnabled,
    bool? deviceCapable,
    bool? modelDownloaded,
    String? lastCampId,
  }) {
    return AppSettings(
      language: language ?? this.language,
      theme: theme ?? this.theme,
      llmEnabled: llmEnabled ?? this.llmEnabled,
      deviceCapable: deviceCapable ?? this.deviceCapable,
      modelDownloaded: modelDownloaded ?? this.modelDownloaded,
      lastCampId: lastCampId ?? this.lastCampId,
    );
  }
}
