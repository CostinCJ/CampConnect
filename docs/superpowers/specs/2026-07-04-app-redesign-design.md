# CampConnect visual redesign — "Trail Adventure"

Date: 2026-07-04 · Status: approved direction (user picked A of three mocked options)

## Goal

Replace the stock Material 3 seeded-green look with a custom, modern, camp-flavored design system. Visual-only: no navigation, data, or behavioral changes; all existing tests keep passing; RO/HU localization and GDPR flows untouched.

## Scope

- `lib/core/theme/app_theme.dart` — rebuilt token + component theme system (light "daylight trail" + dark "campfire night"). See `DESIGN.md` for tokens.
- `pubspec.yaml` + `assets/fonts/` — bundle Nunito 400/600/700/800 (offline-safe; Latin-Ext covers ș ț ă ő ű). Existing NotoSans assets stay (PDF export uses them).
- `lib/shared/widgets/` — new shared widgets: `SectionHeader`, `EmptyState`, `StatPill`, plus restyled nav shells.
- Kid screens: home (hero team card), leaderboard (podium feel via team colors), journal, announcements, map chrome, settings.
- Guide screens: home, management lists (denser, calmer), emergency (red reserved here), settings, auth flow (splash, role selection, logins).

## Non-goals

- No new dependencies (fonts bundled as assets, not google_fonts).
- No route/tab restructuring (guide bar keeps 7 tabs).
- No copy changes beyond what l10n already provides.
- No LLM/map data changes.

## Verification

`flutter analyze` clean, `flutter test` green, debug build compiles. Manual visual pass via existing widget tests' goldens if any (none currently — rely on analyze/tests + code review).

## Risks

- Widget tests that assert on colors/finders: fix tests only where they assert stock-theme specifics.
- 7-tab guide NavigationBar is cramped by design; restyle only (out of scope to restructure).
