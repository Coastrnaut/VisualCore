# Data model: R02-G18-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload `{level: 1, records}` of a seeded play of level 1 with one non-winning tuning applied (playing, not won), seed 7 | migrates 1 → 2 → 3; restores with level 1 and the tuning kept |
| Schema-2 example | schema-2 payload with campaign mode, the tutorial done, progress (frontier 2, level 1 solved with actions spent one above the certified count and its stars), the records of a fresh play | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g18.apsides-workshop.<name>` | the 46 names of clarification Q1; unique; each used once |
| Interface chunk `a4` | `AWPlayUITests`, `AWReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified plan (periapsis to eccentricity 0, direction 0) from size 18, eccentricity 10, direction 6, the budget 9 | asserted equal to the Core by an app unit test |
