# Multi-Org Onboarding & Owner Management Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **⚠ STANDING PROJECT RULE — COMMITS:** Never run the commit steps without the user's explicit go-ahead. At each "Commit" step, stop and ask. This applies to subagents too.

**Goal:** Redesign the app's front door so camp organisers and guides each have a clear entry path, add a day-0 onboarding checklist for new org owners, and give owners tools to manage members and rotate the invite code.

**Architecture:** No data-model changes — one `guide` role; the org's `ownerUid` grants owner powers. Client mutations stay server-side: two new callables (`removeMember`, `rotateInviteCode`) in a shared `orgManagement.js` following the existing `registerGuide`/`deleteMyAccount` patterns. UI: 3-tile role selection → mode-parameterised guide login; a derived-state checklist card on guide home; a new "My organisation" screen.

**Tech Stack:** Flutter + Riverpod + go_router + gen-l10n (RO/HU/EN), Firebase (Auth, Firestore, Cloud Functions v2 callables with App Check), Jest + Firestore/Auth emulators for functions tests, `mocktail` widget tests. New dependency: `share_plus`.

**Spec:** `docs/superpowers/specs/2026-07-06-multi-org-onboarding-design.md`

---

## File Structure

**Create:**

| File | Responsibility |
|---|---|
| `lib/features/home/presentation/day0_checklist_card.dart` | Day-0 onboarding card (owner-only, derived state, local dismissal) |
| `lib/features/organization/presentation/organization_screen.dart` | "My organisation" screen + `friendlyOrgError` mapper |
| `functions/lib/orgManagement.js` | `requireOwner` guard + `removeMemberHandler` + `rotateInviteCodeHandler` |
| `functions/test/orgManagement.test.js` | Emulator tests for both handlers |
| `test/features/auth/role_selection_screen_test.dart` | 3-tile navigation tests |
| `test/features/auth/guide_login_screen_test.dart` | Mode-driven form tests |
| `test/features/home/day0_checklist_card_test.dart` | Checklist visibility/derivation tests |
| `test/features/organization/organization_screen_test.dart` | Member list + owner actions tests |
| `test/features/organization/friendly_org_error_test.dart` | Error mapper unit tests |

**Modify:** `pubspec.yaml`, `lib/l10n/app_{en,ro,hu}.arb` (+ regenerated `.g.dart`), `lib/features/auth/presentation/role_selection_screen.dart`, `lib/features/auth/presentation/guide_login_screen.dart`, `lib/core/router/app_router.dart`, `lib/shared/providers/providers.dart`, `lib/features/organization/domain/org_member.dart`, `lib/features/organization/data/organization_repository.dart`, `lib/features/home/presentation/guide_home_screen.dart`, `lib/features/settings/presentation/guide_settings_screen.dart`, `functions/lib/registerGuide.js`, `functions/index.js`, `functions/package.json`, `functions/test/registerGuide.test.js`, `test/features/organization/organization_test.dart`, `docs/firestore-schema.md`.

---

### Task 1: Dependency + localisation groundwork

No behaviour change — infrastructure the later tasks compile against.

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ro.arb`, `lib/l10n/app_hu.arb`

- [ ] **Step 1: Add share_plus**

Run: `flutter pub add share_plus`
Expected: resolves and adds `share_plus: ^<latest>` to `pubspec.yaml`.

- [ ] **Step 2: Add English strings**

In `lib/l10n/app_en.arb`, after the existing `"inviteCodeCopied"` entry, add:

```json
  "setupCampTile": "I'm setting up a camp",
  "setupCampDescription": "Create your organisation and run your camps",
  "setupYourOrg": "Set up your camp organisation",
  "joinYourOrg": "Join your organisation",
  "switchToJoin": "Have an invite code instead?",
  "switchToCreate": "Setting up a new organisation?",
  "day0Title": "Get your camp running",
  "stepCreateSession": "Create your first camp session",
  "stepInviteGuides": "Invite your guides",
  "stepGenerateCodes": "Generate kid codes",
  "shareInviteMessage": "Join {orgName} on CampConnect! Open the app and register as a guide with invite code {inviteCode}.",
  "@shareInviteMessage": {
    "placeholders": {
      "orgName": {"type": "String"},
      "inviteCode": {"type": "String"}
    }
  },
  "myOrganization": "My organisation",
  "members": "Members",
  "ownerRole": "Owner",
  "guideRole": "Guide",
  "removeGuide": "Remove guide",
  "removeGuideConfirm": "Remove {name} from the organisation? They will lose access immediately.",
  "@removeGuideConfirm": {
    "placeholders": {
      "name": {"type": "String"}
    }
  },
  "memberRemoved": "Guide removed",
  "rotateInviteCodeAction": "Generate new invite code",
  "rotateInviteCodeConfirm": "The current code will stop working. Guides who already joined are not affected.",
  "codeRotated": "New invite code generated",
  "notOrgOwner": "Only the organisation owner can do this",
  "share": "Share",
  "dismiss": "Dismiss",
```

Also **change the value** of the existing `"guideDescription"` key to: `"I have an invite code from my organiser"`.

- [ ] **Step 3: Add Romanian strings**

Same keys in `lib/l10n/app_ro.arb` (keep the same `@`-metadata blocks as EN for the two keys with placeholders):

```json
  "setupCampTile": "Îmi organizez tabăra",
  "setupCampDescription": "Creează-ți organizația și administrează-ți taberele",
  "setupYourOrg": "Configurează-ți organizația taberei",
  "joinYourOrg": "Alătură-te organizației tale",
  "switchToJoin": "Ai deja un cod de invitație?",
  "switchToCreate": "Vrei să creezi o organizație nouă?",
  "day0Title": "Pune tabăra în mișcare",
  "stepCreateSession": "Creează prima sesiune de tabără",
  "stepInviteGuides": "Invită-ți ghizii",
  "stepGenerateCodes": "Generează coduri pentru copii",
  "shareInviteMessage": "Alătură-te {orgName} pe CampConnect! Deschide aplicația și înregistrează-te ca ghid cu codul de invitație {inviteCode}.",
  "myOrganization": "Organizația mea",
  "members": "Membri",
  "ownerRole": "Proprietar",
  "guideRole": "Ghid",
  "removeGuide": "Elimină ghidul",
  "removeGuideConfirm": "Elimini {name} din organizație? Va pierde imediat accesul.",
  "memberRemoved": "Ghid eliminat",
  "rotateInviteCodeAction": "Generează un cod de invitație nou",
  "rotateInviteCodeConfirm": "Codul actual nu va mai funcționa. Ghizii deja membri nu sunt afectați.",
  "codeRotated": "Cod de invitație nou generat",
  "notOrgOwner": "Doar proprietarul organizației poate face asta",
  "share": "Trimite",
  "dismiss": "Închide",
```

`"guideDescription"` → `"Am un cod de invitație de la organizator"`.

- [ ] **Step 4: Add Hungarian strings**

Same keys in `lib/l10n/app_hu.arb`:

```json
  "setupCampTile": "Tábort szervezek",
  "setupCampDescription": "Hozd létre a szervezeted és kezeld a táboraid",
  "setupYourOrg": "Állítsd be a táborszervezeted",
  "joinYourOrg": "Csatlakozz a szervezetedhez",
  "switchToJoin": "Van már meghívó kódod?",
  "switchToCreate": "Új szervezetet hoznál létre?",
  "day0Title": "Indítsd be a tábort",
  "stepCreateSession": "Hozd létre az első tábori turnust",
  "stepInviteGuides": "Hívd meg a vezetőidet",
  "stepGenerateCodes": "Generálj kódokat a gyerekeknek",
  "shareInviteMessage": "Csatlakozz a(z) {orgName} szervezethez a CampConnect-en! Nyisd meg az alkalmazást és regisztrálj vezetőként a(z) {inviteCode} meghívó kóddal.",
  "myOrganization": "Szervezetem",
  "members": "Tagok",
  "ownerRole": "Tulajdonos",
  "guideRole": "Vezető",
  "removeGuide": "Vezető eltávolítása",
  "removeGuideConfirm": "Eltávolítod {name} tagot a szervezetből? Azonnal elveszíti a hozzáférését.",
  "memberRemoved": "Vezető eltávolítva",
  "rotateInviteCodeAction": "Új meghívó kód generálása",
  "rotateInviteCodeConfirm": "A jelenlegi kód érvényét veszti. A már csatlakozott vezetőket nem érinti.",
  "codeRotated": "Új meghívó kód generálva",
  "notOrgOwner": "Ezt csak a szervezet tulajdonosa teheti meg",
  "share": "Megosztás",
  "dismiss": "Bezárás",
```

`"guideDescription"` → `"Meghívó kódom van a szervezőtől"`.

- [ ] **Step 5: Regenerate localisations and verify**

Run: `flutter gen-l10n; flutter analyze`
Expected: generation succeeds; analyze reports no new issues (unused-getter warnings for not-yet-used keys do not occur with gen-l10n).

- [ ] **Step 6: Commit** *(ask user first — standing rule)*

```bash
git add pubspec.yaml pubspec.lock lib/l10n/
git commit -m "feat: add share_plus and RO/HU/EN strings for multi-org onboarding"
```

---

### Task 2: `joinedAt` on org membership

Member list shows a joined date; membership docs don't carry one yet. Add it server-side at write time; the model treats it as optional (existing members lack it).

**Files:**
- Modify: `functions/lib/registerGuide.js:96-104`
- Modify: `functions/test/registerGuide.test.js`
- Modify: `lib/features/organization/domain/org_member.dart`
- Modify: `test/features/organization/organization_test.dart`

- [ ] **Step 1: Extend the functions test (failing)**

In `functions/test/registerGuide.test.js`, inside the first test (`creating a new org…`), after the `memberDoc` role assertion, add:

```js
  expect(memberDoc.data().joinedAt).toBeTruthy();
```

- [ ] **Step 2: Run it to verify it fails**

Run (from `functions/`, emulators must be running — same as existing suite): `npm run test:register`
Expected: FAIL — `joinedAt` is undefined.

- [ ] **Step 3: Write `joinedAt` in registerGuide**

In `functions/lib/registerGuide.js`, add `joinedAt: FieldValue.serverTimestamp(),` to **both** membership writes:

```js
    batch.set(pendingOrg.orgRef.collection("members").doc(uid), {
      role: "owner",
      displayName: displayName,
      joinedAt: FieldValue.serverTimestamp(),
    });
```

```js
    batch.set(
      db.doc(`organizations/${orgId}/members/${uid}`),
      { role: "guide", displayName: displayName,
        joinedAt: FieldValue.serverTimestamp() });
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run test:register`
Expected: PASS.

- [ ] **Step 5: Add `joinedAt` to the Dart model (failing test first)**

In `test/features/organization/organization_test.dart`, add:

```dart
  test('OrgMember parses optional joinedAt', () {
    // Existing members have no joinedAt — must stay null, not crash.
    const member = OrgMember(uid: 'u1', role: 'guide', displayName: 'G');
    expect(member.joinedAt, isNull);

    final withDate = OrgMember(
      uid: 'u2',
      role: 'guide',
      displayName: 'H',
      joinedAt: DateTime(2026, 7, 6),
    );
    expect(withDate.joinedAt, DateTime(2026, 7, 6));
  });
```

Run: `flutter test test/features/organization/organization_test.dart`
Expected: FAIL — no `joinedAt` parameter.

- [ ] **Step 6: Implement**

Replace `lib/features/organization/domain/org_member.dart` with:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class OrgMember {
  final String uid;
  final String role; // 'owner' | 'guide'
  final String displayName;
  final DateTime? joinedAt; // null for members created before this field existed

  const OrgMember({
    required this.uid,
    required this.role,
    required this.displayName,
    this.joinedAt,
  });

  factory OrgMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrgMember(
      uid: doc.id,
      role: data['role'] as String? ?? 'guide',
      displayName: data['displayName'] as String? ?? '',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
    );
  }
}
```

- [ ] **Step 7: Run tests**

Run: `flutter test test/features/organization/organization_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit** *(ask user first)*

```bash
git add functions/lib/registerGuide.js functions/test/registerGuide.test.js lib/features/organization/domain/org_member.dart test/features/organization/organization_test.dart
git commit -m "feat: stamp joinedAt on org memberships"
```

---

### Task 3: Org providers

Two small providers the checklist and org screen both need. No dedicated test — they're thin wiring, exercised by the widget tests in Tasks 6–7.

**Files:**
- Modify: `lib/shared/providers/providers.dart`

- [ ] **Step 1: Add providers**

In `lib/shared/providers/providers.dart`, add the missing domain imports at the top (next to the existing organization import):

```dart
import '../../features/organization/domain/organization.dart';
import '../../features/organization/domain/org_member.dart';
```

Then, directly below `organizationRepositoryProvider`, add:

```dart
/// The signed-in guide's organisation (null for kids / signed-out).
final currentOrganizationProvider = FutureProvider<Organization?>((ref) async {
  final orgId = ref.watch(appUserProvider).valueOrNull?.orgId;
  if (orgId == null) return null;
  return ref.watch(organizationRepositoryProvider).getOrganization(orgId);
});

/// Live member list of the signed-in guide's organisation.
final orgMembersProvider = StreamProvider<List<OrgMember>>((ref) {
  final orgId = ref.watch(appUserProvider).valueOrNull?.orgId;
  if (orgId == null) return Stream.value([]);
  return ref.watch(organizationRepositoryProvider).watchMembers(orgId);
});
```

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: no issues.

- [ ] **Step 3: Commit** *(ask user first)*

```bash
git add lib/shared/providers/providers.dart
git commit -m "feat: add currentOrganization and orgMembers providers"
```

---

### Task 4: Three-door role selection

**Files:**
- Modify: `lib/features/auth/presentation/role_selection_screen.dart:54-72`
- Modify: `lib/core/router/app_router.dart:70-73`
- Test: `test/features/auth/role_selection_screen_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/features/auth/role_selection_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/features/auth/presentation/role_selection_screen.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';

void main() {
  Uri? capturedGuideLoginUri;

  Widget buildTestable() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const RoleSelectionScreen(),
        ),
        GoRoute(
          path: '/guide-login',
          builder: (context, state) {
            capturedGuideLoginUri = state.uri;
            return const Scaffold(body: Text('guide-login'));
          },
        ),
        GoRoute(
          path: '/kid-login',
          builder: (context, state) => const Scaffold(body: Text('kid-login')),
        ),
      ],
    );

    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
      ),
    );
  }

  setUp(() => capturedGuideLoginUri = null);

  testWidgets('shows three role tiles', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    final l10n = AppL10n.of(tester.element(find.byType(RoleSelectionScreen)));
    expect(find.text(l10n.imAKid), findsOneWidget);
    expect(find.text(l10n.imAGuide), findsOneWidget);
    expect(find.text(l10n.setupCampTile), findsOneWidget);
  });

  testWidgets('setup-camp tile navigates to guide-login with create-org mode',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    final l10n = AppL10n.of(tester.element(find.byType(RoleSelectionScreen)));
    await tester.tap(find.text(l10n.setupCampTile));
    await tester.pumpAndSettle();

    expect(capturedGuideLoginUri?.queryParameters['mode'], 'create-org');
  });

  testWidgets('guide tile navigates to guide-login with join-org mode',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    final l10n = AppL10n.of(tester.element(find.byType(RoleSelectionScreen)));
    await tester.tap(find.text(l10n.imAGuide));
    await tester.pumpAndSettle();

    expect(capturedGuideLoginUri?.queryParameters['mode'], 'join-org');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/auth/role_selection_screen_test.dart`
Expected: FAIL — `setupCampTile` text not found; `mode` param absent.

- [ ] **Step 3: Add the third tile and mode params**

In `lib/features/auth/presentation/role_selection_screen.dart`, replace the two `_RoleCard` widgets (and the spacing between them) with:

```dart
              _RoleCard(
                icon: Icons.child_care,
                label: l10n.imAKid,
                description: l10n.kidDescription,
                color: camp.sunsetSoft,
                onColor: camp.onSunsetSoft,
                onTap: () => context.go('/kid-login'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.school,
                label: l10n.imAGuide,
                description: l10n.guideDescription,
                color: colorScheme.primaryContainer,
                onColor: colorScheme.onPrimaryContainer,
                onTap: () => context.go('/guide-login?mode=join-org'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.add_business_outlined,
                label: l10n.setupCampTile,
                description: l10n.setupCampDescription,
                color: colorScheme.secondaryContainer,
                onColor: colorScheme.onSecondaryContainer,
                onTap: () => context.go('/guide-login?mode=create-org'),
              ),
```

Also change `const Spacer(flex: 3)` at the bottom to `const Spacer(flex: 2)` so three cards fit comfortably on small screens.

- [ ] **Step 4: Run test — 2 of 3 pass, mode assertions still need the router**

The test router captures the URI regardless of the real app router, so all 3 should PASS already:

Run: `flutter test test/features/auth/role_selection_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit** *(ask user first)*

```bash
git add lib/features/auth/presentation/role_selection_screen.dart test/features/auth/role_selection_screen_test.dart
git commit -m "feat: three-door role selection (kid / guide / set up a camp)"
```

---

### Task 5: Mode-aware guide login screen

**Files:**
- Modify: `lib/features/auth/presentation/guide_login_screen.dart`
- Modify: `lib/core/router/app_router.dart:70-73`
- Test: `test/features/auth/guide_login_screen_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/features/auth/guide_login_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:camp_connect/features/auth/data/auth_repository.dart';
import 'package:camp_connect/features/auth/presentation/guide_login_screen.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/shared/services/fcm_service.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockFcmService extends Mock implements FcmService {}

void main() {
  late MockAuthRepository authRepository;
  late MockFcmService fcmService;

  setUp(() {
    authRepository = MockAuthRepository();
    fcmService = MockFcmService();
    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => const Stream.empty());
  });

  Widget buildTestable(GuideLoginMode mode) {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => GuideLoginScreen(initialMode: mode),
        ),
        GoRoute(
          path: '/role-selection',
          builder: (context, state) =>
              const Scaffold(body: Text('role-selection')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        fcmServiceProvider.overrideWithValue(fcmService),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
      ),
    );
  }

  AppL10n l10nOf(WidgetTester tester) =>
      AppL10n.of(tester.element(find.byType(GuideLoginScreen)));

  testWidgets('create-org mode starts on the register form with org name field',
      (tester) async {
    await tester.pumpWidget(buildTestable(GuideLoginMode.createOrg));
    await tester.pumpAndSettle();

    final l10n = l10nOf(tester);
    expect(find.text(l10n.setupYourOrg), findsWidgets);
    expect(find.byKey(const ValueKey('newOrgName')), findsOneWidget);
    expect(find.byKey(const ValueKey('joinOrgCode')), findsNothing);
  });

  testWidgets('join-org mode starts on sign-in; register shows invite code field',
      (tester) async {
    await tester.pumpWidget(buildTestable(GuideLoginMode.joinOrg));
    await tester.pumpAndSettle();

    final l10n = l10nOf(tester);
    // Starts in sign-in mode.
    expect(find.text(l10n.welcomeBack), findsOneWidget);

    // Switch to register.
    await tester.tap(find.text(l10n.noAccount));
    await tester.pumpAndSettle();

    expect(find.text(l10n.joinYourOrg), findsWidgets);
    expect(find.byKey(const ValueKey('joinOrgCode')), findsOneWidget);
    expect(find.byKey(const ValueKey('newOrgName')), findsNothing);
  });

  testWidgets('switch link flips between join and create fields',
      (tester) async {
    await tester.pumpWidget(buildTestable(GuideLoginMode.createOrg));
    await tester.pumpAndSettle();

    final l10n = l10nOf(tester);
    await tester.tap(find.text(l10n.switchToJoin));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('joinOrgCode')), findsOneWidget);
    expect(find.byKey(const ValueKey('newOrgName')), findsNothing);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/auth/guide_login_screen_test.dart`
Expected: FAIL — `GuideLoginMode` and `initialMode` don't exist.

- [ ] **Step 3: Implement the mode-aware screen**

In `lib/features/auth/presentation/guide_login_screen.dart`:

**(a)** Add the enum above the widget class:

```dart
/// Which door the user entered through on role selection. Only affects the
/// REGISTER form (which org field shows, titles); sign-in is identical.
enum GuideLoginMode { joinOrg, createOrg }
```

**(b)** Change the widget declaration and add mode-derived initial state:

```dart
class GuideLoginScreen extends ConsumerStatefulWidget {
  const GuideLoginScreen({super.key, this.initialMode = GuideLoginMode.joinOrg});

  final GuideLoginMode initialMode;

  @override
  ConsumerState<GuideLoginScreen> createState() => _GuideLoginScreenState();
}
```

In `_GuideLoginScreenState`, replace the two field initialisers:

```dart
  bool _isRegistering = false;
  ...
  bool _isJoiningOrg = true;
```

with plain declarations plus an `initState`:

```dart
  late bool _isRegistering;
  bool _isLoading = false;
  bool _obscurePassword = true;
  late bool _isJoiningOrg;

  @override
  void initState() {
    super.initState();
    // "Set up a camp" implies a brand-new organiser -> straight to register.
    // "I'm a guide" is usually a returning user -> sign-in first.
    _isRegistering = widget.initialMode == GuideLoginMode.createOrg;
    _isJoiningOrg = widget.initialMode != GuideLoginMode.createOrg;
  }
```

(Keep `_isLoading`/`_obscurePassword` — only their placement moves.)

**(c)** Replace the `SegmentedButton<bool>` block (the whole `SegmentedButton(...)` widget and the `SizedBox` after it) with nothing — delete it. Then, after the join/create `TextFormField` conditional (the existing `if (_isJoiningOrg) ... else ...` block), insert the switch link before the trailing `const SizedBox(height: 16),`:

```dart
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(
                                  () => _isJoiningOrg = !_isJoiningOrg),
                        child: Text(
                          _isJoiningOrg
                              ? l10n.switchToCreate
                              : l10n.switchToJoin,
                        ),
                      ),
                    ),
```

**(d)** Mode-specific titles. Replace the AppBar title:

```dart
        title: Text(
          _isRegistering
              ? (_isJoiningOrg ? l10n.joinYourOrg : l10n.setupYourOrg)
              : l10n.guideLogin,
        ),
```

and the headline `Text` (`_isRegistering ? l10n.createAccount : l10n.welcomeBack`):

```dart
                  Text(
                    _isRegistering
                        ? (_isJoiningOrg ? l10n.joinYourOrg : l10n.setupYourOrg)
                        : l10n.welcomeBack,
```

(The submit button and mode-toggle at the bottom keep using `createAccount`/`hasAccount`/`noAccount` unchanged.)

**(e)** Wire the router. In `lib/core/router/app_router.dart` replace the `/guide-login` route:

```dart
      GoRoute(
        path: '/guide-login',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'];
          return GuideLoginScreen(
            initialMode: mode == 'create-org'
                ? GuideLoginMode.createOrg
                : GuideLoginMode.joinOrg,
          );
        },
      ),
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/auth/guide_login_screen_test.dart test/features/auth/friendly_error_test.dart; flutter analyze`
Expected: PASS, no analyze issues.

- [ ] **Step 5: Commit** *(ask user first)*

```bash
git add lib/features/auth/presentation/guide_login_screen.dart lib/core/router/app_router.dart test/features/auth/guide_login_screen_test.dart
git commit -m "feat: mode-aware guide registration (create-org vs join-org doors)"
```

---

### Task 6: Cloud Functions — removeMember + rotateInviteCode (TDD)

**Files:**
- Create: `functions/lib/orgManagement.js`
- Create: `functions/test/orgManagement.test.js`
- Modify: `functions/index.js`, `functions/package.json`

- [ ] **Step 1: Write the failing tests**

Create `functions/test/orgManagement.test.js`:

```js
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";

const { makeTestEnv, makeAdminDb, makeAuthAdmin, cleanupAdminApps } = require("./helpers/emulatorEnv");
const { removeMemberHandler, rotateInviteCodeHandler } = require("../lib/orgManagement");
const { CHARSET, CODE_LENGTH } = require("../lib/inviteCode");

let testEnv, db, authAdmin;

beforeAll(async () => {
  ({ testEnv } = await makeTestEnv("campconnect-orgmgmt-test"));
  db = makeAdminDb("campconnect-orgmgmt-test");
  authAdmin = makeAuthAdmin("campconnect-orgmgmt-test");
});

afterAll(async () => {
  await testEnv.cleanup();
  await cleanupAdminApps();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

// Seeds an org with an owner and one plain guide. The guide also gets a real
// Auth user because removeMemberHandler clears their custom claims.
async function seedOrg({ ownerUid = "owner-1", memberUid = "member-1" } = {}) {
  await db.doc("organizations/org-1").set({
    name: "Camp Falcon", ownerUid, inviteCode: "AAAAAAAAAA",
  });
  await db.doc(`organizations/org-1/members/${ownerUid}`).set({
    role: "owner", displayName: "Owner",
  });
  await db.doc(`organizations/org-1/members/${memberUid}`).set({
    role: "guide", displayName: "Member",
  });
  await db.doc(`users/${ownerUid}`).set({ role: "guide", orgId: "org-1" });
  await db.doc(`users/${memberUid}`).set({
    role: "guide", orgId: "org-1", campId: "camp-1",
  });
  try {
    await authAdmin.createUser({ uid: memberUid, email: `${memberUid}@example.com`, password: "correcthorsebattery" });
  } catch (e) {
    if (e.code !== "auth/uid-already-exists") throw e;
  }
  await authAdmin.setCustomUserClaims(memberUid, { role: "guide", orgId: "org-1" });
}

// --- removeMember ---

test("owner removes a guide: membership deleted, profile org cleared, claims cleared", async () => {
  await seedOrg();
  const result = await removeMemberHandler(db, authAdmin, { uid: "owner-1" }, { memberUid: "member-1" });
  expect(result.ok).toBe(true);

  const member = await db.doc("organizations/org-1/members/member-1").get();
  expect(member.exists).toBe(false);

  const profile = await db.doc("users/member-1").get();
  expect(profile.data().orgId).toBeUndefined();
  expect(profile.data().campId).toBeUndefined();

  const user = await authAdmin.getUser("member-1");
  expect(user.customClaims.orgId).toBeUndefined();
  expect(user.customClaims.role).toBe("guide");
});

test("non-owner guide cannot remove a member", async () => {
  await seedOrg();
  await expect(
    removeMemberHandler(db, authAdmin, { uid: "member-1" }, { memberUid: "owner-1" })
  ).rejects.toMatchObject({ code: "permission-denied" });
});

test("owner cannot remove themself", async () => {
  await seedOrg();
  await expect(
    removeMemberHandler(db, authAdmin, { uid: "owner-1" }, { memberUid: "owner-1" })
  ).rejects.toMatchObject({ code: "invalid-argument" });
});

test("unauthenticated removeMember is rejected", async () => {
  await seedOrg();
  await expect(
    removeMemberHandler(db, authAdmin, null, { memberUid: "member-1" })
  ).rejects.toMatchObject({ code: "unauthenticated" });
});

test("removing a non-member throws not-found", async () => {
  await seedOrg();
  await expect(
    removeMemberHandler(db, authAdmin, { uid: "owner-1" }, { memberUid: "ghost" })
  ).rejects.toMatchObject({ code: "not-found" });
});

test("missing memberUid throws invalid-argument", async () => {
  await seedOrg();
  await expect(
    removeMemberHandler(db, authAdmin, { uid: "owner-1" }, {})
  ).rejects.toMatchObject({ code: "invalid-argument" });
});

// --- rotateInviteCode ---

test("owner rotates the invite code: new well-formed code stored and returned", async () => {
  await seedOrg();
  const result = await rotateInviteCodeHandler(db, { uid: "owner-1" });
  expect(result.ok).toBe(true);
  expect(result.inviteCode).toHaveLength(CODE_LENGTH);
  expect(result.inviteCode).not.toBe("AAAAAAAAAA");
  for (const ch of result.inviteCode) {
    expect(CHARSET).toContain(ch);
  }

  const org = await db.doc("organizations/org-1").get();
  expect(org.data().inviteCode).toBe(result.inviteCode);
});

test("non-owner cannot rotate the invite code", async () => {
  await seedOrg();
  await expect(
    rotateInviteCodeHandler(db, { uid: "member-1" })
  ).rejects.toMatchObject({ code: "permission-denied" });

  const org = await db.doc("organizations/org-1").get();
  expect(org.data().inviteCode).toBe("AAAAAAAAAA");
});

test("unauthenticated rotateInviteCode is rejected", async () => {
  await expect(
    rotateInviteCodeHandler(db, null)
  ).rejects.toMatchObject({ code: "unauthenticated" });
});
```

- [ ] **Step 2: Run to verify it fails**

Run (from `functions/`, with emulators running): `npx jest test/orgManagement.test.js`
Expected: FAIL — `../lib/orgManagement` module not found.

- [ ] **Step 3: Implement the handlers**

Create `functions/lib/orgManagement.js`:

```js
const { HttpsError } = require("firebase-functions/v2/https");
const { FieldValue } = require("firebase-admin/firestore");
const { generateOrgInviteCode } = require("./inviteCode");

/**
 * Shared guard for owner-only org management. Resolves the caller's org from
 * their users/{uid} profile and verifies they are its ownerUid.
 *
 * Returns { orgRef, orgId, uid }.
 * Throws:
 *   unauthenticated   — no auth context
 *   permission-denied ("not-org-owner") — caller isn't a guide with an org,
 *                       or isn't the owner of that org
 */
async function requireOwner(db, auth) {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = auth.uid;

  const userSnap = await db.doc(`users/${uid}`).get();
  const user = userSnap.exists ? userSnap.data() : null;
  if (!user || user.role !== "guide" || !user.orgId) {
    throw new HttpsError("permission-denied", "not-org-owner");
  }

  const orgRef = db.doc(`organizations/${user.orgId}`);
  const org = await orgRef.get();
  if (!org.exists || org.data().ownerUid !== uid) {
    throw new HttpsError("permission-denied", "not-org-owner");
  }
  return { orgRef, orgId: user.orgId, uid };
}

/**
 * removeMemberHandler(db, authAdmin, auth, data)
 *
 * Owner-only: removes a guide from the caller's organisation. Deletes the
 * membership doc, clears orgId/campId on the ex-member's profile, and strips
 * the org from their custom claims so security-rule access ends on their next
 * token refresh. The removed guide keeps their account and can re-join any
 * org with a valid invite code.
 *
 * data: { memberUid }
 * Throws HttpsError:
 *   unauthenticated / permission-denied ("not-org-owner") — see requireOwner
 *   invalid-argument ("Missing memberUid.") — no target given
 *   invalid-argument ("cannot-remove-owner") — target is the owner themself
 *   not-found ("member-not-found") — target isn't a member of the caller's org
 */
async function removeMemberHandler(db, authAdmin, auth, data) {
  const { orgRef, uid } = await requireOwner(db, auth);

  const { memberUid } = data || {};
  if (!memberUid) {
    throw new HttpsError("invalid-argument", "Missing memberUid.");
  }
  if (memberUid === uid) {
    throw new HttpsError("invalid-argument", "cannot-remove-owner");
  }

  const memberRef = orgRef.collection("members").doc(memberUid);
  const member = await memberRef.get();
  if (!member.exists) {
    throw new HttpsError("not-found", "member-not-found");
  }

  await memberRef.delete();
  // Best-effort profile cleanup: the membership (authoritative) is already
  // gone; a missing users doc must not fail the call.
  await db.doc(`users/${memberUid}`).update({
    orgId: FieldValue.delete(),
    campId: FieldValue.delete(),
  }).catch(() => {});
  await authAdmin.setCustomUserClaims(memberUid, { role: "guide" });

  return { ok: true };
}

/**
 * rotateInviteCodeHandler(db, auth)
 *
 * Owner-only: replaces the org's invite code with a fresh unique one. The old
 * code stops matching on registerGuide joins immediately; existing members
 * are unaffected.
 *
 * Throws HttpsError:
 *   unauthenticated / permission-denied ("not-org-owner") — see requireOwner
 */
async function rotateInviteCodeHandler(db, auth) {
  const { orgRef } = await requireOwner(db, auth);

  // Same uniqueness loop as registerGuide's org creation.
  let code;
  let clash;
  do {
    code = generateOrgInviteCode();
    clash = await db.collection("organizations")
      .where("inviteCode", "==", code).limit(1).get();
  } while (!clash.empty);

  await orgRef.update({ inviteCode: code });
  return { ok: true, inviteCode: code };
}

module.exports = { removeMemberHandler, rotateInviteCodeHandler };
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `npx jest test/orgManagement.test.js`
Expected: all 9 PASS.

- [ ] **Step 5: Export the callables and register the test script**

In `functions/index.js`, add to the requires at the top:

```js
const { removeMemberHandler, rotateInviteCodeHandler } = require("./lib/orgManagement");
```

And after the `deleteCamp` export at the bottom:

```js
/**
 * Owner-only org management (see lib/orgManagement.js): remove a guide from
 * the caller's org / rotate the org's invite code. Client writes to
 * organizations/** remain denied by rules; these are the only mutation paths.
 */
exports.removeMember = onCall({ enforceAppCheck: true }, (request) =>
  removeMemberHandler(getFirestore(), getAuth(), request.auth, request.data)
);

exports.rotateInviteCode = onCall({ enforceAppCheck: true }, (request) =>
  rotateInviteCodeHandler(getFirestore(), request.auth)
);
```

In `functions/package.json`, add to `"scripts"`:

```json
    "test:orgmgmt": "jest test/orgManagement.test.js",
```

and extend the `"test"` chain by appending ` && npm run test:orgmgmt` at the end of the existing value.

- [ ] **Step 6: Run the full functions suite**

Run (from `functions/`): `npm test`
Expected: all suites PASS (including rules tests — no rule changes were needed; org writes stay denied).

- [ ] **Step 7: Commit** *(ask user first)*

```bash
git add functions/lib/orgManagement.js functions/test/orgManagement.test.js functions/index.js functions/package.json
git commit -m "feat: owner-only removeMember and rotateInviteCode callables"
```

---

### Task 7: Client plumbing — repository callables + error mapper

**Files:**
- Modify: `lib/features/organization/data/organization_repository.dart`
- Modify: `lib/shared/providers/providers.dart:67-69`
- Create: `lib/features/organization/presentation/organization_screen.dart` (mapper only in this task; screen body in Task 8)
- Test: `test/features/organization/friendly_org_error_test.dart`

- [ ] **Step 1: Write the failing mapper test**

Create `test/features/organization/friendly_org_error_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:camp_connect/features/organization/presentation/organization_screen.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';

void main() {
  late AppL10n l10n;

  setUp(() {
    l10n = lookupAppL10n(const Locale('en'));
  });

  test('not-org-owner maps to notOrgOwner', () {
    expect(friendlyOrgError('not-org-owner', l10n), l10n.notOrgOwner);
  });

  test('network errors map to networkError', () {
    expect(
      friendlyOrgError('firebase_functions/unavailable network error', l10n),
      l10n.networkError,
    );
  });

  test('anything else maps to somethingWentWrong', () {
    expect(friendlyOrgError('kaboom', l10n), l10n.somethingWentWrong);
  });
}
```

> Note: `lookupAppL10n(Locale)` is how gen-l10n exposes sync lookup; check `test/features/auth/friendly_error_test.dart` for the exact established pattern in this repo and mirror it (including the `Locale` import) if it differs.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/organization/friendly_org_error_test.dart`
Expected: FAIL — file `organization_screen.dart` doesn't exist.

- [ ] **Step 3: Create the mapper (screen shell comes in Task 8)**

Create `lib/features/organization/presentation/organization_screen.dart`:

```dart
import 'package:camp_connect/l10n/app_localizations.g.dart';

/// Maps a lowercased org-management error message (from removeMember /
/// rotateInviteCode callable failures) to a localized message. Top-level for
/// unit-testability, mirroring friendlyGuideAuthError in guide_login_screen.
String friendlyOrgError(String errorMessageLowercase, AppL10n l10n) {
  final msg = errorMessageLowercase;
  if (msg.contains('not-org-owner')) return l10n.notOrgOwner;
  if (msg.contains('network') || msg.contains('unavailable')) {
    return l10n.networkError;
  }
  return l10n.somethingWentWrong;
}
```

- [ ] **Step 4: Run the mapper test**

Run: `flutter test test/features/organization/friendly_org_error_test.dart`
Expected: PASS.

- [ ] **Step 5: Add the callable methods to the repository**

Replace the class header and constructor of `lib/features/organization/data/organization_repository.dart` and append the two methods:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../domain/organization.dart';
import '../domain/org_member.dart';

/// Reads are direct Firestore queries; all organisation WRITES happen
/// server-side (registerGuide, removeMember, rotateInviteCode callables).
class OrganizationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  OrganizationRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  Future<Organization?> getOrganization(String orgId) async {
    final doc =
        await _firestore.collection('organizations').doc(orgId).get();
    return doc.exists ? Organization.fromFirestore(doc) : null;
  }

  Stream<List<OrgMember>> watchMembers(String orgId) {
    return _firestore
        .collection('organizations')
        .doc(orgId)
        .collection('members')
        .snapshots()
        .map((snap) => snap.docs.map(OrgMember.fromFirestore).toList());
  }

  /// Owner-only (enforced server-side): removes [memberUid] from the org.
  Future<void> removeMember(String memberUid) async {
    await _functions
        .httpsCallable('removeMember')
        .call({'memberUid': memberUid});
  }

  /// Owner-only (enforced server-side): replaces the org invite code.
  /// Returns the new code.
  Future<String> rotateInviteCode() async {
    final result = await _functions.httpsCallable('rotateInviteCode').call();
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['inviteCode'] as String;
  }
}
```

- [ ] **Step 6: Verify**

Run: `flutter analyze; flutter test test/features/organization/`
Expected: no issues, tests PASS.

- [ ] **Step 7: Commit** *(ask user first)*

```bash
git add lib/features/organization/ test/features/organization/friendly_org_error_test.dart
git commit -m "feat: client plumbing for org management callables"
```

---

### Task 8: "My organisation" screen

**Files:**
- Modify: `lib/features/organization/presentation/organization_screen.dart`
- Modify: `lib/core/router/app_router.dart` (new route)
- Modify: `lib/features/settings/presentation/guide_settings_screen.dart:225-293`
- Modify: `lib/features/home/presentation/guide_home_screen.dart` (quick action)
- Test: `test/features/organization/organization_screen_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/features/organization/organization_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/features/organization/data/organization_repository.dart';
import 'package:camp_connect/features/organization/domain/organization.dart';
import 'package:camp_connect/features/organization/domain/org_member.dart';
import 'package:camp_connect/features/organization/presentation/organization_screen.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

void main() {
  const org = Organization(
    id: 'org-1',
    name: 'Camp Falcon',
    ownerUid: 'owner-1',
    inviteCode: 'ABCDEFGHJK',
  );

  final members = [
    const OrgMember(uid: 'owner-1', role: 'owner', displayName: 'Olivia Owner'),
    const OrgMember(uid: 'guide-1', role: 'guide', displayName: 'Gabi Guide'),
  ];

  AppUser user(String uid) => AppUser(
        uid: uid,
        role: 'guide',
        displayName: 'X',
        orgId: 'org-1',
        createdAt: DateTime(2026, 7, 1),
      );

  Widget buildTestable({required String uid}) {
    return ProviderScope(
      overrides: [
        organizationRepositoryProvider
            .overrideWithValue(MockOrganizationRepository()),
        appUserProvider.overrideWith((ref) => Future.value(user(uid))),
        currentOrganizationProvider.overrideWith((ref) => Future.value(org)),
        orgMembersProvider.overrideWith((ref) => Stream.value(members)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: OrganizationScreen(),
      ),
    );
  }

  testWidgets('owner sees invite code, rotate action, and remove on non-owner members',
      (tester) async {
    await tester.pumpWidget(buildTestable(uid: 'owner-1'));
    await tester.pumpAndSettle();

    expect(find.text('Camp Falcon'), findsWidgets);
    expect(find.text('ABCDEFGHJK'), findsOneWidget);
    expect(find.text('Olivia Owner'), findsOneWidget);
    expect(find.text('Gabi Guide'), findsOneWidget);
    // Rotate action present.
    final l10n = AppL10n.of(tester.element(find.byType(OrganizationScreen)));
    expect(find.text(l10n.rotateInviteCodeAction), findsOneWidget);
    // Exactly one remove button: for Gabi, not for the owner row.
    expect(find.byIcon(Icons.person_remove_outlined), findsOneWidget);
  });

  testWidgets('non-owner sees members but no invite code or owner actions',
      (tester) async {
    await tester.pumpWidget(buildTestable(uid: 'guide-1'));
    await tester.pumpAndSettle();

    expect(find.text('Olivia Owner'), findsOneWidget);
    expect(find.text('ABCDEFGHJK'), findsNothing);
    expect(find.byIcon(Icons.person_remove_outlined), findsNothing);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/organization/organization_screen_test.dart`
Expected: FAIL — `OrganizationScreen` doesn't exist.

- [ ] **Step 3: Implement the screen**

Append to `lib/features/organization/presentation/organization_screen.dart` (below the existing `friendlyOrgError`; add the imports at the top of the file):

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/features/organization/domain/org_member.dart';
import 'package:camp_connect/features/organization/domain/organization.dart';
```

```dart
class OrganizationScreen extends ConsumerWidget {
  const OrganizationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final orgAsync = ref.watch(currentOrganizationProvider);
    final membersAsync = ref.watch(orgMembersProvider);
    final uid = ref.watch(appUserProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myOrganization)),
      body: orgAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l10n.somethingWentWrong)),
        data: (org) {
          if (org == null || uid == null) {
            return Center(child: Text(l10n.somethingWentWrong));
          }
          final isOwner = org.ownerUid == uid;
          final members = membersAsync.valueOrNull ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(org.name, style: theme.textTheme.titleMedium),
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: 12),
                _InviteCodeCard(org: org),
              ],
              const SizedBox(height: 20),
              Text(l10n.members, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final member in members) ...[
                      if (member != members.first) const Divider(height: 1),
                      _MemberTile(
                        member: member,
                        isOwnerRow: member.uid == org.ownerUid,
                        canRemove: isOwner && member.uid != org.ownerUid,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InviteCodeCard extends ConsumerWidget {
  const _InviteCodeCard({required this.org});

  final Organization org;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);

    Future<void> rotate() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.rotateInviteCodeAction),
          content: Text(l10n.rotateInviteCodeConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.rotateInviteCodeAction),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      try {
        await ref.read(organizationRepositoryProvider).rotateInviteCode();
        ref.invalidate(currentOrganizationProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.codeRotated)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friendlyOrgError(e.toString().toLowerCase(), l10n)),
            ),
          );
        }
      }
    }

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.vpn_key_outlined),
            title: Text(l10n.organizationInviteCode),
            subtitle: Text(org.inviteCode),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: l10n.inviteCodeCopied,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: org.inviteCode),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.inviteCodeCopied)),
                      );
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  tooltip: l10n.share,
                  onPressed: () => Share.share(
                    l10n.shareInviteMessage(org.name, org.inviteCode),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.autorenew),
            title: Text(l10n.rotateInviteCodeAction),
            onTap: rotate,
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.member,
    required this.isOwnerRow,
    required this.canRemove,
  });

  final OrgMember member;
  final bool isOwnerRow;
  final bool canRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final theme = Theme.of(context);

    Future<void> remove() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.removeGuide),
          content: Text(l10n.removeGuideConfirm(member.displayName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.removeGuide),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      try {
        await ref
            .read(organizationRepositoryProvider)
            .removeMember(member.uid);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.memberRemoved)),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(friendlyOrgError(e.toString().toLowerCase(), l10n)),
            ),
          );
        }
      }
    }

    return ListTile(
      leading: Icon(
        isOwnerRow ? Icons.workspace_premium_outlined : Icons.person_outline,
      ),
      title: Text(member.displayName),
      subtitle: Text(
        [
          isOwnerRow ? l10n.ownerRole : l10n.guideRole,
          if (member.joinedAt != null)
            DateFormat.yMd(Localizations.localeOf(context).toString())
                .format(member.joinedAt!),
        ].join(' · '),
      ),
      trailing: canRemove
          ? IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: l10n.removeGuide,
              onPressed: remove,
            )
          : null,
    );
  }
}
```

> If `l10n.cancel` doesn't exist yet, check `app_en.arb`; the codebase has delete-confirmation dialogs (camp session delete) — reuse whatever cancel key they use, or add `"cancel": "Cancel"` / `"Anulează"` / `"Mégse"` in Task 1's files.

- [ ] **Step 4: Run the widget test**

Run: `flutter test test/features/organization/organization_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Route + entry points**

**(a)** `lib/core/router/app_router.dart` — import the screen and add next to the `/guide/camp-sessions` route:

```dart
import '../../features/organization/presentation/organization_screen.dart';
```

```dart
      GoRoute(
        path: '/guide/organization',
        builder: (context, state) => const OrganizationScreen(),
      ),
```

**(b)** `lib/features/settings/presentation/guide_settings_screen.dart` — in `_OrganizationSection`, replace the owner-only invite-code `ListTile` block (`if (isOwner) ...[ ... ]`) with a link for **all** members (needs `import 'package:go_router/go_router.dart';` if not present):

```dart
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(l10n.myOrganization),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/guide/organization'),
                  ),
```

(The `isOwner` variable becomes unused — remove it, and remove the now-unused `Clipboard` import if nothing else uses it.)

**(c)** `lib/features/home/presentation/guide_home_screen.dart` — add a fifth quick action after the `manageCodes` card:

```dart
                      _ActionCard(
                        icon: Icons.groups_outlined,
                        label: l10n.myOrganization,
                        color: theme.colorScheme.secondary,
                        onTap: () => context.push('/guide/organization'),
                      ),
```

- [ ] **Step 6: Verify**

Run: `flutter analyze; flutter test`
Expected: no issues; full suite PASS.

- [ ] **Step 7: Commit** *(ask user first)*

```bash
git add lib/features/organization/presentation/organization_screen.dart lib/core/router/app_router.dart lib/features/settings/presentation/guide_settings_screen.dart lib/features/home/presentation/guide_home_screen.dart test/features/organization/organization_screen_test.dart
git commit -m "feat: My organisation screen with member management and code rotation"
```

---### Task 9: Day-0 onboarding checklist

**Files:**
- Create: `lib/features/home/presentation/day0_checklist_card.dart`
- Modify: `lib/features/home/presentation/guide_home_screen.dart`
- Test: `test/features/home/day0_checklist_card_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/features/home/day0_checklist_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:camp_connect/features/auth/domain/app_user.dart';
import 'package:camp_connect/features/auth/domain/camp_code.dart';
import 'package:camp_connect/features/auth/domain/camp_session.dart';
import 'package:camp_connect/features/home/presentation/day0_checklist_card.dart';
import 'package:camp_connect/features/organization/domain/organization.dart';
import 'package:camp_connect/features/organization/domain/org_member.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

void main() {
  const org = Organization(
    id: 'org-1',
    name: 'Camp Falcon',
    ownerUid: 'owner-1',
    inviteCode: 'ABCDEFGHJK',
  );

  AppUser user(String uid) => AppUser(
        uid: uid,
        role: 'guide',
        displayName: 'X',
        orgId: 'org-1',
        createdAt: DateTime(2026, 7, 1),
      );

  Future<Widget> buildTestable({
    required String uid,
    List<CampSession> sessions = const [],
    List<OrgMember> members = const [
      OrgMember(uid: 'owner-1', role: 'owner', displayName: 'O'),
    ],
    List<CampCode> codes = const [],
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appUserProvider.overrideWith((ref) => Future.value(user(uid))),
        currentOrganizationProvider.overrideWith((ref) => Future.value(org)),
        guideCampSessionsProvider.overrideWith((ref) => Stream.value(sessions)),
        orgMembersProvider.overrideWith((ref) => Stream.value(members)),
        codesForActiveCampProvider.overrideWith((ref) => Stream.value(codes)),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Scaffold(body: Day0ChecklistCard()),
      ),
    );
  }

  testWidgets('owner with nothing set up sees all three steps unchecked',
      (tester) async {
    await tester.pumpWidget(await buildTestable(uid: 'owner-1'));
    await tester.pumpAndSettle();

    final l10n =
        AppL10n.of(tester.element(find.byType(Day0ChecklistCard)));
    expect(find.text(l10n.day0Title), findsOneWidget);
    expect(find.text(l10n.stepCreateSession), findsOneWidget);
    expect(find.text(l10n.stepInviteGuides), findsOneWidget);
    expect(find.text(l10n.stepGenerateCodes), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('non-owner guide sees nothing', (tester) async {
    await tester.pumpWidget(await buildTestable(
      uid: 'guide-2',
      members: const [
        OrgMember(uid: 'owner-1', role: 'owner', displayName: 'O'),
        OrgMember(uid: 'guide-2', role: 'guide', displayName: 'G'),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('card disappears when all three steps are complete',
      (tester) async {
    final session = CampSession(
      id: 'camp-1',
      name: 'Summer',
      startDate: DateTime(2026, 7, 10),
      endDate: DateTime(2026, 7, 20),
      teams: const ['red'],
      createdBy: 'owner-1',
      orgId: 'org-1',
    );
    await tester.pumpWidget(await buildTestable(
      uid: 'owner-1',
      sessions: [session],
      members: const [
        OrgMember(uid: 'owner-1', role: 'owner', displayName: 'O'),
        OrgMember(uid: 'guide-2', role: 'guide', displayName: 'G'),
      ],
      codes: const [
        CampCode(
          code: 'CAMP-0001',
          campId: 'camp-1',
          orgId: 'org-1',
          team: 'red',
          displayName: 'Kid',
          createdBy: 'owner-1',
        ),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
  });
}
```

> `CampSession`'s exact constructor lives in `lib/features/auth/domain/camp_session.dart` — check it when writing the test and adjust the named args (this plan assumes `id, name, startDate, endDate, teams, createdBy, orgId`).

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/home/day0_checklist_card_test.dart`
Expected: FAIL — `Day0ChecklistCard` doesn't exist.

- [ ] **Step 3: Implement the card**

Create `lib/features/home/presentation/day0_checklist_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// Day-0 onboarding for a fresh org owner: create a session, invite guides,
/// generate kid codes. Steps derive from live data (never persisted); the
/// card hides itself for non-owners, when everything is done, or when
/// manually dismissed (dismissal stored locally per uid).
class Day0ChecklistCard extends ConsumerStatefulWidget {
  const Day0ChecklistCard({super.key});

  @override
  ConsumerState<Day0ChecklistCard> createState() => _Day0ChecklistCardState();
}

class _Day0ChecklistCardState extends ConsumerState<Day0ChecklistCard> {
  String _dismissKey(String uid) => 'day0_dismissed_$uid';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final org = ref.watch(currentOrganizationProvider).valueOrNull;
    if (user == null || org == null || org.ownerUid != user.uid) {
      return const SizedBox.shrink();
    }

    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs.getBool(_dismissKey(user.uid)) ?? false) {
      return const SizedBox.shrink();
    }

    final sessions = ref.watch(guideCampSessionsProvider).valueOrNull ?? [];
    final members = ref.watch(orgMembersProvider).valueOrNull ?? [];
    final codes = ref.watch(codesForActiveCampProvider).valueOrNull ?? [];

    final hasSession = sessions.isNotEmpty;
    final hasGuests = members.length >= 2;
    final hasCodes = codes.isNotEmpty;
    if (hasSession && hasGuests && hasCodes) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.day0Title,
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
            _StepRow(
              done: hasSession,
              label: l10n.stepCreateSession,
              onTap: () => context.go('/guide/camp-sessions'),
            ),
            _StepRow(
              done: hasGuests,
              label: l10n.stepInviteGuides,
              onTap: () => Share.share(
                l10n.shareInviteMessage(org.name, org.inviteCode),
              ),
            ),
            _StepRow(
              done: hasCodes,
              label: l10n.stepGenerateCodes,
              onTap: () => context.go('/guide/codes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.done,
    required this.label,
    required this.onTap,
  });

  final bool done;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          decoration: done ? TextDecoration.lineThrough : null,
        ),
      ),
      trailing: done ? null : const Icon(Icons.arrow_forward_rounded, size: 18),
      onTap: done ? null : onTap,
    );
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/home/day0_checklist_card_test.dart`
Expected: PASS.

- [ ] **Step 5: Mount it on guide home**

In `lib/features/home/presentation/guide_home_screen.dart`, add the import:

```dart
import 'package:camp_connect/features/home/presentation/day0_checklist_card.dart';
```

and insert directly after the `const SizedBox(height: 24),` that follows the welcome/`guideDashboard` header (i.e. before the session overview):

```dart
                  const Day0ChecklistCard(),
                  const SizedBox(height: 16),
```

- [ ] **Step 6: Verify**

Run: `flutter analyze; flutter test`
Expected: no issues; full suite PASS.

- [ ] **Step 7: Commit** *(ask user first)*

```bash
git add lib/features/home/ test/features/home/day0_checklist_card_test.dart
git commit -m "feat: day-0 onboarding checklist for new org owners"
```

---

### Task 10: Removed-guide redirect, docs, final verification

**Files:**
- Modify: `lib/core/router/app_router.dart:54-58`
- Modify: `docs/firestore-schema.md`

- [ ] **Step 1: Redirect org-less guides out of the guide shell**

In the router `redirect` in `lib/core/router/app_router.dart`, after the kid/guide cross-access checks, add:

```dart
      // A guide with no org was removed by their owner (removeMember cleared
      // orgId). Send them to the join screen; they can re-join with a code.
      if (appUser.isGuide && appUser.orgId == null && path.startsWith('/guide')) {
        return '/join-organization';
      }
```

(`/join-organization` is built in Task 11 — execute Task 11 BEFORE this task.)

- [ ] **Step 2: Update the schema doc**

In `docs/firestore-schema.md`:
- `organizations/{orgId}` row: change writer note to `registerGuide` / `rotateInviteCode` callables only.
- `organizations/{orgId}/members/{uid}` row: add `joinedAt` to fields; add `removeMember` (owner removes a guide) to the writers alongside `registerGuide` and `deleteMyAccount`.

- [ ] **Step 3: Full verification**

Run, in order:

1. `flutter gen-l10n` — expected: clean regeneration.
2. `flutter analyze` — expected: no issues.
3. `flutter test` — expected: full suite PASS.
4. From `functions/` (emulators running): `npm test` — expected: all suites PASS.

- [ ] **Step 4: Manual smoke check (emulator or device)**

- Fresh install → role selection shows 3 tiles.
- "I'm setting up a camp" → register → lands on home with the day-0 card; all 3 steps tappable.
- Share step opens the OS share sheet with org name + code.
- "My organisation" from settings and from home quick actions; rotate code changes it; second guide registered via code appears in members; removing them boots them to role selection on their next app open.

- [ ] **Step 5: Commit** *(ask user first)*

```bash
git add lib/core/router/app_router.dart docs/firestore-schema.md
git commit -m "feat: redirect removed guides to role selection; document org management writes"
```

---

### Task 11: Re-join path for org-less guides (added during execution — review finding)

`registerGuide` only creates new Auth users, so a guide removed via `removeMember` had no way back into any org with their existing account, and Task 10's redirect would loop them between shells. This task adds the missing path. **Execute before Task 10.**

**Files:**
- Modify: `functions/lib/orgManagement.js`, `functions/test/orgManagement.test.js`, `functions/index.js`
- Create: `lib/features/organization/presentation/join_organization_screen.dart`
- Modify: `lib/features/organization/data/organization_repository.dart`, `lib/core/router/app_router.dart`
- Test: `test/features/organization/join_organization_screen_test.dart`

- [ ] **Step 1: Failing backend tests**

Append to `functions/test/orgManagement.test.js` (import `joinOrganizationHandler` from `../lib/orgManagement` at the top):

```js
// --- joinOrganization ---

// Seeds a signed-in guide with NO org (the removeMember aftermath shape).
async function seedOrglessGuide(uid = "loner-1") {
  await db.doc(`users/${uid}`).set({ role: "guide", displayName: "Loner" });
  return uid;
}

test("org-less guide joins by invite code: membership, profile orgId, claims", async () => {
  await seedOrg();
  const uid = await seedOrglessGuide();
  try {
    await authAdmin.createUser({ uid, email: `${uid}@example.com`, password: "correcthorsebattery" });
  } catch (e) {
    if (e.code !== "auth/uid-already-exists") throw e;
  }

  const result = await joinOrganizationHandler(db, authAdmin, { uid }, { inviteCode: "AAAAAAAAAA" });
  expect(result.ok).toBe(true);
  expect(result.orgId).toBe("org-1");

  const member = await db.doc(`organizations/org-1/members/${uid}`).get();
  expect(member.exists).toBe(true);
  expect(member.data().role).toBe("guide");
  expect(member.data().joinedAt).toBeTruthy();

  const profile = await db.doc(`users/${uid}`).get();
  expect(profile.data().orgId).toBe("org-1");

  const user = await authAdmin.getUser(uid);
  expect(user.customClaims.orgId).toBe("org-1");
});

test("joining with an invalid code throws permission-denied", async () => {
  await seedOrg();
  const uid = await seedOrglessGuide();
  await expect(
    joinOrganizationHandler(db, authAdmin, { uid }, { inviteCode: "NOPE" })
  ).rejects.toMatchObject({ code: "permission-denied" });
});

test("a guide already in an org cannot join another", async () => {
  await seedOrg();
  await expect(
    joinOrganizationHandler(db, authAdmin, { uid: "member-1" }, { inviteCode: "AAAAAAAAAA" })
  ).rejects.toMatchObject({ code: "failed-precondition" });
});

test("unauthenticated joinOrganization is rejected", async () => {
  await expect(
    joinOrganizationHandler(db, authAdmin, null, { inviteCode: "AAAAAAAAAA" })
  ).rejects.toMatchObject({ code: "unauthenticated" });
});
```

Run (from `functions/`): `firebase emulators:exec --only "firestore,auth" --project campconnect-orgmgmt-test "npx jest test/orgManagement.test.js --runInBand"`
Expected: new tests FAIL (`joinOrganizationHandler` is not a function).

- [ ] **Step 2: Implement the handler**

In `functions/lib/orgManagement.js` add (and export):

```js
/**
 * joinOrganizationHandler(db, authAdmin, auth, data)
 *
 * Lets a signed-in guide who belongs to NO organisation (e.g. after being
 * removed via removeMember) join one with its invite code. Mirrors the
 * joinOrgCode branch of registerGuide, but for an existing account.
 *
 * data: { inviteCode }
 * Throws HttpsError:
 *   unauthenticated    — no auth context
 *   invalid-argument   ("Missing inviteCode.") — no/malformed code
 *   permission-denied  ("not-a-guide") — caller has no guide profile
 *   failed-precondition ("already-in-org") — caller already belongs to an org
 *   permission-denied  ("invalid-invite-code") — code matched no org
 */
async function joinOrganizationHandler(db, authAdmin, auth, data) {
  if (!auth) throw new HttpsError("unauthenticated", "Sign in first.");
  const uid = auth.uid;

  const { inviteCode } = data || {};
  if (!inviteCode || typeof inviteCode !== "string") {
    throw new HttpsError("invalid-argument", "Missing inviteCode.");
  }

  const userSnap = await db.doc(`users/${uid}`).get();
  const user = userSnap.exists ? userSnap.data() : null;
  if (!user || user.role !== "guide") {
    throw new HttpsError("permission-denied", "not-a-guide");
  }
  if (user.orgId) {
    throw new HttpsError("failed-precondition", "already-in-org");
  }

  const match = await db.collection("organizations")
    .where("inviteCode", "==", inviteCode.trim().toUpperCase())
    .limit(1).get();
  if (match.empty) {
    throw new HttpsError("permission-denied", "invalid-invite-code");
  }
  const orgId = match.docs[0].id;

  const batch = db.batch();
  batch.set(db.doc(`organizations/${orgId}/members/${uid}`), {
    role: "guide",
    displayName: user.displayName || "",
    joinedAt: FieldValue.serverTimestamp(),
  });
  batch.update(db.doc(`users/${uid}`), { orgId: orgId });
  await batch.commit();

  await authAdmin.setCustomUserClaims(uid, { role: "guide", orgId: orgId });
  return { ok: true, orgId: orgId };
}
```

Add `joinOrganizationHandler` to `module.exports`. Run the suite again — all tests PASS.

- [ ] **Step 3: Export the callable**

In `functions/index.js` (extend the existing orgManagement require and exports block):

```js
exports.joinOrganization = onCall({ enforceAppCheck: true }, (request) =>
  joinOrganizationHandler(getFirestore(), getAuth(), request.auth, request.data)
);
```

Run the full `npm test` from `functions/` — all suites PASS.

- [ ] **Step 4: Failing widget test**

Create `test/features/organization/join_organization_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:camp_connect/features/organization/data/organization_repository.dart';
import 'package:camp_connect/features/organization/presentation/join_organization_screen.dart';
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/shared/providers/providers.dart';
import 'package:camp_connect/features/auth/data/auth_repository.dart';

class MockOrganizationRepository extends Mock
    implements OrganizationRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockOrganizationRepository orgRepository;
  late MockAuthRepository authRepository;
  String? lastLocation;

  setUp(() {
    orgRepository = MockOrganizationRepository();
    authRepository = MockAuthRepository();
    lastLocation = null;
    when(() => authRepository.authStateChanges)
        .thenAnswer((_) => const Stream.empty());
  });

  Widget buildTestable() {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const JoinOrganizationScreen(),
        ),
        GoRoute(
          path: '/guide',
          builder: (context, state) {
            lastLocation = '/guide';
            return const Scaffold(body: Text('guide-home'));
          },
        ),
        GoRoute(
          path: '/role-selection',
          builder: (context, state) {
            lastLocation = '/role-selection';
            return const Scaffold(body: Text('role-selection'));
          },
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        organizationRepositoryProvider.overrideWithValue(orgRepository),
        authRepositoryProvider.overrideWithValue(authRepository),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
      ),
    );
  }

  testWidgets('successful join navigates to guide home', (tester) async {
    when(() => orgRepository.joinOrganization(any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'ABCDEFGHJK');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    verify(() => orgRepository.joinOrganization('ABCDEFGHJK')).called(1);
    expect(lastLocation, '/guide');
  });

  testWidgets('failed join shows error and stays', (tester) async {
    when(() => orgRepository.joinOrganization(any()))
        .thenThrow(Exception('invalid-invite-code'));

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'WRONG');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final l10n =
        AppL10n.of(tester.element(find.byType(JoinOrganizationScreen)));
    expect(find.text(l10n.invalidInviteCode), findsOneWidget);
    expect(lastLocation, isNull);
  });

  testWidgets('sign out returns to role selection', (tester) async {
    when(() => authRepository.signOut()).thenAnswer((_) async {});

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    final l10n =
        AppL10n.of(tester.element(find.byType(JoinOrganizationScreen)));
    await tester.tap(find.text(l10n.signOut));
    await tester.pumpAndSettle();

    verify(() => authRepository.signOut()).called(1);
    expect(lastLocation, '/role-selection');
  });
}
```

(If `l10n.signOut` doesn't exist, check the arb files — guide settings has a sign-out action; reuse its key. Run the test: FAIL — screen doesn't exist.)

- [ ] **Step 5: Implement client**

**(a)** `lib/features/organization/data/organization_repository.dart` — add:

```dart
  /// Joins the signed-in, org-less guide to the org matching [inviteCode]
  /// (server-side validation; see joinOrganization callable).
  Future<void> joinOrganization(String inviteCode) async {
    await _functions
        .httpsCallable('joinOrganization')
        .call({'inviteCode': inviteCode});
  }
```

**(b)** Create `lib/features/organization/presentation/join_organization_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:camp_connect/features/auth/presentation/guide_login_screen.dart'
    show friendlyGuideAuthError;
import 'package:camp_connect/l10n/app_localizations.g.dart';
import 'package:camp_connect/core/l10n/localized_validators.dart';
import 'package:camp_connect/shared/providers/providers.dart';

/// Landing screen for a signed-in guide who belongs to no organisation
/// (typically after being removed by an owner). Offers exactly two exits:
/// join an org with an invite code, or sign out.
class JoinOrganizationScreen extends ConsumerStatefulWidget {
  const JoinOrganizationScreen({super.key});

  @override
  ConsumerState<JoinOrganizationScreen> createState() =>
      _JoinOrganizationScreenState();
}

class _JoinOrganizationScreenState
    extends ConsumerState<JoinOrganizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(organizationRepositoryProvider)
          .joinOrganization(_codeController.text.trim());
      ref.invalidate(appUserProvider);
      await ref.read(appUserProvider.future);
      if (mounted) context.go('/guide');
    } catch (e) {
      if (mounted) {
        final l10n = AppL10n.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(friendlyGuideAuthError(e.toString().toLowerCase(), l10n)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go('/role-selection');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final validators = LocalizedValidators(l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinYourOrg)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.group_add_outlined,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    l10n.joinYourOrg,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.guideDescription,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: l10n.organizationCode,
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.done,
                    validator: validators.required,
                    enabled: !_isLoading,
                    onFieldSubmitted: (_) => _join(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isLoading ? null : _join,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.joinOrganization),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : _signOut,
                    child: Text(l10n.signOut),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

(Reuses existing l10n keys: joinYourOrg, guideDescription, organizationCode, joinOrganization, invalidInviteCode; check `signOut` exists — guide settings uses one. If the key is named differently, use that key.)

**(c)** `lib/core/router/app_router.dart` — import the screen and add a top-level route:

```dart
      GoRoute(
        path: '/join-organization',
        builder: (context, state) => const JoinOrganizationScreen(),
      ),
```

- [ ] **Step 6: Verify**

Run the new widget test file (PASS), then `flutter analyze` and full `flutter test`.

- [ ] **Step 7: Commit** *(ask user first)*

```bash
git add functions/lib/orgManagement.js functions/test/orgManagement.test.js functions/index.js lib/features/organization/ lib/core/router/app_router.dart test/features/organization/join_organization_screen_test.dart
git commit -m "feat: joinOrganization callable + screen for org-less guides"
```

---

## Self-Review Notes (resolved inline)

- **Spec coverage:** entry flow → Task 4; mode-aware registration → Task 5; day-0 checklist → Task 9; org screen + callables → Tasks 6–8; localisation → Task 1; error handling → Tasks 7–8 (mapper) + Task 10 (redirect); testing → every task. `joinedAt` (member list "joined date" from the spec) needed a data addition → Task 2.
- **Known deliberate deviations:** none.
- **Verify-at-implementation notes:** the exact `CampSession` constructor (Task 9 test), the gen-l10n sync-lookup name (`lookupAppL10n`, Task 7 test), the existing `cancel` l10n key (Task 8), and the `share_plus` API (`Share.share` vs `SharePlus.instance.share` in newer majors — use whichever the resolved version exposes without a deprecation warning).
