# Tasks: R02-G14-01 — Moonlit Mechanism: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G14-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G14-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_431, neighbouring checks seed 2_436; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no GLSL
in this feature (the gears, their phases, the lamp and the cast cells are the CPU reference the renderer of R02-G14-03
will consume).

## Phase 1: Setup

- [X] T-R02G1401-001 Baselines after X-R02-G13 is recorded: `--name baseline-host`, `--name baseline-timing`, `--name — Verified 2026-11-24: 2026-11-24: baseline-host, baseline-timing, baseline-round02 exit 0 on 0582a79bf (.autonomy/migration/checks/R02-G14-01.baseline-*.json); rendering baseline = X-R02-G13 visualcore-rendering
  baseline-round02 -- swift test --package-path Packages/ExperiencesRound02`; the rendering baseline is X-R02-G13's
  visualcore-rendering run (exit 0)

## Phase 2: Foundational

- [X] T-R02G1401-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `MoonlitMechanismCore`, — Verified 2026-11-24: 2026-11-24: package targets, error (r02-g14.*), mechanics (directions, turned, alignment and error, cast, run order, action), level (ranges, stored form, names), fixtures (scrambled solutions) and 7 level tests incl. 200 fixtures; host exit 0 (.autonomy/migration/checks/R02-G14-01.host.json)
  `MoonlitMechanismCoreTests`, product); create `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismError.swift`
  (codes "r02-g14.level, .action, .stage, .stale, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismMechanics.swift` (directions "+1 when its distance
  from the driver is even and −1 when odd"; `turned` "(phase + direction · turns) mod T"; the alignment "(phaseₚ +
  phase_c) mod g = a" with g = gcd and its cyclic error; the cast "the blade at pattern bit b of a gear at phase q sits
  at slot (b + q) mod T", every cell shifted down by "h · depth rows", cells outside the wall dropped, cell numbers row by
  row; the run in the order "jammed (pair order), then key frames in order: forbidden, missing (required), stray
  (required)" with per-pair errors and per-key-frame covered, missing, stray and forbidden counts),
  `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismLevel.swift` ("2 … 5 gears", gear 0 the driver,
  every other gear's parent a lower index, "teeth 6 … 20", phase "0 … teeth − 1", blades "teeth bits, at least one
  solid and one open", "depth 1 … 3", slots "teeth lists of offsets, each within ±8, each list non-empty", "g ≥ 2",
  alignment "0 … g − 1"; wall "W 8 … 24 × H 6 … 16"; "lamp heights 2 … 5" with a starting height; "2 … 6" key frames
  with "strictly increasing" turns (the first ≥ 0), a non-empty sorted target and at least one required; "0 … 12"
  forbidden cells "disjoint from every target"; "allowance 0 … 4"; "budget 1 … 40"; "difficulty 1 … 5", tutorial, seed,
  id; gears, the lamp and progress named in words (FR-R02G1401-013); JSON schema 1 with sorted keys and fingerprint;
  decode re-checks) and `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismFixtures.swift` (seeded
  levels with known winning actions) with
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismLevelTests.swift`; `--name host`

## Phase 3: Story 1 — turn the clockwork until its shadows spell the symbols (P1) 🎯

- [X] T-R02G1401-003 [P] [US1] Create — Verified 2026-11-24: 2026-11-24: agent A 11 mechanics tests (independent walk, brute-force alignment, separate rasterisation, Q4 transcription on 500 set-ups; turn keeps alignment; hand cases); lead retest host-2 exit 0 (.autonomy/migration/checks/R02-G14-01.host-2.json)
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismMechanicsTests.swift` (agent A: on 500 seeded
  levels, phases and lamp heights, every turned phase equals an independent walk of the train from the driver one turn
  at a time, every alignment error equals a brute force over the cyclic distances, every cast equals a separate
  rasterisation into a W × H boolean grid, every overlap count and run outcome equals a direct transcription of
  clarification Q4; a turn never changes an alignment and a re-seat changes it by one; hand cases: a two-gear train of 6
  and 12 teeth, a forbidden cell at a key frame that is not required, stray cells at the allowance and one more, a jam
  reported before a forbidden cell, cells shifted off the wall by the lamp); `--name host-2`

## Phase 4: Stories 2 and 3 — failures, budget, undo, redo, replay (P1)

- [X] T-R02G1401-004 [P] [US1] [US2] [US3] Create — Verified 2026-11-24: 2026-11-24: agent B play (stages, validation order, run decision, budget, records, undo/redo from failed, replay) with 9 tests (200 fixtures, named failures, budget either side, 500 traces); lead retest host-3 exit 0 (.autonomy/migration/checks/R02-G14-01.host-3.json)
  `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismPlay.swift` (agent B: stages "loading, tutorial,
  playing, paused, won, failed, result"; phases at the level's starting phases, the lamp at its starting height; `turn`,
  `reseat`, `lamp` and `run` validated in the order stage, previous fingerprint, action (unknown gear, re-seating the
  driver, a step other than ±1, a lamp step out of range); each spends 1 action; a run wins or fails `jammed(child)`,
  `forbidden(frame, cell)`, `missing(frame, count)` or `stray(frame, count)`; after any other action a spent budget fails
  `budget(action index)`; the run report after every action; records with previous and next fingerprints; full undo and
  redo (from failed back to playing, recorded; won is final); replay) with
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismPlayTests.swift` (known actions win on the
  exact run; each failure named; budget failure on the exact action with one action either side; a run on the last
  action wins; 500 seeded traces replay; undo restores exact fingerprints; every refusal reason reachable); `--name
  host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [X] T-R02G1401-005 [P] [US4] Create `Packages/ExperiencesRound02/MoonlitMechanism/Core/MoonlitMechanismRules.swift` — Verified 2026-11-24: 2026-11-24: agent C PuzzleRules (move order, budget, run) with 5 tests incl. 200 walks agreeing with the real play; lead retest host-4 exit 0 (.autonomy/migration/checks/R02-G14-01.host-4.json)
  (agent C: `PuzzleRules`: State = position (phases, height, actions spent, outcome), Move = MoonlitMechanismAction;
  legal moves while playing "turn −1, +1; every re-seat (gear, then −1, +1); lamp −1, +1 when in range; then the run")
  with `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismRulesTests.swift` (agreement with the
  play on 200 walks); `--name host-4`
- [X] T-R02G1401-006 [P] Create — Verified 2026-11-24: 2026-11-24: agent D 9 invariant boundaries (time, input budget, goal, repeatability, undo, failure honesty, stability, save, renderer purity), each with a seeded neighbouring check (2_436), run against the real play and rules; host-5 exit 0 (.autonomy/migration/checks/R02-G14-01.host-5.json)
  `Packages/ExperiencesRound02/MoonlitMechanism/CoreTests/MoonlitMechanismInvariantTests.swift` (agent D:
  `testMoonlitMechanismTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each with
  a seeded neighbouring-input check, seed 2_436); `--name host-5`

## Phase 6: Regression, documentation and close

- [X] T-R02G1401-007 Docs: `docs/architecture/moonlit-mechanism.md` (new: rules), `Packages/ExperiencesRound02/README.md`, — Verified 2026-11-24: 2026-11-24: docs/architecture/moonlit-mechanism.md (rules), ExperiencesRound02 README section, testing doc entry; round02-host exit 0 (.autonomy/migration/checks/R02-G14-01.round02-host.json)
  `docs/automatedtesting.md`; `--name round02-host`
- [X] T-R02G1401-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`, — Verified 2026-11-24: 2026-11-24: rendering-27, rendering-26, experiences, host-full exit 0 (.autonomy/migration/checks/R02-G14-01.{rendering-27,rendering-26,experiences,host-full}.json)
  `--name host-full`
- [X] T-R02G1401-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-24: 2026-11-24: reference-1 exit 0 (.autonomy/migration/checks/R02-G14-01.reference-1.json)
- [ ] T-R02G1401-010 Reference regression chunk 2 (`--name reference-2`)
- [X] T-R02G1401-011 Script tests, run alone (`--name script-tests`) — Verified 2026-11-24: 2026-11-24: script-tests exit 0, run alone (.autonomy/migration/checks/R02-G14-01.script-tests.json)
- [ ] T-R02G1401-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record;
  README row and gate list updated

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, mechanics, level, fixtures, docs) stay with
the lead. Agents may draft in isolated copies before 001 (new files only). MVP: Story 1. Requirement coverage: FR-001,
009, 013 → 002; FR-002, 003, 014 → 002, 003; FR-004 … 008, 011 → 004; FR-010 → 005; FR-012 → 006; SC-001 … 005 →
002 … 006; SC-006 → 007 … 011.
