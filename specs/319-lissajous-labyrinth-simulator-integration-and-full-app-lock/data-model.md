# Data model: R02-G02-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload of a seeded play of level 1 with one action, seed 7 | migrates 1 → 2 → 3; restores with level 1 and the action kept |
| Schema-2 example | schema-2 payload with campaign mode, progress {frontier 2, solved [level 1, best actions, stars]}, tutorial | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g02.lissajous-labyrinth.<name>` | names of clarification Q1; unique |
| Interface chunk `k3` | `LLPlayUITests`, `LLReplayUITests` | serial; each test under 90 s |
| Level 1 constants | start and final value of frequency a, frequency b, phase a, phase c; allowance; shortest | asserted equal to the Core by an app unit test |
