# UI/UX Follow-Up Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Fix the P2/P3 findings from the 2026-07-13 re-measure critique (`.impeccable/critique/2026-07-13T10-58-43Z__lib.md`, score 33/40 up from 25/40): unguarded release-build debug logging, a "grey" preset in the team color picker that contradicts the app's own "grey = bug" rule, a hardcoded-English locale string, missing IconButton tooltips plus one `Semantics(selected:)` gap, points-award chip-cluster density, and the total absence of first-run onboarding for kid users. The two P1s from that critique (kid-login CTA contrast, kid emergency-channel policy) were already closed out in the same session this plan was written in — this plan covers what's left.

**Architecture:** CampConnect is a Flutter app (Material 3, Riverpod, go_router, Firestore) with a committed theme in `lib/core/theme/app_theme.dart` and l10n via gen-l10n (`AppL10n`, template ARB is `lib/l10n/app_ro.arb` — every new key goes into `app_ro.arb`, `app_en.arb`, AND `app_hu.arb`; run `flutter gen-l10n` after ARB edits). Tasks are ordered mechanical-first (logging, color preset, locale string, tooltips) then UI-judgment-heavier (chip density, onboarding).

**Tech Stack:** Flutter/Dart, flutter_test + mocktail (widget tests), gen-l10n.

**House rules for the executor:**
- After every code change run `flutter analyze --no-pub` (must stay at "No issues found!") and the tests named in the step.
- All user-facing strings go through l10n. Never hard-code UI text.
- Grey is the owner's "bug color" — this plan removes the one remaining place it's offered as a deliberate choice.
- Commits are pre-approved per task, same convention as the prior remediation plan. **Do not push** — ask the controlling session/owner before any `git push`.

**Verification commands (used throughout):**
```powershell
flutter analyze --no-pub          # expect: No issues found!
flutter test                      # full suite
flutter gen-l10n                  # after any ARB change
```

---

### Task 1: Strip debug logging from release builds

23 `debugPrint(...)` calls across 7 files execute unguarded in release builds (flagged in the 2026-07-12 plan's own "Out of scope" list, and re-confirmed by the 2026-07-13 critique's deterministic scan). Introduce a single `debugLog` helper that no-ops outside debug builds, and migrate every call site.

**Files:**
- Create: `lib/core/utils/debug_log.dart`
- Test: `test/core/utils/debug_log_test.dart` (create)
- Modify (replace `debugPrint(` with `debugLog(`, add the import): `lib/shared/services/fcm_service.dart` (2 calls, lines 35,45), `lib/shared/services/logo_cache_service.dart` (7 calls, lines 40,49,69,71,83,94,97), `lib/features/auth/data/session_auto_select.dart` (1 call, line 31), `lib/features/settings/presentation/kid_settings_screen.dart` (1 call, line 153), `lib/features/settings/presentation/guide_settings_screen.dart` (1 call, line 156), `lib/features/journal/presentation/journal_export_screen.dart` (10 calls, lines 62,65,103,121,125,136,139,145,207,228), `lib/features/map/presentation/add_session_location_screen.dart` (1 call, line 134)

- [x] **Step 1: Write the failing test**

Create `test/core/utils/debug_log_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/core/utils/debug_log.dart';

void main() {
  test('debugLog forwards to debugPrint (kDebugMode is true under flutter test)',
      () {
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = original);

    debugLog('hello world');

    expect(messages, contains('hello world'));
  });
}
```

Run: `flutter test test/core/utils/debug_log_test.dart` → FAIL (no such file `debug_log.dart`).

- [x] **Step 2: Create the helper**

Create `lib/core/utils/debug_log.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Debug-only logging: swallowed entirely in release builds. Use this
/// instead of calling `debugPrint` directly so diagnostic noise never
/// ships to production (2026-07-13 critique finding: 23 unguarded
/// debugPrint calls previously executed in release builds).
void debugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
```

Run: `flutter test test/core/utils/debug_log_test.dart` → PASS.

- [x] **Step 3: Migrate every call site**

In each of the 7 files listed above: add `import 'package:camp_connect/core/utils/debug_log.dart';` (place alphabetically among existing `camp_connect` imports) and replace every `debugPrint(` occurrence with `debugLog(` — the argument (a String, sometimes multi-line/interpolated) is unchanged, only the function name changes. Example (`lib/features/auth/data/session_auto_select.dart:31`):

```dart
// BEFORE
debugPrint('[AUTO_SELECT] autoSelectActiveSession failed (non-fatal): $e');
// AFTER
debugLog('[AUTO_SELECT] autoSelectActiveSession failed (non-fatal): $e');
```

After migrating each file, run `flutter analyze --no-pub` on it — if `package:flutter/foundation.dart` becomes an unused import in a given file (some files, like `logo_cache_service.dart`, import it for other reasons too — check before removing), the analyzer will flag it; remove the import only if it's genuinely unused after the migration. Do not remove `flutter/foundation.dart` from `debug_log.dart` itself (it's needed there for `kDebugMode`/`debugPrint`).

- [x] **Step 4: Run guard + analyzer + full tests**

Run: `flutter analyze --no-pub` → "No issues found!" (confirms no unused imports, no missed call sites — a leftover raw `debugPrint(` would still compile, so also grep to confirm: `grep -rn "debugPrint(" lib --include="*.dart"` should return zero hits outside `lib/core/utils/debug_log.dart` itself).
Run: `flutter test` → all pass.

- [x] **Step 5: Commit**

```powershell
git add lib/core/utils/debug_log.dart lib/shared/services/fcm_service.dart lib/shared/services/logo_cache_service.dart lib/features/auth/data/session_auto_select.dart lib/features/settings/presentation/kid_settings_screen.dart lib/features/settings/presentation/guide_settings_screen.dart lib/features/journal/presentation/journal_export_screen.dart lib/features/map/presentation/add_session_location_screen.dart test/core/utils/debug_log_test.dart
git commit -m "fix: strip debug logging from release builds via debugLog helper"
```

---

### Task 2: Remove grey from the team color picker

`lib/core/theme/team_colors.dart:24` includes `'#757575', // grey` in `presetHexes`, the list `teams_management_screen.dart`'s `BlockPicker` offers to guides. This is the one place a guide can hand a kid's team the exact color the rest of the app treats as a bug (`team_colors.dart:44-47` documents grey as "never a deliberate choice" — yet the picker offers it as one).

**Files:**
- Modify: `lib/core/theme/team_colors.dart:24`
- Test: `test/core/theme/team_colors_test.dart` (extend)

- [x] **Step 1: Write the failing test**

Append to `test/core/theme/team_colors_test.dart` (inside `main()`):

```dart
  test('presetHexes never offers grey as a pickable team color', () {
    expect(TeamColors.presetHexes, isNot(contains('#757575')));
  });
```

Run: `flutter test test/core/theme/team_colors_test.dart` → new test FAILS (grey is still in the list).

- [x] **Step 2: Remove the grey preset**

In `lib/core/theme/team_colors.dart`, delete line 24 entirely:

```dart
// BEFORE
    '#6D4C41', // brown
    '#757575', // grey
  ];
// AFTER
    '#6D4C41', // brown
  ];
```

Do not touch `hexForColorName`'s `'grey'/'gray'/'gri'/'szürke'/'szurke' => '#757575'` mapping (lines ~106-111) or `_legacyGreyArgb` (line 47) — both exist to gracefully resolve legacy/imported data that already contains grey, which is a different concern from what the picker *offers* going forward.

- [x] **Step 3: Run tests**

Run: `flutter test test/core/theme/team_colors_test.dart` → all pass (including the two pre-existing tests — neither hardcodes the list length or the grey hex, so they're unaffected).
Run: `flutter analyze --no-pub` → clean.

- [x] **Step 4: Commit**

```powershell
git add lib/core/theme/team_colors.dart test/core/theme/team_colors_test.dart
git commit -m "fix: remove grey from team color picker presets"
```

---

### Task 3: Localize the "saved to Downloads" export message

`lib/features/journal/presentation/journal_export_screen.dart:327` hardcodes the English word "Downloads" in the post-export success message regardless of the RO/HU locale the rest of the string is localized in.

**Files:**
- Modify: `lib/features/journal/presentation/journal_export_screen.dart:325-328`
- Modify: `lib/l10n/app_ro.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_hu.arb`

- [x] **Step 1: Add the l10n key (all three ARBs)**

The physical Android folder this saves to is always named `Download` on-device regardless of locale (the OS doesn't localize its own directory name), so the fix localizes the sentence around the path, not the literal folder-name segment — keeping "Downloads" as a literal, consistent path fragment across all three locales is intentional, not an oversight.

`app_ro.arb` (template):
```json
  "pdfSavedToDownloads": "Salvat în Downloads/{filename}",
  "@pdfSavedToDownloads": {
    "placeholders": {
      "filename": {"type": "String"}
    }
  },
```

`app_en.arb`: `"pdfSavedToDownloads": "Saved to Downloads/{filename}"`.
`app_hu.arb`: `"pdfSavedToDownloads": "Mentve: Downloads/{filename}"`.

Place near `pdfExported` (the existing neighboring key in this screen's ARB entries). Run `flutter gen-l10n` → succeeds.

- [x] **Step 2: Use the new key**

In `lib/features/journal/presentation/journal_export_screen.dart`, replace the string interpolation:

```dart
// BEFORE
                    _savedToDownloads
                        ? '${l10n.pdfExported}\nDownloads/$_filename'
                        : l10n.pdfExported,
// AFTER
                    _savedToDownloads
                        ? '${l10n.pdfExported}\n${l10n.pdfSavedToDownloads(_filename)}'
                        : l10n.pdfExported,
```

- [x] **Step 3: Verify**

Run: `flutter analyze --no-pub` → clean.
Run: `flutter test` → pass (check `test/features/journal/` for any test asserting the old hardcoded string; update it to use `l10n.pdfSavedToDownloads(...)` if found — grep first: `grep -rn "Downloads/" test/`).

- [x] **Step 4: Commit**

```powershell
git add lib/features/journal/presentation/journal_export_screen.dart lib/l10n
git commit -m "fix: localize the pdf-saved-to-Downloads export message"
```

---

### Task 4: Missing tooltips + one Semantics(selected:) gap

12 `IconButton`s lack a `tooltip:` (a floor from the critique's sampling, all individually confirmed by direct inspection for this plan), and one location-picker card conveys its selected state by color alone with no `Semantics(selected:)` wrapper, unlike the correct pattern already used on the points-management team selector and the map filter chips.

**Files:**
- Modify: `lib/features/auth/presentation/guide_login_screen.dart:216,344`, `lib/features/auth/presentation/kid_login_screen.dart:111`, `lib/features/organization/presentation/organization_screen.dart:155,280`, `lib/features/leaderboard/presentation/teams_management_screen.dart:49,54`, `lib/features/leaderboard/presentation/points_management_screen.dart:746,777`, `lib/features/journal/presentation/journal_editor_screen.dart:632`, `lib/features/map/presentation/knowledge_base_editor_screen.dart:110`, `lib/features/auth/presentation/camp_session_screen.dart:588`
- Modify: `lib/features/map/presentation/add_session_location_screen.dart:270-357` (Semantics gap)
- Modify: `lib/l10n/app_ro.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_hu.arb`
- Test: `test/features/map/add_session_location_screen_test.dart` (extend if it exists, else create) and `test/features/auth/guide_login_screen_test.dart` (extend)

- [x] **Step 1: Add the new l10n keys (all three ARBs)**

Five new generic, reusable keys are needed (`dismiss` already exists — reused as-is at Step 2 below, do NOT add it again; confirmed via `grep -n '"dismiss"' lib/l10n/app_en.arb`, it's already used by `Day0ChecklistCard`'s own close-icon tooltip):

`app_ro.arb` (template):
```json
  "back": "Înapoi",
  "copy": "Copiază",
  "showPassword": "Arată parola",
  "hidePassword": "Ascunde parola",
  "removeTeam": "Elimină echipa",
```
`app_en.arb`: `"back": "Back", "copy": "Copy", "showPassword": "Show password", "hidePassword": "Hide password", "removeTeam": "Remove team"`.
`app_hu.arb`: `"back": "Vissza", "copy": "Másolás", "showPassword": "Jelszó megjelenítése", "hidePassword": "Jelszó elrejtése", "removeTeam": "Csapat eltávolítása"`.

Run `flutter gen-l10n` → succeeds.

- [x] **Step 2: Wire the 12 tooltips**

Two back-arrow buttons — `guide_login_screen.dart:216` and `kid_login_screen.dart:111`:
```dart
// BEFORE
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/role-selection'),
        ),
// AFTER
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: l10n.back,
          onPressed: () => context.go('/role-selection'),
        ),
```

Password visibility toggle — `guide_login_screen.dart:344` (tooltip must reflect what tapping DOES, i.e. the opposite of the current obscured state):
```dart
// BEFORE
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
// AFTER
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        tooltip: _obscurePassword
                            ? l10n.showPassword
                            : l10n.hidePassword,
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
```

Copy buttons — `organization_screen.dart:155` (copy invite code), `points_management_screen.dart:746` (copy TV URL), `points_management_screen.dart:777` (copy session code) — same pattern at each site, add `tooltip: l10n.copy,` right after the `icon:` line, e.g.:
```dart
// BEFORE (organization_screen.dart:155-157)
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
// AFTER
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: l10n.copy,
                  onPressed: () async {
```

Edit/delete team — `teams_management_screen.dart:49` and `:54` (reuse the existing generic `l10n.edit`/`l10n.delete` keys, already used identically elsewhere in the app since Task 7 of the prior plan):
```dart
// BEFORE (:49-52)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _showTeamDialog(context, ref, campId, t),
                              ),
// AFTER
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: l10n.edit,
                                onPressed: () =>
                                    _showTeamDialog(context, ref, campId, t),
                              ),
```
```dart
// BEFORE (:54-59)
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                onPressed: () => _confirmDelete(
                                  context,
// AFTER
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                tooltip: l10n.delete,
                                onPressed: () => _confirmDelete(
                                  context,
```

Edit trailing icon — `organization_screen.dart:280`:
```dart
// BEFORE
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: edit,
        ),
// AFTER
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: l10n.edit,
          onPressed: edit,
        ),
```

Dismiss prompt banner — `journal_editor_screen.dart:632`:
```dart
// BEFORE
          trailing: IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClear,
          ),
// AFTER
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.dismiss,
            onPressed: onClear,
          ),
```
(`l10n` must be in scope in this `_PromptBanner.build` method — it already is, per the existing `final l10n = AppL10n.of(context);` at the top of that method.)

Save button — `knowledge_base_editor_screen.dart:110` (reuse the existing generic `l10n.saveEntry` key — its value is the plain word "Save"/"Salvează"/"Mentés" in all three locales despite the journal-specific key name, so it's safe to reuse here):
```dart
// BEFORE
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _save,
          ),
// AFTER
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: l10n.saveEntry,
            onPressed: _isSaving ? null : _save,
          ),
```

Remove-team-row — `camp_session_screen.dart:588`:
```dart
// BEFORE
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      onPressed: _teams.length <= 1
                          ? null
// AFTER
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      tooltip: l10n.removeTeam,
                      onPressed: _teams.length <= 1
                          ? null
```

For every site above, confirm `l10n` is an in-scope local variable in that `build` method before adding the reference (all 12 sites are inside methods that already resolve `AppL10n.of(context)` for other strings on the same screen — verify, don't assume).

- [x] **Step 3: Fix the Semantics gap**

In `lib/features/map/presentation/add_session_location_screen.dart`, `_buildLocationCard` currently conveys selection via `color:` alone. Wrap the returned `Card` in `Semantics`, matching the pattern already used correctly in `points_management_screen.dart:311-315` and `map_screen.dart:469`:

```dart
// BEFORE (:273-277)
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
// AFTER
    return Semantics(
      button: true,
      selected: isSelected,
      label: location.name,
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.only(bottom: 8),
        color: isSelected ? theme.colorScheme.primaryContainer : null,
        child: InkWell(
```

This requires re-indenting the rest of `_buildLocationCard`'s body one level deeper (it now nests inside `Semantics(child: Card(child: ...))`) and adding the matching closing `),` for both new wrapping widgets at the end of the method. Read the full method (`add_session_location_screen.dart:270-360`) before editing so the brace/paren nesting comes out balanced — `flutter analyze` will catch a mismatch immediately if it doesn't.

- [x] **Step 4: Write regression tests**

Extend `test/features/auth/guide_login_screen_test.dart` (append inside `main()`). The file's real `buildTestable()` helper takes a `GuideLoginMode` argument (see its existing usage at line 64, `buildTestable(GuideLoginMode.createOrg)`) and already registers a `/role-selection` route in its test router, which is exactly where the back button navigates:

```dart
  testWidgets('back button and password toggle have tooltips', (tester) async {
    await tester.pumpWidget(buildTestable(GuideLoginMode.createOrg));
    final l10n = AppL10n.of(tester.element(find.byType(GuideLoginScreen)));

    expect(find.byTooltip(l10n.back), findsOneWidget);
    expect(find.byTooltip(l10n.showPassword), findsOneWidget);
  });
```

For the Semantics fix, check whether `test/features/map/add_session_location_screen_test.dart` already exists (`grep -rl "AddSessionLocationScreen" test/`). If it exists, extend it; if not, this fix doesn't need a dedicated new test file — the widget test coverage gap here is pre-existing and out of this task's scope (only add a test if a suitable harness already exists to extend cheaply; don't stand up new provider-mocking infrastructure just for this one assertion, matching the judgment call made for the announcement-sheet drag-dismiss fix in the prior plan).

- [x] **Step 5: Verify + commit**

Run: `flutter analyze --no-pub` → clean.
Run: `flutter test` → pass.

```powershell
git add lib/features/auth/presentation/guide_login_screen.dart lib/features/auth/presentation/kid_login_screen.dart lib/features/organization/presentation/organization_screen.dart lib/features/leaderboard/presentation/teams_management_screen.dart lib/features/leaderboard/presentation/points_management_screen.dart lib/features/journal/presentation/journal_editor_screen.dart lib/features/map/presentation/knowledge_base_editor_screen.dart lib/features/auth/presentation/camp_session_screen.dart lib/features/map/presentation/add_session_location_screen.dart lib/l10n test
git commit -m "fix: add missing IconButton tooltips; Semantics(selected:) on location picker"
```

---

### Task 5: Points-award chip cluster — default to top 4, expand for the rest

`points_management_screen.dart:482-512` renders 13 simultaneous tap targets (10 amount chips + 3 reason-preset chips) in one region — the one place in the app that fails the app's own ≤4-visible-options cognitive-load guideline, on the screen where a guide is moving fastest.

**Files:**
- Modify: `lib/features/leaderboard/presentation/points_management_screen.dart`
- Modify: `lib/l10n/app_ro.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_hu.arb`
- Test: `test/features/leaderboard/points_management_screen_test.dart` (extend if it exists, else create)

- [x] **Step 1: Add the l10n key (all three ARBs)**

`app_ro.arb`: `"moreAmounts": "Mai multe"`. `app_en.arb`: `"moreAmounts": "More amounts"`. `app_hu.arb`: `"moreAmounts": "Több összeg"`. Run `flutter gen-l10n`.

- [x] **Step 2: Lift a `_showMoreAmounts` flag into `_PointsManagementScreenState`**

`_PointsInputForm` (points_management_screen.dart:390) is a `StatelessWidget`; add the toggle state to the parent `_PointsManagementScreenState` (which already owns `_selectedTeam`, `_isSubmitting`, etc.) rather than converting `_PointsInputForm` to stateful — this matches the existing pattern where the parent owns all form state and passes it down.

In `_PointsManagementScreenState` (near the existing `bool _isSubmitting = false;` field):
```dart
  bool _showMoreAmounts = false;
```

Where `_PointsInputForm` is constructed (around points_management_screen.dart:214), add the two new parameters:
```dart
                  child: _PointsInputForm(
                    pointsController: _pointsController,
                    reasonController: _reasonController,
                    isSubmitting: _isSubmitting,
                    selectedTeam: teams
                        .where((t) => t.id == _selectedTeam)
                        .firstOrNull,
                    onSubmit: _submitPoints,
                    showMoreAmounts: _showMoreAmounts,
                    onToggleMoreAmounts: () =>
                        setState(() => _showMoreAmounts = !_showMoreAmounts),
                  ),
```

- [x] **Step 3: Thread the new parameters through `_PointsInputForm`**

In `_PointsInputForm`'s constructor and fields (points_management_screen.dart:390-410 — read the exact current field list first), add:
```dart
  final bool showMoreAmounts;
  final VoidCallback onToggleMoreAmounts;
```
and the corresponding `required this.showMoreAmounts` / `required this.onToggleMoreAmounts` constructor parameters, following the exact style of the existing fields in that class.

- [x] **Step 4: Split the amount-chip row into a default 4 + expander**

Replace the amount-chip `Wrap` (points_management_screen.dart:482-496):

```dart
// BEFORE
              // Quick-amount chips SET the field (tapping +50 twice is still
              // 50) — the running total was an invisible mental model for a
              // hurried guide (audit 2026-07-12).
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [-150, -100, -50, -25, -10, 10, 25, 50, 100, 150].map(
                  (amount) {
                    final label = amount > 0 ? '+$amount' : '$amount';
                    return ActionChip(
                      label: Text(label),
                      onPressed: () {
                        pointsController.text = '$amount';
                      },
                    );
                  },
                ).toList(),
              ),
// AFTER
              // Quick-amount chips SET the field (tapping +50 twice is still
              // 50) — the running total was an invisible mental model for a
              // hurried guide (audit 2026-07-12). Default to the 4 most
              // common amounts; the rest are one tap away behind "More
              // amounts" rather than all 13 chips competing for attention
              // at once (audit 2026-07-13 — cognitive-load ≤4 guideline).
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...[-50, -10, 10, 50].map((amount) {
                    final label = amount > 0 ? '+$amount' : '$amount';
                    return ActionChip(
                      label: Text(label),
                      onPressed: () {
                        pointsController.text = '$amount';
                      },
                    );
                  }),
                  if (showMoreAmounts)
                    ...[-150, -100, -25, 25, 100, 150].map((amount) {
                      final label = amount > 0 ? '+$amount' : '$amount';
                      return ActionChip(
                        label: Text(label),
                        onPressed: () {
                          pointsController.text = '$amount';
                        },
                      );
                    })
                  else
                    ActionChip(
                      avatar: Icon(
                        Icons.expand_more,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      label: Text(l10n.moreAmounts),
                      onPressed: onToggleMoreAmounts,
                    ),
                ],
              ),
```

(`theme` and `l10n` must already be in scope in `_PointsInputForm.build` — confirm by reading the method's opening lines before editing; every other chip/text in this widget already references both.)

- [x] **Step 5: Write a widget test for the collapse/expand behavior**

Check for an existing `test/features/leaderboard/points_management_screen_test.dart` (`grep -rl "PointsManagementScreen" test/`). If one exists, extend it with:

```dart
  testWidgets('amount chips default to 4, expand to all 10 on "More amounts"',
      (tester) async {
    await tester.pumpWidget(buildTestable()); // reuse the file's existing helper
    // Select a team first if the form only renders once one is selected —
    // mirror whatever setup the file's other _PointsInputForm-exercising
    // tests already do.

    expect(find.text('+50'), findsOneWidget);
    expect(find.text('+150'), findsNothing);

    final l10n = AppL10n.of(tester.element(find.byType(PointsManagementScreen)));
    await tester.tap(find.text(l10n.moreAmounts));
    await tester.pump();

    expect(find.text('+150'), findsOneWidget);
  });
```

If no such test file exists yet, standing up the full provider-mocking infrastructure for this one screen (it depends on `activeCampIdProvider`, `leaderboardProvider`, `leaderboardRepositoryProvider`, `appUserProvider`, and more) is disproportionate to this task alone — report `DONE_WITH_CONCERNS`, skip the widget test, and rely on `flutter analyze` + manual code review of the diff instead, same judgment call precedent set in the prior plan's Task 9 fix commit.

- [x] **Step 6: Verify + commit**

Run: `flutter analyze --no-pub` → clean.
Run: `flutter test` → pass.

```powershell
git add lib/features/leaderboard/presentation/points_management_screen.dart lib/l10n test
git commit -m "fix: points-award amount chips default to top 4, rest behind an expander"
```

---

### Task 6: Kid home first-run onboarding card

`kid_home_screen.dart` renders a team card, up-next widget, stat tiles, and a passport-progress tile immediately on first login with zero explainer anywhere — a 7-14 year-old first-timer has no way to learn what points or the "Explorer Passport" mean except by trial or asking a counselor.

There is already an exact precedent for this in the codebase: `lib/features/home/presentation/day0_checklist_card.dart` (`Day0ChecklistCard`, shown on the guide home screen) is a small, self-contained `ConsumerStatefulWidget` that reads/writes `sharedPreferencesProvider` directly (no separate Riverpod provider needed), hides itself with `SizedBox.shrink()` once dismissed, and has its own isolated widget test (`test/features/home/day0_checklist_card_test.dart`, pumped standalone in a bare `Scaffold`, not through the full guide home screen). Mirror this pattern exactly rather than inventing a new one.

**Files:**
- Create: `lib/features/home/presentation/kid_onboarding_card.dart`
- Modify: `lib/features/home/presentation/kid_home_screen.dart`
- Modify: `lib/l10n/app_ro.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_hu.arb`
- Test: `test/features/home/kid_onboarding_card_test.dart` (create)

- [x] **Step 1: Add the l10n keys (all three ARBs)**

Only 2 new keys are needed — the dismiss icon reuses the existing `dismiss` key (`app_en.arb:253`, already used by `Day0ChecklistCard`'s own close-icon tooltip; do not add it again).

`app_ro.arb`:
```json
  "onboardingTitle": "Bine ai venit la tabără!",
  "onboardingBody": "Câștigă puncte pentru echipa ta la activități și adună ștampile în Pașaportul de Explorator vizitând locuri de pe hartă.",
```
`app_en.arb`: `"onboardingTitle": "Welcome to camp!", "onboardingBody": "Earn points for your team at activities, and collect stamps in your Explorer Passport by visiting places on the map."`.
`app_hu.arb`: `"onboardingTitle": "Üdvözlünk a táborban!", "onboardingBody": "Szerezz pontokat a csapatodnak a foglalkozásokon, és gyűjts pecséteket a Felfedező Útlevélbe a térkép helyeinek felfedezésével."`.

Run `flutter gen-l10n`.

- [x] **Step 2: Write the failing test**

Create `test/features/home/kid_onboarding_card_test.dart`, mirroring `test/features/home/day0_checklist_card_test.dart`'s exact `buildTestable()` structure:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/features/home/presentation/kid_onboarding_card.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

void main() {
  AppUser kid(String uid) => AppUser(
    uid: uid,
    role: 'kid',
    displayName: 'X',
    orgId: 'org-1',
    createdAt: DateTime(2026, 7, 1),
  );

  Future<Widget> buildTestable({required String uid}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appUserProvider.overrideWith((ref) => Future.value(kid(uid))),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(body: KidOnboardingCard()),
      ),
    );
  }

  testWidgets('shows the onboarding card on first visit', (tester) async {
    await tester.pumpWidget(await buildTestable(uid: 'kid-1'));
    await tester.pumpAndSettle();

    final l10n = AppL10n.of(tester.element(find.byType(KidOnboardingCard)));
    expect(find.text(l10n.onboardingTitle), findsOneWidget);
    expect(find.text(l10n.onboardingBody), findsOneWidget);
  });

  testWidgets('dismiss hides the card', (tester) async {
    await tester.pumpWidget(await buildTestable(uid: 'kid-1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
  });
}
```

Run: `flutter test test/features/home/kid_onboarding_card_test.dart` → FAIL (no such file `kid_onboarding_card.dart`).

- [x] **Step 3: Create the widget**

Create `lib/features/home/presentation/kid_onboarding_card.dart`, structurally mirroring `Day0ChecklistCard` (`lib/features/home/presentation/day0_checklist_card.dart:13-34`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// First-run explainer for a kid's very first visit to the home screen:
/// what points and the Explorer Passport are. Dismissal is stored locally
/// per uid (GDPR: no server write) and the card never reappears after that
/// (2026-07-13 critique finding: zero onboarding existed before this).
class KidOnboardingCard extends ConsumerStatefulWidget {
  const KidOnboardingCard({super.key});

  @override
  ConsumerState<KidOnboardingCard> createState() => _KidOnboardingCardState();
}

class _KidOnboardingCardState extends ConsumerState<KidOnboardingCard> {
  String _dismissKey(String uid) => 'kid_onboarding_dismissed_$uid';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const SizedBox.shrink();

    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs.getBool(_dismissKey(user.uid)) ?? false) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.onboardingTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.dismiss,
                    onPressed: () async {
                      await prefs.setBool(_dismissKey(user.uid), true);
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
              Text(l10n.onboardingBody, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
```

Run: `flutter test test/features/home/kid_onboarding_card_test.dart` → PASS.

- [x] **Step 4: Wire it into the kid home screen**

In `lib/features/home/presentation/kid_home_screen.dart`, add the import (alphabetically among the other `camp_connect` imports) and insert the card right after the greeting `Row`, before the `campSessionAsync.when(...)` block (read the current structure around lines 54-90 first to confirm exact placement — this file was last touched in the prior plan's Task 8, which only changed the greeting `Row` itself, so everything below it should be unshifted):

```dart
import 'package:camp_connect/features/home/presentation/kid_onboarding_card.dart';
```
```dart
                  const SizedBox(height: 6),
                  const KidOnboardingCard(),
                  campSessionAsync.when(
```

- [x] **Step 5: Verify + commit**

Run: `flutter analyze --no-pub` → clean.
Run: `flutter test` → pass (including both new tests and the full suite).

```powershell
git add lib/features/home/presentation/kid_onboarding_card.dart lib/features/home/presentation/kid_home_screen.dart lib/l10n test/features/home/kid_onboarding_card_test.dart
git commit -m "feat: dismissible first-run onboarding card on kid home screen"
```

---

## Out of scope (explicitly deferred)

- Guide bottom nav still carries 6 destinations vs. the kid shell's 5 — the 5-cap was a kid-specific decision in the prior plan; not revisited here.
- Guide settings logout has no confirmation dialog while kid settings logout does — noted as defensible asymmetry (guide accounts are re-loggable, kid accounts are anonymous/one-shot), not treated as a bug.
- `announcement_management_screen.dart` at 1301 lines (maintainability outlier, not a design defect) — a refactor candidate if it keeps growing, not scoped here.
- Third-party `BlockPicker` widget's own internal accessibility (semantic labels on individual color swatches) — outside this app's code to fix; noted as a known limitation of the dependency.
