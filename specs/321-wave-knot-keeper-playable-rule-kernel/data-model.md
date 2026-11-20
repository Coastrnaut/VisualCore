# Data model: R02-G03-01

| Entity | Fields | Rules |
|---|---|---|
| `WaveKnotKeeperPoint` | x, y, z (−16 … 16) | integers |
| `WaveKnotKeeperGate` | min and max corners (inclusive box) | inside bounds |
| `WaveKnotKeeperTarget` | crossings 0 … 32, writhe −32 … 32 | |
| `WaveKnotKeeperLevel` | id, seed, band 1 … 5, points 6 … 16, gates 0 … 4, target, tension bound, allowance 1 … 64, tutorial, fingerprint | points distinct; start not won; start tension ≤ bound; schema 1 |
| `WaveKnotKeeperMove` | point index, direction (±x, ±y, ±z) | one lattice step |
| `WaveKnotKeeperSummary` | crossings, writhe, degenerate | from the xy-projection |
| `WaveKnotKeeperPlay` | stage, points, spent, records, undo/redo stacks, failure | records carry previous and next fingerprints |
