# Data model: R02-G20-06

| Entity | Fields | Rules |
|---|---|---|
| `MushroomWeatherFeedbackPlan` | text, kind, haptic | from the old and new core; the run plans only its outcome; refusals in words |
| `MushroomWeatherLights` | glow (0.7 playing, 1 won, 0.35 failed), won (1 won, else 0) | linear easing 0.15 s / 0.45 s under Reduce Flashing; a started fade finishes before turning back |
| Audition recipe (`MushroomWeatherAudition`) | partials (`MushroomWeatherPartial`: frequency, gain), 0.6 s decay | tone 220 Hz × 2^(n / 12), n = 2 × site index, gain 0.04; with × 3/2 when a pod can go there, with a partial 3 Hz above when not |
| Ambient recipe | root step 0 … 3, partials, loop length | root by actions-left share; one partial per quarter of the colonies staying in band (≤ 4); a moonlight partial at root × 3 with gain × moonlight / 3; octave when won, halved gains when failed |
