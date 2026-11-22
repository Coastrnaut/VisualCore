# Data model: R02-G06-06

| Entity | Fields | Rules |
|---|---|---|
| `ChronoConstellatorFeedbackPlan` | text?, kind? (`AnnouncementKind`), haptic? (`HapticKind`) | pure function of old and new core or a refusal code; texts of clarification Q1; haptics of Q2 |
| `ChronoConstellatorLights` | rings [Double], nodes [Double], win glow, collision mark | ease toward targets (ring 1 lit / 0.5; node 1 on target / 0.7; glow and mark 0 or 1) over 0.15 s, 0.45 s under Reduce Flashing; no reversal mid-fade under Reduce Flashing |
| `ChronoConstellatorSoundRecipe` | partials, loop length 12 s | root 110 Hz; one partial per star on target; octave when won; halved gains when failed |
| Feedback log (presenter) | trigger, kind, text, haptic | presentation only; for tests and diagnostics |
