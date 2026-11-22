# Tasks: R02-G07-01 — Amethyst Escape: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G07-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G07-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_361, neighbouring checks seed 2_366; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no GLSL
in this feature (the crystal state is the CPU reference the renderer of R02-G07-03 will consume).

## Phase 1: Setup

- [ ] T-R02G0701-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test
  --package-path Packages/ExperiencesRound02`; the rendering baseline is X-R02-G06's rendering runs (exit 0)

## Phase 2: Foundational

- [ ] T-R02G0701-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `AmethystEscapeCore`, `AmethystEscapeCoreTests`,
  product); create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeError.swift` (codes "r02-g07.level,
  .action, .stage, .stale, .stuck, .newer-schema, .malformed"), `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeLevel.swift`
  (shells "apertures (own sectors, sorted, non-empty)", "walls … at most N − 1", "blocked … never all"; "sectors 6 … 12",
  "shells 2 … 5", "start (sector of shell 0, not blocked)", "budget 1 … 60", "difficulty 1 … 5", "the outermost shell has
  exactly one aperture (the exit gap)"; shells and sectors named in words (FR-R02G0701-013); JSON schema 1 with sorted keys
  and fingerprint; decode re-checks), `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeCrystal.swift`
  (offsets and pearl; own sector "(sector − offset) mod N"; rotate ±1 with the pearl riding its own shell; the advance
  transition of clarification Q2 — outward through an aligned aperture (exit from the outermost shell), else clockwise
  unless wall j, else stuck; landing on a blocked wedge is `wedge`) and
  `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeFixtures.swift` (seeded levels with a known winning
  action sequence) with `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeLevelTests.swift`; `--name host`

## Phase 3: Story 1 — rotate and roll the pearl out (P1) 🎯

- [ ] T-R02G0701-003 [P] [US1] Create `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeCrystalTests.swift`
  (agent A: after every move the offsets and the pearl equal an independent pocket-graph reference written in the test,
  on 500 seeded levels and action sequences; a full turn of N steps is the identity; the pearl turns only with its own
  shell; transition priority outward, clockwise, stuck; exit only from the outermost shell's gap); `--name host-2`

## Phase 4: Stories 2 and 3 — wedge, budget, undo, redo, replay (P1)

- [ ] T-R02G0701-004 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapePlay.swift`
  (agent B: stages "loading, tutorial, playing, paused, won, failed, result"; actions validated for stage, previous
  fingerprint, range, stuck; each accepted rotate and advance spends one move; after a move exit, then wedge, then budget;
  failures wedge (shell, sector) and budget; records with previous and next fingerprints; full undo and redo (from failed
  back to playing; won is final); replay) with `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapePlayTests.swift`
  (known solutions win on the exact move; wedge and budget on the exact move with one move either side of the budget; an
  exit on the last move wins; 500 seeded traces replay; undo restores exact fingerprints; every refusal reason
  reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [ ] T-R02G0701-005 [P] [US4] Create `Packages/ExperiencesRound02/AmethystEscape/Core/AmethystEscapeRules.swift` (agent C:
  `PuzzleRules`: State = position (crystal, moves, outcome), Move = AmethystEscapeAction; legal moves while playing
  "rotate(r, +1), rotate(r, −1) for each shell r in order, then advance unless it is stuck") with
  `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeRulesTests.swift` (agreement with the play on 200
  walks); `--name host-4`
- [ ] T-R02G0701-006 [P] Create `Packages/ExperiencesRound02/AmethystEscape/CoreTests/AmethystEscapeInvariantTests.swift`
  (agent D: `testAmethystEscapeTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each with a
  seeded neighbouring-input check, seed 2_366); `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0701-007 Docs: `docs/architecture/amethyst-escape.md` (new: rules), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0701-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G0701-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0701-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0701-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0701-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, level, crystal, fixtures, docs) stay with
the lead. MVP: Story 1.
