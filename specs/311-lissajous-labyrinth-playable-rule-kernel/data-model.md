# Data model: R02-G02-01

| Entity | Fields | Rules |
|---|---|---|
| `LissajousLabyrinthBall` | x, y, z, radius | each coordinate −5,000 … 5,000; radius 64 … 1,024 |
| `LissajousLabyrinthDials` | frequencyA, frequencyB (1 … 9, coprime), phaseA, phaseC (0 … 15) | |
| `LissajousLabyrinthDial` | `frequencyA`, `frequencyB`, `phaseA`, `phaseC` | dial order |
| `LissajousLabyrinthLevel` | schema 1, id (slug), seed, band 1 … 5, amplitudes [3] (1 … 4), frequencyC 1 … 9, start dials, checkpoints [1 … 6], obstacles [0 … 8], allowance 1 … 64, tutorial, fingerprint | start must not win; fingerprint = SHA-256 of canonical JSON |
| `LissajousLabyrinthVerdict` | `won`, `contact(obstacle, tick)`, `missed(checkpoint)` | contact first by tick, then obstacle |
| `LissajousLabyrinthAction` | dial, value | |
| `LissajousLabyrinthStage` | loading, tutorial, playing, paused, won, failed, result | events begin, dismissTutorial, pause, resume, showResult |
| `LissajousLabyrinthRecord` | schema, seed, tick, kind (action, undo, redo), dial, value, previous, next | append-only |
| `LissajousLabyrinthPlay` | level, stage, dials, spent, records, failure verdict, undo/redo stacks | fingerprint = SHA-256(schema, level fingerprint, dials, spent, stage) |
