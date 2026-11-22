# Tasks: R02-G09-01 — Nocturne Garden: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G09-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G09-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_381, neighbouring checks seed 2_386; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no GLSL
in this feature (the blooms and the mask are the CPU reference the renderer of R02-G09-03 will consume).

## Phase 1: Setup

- [X] T-R02G0901-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: baseline-host, baseline-round02 exit 0; baseline-timing exit 1 under load (load average 13 right after the round-two suite: mesh build 5.96 s vs 5 s, analysis mean over 0.5), baseline-timing-2 exit 0; rendering baseline is X-R02-G08's visualcore-rendering run (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is X-R02-G08's visualcore-rendering run (exit 0)

## Phase 2: Foundational

- [ ] T-R02G0901-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `NocturneGardenCore`, `NocturneGardenCoreTests`,
  product); create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenError.swift` (codes "r02-g09.level, .action, .supply, .noop, .stage, .stale,
  .newer-schema, .malformed"), `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenBloom.swift` (the six kinds "tulip, bell, star, fern, rose, lily"
  as "simple polygons with integer vertices, foot at the origin, at most 16 vertices, within 3 × 6 cells at size 1";
  bloom "kind, column, row, size (1 … 3)"; the cast polygon "factor e/2 (1/2, 1, 3/2, 2) stretching y about each foot" in
  doubled coordinates; the cell test of clarification Q2: centre inside or on the boundary, exact winding number),
  `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenMask.swift` (union clipped to the bed; match by cross multiplication "|M ∩ T|·q ≥ p·|M ∪ T|",
  an empty union never wins; leak |M ∩ F|; boundary deviation as the symmetric Chebyshev Hausdorff distance between
  boundary cells), `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenLevel.swift` ("width 16 … 32, height 12 … 24", target cells non-empty,
  "forbidden cells (disjoint from the target)", "supply (count per kind, total 1 … 12)", sizes, elevations, opening
  sun, "budget 1 … 40", "required match p/q (0 < p/q ≤ 1)", "leak allowance ≥ 0", "difficulty 1 … 5"; blooms, regions
  and measures named in words (FR-R02G0901-013); JSON schema 1 with sorted keys and fingerprint; decode re-checks) and
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenFixtures.swift` (seeded levels with a known winning arrangement) with
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenLevelTests.swift`; `--name host`

## Phase 3: Story 1 — cast the target silhouette (P1) 🎯

- [ ] T-R02G0901-003 [P] [US1] Create `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenBloomTests.swift` (agent A: on 500 seeded blooms and
  elevations every cell decision equals an independent even-odd ray casting on rational coordinates with boundary
  points counted inside; the mask equals the union recomputed from scratch; match, leak and boundary deviation equal
  brute force over all cells and cell pairs; every outline is simple and within its stated bounds); `--name host-2`

## Phase 4: Stories 2 and 3 — leak, budget, undo, redo, replay (P1)

- [ ] T-R02G0901-004 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenPlay.swift` (agent B: stages "loading,
  tutorial, playing, paused, won, failed, result"; actions plant, move, resize, remove, sun validated for stage,
  previous fingerprint, range, supply, no-op; each accepted action spends one move; after an action leak, then win, then
  budget; failures leak (move) and budget; blooms in canonical order "row, column, kind, size"; records with previous
  and next fingerprints; full undo and redo (from failed back to playing; won is final); replay) with
  `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenPlayTests.swift` (known arrangements win on the exact action; leak at and above the
  allowance; budget on the exact action with one move either side; a win on the last move wins; 500 seeded traces
  replay; undo restores exact fingerprints; every refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [ ] T-R02G0901-005 [P] [US4] Create `Packages/ExperiencesRound02/NocturneGarden/Core/NocturneGardenRules.swift` (agent C: `PuzzleRules`: State = position
  (blooms, sun, moves, outcome), Move = NocturneGardenAction; legal moves while playing "plant by kind, row, column,
  size; then move, resize, remove by bloom; then sun") with `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenRulesTests.swift` (agreement
  with the play on 200 walks); `--name host-4`
- [ ] T-R02G0901-006 [P] Create `Packages/ExperiencesRound02/NocturneGarden/CoreTests/NocturneGardenInvariantTests.swift` (agent D:
  `testNocturneGardenTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each
  with a seeded neighbouring-input check, seed 2_386); `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0901-007 Docs: `docs/architecture/nocturne-garden.md` (new: rules), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0901-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G0901-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0901-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0901-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0901-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, bloom, mask, level, fixtures, docs) stay
with the lead. MVP: Story 1.
