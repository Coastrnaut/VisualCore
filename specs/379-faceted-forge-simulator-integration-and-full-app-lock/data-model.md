# Data model: R02-G08-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload of a seeded play of level 1 with one cut that does not win, seed 7 | migrates 1 → 2 → 3; restores with level 1 and the cut kept |
| Schema-2 example | schema-2 payload with campaign mode, progress {frontier 2, solved [level 1, cuts made, stars]}, tutorial | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g08.faceted-forge.<name>` | names of clarification Q1; unique |
| Interface chunk `q3` | `FFPlayUITests`, `FFReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified cuts (piece, direction, depth), the pickers' starting choice, the smallest cut count | asserted equal to the Core by an app unit test |
