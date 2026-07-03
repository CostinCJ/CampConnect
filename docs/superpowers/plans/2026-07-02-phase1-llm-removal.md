# Phase 1 — LLM Removal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completely remove the on-device LLM feature (fllama, model download, content filter, device-capability checks, chat UI) so the app builds reproducibly, drops ~1,500 lines, and removes a child-safety/store liability — while preserving the map pin knowledge-base text display.

**Architecture:** Delete the `lib/features/llm/` directory and its tests, strip every import/reference in `main.dart`, `app.dart`, and `location_detail_page.dart`, remove the `fllama` dependency, and clean the LLM settings keys/fields/toggles. The `Location.knowledgeBase` model and its detail-page rendering stay; only the "Start chat" button and chat widget go.

**Tech Stack:** Flutter, Riverpod, Firebase. No new dependencies.

**Branch:** `phase1-llm-removal` (do NOT commit to `main`; do NOT push unless the user asks).

---

### Task 1: Create the working branch

**Files:** none (git only)

- [ ] **Step 1: Create and switch to the phase branch**

Run:
```bash
cd /d/CampConnect && git checkout -b phase1-llm-removal
```
Expected: `Switched to a new branch 'phase1-llm-removal'`

- [ ] **Step 2: Confirm a clean analyze baseline before changes**

Run:
```bash
flutter analyze
```
Expected: `2 issues found` (the pre-existing `unused_import` in `llm_providers.dart` and `avoid_print` in `add_session_location_screen.dart`). Record this — Task 10 verifies it drops to `1 issue` (only the `avoid_print`, since the LLM file is deleted).

---

### Task 2: Remove the LLM chat button from the location detail page

**Files:**
- Modify: `lib/features/map/presentation/location_detail_page.dart`

This is the ONLY place LLM is user-facing outside settings. The page must keep rendering `knowledgeBase` (description/facts/funFact) and lose the chat button + all LLM plumbing.

- [ ] **Step 1: Remove the four LLM imports (lines 11–14)**

Delete these lines:
```dart
import 'package:camp_connect/features/llm/data/llm_runtime.dart';
import 'package:camp_connect/features/llm/presentation/llm_chat_widget.dart';
import 'package:camp_connect/features/llm/presentation/start_chat_button.dart';
import 'package:camp_connect/features/llm/providers/llm_providers.dart';
```

- [ ] **Step 2: Convert the widget from stateful chat host to a plain detail view**

Replace the class body from `class _LocationDetailPageState` down through the `build` method's `if (_chatActive)` branch. Specifically, delete the `bool _chatActive = false;` field, the entire `_startChat()` method (lines ~36–81), and change `build` so it no longer branches on `_chatActive`.

Replace:
```dart
  bool _chatActive = false;

  Future<void> _startChat() async {
```
… through the end of `_startChat()` (the closing brace before `@override Widget build`), and the `build` method's chat branch:
```dart
  @override
  Widget build(BuildContext context) {
    if (_chatActive) {
      return Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => setState(() => _chatActive = false),
          ),
          title: Text(widget.masterLocation.name),
        ),
        body: LlmChatWidget(masterLocation: widget.masterLocation),
      );
    }

    return _buildDetailView(context);
  }
```

With:
```dart
  @override
  Widget build(BuildContext context) {
    return _buildDetailView(context);
  }
```

- [ ] **Step 3: Remove the chat button from `_buildDetailView`**

Find and delete these lines (near the end of the sliver list, ~266–268):
```dart
                // LLM chat button
                if (settings.llmAvailable)
                  StartChatButton(onStartChat: _startChat),

```
Also remove the now-unused `final settings = ref.watch(settingsProvider);` line near the top of `_buildDetailView` **only if** `settings` is not used elsewhere in that method (verify with search in Step 4). Leave `ref` — the class is still a `ConsumerStatefulWidget` which is fine.

- [ ] **Step 4: Verify no dangling LLM/settings references remain in the file**

Run:
```bash
grep -n "llm\|Llm\|_chatActive\|StartChatButton\|settings\." lib/features/map/presentation/location_detail_page.dart
```
Expected: no matches for `llm`, `Llm`, `_chatActive`, `StartChatButton`. If `settings.` still appears, keep the `final settings = ...` line; otherwise it should have been removed in Step 3.

- [ ] **Step 5: Commit**

```bash
git add lib/features/map/presentation/location_detail_page.dart
git commit -m "refactor: remove LLM chat button from location detail page"
```

---

### Task 3: Strip LLM from app.dart

**Files:**
- Modify: `lib/app.dart`

`app.dart` imports the LLM providers and releases the model on app pause.

- [ ] **Step 1: Remove the LLM import (line 9)**

Delete:
```dart
import 'features/llm/providers/llm_providers.dart';
```

- [ ] **Step 2: Remove the model-release lifecycle hook**

In `didChangeAppLifecycleState`, delete the release call so the method body becomes empty of LLM logic:

Replace:
```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      ref.read(llmRuntimeProvider.notifier).releaseModel();
    }
  }
```

With:
```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No lifecycle-specific work needed after LLM removal.
  }
```

(Keep the method — `WidgetsBindingObserver` is still mixed in and the override is harmless; leaving it avoids touching the observer registration.)

- [ ] **Step 3: Verify no LLM references remain**

Run:
```bash
grep -n "llm\|Llm" lib/app.dart
```
Expected: no matches.

- [ ] **Step 4: Commit**

```bash
git add lib/app.dart
git commit -m "refactor: remove LLM model-release lifecycle hook from app.dart"
```

---

### Task 4: Strip LLM from main.dart

**Files:**
- Modify: `lib/main.dart`

`main.dart` does a device-capability check and a model-file existence check at startup and writes both to settings.

- [ ] **Step 1: Remove the device_capability import (line 15)**

Delete:
```dart
import 'features/llm/domain/device_capability.dart';
```

- [ ] **Step 2: Remove the capability + model-file startup block**

Delete these lines (49–56):
```dart
  // Check device capability for LLM (CPU / RAM checks — no native dependency)
  final isCapable = await DeviceCapability.isCapable();
  await settingsRepo.setDeviceCapable(isCapable);

  // Check if model file exists (plain file check — no native dependency)
  final docsDir = await getApplicationDocumentsDirectory();
  final modelFile = File('${docsDir.path}/${AppConstants.llmModelFileName}');
  await settingsRepo.setModelDownloaded(modelFile.existsSync());
```

- [ ] **Step 3: Remove now-unused imports and the unused settingsRepo if orphaned**

After Step 2, `dart:io` (`File`), `path_provider` (`getApplicationDocumentsDirectory`), and `AppConstants` may be unused in `main.dart`, and `settingsRepo` is now only constructed but not used. Check each:

Run:
```bash
grep -n "File(\|getApplicationDocumentsDirectory\|AppConstants\|settingsRepo\|SettingsRepository" lib/main.dart
```
Remove the `import 'dart:io';`, `import 'package:path_provider/path_provider.dart';`, `import 'core/constants/app_constants.dart';`, `import 'features/settings/data/settings_repository.dart';`, and the `final settingsRepo = SettingsRepository(sharedPreferences);` line **only if** the grep shows they have no other use. (They do not — `sharedPreferences` is still passed to the `ProviderScope` override directly.)

- [ ] **Step 4: Run analyze to confirm main.dart has no unused-import warnings**

Run:
```bash
flutter analyze lib/main.dart
```
Expected: no issues for `main.dart`.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "refactor: remove LLM capability and model-file checks from startup"
```

---

### Task 5: Remove LLM fields from settings domain + repository

**Files:**
- Modify: `lib/features/settings/domain/app_settings.dart`
- Modify: `lib/features/settings/data/settings_repository.dart`
- Modify: `lib/shared/providers/providers.dart`
- Modify: `lib/core/constants/app_constants.dart`

- [ ] **Step 1: Remove LLM fields from `AppSettings`**

In `app_settings.dart`, delete the fields `llmEnabled`, `deviceCapable`, `modelDownloaded`, their constructor defaults, the `llmReady` and `llmAvailable` getters, and their `copyWith` parameters/assignments. The resulting class keeps only `language`, `theme`, `lastCampId`.

Final `app_settings.dart`:
```dart
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
```

- [ ] **Step 2: Remove LLM methods + reads from `SettingsRepository`**

In `settings_repository.dart`, delete `setLlmEnabled`, `setDeviceCapable`, `setModelDownloaded`, and the three LLM lines in `load()`. Final `load()`:
```dart
  AppSettings load() {
    return AppSettings(
      language: _prefs.getString(AppConstants.keyLanguage) ?? 'ro',
      theme: _prefs.getString(AppConstants.keyTheme) ?? 'light',
      lastCampId: _prefs.getString(AppConstants.keyLastCampId),
    );
  }
```
(Keep `clear()` for now — it is addressed separately in Phase 3.)

- [ ] **Step 3: Remove LLM setters from `SettingsNotifier`**

In `lib/shared/providers/providers.dart`, delete the `setLlmEnabled`, `setDeviceCapable`, and `setModelDownloaded` methods from `SettingsNotifier` (lines ~213–226).

- [ ] **Step 4: Remove LLM constants**

In `app_constants.dart`, delete: `keyLlmEnabled`, `keyModelDownloaded`, `keyLlmLoadAttempted`, `keyLlmLoadSucceeded`, `llmModelFileName`, `llmMinRamMb`, `llmContextTokens`, `llmSystemPromptTokens`, `llmMaxConversationTokens` (lines 41, 48–59). Keep `keyLanguage`, `keyTheme`, `keyLastCampId`.

- [ ] **Step 5: Verify no references to deleted symbols remain**

Run:
```bash
grep -rn "llmEnabled\|deviceCapable\|modelDownloaded\|llmReady\|llmAvailable\|setLlmEnabled\|setDeviceCapable\|setModelDownloaded\|keyLlm\|llmModelFileName\|llmMinRamMb\|llmContextTokens\|llmSystemPromptTokens\|llmMaxConversationTokens\|keyModelDownloaded" lib
```
Expected: no matches (settings screens are cleaned in Task 6, so run this again after Task 6 too).

- [ ] **Step 6: Commit**

```bash
git add lib/features/settings/domain/app_settings.dart lib/features/settings/data/settings_repository.dart lib/shared/providers/providers.dart lib/core/constants/app_constants.dart
git commit -m "refactor: remove LLM fields from settings model, repo, and constants"
```

---

### Task 6: Remove the LLM toggle from the kid settings screen + fix the LLM-error logout bug

**Files:**
- Modify: `lib/features/settings/presentation/kid_settings_screen.dart`
- Modify: `lib/features/settings/presentation/guide_settings_screen.dart`

- [ ] **Step 1: Delete the LLM toggle block in kid settings (lines 67–83)**

Delete:
```dart
          // LLM Toggle (only show if device is capable)
          if (settings.deviceCapable) ...[
            const Divider(),
            SwitchListTile(
              title: Text(l10n.llmToggleLabel),
              subtitle: Text(
                settings.modelDownloaded
                    ? l10n.llmModelDownloaded
                    : l10n.llmModelNotDownloaded,
              ),
              secondary: const Icon(Icons.smart_toy),
              value: settings.llmEnabled,
              onChanged: (value) {
                ref.read(settingsProvider.notifier).setLlmEnabled(value);
              },
            ),
          ],
```

- [ ] **Step 2: Fix the copy-paste logout error string in kid settings (line 106)**

Replace `Text(l10n.llmError)` with `Text(l10n.somethingWentWrong)` in the logout catch block.

- [ ] **Step 3: Fix the same copy-paste logout error string in guide settings (line 124)**

In `guide_settings_screen.dart`, replace `Text(l10n.llmError)` with `Text(l10n.somethingWentWrong)`.

- [ ] **Step 4: Verify**

Run:
```bash
grep -rn "llm\|Llm\|smart_toy\|deviceCapable\|modelDownloaded" lib/features/settings/presentation
```
Expected: no matches.

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/presentation/kid_settings_screen.dart lib/features/settings/presentation/guide_settings_screen.dart
git commit -m "refactor: remove LLM toggle from settings; fix logout error string"
```

---

### Task 7: Delete the LLM feature directory and its tests

**Files:**
- Delete: `lib/features/llm/` (entire directory, 10 files)
- Delete: `test/features/llm/` (entire directory, 6 files)
- Delete: `integration_test/llm_benchmark_test.dart`

- [ ] **Step 1: Delete the source directory**

Run:
```bash
git rm -r lib/features/llm
```
Expected: git lists the 10 removed files.

- [ ] **Step 2: Delete the test directory and integration test**

Run:
```bash
git rm -r test/features/llm && git rm integration_test/llm_benchmark_test.dart
```
Expected: git lists the 7 removed files.

- [ ] **Step 3: Verify no source references any deleted path**

Run:
```bash
grep -rn "features/llm" lib test integration_test
```
Expected: no matches.

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor: delete LLM feature source and tests"
```

---

### Task 8: Remove the fllama dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Delete the fllama dependency block (lines 51–55)**

Delete:
```yaml
  # LLM (Phase 6) — on-device inference via llama.cpp (ARM64 only)
  fllama:
    git:
      url: https://github.com/Telosnex/fllama.git
      ref: main
```

- [ ] **Step 2: Re-resolve dependencies**

Run:
```bash
flutter pub get
```
Expected: resolves successfully with no reference to `fllama`.

- [ ] **Step 3: Verify fllama is gone from the lockfile**

Run:
```bash
grep -n "fllama" pubspec.lock pubspec.yaml
```
Expected: no matches.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: remove fllama on-device LLM dependency"
```

---

### Task 9: Remove the LLM strings from localization and the models storage rule

**Files:**
- Modify: `lib/core/l10n/app_localizations.dart`
- Modify: `storage.rules`

- [ ] **Step 1: Delete the LLM getter declarations**

In `app_localizations.dart`, delete the getters (lines ~325–336 region): `downloadingModel`, `llmToggleLabel`, `llmModelNotDownloaded`, `llmModelDownloaded`, `llmModelLoading`, `llmError`, `llmRetry`. Also delete any `// LLM Chat strings` comment header.

- [ ] **Step 2: Delete the LLM key/value pairs from all three maps**

Delete the `downloadingModel`, `llmToggleLabel`, `llmModelNotDownloaded`, `llmModelDownloaded`, `llmModelLoading`, `llmError`, `llmRetry` entries from `_ro` (~697–705), `_hu` (~1009–1017), and `_en` (~1321–1329).

- [ ] **Step 3: Verify no LLM keys remain in l10n**

Run:
```bash
grep -n "llm\|Llm\|downloadingModel\|Model" lib/core/l10n/app_localizations.dart
```
Expected: no matches.

- [ ] **Step 4: Remove the obsolete models storage rule**

In `storage.rules`, delete the block (lines 16–20):
```
    // Model files — only authenticated users can download
    match /models/{modelFile} {
      allow read: if request.auth != null;
      allow write: if false;
    }
```

- [ ] **Step 5: Commit**

```bash
git add lib/core/l10n/app_localizations.dart storage.rules
git commit -m "chore: remove LLM localization strings and model storage rule"
```

---

### Task 10: Full verification pass

**Files:** none (verification only)

- [ ] **Step 1: Global grep for any surviving LLM reference**

Run:
```bash
grep -rin "llm\|fllama\|llama\|qwen\|smart_toy\|DeviceCapability\|modelDownload\|ContentFilter" lib test integration_test pubspec.yaml storage.rules
```
Expected: **no matches.** (The `_lastAcknowledgedAlertId` provider and unrelated words must not contain `llm` — verify any hit is genuinely unrelated; there should be none.)

- [ ] **Step 2: Analyze the whole project**

Run:
```bash
flutter analyze
```
Expected: `1 issue found` — only the pre-existing `avoid_print` info in `add_session_location_screen.dart`. The `unused_import` in `llm_providers.dart` is gone because the file is deleted. If any new error appears, it points to a missed reference — fix before proceeding.

- [ ] **Step 3: Confirm the app builds (Android debug)**

Run:
```bash
flutter build apk --debug
```
Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 4: Manual smoke test on a device/emulator**

Run `flutter run`, then verify by hand:
1. App launches to the splash → role selection without crashing.
2. Log in as a guide, open a camp, open the **Map**, tap a location pin → the detail page shows the photo, description, and knowledge-base **Description / Facts / Fun fact** sections.
3. There is **no** "Start chat"/interactive-guide button on the detail page.
4. Open kid **Settings** → there is **no** interactive-guide toggle; language + dark mode still work.
5. Log out from settings → returns to role selection with no error snackbar.

Record the result (pass/fail per item) in the commit message.

- [ ] **Step 5: Final commit (docs/verification note)**

```bash
git commit --allow-empty -m "test: verify LLM removal — analyze clean, app builds, detail page renders KB, no chat button"
```

---

## Notes for the implementer

- **Do NOT** touch `Location.knowledgeBase`, `KnowledgeBaseEditorScreen`, or the KB rendering in
  `location_detail_page.dart` — the knowledge base is retained content, only the *chat* is removed.
- **`clear()` in `SettingsRepository`** is intentionally left in this phase; it is handled in Phase 3.
- If `flutter pub get` in Task 8 pulls transitive packages that were only needed by fllama, that is
  fine — `flutter pub get` prunes them automatically; do not hand-edit `pubspec.lock`.
- After this phase merges, update `docs/superpowers/plans/00-campconnect-production-roadmap.md`
  checklist: mark Phase 1 done.
