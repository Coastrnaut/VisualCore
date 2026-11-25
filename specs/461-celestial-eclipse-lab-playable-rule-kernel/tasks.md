# Tasks: R02-G17-01 — Celestial Eclipse Lab: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G17-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G17-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_461, neighbouring checks seed 2_466; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no
GLSL in this feature (positions, eclipse intervals and classes are the CPU reference the renderer of R02-G17-03 will
consume). Agents compile but run no tests while the lead's baselines or chain run.

## Phase 1: Setup

- [X] T-R02G1701-001 Baselines after X-R02-G16 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-25: 2026-11-25 baseline-host and round02-1, -2, -3c, -3e, -3f exit 0; baseline-timing printed bounds above its asserts (process tree at background priority PRI 4, VisualCore unchanged), host scheduling, not code; rendering baseline is X-R02-G16 visualcore-rendering (exit 0)
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the round-two chunks of feature 457); the rendering baseline is
  X-R02-G16's visualcore-rendering run (exit 0)

## Phase 2: Foundational

- [X] T-R02G1701-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `CelestialEclipseLabCore`, — Verified 2026-11-25: 2026-11-25 Package.swift gains CelestialEclipseLabCore and its tests; Error, Level, fixtures and CelestialEclipseLabLevelTests pass (host, host-1b exit 0)
  `CelestialEclipseLabCoreTests`, product); create
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabError.swift` (codes "r02-g17.level, .action,
  .budget, .stage, .stale, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabSky.swift` (vectors; bodies with "position(at
  tick, phase) = orbit[(tick + phase) mod period]"; the eclipse test "(xa − xb)² + (ya − yb)² < (ra + rb)²"; the
  visibility class "total when the front radius is at least the back radius and the squared distance is at most (rf −
  rb)², annular when the front radius is smaller and the squared distance is at most (rb − rf)², partial otherwise";
  intervals of every pair over ticks 0 … horizon − 1 "ordered by first tick, then front, then back", each interval's
  class "the deepest over its ticks"; the timeline judge "a match advances; the next target outside its window fails
  window; any other event fails unwanted; no events left fails horizon at tick horizon − 1; events after the last match
  ignored"), `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabLevel.swift` ("2 … 6 bodies",
  orbits "4 … 24 positions, coordinates −32 … 32", "radius 1 … 8", "at least one movable body", every pair depth-ordered
  "the front body's smallest z above the back body's largest z", "horizon 8 … 96", target "1 … 6 eclipses", each "front
  and back different, the front the front one of its pair, 0 ≤ open ≤ close ≤ horizon − 1", starting phases "0 … period
  − 1" that "do not win", "budget 1 … 24", "difficulty 1 … 5", tutorial, seed, id; bodies, eclipses and progress named
  in words (FR-R02G1701-013); JSON schema 1 with sorted keys and fingerprint; decode re-checks) and
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabFixtures.swift` (seeded levels with
  known winning phases, built by choosing phases, reading the timeline they produce and making its first eclipses the
  target with windows around them, then moving the starting phases away until they do not win) with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabLevelTests.swift`; `--name host`

## Phase 3: Story 1 — phase the orbits so the eclipses come in order (P1) 🎯

- [X] T-R02G1701-003 [P] [US1] Create — Verified 2026-11-25: 2026-11-25 CelestialEclipseLabSky and CelestialEclipseLabSkyTests pass (host-2 exit 0)
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabSkyTests.swift` (agent A: on 500 seeded
  levels and phase vectors, positions, overlap decisions, events, intervals, classes, the matched prefix and the judge's
  outcome equal an independent recomputation by direct enumeration of every tick and pair; hand cases: a distance one
  unit inside and outside the radius sum (touching is no eclipse), an eclipse under way at tick 0, two events on one
  tick, each class at its boundary, an event exactly on a window's opening and closing tick and one tick outside each,
  the horizon's last tick); `--name host-2`

## Phase 4: Stories 2 and 3 — failures, undo, redo, replay (P1)

- [ ] T-R02G1701-004 [P] [US1] [US2] [US3] Create
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabPlay.swift` (agent B: stages "loading,
  tutorial, playing, paused, won, failed, result"; phases from the level; `phase(body, offset)` validated in the order
  stage, previous fingerprint, action ("an unknown or fixed body, an offset outside the period or equal to the current
  one"), budget ("no action left"), spending 1 action and recomputing the timeline; `run` spending nothing and ending
  the level won or failed with the judge's failure; records with previous and next fingerprints; full undo and redo
  (from failed back to playing before the run, recorded; won is final); replay) with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabPlayTests.swift` (known phases win on
  the run; each failure named; the budget refusal on the exact action with the run still allowed; 500 seeded traces
  replay; undo restores exact fingerprints; every refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [ ] T-R02G1701-005 [P] [US4] Create
  `Packages/ExperiencesRound02/CelestialEclipseLab/Core/CelestialEclipseLabRules.swift` (agent C: `PuzzleRules`: State =
  position (phases, actions spent), Move = a phase change; legal moves "every legal phase change while actions are
  left"; goal "the predicted run wins") with
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabRulesTests.swift` (agreement with the
  play on 200 walks); `--name host-4`
- [ ] T-R02G1701-006 [P] Create
  `Packages/ExperiencesRound02/CelestialEclipseLab/CoreTests/CelestialEclipseLabInvariantTests.swift` (agent D:
  `testCelestialEclipseLabTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each
  with a seeded neighbouring-input check, seed 2_466); `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G1701-007 Docs: `docs/architecture/celestial-eclipse-lab.md` (new: rules),
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (chunk 3c gains CelestialEclipseLab)
- [ ] T-R02G1701-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G1701-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G1701-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G1701-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1701-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, sky, level, fixtures, docs) stay with the
lead. Agents may draft in isolated copies before 001 (new files only). MVP: Story 1. Requirement coverage: FR-001, 002,
009, 013 → 002; FR-004, 014 → 002, 003; FR-003, 005 … 008, 011 → 004; FR-010 → 005; FR-012 → 006; SC-001 … 005 →
002 … 006; SC-006 → 007 … 011.
