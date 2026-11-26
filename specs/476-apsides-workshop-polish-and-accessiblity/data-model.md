# Data model: R02-G18-06

| Entity | Fields | Rules |
|---|---|---|
| `ApsidesWorkshopFeedbackPlan` | text, kind, haptic | from the old and new core; the play plans only its outcome; refusals in words |
| `ApsidesWorkshopLights` | glow (0.7 playing, 1 won, 0.35 failed), won (1 won, else 0) | linear easing 0.15 s / 0.45 s under Reduce Flashing; a started fade finishes before turning back |
| Audition recipe (`ApsidesWorkshopAudition`) | partials (`ApsidesWorkshopPartial`: frequency, gain), 0.6 s decay | tone 220 Hz × 2^(n / 12), n = (48 − a) / 4 rounded down, gain 0.04; with × 3/2 (k ≤ 7) or × 4/3 (k ≥ 8) when the orbit can be set, with a partial 3 Hz above when it cannot |
| Ambient recipe | root step 0 … 3, partials, loop length | root by actions-left share; one partial per quarter of the targets met (≤ 4); octave when won, halved gains when failed |
