# Data model: R02-G12-06

| Entity | Fields | Rules |
|---|---|---|
| `HarmonicBridgesFeedbackPlan` | text, kind, haptic | from the old and new core; a test plans only its outcome; refusals in words |
| `HarmonicBridgesLights` | glow (0.7 playing, 1 won, 0.35 failed), won (1 won, else 0) | linear easing 0.15 s / 0.45 s under Reduce Flashing; a started fade finishes before turning back |
| Audition recipe (`HarmonicBridgesAudition`) | partials (`HarmonicBridgesPartial`: frequency, gain), 0.6 s decay | fundamental 110 Hz × 2^((peg − 1) / 12); one partial per resonant mode; muted pluck without modes |
| Ambient recipe | root step 0 … 3, partials, loop length | root by actions-left share; one partial per step reached (≤ 4); octave when won, halved gains when failed |
