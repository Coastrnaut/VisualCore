# Tasks: R02-G05-01 — Colorfall Canyons: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G05-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G05-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_341, neighbouring checks seed 2_346; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no GLSL
in this feature (the CPU flow step is the reference the renderer of R02-G05-03 will consume).

## Phase 1: Setup

- [ ] T-R02G0501-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G04-10's rendering runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02G0501-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `ColorfallCanyonsCore`, `ColorfallCanyonsCoreTests`,
  product); create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsError.swift` (codes "r02-g05.level, .action, .stage, .stale, .budget,
  .newer-schema, .malformed"), `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsLevel.swift` (colours cyan 0, coral 1, yellow 2 with names; each basin's required mix described in words and amounts (FR-R02G0501-013);
  cells "height 0 … 15", kinds open, rock, spring, basin, drain; springs "release 1 … 4, supply 1 … 999"; basins
  "capacity 1 … 999, fill 0 … capacity, shares per mille summing to 1,000, tolerance 0 … 500, tolerated wrong 0 … 999";
  "columns 4 … 12, rows 4 … 10", "1 … 3 springs", "1 … 4 basins", at least one drain, at least one basin with fill > 0,
  "flow rate 1 … 8", "budget 1 … 30", "tick limit 1 … 3,600", "difficulty 1 … 5"; JSON schema 1 with sorted keys and
  fingerprint; decode re-checks), `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsFlow.swift` (fluid state; downhill neighbour, lowest strictly
  lower non-rock 4-neighbour, ties east, south, west, north; synchronous tick: outflows min(V, flow rate) shared by
  largest remainder, then springs release min(release, supply), basins and drains receive, drains count spilled;
  conservation; verdict contamination, overflow, win, time) and `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsFixtures.swift` (seeded
  levels with a known winning action sequence) with `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsLevelTests.swift`; `--name host`

## Phase 3: Story 1 — route the colours (P1) 🎯

- [ ] T-R02G0501-003 [P] [US1] Create `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsFlowTests.swift` (routing and every tick equal an
  independent brute-force reference written in the test on 500 seeded levels run to their tick limit; total fluid and
  each colour's mass drift by exactly zero on every tick; sharing never creates or loses a unit and keeps the leftover
  rule; flat ground pools; ties follow east, south, west, north; a dry spring and a closed valve release nothing);
  `--name host-2`

## Phase 4: Stories 2 and 3 — fail, pause, step, undo, redo, replay (P1)

- [ ] T-R02G0501-004 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsPlay.swift` (stages "loading, tutorial, playing,
  paused, won, failed, result"; actions validated for stage, previous fingerprint, range or carvability, budget; carve and
  valve spend one, step(1 … 600) spends nothing and stops at the deciding tick; failures contamination, overflow, time;
  records with previous and next fingerprints; full undo and redo (from failed back to playing; won is final); replay)
  with `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsPlayTests.swift` (known solutions win at the exact tick; each failure at the exact
  tick with one unit either side of each limit; 500 seeded traces replay; undo restores exact fingerprints; every
  refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [ ] T-R02G0501-005 [P] [US4] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsRules.swift` (`PuzzleRules`: State = position (fluid,
  spent, outcome), Move = ColorfallCanyonsAction; legal moves carve(c) for each carvable cell in index order, valve(s) for
  each spring, step(1)) with `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsRulesTests.swift` (agreement with the play on 200 walks);
  `--name host-4`
- [ ] T-R02G0501-006 [P] Create `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsInvariantTests.swift` (`testColorfallCanyonsTimeBoundary`,
  `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`, `…UndoBoundary`, `…FailurehonestyBoundary`,
  `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each with a seeded neighbouring-input check, seed
  2_346); `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0501-007 Docs: `docs/architecture/colorfall-canyons.md` (rules), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0501-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G0501-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0501-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0501-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0501-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, level, flow, fixtures, docs) stay with the
lead. MVP: Story 1.
