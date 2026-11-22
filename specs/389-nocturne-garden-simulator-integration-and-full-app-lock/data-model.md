# Data model: R02-G09-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload of a seeded play of level 1 with one plant that does not win, seed 7 | migrates 1 → 2 → 3; restores with level 1 and the plant kept |
| Schema-2 example | schema-2 payload with campaign mode, progress {frontier 2, solved [level 1, moves made, stars]}, tutorial | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g09.nocturne-garden.<name>` | names of clarification Q1; unique |
| Interface chunk `r3` | `NGPlayUITests`, `NGReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified moves (plants and sun moves), the pickers' starting picks, the smallest move count | asserted equal to the Core by an app unit test |
