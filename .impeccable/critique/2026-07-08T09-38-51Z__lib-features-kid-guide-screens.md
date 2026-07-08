---
target: kid + guide screens (lib/features)
total_score: 25
p0_count: 0
p1_count: 4
timestamp: 2026-07-08T09-38-51Z
slug: lib-features-kid-guide-screens
---
# Design Critique — CampConnect kid & guide screens (25 screens)

⚠️ DEGRADED: single-context (harness policy blocks unsolicited subagent spawning; A then B ran sequentially). Detector: 0 findings on lib/ — Dart not scannable, treat as no-signal. No browser visualization (Flutter mobile, no web build).

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3 | Map marker load failure silent; export screen says "PDF exported" while still saving |
| 2 | Match System / Real World | 3 | `CAMP-XXXX` hint on kid login can mismatch orgs with custom code prefixes |
| 3 | User Control and Freedom | 2 | No unsaved-changes guard in journal editor; tapping a session card silently switches the active camp |
| 4 | Consistency and Standards | 2 | Kid screens use EmptyState widget, guide screens hand-roll; retry buttons inconsistent |
| 5 | Error Prevention | 3 | Destructive confirms everywhere; lat/lng free-text silently falls back to defaults; create-session double-tap risk |
| 6 | Recognition Rather Than Recall | 3 | Teams management buried in Settings, invisible from leaderboard |
| 7 | Flexibility and Efficiency | 2 | Templates + Day-0 checklist good; codes can't be copied/shared; no quick point amounts |
| 8 | Aesthetic and Minimalist Design | 3 | Committed palette holds; kid home under-uses prime real estate |
| 9 | Error Recovery | 2 | Generic "Something went wrong" dominates outside auth flows |
| 10 | Help and Documentation | 2 | Day-0 checklist + inline hints only |
| **Total** | | **25/40** | **Acceptable** |

## Anti-Patterns Verdict

Not AI-slop. "Trail Adventure" system is real and consistently applied (team-color-only accent, red reserved for emergency, hero card discipline, undo-window photo delete). Weaknesses are workflow gaps and polish inconsistency, not slop. Deterministic scan: 0 findings / 0 scannable files.

## Priority Issues

**[P1] Kid map fails silently + violates sunlight-first principle** — lib/features/map/presentation/map_screen.dart:119
Error branch renders empty MarkerLayer (blank map, no explanation); no empty state for sessions with no locations; markers are bare 36px icons over tiles (no pin backing/halo — low contrast at noon); filter chips ~34dp < 48dp kid touch-target minimum.
Fix: white circular marker backing + shadow; error banner with retry; friendly empty hint; chips to 48dp.

**[P1] Journal editor loses kid's writing with no warning** — lib/features/journal/presentation/journal_editor_screen.dart:315
System back discards title/body and actively deletes newly added photos (orphan cleanup). Fix: PopScope + Keep writing / Discard dialog when dirty (or draft autosave).

**[P1] Codes can be generated but not distributed** — lib/features/auth/presentation/code_management_screen.dart:160
Codes are non-interactive ListTiles: no copy, no share, no export. Guide must transcribe/read aloud. Fix: tap-to-copy + per-team "share unused codes" share-sheet; QR as deluxe.

**[P1] Kid home never says what's happening** — lib/features/home/presentation/kid_home_screen.dart:137
Home shows identity + static stats; schedule/announcements two taps away. Fix: "Up next" card from schedule data + latest pinned announcement; make stat cards tappable (points/rank → leaderboard, entries → journal).

**[P2] Session cards switch active session on tap** — lib/features/auth/presentation/camp_session_screen.dart:88
Tap = view-details gesture but re-points app + FCM topics at another camp with no affordance. Fix: explicit "Set active" affordance or confirm when switching away from in-progress session. Also: create-session button lacks loading state (double-tap → duplicate camps).

## Persona Red Flags

**Casey (distracted guide, one-handed):** +5 points = 6 interactions; add quick-amount chips. Team selector tiles are GestureDetectors — no ripple feedback, no button semantics. No offline/queue indicator anywhere despite trail context.

**Jordan (first-time kid, 8):** CAMP-XXXX hint mismatches custom org prefixes at first step; filter chips too small for small fingers; Program tab lands at day 1 with no "today" anchor/highlight.

**Hungarian locale:** 6 nav destinations with always-shown labels — long hu strings risk truncation; export banner hardcodes "Downloads/" path fragment.

## Minor Observations

- Export screen shows "PDF exported" during saving (journal_export_screen.dart:137); share button tooltip says "Export PDF"; auto-writes to Downloads on open (side effect before user action).
- Sheet submit buttons reuse sheet titles ("New announcement" as the post button) — should be verbs (announcement_management_screen.dart:527).
- Lat/lng inputs unvalidated; garbage silently becomes default camp coords (location_form_screen.dart:158); "pick on map" would remove the field.
- Kid home error state has no retry (leaderboard's does); guide empty states hand-roll instead of EmptyState widget.
- Emergency ack count has no denominator ("3" vs "3 of 7 guides").
- Journal FAB uses pencil for "new"; + is convention.
- Create-session color dots are 28px tap targets (camp_session_screen.dart:569).
- Code generation silently caps count at max.
- Kid shell doesn't mount EmergencyAlertListener — kids never see the overlay; confirm intent.

## Questions to Consider

- What would kid home look like if it answered "what's happening right now?" first?
- Should "active session" be a mode consciously entered, not a tap side effect?
- If a guide had 10 seconds of signal per hour, which actions must still feel trustworthy?
