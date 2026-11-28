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

## Content pipeline (feature 512, R02-G22-02)

- **Sites.** A level may declare 2 … 12 placement sites; nutrients and blockers are then placed only there (refused
  "not a site"), which bounds the move space the solver must search. A level without sites keeps feature 511's stored
  form and fingerprint. Every catalog level declares sites.
- **Manifest and generator.** The 100 planned entries (20 per band, budgets 8 … 19) are a table with provenance.
  Candidate c of entry n draws from its planned seed: the board, root, rocks and toxins, fixed nutrients, field and
  penalties, sites, a winning plan of the band's length p (1, 2, 3, 3, 4; the emphasised kind first) and the starting
  seeds; the winning arrangement is grown, the latest-grown cells (never sites or fixed nutrients) become the terminals,
  and budget and limit follow from the grown weight plus the band's slack. Candidates are skipped when the growth is
  toxic, starved or too small, the level rules refuse them, the board repeats the previous level's, the minimal plan is
  not p, or the plan does not win through the play; at most 1 024 candidates (measured: at most 349).
- **Solver.** Breadth-first over arrangements by action count with a loss order (16 × the distance from each unreached
  terminal to the network, the excess weight, 1 024 for a toxic or starved run) and reachability checks; the first win
  is minimal and the arrangements at each smaller depth, all judged and none winning, are the proof. Work is counted
  and bounded at 20 000.
- **Witnesses and catalog.** `docs/games/mycelium-architect/levels/NNN.witness.json` holds the level, the actions,
  per-action state digests, the play fingerprints, the terminal growth report, the counterexample with the nearest miss,
  the difficulty and the skipped candidates; they are rewritten only with `MYCELIUM_ARCHITECT_WRITE_WITNESSES=1` and
  compared byte for byte otherwise. The catalog digest over the 100 fingerprints is pinned; witness lengths keep the
  standard progression rule (band means 1, 2, 3, 3, 4). The whole catalog generates in about 9 s on a debug host build.

## Hero renderer (feature 513, R02-G22-03)

- **Scene.** The board lies in the plane z = 0, fitted by one rule per level (cell side s = 1.9 / max(W, H), the board a
  square of side 1.9 centred at (0, 0.05)), seen from a fixed authored perspective (eye (0, −1.9, 2.8), target
  (0, −0.3, 0), fitted with a 5 % margin for aspects 0.4 … 2.5). Drawn in painter's order with depth testing off: the
  cave backdrop with hashed spores, the floor and grid, sites, violet toxin pools, rocks with copper veins, blockers,
  copper nutrient orbs, the emerald vein tubes of every segment grown up to the shown pulse (tapering from 0.16·s at the
  root to 0.06·s by path weight, pulsing outward with time), blooms where nutrients were consumed, hyphae fuzz and spores
  (beneath the caps, so decoration never hides them), seed sprouts, the root cap and the terminal caps (open and lit when
  reached), then the weight gauge with its limit tick, the terminal pips and the actions bars, and the additive glow.
- **Purity.** The presenter draws only `MyceliumArchitectSceneSnapshot`, made by the adapter from the play; the shown
  pulse (`growth.show`) is presentation state, never in the digest; tiers, time and failures never change the kernel.
- **Tiers.** `level-0` (tubes of 8 sides, caps of 16 segments, 6 fuzz strands, 24 spores, 2 glow shells), `level-1`
  (6, 12, 3, 12, 1) and `level-2` (4, 8, none); everything else is identical; the presenter logs tier changes.
- **Materials.** GLSL ES 3.00 board and glow programs (7 uniform slots each, no samplers, bounded loops, a fixed hash);
  the material code, a value and a broken mark travel in `a_uv.x`; flats are cut out by signed distance. A failed
  program falls back to the unlit renderer with the level-2 geometry in flat palette colours, keeping the reason.
- **Candidate.** `MyceliumArchitectExperienceCore` adapts the kernel (cell nutrient, blocker and clear, root seed and
  unseed, growth run and show, undo, redo, next level; digest domain `r02-g22.mycelium-architect.v1`; snapshot schema 1),
  registered in the one app as a candidate (not available) with 100 levels and the pinned catalog digest; simulator
  tests check frames of levels 1, 21, 41, 61 and 81 at every tier against the CPU reference.

