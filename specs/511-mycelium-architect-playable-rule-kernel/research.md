# Research: R02-G22-01

- **R1 Pulses, not seconds.** Decision: the kernel counts whole growth pulses 1 … P; the catalog's 0.016667 s timestep
  is the presentation clock of later features. Rationale: an exact clock; no floating point decides a rule.
  Alternatives: continuous growth with a real time step (rounding would change which tip arrives first).
- **R2 A square lattice with eight directions.** Decision: cells (column, row) from (0, 0) at the top left; directions
  numbered clockwise from north, 0 N … 7 NW; Chebyshev distance. Rationale: eight directions let veins curve and the
  turn between two directions is a whole number of 45° steps (0 … 4), so the curvature penalty is exact.
  Alternatives: four directions (no diagonal veins, curvature only 0, 1 or 2); a hexagonal lattice (harder to name
  cells in words).
- **R3 A tent-shaped nutrient field.** Decision: f(c) = Σ s · max(0, R − d(c, n)) over unconsumed nutrients. Rationale:
  whole numbers, bounded (at most 1 792), monotone toward each nutrient within its reach, and additive, so several
  nutrients combine predictably. Alternatives: inverse distance (needs division and rounding); diffusion (iterative,
  expensive, and harder to explain).
- **R4 Score and tie-breaks.** Decision: score = (f(t) − f(c)) − κ·turn(h, k) − ο·obs(t); highest wins; ties go to the
  smaller turn, then the lower direction number. Rationale: the source's "max nutrient-gradient direction minus
  curvature and obstacle penalties" kept as written; the tie-breaks make growth a total function of the arrangement.
- **R5 Admissibility and dormancy.** Decision: a step needs an on-board target that is not a rock, a blocker or already
  in the network, and no corner cut (a diagonal step between two orthogonal obstacles); toxins are admissible and fail
  the run. A tip with no admissible direction or a negative best score goes dormant for good. Rationale: the network
  stays a tree; growth always ends; "network enters toxic volume" is a real failure the player must steer away from.
- **R6 Order within a pulse.** Decision: growing tips move in ascending tip number; a tip sees cells grown earlier in
  the same pulse; tips born in a pulse first move in the next. Rationale: sequential, deterministic, no simultaneous
  conflicts.
- **R7 Branching at nutrients.** Decision: a tip stepping onto an unconsumed nutrient consumes it and a new tip (the next
  unused number) starts on that cell with heading (k + 2) mod 8; the parent keeps heading k. Rationale: "branching
  growth" with one fixed, explainable rule; consumption keeps a nutrient from pulling forever and bounds the tips.
- **R8 Weights and the node cap.** Decision: orthogonal 2, diagonal 3; budget 2 … 4094; limit 2 … budget. Rationale: an
  integer stand-in for 1 : √2 (error under 6 %); every segment weighs at least 2, so a network within the budget has at
  most 1 + 2 047 = 2 048 nodes and the source's cap holds by construction.
- **R9 Judge order.** Decision: during growth, before each step: `starved` if the step's weight would exceed the budget;
  after the step: `toxic` if the target is toxic; after growth: `unreached` (lowest-numbered terminal not reached), then
  `overweight`; otherwise won. Rationale: the earliest failure is named; a budget failure grows nothing.
- **R10 Seeds are headings.** Decision: a seed is a direction at the root that starts a tip with that heading; the tip
  chooses its first step by score. Rationale: "seed filament" and "steer growth" act through the curvature penalty;
  a forced first step would bypass the law. Starting seeds are locked; seeds are numbered by ascending direction.
- **R11 Run as the commitment.** Decision: arrangement actions cost one action each and keep the level playing; `run`
  costs nothing, is allowed with the budget spent, and ends the level won or failed; the predicted outcome is reported
  after every action; undo from failed returns to playing with the arrangement before the run; a won level is final.
  Rationale: as features 491 and 501.
- **R12 Where the tests run.** Decision: CI half b of `round02-host-tests` gains `MyceliumArchitect`; locally chunk 1
  (`VoxelOrigami`) becomes `VoxelOrigami|MyceliumArchitect`. Rationale: the new tests run in exactly one CI half and one
  local chunk; chunk 2 already gained Binary Gardens and its regression net, chunk 1 is the lightest.
- **R13 Fingerprints.** Decision: the level fingerprint is SHA-256 of a canonical text of every level field in a fixed
  order (cell lists in ascending (row, column)); the play fingerprint is SHA-256 of schema, level fingerprint,
  arrangement, actions spent, stage and failure; every record carries the previous and next fingerprints. Decode
  re-runs the initializer's checks and passes `.level` through; a fingerprint mismatch or broken JSON is `.malformed`.
- **R14 Search space for R02-G22-02.** Decision: the puzzle position is the arrangement plus actions spent; moves in a
  fixed order: nutrients on empty cells in ascending (row, column), then blockers likewise, then clears of placed
  items in ascending (row, column), then seeds and unseeds in ascending direction; each skipping refused moves.
  R02-G22-02's fairness budget passes a `maxBranching` covering 2 · W · H + 20. Rationale: "graph shortest path plus
  deterministic branching-growth heuristic" searches these arrangements; the goal test is the kernel's predicted win.
- **R15 Budget from the start at 1 … 24.** Decision: the action budget range is 1 … 24 (the R02-G22 manifest needs
  8 … 19), as feature 501.
