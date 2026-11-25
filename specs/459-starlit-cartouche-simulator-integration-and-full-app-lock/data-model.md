# Data model: R02-G16-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload `{level: 1, records}` of a seeded play of level 1 with its first certified leg applied (playing, not won), seed 7 | migrates 1 → 2 → 3; restores with level 1 and the leg kept |
| Schema-2 example | schema-2 payload with campaign mode, the tutorial done, progress (frontier 2, level 1 solved with actions spent one above the certified count and its stars), records [] | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g16.starlit-cartouche.<name>` | the 37 names of clarification Q1; unique; each used once |
| Interface chunk `y3` | `SCPlayUITests`, `SCReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified legs (to star 4 after 1 beat, then to star 5 after 0 beats), the budget 9 | asserted equal to the Core by an app unit test |
