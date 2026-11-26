# Data model: R02-G19-01

| Entity | Fields | Rules |
|---|---|---|
| `MicroscopicAuroraPoint` | x, y (Int, dish units, 256 per cell) | 0 … 6143 inside the dish |
| `MicroscopicAuroraSwimmer` | position, velocity (Int, dish units per tick) | starts inside the enclosure; velocity within ±v_max |
| `MicroscopicAuroraCell` | row, column (0 … 23) | a stencil or well cell's centre lies inside the enclosure |
| `MicroscopicAuroraWell` | cell, strength 1 … 4, sense (clockwise, counterclockwise) | at most three; never two on one cell |
| `MicroscopicAuroraSwarmRules` | ρ 2 … 6 and σ 1 … ρ cells, κ 2 … 8 cells, weights wₛ, wₐ, w_c 0 … 8, a_max 2 … 16, v_max 8 … 48 | integers |
| `MicroscopicAuroraLevel` | id, seed, difficulty 1 … 5, enclosure radius R 6 … 11, swim length T 120 … 480, swarm rules, swimmers (4 … 16), stencil (4 … 120 distinct cells), threshold 1 … 64, coverage 500 … 1000, coherence 2 … N, starting wells (0 … 3), budget 1 … 12, tutorial, fingerprint | start inside, start coherent, starting wells do not win; schema 1; sorted-key JSON |
| `MicroscopicAuroraReport` | positions by tick, density per cell (576), lit stencil cells, coverage, groups, smallest coherence and its tick, failure, outcome | exact; never decides by itself |
| `MicroscopicAuroraAction` | place(slot, cell, strength, sense), remove(slot), play | placements spend 1 action; play spends none and ends the level |
| `MicroscopicAuroraFailure` | exit(swimmer, tick), coherence(tick, group), coverage(lit, needed), connectedness(cell) | codes `exit`, `coherence`, `coverage`, `connectedness` |
| `MicroscopicAuroraPlay` | stage, wells, actions spent, report, failure, records, undo/redo stacks | records carry previous and next fingerprints |
| `MicroscopicAuroraRecord` | schema, level seed, index, kind (place, remove, play, undo, redo, begin, dismissTutorial, pause, resume), action, previous and next fingerprints | appended for every accepted action and event |
| `MicroscopicAuroraPuzzle.Position` | wells, actions spent | moves: every legal placement; goal: the predicted play wins |
