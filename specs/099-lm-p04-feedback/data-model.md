# Data model: A13-P04 (feature 099)

No persisted format changes: the session state stays schema 2 and `progress.json` schema 1.

## Hint (core, value)
- `tile: Int?` — index among the level's turnable tiles; nil when the board is solved.
- Rule: first index `i` (board order) with `orientations[i] != level.solution[i]`; nil when the tracer reads the board
  solved. Following hints (select + turn) changes one differing tile per step.

## BoardDescription (core, value)
- `targetWords: String` — "K of T targets lit"; the adapter inserts it into the canvas description, which is the
  summary (contract §Words).
- `full: String` — level and size; per tile kind the places (row and column counted from 1, rows from the bottom) with direction
  (emitter) or orientation (mirror, prism: "leaning right"/"leaning left"); per beam branch its start, turn cells and end; per
  target lit or unlit. Length ≤ 4,000 characters for any board within the caps.

## SuccessCue (core, rules)
- `duration = 0.6` s; `brightness(elapsed:reduceMotion:reduceFlashing:) -> Double` (1…1.5).
- `words(levelNumber:moves:nextOpened:isLast:) -> String`.
- Experience state: `cueStart: Double?` (frame-time clock), cleared on suspension; played once per solve transition.

## State style (experience)
- `MazeStyle.signs: [StateSign]` — nine states (`wall`, `mirror`, `prism`, `emitter`, `target-unlit`, `target-lit`,
  `beam`, `selected`, `solved`) with colour hex and sign; `stateSignProblems(signs) == []`.
- Colours: each state's colour against `boardColor` ≥ 3 : 1.
