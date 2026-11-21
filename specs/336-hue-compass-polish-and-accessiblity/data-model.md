# Data model: R02-G04-06 (presentation only; no stored state)

| Entity | Fields | Rules |
|---|---|---|
| `HueCompassFeedbackPlan` | text?, kind? (`AnnouncementKind`), haptic? (`HapticKind`) | pure function of old core, new core, a band pick or a refusal code; outcome replaces selection; `summaryText(core:)` gives the summary element's words |
| `HueCompassLights` | probes [bearing: level 0 … 1], selection (level, bearing), ring (level, bearing), glow 0 … 1, reducedFlash | linear easing 0.15 s / 0.45 s; under Reduce Flashing a started fade completes before reversing; a probe level at 0 with target 0 is dropped |
| `HueCompassSoundRecipe` | → `AmbientLoopRecipe` (partials, 8 s) | pure function of the last clue (or none) and the stage |
| `HueCompassSound` (iOS) | wanted, onScreen, active, player? | plays exactly while wanted ∧ onScreen ∧ active; no player while unwanted |
| Feedback log (iOS) | [(text?, kind?, haptic?, trigger)] | appended for every routed plan |
