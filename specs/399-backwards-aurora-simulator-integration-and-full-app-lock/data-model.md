# Data model: R02-G10-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload of a seeded play of level 1 with one reversal that does not win, seed 7 | migrates 1 → 2 → 3; restores with level 1 and the reversal kept |
| Schema-2 example | schema-2 payload with campaign mode, progress {frontier 2, solved [level 1, reversals made, stars]}, tutorial | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g10.backwards-aurora.<name>` | names of clarification Q1; unique |
| Interface chunk `s3` | `BAPlayUITests`, `BAReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified reversals (start, end), the steppers' starting section, the smallest reversal count | asserted equal to the Core by an app unit test |
