# Mycelium Architect (R02-G22)

Experience `r02-g22.mycelium-architect` (free), a puzzle of living fungal networks: the player seeds filaments from a
root, places nutrients that pull growth toward them and blockers that turn it away from toxin, then advances the growth
pulses, so that the glowing veins join every terminal within a branch-weight limit without touching toxin or running out
of nutrient. Code lives in `Packages/ExperiencesRound02/MyceliumArchitect`; this page grows with each feature of
R02-G22. Every rule is decided exactly on integers on a square lattice; the catalog's 0.016667 s timestep belongs to the
presentation of later features.

## Rule kernel (feature 511, R02-G22-01)

- **Lattice.** A board of 4 … 32 by 4 … 32 cells named (column, row) from the top left; eight directions numbered
  clockwise from north; Chebyshev distance. Features: one root, 1 … 6 terminals, rocks, toxins and 0 … 8 fixed
  nutrients, never two on one cell.
- **Field.** f(c) = Σ s · max(0, R − distance) over unconsumed nutrients (strength s 1 … 8, reach R 1 … 16), at most
  1 792 per cell.
- **Growth.** Each pulse (1 … 128) moves the growing tips in ascending number one cell, to the admissible neighbour (on
  the board, not a rock or blocker, not grown, no corner cut between two obstacles; toxins admissible) of greatest score
  (f(t) − f(c)) − κ·turn − ο·obstacles around t (κ, ο 0 … 8; turn 0 … 4 in 45° steps); ties go to the smaller turn,
  then the lower direction number; a tip with nothing admissible or a negative best score goes dormant. Seeds start
  tips at the root in ascending direction; a tip stepping onto a nutrient consumes it and a new tip starts there a
  quarter turn clockwise. Orthogonal segments weigh 2, diagonal 3; the network is a tree of at most 2 048 nodes.
- **The judge.** Before each step `starved` when the step would take the branch weight above the nutrient budget
  (2 … 4094; nothing grown), after it `toxic` when it entered toxin; after growth `unreached` (the lowest-numbered
  terminal not in the network), then `overweight` (above the limit); otherwise won.
- **Actions.** `nutrient(cell)`, `blocker(cell)` (on empty cells, within the level's limits of 0 … 6), `clear(cell)`,
  `seed(direction)` and `unseed(direction)` (up to 1 … 4 seeds; starting seeds locked) each spend one action of a budget
  of 1 … 24 (refused `r02-g22.action`, or `r02-g22.budget` with none left); the run spends nothing and ends the level.
  The growth report (field, every step with its score, the network in growth order with pulses and parents, the node
  count, the total weight, each terminal's reach pulse and path weight, the first failure and the predicted outcome)
  and its words follow every action. Undo and redo are exact.
- **Life and stored form.** Stages loading, tutorial, playing, paused, won, failed, result; records with previous and
  next fingerprints replay a play exactly; the level's stored form is JSON schema 1 with sorted keys and a SHA-256
  fingerprint, re-checked on decode in a fixed order (`r02-g22.malformed`, `.newer-schema`, `.level`). The rules are an
  R02-F23 `PuzzleRules` (`MyceliumArchitectPuzzle`) over arrangements; play and puzzle share one rule for legal moves.
