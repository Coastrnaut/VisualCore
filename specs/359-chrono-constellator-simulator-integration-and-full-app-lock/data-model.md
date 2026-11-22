# Data model: R02-G06-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | schema-1 payload of a seeded play of level 1 with one phase change that does not win, seed 7 | migrates 1 → 2 → 3; restores with level 1 and the phase change kept |
| Schema-2 example | schema-2 payload with campaign mode, progress {frontier 2, solved [level 1, best edits, stars]}, tutorial | migrates 2 → 3; the result is kept, unverified, without a trace |
| Control identifier | `experience.r02-g06.chrono-constellator.<name>` | names of clarification Q1; unique |
| Interface chunk `o3` | `CRPlayUITests`, `CRReplayUITests` | serial; each test under 90 s |
| Level 1 constants | certified actions (phase changes, then the step), every star's default phase and loop length, the smallest edit count | asserted equal to the Core by an app unit test |
