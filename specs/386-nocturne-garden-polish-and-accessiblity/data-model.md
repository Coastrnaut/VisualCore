# Data model: R02-G09-06

| Entity | Fields | Rules |
|---|---|---|
| `NocturneGardenFeedbackPlan` | text?, kind? (state, outcome, level, rejection), haptic? | pure function of old and new core or a refusal code; texts of clarification Q1 |
| `NocturneGardenLights` | glow (0.35 … 1), leak (0 … 1) | targets 0.7 playing, 1 won, 0.35 failed; leak 1 on a leak failure; 0.15 s or 0.45 s linear fades |
| `NocturneGardenSoundRecipe` | partials (frequency, gain), loop length | root 110 Hz × sun ratio; up to four bloom partials; octave when won; halved when failed |
| Feedback log | announcement kind and text, haptic kind, trigger | presentation only, for tests and diagnostics |
