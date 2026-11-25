# Data model: R02-G16-06

| Entity | Fields | Rules |
|---|---|---|
| `StarlitCartoucheFeedbackPlan` | text, kind, haptic | from the old and new core; a leg that ends the level plans only its outcome; refusals in words |
| `StarlitCartoucheLights` | glow (0.7 playing, 1 won, 0.35 failed), won (1 won, else 0) | linear easing 0.15 s / 0.45 s under Reduce Flashing; a started fade finishes before turning back |
| Audition recipe (`StarlitCartoucheAudition`) | partials (`StarlitCartouchePartial`: frequency, gain), 0.6 s decay | star j's tone 220 Hz × 2^(j / 12), gain 0.04; with its fifth when a corridor joins it to the ship's star, with a partial 3 Hz above when none does |
| Ambient recipe | root step 0 … 3, partials, loop length | root by actions-left share; one partial per quarter of the symbol drawn (≤ 4); octave when won, halved gains when failed |
