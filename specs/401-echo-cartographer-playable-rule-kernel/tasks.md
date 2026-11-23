# Tasks: R02-G11-01 — Echo Cartographer: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G11-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G11-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_401, neighbouring checks seed 2_406; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no GLSL
in this feature (the chamber, its rays and echoes are the CPU reference the renderer of R02-G11-03 will consume).

## Phase 1: Setup

- [X] T-R02G1101-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-23: baseline-host, baseline-timing, baseline-round02 exit 0, 2026-11-23; rendering baseline is X-R02-G10's visualcore-rendering run (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is X-R02-G10's visualcore-rendering run (exit 0)

## Phase 2: Foundational

- [ ] T-R02G1101-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `EchoCartographerCore`,
  `EchoCartographerCoreTests`, product); create `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerError.swift`
  (codes "r02-g11.level, .action, .noop, .stage, .stale, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerChamber.swift` ("width, height (5 … 16)", walls as
  cell indices "y · W + x"; cells, directions north, east, south, west; `ray(from:_:)` with the open cells crossed, the
  struck wall (nil at the border) and the distance ≥ 1; `pathLengths(from:)` breadth-first over open cells by side steps;
  `echo(from:beacons:)` with sorted unlabelled beacon distances; delays "24 × distance"),
  `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerLevel.swift` (entry open; "beacons (1 … 4 distinct
  sorted cells)" open, not the entry, reachable from the entry; "tolerance 0 … 2", "energy 1 … 60", "miss cost 1 … 3",
  "difficulty 1 … 5", tutorial, seed, id; knowledge type (unknown, open, wall); cells, echoes and progress named in words
  (FR-R02G1101-013); JSON schema 1 with sorted keys and fingerprint; decode re-checks) and
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerFixtures.swift` (seeded levels with known
  winning actions) with `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerLevelTests.swift`;
  `--name host`

## Phase 3: Story 1 — map the chamber and find the beacons (P1) 🎯

- [ ] T-R02G1101-003 [P] [US1] Create `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerChamberTests.swift`
  (agent A: on 500 seeded chambers and emitters, every ray equals explicit coordinate stepping (open cells, struck wall or
  border, distance); every path length equals repeated relaxation to a fixed point (no queue); unreachable cells and
  walls have none; echoes are the sorted beacon path lengths; delays are 24 × distance; hand cases: a wall next to the
  emitter (distance 1), a ray to the border, a beacon on the emitter (0), a beacon behind a wall reached around it);
  `--name host-2`

## Phase 4: Stories 2 and 3 — energy, undo, redo, replay (P1)

- [ ] T-R02G1101-004 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerPlay.swift`
  (agent B: stages "loading, tutorial, playing, paused, won, failed, result"; knowledge starting with only the entry
  open; `pulse`, `claim`, `mark` validated in the order stage, previous fingerprint, action (outside, pulse not from a
  known-open cell, claim on a known wall, a ninth marker), no-op (claim near only located beacons); a pulse spends 1 and
  reveals its rays' cells; a claim locates the nearest unlocated beacon within the tolerance (then lowest row, then lowest
  column) or misses for min(miss cost, energy); markers toggle free; after an action win, then energy (failure
  `energy(action index)`); localization errors; records with previous and next fingerprints; full undo and redo (from
  failed back to playing, recorded; won is final); replay) with
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerPlayTests.swift` (known actions win on the
  exact claim; a claim at the tolerance locates and one cell further misses; energy failure on the exact action with one
  action either side; a win with no energy left wins; 500 seeded traces replay; undo restores exact fingerprints and
  energy; every refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [ ] T-R02G1101-005 [P] [US4] Create `Packages/ExperiencesRound02/EchoCartographer/Core/EchoCartographerRules.swift`
  (agent C: `PuzzleRules`: State = position (knowledge, located, energy, outcome), Move = EchoCartographerAction; legal
  moves while playing "every valid pulse, then every valid claim, each in cell-index order (markers are not moves)") with
  `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerRulesTests.swift` (agreement with the play on 200
  walks); `--name host-4`
- [ ] T-R02G1101-006 [P] Create `Packages/ExperiencesRound02/EchoCartographer/CoreTests/EchoCartographerInvariantTests.swift`
  (agent D: `testEchoCartographerTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each
  with a seeded neighbouring-input check, seed 2_406); `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1101-007 Docs: `docs/architecture/echo-cartographer.md` (new: rules), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G1101-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G1101-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1101-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1101-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1101-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, chamber, level, fixtures, docs) stay with
the lead. MVP: Story 1.
