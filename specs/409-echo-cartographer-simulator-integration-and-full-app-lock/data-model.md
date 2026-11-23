# Data model: R02-G11-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload of a seeded play of level 1 with one pulse that does not win, seed 7 | migrates 1 → 2 → 3; restores with level 1 and the pulse kept |
| Schema-2 example | schema-2 payload with campaign mode, progress {frontier 2, solved [level 1, energy spent, stars]}, tutorial | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g11.echo-cartographer.<name>` | names of clarification Q1; unique |
| Interface chunk `t3` | `ECGPlayUITests`, `ECGReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified actions (pulse or claim, column, row), the cursor's starting cell, the chamber size | asserted equal to the Core by an app unit test |
