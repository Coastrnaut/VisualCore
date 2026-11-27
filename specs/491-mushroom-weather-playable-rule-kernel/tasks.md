# Tasks: R02-G20-01 — Mushroom Weather: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G20-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G20-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_491, neighbouring checks seed 2_496; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no
GLSL in this feature (the humidity fields, ledger and colony runs are the CPU reference the renderer of R02-G20-03 will
consume). Agents compile but run no tests while the lead's baselines or chain run.

## Phase 1: Setup

- [X] T-R02G2001-001 Baselines after X-R02-G19 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-26: 2026-11-26 baseline-host, baseline-timing, baseline-round02-1, -2, -3c, -3e, -3f exit 0 after X-R02-G19 (.autonomy/migration/checks/R02-G20-01.baseline-*.json)
  baseline-round02-1`, `-2`, `-3c`, `-3e`, `-3f` (the round-two chunks of feature 457); the rendering baseline is
  X-R02-G19's visualcore-rendering run

## Phase 2: Foundational

- [X] T-R02G2001-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `MushroomWeatherCore` depending on — Verified 2026-11-26: 2026-11-26 host exit 0: 13 level tests (ranges, every refusal, stored form, fixtures, ledger, hand cycles, words) (.autonomy/migration/checks/R02-G20-01.host.json)
  VisualCoreSimulation and VisualCoreMath, `MushroomWeatherCoreTests`, product); create
  `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherError.swift` (codes "r02-g20.level, .action, .budget,
  .stage, .stale, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherForest.swift` (the synchronous cycle: diffusion
  "for every pair of orthogonally adjacent floor cells, flow (hₐ − h_b)·D/64 truncated toward zero, antisymmetric",
  evaporation "⌊h·rate·(4 + L)/4096⌋, never more than the cell holds, rate by vent state", release "r, or g once grown";
  the ledger "total after = total before + released − evaporated"; growth "integral += cell humidity after each cycle;
  grown from the next cycle once integral ≥ G"; colony runs "in band when low ≤ h ≤ high"; the judge "per cycle dried
  (lowest sensitive colony with h < f) then mold (first cell in row-major order with h > M); after the run won when
  every colony is in band for each of the last K cycles, else unstable naming the colony with the shortest final run";
  the report), `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherLevel.swift` ("rows 6 … 12", "columns
  6 … 14", blocked cells, "starting humidity 0 … M", "diffusion 1 … 12", "rates 0 … 200", "vents 0 … 6", "moonlight
  0 … 3", pod rules "slots 1 … 6, release 1 … 40, grown release r … 80, threshold 100 … 200000", "colonies 1 … 6,
  0 ≤ floor ≤ low ≤ high ≤ M", "mold bound 1000 … 10000", "run length 20 … 200", "required cycles 5 … T", "budget
  1 … 12", "difficulty 1 … 5", tutorial, seed, id; refused per FR-R02G2001-001 (off-floor or shared cells, a pod on a
  colony, a sensitive colony below its floor or a cell above M at the start, a starting arrangement that wins); pods,
  colonies and progress named in words (FR-R02G2001-013); JSON schema 1 with sorted keys and fingerprint; decode
  re-checks) and `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherFixtures.swift` (seeded levels
  with known winning arrangements, built by choosing a floor, rules and an arrangement, running it, taking each
  colony's band around its final humidity so the last K cycles fit, then choosing a starting arrangement that does not
  win) with `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherLevelTests.swift`; `--name host`

## Phase 3: Story 1 — arrange the fungi so every colony stays in band (P1) 🎯

- [X] T-R02G2001-003 [P] [US1] Create — Verified 2026-11-26: 2026-11-26 host-2 exit 0: 11 weather tests against an independent reimplementation, 500 seeded fixtures with three arrangements each, every field, ledger entry, growth cycle, colony run and outcome equal (.autonomy/migration/checks/R02-G20-01.host-2.json)
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherWeatherTests.swift` (agent A: an independent
  reimplementation of the cycle law, ledger, growth, colony runs and the judge, written from the spec's clarifications
  only, compared with the kernel on 500 seeded runs: every humidity value at every cycle, every ledger entry, growth
  cycle, colony run and outcome equal, and the ledger balancing for every cycle; hand cases: a colony one unit either
  side of a band edge, a cell one unit either side of the mold bound, a sensitive colony one unit either side of its
  floor, a growth integral one unit either side of its threshold, a final run one cycle short, equal neighbours, an
  evaporation larger than the cell holds, a vent and the moonlight changing the outcome); `--name host-2`

## Phase 4: Stories 2 and 3 — failures, undo, redo, replay (P1)

- [X] T-R02G2001-004 [P] [US1] [US2] [US3] Create — Verified 2026-11-26: 2026-11-26 host-3 exit 0: 8 play tests (known actions win on 500 fixtures, each failure named, budget, every refusal in order, fingerprints, undo and redo, 500 seeded traces replayed) (.autonomy/migration/checks/R02-G20-01.host-3.json)
  `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherPlay.swift` (agent B: stages "loading, tutorial,
  playing, paused, won, failed, result"; the arrangement from the level; `place(slot, cell)`, `remove(slot)`,
  `vent(index, open)` and `moonlight(level)` validated in the order stage, previous fingerprint, action ("out of range,
  unchanged, on a forbidden cell, removing an empty slot"), budget ("no action left"), spending 1 action and recomputing
  the report; `run` spending nothing and ending the level won or failed with the judge's failure; records with previous
  and next fingerprints; full undo and redo (from failed back to playing before the run, recorded; won is final);
  replay) with `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherPlayTests.swift` (known
  arrangements win on the run; each failure named; the budget refusal on the exact action with the run still allowed;
  500 seeded traces replay; undo restores exact fingerprints; every refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [X] T-R02G2001-005 [P] [US4] Create `Packages/ExperiencesRound02/MushroomWeather/Core/MushroomWeatherPuzzle.swift` — Verified 2026-11-26: 2026-11-26 host-4 exit 0: 4 puzzle tests (move order and refusals, agreement with the kernel and with the play on 200 seeded walks each) (.autonomy/migration/checks/R02-G20-01.host-4.json)
  (agent C: `PuzzleRules`: State = position (arrangement, actions spent), Move = an arrangement action; legal moves
  "every legal arrangement action while actions are left"; goal "the predicted run wins"; rulesID
  "r02-g20-mushroom-weather") with `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherPuzzleTests.swift`
  (agreement with the play on 200 walks); `--name host-4`
- [X] T-R02G2001-006 [P] Create — Verified 2026-11-26: 2026-11-26 host-5 exit 0: the nine named source invariant tests with seeded neighbouring checks; 45 Mushroom Weather tests in six suites pass (.autonomy/migration/checks/R02-G20-01.host-5.json)
  `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherInvariantTests.swift` (agent D:
  `testMushroomWeatherTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each
  with a seeded neighbouring-input check, seed 2_496); `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G2001-007 Docs: `docs/architecture/mushroom-weather.md` (new: rules), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-26: 2026-11-26 round02-host-1, -2, -3c, -3e, -3f exit 0, chunk 3f with MushroomWeather (.autonomy/migration/checks/R02-G20-01.round02-host-*.json); architecture page, package README and testing doc written
  `docs/automatedtesting.md`; `--name round02-host-1`, `-2`, `-3c`, `-3e`, `-3f` (chunk 3f gains MushroomWeather)
- [ ] T-R02G2001-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G2001-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G2001-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G2001-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G2001-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, forest, level, fixtures, docs) stay with
the lead. Agents may draft in isolated copies before 001 (new files only). MVP: Story 1. Requirement coverage: FR-001,
002, 009, 013 → 002; FR-003, 004, 014 → 002, 003; FR-005 … 008, 011 → 004; FR-010 → 005; FR-012 → 006; SC-001 … 005 →
002 … 006; SC-006 → 007 … 011.

## Phase 7: Convergence

- [ ] T-R02G2001-013 Make `MushroomWeatherLevel.decode` refuse a stored level whose values are invalid with
  `r02-g20.level` (pass the initializer's `.level` refusal through instead of wrapping it as `.malformed`), and update
  the stored-form tests in `Packages/ExperiencesRound02/MushroomWeather/CoreTests/MushroomWeatherLevelTests.swift` and
  `…InvariantTests.swift` per FR-R02G2001-009, Clarification Q5 (contradicts); `--name host-6`
