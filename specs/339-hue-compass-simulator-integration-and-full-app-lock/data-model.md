# Data model: R02-G04-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload of a seeded play of level 1 with one turn that does not win, seed 7 | migrates 1 → 2 → 3; restores with level 1 and the turn kept |
| Schema-2 example | schema-2 payload with campaign mode, progress {frontier 2, solved [level 1, best units, stars]}, tutorial | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g04.hue-compass.<name>` | names of clarification Q1; unique |
| Interface chunk `m3` | `HCPlayUITests`, `HCReplayUITests` | serial; each test under 90 s |
| Level 1 constants | start bearing, target, target band, allowance, certified witness actions (turns, probes, selection), smallest | asserted equal to the Core by an app unit test |
