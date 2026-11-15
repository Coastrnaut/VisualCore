# Data model: A13-P05 (feature 100)

No persisted format changes.

## SolverResult (core, value, Equatable)
- `.solved(orientations: [Orientation], turns: Int, examined: Int)` — the first solved set in search order.
- `.unsolvable(examined: Int)` — all 2ⁿ sets examined, none solved.
- `.refused(SolverRefusal)` — `invalid-board` (with the board's `BoardRefusal`) or `too-many-tiles`; examined 0.
- Constants: `Solver.maxTurnable = 16`.

## LevelQA (core, value, Equatable)
- `id: String`, `fewestTurns: Int?` (nil when unsolvable), `recordedTurns: Int`, `failures: [QACheck]` in the order
  `unsolvable`, `wrong-solution`, `longer-solution`, `solved-start`, `no-license`; passes when `failures` is empty.
