# Data model: R02-G03-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload of a seeded play of level 1 with one move, seed 7 | migrates 1 → 2 → 3; restores with level 1 and the move kept |
| Schema-2 example | schema-2 payload with campaign mode, progress {frontier 2, solved [level 1, best moves, stars]}, tutorial | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g03.wave-knot-keeper.<name>` | names of clarification Q1; unique |
| Interface chunk `l3` | `WKPlayUITests`, `WKReplayUITests` | serial; each test under 90 s |
| Level 1 constants | point count, certified solution moves (point, direction index); allowance; shortest | asserted equal to the Core by an app unit test |
