# Data Model: A13-P01

| Entity | Fields | Rules |
|---|---|---|
| `Segment2`, `Ray2`, `RayHit2` (VisualCoreMath) | see contracts/api.md | finite values; unit direction and normal |
| `Direction` | east, north, west, south | unit vectors (1,0), (0,1), (−1,0), (0,−1) |
| `Orientation` | slash `/`, backslash `\` | turn toggles |
| `Tile` | kind ∈ {emitter, wall, mirror, target, prism}, cell (column, row), direction (emitter), orientation (mirror, prism) | one tile per cell; inside the board |
| `Board` | width 4…12, height 4…12, tiles | exactly one emitter, ≥ 1 target, ≤ 144 tiles |
| `Beam` | segments [start, end, bounce, branch], lit target cells, end reasons | ≤ 256 segments, ≤ 64 bounces per branch, ≤ 16 branches |
| `Level` | id, name, board, solution (orientation per turnable tile), author, license | valid; unsolved at start; solution lights all targets |
| `MazeState` (schema 1) | level index 0…19, orientations of turnable tiles, selection (−1 or index) | damaged or newer refused |
