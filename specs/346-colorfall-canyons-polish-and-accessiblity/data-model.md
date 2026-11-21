# Data model: R02-G05-06 (presentation only; no stored state)

| Entity | Fields | Rules |
|---|---|---|
| `ColorfallCanyonsFeedbackPlan` | text?, kind? (`AnnouncementKind`), haptic? (`HapticKind`) | pure function of old core, new core, a cell pick or a refusal code; outcome replaces selection; `summaryText(core:)` gives the summary element's words |
| `ColorfallCanyonsLights` | sheets [cell: (level 0 … 1, weights)], emitters [level], glow 0 … 1, reducedFlash | linear easing 0.15 s / 0.45 s; under Reduce Flashing a started fade completes before reversing; a sheet at 0 with target 0 is dropped |
| `ColorfallCanyonsSoundRecipe` | → `AmbientLoopRecipe` (partials, 10 s) | pure function of the basins' colour masses and the stage |
| `ColorfallCanyonsSound` (iOS) | wanted, onScreen, active, player? | plays exactly while wanted ∧ onScreen ∧ active; no player while unwanted |
| Feedback log (iOS) | [(text?, kind?, haptic?, trigger)] | appended for every routed plan |
