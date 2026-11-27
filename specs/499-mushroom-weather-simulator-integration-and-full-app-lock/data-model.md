# Data model: R02-G20-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload `{level: 1, records}` of a seeded play of level 1 with one non-winning pod placed (playing, not won), seed 7 | migrates 1 → 2 → 3; restores with level 1 and the pod kept |
| Schema-2 example | schema-2 payload with campaign mode, the tutorial done, progress (frontier 2, level 1 solved with actions spent one above the certified count and its stars), the records of a fresh play | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g20.mushroom-weather.<name>` | the names of clarification Q1 (`MushroomWeatherControls.identifierNames`); unique; each used once |
| Interface chunk `c4` | `MWPlayUITests`, `MWReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified plan (a pod at row 2, column 5 in slot 0, vent 0 closed; then the run) and the budget | asserted equal to the Core by an app unit test |
