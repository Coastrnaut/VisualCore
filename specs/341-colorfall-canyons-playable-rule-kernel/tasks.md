# Tasks: R02-G05-01 — Colorfall Canyons: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G05-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G05-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_341, neighbouring checks seed 2_346; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no GLSL
in this feature (the CPU flow step is the reference the renderer of R02-G05-03 will consume).

## Phase 1: Setup

- [X] T-R02G0501-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 R02-G05-01.baseline-host/timing/round02 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G04-10's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0501-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `ColorfallCanyonsCore`, `ColorfallCanyonsCoreTests`, — Verified 2026-11-21: 2026-11-21 host exit 0 (package targets; error codes; level with ranges, placement, drain and target rules, colour names and mix words, stored form; exact fluid tick with downhill routing, largest-remainder sharing, springs, drains, conservation and verdict; fixtures: 500 channel levels whose known solution wins and random valid levels; 5 level tests). The lead also wrote ColorfallCanyonsPlay (the rules and invariants depend on it); agent B writes its tests
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

- [X] T-R02G0501-003 [P] [US1] Create `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsFlowTests.swift` (routing and every tick equal an — Verified 2026-11-21: 2026-11-21 host-2 exit 0 (flow, 22 tests by agent A, retested by the lead: every tick of 500 seeded levels, valves as given and all toggled, run to their tick limit (random limits now 1 … 120 so the runs stay short), equals an independent brute-force reference; zero drift per colour every tick; largest-remainder sharing over 20,000 cases; pools, tie order, rock, basins, drains, dry springs, closed valves; verdict precedence and boundaries one unit either side)
  independent brute-force reference written in the test on 500 seeded levels run to their tick limit; total fluid and
  each colour's mass drift by exactly zero on every tick; sharing never creates or loses a unit and keeps the leftover
  rule; flat ground pools; ties follow east, south, west, north; a dry spring and a closed valve release nothing);
  `--name host-2`

## Phase 4: Stories 2 and 3 — fail, pause, step, undo, redo, replay (P1)

- [X] T-R02G0501-004 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsPlay.swift` (stages "loading, tutorial, playing, — Verified 2026-11-21: 2026-11-21 host-3 exit 0 (play by the lead, 12 tests by agent B plus one by the lead: 500 known solutions win at the first met tick and fail on time without carves; contamination, overflow and time at the exact tick one unit either side; every refusal in order with no change; 500 seeded traces replay, tampered traces refused; undo/redo exact for every kind, from failed and while paused; full stage table; fingerprint against an independent byte layout). Agent B found that an undo or redo made while paused did not replay; the lead made replay pause or resume where a record's previous fingerprint says so and added testUndoAndRedoWhilePausedReplay
  paused, won, failed, result"; actions validated for stage, previous fingerprint, range or carvability, budget; carve and
  valve spend one, step(1 … 600) spends nothing and stops at the deciding tick; failures contamination, overflow, time;
  records with previous and next fingerprints; full undo and redo (from failed back to playing; won is final); replay)
  with `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsPlayTests.swift` (known solutions win at the exact tick; each failure at the exact
  tick with one unit either side of each limit; 500 seeded traces replay; undo restores exact fingerprints; every
  refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [X] T-R02G0501-005 [P] [US4] Create `Packages/ExperiencesRound02/ColorfallCanyons/Core/ColorfallCanyonsRules.swift` (`PuzzleRules`: State = position (fluid, — Verified 2026-11-21: 2026-11-21 host-4 exit 0 (ColorfallCanyonsRules as PuzzleRules by agent C, 9 tests retested by the lead: move order, budget gating, ended positions, agreement with the play on 200 seeded walks (capped at 100 moves), 100 known solutions as single ticks, Position JSON, PuzzleValidator certifies a hand-made level and refuses wrong rules, illegal moves and unsolved paths)
  spent, outcome), Move = ColorfallCanyonsAction; legal moves carve(c) for each carvable cell in index order, valve(s) for
  each spring, step(1)) with `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsRulesTests.swift` (agreement with the play on 200 walks);
  `--name host-4`
- [X] T-R02G0501-006 [P] Create `Packages/ExperiencesRound02/ColorfallCanyons/CoreTests/ColorfallCanyonsInvariantTests.swift` (`testColorfallCanyonsTimeBoundary`, — Verified 2026-11-21: 2026-11-21 host-5 exit 0 (9 invariant tests by agent D, retested by the lead against the final fixtures: time, input budget, goal, repeatability, undo, failure honesty, stability, save, renderer purity, each with a seeded neighbouring-input check, seed 2_346)
  `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`, `…UndoBoundary`, `…FailurehonestyBoundary`,
  `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each with a seeded neighbouring-input check, seed
  2_346); `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G0501-007 Docs: `docs/architecture/colorfall-canyons.md` (rules), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-21: 2026-11-21 round02-host exit 0; docs/architecture/colorfall-canyons.md, Packages/ExperiencesRound02/README.md, docs/automatedtesting.md
  `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G0501-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-21: 2026-11-21 rendering-27, rendering-26, experiences, host-full exit 0
  `--name host-full`
- [X] T-R02G0501-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-21: 2026-11-21 reference-1 exit 0
- [X] T-R02G0501-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-21: 2026-11-21 reference-2 exit 0: 7 of 7 with chunk 1
- [X] T-R02G0501-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-21: 2026-11-21 script-tests exit 0, run alone
- [X] T-R02G0501-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record — Verified 2026-11-21: 2026-11-21 converge round 1 appended T-R02G0501-013 (contract and data model), implemented; round 2 converged; sealed 16 passing checks, 0 failed attempts; recorded R02-G05-01 pass (.autonomy/migration/evidence/R02-G05-01.json); validators PASS

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, level, flow, fixtures, docs) stay with the
lead. MVP: Story 1.

## Phase 7: Convergence

- [X] T-R02G0501-013 Document `ColorfallCanyonsGround` (open, rock, drain as stored), `ColorfallCanyonsLevel.kind(of:)` (`ColorfallCanyonsCellKind` is not Codable), `ColorfallCanyonsBasin.description`, `ColorfallCanyonsFluid.volume(_:)` and the replay's pause/resume alignment in `specs/341-colorfall-canyons-playable-rule-kernel/contracts/api.md` and `specs/341-colorfall-canyons-playable-rule-kernel/data-model.md` per plan: contracts (partial) — Verified 2026-11-21: 2026-11-21 ColorfallCanyonsGround, kind(of:), CellKind not Codable, Basin.description, Fluid.volume and the replay's pause alignment documented in contracts/api.md and data-model.md (grep: present in both); code unchanged
