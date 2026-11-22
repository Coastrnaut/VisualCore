# Tasks: R02-G08-01 — Faceted Forge: playable rule kernel

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-G08-01 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-G08-01 --name <check> -- <command>` (never a scratchpad path;
recorded only after every agent has reported). Commit after every task with its check record (no trailers). Fixture seed
2_371, neighbouring checks seed 2_376; tests stay short (< 10 s each). No {owner} or {device} tasks (pure logic); no GLSL
in this feature (the pieces are the CPU reference the renderer of R02-G08-03 will consume).

## Phase 1: Setup

- [X] T-R02G0801-001 Baselines: `--name baseline-host`, `--name baseline-timing`, `--name baseline-round02 -- swift test — Verified 2026-11-22: baseline-host, baseline-timing, baseline-round02 exit=0; rendering baseline is X-R02-G07's visualcore-rendering run (exit 0)
  --package-path Packages/ExperiencesRound02`; the rendering baseline is X-R02-G07's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02G0801-002 Edit `Packages/ExperiencesRound02/Package.swift` (+ `FacetedForgeCore`, `FacetedForgeCoreTests`, — Verified 2026-11-22: host exit=0 (FacetedForgeFractionTests 4, FacetedForgeLevelTests 6: directions, cube geometry, range refusals, stored form, names, 500 fixtures closed and conserving volume)
  product); create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeError.swift` (codes "r02-g08.level,
  .action, .stage, .stale, .miss, .newer-schema, .malformed"),
  `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeFraction.swift` ("reduced, denominator > 0; checked +, −,
  ×, ÷; ordered; written n/d"), `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgePiece.swift` (the 13 named
  directions; half-spaces "sign·(n·p) ≤ sign·depth", depth "−24 … 24"; corners from plane triples satisfying every
  plane; faces "planes with ≥ 3 corners, corners ordered" round the outward normal; edges; face count; volume by signed
  tetrahedra; the cut of clarification Q2 with `.miss` unless a corner lies strictly on each side),
  `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeLevel.swift` ("crystal (4 … 14 half-spaces)", "bounded
  inside −6 … 6 with an interior", "budget 1 … 12", "sliver (fraction 0 < s < 1/2)", target "shares sum to 1; at least
  two entries", faces "4 … 26", "difficulty 1 … 5"; pieces, directions and targets named in words (FR-R02G0801-013);
  JSON schema 1 with sorted keys and fingerprint; decode re-checks) and
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeFixtures.swift` (seeded levels with a known winning
  cut sequence) with `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeFractionTests.swift` and
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeLevelTests.swift`; `--name host`

## Phase 3: Story 1 — cut the crystal into the target pieces (P1) 🎯

- [X] T-R02G0801-003 [P] [US1] Create `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgePieceTests.swift` — Verified 2026-11-22: host-2 exit=0 (FacetedForgePieceTests 5: corners and volume against an independent brute force and origin fan after every cut of 500 fixtures plus seeded cuts, halves partition, edges on two faces, degenerate planes refused)
  (agent A: after every cut the corners equal an independent brute force over all plane triples and the volume equals an
  independent divergence-theorem computation over the faces, on 500 seeded crystals and cut sequences; volumes sum to
  the crystal's; every edge lies on exactly two faces; the two halves partition the piece; degenerate planes are
  refused); `--name host-2`

## Phase 4: Stories 2 and 3 — sliver, budget, undo, redo, replay (P1)

- [X] T-R02G0801-004 [P] [US1] [US2] [US3] Create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgePlay.swift` — Verified 2026-11-22: host-3 exit=0 (FacetedForgePlayTests 12: fixtures win on the last cut, sliver at and below the limit, budget either side, 500 traces replay, undo exact, every refusal)
  (agent B: stages "loading, tutorial, playing, paused, won, failed, result"; actions validated for stage, previous
  fingerprint, range, miss; each accepted cut spends one cut; after a cut sliver, then win, then budget; failures sliver
  (piece, cut) and budget; pieces in canonical order; records with previous and next fingerprints; full undo and redo
  (from failed back to playing; won is final); replay) with
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgePlayTests.swift` (known solutions win on the exact
  cut; sliver at and below the limit; budget on the exact cut with one cut either side; a win on the last cut wins; 500
  seeded traces replay; undo restores exact fingerprints; every refusal reason reachable); `--name host-3`

## Phase 5: Story 4 — contract and invariants (P2)

- [X] T-R02G0801-005 [P] [US4] Create `Packages/ExperiencesRound02/FacetedForge/Core/FacetedForgeRules.swift` (agent C: — Verified 2026-11-22: host-4 exit=0 (FacetedForgeRules 6: move order, fixture solutions legal and winning, terminal positions, 200 walks agree with the play)
  `PuzzleRules`: State = position (pieces, cuts, outcome), Move = FacetedForgeAction; legal moves while playing "every
  non-degenerate cut, pieces in order, directions 0 … 12, depths ascending") with
  `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeRulesTests.swift` (agreement with the play on 200
  walks); `--name host-4`
- [X] T-R02G0801-006 [P] Create `Packages/ExperiencesRound02/FacetedForge/CoreTests/FacetedForgeInvariantTests.swift` — Verified 2026-11-22: host-5 exit=0 (FacetedForgeInvariantTests 9: time, input budget, goal, repeatability, undo, failure honesty, stability, save, renderer purity, each with seeded neighbouring inputs)
  (agent D: `testFacetedForgeTimeBoundary`, `…InputbudgetBoundary`, `…GoalBoundary`, `…RepeatabilityBoundary`,
  `…UndoBoundary`, `…FailurehonestyBoundary`, `…StabilityBoundary`, `…SaveBoundary`, `…RendererpurityBoundary`, each
  with a seeded neighbouring-input check, seed 2_376); `--name host-5`

## Phase 6: Regression, documentation and close

- [ ] T-R02G0801-007 Docs: `docs/architecture/faceted-forge.md` (new: rules), `Packages/ExperiencesRound02/README.md`,
  `docs/automatedtesting.md`; `--name round02-host`
- [ ] T-R02G0801-008 No Stage One breakage: `--name rendering-27`, `--name rendering-26`, `--name experiences`,
  `--name host-full`
- [ ] T-R02G0801-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02G0801-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02G0801-011 Script tests, run alone (`--name script-tests`)
- [ ] T-R02G0801-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Dependencies and parallel work

001 → 002 (lead) → {003 (agent A), 004 (agent B), 005 (agent C), 006 (agent D)} → 007 … 012. Agents C and D code
against the play contract in contracts/api.md; shared files (package, error, fraction, piece, level, fixtures, docs)
stay with the lead. MVP: Story 1.
