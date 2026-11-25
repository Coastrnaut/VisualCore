# Data model: R02-G17-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload `{level: 1, records}` of a seeded play of level 1 with its first certified phase change applied (playing, not won), seed 7 | migrates 1 → 2 → 3; restores with level 1 and the change kept |
| Schema-2 example | schema-2 payload with campaign mode, the tutorial done, progress (frontier 2, level 1 solved with actions spent one above the certified count and its stars), the records of a fresh play | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g17.celestial-eclipse-lab.<name>` | the 41 names of clarification Q1; unique; each used once |
| Interface chunk `z3` | `CELPlayUITests`, `CELReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified plan (body 1 to phase 2, then body 2 to phase 0), the budget 9 | asserted equal to the Core by an app unit test |
