# Data model: R02-G19-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload `{level: 1, records}` of a seeded play of level 1 with one non-winning well placed (playing, not won), seed 7 | migrates 1 → 2 → 3; restores with level 1 and the well kept |
| Schema-2 example | schema-2 payload with campaign mode, the tutorial done, progress (frontier 2, level 1 solved with actions spent one above the certified count and its stars), the records of a fresh play | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g19.microscopic-aurora.<name>` | the 48 names of clarification Q1; unique; each used once |
| Interface chunk `b4` | `MAPlayUITests`, `MAReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified plan (the wells of `certifiedActions(1)`: slot, site, strength, sense; then the play) and the budget | asserted equal to the Core by an app unit test |
