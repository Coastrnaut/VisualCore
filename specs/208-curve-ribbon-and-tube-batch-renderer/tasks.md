# Tasks: R02-F08 — Curve, ribbon and tube batch renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F08 --name <check> -- <command>`. Commit after every task
(no trailers). No {owner} tasks; large-batch draw cost on D1–D3 is a {device} campaign item.

## Phase 1: Setup

- [ ] T-R02F08-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and
  `--name baseline-rendering --` the VisualCoreRendering scheme on sim-27.2

## Phase 2: Story 1 — adaptive curves (P1) 🎯

- [ ] T-R02F08-002 [US1] Create `Packages/VisualCore/Sources/VisualCoreScenes/CurveSplines.swift` (`ParametricCurve`,
  `CubicBezierChain` — open 3n + 1, closed 3n control points, n ≥ 1, finite; `CatmullRomSpline` — centripetal alpha 0.5,
  ≥ 2 distinct points open with phantom end points, ≥ 3 closed; exact positions and derivatives) and
  `Packages/VisualCore/Sources/VisualCoreScenes/CurveSampler.swift` (`CurveSamples`; `CurveSampler.sample` per
  clarification Q2: 5 interior points, depth 20, at least one split unless collinear, ≤ 65,536 samples, finite
  positive tolerance, cumulative chord arc lengths), with tests
  `Packages/VisualCore/Tests/VisualCoreScenesTests/CurveSplineTests.swift` (end points interpolated, derivative vs
  finite differences, refusals) and `CurveSamplerTests.swift` (6 reference curves × 3 tolerances within tolerance on
  1,000 points per segment; straight line → 2 samples; budget refusal; deterministic)

## Phase 3: Story 2 — frames (P1)

- [ ] T-R02F08-003 [US2] Create `Packages/VisualCore/Sources/VisualCoreScenes/CurveFrames.swift` (`CurveFrame`,
  `CurveFrames.parallelTransport` per clarification Q3: scale-aware collapse 1e-9 × (1 + extent), reversal tangent from
  the chord ahead, normal kept at a reversal, `initialNormal` or least-parallel axis, closed twist spread by arc length)
  with `Packages/VisualCore/Tests/VisualCoreScenesTests/CurveFrameTests.swift` (orthonormal within 1e-9; rotation ≤
  bend + 1e-9 on helix, trefoil, Lissajous, a 180° reversal and repeated points; closed curves close within 1e-9;
  agreement with the existing internal tube frames on a helix)

## Phase 4: Story 3 and 4 — ribbons, tubes, merge (P1, P2)

- [ ] T-R02F08-004 [US3] [US4] Create `Packages/VisualCore/Sources/VisualCoreScenes/CurveMeshes.swift`
  (`RibbonWidth`; `Mesh.ribbon` per clarification Q4 and data-model "Ribbon mesh"; `Mesh.tube(samples:radius:sides:
  caps:repeatLength:budget:)`; `Mesh.merged` per clarification Q5) with
  `Packages/VisualCore/Tests/VisualCoreScenesTests/CurveMeshTests.swift` (v grows 1 per repeat length within 1e-9; closed
  seams match; per-sample width followed; zero/non-finite widths refused; ribbons and tubes validate (open/closed as
  expected); merge of 200 meshes has summed counts, offset indices, validates; budget refusal; existing `Mesh.tube`
  output unchanged)
- [ ] T-R02F08-005 Host checkpoint: `--name host -- swift test --package-path Packages/VisualCore`
- [ ] T-R02F08-006 [US4] Create `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/CurveBatchRuntimeTests.swift`:
  200 ribbons on a grid merged and drawn by one `MeshRenderer` draw; pixels at every ribbon's projected centre differ
  from the background; `--name rendering-27` and `--name rendering-26` (the VisualCoreRendering scheme on sim-27.2 and
  sim-26.5)

## Phase 5: Regression, documentation and close

- [ ] T-R02F08-007 No Stage One breakage: `--name experiences --` ExperiencesCreative on sim-27.2
- [ ] T-R02F08-008 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; section in `Packages/VisualCore/README.md`;
  curve rules in `docs/architecture/determinism.md`; section 13.4 row R02-F08 "As built" in
  `docs/catalog/shared-feature-map.json` and `render_autocreator.py`
- [ ] T-R02F08-009 Reference regression chunk 1 (`--name reference-1`)
- [ ] T-R02F08-010 Reference regression chunk 2 (`--name reference-2`)
- [ ] T-R02F08-011 Script tests (`--name script-tests`)
- [ ] T-R02F08-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record
  R02-F08; README.md and `docs/automatedtesting.md`

## Dependencies

001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010 → 011 → 012.

## Parallel examples

- **Agent A:** 002, 003, 004 in one package (one builder). **Lead:** 001, 005–012.
