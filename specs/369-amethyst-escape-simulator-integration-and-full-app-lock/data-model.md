# Data model: R02-G07-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload of a seeded play of level 1 with one turn that does not win, seed 7 | migrates 1 → 2 → 3; restores with level 1 and the turn kept |
| Schema-2 example | schema-2 payload with campaign mode, progress {frontier 2, solved [level 1, best moves, stars]}, tutorial | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g07.amethyst-escape.<name>` | names of clarification Q1; unique |
| Interface chunk `p3` | `AEPlayUITests`, `AEReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified actions (turns and advances), the shell picker's starting shell, the smallest move count | asserted equal to the Core by an app unit test |
