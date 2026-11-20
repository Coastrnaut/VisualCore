# Data model: R02-G01-06

| Entity | Fields | Rules |
|---|---|---|
| `AuroraLoomFeedbackPlan` | announcement (text, kind)?, haptic kind? | pure from (old, new) cores or a refusal; outcome replaces the move's selection |
| `AuroraLoomLights` | 12 crossing levels 0…1, win glow 0…1, duration | eases toward targets; 0.15 s, 0.45 s under Reduce Flashing |
| `AuroraLoomSoundRecipe` | steps, stage → `AmbientLoopRecipe` | pure; equal input equal recipe |
| Feedback log (presenter) | entries (time, text?, kind?, haptic?) | tests and diagnostics; presentation only |
| Sound choice (presenter) | on/off, default off | not state; saving is R02-G01-07 |
