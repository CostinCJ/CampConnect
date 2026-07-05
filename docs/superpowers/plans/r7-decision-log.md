# R7 Decision Log

## Accessibility semantics — scope of this phase

The verify-team design review found a systemic absence of `Semantics`/accessibility labels across
`lib/features/{emergency,leaderboard,map,journal,auth,announcements}` and `lib/shared/widgets`.
This phase closes the map markers (R7 Task 2) and the two color-only team indicators named
explicitly in the review (this task). A full pass over every icon-only `IconButton` and custom-
drawn widget in the app is real, proportionate follow-up work — **not done in this phase** — and
should be scheduled as its own dedicated task before or shortly after the first store submission,
scoped screen-by-screen rather than attempted all at once.
