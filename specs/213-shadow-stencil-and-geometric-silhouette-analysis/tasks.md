# Tasks: R02-F13 — Shadow stencil and geometric silhouette analysis

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F13 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F13 --name <check> -- <command>`. Commit after every task
(no trailers). No {owner} tasks. New public names checked against Packages and Apps (none used). Fixture seed 2_013.
Tests stay light (≤ 512 × 512 masks) so the timed R02-F05 budget test beside them keeps its bound (R02-F12 lesson).

## Phase 1: Setup

- [X] T-R02F13-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore`; the rendering — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F13.baseline-host.json (exit 0); rendering baseline = R02-F12.rendering-27.json and rendering-26.json (exit 0), package sources unchanged since R02-F12's last source commit
  baseline is R02-F12's last rendering runs when package sources are unchanged since them

## Phase 2: Story 1 — projection (P1) 🎯

- [X] T-R02F13-002 [P] [US1] Create `Packages/VisualCore/Sources/VisualCoreScenes/ShadowError.swift` (cases and `r2-f13.*` codes of clarification Q5), — Verified 2026-11-19: lead retest 2026-11-19: R02-F13.host.json (exit 0, 0 failures; VisualCoreScenes run 295 tests incl. ShadowProjectionTests 8 and ConvexHull2DTests 4; cube-down area error 2.2e-16, matrix vs project 4.9e-16)
  `Packages/VisualCore/Sources/VisualCoreScenes/ShadowProjection.swift` (`ShadowLight`, `ProjectionPlane` with the basis of Q1, `ShadowProjector` per Q2 and
  research R1–R2: point, triangle with slab clipping, mesh "≤ 1,048,576 triangles", solid outline as the hull of its
  projected vertices, `matrix(light:onto:)` equal to the CPU projection) and `Packages/VisualCore/Sources/VisualCoreScenes/ConvexHull2D.swift` (Andrew's chain,
  CCW, collinear dropped; signed area) with `Packages/VisualCore/Tests/VisualCoreScenesTests/ShadowProjectionTests.swift` (unit cube straight down → unit square
  within 1e-12 over 100 seeded rotations of the cube about y (area preserved); point light similar triangles h/(h−s);
  geometry above the light or below the ground casts nothing; a triangle crossing the light's slab is clipped, never
  flipped; parallel, on-plane and below-plane lights refused; the matrix maps 100 seeded points like `project` within
  1e-12; basis u × v = n for 100 seeded normals) and `Packages/VisualCore/Tests/VisualCoreScenesTests/ConvexHull2DTests.swift` (square with interior and collinear
  points → 4 corners CCW; 1,000 seeded points: every point inside or on the hull; area of the unit square 1; fewer
  than three distinct points → empty or degenerate as documented); `--name host`

## Phase 3: Story 2 — masks and IoU (P1)

- [X] T-R02F13-003 [P] [US2] Create `Packages/VisualCore/Sources/VisualCoreScenes/CoverageMask.swift` (`CoverageMask` per data-model.md: "1…2,048" per side, min < — Verified 2026-11-19: lead retest 2026-11-19: R02-F13.host.json (exit 0; CoverageMaskTests 8 passed: exact IoU 1/0/1/3, shared edges once, 100-polygon mean error 0.0039→0.0011 and worst 0.26% at 256², determinism, stored form; research R7)
  max, packed UInt64 rows with zero padding, `fill` by row-centre crossings with the half-open rule of research R4,
  `count`, `area`, `digest` FNV-1a 64, `cellCentre(x:y:)`; `MaskComparison` with IoU, both empty → 1, mismatch refused;
  `CoverageMaskDocument` schema 1 with base64 words) with `Packages/VisualCore/Tests/VisualCoreScenesTests/CoverageMaskTests.swift` (identical, disjoint and
  half-overlapping squares give IoU 1, 0, 1/3 exactly on aligned grids; two squares sharing an edge cover each cell once;
  a seeded convex polygon's area within 1% at 256² and the error at 256 at most half of 128; polygon clipped to the
  region; zero and 2,049 sizes refused; mismatched masks refused; two runs of 100 seeded scenes give identical digests;
  stored form round-trips byte for byte, schema 2 and bad padding refused); `--name host-2`

## Phase 4: Story 3 — drawing (P2)

- [X] T-R02F13-004 [US3] Create `Packages/VisualCoreRendering/Sources/VisualCoreRendering/PlanarShadowRenderer.swift` (contracts/api.md; coverage — Verified 2026-11-19: lead retest 2026-11-19: R02-F13.rendering-27.json and rendering-26.json (exit 0, 233 tests each) incl. PlanarShadowRendererTests 5 passed (0 mismatches vs CPU coverage, single darkening 0/255, parallel light and failed target draw nothing, zero leaks, context rebuild identical); research R8
  pass into a pooled target with `ShadowProjector.matrix`, no blending, then one full-screen composite with darkness
  and premultiplied blending; GL state restored; rebuild after context loss; target creation failure throws and draws
  nothing) with `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/PlanarShadowRendererTests.swift` (a cube and a self-overlapping
  shape (two overlapping boxes merged) drawn over a white background: covered pixels equal a `CoverageMask` of the same
  view at every pixel with a uniform 3 × 3 CPU neighbourhood; every shadow pixel has the single-shadow value; zero live
  GPU objects after destroy; a context rebuild gives the same picture); `--name rendering-27` and `--name rendering-26`

## Phase 5: Regression, documentation and close

- [X] T-R02F13-005 No Stage One breakage: `--name experiences --` ExperiencesCreative on sim-27.2 — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F13.experiences.json (exit 0)
- [X] T-R02F13-006 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api — Verified 2026-11-19: 2026-11-19 R02-F13.public-api.json and R02-F13.documented-api.json (exit 0; 3461 declarations, 0 undocumented); docs/architecture/shadow-silhouettes.md; both README sections and section 13.4 note rendered; validate_autocreator PASS
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/shadow-silhouettes.md`;
  sections in both package READMEs; section 13.4 row R02-F13 "As built" in `docs/catalog/shared-feature-map.json` and
  `render_autocreator.py`
- [X] T-R02F13-007 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F13.reference-1.json (exit 0)
- [X] T-R02F13-008 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F13.reference-2.json (exit 0)
- [X] T-R02F13-009 Script tests (`--name script-tests`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F13.script-tests.json (exit 0)
- [ ] T-R02F13-010 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Device campaign (after ImplementationLock-100)

- [ ] T-R02F13-011 {device} Measure the shadow drawing cost of a 10,000-triangle mesh at full screen on D1–D3 and record
  it in the device campaign; never before `guard-device` passes

## Dependencies and parallel work

001 → (002 ∥ 003) → 004 → 005 → 006 → 007 → 008 → 009 → 010. Agents: A (002), B (003), G (004 after 002 and 003). Shared
files stay with the lead. MVP: Stories 1 and 2.
