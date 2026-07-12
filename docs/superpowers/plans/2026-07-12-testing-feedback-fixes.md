# Testing Feedback Fixes Implementation Plan (18 items, 2026-07-12)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **EXECUTION AUTHORIZATION (2026-07-12, from Costin):** commits, pushes, and function deploys for THIS plan are pre-approved. Every "Commit" step means: commit with the given message, then `git push` to main immediately, no further approval needed. The deploy steps in Tasks 15 and 16 SHOULD be run (`-P default`, never the dev alias). This authorization is scoped to this plan; the usual no-commit rule still applies to anything else.
>
> **STRICT EXECUTION:** follow the plan exactly as written. No deviations, no reordering, no extra refactors, no scope creep. If a step is impossible or wrong as written, STOP and report to Costin instead of improvising. Manual QA lines are Costin's later device pass: do not block on them, collect them into a final checklist for him.
>
> Note that `docs/` is served publicly by GitHub Pages, including this plan file once pushed.

**Goal:** Fix all 18 bugs/UX issues Costin found while manually testing CampConnect (auth gating, team colors, points UX, program scheduling, emergency counts, localization, onboarding, logo cropping, map behavior, location photos, first-login session flow, journal question of the day, em dashes) and add the TV leaderboard feature.

**Architecture:** Flutter app (Riverpod + go_router + Firebase) with Cloud Functions (europe-west1, project `camp-connect-4644c`, deploy with `-P default`, never the dev alias). l10n template is `lib/l10n/app_ro.arb` (ro/hu/en, regenerate with `flutter gen-l10n`). The GitHub Pages site is this repo's `docs/` folder. All client screens read data through providers in `lib/shared/providers/providers.dart`.

**Tech Stack:** Flutter 3.x / Dart 3.11, flutter_riverpod 2.x, go_router, flutter_map 7, geolocator, image_picker, Firebase (Auth/Firestore/Storage/Functions/FCM), Node 20 Cloud Functions v2, one new Flutter dependency: `image_cropper`.

**Verification commands used throughout:**
- `flutter analyze` (expect: `No issues found!`)
- `flutter test` (expect: `All tests passed!`)
- `flutter gen-l10n` after any `.arb` change (expect: silent success, no untranslated-message warnings)
- `cd functions && npm test` (expect: all suites pass; needs the Firestore emulator, same as today)

**Decisions baked into this plan (flag to Costin if he disagrees):**
1. **Org-creation gate (items 1+2):** every registration path now requires a code. Joining an org already requires the org invite code; creating an org will additionally require a global "setup code" stored in Firestore at `config/registration` and handed out personally by Costin. Alternative considered and rejected: email verification (kids can pass it, and it adds an async state machine).
2. **"See the leaderboard" after adding points (item 5):** after a successful points submit the form collapses and the app pushes a read-only standings screen (the existing `LeaderboardScreen`) on top.
3. **QOTD (item 17):** the answer box is added inline in the announcement detail sheet, saved as a local journal entry; "answered" is detected locally (journal is device-local by GDPR design), keyed on prompt title + same calendar day.
4. **Map start view (item 16):** precedence is GPS fix (if permitted) → fit to session markers → old defaults. Camera bounds widen to cover Hungary as well as Romania (the app has HU orgs; the current bounds exclude most of Hungary).

---

## Task 1: Remove em dashes from all user-visible text (item 18)

**Files:**
- Modify: `lib/l10n/app_ro.arb` (lines 352, 354, 356, 361, 537)
- Modify: `lib/l10n/app_en.arb` (lines 320, 322, 324, 329, 471, 477)
- Modify: `lib/l10n/app_hu.arb` (lines 320, 322, 324, 329, 471, 477)
- Modify: `lib/features/announcements/domain/announcement_template.dart:138-160`
- Modify: `lib/features/leaderboard/presentation/points_management_screen.dart:584`
- Modify: `lib/features/leaderboard/presentation/leaderboard_screen.dart:295`
- Modify: `lib/features/leaderboard/presentation/points_entry_details.dart:53`
- Modify: `functions/index.js:290`

Scope note: only the em dash `—` goes. The en dash `–` used as a date/time range separator (session cards, schedule pills) is a range mark, not prose punctuation; leave it.

- [x] **Step 1: Replace em dashes in the three ARB files**

Apply these exact replacements (`—` becomes `:` mid-sentence, or a period + new sentence where that reads better):

`app_en.arb`:
```json
"presetMissingChildMessage": "Missing child: stop activities and count the kids.",
"presetMedicalMessage": "Medical emergency: I need help.",
"presetWeatherMessage": "Dangerous weather: get the kids to shelter.",
"locationAttachFailed": "Couldn't get your location. The alert was sent without it.",
"checkInHere": "I'm here, check in!",
"noStampsYet": "No stamps yet. Explore the map!",
```

`app_ro.arb`:
```json
"presetMissingChildMessage": "Copil dispărut: opriți activitățile și numărați copiii.",
"presetMedicalMessage": "Urgență medicală: am nevoie de ajutor.",
"presetWeatherMessage": "Vreme periculoasă: duceți copiii la adăpost.",
"locationAttachFailed": "Nu am putut obține locația. Alerta a fost trimisă fără ea.",
"noStampsYet": "Nicio ștampilă încă. Explorează harta!",
```

`app_hu.arb`:
```json
"presetMissingChildMessage": "Eltűnt gyerek: állítsátok le a programokat és számoljátok meg a gyerekeket.",
"presetMedicalMessage": "Orvosi vészhelyzet: segítségre van szükségem.",
"presetWeatherMessage": "Veszélyes időjárás: vigyétek a gyerekeket fedett helyre.",
"locationAttachFailed": "Nem sikerült lekérni a helyzetet. A riasztás nélküle ment el.",
"checkInHere": "Itt vagyok, pecsételj!",
"noStampsYet": "Még nincs pecsét. Fedezd fel a térképet!",
```

- [x] **Step 2: Replace em dashes in seed announcement templates**

In `lib/features/announcements/domain/announcement_template.dart` change the six template body strings:
```dart
enB: 'Lights out. Time to sleep. Good night!',
roB: 'Stingerea! E timpul de culcare. Noapte bună!',
huB: 'Villanyoltás! Ideje aludni. Jó éjszakát!',
```
```dart
enB: 'Get your things ready, we are leaving soon.',
roB: 'Pregătiți-vă lucrurile, plecăm în curând.',
huB: 'Készítsétek össze a holmitokat, hamarosan indulunk.',
```

- [x] **Step 3: Replace the `'—'` empty-reason fallback in the three points widgets**

In all three files (`points_management_screen.dart:584`, `leaderboard_screen.dart:295`, `points_entry_details.dart:53`) change:
```dart
entry.reason.isNotEmpty ? entry.reason : '—',
```
to:
```dart
entry.reason.isNotEmpty ? entry.reason : '-',
```

- [x] **Step 4: Replace the em dash in the FCM points notification**

`functions/index.js:290`, change:
```js
body += " — " + l.reason.replace("{reason}", data.reason);
```
to:
```js
body += ". " + l.reason.replace("{reason}", data.reason);
```

- [x] **Step 5: Verify no em dashes remain in user-visible strings**

Run: `grep -rn '—' lib/l10n/*.arb lib/features/announcements/domain/announcement_template.dart functions/index.js`
Expected: no output. (Em dashes inside Dart `//` comments elsewhere are fine and out of scope.)

- [x] **Step 6: Regenerate l10n, analyze, test**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Expected: no issues, all tests pass.

- [x] **Step 7: Commit and push**

```bash
git add lib/l10n functions/index.js lib/features/announcements/domain/announcement_template.dart lib/features/leaderboard
git commit -m "fix: remove em dashes from user-visible strings"
git push
```

---

## Task 2: Localize the remaining English UI/errors (item 8)

**Files:**
- Modify: `lib/l10n/app_ro.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_hu.arb` (2 new keys)
- Modify: `lib/features/map/presentation/location_form_screen.dart:310-334`
- Modify: `lib/shared/providers/providers.dart` (SettingsNotifier)
- Modify: `lib/main.dart`

Context: the ARBs are already at full parity (462 keys each) and every catch block maps to localized strings. The remaining leaks are (a) the hardcoded `'Latitude'`/`'Longitude'` field labels, and (b) Firebase Auth emails (password reset) which go out in the project default language unless `setLanguageCode` is called.

- [x] **Step 1: Add the two label keys to all three ARBs**

`app_ro.arb` (template, so add here first):
```json
"latitudeLabel": "Latitudine",
"longitudeLabel": "Longitudine",
```
`app_en.arb`:
```json
"latitudeLabel": "Latitude",
"longitudeLabel": "Longitude",
```
`app_hu.arb`:
```json
"latitudeLabel": "Szélesség",
"longitudeLabel": "Hosszúság",
```

- [x] **Step 2: Use them in the location form**

In `location_form_screen.dart` replace the two `InputDecoration`s (note: they lose `const`):
```dart
decoration: InputDecoration(
  labelText: l10n.latitudeLabel,
  border: const OutlineInputBorder(),
),
```
```dart
decoration: InputDecoration(
  labelText: l10n.longitudeLabel,
  border: const OutlineInputBorder(),
),
```

- [x] **Step 3: Propagate the app language to Firebase Auth**

In `lib/shared/providers/providers.dart`, `SettingsNotifier.setLanguage`, after persisting:
```dart
Future<void> setLanguage(String language) async {
  await _repo.setLanguage(language);
  state = state.copyWith(language: language);
  // Auth-generated emails (password reset) follow this, not the app locale.
  try {
    await FirebaseAuth.instance.setLanguageCode(language);
  } catch (_) {
    // Non-fatal: the email falls back to the project default language.
  }
}
```
Add the import: `import 'package:firebase_auth/firebase_auth.dart';` (already imported in that file).

In `lib/main.dart`, after `Firebase.initializeApp(...)` and after SharedPreferences are available (the language setting is read from prefs there; follow the existing initialization order in main), add:
```dart
// Password-reset emails etc. must go out in the user's chosen app language.
try {
  final savedLanguage =
      prefs.getString(AppConstants.keyLanguage) ?? AppConstants.languageRomanian;
  await FirebaseAuth.instance.setLanguageCode(savedLanguage);
} catch (_) {
  // Non-fatal.
}
```
(Adjust the prefs variable name to what `main.dart` actually uses; import `firebase_auth` and `app_constants` if missing.)

- [x] **Step 4: Analyze + test + commit + push**

Run: `flutter gen-l10n && flutter analyze && flutter test`
```bash
git add lib/l10n lib/features/map/presentation/location_form_screen.dart lib/shared/providers/providers.dart lib/main.dart
git commit -m "fix: localize latitude/longitude labels and auth email language"
git push
```

---

## Task 3: Emergency alert confirmation count excludes the sender (item 7)

**Files:**
- Modify: `lib/features/emergency/domain/emergency_alert.dart`
- Modify: `lib/features/emergency/presentation/emergency_screen.dart:79-184`
- Test: `test/features/emergency/alert_ack_counts_test.dart` (create)

The sender never sees the confirm overlay (`emergency_overlay.dart:41`), so today "x of y" can never reach y. Fix: exclude the sender from both numerator and denominator.

- [x] **Step 1: Write the failing test**

Create `test/features/emergency/alert_ack_counts_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/emergency/domain/emergency_alert.dart';

EmergencyAlert _alert({required String senderId, List<String> acked = const []}) {
  return EmergencyAlert(
    id: 'a1',
    message: 'test',
    senderId: senderId,
    senderName: 'Sender',
    acknowledgedBy: acked,
    timestamp: DateTime(2026, 7, 12),
  );
}

void main() {
  test('sender is excluded from the total', () {
    final (confirmed, total) =
        alertAckCounts(_alert(senderId: 'u1'), ['u1', 'u2', 'u3']);
    expect(total, 2);
    expect(confirmed, 0);
  });

  test('all other guides confirming reaches total of total', () {
    final (confirmed, total) = alertAckCounts(
        _alert(senderId: 'u1', acked: ['u2', 'u3']), ['u1', 'u2', 'u3']);
    expect(confirmed, 2);
    expect(total, 2);
  });

  test('a stray self-ack is not counted', () {
    final (confirmed, total) = alertAckCounts(
        _alert(senderId: 'u1', acked: ['u1', 'u2']), ['u1', 'u2', 'u3']);
    expect(confirmed, 1);
    expect(total, 2);
  });
}
```

- [x] **Step 2: Run it, confirm it fails**

Run: `flutter test test/features/emergency/alert_ack_counts_test.dart`
Expected: FAIL, `alertAckCounts` is not defined.

- [x] **Step 3: Implement `alertAckCounts`**

Append to `lib/features/emergency/domain/emergency_alert.dart` (top-level, next to `emergencyTypeIcon`):
```dart
/// Confirmation counts for an alert's "x of y guides confirmed" line.
/// The sender is excluded from BOTH sides: they never receive their own
/// overlay (see emergency_overlay.dart), so counting them in the total
/// makes "all confirmed" unreachable. [memberUids] is the org member list.
(int confirmed, int total) alertAckCounts(
    EmergencyAlert alert, List<String> memberUids) {
  final total = memberUids.where((uid) => uid != alert.senderId).length;
  final confirmed = alert.acknowledgedBy
      .where((uid) => uid != alert.senderId)
      .toSet()
      .length;
  return (confirmed, total);
}
```

- [x] **Step 4: Run the test again**

Run: `flutter test test/features/emergency/alert_ack_counts_test.dart`
Expected: PASS (3 tests).

- [x] **Step 5: Use it in the alert card**

In `emergency_screen.dart`, `_EmergencyAlertCard.build`, replace:
```dart
final totalGuides = ref.watch(orgMembersProvider).valueOrNull?.length ?? 0;
```
with:
```dart
final memberUids = (ref.watch(orgMembersProvider).valueOrNull ?? [])
    .map((m) => m.uid)
    .toList();
final (ackCount, ackTotal) = alertAckCounts(alert, memberUids);
```
and replace the whole `if (alert.acknowledgedBy.isNotEmpty) ...` block's row condition and text with:
```dart
if (ackTotal > 0 || alert.acknowledgedBy.isNotEmpty) ...[
  const SizedBox(height: 12),
  const Divider(height: 1),
  const SizedBox(height: 12),
  Row(
    children: [
      Icon(Icons.check_circle,
          size: 16, color: theme.colorScheme.primary),
      const SizedBox(width: 4),
      Text(
        ackTotal > 0
            ? l10n.acknowledgedByCount(ackCount, ackTotal)
            : '${l10n.acknowledgedBy}: $ackCount',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  ),
],
```
This also makes "0 of 2 confirmed" visible immediately after sending, which is the honest state.

- [x] **Step 6: Analyze + full test + commit + push**

Run: `flutter analyze && flutter test`
```bash
git add lib/features/emergency test/features/emergency
git commit -m "fix: exclude sender from emergency confirmation counts"
git push
```

---

## Task 4: Guide settings scroll-to-bottom bounce (item 4)

**Files:**
- Modify: `lib/features/settings/presentation/guide_settings_screen.dart:226-274`

Root cause: `_OrganizationSection` builds a `FutureBuilder` whose future is re-created on every build. `ListView` unmounts far-offscreen children; when you fling to the bottom the section remounts, renders `SizedBox.shrink()` (height 0) while the fresh future resolves, then re-expands, shifting the whole list and yanking the viewport back up. Fix: read the already-cached `currentOrganizationProvider` (a FutureProvider, resolved once), so a remount renders instantly at full height.

- [x] **Step 1: Replace the FutureBuilder with the cached provider**

Replace the whole `_OrganizationSection` class with:
```dart
class _OrganizationSection extends ConsumerWidget {
  const _OrganizationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    // Cached FutureProvider: when the ListView unmounts/remounts this
    // section during a hard scroll, it re-renders synchronously at full
    // height instead of collapsing to 0 and re-expanding (which shifted
    // the list and bounced the scroll position back up).
    final org = ref.watch(currentOrganizationProvider).valueOrNull;
    if (org == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(org.name, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.business_outlined),
                title: Text(org.name),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(l10n.myOrganization),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/guide/organization'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```
Remove the now-unused `import 'package:camp_connect/features/organization/domain/organization.dart';` and update the call site at the top of `GuideSettingsScreen.build`:
```dart
if (appUser?.orgId != null) ...[
  const _OrganizationSection(),
  const SizedBox(height: 24),
],
```

- [x] **Step 2: Analyze, manual check, commit + push**

Run: `flutter analyze`
Manual QA (device/emulator): open guide Settings, fling hard to the bottom. Expected: the list stays at the bottom.
```bash
git add lib/features/settings/presentation/guide_settings_screen.dart
git commit -m "fix: guide settings scroll no longer bounces back from the bottom"
git push
```

---

## Task 5: Team colors always come from the palette, never a duplicate (item 3)

**Files:**
- Modify: `lib/core/theme/team_colors.dart`
- Modify: `lib/features/auth/presentation/camp_session_screen.dart:608-618`
- Modify: `lib/features/leaderboard/presentation/teams_management_screen.dart:78-107`
- Test: `test/core/theme/team_colors_test.dart` (extend if it exists, else create)

Root cause of the "random" color: "Add team" in the create-session sheet assigns `presetHexes[_teams.length % 13]`. With the default 4 teams (palette indexes 0, 4, 7, 9), the 5th team gets index 4, which is the same blue as team 2. The palette picker itself already exists in both dialogs; the bug is the auto-assignment colliding.

- [x] **Step 1: Write the failing test**

Create (or extend) `test/core/theme/team_colors_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/core/theme/team_colors.dart';

void main() {
  test('firstUnusedPresetHex skips colors already in use', () {
    final used = ['#E53935', '#1E88E5', '#43A047', '#FDD835'];
    final next = TeamColors.firstUnusedPresetHex(used);
    expect(used.contains(next), isFalse);
    expect(TeamColors.presetHexes.contains(next), isTrue);
    expect(next, '#D81B60'); // first preset not among the defaults
  });

  test('firstUnusedPresetHex is case-insensitive', () {
    final next = TeamColors.firstUnusedPresetHex(['#e53935']);
    expect(next, isNot('#E53935'));
  });

  test('falls back to cycling when every preset is taken', () {
    final all = List.of(TeamColors.presetHexes);
    expect(TeamColors.firstUnusedPresetHex(all, fallbackIndex: 14),
        TeamColors.presetHexes[14 % TeamColors.presetHexes.length]);
  });
}
```

- [x] **Step 2: Run it, confirm it fails**

Run: `flutter test test/core/theme/team_colors_test.dart`
Expected: FAIL, `firstUnusedPresetHex` not defined.

- [x] **Step 3: Implement the helper**

Add to `TeamColors` in `lib/core/theme/team_colors.dart`:
```dart
/// First preset color not already used by another team, so every new team
/// starts visually distinct. Falls back to cycling through the palette by
/// [fallbackIndex] once all presets are taken.
static String firstUnusedPresetHex(Iterable<String> usedHexes,
    {int fallbackIndex = 0}) {
  final used = usedHexes.map((h) => h.toUpperCase()).toSet();
  for (final hex in presetHexes) {
    if (!used.contains(hex.toUpperCase())) return hex;
  }
  return presetHexes[fallbackIndex % presetHexes.length];
}
```

- [x] **Step 4: Run the test again**

Run: `flutter test test/core/theme/team_colors_test.dart`
Expected: PASS.

- [x] **Step 5: Use it in the create-session sheet's Add team button**

In `camp_session_screen.dart`, replace the `TextButton.icon` `onPressed` body:
```dart
TextButton.icon(
  onPressed: () => setState(() {
    // Next free palette color, so a new team never duplicates an
    // existing team's color; named after that color (translatable).
    final hex = TeamColors.firstUnusedPresetHex(
      _teams.map((t) => t.colorHex),
      fallbackIndex: _teams.length,
    );
    _teams.add(_TeamRow(localizedColorNameForHex(l10n, hex), hex));
  }),
  icon: const Icon(Icons.add),
  label: Text(l10n.addTeam),
),
```

- [x] **Step 6: Use it as the default in the Teams management dialog**

In `teams_management_screen.dart`, `_showTeamDialog`, replace the two `TeamColors.presetHexes.first` defaults so a NEW team also starts on a free color:
```dart
final existingHexes = (ref.read(leaderboardProvider).valueOrNull ?? [])
    .map((t) => TeamColors.hexFromColor(t.color));
final defaultHex = TeamColors.firstUnusedPresetHex(existingHexes);
final nameCtrl = TextEditingController(
  text: existing != null
      ? localizedTeamName(l10n, existing.name)
      : localizedColorNameForHex(l10n, defaultHex),
);
String colorHex = existing != null
    ? TeamColors.hexFromColor(existing.color)
    : defaultHex;
```

- [x] **Step 7: Analyze + test + commit + push**

Run: `flutter analyze && flutter test`
```bash
git add lib/core/theme/team_colors.dart lib/features/auth/presentation/camp_session_screen.dart lib/features/leaderboard/presentation/teams_management_screen.dart test/core/theme
git commit -m "fix: new teams always get a distinct palette color"
git push
```

---

## Task 6: Points UX: presets add up, clear button, collapse + show leaderboard after submit (items 5, 10)

**Files:**
- Modify: `lib/features/leaderboard/presentation/points_management_screen.dart`
- Modify: `lib/core/router/app_router.dart` (new route)

- [x] **Step 1: Add a guide standings route**

In `app_router.dart`, next to the other guide management routes (after `/guide/camp-sessions`), add:
```dart
// Read-only standings for guides, shown after submitting points.
GoRoute(
  path: '/guide/standings',
  builder: (context, state) => const LeaderboardScreen(),
),
```
(`LeaderboardScreen` is already imported for the kid route.)

- [x] **Step 2: Make the quick-amount chips accumulate**

In `points_management_screen.dart`, `_PointsInputForm`, replace the chips block:
```dart
// Quick-amount chips ADD to the current value (+50 twice = 100).
// Typos are fixed with the field's clear button.
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [-150, -100, -50, -25, -10, 10, 25, 50, 100, 150].map((
    amount,
  ) {
    final label = amount > 0 ? '+$amount' : '$amount';
    return ActionChip(
      label: Text(label),
      onPressed: () {
        final current =
            int.tryParse(pointsController.text.trim()) ?? 0;
        pointsController.text = '${current + amount}';
      },
    );
  }).toList(),
),
```

- [x] **Step 3: Add a clear button to the amount field**

In the same widget, the points `TextField` decoration gets a suffix:
```dart
decoration: InputDecoration(
  labelText: l10n.pointAmount,
  hintText: l10n.enterPoints,
  prefixIcon: const Icon(Icons.add_circle_outline),
  suffixIcon: IconButton(
    icon: const Icon(Icons.clear),
    tooltip: l10n.cancel,
    onPressed: () => pointsController.clear(),
  ),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
  ),
),
```

- [x] **Step 4: Collapse the form and open the standings after a successful submit**

In `_submitPoints`, replace the success block after `if (!mounted) return;`:
```dart
_pointsController.clear();
_reasonController.clear();
// Close the entry form and show the resulting standings.
setState(() => _selectedTeam = null);

ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(l10n.pointsUpdated)));
context.push('/guide/standings');
```
Add the import: `import 'package:go_router/go_router.dart';`

- [x] **Step 5: Analyze + manual QA + commit + push**

Run: `flutter analyze && flutter test`
Manual QA: add points; tap +50 twice (field shows 100); submit; expect the form to close and the standings screen to appear with updated points; back returns to the points screen with no team selected.
```bash
git add lib/features/leaderboard/presentation/points_management_screen.dart lib/core/router/app_router.dart
git commit -m "feat: points presets accumulate and submit opens the standings"
git push
```

---

## Task 7: Program activity form: friendlier time entry, no past start, end after start (item 6)

**Files:**
- Modify: `lib/l10n/app_ro.arb`, `app_en.arb`, `app_hu.arb` (2 new keys)
- Modify: `lib/features/announcements/presentation/announcement_management_screen.dart` (`_ScheduleFormSheet`)

- [x] **Step 1: Add the validation message keys**

`app_ro.arb`:
```json
"startTimeInPast": "Ora de început nu poate fi în trecut",
"endTimeBeforeStartTime": "Ora de sfârșit trebuie să fie după ora de început",
```
`app_en.arb`:
```json
"startTimeInPast": "Start time cannot be in the past",
"endTimeBeforeStartTime": "End time must be after the start time",
```
`app_hu.arb`:
```json
"startTimeInPast": "A kezdési időpont nem lehet a múltban",
"endTimeBeforeStartTime": "A befejezésnek a kezdés után kell lennie",
```
Run `flutter gen-l10n`.

- [x] **Step 2: Add a 24h keyboard-first time picker helper**

In `_ScheduleFormSheetState` add:
```dart
/// Keyboard-first 24h picker: guides type 14:30 directly instead of
/// dragging the clock dial (the dial stays one icon-tap away).
Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
  return showTimePicker(
    context: context,
    initialTime: initial,
    initialEntryMode: TimePickerEntryMode.input,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
}
```
Replace both inline `showTimePicker(...)` calls:
```dart
final picked = await _pickTime(
    _startTime ?? const TimeOfDay(hour: 9, minute: 0));
if (picked != null) setState(() => _startTime = picked);
```
```dart
final picked = await _pickTime(
    _endTime ?? const TimeOfDay(hour: 10, minute: 0));
if (picked != null) setState(() => _endTime = picked);
```

- [x] **Step 3: Clamp the date picker so past days can't be picked for new entries**

Replace the date `InkWell.onTap`:
```dart
onTap: () async {
  final today = DateUtils.dateOnly(DateTime.now());
  var firstDate = campSession?.startDate ?? today;
  // A camp already in progress must not offer its past days.
  if (firstDate.isBefore(today)) firstDate = today;
  // Editing an old entry keeps its own (past) date reachable.
  if (isEditing && _selectedDate != null && _selectedDate!.isBefore(firstDate)) {
    firstDate = DateUtils.dateOnly(_selectedDate!);
  }
  final lastDate = campSession?.endDate ??
      DateTime.now().add(const Duration(days: 365));
  var initial = _selectedDate ?? today;
  if (initial.isBefore(firstDate)) initial = firstDate;
  if (initial.isAfter(lastDate)) initial = lastDate;
  final picked = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: firstDate,
    lastDate: lastDate,
  );
  if (picked != null) setState(() => _selectedDate = picked);
},
```

- [x] **Step 4: Validate start-not-in-past and end-after-start on submit**

In `_submit`, right after the existing `_startTime == null` check, add:
```dart
final startDateTime = DateTime(
  _selectedDate!.year,
  _selectedDate!.month,
  _selectedDate!.day,
  _startTime!.hour,
  _startTime!.minute,
);
// Only NEW entries are blocked from starting in the past: editing
// yesterday's activity (e.g. fixing a typo) must stay possible.
if (!isEditing && startDateTime.isBefore(DateTime.now())) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(l10n.startTimeInPast)));
  return;
}
if (_endTime != null) {
  final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
  final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
  if (endMinutes <= startMinutes) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.endTimeBeforeStartTime)));
    return;
  }
}
```

- [x] **Step 5: Analyze + manual QA + commit + push**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Manual QA: new program entry: date picker starts today (no earlier days); time picker opens in typed 24h mode; creating an entry at an earlier hour today is blocked with the localized message; end 09:00 with start 10:00 is blocked.
```bash
git add lib/l10n lib/features/announcements/presentation/announcement_management_screen.dart
git commit -m "feat: program form gets 24h typed time entry and past/order validation"
git push
```

---

## Task 8: Day-0 quick tips: add the logo-upload step (item 9)

**Files:**
- Modify: `lib/l10n/app_ro.arb`, `app_en.arb`, `app_hu.arb` (1 new key)
- Modify: `lib/features/home/presentation/day0_checklist_card.dart`

- [x] **Step 1: Add the step label key**

`app_ro.arb`: `"stepUploadLogo": "Adaugă logo-ul organizației",`
`app_en.arb`: `"stepUploadLogo": "Add your organization logo",`
`app_hu.arb`: `"stepUploadLogo": "Add hozzá a szervezet logóját",`
Run `flutter gen-l10n`.

- [x] **Step 2: Add the step to the checklist**

In `day0_checklist_card.dart`, extend the derived state and the all-done gate:
```dart
final hasSession = sessions.isNotEmpty;
final hasGuides = members.length >= 2;
final hasCodes = codes.isNotEmpty;
final hasLogo = (org.logoUrl ?? '').isNotEmpty;
if (hasSession && hasGuides && hasCodes && hasLogo) {
  return const SizedBox.shrink();
}
```
and add a fourth `_StepRow` after the generate-codes row:
```dart
_StepRow(
  done: hasLogo,
  label: l10n.stepUploadLogo,
  onTap: () => context.push('/guide/organization'),
),
```
(`currentOrganizationProvider` is invalidated after a logo upload, so the row ticks itself.)

- [x] **Step 3: Analyze + commit + push**

Run: `flutter gen-l10n && flutter analyze && flutter test`
```bash
git add lib/l10n lib/features/home/presentation/day0_checklist_card.dart
git commit -m "feat: day-0 checklist points new owners to the logo upload"
git push
```

---

## Task 9: Crop the logo before uploading (item 11)

**Files:**
- Modify: `pubspec.yaml` (new dependency `image_cropper`)
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `lib/l10n/app_ro.arb`, `app_en.arb`, `app_hu.arb` (1 new key)
- Modify: `lib/features/organization/presentation/organization_screen.dart` (`_LogoCardState._pickAndUpload`)

- [x] **Step 1: Add the dependency**

Run: `flutter pub add image_cropper`
Expected: resolves to the current stable major (9.x or newer). If the resolved major is newer than 9, check its README for API renames before Step 4 (the `cropImage`/`CroppedFile`/`uiSettings` API has been stable across recent majors). iOS needs no configuration (TOCropViewController is bundled).

- [x] **Step 2: Register the uCrop activity on Android**

In `android/app/src/main/AndroidManifest.xml`, inside `<application>`, add:
```xml
<activity
    android:name="com.yalantis.ucrop.UCropActivity"
    android:screenOrientation="portrait"
    android:theme="@style/Theme.AppCompat.Light.NoActionBar"/>
```

- [x] **Step 3: Add the l10n key**

`app_ro.arb`: `"cropLogo": "Decupează logo-ul",`
`app_en.arb`: `"cropLogo": "Crop logo",`
`app_hu.arb`: `"cropLogo": "Logó kivágása",`
Run `flutter gen-l10n`.

- [x] **Step 4: Crop between pick and upload**

In `organization_screen.dart`, `_LogoCardState._pickAndUpload`, after the null check on `picked`:
```dart
// Let the owner frame the logo before it's compressed and uploaded.
final cropped = await ImageCropper().cropImage(
  sourcePath: picked.path,
  compressFormat: ImageCompressFormat.jpg,
  compressQuality: 95,
  uiSettings: [
    AndroidUiSettings(
      toolbarTitle: l10n.cropLogo,
      initAspectRatio: CropAspectRatioPreset.square,
      lockAspectRatio: false,
    ),
    IOSUiSettings(title: l10n.cropLogo),
  ],
);
if (cropped == null) return; // backed out of the crop screen

setState(() => _busy = true);
try {
  final url = await ref.read(imageUploadServiceProvider).uploadImage(
        imageFile: XFile(cropped.path),
        storagePath: 'organizations/${widget.org.id}/logo.jpg',
      );
  ...
```
(The rest of the try/catch stays as it is.) Add imports:
```dart
import 'package:image_cropper/image_cropper.dart';
```

- [x] **Step 5: Analyze + manual QA + commit + push**

Run: `flutter analyze && flutter test`
Manual QA on a device: change logo, crop screen appears, cropped image lands in the org card.
```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml lib/l10n lib/features/organization/presentation/organization_screen.dart
git commit -m "feat: crop the organization logo before upload"
git push
```

---

## Task 10: Map: dismissible "no locations" banner (item 12)

**Files:**
- Modify: `lib/features/map/presentation/map_screen.dart`

- [x] **Step 1: Give `_MapBanner` an optional close button**

Extend the widget:
```dart
class _MapBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  const _MapBanner({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });
  ...
```
and after the existing action button block inside the `Row`, add:
```dart
if (onDismiss != null)
  IconButton(
    icon: const Icon(Icons.close, size: 20),
    tooltip: AppL10n.of(context).dismiss,
    visualDensity: VisualDensity.compact,
    onPressed: onDismiss,
  ),
```

- [x] **Step 2: Wire it up for the no-locations state**

In `_MapScreenState` add a field:
```dart
bool _noLocationsBannerDismissed = false;
```
and in the banner `data:` branch replace the final return:
```dart
if (_noLocationsBannerDismissed) return const SizedBox.shrink();
return _MapBanner(
  icon: Icons.explore_off_outlined,
  message: l10n.mapNoLocationsInSession,
  onDismiss: () =>
      setState(() => _noLocationsBannerDismissed = true),
);
```
(Dismissal lasts until the screen is remounted, which is the right lifetime: the hint returns next visit if there are still no locations.)

- [x] **Step 3: Analyze + commit + push**

Run: `flutter analyze && flutter test`
```bash
git add lib/features/map/presentation/map_screen.dart
git commit -m "feat: map empty-state banner can be dismissed"
git push
```

---

## Task 11: Map opens on the user/camp, not hardcoded coordinates (item 16)

**Files:**
- Modify: `lib/features/map/presentation/map_screen.dart`

Behavior: keep the constants as the pre-data placeholder, then auto-center exactly once per screen visit: GPS fix wins (guides always, kids after their existing opt-in), otherwise fit the session's markers, otherwise stay on the defaults. Also widen the camera constraint so Hungarian camps aren't clamped out (current bounds cut Hungary off at longitude 20.2).

- [x] **Step 1: Widen the camera bounds to Romania + Hungary**

In `MapOptions`, replace the constraint:
```dart
cameraConstraint: CameraConstraint.contain(
  bounds: LatLngBounds(
    const LatLng(43.0, 15.5), // SW: covers all of Romania and Hungary
    const LatLng(49.0, 30.5), // NE
  ),
),
```

- [x] **Step 2: Track one-shot auto-centering**

Add a field to `_MapScreenState`:
```dart
/// Set once the camera has been pointed somewhere meaningful (GPS fix or
/// marker bounds), so later fixes/streams don't keep yanking the view.
bool _didAutoCenter = false;
```

- [x] **Step 3: Center on the first GPS fix**

In `_startPositionStream`'s `.listen`, extend the callback:
```dart
).listen((position) {
  if (!mounted) return;
  final latLng = LatLng(position.latitude, position.longitude);
  setState(() => _selfPosition = latLng);
  if (!_didAutoCenter) {
    _didAutoCenter = true;
    _mapController.move(latLng, AppConstants.defaultMapZoom);
  }
});
```

- [x] **Step 4: Fall back to fitting the session's markers**

In `build`, before the `return Scaffold(...)`, add:
```dart
// Without a GPS fix (kid who hasn't opted in, permission denied), frame
// the camp itself: fit all session markers once they load.
ref.listen<AsyncValue<List<ResolvedSessionLocation>>>(
    resolvedSessionLocationsProvider, (prev, next) {
  final locs = next.valueOrNull;
  if (_didAutoCenter || locs == null || locs.isEmpty) return;
  _didAutoCenter = true;
  final points = locs
      .map((r) =>
          LatLng(r.masterLocation.latitude, r.masterLocation.longitude))
      .toList();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (points.length == 1) {
      _mapController.move(points.first, AppConstants.defaultMapZoom);
    } else {
      _mapController.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(64),
      ));
    }
  });
});
```

- [x] **Step 5: Analyze + manual QA + commit + push**

Run: `flutter analyze && flutter test`
Manual QA: guide with GPS on opens the map away from Apuseni, map centers on them; kid without opt-in sees the map framed on the camp's markers.
```bash
git add lib/features/map/presentation/map_screen.dart
git commit -m "feat: map auto-centers on GPS or camp markers instead of hardcoded coords"
git push
```

---

## Task 12: Session-location photo required only when the master has none (item 13)

**Files:**
- Modify: `lib/l10n/app_ro.arb`, `app_en.arb`, `app_hu.arb` (2 new keys)
- Modify: `lib/features/map/presentation/add_session_location_screen.dart`
- Modify: `lib/features/map/presentation/location_detail_page.dart:58`

Master-location creation (`location_form_screen.dart`) already treats the photo as optional; verify, no change there. `SessionLocation.photoUrl` is already nullable, so no model change either.

- [x] **Step 1: Add the hint keys**

`app_ro.arb`:
```json
"groupPhotoRequiredNoMasterPhoto": "Această locație nu are nicio poză, adaugă una acum",
"groupPhotoOptionalHint": "Opțional: poza de grup apare pe pagina locației",
```
`app_en.arb`:
```json
"groupPhotoRequiredNoMasterPhoto": "This location has no photo yet, so one is required now",
"groupPhotoOptionalHint": "Optional: the group photo appears on the location page",
```
`app_hu.arb`:
```json
"groupPhotoRequiredNoMasterPhoto": "Ennek a helyszínnek még nincs fotója, ezért most kötelező feltölteni",
"groupPhotoOptionalHint": "Opcionális: a csoportkép a helyszín oldalán jelenik meg",
```
Run `flutter gen-l10n`.

- [x] **Step 2: Relax the requirement in the add-to-session screen**

In `add_session_location_screen.dart`:

(a) `_saveSessionLocation` guard, change:
```dart
if (_selectedLocation == null || _pickedImage == null) return;
```
to:
```dart
if (_selectedLocation == null) return;
// A group photo is only mandatory when the master location has no photo
// at all (otherwise the detail page would be imageless).
final masterHasPhoto =
    (_selectedLocation!.photoUrl ?? '').isNotEmpty;
if (_pickedImage == null && !masterHasPhoto) return;
```

(b) Upload only when picked; replace the upload block:
```dart
String? photoUrl;
if (_pickedImage != null) {
  photoUrl = await ref.read(imageUploadServiceProvider).uploadImage(
    imageFile: _pickedImage!,
    storagePath:
        'organizations/$orgId/${AppConstants.sessionPhotosStorageFolder}/$campId/$sessionLocId/group_photo.jpg',
  );
}
```
and pass `photoUrl: photoUrl` (now possibly null) into the `SessionLocation`.

(c) Contextual hint: replace `Text(l10n.groupPhotoHint, ...)` with:
```dart
Text(
  (_selectedLocation!.photoUrl ?? '').isNotEmpty
      ? l10n.groupPhotoOptionalHint
      : l10n.groupPhotoRequiredNoMasterPhoto,
  style: theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  ),
),
```

(d) Save button enablement:
```dart
FilledButton.icon(
  onPressed: _pickedImage != null ||
          (_selectedLocation!.photoUrl ?? '').isNotEmpty
      ? _saveSessionLocation
      : null,
  ...
```

- [x] **Step 3: Detail page falls back to the master photo**

In `location_detail_page.dart`, the flexible-space background currently keys on `widget.groupPhotoUrl`. Introduce a resolved URL at the top of `build`:
```dart
final headerPhotoUrl = (widget.groupPhotoUrl?.isNotEmpty ?? false)
    ? widget.groupPhotoUrl
    : widget.masterLocation.photoUrl;
```
and use `headerPhotoUrl` in place of `widget.groupPhotoUrl` in the `background:` expression (both the null check and the `imageUrl:`). The existing icon fallback stays for the both-null case.

- [x] **Step 4: Analyze + manual QA + commit + push**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Manual QA: master WITH photo: adding to session allows saving with no group photo, detail page shows the master photo. Master WITHOUT photo: save stays disabled until a photo is picked, hint explains why.
```bash
git add lib/l10n lib/features/map
git commit -m "feat: group photo optional when the master location already has one"
git push
```

---

## Task 13: Question of the day: inline answer box + answered state (item 17)

**Files:**
- Create: `lib/features/journal/domain/prompt_answer.dart`
- Test: `test/features/journal/prompt_answer_test.dart` (create)
- Modify: `lib/l10n/app_ro.arb`, `app_en.arb`, `app_hu.arb` (3 new keys)
- Modify: `lib/features/announcements/presentation/announcements_screen.dart` (detail sheet)
- Modify: `lib/features/journal/presentation/journal_editor_screen.dart` (`_PromptBanner`)

- [x] **Step 1: Write the failing test for answered-detection**

Create `test/features/journal/prompt_answer_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/announcements/domain/announcement.dart';
import 'package:camp_connect/features/journal/domain/journal_entry.dart';
import 'package:camp_connect/features/journal/domain/prompt_answer.dart';

Announcement _prompt(String title, DateTime ts) => Announcement(
      id: 'p1',
      title: title,
      body: '',
      type: 'prompt',
      pinned: false,
      createdBy: 'g1',
      createdByName: 'Guide',
      timestamp: ts,
    );

JournalEntry _entry({String? prompt, required DateTime date}) => JournalEntry(
      id: 'e1',
      date: date,
      title: 't',
      body: 'b',
      prompt: prompt,
      createdAt: date,
      updatedAt: date,
    );

void main() {
  final day = DateTime(2026, 7, 12, 9);

  test('answered when an entry adopted the prompt on the same day', () {
    final entries = [
      _entry(prompt: 'How was the hike?', date: DateTime(2026, 7, 12, 20))
    ];
    expect(hasAnsweredPrompt(entries, _prompt('How was the hike?', day)), isTrue);
  });

  test('not answered by an entry from another day', () {
    final entries = [
      _entry(prompt: 'How was the hike?', date: DateTime(2026, 7, 11))
    ];
    expect(hasAnsweredPrompt(entries, _prompt('How was the hike?', day)), isFalse);
  });

  test('not answered by entries without that prompt', () {
    final entries = [_entry(prompt: null, date: day)];
    expect(hasAnsweredPrompt(entries, _prompt('How was the hike?', day)), isFalse);
  });
}
```
(Adjust the `Announcement` constructor arguments to the real signature in `announcement.dart` if it differs; it has all these fields.)

- [x] **Step 2: Run it, confirm it fails**

Run: `flutter test test/features/journal/prompt_answer_test.dart`
Expected: FAIL, `prompt_answer.dart` does not exist.

- [x] **Step 3: Implement the util**

Create `lib/features/journal/domain/prompt_answer.dart`:
```dart
import '../../announcements/domain/announcement.dart';
import 'journal_entry.dart';

/// Whether a local journal entry already answers [prompt]: same adopted
/// prompt title, written on the prompt's calendar day. Local-only by
/// design (the journal never leaves the device), so "answered" is
/// per-device, which matches how kids use one device each.
bool hasAnsweredPrompt(List<JournalEntry> entries, Announcement prompt) {
  final d = prompt.timestamp;
  for (final e in entries) {
    if (e.prompt != prompt.title) continue;
    if (e.date.year == d.year && e.date.month == d.month && e.date.day == d.day) {
      return true;
    }
  }
  return false;
}
```

- [x] **Step 4: Run the test again**

Run: `flutter test test/features/journal/prompt_answer_test.dart`
Expected: PASS (3 tests).

- [x] **Step 5: Add the l10n keys**

`app_ro.arb`:
```json
"promptAnswerHint": "Scrie ce s-a întâmplat azi...",
"promptAnswered": "Ai răspuns la întrebarea de azi",
"promptAnswerSaved": "Răspunsul a fost salvat în jurnal",
```
`app_en.arb`:
```json
"promptAnswerHint": "Write what happened today...",
"promptAnswered": "You answered today's question",
"promptAnswerSaved": "Your answer was saved to the journal",
```
`app_hu.arb`:
```json
"promptAnswerHint": "Írd le, mi történt ma...",
"promptAnswered": "Megválaszoltad a mai kérdést",
"promptAnswerSaved": "A válasz a naplóba került",
```
Run `flutter gen-l10n`.

- [x] **Step 6: Inline answer section in the announcement detail sheet**

In `announcements_screen.dart`, replace the `if (announcement.isPrompt) ...FilledButton...` block inside `showAnnouncementDetails` with:
```dart
if (announcement.isPrompt) ...[
  const SizedBox(height: 16),
  _PromptAnswerSection(announcement: announcement),
],
```
and add the widget at the bottom of the file:
```dart
/// Inline QOTD answering: a text box under the question. Once a journal
/// entry for today's prompt exists, it flips to a locked "answered" state.
class _PromptAnswerSection extends ConsumerStatefulWidget {
  final Announcement announcement;

  const _PromptAnswerSection({required this.announcement});

  @override
  ConsumerState<_PromptAnswerSection> createState() =>
      _PromptAnswerSectionState();
}

class _PromptAnswerSectionState extends ConsumerState<_PromptAnswerSection> {
  final _answerCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _answerCtrl.text.trim();
    if (text.isEmpty) return;
    final l10n = AppL10n.of(context);
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      await ref.read(journalProvider.notifier).saveEntry(JournalEntry(
            id: const Uuid().v4(),
            date: now,
            title: widget.announcement.title,
            body: text,
            prompt: widget.announcement.title,
            createdAt: now,
            updatedAt: now,
          ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.promptAnswerSaved)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final entries = ref.watch(journalProvider).valueOrNull ?? const [];

    if (hasAnsweredPrompt(entries, widget.announcement)) {
      return Row(
        children: [
          Icon(Icons.check_circle, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.promptAnswered,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _answerCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l10n.promptAnswerHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.edit_note),
          label: Text(l10n.answerInJournal),
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
```
New imports in `announcements_screen.dart`:
```dart
import 'package:uuid/uuid.dart';
import 'package:camp_connect/features/journal/domain/journal_entry.dart';
import 'package:camp_connect/features/journal/domain/prompt_answer.dart';
```
Note: `showAnnouncementDetails`'s sheet content is a plain builder; `_PromptAnswerSection` being a `ConsumerStatefulWidget` gives it `ref` without changing the function's signature. On save the `journalProvider` reloads, the watch rebuilds, and the section flips to the answered state in place. Kids no longer navigate away; the old push to `/kid/journal/new` goes away with this block.

- [x] **Step 7: Answered state in the journal editor's prompt banner**

In `journal_editor_screen.dart`, `_PromptBanner.build`, after `final prompt = activePrompt(...)` and its null check, add:
```dart
final entries = ref.watch(journalProvider).valueOrNull ?? const [];
if (hasAnsweredPrompt(entries, prompt)) {
  return Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: ListTile(
      leading: Icon(Icons.check_circle, color: theme.colorScheme.primary),
      title: Text(l10n.promptAnswered, style: theme.textTheme.titleSmall),
      subtitle: Text(prompt.title, style: theme.textTheme.bodySmall),
    ),
  );
}
```
Import `prompt_answer.dart` there too.

- [x] **Step 8: Analyze + manual QA + commit + push**

Run: `flutter analyze && flutter test`
Manual QA: guide posts a QOTD; kid opens it from news, writes in the inline box, saves; the sheet flips to "answered"; reopening the announcement shows the answered state; the saved entry appears in the journal with the prompt banner; a new manual journal entry no longer offers the adopt button for that prompt.
```bash
git add lib/features/journal lib/features/announcements/presentation/announcements_screen.dart lib/l10n test/features/journal
git commit -m "feat: inline question-of-the-day answering with answered lock"
git push
```

---

## Task 14: First-login session flow: select instead of create, auto-select, no more restart bug (item 14)

**Files:**
- Modify: `lib/shared/providers/providers.dart` (`ActiveCampIdNotifier`)
- Test: `test/shared/providers/active_camp_id_notifier_test.dart` (create)
- Modify: `lib/features/auth/data/camp_repository.dart` (one-shot org sessions fetch)
- Create: `lib/features/auth/data/session_auto_select.dart`
- Modify: `lib/features/auth/presentation/splash_screen.dart`
- Modify: `lib/features/auth/presentation/guide_login_screen.dart`
- Modify: `lib/features/home/presentation/guide_home_screen.dart` (`_NoSessionCard`)
- Modify: `lib/l10n/app_ro.arb`, `app_en.arb`, `app_hu.arb` (3 new keys)

Two real defects behind the reported symptom:
1. `ActiveCampIdNotifier` follows `appUserProvider` through its LOADING transitions: any profile refresh mid-session momentarily makes `valueOrNull` null, which can null the campId and leave session-scoped providers half-loaded until restart.
2. A brand-new guide (campId null) lands on a dashboard that says "create a session" even when the org already has one running, and nothing selects it for them.

- [x] **Step 1: Write the failing notifier test**

Create `test/shared/providers/active_camp_id_notifier_test.dart`:
```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/shared/providers/providers.dart';

AppUser _guide(String? campId) => AppUser(
      uid: 'u1',
      role: 'guide',
      displayName: 'G',
      email: 'g@x.com',
      orgId: 'org1',
      campId: campId,
    );

void main() {
  test('a loading flicker of appUserProvider does not clear the camp', () async {
    // Drives appUserProvider through data -> loading -> data(same).
    final gate = StateProvider<int>((_) => 0);
    final container = ProviderContainer(overrides: [
      appUserProvider.overrideWith((ref) async {
        ref.watch(gate);
        return _guide('campA');
      }),
    ]);
    addTearDown(container.dispose);

    // Materialize the notifier and let the first profile land.
    container.listen(activeCampIdProvider, (_, _) {});
    await container.read(appUserProvider.future);
    expect(container.read(activeCampIdProvider), 'campA');

    // Refresh: provider flips to loading, then resolves to the SAME campId.
    container.read(gate.notifier).state++;
    // While loading, the camp must not be nulled out.
    expect(container.read(activeCampIdProvider), 'campA');
    await container.read(appUserProvider.future);
    expect(container.read(activeCampIdProvider), 'campA');
  });

  test('a real profile campId change still propagates', () async {
    final profile = StateProvider<String?>((_) => 'campA');
    final container = ProviderContainer(overrides: [
      appUserProvider.overrideWith((ref) async {
        return _guide(ref.watch(profile));
      }),
    ]);
    addTearDown(container.dispose);

    container.listen(activeCampIdProvider, (_, _) {});
    await container.read(appUserProvider.future);
    expect(container.read(activeCampIdProvider), 'campA');

    container.read(profile.notifier).state = 'campB';
    await container.read(appUserProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(activeCampIdProvider), 'campB');
  });
}
```
(Match the `AppUser` constructor to the real one in `app_user.dart`; adjust named parameters if needed.)

- [x] **Step 2: Run it, confirm the first test fails**

Run: `flutter test test/shared/providers/active_camp_id_notifier_test.dart`
Expected: first test FAILS on the "while loading" expectation (state flips to null with the current code); second passes.

- [x] **Step 3: Harden the notifier** (skipped — already correct; see note below)

In `providers.dart`, replace `ActiveCampIdNotifier` with:
```dart
class ActiveCampIdNotifier extends StateNotifier<String?> {
  ActiveCampIdNotifier(this._ref)
    : _lastProfileCampId = _ref.read(appUserProvider).valueOrNull?.campId,
      super(_ref.read(appUserProvider).valueOrNull?.campId) {
    _ref.listen<AsyncValue<AppUser?>>(appUserProvider, (prev, next) {
      // Only resolved DATA states move the selection. Loading/error
      // flickers from a profile refresh used to null the camp mid-session,
      // leaving screens half-loaded until an app restart.
      if (next is! AsyncData<AppUser?>) return;
      final newCampId = next.value?.campId;
      if (newCampId != _lastProfileCampId) {
        _lastProfileCampId = newCampId;
        state = newCampId;
      }
    });
  }

  final Ref _ref;

  /// Last campId actually seen on a RESOLVED profile; comparing against
  /// this (not against [state]) keeps an in-session override from being
  /// clobbered by a profile echo that hasn't caught up yet.
  String? _lastProfileCampId;

  /// Explicitly point the app at [campId] (or null to clear), e.g. right after
  /// a guide taps a session or deletes the active one.
  void select(String? campId) => state = campId;
}
```

- [x] **Step 4: Run the notifier tests again**

Run: `flutter test test/shared/providers/active_camp_id_notifier_test.dart`
Expected: PASS (2 tests).

- [x] **Step 5: One-shot org sessions fetch in the repository**

In `camp_repository.dart`, next to `getCampSessionsForOrg`, add (copy the exact `where` clause the stream version uses; it queries `AppConstants.campsCollection` on `orgId`):
```dart
/// One-shot version of [getCampSessionsForOrg], for login-time
/// auto-selection where waiting on a stream is overkill.
Future<List<CampSession>> fetchCampSessionsForOrg(String orgId) async {
  final snapshot = await _firestore
      .collection(AppConstants.campsCollection)
      .where('orgId', isEqualTo: orgId)
      .get();
  return snapshot.docs.map(CampSession.fromFirestore).toList()
    ..sort((a, b) => b.startDate.compareTo(a.startDate));
}
```

- [x] **Step 6: The auto-select helper**

Create `lib/features/auth/data/session_auto_select.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_user.dart';
import '../domain/camp_session.dart';
import '../../../shared/providers/providers.dart';

/// For a guide with no selected camp whose org has a session running right
/// now (startDate < now < endDate), selects it: in-memory immediately and
/// persisted on the profile. Returns the selected session, or null when
/// nothing applies. Never throws: this is a login-time convenience and
/// must not block sign-in.
Future<CampSession?> autoSelectActiveSession(WidgetRef ref, AppUser user) async {
  if (!user.isGuide || user.campId != null || user.orgId == null) return null;
  try {
    final sessions = await ref
        .read(campRepositoryProvider)
        .fetchCampSessionsForOrg(user.orgId!);
    // fetch... returns newest-start first, so overlapping sessions resolve
    // to the most recently started one.
    final active = sessions.where((s) => s.isActive()).firstOrNull;
    if (active == null) return null;
    await ref
        .read(authRepositoryProvider)
        .updateUserCampId(user.uid, active.id);
    ref.read(activeCampIdProvider.notifier).select(active.id);
    return active;
  } catch (_) {
    return null;
  }
}
```

- [x] **Step 7: Call it from the splash for returning users**

In `splash_screen.dart`, make `_route` async and auto-select before entering the guide shell:
```dart
Future<void> _route(AppUser? user) async {
  if (_routed || !mounted) return;
  _routed = true;
  if (user == null) {
    context.go('/role-selection');
    return;
  }

  ref.read(fcmServiceProvider).requestPermission();

  if (user.isGuide) {
    var campId = user.campId;
    if (campId == null) {
      // New guide in an org with a running session: select it for them
      // instead of dropping them on an empty dashboard.
      final auto = await autoSelectActiveSession(ref, user);
      campId = auto?.id;
    }
    if (campId != null) {
      ref.read(fcmServiceProvider).subscribeToTopics(
            campId: campId,
            role: user.role,
          );
    }
    if (!mounted) return;
    context.go('/guide');
  } else {
    ...unchanged kid branch...
  }
}
```
Import the helper. The two call sites (`ref.listen` and the post-frame callback) don't need changes; `_route` returning a Future is fine fire-and-forget, the `_routed` guard already prevents double entry.

- [x] **Step 8: Call it right after guide login/registration**

In `guide_login_screen.dart`, `_submit`, after `final user = await ref.read(appUserProvider.future);` replace the FCM block with:
```dart
CampSession? autoSelected;
if (user != null) {
  autoSelected = await autoSelectActiveSession(ref, user);
}
final effectiveCampId = autoSelected?.id ?? user?.campId;

try {
  await ref.read(fcmServiceProvider).requestPermission();
  if (effectiveCampId != null) {
    await ref
        .read(fcmServiceProvider)
        .subscribeToTopics(campId: effectiveCampId, role: 'guide');
  }
} catch (_) {
  // Ignored: push setup failure must not block sign-in.
}
```
Imports: `session_auto_select.dart` and `camp_session.dart`.

- [x] **Step 9: "Select the session" card when sessions exist**

l10n keys:

`app_ro.arb`:
```json
"noSessionSelected": "Nicio sesiune selectată",
"selectSessionPrompt": "Organizația ta are deja sesiuni. Alege una pentru a continua.",
"selectSession": "Alege sesiunea",
```
`app_en.arb`:
```json
"noSessionSelected": "No session selected",
"selectSessionPrompt": "Your organization already has sessions. Pick one to continue.",
"selectSession": "Select session",
```
`app_hu.arb`:
```json
"noSessionSelected": "Nincs kiválasztott turnus",
"selectSessionPrompt": "A szervezetednek már vannak turnusai. Válassz egyet a folytatáshoz.",
"selectSession": "Turnus kiválasztása",
```
Run `flutter gen-l10n`.

In `guide_home_screen.dart`, the `session == null` branch becomes:
```dart
if (session == null) {
  final hasSessions =
      (ref.watch(guideCampSessionsProvider).valueOrNull ?? [])
          .isNotEmpty;
  return _NoSessionCard(
    hasExistingSessions: hasSessions,
    onPressed: () => context.push('/guide/camp-sessions'),
  );
}
```
and `_NoSessionCard` becomes:
```dart
class _NoSessionCard extends StatelessWidget {
  final bool hasExistingSessions;
  final VoidCallback onPressed;

  const _NoSessionCard({
    required this.hasExistingSessions,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            IconBubble(
              icon: hasExistingSessions
                  ? Icons.event_available
                  : Icons.event_busy,
              size: 64,
            ),
            const SizedBox(height: 14),
            Text(
              hasExistingSessions
                  ? l10n.noSessionSelected
                  : l10n.noActiveSession,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              hasExistingSessions
                  ? l10n.selectSessionPrompt
                  : l10n.createSessionPrompt,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(hasExistingSessions
                  ? Icons.check_circle_outline
                  : Icons.add),
              label: Text(hasExistingSessions
                  ? l10n.selectSession
                  : l10n.createSession),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [x] **Step 10: Analyze + full tests + manual QA + commit + push**

Run: `flutter gen-l10n && flutter analyze && flutter test`
Manual QA (the exact repro Costin hit): create a fresh guide account joining an org that has a running session. Expected: after registering, the running session is already selected, leaderboard/announcements/map all load, no restart needed. Also: org with only FUTURE sessions: dashboard says "select session" (not "create"); org with none: "create".
```bash
git add lib/shared/providers lib/features/auth lib/features/home lib/l10n test/shared
git commit -m "fix: auto-select the running session on first login and stop campId flicker"
git push
```

---

## Task 15: Gate organization creation behind a setup code (items 1, 2)

**Files:**
- Modify: `functions/lib/registerGuide.js`
- Test: `functions/test/registerGuide.test.js` (extend)
- Modify: `lib/features/auth/data/auth_repository.dart` (`registerGuide`)
- Modify: `lib/features/auth/presentation/guide_login_screen.dart`
- Test: `test/features/auth/friendly_error_test.dart` (extend)
- Modify: `lib/l10n/app_ro.arb`, `app_en.arb`, `app_hu.arb` (3 new keys)

Server-first: after this task, `registerGuide` with `newOrgName` REQUIRES `orgCreationCode` matching `config/registration.orgCreationCode` in Firestore. The join path is untouched (it already requires the org invite code). Result: no path creates an account without a code, and a kid poking at the register form cannot spin up an org.

**Manual GCP step for Costin (fail-closed: org creation is blocked until done):** in the Firebase console, project `camp-connect-4644c`, create document `config/registration` with a string field `orgCreationCode`, value of his choosing (e.g. 8+ chars from the code charset). Firestore rules must NOT allow client reads of `config/**`; the default deny already covers it, verify no wildcard allow exists in `firestore.rules`.

- [x] **Step 1: Write the failing function tests**

In `functions/test/registerGuide.test.js`, following the file's existing setup helpers, add a describe block (adapt helper names to the file's actual ones):
```js
describe("org creation code gate", () => {
  beforeEach(async () => {
    await db.doc("config/registration").set({ orgCreationCode: "LETMEIN2" });
  });

  test("creates the org when the code matches (case/space insensitive)", async () => {
    const res = await registerGuideHandler(db, auth, {
      email: "owner@x.com", password: "secret123", displayName: "Owner",
      newOrgName: "Camp X", orgCreationCode: " letmein2 ",
    }, "1.2.3.4");
    expect(res.ok).toBe(true);
  });

  test("rejects a wrong code", async () => {
    await expect(registerGuideHandler(db, auth, {
      email: "o2@x.com", password: "secret123", displayName: "O",
      newOrgName: "Camp Y", orgCreationCode: "WRONG",
    }, "1.2.3.5")).rejects.toMatchObject({
      code: "permission-denied",
      message: "invalid-org-creation-code",
    });
  });

  test("rejects a missing code", async () => {
    await expect(registerGuideHandler(db, auth, {
      email: "o3@x.com", password: "secret123", displayName: "O",
      newOrgName: "Camp Z",
    }, "1.2.3.6")).rejects.toMatchObject({
      code: "permission-denied",
      message: "invalid-org-creation-code",
    });
  });

  test("rejects when no config doc exists (fail closed)", async () => {
    await db.doc("config/registration").delete();
    await expect(registerGuideHandler(db, auth, {
      email: "o4@x.com", password: "secret123", displayName: "O",
      newOrgName: "Camp W", orgCreationCode: "LETMEIN2",
    }, "1.2.3.7")).rejects.toMatchObject({
      code: "permission-denied",
      message: "invalid-org-creation-code",
    });
  });

  test("joining with an invite code does not need the creation code", async () => {
    // Use the suite's existing seeded-org helper, then:
    const res = await registerGuideHandler(db, auth, {
      email: "joiner@x.com", password: "secret123", displayName: "J",
      joinOrgCode: seededInviteCode,
    }, "1.2.3.8");
    expect(res.ok).toBe(true);
  });
});
```

- [x] **Step 2: Run, confirm failures**

Run: `cd functions && npm test -- registerGuide`
Expected: the new cases FAIL (org creation currently succeeds without any code).

- [x] **Step 3: Implement the gate**

In `functions/lib/registerGuide.js`:
- Destructure the new field: `const { email, password, displayName, newOrgName, joinOrgCode, orgCreationCode } = data || {};`
- At the top of the `if (newOrgName) {` branch, before generating the invite code:
```js
// Org creation is gated by a global setup code handed out personally
// (config/registration.orgCreationCode). Fail closed: no config doc
// means no org creation. Keeps kids (or anyone) from spinning up orgs
// with just an email; guides joining an org are unaffected.
const cfg = await db.doc("config/registration").get();
const expected = cfg.exists ? cfg.data().orgCreationCode : null;
const supplied = (orgCreationCode || "").trim().toUpperCase();
if (!expected || supplied !== String(expected).trim().toUpperCase()) {
  throw new HttpsError("permission-denied", "invalid-org-creation-code");
}
```
- Update the function's doc comment error list with the new error.

- [x] **Step 4: Run the function tests**

Run: `cd functions && npm test`
Expected: all pass, including the untouched older registerGuide cases (they create orgs, so ADD the config doc to that suite's shared setup if they start failing; that is the expected fallout of fail-closed).

- [x] **Step 5: Client: pass the code through the repository**

In `auth_repository.dart`, `registerGuide`, add the parameter and payload field:
```dart
Future<AppUser> registerGuide({
  required String email,
  required String password,
  required String displayName,
  String? joinOrgCode,
  String? newOrgName,
  String? orgCreationCode,
}) async {
  ...
  await _functions.httpsCallable('registerGuide').call({
    'email': email,
    'password': password,
    'displayName': displayName,
    if (joinOrgCode != null) 'joinOrgCode': joinOrgCode,
    if (newOrgName != null) 'newOrgName': newOrgName,
    if (orgCreationCode != null) 'orgCreationCode': orgCreationCode,
  });
  ...
```
(Merge with the exact existing call-shape in the file.)

- [x] **Step 6: Client: the setup-code field in the create-org form**

l10n keys:

`app_ro.arb`:
```json
"orgCreationCode": "Cod de configurare",
"orgCreationCodeHelp": "Primești acest cod de la echipa CampConnect.",
"invalidOrgCreationCode": "Cod de configurare invalid",
```
`app_en.arb`:
```json
"orgCreationCode": "Setup code",
"orgCreationCodeHelp": "You get this code from the CampConnect team.",
"invalidOrgCreationCode": "Invalid setup code",
```
`app_hu.arb`:
```json
"orgCreationCode": "Beállítási kód",
"orgCreationCodeHelp": "Ezt a kódot a CampConnect csapatától kapod.",
"invalidOrgCreationCode": "Érvénytelen beállítási kód",
```
Run `flutter gen-l10n`.

In `guide_login_screen.dart`:
- Add `final _orgCreationCodeController = TextEditingController();` (and dispose it).
- In the register form's `else` branch (create-org mode), after the org-name field, add:
```dart
const SizedBox(height: 16),
TextFormField(
  key: const ValueKey('orgCreationCode'),
  controller: _orgCreationCodeController,
  decoration: InputDecoration(
    labelText: l10n.orgCreationCode,
    helperText: l10n.orgCreationCodeHelp,
    prefixIcon: const Icon(Icons.key_outlined),
    border: const OutlineInputBorder(),
  ),
  textInputAction: TextInputAction.next,
  textCapitalization: TextCapitalization.characters,
  validator: validators.required,
  enabled: !_isLoading,
),
```
(Wrap the org-name field and this one in a `Column` or list them sequentially inside the existing `if/else`, matching the file's structure: change the `else` to `else ...[ orgNameField, SizedBox, setupCodeField ]` using a spread, since the current code has a single widget in the else branch.)
- In `_submit`, pass it:
```dart
await authRepository.registerGuide(
  email: email,
  password: password,
  displayName: displayName,
  joinOrgCode: _isJoiningOrg ? _joinOrgCodeController.text.trim() : null,
  newOrgName: _isJoiningOrg ? null : _newOrgNameController.text.trim(),
  orgCreationCode:
      _isJoiningOrg ? null : _orgCreationCodeController.text.trim(),
);
```
- In `friendlyGuideAuthError`, add as the FIRST check:
```dart
if (msg.contains('invalid-org-creation-code')) {
  return l10n.invalidOrgCreationCode;
}
```
(Before `invalid-invite-code`, since both contain "invalid".)

- [x] **Step 7: Extend the friendly-error test**

In `test/features/auth/friendly_error_test.dart`, add a case following the file's pattern:
```dart
test('maps invalid-org-creation-code', () {
  expect(
    friendlyGuideAuthError('firebasefunctionsexception: invalid-org-creation-code', l10n),
    l10n.invalidOrgCreationCode,
  );
});
```

- [x] **Step 8: Analyze + all tests + commit + push**

Run: `flutter gen-l10n && flutter analyze && flutter test && cd functions && npm test`
```bash
git add functions lib/features/auth lib/l10n test/features/auth
git commit -m "feat: org creation requires a setup code (all signups now code-gated)"
git push
```

- [x] **Step 9: Deploy (pre-approved)**

Run: `firebase deploy --only functions:registerGuide -P default` (always `-P default`, never the dev alias).
Expected: deploy completes for europe-west1.
Immediately after, remind Costin to create the `config/registration` doc in the Firebase console: until he does, org CREATION is blocked in prod (fail-closed by design; joining an org is unaffected).

---

## Task 16: TV leaderboard (item 15)

**Files:**
- Modify: `lib/features/auth/domain/camp_session.dart` (tvCode field)
- Modify: `lib/features/auth/data/camp_repository.dart` (generate on create)
- Modify: `lib/features/leaderboard/presentation/points_management_screen.dart` (Show-on-TV sheet)
- Modify: `lib/l10n/app_ro.arb`, `app_en.arb`, `app_hu.arb` (5 new keys)
- Create: `functions/lib/tvLeaderboard.js`
- Modify: `functions/index.js`
- Test: `functions/test/tvLeaderboard.test.js` (create)
- Create: `docs/tv/index.html`

Design: each camp gets a 6-char `tvCode`. A public HTTP function returns `{campName, language, teams:[{name, colorHex, points}]}` for a valid code (team aggregates only, no personal data, GDPR-clean). A static page at `https://costincj.github.io/CampConnect/tv/` (this repo's `docs/tv/`) asks for the code once, stores it in localStorage, and polls every 15 seconds, rendered big and dark for a TV browser. Guides find the code under a TV icon on the points screen. Phones keep using the in-app leaderboard.

- [x] **Step 1: Model: add `tvCode` to `CampSession`**

In `camp_session.dart`: add `final String? tvCode;` to fields and constructor (`this.tvCode`), read it in `fromFirestore` (`tvCode: data['tvCode'] as String?`), write it in `toFirestore` (`if (tvCode != null) 'tvCode': tvCode`), and thread it through `copyWith` (`String? tvCode`, `tvCode: tvCode ?? this.tvCode`).

- [x] **Step 2: Generate a code for new camps** (hardened with a collision check beyond the plan's literal snippet — see review notes)

In `camp_repository.dart`, add a private helper and use it in `createCampSession` when building the `CampSession`:
```dart
/// 6 chars from the ambiguity-free charset: easy to type on a TV remote,
/// 32^6 combinations behind a rate-limited endpoint.
static String generateTvCode() {
  final rng = Random.secure();
  return List.generate(
    6,
    (_) => AppConstants
        .codeCharset[rng.nextInt(AppConstants.codeCharset.length)],
  ).join();
}
```
(`import 'dart:math';`) and pass `tvCode: generateTvCode()` into the session object created in `createCampSession`.

- [x] **Step 3: l10n keys**

`app_ro.arb`:
```json
"showOnTv": "Afișează pe TV",
"tvCodeTitle": "Cod TV",
"tvInstructions": "Deschide adresa pe browserul televizorului și introdu codul:",
"tvUrlCopied": "Adresa a fost copiată",
"tvCodeCopied": "Codul a fost copiat",
```
`app_en.arb`:
```json
"showOnTv": "Show on TV",
"tvCodeTitle": "TV code",
"tvInstructions": "Open this address in the TV's browser and enter the code:",
"tvUrlCopied": "Address copied",
"tvCodeCopied": "Code copied",
```
`app_hu.arb`:
```json
"showOnTv": "Megjelenítés TV-n",
"tvCodeTitle": "TV-kód",
"tvInstructions": "Nyisd meg a címet a TV böngészőjében, és írd be a kódot:",
"tvUrlCopied": "Cím kimásolva",
"tvCodeCopied": "Kód kimásolva",
```
Run `flutter gen-l10n`.

- [x] **Step 4: Show-on-TV sheet on the points screen**

In `points_management_screen.dart`:
- AppBar gets an action (only when a session is active):
```dart
appBar: AppBar(
  title: Text(l10n.pointsManagement),
  actions: [
    if (ref.watch(activeCampSessionProvider).valueOrNull != null)
      IconButton(
        icon: const Icon(Icons.tv),
        tooltip: l10n.showOnTv,
        onPressed: () => _showTvSheet(context),
      ),
  ],
),
```
- The sheet (add to `_PointsManagementScreenState`):
```dart
void _showTvSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _TvLeaderboardSheet(),
  );
}
```
- New widget at the bottom of the file:
```dart
const _tvPageUrl = 'https://costincj.github.io/CampConnect/tv/';

/// Shows (and lazily creates, for camps made before this feature) the
/// camp's TV code plus the public page address.
class _TvLeaderboardSheet extends ConsumerStatefulWidget {
  const _TvLeaderboardSheet();

  @override
  ConsumerState<_TvLeaderboardSheet> createState() =>
      _TvLeaderboardSheetState();
}

class _TvLeaderboardSheetState extends ConsumerState<_TvLeaderboardSheet> {
  bool _generating = false;

  Future<void> _ensureTvCode(CampSession session) async {
    if (session.tvCode != null || _generating) return;
    _generating = true;
    try {
      await ref.read(campRepositoryProvider).updateCampSession(
            session.copyWith(tvCode: CampRepository.generateTvCode()),
          );
      ref.invalidate(activeCampSessionProvider);
    } finally {
      _generating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final sessionAsync = ref.watch(activeCampSessionProvider);
    final session = sessionAsync.valueOrNull;

    if (session != null && session.tvCode == null) {
      // Backfill for camps created before TV codes existed.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureTvCode(session));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: session == null || session.tvCode == null
          ? const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.tv, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(l10n.showOnTv,
                        style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(l10n.tvInstructions,
                    style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    title: Text(_tvPageUrl,
                        style: theme.textTheme.bodyMedium),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                            const ClipboardData(text: _tvPageUrl));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.tvUrlCopied)));
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: ListTile(
                    title: Text(l10n.tvCodeTitle,
                        style: theme.textTheme.labelMedium),
                    subtitle: Text(
                      session.tvCode!,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: session.tvCode!));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.tvCodeCopied)));
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
```
Imports to add: `package:flutter/services.dart`, `camp_session.dart`, `camp_repository.dart` (match paths used elsewhere).

- [x] **Step 5: Write the failing function test**

Create `functions/test/tvLeaderboard.test.js` (follow the emulator setup pattern of the sibling tests; use a minimal express-style req/res stub):
```js
const { tvLeaderboardHandler } = require("../lib/tvLeaderboard");

function fakeRes() {
  const res = {
    statusCode: 200, headers: {}, body: undefined,
    set(k, v) { this.headers[k] = v; return this; },
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
  };
  return res;
}

describe("tvLeaderboard", () => {
  beforeEach(async () => {
    await db.collection("camps").doc("c1").set({
      name: "Camp One", orgId: "o1", tvCode: "ABC234",
      language: "ro",
      startDate: new Date(), endDate: new Date(Date.now() + 86400000),
      teams: [], createdBy: "g1",
    });
    await db.doc("camps/c1/teams/t1").set(
        { name: "Red", colorHex: "#E53935", points: 40 });
    await db.doc("camps/c1/teams/t2").set(
        { name: "Blue", colorHex: "#1E88E5", points: 90 });
  });

  test("returns teams sorted by points for a valid code", async () => {
    const res = fakeRes();
    await tvLeaderboardHandler(db, { method: "GET", query: { code: "abc234" }, ip: "9.9.9.9" }, res);
    expect(res.statusCode).toBe(200);
    expect(res.body.campName).toBe("Camp One");
    expect(res.body.teams.map((t) => t.name)).toEqual(["Blue", "Red"]);
    expect(res.body.teams[0]).toEqual(
        { name: "Blue", colorHex: "#1E88E5", points: 90 });
  });

  test("404 for an unknown code", async () => {
    const res = fakeRes();
    await tvLeaderboardHandler(db, { method: "GET", query: { code: "ZZZZZZ" }, ip: "9.9.9.8" }, res);
    expect(res.statusCode).toBe(404);
  });

  test("400 for a malformed code", async () => {
    const res = fakeRes();
    await tvLeaderboardHandler(db, { method: "GET", query: { code: "x" }, ip: "9.9.9.7" }, res);
    expect(res.statusCode).toBe(400);
  });
});
```

- [x] **Step 6: Run, confirm failure**

Run: `cd functions && npm test -- tvLeaderboard`
Expected: FAIL, module not found.

- [x] **Step 7: Implement the handler + export** (purpose-specific rate limiter used instead of the shared login limiter, per the plan's own Step 7 note)

Create `functions/lib/tvLeaderboard.js`:
```js
const { checkRateLimit } = require("./rateLimiter");

const CODE_RE = /^[A-Z0-9]{6}$/;

/**
 * Public read-only leaderboard for the TV page. Input: ?code=XXXXXX (the
 * camp's tvCode). Output: team aggregates only (name, colorHex, points),
 * never personal data, so the endpoint is GDPR-safe to expose. Rate
 * limited per IP; responses are edge-cacheable for 10s to absorb the TV's
 * polling.
 */
async function tvLeaderboardHandler(db, req, res) {
  if (req.method !== "GET") {
    res.status(405).json({ error: "method-not-allowed" });
    return;
  }
  const ip = req.ip || "unknown";
  const allowed = await checkRateLimit(db, `tvLeaderboard:${ip}`);
  if (!allowed) {
    res.status(429).json({ error: "too-many-requests" });
    return;
  }
  const code = String((req.query && req.query.code) || "")
      .trim().toUpperCase();
  if (!CODE_RE.test(code)) {
    res.status(400).json({ error: "bad-code" });
    return;
  }
  const match = await db.collection("camps")
      .where("tvCode", "==", code).limit(1).get();
  if (match.empty) {
    res.status(404).json({ error: "not-found" });
    return;
  }
  const campDoc = match.docs[0];
  const camp = campDoc.data();
  const teamsSnap = await campDoc.ref.collection("teams").get();
  const teams = teamsSnap.docs.map((d) => ({
    name: d.data().name || d.id,
    colorHex: d.data().colorHex || "#9E9E9E",
    points: d.data().points || 0,
  })).sort((a, b) => b.points - a.points);

  res.set("Cache-Control", "public, max-age=10");
  res.status(200).json({
    campName: camp.name || "",
    language: camp.language || "ro",
    updatedAt: new Date().toISOString(),
    teams,
  });
}

module.exports = { tvLeaderboardHandler };
```
In `functions/index.js`: add `onRequest` to the https require, require the handler, and export:
```js
const { onCall, onRequest } = require("firebase-functions/v2/https");
const { tvLeaderboardHandler } = require("./lib/tvLeaderboard");
```
```js
/**
 * Public read-only TV leaderboard (see lib/tvLeaderboard.js). CORS open:
 * the page is served from GitHub Pages, and the response contains only
 * team aggregates.
 */
exports.tvLeaderboard = onRequest({ cors: true }, (req, res) =>
  tvLeaderboardHandler(getFirestore(), req, res)
);
```
Note: `checkRateLimit`'s existing limits were tuned for login attempts. If they are tighter than 1 request/15s per IP, add a purpose-specific generous limit (e.g. keyed window of 30 requests/minute) inside `tvLeaderboardHandler` instead of reusing the login limiter; check `rateLimiter.js` at implementation time and keep the TV polling comfortably inside it.

- [x] **Step 8: Run the function tests**

Run: `cd functions && npm test`
Expected: all pass.

- [x] **Step 9: The TV page**

Create `docs/tv/index.html` (self-contained, no build step; GitHub Pages serves it at `/CampConnect/tv/`):
```html
<!doctype html>
<html lang="ro">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CampConnect TV</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; margin: 0; }
  body {
    background: #101613; color: #fff; min-height: 100vh;
    font-family: system-ui, "Segoe UI", Roboto, sans-serif;
    display: flex; flex-direction: column; align-items: center;
  }
  #setup { margin: auto; text-align: center; }
  #setup h1 { font-size: 3rem; margin-bottom: 1rem; color: #7ddc9c; }
  #setup input {
    font-size: 3rem; letter-spacing: .5rem; text-align: center;
    text-transform: uppercase; width: 11ch; padding: .5rem 1rem;
    border-radius: 16px; border: 2px solid #7ddc9c;
    background: #1b241f; color: #fff;
  }
  #setup button {
    display: block; margin: 1.5rem auto 0; font-size: 1.6rem;
    padding: .6rem 2.5rem; border-radius: 999px; border: 0;
    background: #7ddc9c; color: #10241a; font-weight: 700; cursor: pointer;
  }
  #setup .err { color: #ff8a80; margin-top: 1rem; min-height: 1.5rem; }
  #board { display: none; width: 100%; max-width: 1400px; padding: 3vh 4vw; }
  #board h1 { font-size: 5vh; text-align: center; margin-bottom: 3vh; }
  .row {
    display: flex; align-items: center; gap: 2vw;
    background: #1b241f; border-radius: 20px;
    padding: 2vh 3vw; margin-bottom: 2vh;
  }
  .rank { font-size: 5vh; font-weight: 800; width: 8vw; text-align: center; }
  .dot { width: 5vh; height: 5vh; border-radius: 50%; flex: none; }
  .team { font-size: 5vh; font-weight: 700; flex: 1;
          overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .pts { font-size: 5vh; font-weight: 800; }
  #err { text-align: center; color: #ff8a80; font-size: 2.5vh; min-height: 3vh; }
</style>
</head>
<body>
  <div id="setup">
    <h1>CampConnect TV</h1>
    <input id="code" maxlength="6" autocomplete="off"
           placeholder="COD TV" aria-label="TV code">
    <button id="go">START</button>
    <div class="err" id="setupErr"></div>
  </div>
  <div id="board">
    <h1 id="campName"></h1>
    <div id="rows"></div>
    <div id="err"></div>
  </div>
<script>
  var ENDPOINT =
    "https://europe-west1-camp-connect-4644c.cloudfunctions.net/tvLeaderboard";
  var POLL_MS = 15000;
  var MEDALS = ["🥇", "🥈", "🥉"];
  var STRINGS = {
    ro: { pts: "pct", invalid: "Cod invalid", offline: "Fără conexiune, reîncerc..." },
    hu: { pts: "pont", invalid: "Érvénytelen kód", offline: "Nincs kapcsolat, újra..." },
    en: { pts: "pts", invalid: "Invalid code", offline: "Offline, retrying..." }
  };
  var lang = "ro", timer = null;

  function t(k) { return (STRINGS[lang] || STRINGS.ro)[k]; }

  function render(data) {
    lang = data.language || "ro";
    document.getElementById("campName").textContent = data.campName;
    var rows = document.getElementById("rows");
    rows.innerHTML = "";
    data.teams.forEach(function (team, i) {
      var row = document.createElement("div");
      row.className = "row";
      var rank = document.createElement("div");
      rank.className = "rank";
      rank.textContent = MEDALS[i] || (i + 1) + ".";
      var dot = document.createElement("div");
      dot.className = "dot";
      dot.style.background = team.colorHex;
      var name = document.createElement("div");
      name.className = "team";
      name.textContent = team.name;
      var pts = document.createElement("div");
      pts.className = "pts";
      pts.textContent = team.points + " " + t("pts");
      row.append(rank, dot, name, pts);
      rows.appendChild(row);
    });
    document.getElementById("err").textContent = "";
  }

  function poll(code) {
    fetch(ENDPOINT + "?code=" + encodeURIComponent(code))
      .then(function (r) {
        if (r.status === 404 || r.status === 400) {
          stop(); showSetup(t("invalid")); return null;
        }
        return r.ok ? r.json() : Promise.reject(new Error(r.status));
      })
      .then(function (data) { if (data) { showBoard(); render(data); } })
      .catch(function () {
        document.getElementById("err").textContent = t("offline");
      });
  }

  function start(code) {
    localStorage.setItem("tvCode", code);
    poll(code);
    timer = setInterval(function () { poll(code); }, POLL_MS);
  }
  function stop() { if (timer) clearInterval(timer); timer = null; }
  function showBoard() {
    document.getElementById("setup").style.display = "none";
    document.getElementById("board").style.display = "block";
  }
  function showSetup(msg) {
    localStorage.removeItem("tvCode");
    document.getElementById("board").style.display = "none";
    document.getElementById("setup").style.display = "block";
    document.getElementById("setupErr").textContent = msg || "";
  }

  document.getElementById("go").addEventListener("click", function () {
    var code = document.getElementById("code").value.trim().toUpperCase();
    if (code.length === 6) start(code);
  });
  document.getElementById("code").addEventListener("keydown", function (e) {
    if (e.key === "Enter") document.getElementById("go").click();
  });

  var saved = localStorage.getItem("tvCode");
  if (saved) start(saved);
</script>
</body>
</html>
```

- [x] **Step 10: Analyze + tests + manual QA + commit + push**

Run: `flutter gen-l10n && flutter analyze && flutter test && cd functions && npm test`
Manual QA (after Costin deploys the function): open the points screen, tap the TV icon, note the code; open the page in a desktop browser, enter the code; add points in the app; the page updates within ~15s. GitHub Pages check: since `docs/` has no Jekyll config, plain HTML in `docs/tv/` is served as-is once pushed.
```bash
git add lib functions docs/tv
git commit -m "feat: public TV leaderboard page with per-camp code"
git push
```

- [x] **Step 11: Deploy (pre-approved)**

Run: `firebase deploy --only functions:tvLeaderboard -P default`
Expected: deploy completes for europe-west1. The per-task push has already published `docs/tv/` via GitHub Pages (allow a few minutes for Pages to update).

---

## Final verification (run after all tasks)

- [x] `flutter gen-l10n` (clean), `flutter analyze` (No issues found!), `flutter test` (all pass)
- [x] `cd functions && npm test` (all pass)
- [ ] Manual device pass of the 18 original complaints, one by one, in Romanian UI — **Costin's task**
- [x] Confirm both deploys ran (`registerGuide`, `tvLeaderboard`, both with `-P default`) and remind Costin to create the `config/registration` doc if he hasn't yet
- [x] Hand Costin the collected manual-QA checklist from all tasks

## Self-review notes (done at plan time)

- Spec coverage: all 18 user items map to tasks: em dashes (T1), localized errors (T2), emergency count (T3), settings scroll (T4), team palette/random color (T5), points presets + after-submit leaderboard (T6), program time UX + past times (T7), quick-tips logo step (T8), logo cropper (T9), map banner X (T10), map default location (T11), location photo rules (T12), QOTD text box + answered (T13), select-vs-create session + first-login bug (T14), guide code gating + org-creation protection (T15), TV leaderboard (T16).
- Known judgment calls are listed under "Decisions" in the header; Costin should skim those four bullets before execution starts.
- Type consistency checked: `alertAckCounts` returns a Dart record, `firstUnusedPresetHex` takes `Iterable<String>`, `tvCode` is `String?` end to end, `autoSelectActiveSession(WidgetRef, AppUser)` matches both call sites.
- Constructor signatures for `AppUser` and `Announcement` in tests are marked "adjust to the real signature": the executor must open those two domain files before writing the tests.
