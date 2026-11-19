# Tasks: R02-F08 — Curve, ribbon and tube batch renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F08 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F08 --name <check> -- <command>`. Commit after every task
(no trailers). No {owner} tasks; large-batch draw cost on D1–D3 is a {device} campaign item.

## Phase 1: Setup

- [X] T-R02F08-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore` and — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F08.{baseline-host,baseline-rendering}.json (exit 0)
  `--name baseline-rendering --` the VisualCoreRendering scheme on sim-27.2

## Phase 2: Story 1 — adaptive curves (P1) 🎯

- [X] T-R02F08-002 [US1] Create `Packages/VisualCore/Sources/VisualCoreScenes/CurveSplines.swift` (`ParametricCurve`, — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F08.host.json (swift test exit 0; 18 of 18 curve/tolerance cases within tolerance, worst ratio 0.996)
  `CubicBezierChain` — open 3n + 1, closed 3n control points, n ≥ 1, finite; `CatmullRomSpline` — centripetal alpha 0.5,
  ≥ 2 distinct points open with phantom end points, ≥ 3 closed; exact positions and derivatives) and
  `Packages/VisualCore/Sources/VisualCoreScenes/CurveSampler.swift` (`CurveSamples`; `CurveSampler.sample` per
  clarification Q2: 5 interior points, depth 20, at least one split unless collinear, ≤ 65,536 samples, finite
  positive tolerance, cumulative chord arc lengths), with tests
  `Packages/VisualCore/Tests/VisualCoreScenesTests/CurveSplineTests.swift` (end points interpolated, derivative vs
  finite differences, refusals) and `CurveSamplerTests.swift` (6 reference curves × 3 tolerances within tolerance, measured against the spline itself on 1,000 points per
  segment; the circle, helix, trefoil and Lissajous figure are Catmull-Rom splines through points of the analytic
  shape (closed where it closes), the S curve a two-segment Bézier chain; the straight line is a one-segment Bézier
  with collinear control points → 2 samples; budget refusal; deterministic; analyze A1, A2)

## Phase 3: Story 2 — frames (P1)

- [X] T-R02F08-003 [US2] Create `Packages/VisualCore/Sources/VisualCoreScenes/CurveFrames.swift` (`CurveFrame`, — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F08.host.json (orthonormal 2.2e-16; seams 3.5e-17; agreement with pathFrames 2.2e-16; closed curves allow the closing twist spread)
  `CurveFrames.parallelTransport` per clarification Q3: scale-aware collapse 1e-9 × (1 + extent), reversal tangent from
  the chord ahead, normal kept at a reversal, `initialNormal` or least-parallel axis, closed twist spread by arc length)
  with `Packages/VisualCore/Tests/VisualCoreScenesTests/CurveFrameTests.swift` (orthonormal within 1e-9; rotation ≤
  bend + 1e-9 on helix, trefoil, Lissajous, a 180° reversal and repeated points; closed curves close within 1e-9;
  agreement with the existing internal tube frames on a helix)

## Phase 4: Story 3 and 4 — ribbons, tubes, merge (P1, P2)

- [X] T-R02F08-004 [US3] [US4] Create `Packages/VisualCore/Sources/VisualCoreScenes/CurveMeshes.swift` — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F08.host.json (CurveMeshTests; existing tube digests unchanged; tiled v reports only uvOutOfRange)
  (`RibbonWidth`; `Mesh.ribbon` per clarification Q4 and data-model "Ribbon mesh"; `Mesh.tube(samples:radius:sides:
  caps:repeatLength:budget:)`; `Mesh.merged` per clarification Q5) with
  `Packages/VisualCore/Tests/VisualCoreScenesTests/CurveMeshTests.swift` (v grows 1 per repeat length within 1e-9; closed
  seams match; per-sample width followed; zero/non-finite widths refused; ribbons and tubes validate (open/closed as
  expected); merge of 200 meshes has summed counts, offset indices, validates; budget refusal; existing `Mesh.tube`
  output unchanged)
- [X] T-R02F08-005 Host checkpoint: `--name host -- swift test --package-path Packages/VisualCore` — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F08.host.json (exit 0)
- [X] T-R02F08-006 [US4] Create `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/CurveBatchRuntimeTests.swift`: — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F08.{rendering-27,rendering-26}.json (exit 0; CurveBatchRuntimeTests: 200 merged ribbons, one draw, every centre lit)
  200 ribbons on a grid merged and drawn by one `MeshRenderer` draw; pixels at every ribbon's projected centre differ
  from the background; `--name rendering-27` and `--name rendering-26` (the VisualCoreRendering scheme on sim-27.2 and
  sim-26.5)

## Phase 5: Regression, documentation and close

- [X] T-R02F08-007 No Stage One breakage: `--name experiences --` ExperiencesCreative on sim-27.2 — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F08.experiences.json (exit 0)
- [X] T-R02F08-008 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F08.{public-api,documented-api}.json (exit 0; 3206 lines); README, determinism.md section 10, section 13.4 as built
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; section in `Packages/VisualCore/README.md`;
  curve rules in `docs/architecture/determinism.md`; section 13.4 row R02-F08 "As built" in
  `docs/catalog/shared-feature-map.json` and `render_autocreator.py`
- [X] T-R02F08-009 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F08.reference-1.json (exit 0)
- [X] T-R02F08-010 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F08.reference-2.json (exit 0)
- [X] T-R02F08-011 Script tests (`--name script-tests`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F08.script-tests.json (exit 0)
- [X] T-R02F08-012 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record — Verified 2026-11-19: 2026-11-19 converge round 2 clean; .autonomy/migration/evidence/R02-F08.json sealed (11 passing); R02-F08 recorded pass
  R02-F08; README.md and `docs/automatedtesting.md`

## Dependencies

001 → 002 → 003 → 004 → 005 → 006 → 007 → 008 → 009 → 010 → 011 → 012.

## Parallel examples

- **Agent A:** 002, 003, 004 in one package (one builder). **Lead:** 001, 005–012.

## Phase 6: Convergence

- [X] T-R02F08-013 Record in `specs/208-curve-ribbon-and-tube-batch-renderer/data-model.md` that a ribbon or tube whose v — Verified 2026-11-19: 2026-11-19 data-model.md Ribbon mesh records uvOutOfRange for tiled v (matches CurveMeshTests); validate_docs PASS
  tiles beyond 1 (repeat length shorter than the curve) is reported by `Mesh.validate` only as `uvOutOfRange` (the
  validator's 0…1 rule is for atlased meshes) and validates fully when the repeat length is the curve length, per
  data-model "Ribbon mesh" (contradicts)
- [X] T-R02F08-014 Record in `research.md` and `data-model.md` that on closed curves the frame rotation bound is the bend — Verified 2026-11-19: 2026-11-19 research.md R6 and data-model.md record the closed-curve rotation bound (matches CurveFrameTests)
  plus the closing twist spread per step (|closing angle| × step / length), open curves keep the strict bound, per
  SC-R02F08-002 (partial)
- [X] T-R02F08-015 Record the as-built API in `contracts/api.md`: `CurveSamples.init(positions:closed:)`, — Verified 2026-11-19: 2026-11-19 contracts/api.md As built (names checked by grep in CurveSampler.swift)
  `CubicBezierChain.controlPoints(segment:)`, `CatmullRomSpline.neighbourhood(segment:)` and `alpha`,
  `CurveSampler.maxDepth`, the budget clamp to 2…65,536, `Mesh.merged` refusing mismatched attribute counts, closed
  frames returning count + 1 with a seam frame, and no welding in ribbons and tubes, per contracts/api.md (partial)
