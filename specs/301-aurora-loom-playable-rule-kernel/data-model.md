# Data model: R02-G01-01

| Entity | Fields | Rules |
|---|---|---|
| AuroraLoomRibbon | wave, phase (steps), omega | steps 0 … 15; omega 0 … 256 units per tick |
| AuroraLoomGate | position (sixteenths), target Θ | position 1 … 15; Θ 0 … 4,095 |
| AuroraLoomLevel | id, seed, band, ribbons (3), gates (4), omega Ω, tolerance, allowance, tutorial, fingerprint | id slug; band 1 … 5; 3 ribbons; 4 gates with distinct positions; Ω power of two 1 … 256; tolerance 1 … 512; allowance 1 … 64; start must not win; schema 1 |
| AuroraLoomControl | wave, phase | |
| AuroraLoomMove | ribbon, control, step | ribbon 0 … 2; step 0 … 15 |
| AuroraLoomMismatch | ribbon, gate, tick, residual | worst |residual|, ties by ribbon, gate, tick |
| AuroraLoomStage | loading, tutorial, playing, paused, won, failed, result | events begin, dismissTutorial, pause, resume, showResult |
| AuroraLoomRecord | schema, seed, tick, kind (move, undo, redo), ribbon, control, step, previous, next | append-only |
| AuroraLoomPlay | level, stage, steps, spent, records, undo stack, redo stack, outcome | fingerprint = SHA-256 of schema, level fingerprint, six steps, spent, stage |
| AuroraLoomError | level(String), move(String), stage, stale, allowance, newerSchema(Int), malformed(String) | `reasonCode` `r02-g01.*` |
