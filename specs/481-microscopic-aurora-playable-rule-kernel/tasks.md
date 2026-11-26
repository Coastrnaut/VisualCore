# Tasks: R02-G19-01 — Microscopic Aurora: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G19-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G19-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_481, neighbouring checks seed 2_486; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no
GLSL in this feature (positions, densities and lit cells are the CPU reference the renderer of R02-G19-03 will
consume). Agents compile but run no tests while the lead's baselines or chain run.

## Phase 1: Setup

- [X] T-R02G1901-001 Baselines after X-R02-G18 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-26: 2026-11-26: baseline-host, baseline-timing and round02-1, -2, -3c, -3e, -3f exit 0 on the committed X-R02-G18 record; rendering baseline is X-R02-G18's visualcore-rendering run (exit 0)
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the round-two chunks of feature 457); the rendering baseline is
  X-R02-G18's visualcore-rendering run

## Phase 2: Foundational

- [X] T-R02G1901-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `MicroscopicAuroraCore` depending on — Verified 2026-11-26: 2026-11-26: Package.swift gains MicroscopicAuroraCore and its tests; Error, Swim, Level, fixtures and MicroscopicAuroraLevelTests pass (host exit 0, 7 tests); the Codable path refuses schema 0 (found by agent D's save invariant)
  VisualCoreSimulation and VisualCoreMath, `MicroscopicAuroraCoreTests`, product); create
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraError.swift` (codes "r02-g19.level, .action,
  .budget, .stage, .stale, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraSwim.swift` (dish "24 × 24 cells, 256 units
  each, centre (3072, 3072)", inside "(x − 3072)² + (y − 3072)² ≤ (256R)²", cell "(⌊y/256⌋, ⌊x/256⌋)"; the
  synchronous tick: neighbours "within ρ", separation "within σ, coincident swimmers ±x by index", alignment and
  cohesion "means truncated toward zero", acceleration "(wₛ·sep)/64 + (wₐ·align)/16 + (w_c·coh)/256 + Σ
  sense·s·4096·(−dy, dx)/(dx² + dy² + 65536)", "every division truncates toward zero", clamps "±a_max then ±v_max per
  axis", "p ← p + v"; density "(swimmer, tick) pairs for ticks 1 … T", lit "density ≥ threshold"; coverage "tenths of
  a percent, rounded down"; groups "four-neighbour"; coherence "largest group linked within κ"; the judge "per tick
  exit (lowest swimmer) then coherence; after the swim coverage then connectedness (first lit stencil cell in row-major
  order outside the first one's group); otherwise won"; the report),
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraLevel.swift` ("enclosure radius 6 … 11", "swim
  length 120 … 480", "swimmers 4 … 16", rules "ρ 2 … 6, σ 1 … ρ, κ 2 … 8, weights 0 … 8, a_max 2 … 16, v_max 8 … 48",
  "stencil 4 … 120 distinct cells inside the enclosure", "threshold 1 … 64", "coverage 500 … 1000", "coherence 2 … N",
  "starting wells 0 … 3, inside, distinct cells, strength 1 … 4", "budget 1 … 12", "difficulty 1 … 5", tutorial,
  seed, id; refused when a swimmer starts outside, the start is incoherent or the starting wells already win; wells,
  coverage and progress named in words (FR-R02G1901-013); JSON schema 1 with sorted keys and fingerprint; decode
  re-checks) and `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraFixtures.swift` (seeded
  levels with known winning wells, built by choosing a swarm and wells, swimming it, taking a connected set of the
  densest lit cells as the stencil with a coverage requirement at or below the result, then choosing starting wells
  that do not win) with `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraLevelTests.swift`;
  `--name host`

## Phase 3: Story 1 — steer the swimmers so their trails draw the pattern (P1) 🎯

- [X] T-R02G1901-003 [P] [US1] Create — Verified 2026-11-26: 2026-11-26: MicroscopicAuroraSwimTests pass (host-2 exit 0, 10 tests): 1,000 swims of 500 fixtures equal an independent reimplementation at every tick; rim, coincident swimmers, threshold, coverage, coherence, no well, sense mirror, groups
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraSwimTests.swift` (agent A: an independent
  reimplementation of the tick law, trails, coverage, four-neighbour groups, coherence and the judge, written from the
  spec's clarifications only, compared with the kernel on 500 seeded swims: every position at every tick, every
  density, lit cell, coverage, group count, smallest coherence and outcome equal; hand cases: a swimmer on the rim and
  one unit outside, coincident swimmers, a density at and one below the threshold, a coverage one cell either side of
  the requirement, a coherence one swimmer either side, a swim with no well, a curl's sense reversing the turn);
  `--name host-2`

## Phase 4: Stories 2 and 3 — failures, undo, redo, replay (P1)

- [X] T-R02G1901-004 [P] [US1] [US2] [US3] Create — Verified 2026-11-26: 2026-11-26: MicroscopicAuroraPlay and MicroscopicAuroraPlayTests pass (host-3 exit 0, 8 tests)
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraPlay.swift` (agent B: stages "loading,
  tutorial, playing, paused, won, failed, result"; the wells from the level; `place(slot, well)` and `remove(slot)`
  validated in the order stage, previous fingerprint, action ("out of range, unchanged, on an occupied or outside cell,
  removing an empty slot"), budget ("no action left"), spending 1 action and recomputing the report; `play` spending
  nothing and ending the level won or failed with the judge's failure; records with previous and next fingerprints;
  full undo and redo (from failed back to playing before the play, recorded; won is final); replay) with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraPlayTests.swift` (known wells win on the
  play; each failure named; the budget refusal on the exact action with the play still allowed; 500 seeded traces
  replay; undo restores exact fingerprints; every refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [X] T-R02G1901-005 [P] [US4] Create — Verified 2026-11-26: 2026-11-26: MicroscopicAuroraPuzzle and its tests pass (host-4 exit 0): moves equal a hand enumeration on 200 walks and agree with the play on 200 walks; a trial with halved samples was discarded (no time gain)
  `Packages/ExperiencesRound02/MicroscopicAurora/Core/MicroscopicAuroraPuzzle.swift` (agent C: `PuzzleRules`: State =
  position (wells, actions spent), Move = a placement; legal moves "every legal placement while actions are left";
  goal "the predicted play wins"; rulesID "r02-g19-microscopic-aurora") with
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraPuzzleTests.swift` (agreement with the play
  on 200 walks); `--name host-4`
- [X] T-R02G1901-006 [P] Create — Verified 2026-11-26: 2026-11-26: MicroscopicAuroraInvariantTests pass (host-5 exit 0, 9 tests); the save invariant found the Codable path accepting schema 0, fixed in T-002
  `Packages/ExperiencesRound02/MicroscopicAurora/CoreTests/MicroscopicAuroraInvariantTests.swift` (agent D:
  `testMicroscopicAuroraTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each
  with a seeded neighbouring-input check, seed 2_486); `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G1901-007 Docs: `docs/architecture/microscopic-aurora.md` (new: rules), — Verified 2026-11-26: 2026-11-26: docs/architecture/microscopic-aurora.md, round-two README section and automatedtesting entry written; round02-host-1, -2, -3c, -3e (with MicroscopicAurora), -3f exit 0
  `Packages/ExperiencesRound02/README.md`, `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`,
  `-3f` (chunk 3e gains MicroscopicAurora)
- [X] T-R02G1901-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-26: 2026-11-26: rendering-27, rendering-26, experiences, host-full exit 0 (app-unit too)
  `--name host-full`
- [X] T-R02G1901-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-26: 2026-11-26: reference-1 exit 0
- [X] T-R02G1901-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-26: 2026-11-26: reference-2 exit 0
- [ ] T-R02G1901-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G1901-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, swim, level, fixtures, docs) stay with the
lead. Agents may draft in isolated copies before 001 (new files only). MVP: Story 1. Requirement coverage: FR-001, 002,
009, 013 → 002; FR-003, 004, 014 → 002, 003; FR-005 … 008, 011 → 004; FR-010 → 005; FR-012 → 006; SC-001 … 005 → 002
… 006; SC-006 → 007 … 011.
