# Data model: R02-G19-06

| Entity | Fields | Rules |
|---|---|---|
| `MicroscopicAuroraFeedbackPlan` | text, kind, haptic | from the old and new core; the play plans only its outcome; refusals in words |
| `MicroscopicAuroraLights` | glow (0.7 playing, 1 won, 0.35 failed), won (1 won, else 0) | linear easing 0.15 s / 0.45 s under Reduce Flashing; a started fade finishes before turning back |
| Audition recipe (`MicroscopicAuroraAudition`) | partials (`MicroscopicAuroraPartial`: frequency, gain), 0.6 s decay | tone 220 Hz × 2^(n / 12), n = 3 × (strength − 1), gain 0.04; with × 3/2 (clockwise) or × 4/3 (counterclockwise) when the well can be placed, with a partial 3 Hz above when it cannot |
| Ambient recipe | root step 0 … 3, partials, loop length | root by actions-left share; one partial per quarter of the needed cells lit (≤ 4); octave when won, halved gains when failed |
