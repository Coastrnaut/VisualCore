# Data model: R02-G02-06

| Entity | Fields | Rules |
|---|---|---|
| `LissajousLabyrinthFeedbackPlan` | text?, kind?, haptic? | `after(old:new:)` per clarification Q1/Q2; `refused(code:)` → rejection + error; `none` when nothing changed |
| `LissajousLabyrinthLights` | checkpoints [0…1], obstacles [0…1], glow 0…1, reducedFlash | targets: checkpoint dim 0 / next 0.5 / visited 1; obstacle 0 / touched 1; glow 1 when won; 0.15 s or 0.45 s linear; a started fade completes under Reduce Flashing |
| `LissajousLabyrinthSoundRecipe` | `recipe(dials:stage:)` → `AmbientLoopRecipe` | 110 Hz × a, 110 Hz × b, a fifth above the lower; gains 0.6 … 1.0 of a base by phase; won adds an octave; failed halves gains; 8 s |
| Presenter feedback log | text, kind, haptic per routed plan | tests and diagnostics; not state |
