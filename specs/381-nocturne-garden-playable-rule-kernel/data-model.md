# Data model: R02-G09-01

| Entity | Fields | Rules |
|---|---|---|
| `NocturneGardenKind` | tulip, bell, star, fern, rose, lily | each a fixed simple polygon with integer vertices, foot at the origin, at most 16 vertices, within 3 × 6 cells at size 1; named in words |
| `NocturneGardenBloom` | kind, column, row, size (1 … 3) | foot at the lattice point (column, row); outline scaled by size; canonical order: row, column, kind, size |
| `NocturneGardenSun` | elevation 1 … 4 | factor e/2 (1/2, 1, 3/2, 2) stretching y about each foot |
| `NocturneGardenMask` | width, height, cells (sorted row-major indices) | union of the blooms' cells clipped to the bed; match, leak, boundary deviation |
| `NocturneGardenLevel` | id, seed, difficulty 1 … 5, width 16 … 32, height 12 … 24, target cells, forbidden cells (disjoint from the target), supply (count per kind, total 1 … 12), sizes, elevations, opening sun, budget 1 … 40, required match p/q (0 < p/q ≤ 1), leak allowance ≥ 0, tutorial, fingerprint | schema 1; sorted-key JSON |
| `NocturneGardenAction` | plant(kind, column, row, size), move(bloom, column, row), resize(bloom, size), remove(bloom), sun(elevation) | each accepted one spends one move |
| `NocturneGardenPlay` | stage, blooms (canonical order), sun, moves, failure (`leak(move)`: the move whose action leaked, its bloom or the sun read from that record; `budget`), records, undo/redo stacks | records carry previous and next fingerprints |
| `NocturneGardenRecord` | schema, level seed, move, kind (plant, move, resize, remove, sun, undo, redo), action, previous and next fingerprints | appended for every accepted action |
| `NocturneGardenRules.Position` | blooms, sun, moves, outcome (playing, won, failed) | moves: every accepted action in a fixed order (plant by kind, row, column, size; then move, resize, remove by bloom; then sun) |
