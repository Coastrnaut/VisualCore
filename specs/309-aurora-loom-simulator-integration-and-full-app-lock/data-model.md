# Data model: R02-G01-09

| Entity | Fields | Rules |
|---|---|---|
| Schema-1 example | `{level: 2, records: [two moves]}`, seed 7 | migrates 1 → 2 → 3; restores with level 2, records kept |
| Schema-2 example | `{level: 1, mode: campaign, progress: {frontier 2, solved [level 1, bestMoves, stars]}, records: [], tutorial}` | migrates 2 → 3; result kept unverified |
| Pending steps | wave and phase per ribbon, nil when none | stepper sets; Apply commits one move per changed control; Clear or an outside change drops them |
| Control identifier | `experience.r02-g01.aurora-loom.<name>` | names of clarification Q1 |
| Interface chunk `i3` | `ALPlayUITests`, `ALReplayUITests` | serial; each test under 60 s |
| Level 1 solution constants | per ribbon target wave and phase | asserted equal to the Core's certified solution by an app unit test |
