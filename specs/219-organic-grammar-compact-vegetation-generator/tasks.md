# Tasks: R02-F19 — Organic grammar & compact vegetation generator

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F19 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F19 --name <check> -- <command>`. Commit after every task with
its check record (no trailers). No {owner} tasks; one {device} task. Fixture seed 2_019; tests stay short.

## Phase 1: Setup

- [X] T-R02F19-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and the isolated — Verified 2026-11-20: 2026-11-20 .autonomy/migration/checks/R02-F19.baseline-host.json and R02-F19.baseline-timing.json (exit 0); rendering baseline = R02-F18.rendering-27.json and rendering-26.json (exit 0)
  timing run; the rendering baseline is R02-F18's rendering runs (exit 0)

## Phase 2: Foundational

- [X] T-R02F19-002 Create `Packages/VisualCore/Sources/VisualCoreScenes/PlantError.swift` and `Packages/VisualCore/Sources/VisualCoreScenes/PlantGrammar.swift` (PlantRule "1 … 8 successors, each ≤ 256 — Verified 2026-11-20: lead 2026-11-20: R02-F19.host.json (exit 0, full suite; PlantGrammarTests 4 passed: every rule and grammar refusal with its code, byte-identical round trip, newer, out-of-range and damaged forms refused)
  symbols; weights finite > 0"; PlantGrammar "≤ 64 rules, unique predecessors; generations 0 … 12; δ finite 0 … π; step
  and radius finite > 0; radiusFactor 0 < k ≤ 1; JSON schema 1") with `Packages/VisualCore/Tests/VisualCoreScenesTests/PlantGrammarTests.swift` (every refusal and
  code; round trip byte for byte; schema 2 and damaged JSON refused); `--name host`

## Phase 3: Story 1 — grow branches (P1) 🎯

- [ ] T-R02F19-003 [P] [US1] Create `Packages/VisualCore/Sources/VisualCoreScenes/PlantTurtle.swift` (LSystem.derive per clarifications Q1–Q2, word ≤ 1,048,576;
  PlantBranch, PlantPart, PlantMarker, PlantSkeleton; PlantTurtle.interpret and grow; branches ≤ 65,536; unbalanced
  brackets refused) with `Packages/VisualCore/Tests/VisualCoreScenesTests/PlantTurtleTests.swift` (three hand-derived grammars give their exact words and branch
  counts; 100 seeded weighted grammars repeat and differ by seed in ≥ 95 of 100; frames orthonormal; known turtle
  positions; a grammar reopened from its stored form grows the identical skeleton; limits refused); `--name host-2`

## Phase 4: Story 2 — parametric parts (P1)

- [ ] T-R02F19-004 [P] [US2] Create `Packages/VisualCore/Sources/VisualCoreScenes/PlantShapes.swift` (PetalShape "0 < ℓ ≤ 100; 0 < w ≤ ℓ; abs(c) ≤ π; n 2 … 64",
  CapShape "0 < R ≤ 100; 0 < h ≤ 100; 0 ≤ d < h; s 8 … 128; k 2 … 64", StemShape "0 < L ≤ 100; r₀ ≥ r₁ > 0; abs(b) ≤ π;
  s 3 … 64; m 1 … 64") with `Packages/VisualCore/Tests/VisualCoreScenesTests/PlantShapesTests.swift` (200 seeded parameter sets: valid, within budget, stated length,
  radius or height within 1e-9; caps and stems closed; refusals); `--name host-3`

## Phase 5: Story 4 — scatter (P1)

- [ ] T-R02F19-005 [P] [US4] Create `Packages/VisualCore/Sources/VisualCoreScenes/PlantScatter.swift` (PlantInstance, PlantScatter per clarification Q4) with
  `Packages/VisualCore/Tests/VisualCoreScenesTests/PlantScatterTests.swift` (100 seeded scatters: spacing kept, inside the area, count ≤ maxCount, identical twice,
  model = T · R_y · S; empty area and bad parameters refused); `--name host-4`

## Phase 6: Story 3 — plant meshes (P2)

- [ ] T-R02F19-006 [US3] Create `Packages/VisualCore/Sources/VisualCoreScenes/PlantMesh.swift` (branches through `CurveMeshes.tube`, parts at markers, merged with
  `CurveMeshes.merged`) with `Packages/VisualCore/Tests/VisualCoreScenesTests/PlantMeshTests.swift` (50 seeded grammars: valid, within budget, vertex count equals the
  sum of parts, each part's origin at its marker within 1e-9); `--name host-5`

## Phase 7: Regression, documentation and close

- [ ] T-R02F19-007 No Stage One breakage: `--name rendering-27`, `--name rendering-26` and `--name experiences`
- [ ] T-R02F19-008 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/vegetation.md`; section
  in `Packages/VisualCore/README.md`; section 13.4 row R02-F19 "As built" in `docs/catalog/shared-feature-map.json` and
  `render_autocreator.py`
- [ ] T-R02F19-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02F19-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02F19-011 Script tests (`--name script-tests`)
- [ ] T-R02F19-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Device campaign (after ImplementationLock-100)

- [ ] T-R02F19-013 {device} Measure the frame cost of a dense instanced garden on D1–D3 and record it in the device
  campaign; never before `guard-device` passes

## Dependencies and parallel work

001 → 002 → {003, 004, 005} in parallel → 006 (needs 003 and 004) → 007 → … → 012. Agents: A (003), B (004), C (005).
Shared files (002, 006, docs) stay with the lead. MVP: Stories 1, 2 and 4.
