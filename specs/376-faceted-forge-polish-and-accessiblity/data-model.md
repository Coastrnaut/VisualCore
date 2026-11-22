# Data model: R02-G08-06

| Entity | Fields | Rules |
|---|---|---|
| `FacetedForgeFeedbackPlan` | text?, kind? (`AnnouncementKind`), haptic? (`HapticKind`) | pure function of old and new core or a refusal code; texts of clarification Q1; haptics of Q2 |
| `FacetedForgeLights` | glow, sliver | ease toward targets (glow 0.7 playing / 1 won / 0.35 failed; sliver 0 / 1 while the failure is a sliver) over 0.15 s, 0.45 s under Reduce Flashing; no reversal mid-fade under Reduce Flashing |
| `FacetedForgeSoundRecipe` | partials, loop length 12 s | root 110 Hz; one partial per piece beyond the first (up to four); octave when won; halved gains when failed |
| Feedback log (presenter) | trigger, kind, text, haptic | presentation only; for tests and diagnostics |
