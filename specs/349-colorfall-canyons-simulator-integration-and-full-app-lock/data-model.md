# Data model: R02-G05-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload of a seeded play of level 1 with one carve that does not win, seed 7 | migrates 1 → 2 → 3; restores with level 1 and the carve kept |
| Schema-2 example | schema-2 payload with campaign mode, progress {frontier 2, solved [level 1, best units, stars]}, tutorial | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g05.colorfall-canyons.<name>` | names of clarification Q1; unique |
| Interface chunk `n3` | `CCPlayUITests`, `CCReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified actions (carves, valves, steps), carvable-cell order at the start, smallest | asserted equal to the Core by an app unit test |
