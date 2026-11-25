# Data model: R02-G17-06

| Entity | Fields | Rules |
|---|---|---|
| `CelestialEclipseLabFeedbackPlan` | text, kind, haptic | from the old and new core; the run plans only its outcome; refusals in words |
| `CelestialEclipseLabLights` | glow (0.7 playing, 1 won, 0.35 failed), won (1 won, else 0) | linear easing 0.15 s / 0.45 s under Reduce Flashing; a started fade finishes before turning back |
| Audition recipe (`CelestialEclipseLabAudition`) | partials (`CelestialEclipseLabPartial`: frequency, gain), 0.6 s decay | body j's tone 220 Hz × 2^(2j / 12), gain 0.04; with its fifth when it takes part in a predicted eclipse, with a partial 3 Hz above when it does not |
| Ambient recipe | root step 0 … 3, partials, loop length | root by actions-left share; one partial per quarter of the target matched (≤ 4); octave when won, halved gains when failed |
