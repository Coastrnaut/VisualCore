# Tasks: R02-G15-01 — Voxel Origami: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G15-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G15-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_441, neighbouring checks seed 2_446; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no GLSL
in this feature (the cube cells, orientations and hinge quarter turns are the CPU reference the renderer of R02-G15-03
will consume).

## Phase 1: Setup

- [X] T-R02G1501-001 Baselines after X-R02-G14 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 (.autonomy/migration/checks/R02-G15-01.baseline-*.json); rendering baseline = X-R02-G14 visualcore-rendering
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is X-R02-G14's
  visualcore-rendering run (exit 0)

## Phase 2: Foundational

- [ ] T-R02G1501-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `VoxelOrigamiCore`, `VoxelOrigamiCoreTests`,
  product); create `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiError.swift` (codes "r02-g15.level,
  .action, .stage, .stale, .newer-schema, .malformed"), `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiLattice.swift`
  (vectors and the six units; the 24 rotation matrices with "entries −1, 0, 1", quarter turns about an axis by the
  right-hand rule; the pose "x(i) = x(p) + O(p) · d(i), O(i) = O(p) · R(d(i), q(i))" from cube 0 at (0, 0, 0) with the
  identity; the swinging set "cube i's descendants with a non-zero offset from the axis"; the turn check "collision
  first (a swinging cube landing on a still cube's cell, naming the lowest such swinging cube, the still cube and the
  cell), then the sweep (a still cube outside the turning body, in the same layer, whose open square of half-side 1 the open quarter arc of a swinging cube's centre enters, decided exactly in rationals by clipping the square to the arc's wedge)"; the canonical form "the lexicographically smallest sorted cell list among
  the allowed rotations, each translated so its smallest x, y and z are 0" and its `StableHash`; the covered count over
  every allowed rotation and every translation mapping a target cell onto an occupied cell),
  `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiLevel.swift` ("4 … 12 cubes", cube 0 the root with no
  parent, every other cube's parent "a lower index", a rest direction among the six units, start turns "0 … 3" (0 for
  cube 0); rest and starting poses "collision-free"; target "n distinct cells"; orientations `fixed`, `upright`, `any`;
  "the starting pose does not already match"; "budget 1 … 40"; "difficulty 1 … 5", tutorial, seed, id; cubes, hinges and
  progress named in words (FR-R02G1501-013); the shape report; JSON schema 1 with sorted keys and fingerprint; decode
  re-checks) and `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiFixtures.swift` (seeded levels with known
  winning turns, built by scrambling a solved pose with legal turns) with
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiLevelTests.swift`; `--name host`

## Phase 3: Story 1 — fold a chain of hinged cubes into the target solid (P1) 🎯

- [ ] T-R02G1501-003 [P] [US1] Create `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiLatticeTests.swift`
  (agent A: on 500 seeded levels and turn sequences, every pose equals an independent recomputation that rotates each
  subtree's cell list directly about its hinge line one quarter turn at a time from the rest pose; collision equals a set
  intersection; the sweep decision equals a fine sampling of the quarter arc (1 000 steps, unit-cube overlap with the
  still cubes) wherever the sampling is unambiguous; canonical forms and covered counts equal an enumeration of all
  allowed rotations and translations; the 24 rotations are distinct, closed under composition and orthogonal; hand
  cases: an L of three cubes turning about its middle (the hinge cube never blocks, a cube diagonal to the arc does), a
  cube one cell clear of the swept path and one clipped by it, a straight chain whose turn is idle, a target matched only
  under `any` and not under `upright`); `--name host-2`

## Phase 4: Stories 2 and 3 — failures, budget, undo, redo, replay (P1)

- [ ] T-R02G1501-004 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiPlay.swift`
  (agent B: stages "loading, tutorial, playing, paused, won, failed, result"; turns at the level's start turns; `turn`
  validated in the order stage, previous fingerprint, action (unknown hinge, a step other than ±1, a hinge with nothing
  that would move); each spends 1 action; a collision or sweep fails the level on that turn with the pose unchanged; after
  an accepted turn a match wins, otherwise a spent budget fails `budget(action index)`; the shape report after every
  action; records with previous and next fingerprints; full undo and redo (from failed back to playing before the failing
  turn, its action refunded, recorded; won is final); replay) with
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiPlayTests.swift` (known turns win on the exact turn;
  each failure named; budget failure on the exact action with one action either side; a turn on the last action wins;
  500 seeded traces replay; undo restores exact fingerprints; every refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [ ] T-R02G1501-005 [P] [US4] Create `Packages/ExperiencesRound02/VoxelOrigami/Core/VoxelOrigamiRules.swift` (agent C:
  `PuzzleRules`: State = position (turns, actions spent, outcome), Move = VoxelOrigamiAction; legal moves while playing
  "every hinge with a descendant off its axis, then −1, +1") with
  `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiRulesTests.swift` (agreement with the play on 200
  walks); `--name host-4`
- [ ] T-R02G1501-006 [P] Create `Packages/ExperiencesRound02/VoxelOrigami/CoreTests/VoxelOrigamiInvariantTests.swift`
  (agent D: `testVoxelOrigamiTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each with
  a seeded neighbouring-input check, seed 2_446); `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1501-007 Docs: `docs/architecture/voxel-origami.md` (new: rules), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1501-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G1501-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1501-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1501-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1501-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, lattice, level, fixtures, docs) stay with
the lead. Agents may draft in isolated copies before 001 (new files only). MVP: Story 1. Requirement coverage: FR-001,
009, 013 → 002; FR-002, 003, 014 → 002, 003; FR-004 … 008, 011 → 004; FR-010 → 005; FR-012 → 006; SC-001 … 005 →
002 … 006; SC-006 → 007 … 011.
