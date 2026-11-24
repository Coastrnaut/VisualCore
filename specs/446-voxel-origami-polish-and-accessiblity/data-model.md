# Data model: R02-G15-06

| Entity | Fields | Rules |
|---|---|---|
| `VoxelOrigamiFeedbackPlan` | text, kind, haptic | from the old and new core; a turn that ends the level plans only its outcome; refusals in words |
| `VoxelOrigamiLights` | glow (0.7 playing, 1 won, 0.35 failed), won (1 won, else 0) | linear easing 0.15 s / 0.45 s under Reduce Flashing; a started fade finishes before turning back |
| Audition recipe (`VoxelOrigamiAudition`) | partials (`VoxelOrigamiPartial`: frequency, gain), 0.6 s decay | hinge h's tone 220 Hz × 2^((h − 1) / 12), gain 0.04; with its fifth when it can turn, with a partial 3 Hz above when it swings nothing |
| Ambient recipe | root step 0 … 3, partials, loop length | root by actions-left share; one partial per quarter of the cubes in place (≤ 4); octave when won, halved gains when failed |
