# Data model: R02-G10-06

| Entity | Fields | Rules |
|---|---|---|
| `BackwardsAuroraFeedbackPlan` | text?, kind? (state, outcome, level, rejection), haptic? | pure function of old and new core or a refusal code; texts of clarification Q1 |
| `BackwardsAuroraLights` | glow (0.35 … 1), won (0 … 1), tear (0 … 1), preview (0 … 1) | targets glow 0.7 playing, 1 won, 0.35 failed; won 1 once won; tear 1 on a tear failure; preview 1 while a preview shows; 0.15 s or 0.45 s linear fades; under Reduce Flashing a started fade finishes before turning back |
| `BackwardsAuroraSoundRecipe` | partials (frequency, gain), loop length | root 110 Hz × bend ratio; up to four checkpoint partials; octave when won; halved when failed |
| Feedback log | announcement kind and text, haptic kind, trigger | presentation only, for tests and diagnostics |
