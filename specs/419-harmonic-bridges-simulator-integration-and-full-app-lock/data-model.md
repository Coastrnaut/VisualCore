# Data model: R02-G12-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload `{level: 1, records}` of a seeded play of level 1 with its one certified tuning applied (playing, not won), seed 7 | migrates 1 → 2 → 3; restores with level 1 and the tuning kept |
| Schema-2 example | schema-2 payload with campaign mode, progress (level 2 open, level 1 solved with its actions spent and stars), records [] | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g12.harmonic-bridges.<name>` | the 30 names of clarification Q1; unique; each used once |
| Interface chunk `u3` | `HBPlayUITests`, `HBReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified actions (tune string 0 to peg 12, test), the opening choice (string 0, peg 11), the budget 9 | asserted equal to the Core by an app unit test |
