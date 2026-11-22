# Tasks: R02-G06-01 — Chrono Constellator: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G06-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G06-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_351, neighbouring checks seed 2_356; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no GLSL
in this feature (the closed-form positions are the CPU reference the renderer of R02-G06-03 will consume).

## Phase 1: Setup

- [X] T-R02G0601-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-21: 2026-11-21 baseline-host, baseline-timing, baseline-round02 exit 0, run with the new Chrono files set aside (.autonomy/migration/checks/R02-G06-01.baseline-*.json); rendering baseline: R02-G05-10 rendering-27/26 exit 0
  --package-path Packages/ExperiencesRound02`; the rendering baseline is R02-G05-10's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0601-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `ChronoConstellatorCore`, — Verified 2026-11-21: 2026-11-21 host exit 0: 7 level tests (ranges and loop rules refused by name, stored form round-trips and refuses damage, reason codes, star descriptions, 200 fixtures win exactly at their win tick) (.autonomy/migration/checks/R02-G06-01.host.json); package, error, level, timeline, fixtures; play source written by the lead so agents C and D compile against it; lead run
  `ChronoConstellatorCoreTests`, product); create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorError.swift`
  (codes "r02-g06.level, .action, .stage, .stale, .budget, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorLevel.swift` (shapes ring, cross, diamond, triangle,
  square with names; stars "loop of 4 … 32 distinct cells, consecutive and last-first 4-neighbours", "phase 0 … L − 1",
  "target on the loop", targets pairwise distinct, each star described in words, number and shape (FR-R02G0601-013);
  "columns 5 … 12, rows 5 … 10", "2 … 5 stars", "budget 1 … 20", "tick limit 1 … 1,200", "difficulty 1 … 5"; JSON schema 1
  with sorted keys and fingerprint; decode re-checks), `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorTimeline.swift`
  (phases and holds; holds "start ≥ 1, length 1 … 60, start + length − 1 ≤ tick limit", a star's holds neither overlap nor
  touch; edits in use = changed phases + holds; held(star, through:) and position "loop[(φ + t − h(t)) mod L]"; timeline
  fingerprint; evaluation collision (stars, cell), win, time, nothing at tick 0) and
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorFixtures.swift` (seeded levels with a known
  winning timeline) with `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorLevelTests.swift`;
  `--name host`

## Phase 3: Story 1 — align the stars (P1) 🎯

- [X] T-R02G0601-003 [P] [US1] Create `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorTimelineTests.swift` — Verified 2026-11-21: 2026-11-21 host-2 exit 0: ChronoConstellatorTimelineTests 15 tests in 0.37 s (positions equal an independent step-by-step reference on 500 seeded levels and timelines; held counts; edits in use; every edit refusal; collision names the lowest pair and cell; collision before win before time; swaps are no collision; nothing at tick 0; timeline fingerprint) (.autonomy/migration/checks/R02-G06-01.host-2.json); lead retest
  (agent A: positions on every tick equal an independent step-by-step reference written in the test on 500 seeded levels
  and timelines run to their tick limit; holds count exactly; the edits-in-use count; evaluation order collision, win,
  time; swaps on an edge are not collisions; nothing judged at tick 0); `--name host-2`

## Phase 4: Stories 2 and 3 — collide, edit, rewind, undo, redo, replay (P1)

- [X] T-R02G0601-004 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorPlay.swift` — Verified 2026-11-21: 2026-11-21 host-3 exit 0: ChronoConstellatorPlayTests 8 tests in 3.6 s (stage table; 200 fixtures win at their win tick; collision and time at the exact tick with one tick either side; validation order and every refusal; rewind and won final; exact undo/redo; 500 seeded traces with pauses replay identically, tampered records refused) (.autonomy/migration/checks/R02-G06-01.host-3.json); replay aligns pause/resume; lead retest
  (agent B: stages "loading, tutorial, playing, paused, won, failed, result"; actions validated for stage, previous
  fingerprint, range, "edits only at tick 0", unchanged phase, overlapping hold, missing hold, budget; step(1 … 1,200)
  stops at the deciding tick; rewind to tick 0; failures collision and time; records with previous and next fingerprints;
  full undo and redo (from failed back to playing; won is final); replay) with
  `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorPlayTests.swift` (known solutions win at the
  exact tick; collision and time at the exact tick with one tick either side of each limit; 500 seeded traces replay; undo
  restores exact fingerprints; every refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [X] T-R02G0601-005 [P] [US4] Create `Packages/ExperiencesRound02/ChronoConstellator/Core/ChronoConstellatorRules.swift` — Verified 2026-11-21: 2026-11-21 host-4 exit 0: ChronoConstellatorRulesTests 6 tests in 0.75 s (move order, terminal positions, agreement with the play on 200 walks, known solutions) (.autonomy/migration/checks/R02-G06-01.host-4.json); lead retest
  (agent C: `PuzzleRules`: State = position (timeline, tick, outcome), Move = ChronoConstellatorAction; legal moves at tick
  0 phase(i, o) for each star and offset ≠ current in order, then hold(i, s, k) for each star, "start 1 … 32 and length 1 … 32"
  in that order skipping refused ones, then release(i, s) for each hold, then step(tick limit); after tick 0 only rewind)
  with `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorRulesTests.swift` (agreement with the play
  on 200 walks); `--name host-4`
- [X] T-R02G0601-006 [P] Create `Packages/ExperiencesRound02/ChronoConstellator/CoreTests/ChronoConstellatorInvariantTests.swift` — Verified 2026-11-21: 2026-11-21 host-5 exit 0: ChronoConstellatorInvariantTests 9 tests in 2.1 s (time, input budget, goal, repeatability, undo, failure honesty, stability, save, renderer purity, each with a seeded neighbouring-input check, seed 2_356) (.autonomy/migration/checks/R02-G06-01.host-5.json); lead retest
  (agent D: `testChronoConstellatorTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each with a
  seeded neighbouring-input check, seed 2_356); `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G0601-007 Docs: `docs/architecture/chrono-constellator.md` (new: rules), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-21: 2026-11-21 round02-host exit 0 (.autonomy/migration/checks/R02-G06-01.round02-host.json); new docs/architecture/chrono-constellator.md (rules), package README section, testing doc (closed form against a step-by-step reference; baselines with new files set aside)
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0601-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G0601-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0601-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0601-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0601-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, level, timeline, fixtures, docs) stay with
the lead. MVP: Story 1.

## Phase 7: Convergence

- [ ] T-R02G0601-013 Bring `specs/351-chrono-constellator-playable-rule-kernel/contracts/api.md` and `specs/351-chrono-constellator-playable-rule-kernel/data-model.md` in line with the code: stars are described by `ChronoConstellatorLevel.description(ofStar:)` (not a star property), and the public `isNeighbour`, `place(_:)`, `shape(of:)`, `ChronoConstellatorTimeline.isHeld(star:on:)`, `ChronoConstellatorHold.end` and its star-then-start order, `ChronoConstellatorFailure.code`, `ChronoConstellatorPlay.positions` and `spent`, and `ChronoConstellatorRules.Position`, `Outcome`, `holdStarts`, `holdLengths` are listed per plan: contracts (partial)
