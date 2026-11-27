# Data model: R02-G22-01

All values are integers (`Int`, 64-bit); tips and terminals are numbered from 1 in words and 0-based in code; cells are
(column, row) from (0, 0).

## Entities

| Entity | Fields | Rules |
|---|---|---|
| `MyceliumArchitectCell` | column, row | 0 ≤ column < W, 0 ≤ row < H; ordered by (row, column) |
| `MyceliumArchitectDirection` | 0 … 7 (N, NE, E, SE, S, SW, W, NW) | offsets (0,−1), (1,−1), (1,0), (1,1), (0,1), (−1,1), (−1,0), (−1,−1); turn(h, k) = min(|k − h|, 8 − |k − h|) |
| `MyceliumArchitectArrangement` | nutrients (placed cells), blockers (placed cells), seeds (directions, including the starting seeds) | sorted; distinct; counts within the level's limits; placements on empty cells |
| `MyceliumArchitectLevel` | id, seed (UInt64), difficulty 1 … 5, width W 4 … 32, height H 4 … 32, root, terminals (1 … 6), rocks, toxins, fixedNutrients (0 … 8), strength s 1 … 8, reach R 1 … 16, curvature κ 0 … 8, obstacle ο 0 … 8, maxNutrients 0 … 6, maxBlockers 0 … 6, maxSeeds 1 … 4, startSeeds (0 … maxSeeds, distinct), pulses P 1 … 128, nutrientBudget 2 … 4094, weightLimit 2 … budget, budget 1 … 24, tutorial, fingerprint | refused `r02-g22.level` when a value is out of range, two features share a cell, a cell is off the board, nothing can be placed or seeded (maxNutrients = maxBlockers = 0 and startSeeds = maxSeeds), or the starting arrangement already wins; schema 1; sorted-key JSON |
| `MyceliumArchitectTip` | number, cell, heading, growing (Bool) | heading 0 … 7 |
| `MyceliumArchitectStep` | pulse, tip, from, direction, to, score, weight, consumed (Bool), newTip (number or nil) | weight 2 (orthogonal) or 3 (diagonal) |
| `MyceliumArchitectReport` (growth report) | field [H][W], steps (in order), grown cells in growth order (root first, pulse 0, no parent) with aligned pulses and parent indices (arrays, never dictionaries, so iteration order is fixed), node count (root included), total weight, terminal reach pulses and path weights, first toxic entry, pulses run, failure, outcome | exact; computed after every action; never decides by itself |
| `MyceliumArchitectFailure` | toxic(pulse, tip, cell), starved(pulse, tip, cell, weight, budget), unreached(terminal), overweight(weight, limit) | codes `toxic`, `starved`, `unreached`, `overweight` |
| `MyceliumArchitectAction` | nutrient(cell), blocker(cell), clear(cell), seed(direction), unseed(direction), run | the five arrangement actions spend 1 action; run spends none and ends the level |
| `MyceliumArchitectStage` | loading, tutorial, playing, paused, won, failed, result | see transitions |
| `MyceliumArchitectPlay` | level, stage, arrangement, actions spent, report, failure, records, undo and redo stacks | fingerprint = SHA-256(schema, level fingerprint, arrangement, actions spent, stage, failure) |
| `MyceliumArchitectRecord` | schema (1), level seed, index, kind (nutrient, blocker, clear, seed, unseed, run, undo, redo, begin, dismissTutorial, pause, resume, showResult), action, previous and next fingerprints | a replayed chain must start at the initial fingerprint and link every next to the following previous |
| `MyceliumArchitectPuzzle.Position` | arrangement, actions spent | moves: every legal arrangement action while actions are left; goal: the predicted run wins |

## Validation rules (actions)

Checked in this order, each refusal leaving the play unchanged:
1. `.stage` — the stage is not `playing`.
2. `.stale` — the expected previous fingerprint differs from the play's fingerprint.
3. `.action` — a cell off the board or not empty (rock, toxin, root, terminal, fixed nutrient, placed item) for
   nutrient or blocker; a count already at its limit; clear of a cell without a placed item; a direction outside
   0 … 7, already seeded, or the seed limit reached; unseed of a direction not seeded or a starting seed. (A direction outside 0 … 7 cannot be expressed by the closed
   direction type; only a damaged stored form could carry one, and decoding refuses it `r02-g22.malformed`.)
4. `.budget` — no action left. `run` never checks the budget.

## State transitions

```text
loading --begin--> tutorial (level.tutorial)  |  loading --begin--> playing (no tutorial)
tutorial --dismissTutorial--> playing
playing --pause--> paused --resume--> playing
playing --nutrient|blocker|clear|seed|unseed--> playing (1 action spent, report recomputed)
playing --run--> won | failed
failed --undo--> playing (the arrangement before the run)
won | failed --showResult--> result
playing --undo/redo--> playing (exact earlier/later state)
```

A won level is final (undo refused `.stage`); every action and event not listed is refused `.stage`; undo or redo with
nothing to undo or redo is refused `.action`.

## Stored form (schema 1)

Sorted-key JSON with the top-level keys `budget`, `curvature`, `difficulty`, `fingerprint`, `fixedNutrients`, `height`,
`id`, `maxBlockers`, `maxNutrients`, `maxSeeds`, `nutrientBudget`, `obstacle`, `pulses`, `reach`, `rocks`, `root`,
`schema` (1), `seed`, `startSeeds`, `strength`, `terminals`, `toxins`, `tutorial`, `weightLimit`, `width`; cells as
`{"column", "row"}`, cell lists in ascending (row, column) except terminals, which keep their numbered order. The
fingerprint is SHA-256 of the canonical text of every other field. Decode order: broken JSON → `malformed`; schema > 1
→ `newer-schema`; schema below 1 or a missing field → `malformed`; a value the initializer refuses → `level`; a
fingerprint mismatch → `malformed`.
