# Tasks: R02-G18-01 — Apsides Workshop: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G18-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G18-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_471, neighbouring checks seed 2_476; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no
GLSL in this feature (positions, shares and apsis readings are the CPU reference the renderer of R02-G18-03 will
consume). Agents compile but run no tests while the lead's baselines or chain run.

## Phase 1: Setup

- [ ] T-R02G1801-001 Baselines after X-R02-G17 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the round-two chunks of feature 457); the rendering baseline is
  X-R02-G17's visualcore-rendering run

## Phase 2: Foundational

- [ ] T-R02G1801-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `ApsidesWorkshopCore`,
  `ApsidesWorkshopCoreTests`, product); create
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopError.swift` (codes "r02-g18.level, .action, .budget,
  .stage, .stale, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopFixed.swift` ("Int64, 2^30 as one"; integer sine,
  cosine and square root; Kepler inversion "at most 8 Newton steps from E = M + e·sin M, stopping when the residual is
  at most 2^−24; otherwise 48 bisection steps on [M − e, M + e]"; every residual "at most 2^−22"),
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopOrbit.swift` (orbit "size 8 … 48, eccentricity 0 …
  15, direction 0 … 23", valid "a(20 − k) ≥ 60 and a(20 + k) ≤ 1280"; positions "(a(cos E − e), a·√(1 − e²)·sin E)
  turned by 15d° (exact quarter-turn table sin 15j°, j = 0 … 6, extended by symmetry; M = (twoPi · t) / T truncated) and
  rounded to whole sky units, half away from zero", 256 sky units per lattice unit; sectors "8 of 45°, the boundary ray
  belonging to the sector it begins"; shares "one triangle per tick, counted for P(t), tenths of a percent rounded
  down"; apsis readings "sector ⌊d/3⌋ at a(20 − k), sector ⌊(d + 12)/3⌋ mod 8 at a(20 + k), in twentieths"; contact "the
  centre's distance to a tick segment strictly below the radius"; event ticks "sweep: first tick in its sector, T if
  none; periapsis 0; apoapsis T/2"; the judge "contact first (lowest tick, then planet); then targets in order: order,
  share, apsis-sector, apsis-distance; all met wins"; the report),
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopLevel.swift` ("period even 16 … 96", planets "0 … 6,
  centre −64 … 64, radius 1 … 8, never overlapping the star", targets "1 … 6", sweeps "sector 0 … 7, low ≤ high in 0 …
  1000", apsis targets "sector 0 … 7, near ≤ far", "no two targets identical", starting orbit "valid and does not win",
  "budget 1 … 24", "difficulty 1 … 5", tutorial, seed, id; sectors, targets and progress named in words
  (FR-R02G1801-013); JSON schema 1 with sorted keys and fingerprint; decode re-checks) and
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopFixtures.swift` (seeded levels with known
  winning orbits, built by choosing an orbit, reading the report it produces and making targets from its shares and
  apsides with bands around them, adding planets away from its path, then moving the starting orbit away until it does
  not win) with `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopLevelTests.swift`; `--name host`

## Phase 3: Story 1 — shape the orbit so it sweeps the prescribed sky (P1) 🎯

- [ ] T-R02G1801-003 [P] [US1] Create
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopOrbitTests.swift` (agent A: on 500 seeded
  orbits, positions agree with an independent `Double` Kepler solution within 2 sky units, every residual is within
  2^−22, and sectors, shares, apsis readings, contact decisions, event ticks and the judge's outcome equal an
  independent recomputation by direct enumeration on the kernel's integer positions; hand cases: a point on each sector
  boundary, a circular orbit, the extreme valid orbits and one step beyond, a share one unit either side of a band
  bound, a distance one unit either side of a range bound, a planet one unit inside and outside contact (grazing is no
  contact), a sector never entered); `--name host-2`

## Phase 4: Stories 2 and 3 — failures, undo, redo, replay (P1)

- [ ] T-R02G1801-004 [P] [US1] [US2] [US3] Create
  `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopPlay.swift` (agent B: stages "loading, tutorial,
  playing, paused, won, failed, result"; the orbit from the level; `periapsis(k, d)` and `size(a)` validated in the
  order stage, previous fingerprint, action ("out of range, unchanged or making the orbit invalid"), budget ("no action
  left"), spending 1 action and recomputing the report; `play` spending nothing and ending the level won or failed with
  the judge's failure; records with previous and next fingerprints; full undo and redo (from failed back to playing
  before the play, recorded; won is final); replay) with
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopPlayTests.swift` (known orbits win on the play;
  each failure named; the budget refusal on the exact action with the play still allowed; 500 seeded traces replay; undo
  restores exact fingerprints; every refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [ ] T-R02G1801-005 [P] [US4] Create `Packages/ExperiencesRound02/ApsidesWorkshop/Core/ApsidesWorkshopRules.swift`
  (agent C: `PuzzleRules`: State = position (orbit, actions spent), Move = a tuning; legal moves "every legal tuning
  while actions are left"; goal "the predicted play wins") with
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopRulesTests.swift` (agreement with the play on
  200 walks); `--name host-4`
- [ ] T-R02G1801-006 [P] Create
  `Packages/ExperiencesRound02/ApsidesWorkshop/CoreTests/ApsidesWorkshopInvariantTests.swift` (agent D:
  `testApsidesWorkshopTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`, `…UndoBoundary`,
  `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each with a seeded
  neighbouring-input check, seed 2_476); `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1801-007 Docs: `docs/architecture/apsides-workshop.md` (new: rules),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (chunk 3f gains ApsidesWorkshop)
- [ ] T-R02G1801-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G1801-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1801-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1801-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1801-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, fixed point, orbit, level, fixtures, docs)
stay with the lead. Agents may draft in isolated copies before 001 (new files only). MVP: Story 1. Requirement
coverage: FR-001, 002, 009, 013 → 002; FR-003, 004, 014 → 002, 003; FR-005 … 008, 011 → 004; FR-010 → 005; FR-012 →
006; SC-001 … 005 → 002 … 006; SC-006 → 007 … 011.
