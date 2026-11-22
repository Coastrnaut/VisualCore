# Data model: R02-G07-06

| Entity | Fields | Rules |
|---|---|---|
| `AmethystEscapeFeedbackPlan` | text?, kind? (`AnnouncementKind`), haptic? (`HapticKind`) | pure function of old and new core or a refusal code; texts of clarification Q1; haptics of Q2 |
| `AmethystEscapeLights` | pearl, exit, wedge | ease toward targets (pearl 1 playing / 0.6 failed; exit 0.5 / 1 won; wedge 0 / 1 failed in a wedge) over 0.15 s, 0.45 s under Reduce Flashing; no reversal mid-fade under Reduce Flashing |
| `AmethystEscapeSoundRecipe` | partials, loop length 12 s | root 98 Hz; one partial per shell passed; octave when won; halved gains when failed |
| Feedback log (presenter) | trigger, kind, text, haptic | presentation only; for tests and diagnostics |
