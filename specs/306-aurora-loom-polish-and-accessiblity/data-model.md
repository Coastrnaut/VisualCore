# Data model: R02-G01-06

| Entity | Fields | Rules |
|---|---|---|
| `AuroraLoomFeedbackPlan` | announcement (text, kind)?, haptic kind? | pure from (old, new) cores or a refusal; outcome replaces the move's selection |
| `AuroraLoomLights` | 12 crossing levels 0…1, win glow 0…1, duration | eases toward targets; 0.15 s, 0.45 s under Reduce Flashing |
| `AuroraLoomSoundRecipe` | steps, stage → `AmbientLoopRecipe` | pure; equal input equal recipe |
| Feedback log (presenter) | entries (text?, kind?, haptic?) in routing order | tests and diagnostics; presentation only; the shared route keeps the timing and rate limits |
| Sound choice (presenter) | on/off, default off | not state; saving is R02-G01-07 |
