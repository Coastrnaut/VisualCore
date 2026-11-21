# Data model: R02-G05-01

| Entity | Fields | Rules |
|---|---|---|
| `ColorfallCanyonsColor` | cyan 0, coral 1, yellow 2 | names in words for accessibility |
| `ColorfallCanyonsGround` | open, rock, drain — stored per cell | springs and basins sit on open ground |
| `ColorfallCanyonsCellKind` | open, rock, spring(index), basin(index), drain — resolved by `kind(of:)`, not stored | rock holds nothing |
| `ColorfallCanyonsSpring` | cell, colour, release 1 … 4, supply 1 … 999, open at start | one colour per spring |
| `ColorfallCanyonsBasin` | cell, capacity 1 … 999, fill 0 … capacity, shares (per mille, sum 1,000), tolerance 0 … 500, protected, tolerated wrong 0 … 999 | wrong = colours with share 0 |
| `ColorfallCanyonsLevel` | id, seed, difficulty 1 … 5, columns 4 … 12, rows 4 … 10, cells, springs 1 … 3, basins 1 … 4, flow rate 1 … 8, budget 1 … 30, tick limit 1 … 3,600, tutorial, fingerprint | schema 1; ≥ 1 drain; ≥ 1 basin with fill > 0 |
| `ColorfallCanyonsFluid` | tick, heights, valves, supplies left, per-cell masses [3], spilled [3], released [3] | conservation: released = Σ cells + spilled per colour |
| `ColorfallCanyonsAction` | carve(cell), valve(spring), step(ticks 1 … 600) | |
| `ColorfallCanyonsPlay` (replay pauses or resumes where a record's previous fingerprint says so) | stage, fluid, spent, failure (`contamination`, `overflow`, `time`), records, undo/redo stacks (snapshots) | records carry previous and next fingerprints |
| `ColorfallCanyonsRecord` | schema, level seed, tick, kind (carve, valve, step, undo, redo), action (nil for undo and redo), previous and next fingerprints | appended for every accepted action |
