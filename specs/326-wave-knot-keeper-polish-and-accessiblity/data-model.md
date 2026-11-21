# Data model: R02-G03-06 (presentation only; no stored state)

| Entity | Fields | Rules |
|---|---|---|
| `WaveKnotKeeperFeedbackPlan` | text?, kind? (`AnnouncementKind`), haptic? (`HapticKind`) | pure function of old core, new core or a refusal code; outcome replaces selection |
| `WaveKnotKeeperLights` | crossings [key (first, second): level 0 … 1, over segment, fraction], match 0 … 1, glow 0 … 1, reducedFlash | linear easing 0.15 s / 0.45 s; under Reduce Flashing a started fade completes before reversing; a level at 0 with target 0 is dropped |
| `WaveKnotKeeperSoundRecipe` | → `AmbientLoopRecipe` (partials, 8 s) | pure function of summary, target and stage |
| `WaveKnotKeeperSound` (iOS) | wanted, onScreen, active, player? | plays exactly while wanted ∧ onScreen ∧ active; no player while unwanted |
| Feedback log (iOS) | [(text?, kind?, haptic?, trigger)] | appended for every routed plan |
