# Tasks: R02-G22-01 — Mycelium Architect: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G22-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G22-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_511, neighbouring checks seed 2_516; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no
GLSL in this feature (the field, steps, grown network, weights and reach pulses are the CPU reference the renderer of
R02-G22-03 will consume). Agents compile but run no tests while the lead's baselines or chain run. Every `host` …
`host-5` check runs `swift test --package-path Packages/ExperiencesRound02 --filter MyceliumArchitect`. Public names
beyond the contract (memberwise initializers, word helpers, range constants) are listed in contracts/api.md with their
reasons as they are added (feature 501's convergence lesson).

## Phase 1: Setup

- [X] T-R02G2201-001 Baselines after X-R02-G21 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-27: baseline-host, baseline-timing, baseline-round02-1/2/3c/3e/3f exit=0
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the five round-two filters as at R02-G21-10, without
  `MyceliumArchitect`, on the committed tree before the targets exist); the rendering baseline is X-R02-G21's
  visualcore-rendering run

## Phase 2: Foundational

- [X] T-R02G2201-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `MyceliumArchitectCore` depending on — Verified 2026-11-27: package targets, CI half b filter, error, growth, level, fixtures and level tests installed; host exit=0 (12 tests)
  VisualCoreSimulation and VisualCoreMath, path `MyceliumArchitect/Core`; `MyceliumArchitectCoreTests`, path
  `MyceliumArchitect/CoreTests`, depending on MyceliumArchitectCore, VisualCoreSimulation and VisualCoreMath; product)
  and `.github/workflows/ci.yml` (job `round02-host-tests`, matrix `group: b`: `|MyceliumArchitect` appended after
  `BinaryGardens` in its `--filter`; half a unchanged; research R12); create
  `Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectError.swift` (codes "r02-g22.level, .action,
  .budget, .stage, .stale, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectGrowth.swift` (cells "(column, row) from
  (0, 0)", "ordered by (row, column)"; directions "0 … 7 (N, NE, E, SE, S, SW, W, NW)" with offsets "(0,−1), (1,−1),
  (1,0), (1,1), (0,1), (−1,1), (−1,0), (−1,−1)" and "turn(h, k) = min(|k − h|, 8 − |k − h|)"; the field "f(c) = Σ s ·
  max(0, R − d(c, n)) over unconsumed nutrients" with Chebyshev distance; admissibility (on the board, not rock or
  blocker, not grown, no corner cut; toxins admissible); the score "(f(t) − f(c)) − κ·turn(h, k) − ο·obs(t)" with obs
  counting rocks, blockers and off-board cells among t's eight neighbours; ties "smaller turn, then lower direction
  number"; dormancy when nothing is admissible or the best score is below 0; tips in ascending number, born tips moving
  from the next pulse; seeds start tips 1, 2, … in ascending direction at the root; a step onto an unconsumed nutrient
  consumes it and starts a new tip "with heading (k + 2) mod 8"; weights "2 (orthogonal) or 3 (diagonal)"; the judge:
  before a step `starved` "if the step's weight would exceed the budget" (nothing grown), after it `toxic` if the
  target is toxic, after growth `unreached` (lowest-numbered terminal) then `overweight`, otherwise won; the report
  "exact; computed after every action; never decides by itself"),
  `Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectLevel.swift` ("difficulty 1 … 5, width W
  4 … 32, height H 4 … 32, root, terminals (1 … 6), rocks, toxins, fixedNutrients (0 … 8), strength s 1 … 8, reach R
  1 … 16, curvature κ 0 … 8, obstacle ο 0 … 8, maxNutrients 0 … 6, maxBlockers 0 … 6, maxSeeds 1 … 4, startSeeds
  (0 … maxSeeds, distinct), pulses P 1 … 128, nutrientBudget 2 … 4094, weightLimit 2 … budget, budget 1 … 24",
  tutorial, seed, id; "refused `r02-g22.level` when a value is out of range, two features share a cell, a cell is off
  the board, nothing can be placed or seeded (maxNutrients = maxBlockers = 0 and startSeeds = maxSeeds), or the
  starting arrangement already wins"; the arrangement "sorted; distinct; counts within the level's limits; placements
  on empty cells"; cells, directions, tips, terminals, steps, failures and progress named in words (FR-R02G2201-014);
  JSON schema 1 with sorted keys and fingerprint; decode order "broken JSON → `malformed`; schema > 1 →
  `newer-schema`; schema below 1 or a missing field → `malformed`; a value the initializer refuses → `level`; a
  fingerprint mismatch → `malformed`") and
  `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectFixtures.swift` (seeded levels with known
  winning arrangements, `SeededRandom(seed: 2_511)`: a board with rocks and toxins, a root, a winning arrangement of
  nutrients, blockers and seeds, run, terminals taken from cells of the grown network, budget and limit set at or
  above the grown weight, then a starting arrangement that does not win) with
  `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectLevelTests.swift` (ranges, every refusal,
  stored form, the field, hand cases of scoring, ties, corner cutting, branching, fixtures, words); `--name host`

## Phase 3: Story 1 — feed the network so its veins reach every terminal (P1) 🎯

- [ ] T-R02G2201-003 [P] [US1] Create
  `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectGrowthTests.swift` (agent A: an
  independent reimplementation of the field, admissibility, scoring, tie-breaks, tip order, branching, weights and the
  judge, written from the spec's clarifications only, compared with the kernel on 500 seeded runs: every field value,
  step, score, grown cell and pulse, parent, node count, total weight, reach pulse, path weight and outcome equal, no
  network above 2048 nodes; hand cases: a branch weight one unit either side of the budget and of the limit, a toxin
  one cell either side of a tip's path, a terminal one cell beyond the network, a starved step onto toxin, equal scores
  broken by turn and then direction, a corner cut refused, a negative best score, a consumed nutrient no longer pulling,
  two tips competing for one cell, growth ending early); `--name host-2`

## Phase 4: Stories 2 and 3 — failures, undo, redo, replay (P1)

- [ ] T-R02G2201-004 [P] [US1] [US2] [US3] Create
  `Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectPlay.swift` (agent B: stages "loading,
  tutorial, playing, paused, won, failed, result"; `nutrient(cell)`, `blocker(cell)`, `clear(cell)`, `seed(direction)`
  and `unseed(direction)` validated in the order stage, previous fingerprint, action ("a cell off the board or not
  empty (rock, toxin, root, terminal, fixed nutrient, placed item) for nutrient or blocker; a count already at its
  limit; clear of a cell without a placed item; a direction outside 0 … 7, already seeded, or the seed limit reached;
  unseed of a direction not seeded or a starting seed"), budget ("no action left. `run` never checks the budget"),
  spending 1 action and recomputing the report; `run` spending nothing and ending the level won or failed; records with
  previous and next fingerprints; full undo and redo (from failed back to playing with the arrangement before the run;
  won is final; undo or redo with nothing to undo or redo refused `.action`); replay ("a replayed chain must start at
  the initial fingerprint and link every next to the following previous")) with
  `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectPlayTests.swift` (known arrangements win on
  the run on 500 seeded fixtures (SC-R02G2201-001); each failure named; the budget refusal on the exact action with the
  run still allowed; 500 seeded traces replay; undo restores exact fingerprints; every refusal reason reachable);
  `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [ ] T-R02G2201-005 [P] [US4] Create
  `Packages/ExperiencesRound02/MyceliumArchitect/Core/MyceliumArchitectPuzzle.swift` (agent C: `PuzzleRules`: State =
  position (arrangement, actions spent), Move = an arrangement action; legal moves "every legal arrangement action while
  actions are left" in the order of research R14 (nutrients on empty cells in ascending (row, column), blockers
  likewise, clears ascending, then seeds and unseeds in ascending direction); goal "the predicted run wins"; rulesID
  "r02-g22-mycelium-architect") with
  `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectPuzzleTests.swift` (agreement with the play
  on 200 walks); `--name host-4`
- [ ] T-R02G2201-006 [P] Create
  `Packages/ExperiencesRound02/MyceliumArchitect/CoreTests/MyceliumArchitectInvariantTests.swift` (agent D:
  `testMyceliumArchitectTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each
  with a seeded neighbouring-input check, seed 2_516); `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G2201-007 Docs: `docs/architecture/mycelium-architect.md` (new: rules),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md` (MyceliumArchitect in local chunk round02-host-1
  and in CI half b); `--name round02-host-1`, `-2`, `-3c`, `-3e`, `-3f` (chunk 1 gains MyceliumArchitect: `swift test
  --package-path Packages/ExperiencesRound02 --filter 'VoxelOrigami|MyceliumArchitect'`; the other four filters
  unchanged)
- [ ] T-R02G2201-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G2201-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2201-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2201-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G2201-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, ci.yml, error, growth, level, fixtures, docs)
stay with the lead. Agents may draft in isolated copies before 001 (new files only). MVP: Story 1. Requirement
coverage: FR-001, 002, 010, 014 → 002; FR-003, 004, 005, 006, 015 → 002, 003; FR-007 … 009, 012 → 004; FR-011 → 005;
FR-013 → 006; SC-001 … 005 → 002 … 006; SC-006 → 007 … 011.
