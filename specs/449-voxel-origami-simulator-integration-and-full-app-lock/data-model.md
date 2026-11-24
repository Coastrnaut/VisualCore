# Data model: R02-G15-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload `{level: 1, records}` of a seeded play of level 1 with its first certified turn applied (playing, not won), seed 7 | migrates 1 → 2 → 3; restores with level 1 and the turn kept |
| Schema-2 example | schema-2 payload with campaign mode, the tutorial done, progress (frontier 2, level 1 solved with actions spent one above the certified count and its stars), records [] | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g15.voxel-origami.<name>` | the 35 names of clarification Q1; unique; each used once |
| Interface chunk `x3` | `VOPlayUITests`, `VOReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified turns (hinge 4 by −1, twice), the budget 9 | asserted equal to the Core by an app unit test |
