# Tasks: R02-F12 — Convex solid clipping & polygon robustness

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F12 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F12 --name <check> -- <command>`. Commit after every task
(no trailers). No {owner} tasks. New public names checked against Packages and Apps (none used). Fixture seed 2_012
(`SDFTestRandom` of the VisualCoreScenes tests).

## Phase 1: Setup

- [X] T-R02F12-001 Baselines: `--name baseline-host -- swift test --package-path Packages/VisualCore`; the rendering — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F12.baseline-host.json (exit 0); rendering baseline = R02-F11.rendering-27-2.json and rendering-26.json (exit 0) at e0d50caf, package sources unchanged since R02-F11's last commit
  baseline is R02-F11's last rendering runs when package sources are unchanged since them

## Phase 2: Foundational

- [X] T-R02F12-002 [P] Create `Packages/VisualCore/Sources/VisualCoreScenes/ConvexSolidError.swift` (cases and `r2-f12.*` reason codes of the spec), `Packages/VisualCore/Sources/VisualCoreScenes/ClipPlane.swift` — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F12.host.json (exit 0; PolygonCleanupTests 4 passed: repeated/collinear removal, orientation, degenerate refusals, plane validation and nine reason codes)
  (normal "unit, from a finite non-zero input", kept unchanged when already unit within 1e-12; offset finite;
  `distance(to:)`; Codable) and `Packages/VisualCore/Sources/VisualCoreScenes/PolygonCleanup.swift` (merge points within tolerance, remove collinear corners
  within tolerance of the line through their neighbours, orient CCW about the normal, `.degeneratePolygon` below three
  corners) with `Packages/VisualCore/Tests/VisualCoreScenesTests/PolygonCleanupTests.swift` (repeated, collinear and nearly collinear points reduced to the corners;
  a reversed square reversed back; two-point and zero-area polygons refused; plane refusals and reason codes);
  `--name host`

## Phase 3: Stories 1 and 2 — cut and ledger (P1) 🎯

- [X] T-R02F12-003 [US1] Create `Packages/VisualCore/Sources/VisualCoreScenes/ConvexSolid.swift` (data-model.md: "≤ 4,096 vertices", "≤ 1,024 faces", "3…256 distinct — Verified 2026-11-19: lead retest 2026-11-19: R02-F12.host-3.json (exit 0, 0 failures; ConvexSolidTests 6 and ConvexCutTests 8 passed; first full run R02-F12.host-2 exit 1: the 1,024-plane limit fixture slowed the timed R02-F05 budget test, replaced by a direct bipyramid, research R7f)
  indices" per face, convex, CCW from outside; `box(min:max:)` with min < max; `bounded(by:min:max:)`; `init(mesh:)`
  accepting closed convex meshes per research R4; `diagonal`, `tolerance` = 1e-9 × diagonal, `volume` per research
  R3; `contains(_:)`; `cut(by:)` per research R2 returning `ConvexCutResult`; `mesh()` fanning faces with flat
  normals; Codable with re-validation) with `Packages/VisualCore/Tests/VisualCoreScenesTests/ConvexSolidTests.swift` (box volume and faces; bounded by planes gives
  the expected polyhedron (a tetrahedron, an octahedron); a mesh cube accepted, a non-convex and an open mesh refused;
  `mesh()` validates closed with equal volume) and `Packages/VisualCore/Tests/VisualCoreScenesTests/ConvexCutTests.swift` (unit cube through its centre on three
  axes and 100 seeded planes: parts sum within 1e-12 relative, both parts' meshes valid closed and outward; a missing
  plane keeps or removes the solid whole; planes through a vertex, an edge, a face and within ε of them leave no
  degenerate face in 100 fixtures; a sliver side is empty; a 1e-3 and a 1e3 cube give equal counts and rescaled
  vertices within 1e-12 relative; cutting repeatedly keeps the solid valid; a cut past the limits is refused
  `tooComplex`); `--name host-2`
- [X] T-R02F12-004 [US2] Create `Packages/VisualCore/Sources/VisualCoreScenes/VolumeLedger.swift` (data-model.md; "≤ 65,536 entries", refuse the next cut beyond — Verified 2026-11-19: lead retest 2026-11-19: R02-F12.host-4.json (exit 0, 0 failures; VolumeLedgerTests 4 passed: 1,000 seeded cuts balanced at every step and identical twice, miss and empty records, limit 3 refuses the 4th unchanged)
  and stay unchanged; `imbalance`, `isBalanced` at 1e-9) with `Packages/VisualCore/Tests/VisualCoreScenesTests/VolumeLedgerTests.swift` (1,000 seeded cuts
  balanced at every step; two runs identical; a cut that misses records 0 removed; the entry limit, tested through an
  internal `init(solid:maxEntries:)` used only by `@testable` tests, with 3 entries, rather than 65,536 cuts); `--name host-3`

## Phase 4: Stories 3 and 4 — stored form (P2)

- [X] T-R02F12-005 [US4] Create `Packages/VisualCore/Sources/VisualCoreScenes/ConvexSolidCoding.swift` (`ConvexSolidDocument`, schema 1 JSON with sorted keys; — Verified 2026-11-19: lead retest 2026-11-19: R02-F12.host-4.json (exit 0; ConvexSolidCodingTests 7 passed: byte-identical round trip, newer schema, truncated, not convex, index out of range, not closed, negative ledger volume)
  decode re-validates; `newerSchema`, `malformed`) with `Packages/VisualCore/Tests/VisualCoreScenesTests/ConvexSolidCodingTests.swift` (at least five fixtures: a
  cut solid with its ledger round-trips byte for byte; schema 2 refused; truncated JSON refused; a non-convex stored
  solid refused `notConvex`; a face with an index out of range refused `malformed`; an open stored solid refused
  `notClosed`); `--name host-4`

## Phase 5: Regression, documentation and close

- [X] T-R02F12-006 Simulator regression (no rendering change): `--name rendering-27` and `--name rendering-26`, and — Verified 2026-11-19: 2026-11-19 R02-F12.rendering-27.json, R02-F12.rendering-26.json and R02-F12.experiences.json (exit 0 each)
  `--name experiences` on sim-27.2
- [X] T-R02F12-007 API baseline and docs: `check_public_api.py --update`, `--name public-api`, `--name documented-api — Verified 2026-11-19: 2026-11-19 R02-F12.public-api.json and R02-F12.documented-api.json (exit 0; 3415 declarations, 0 undocumented); docs/architecture/convex-cutting.md; README section and section 13.4 note rendered; validate_autocreator PASS
  -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; new `docs/architecture/convex-cutting.md`
  (representation, tolerance, cut, ledger, degeneracy rules, stored form, reason codes, sources); section in
  `Packages/VisualCore/README.md`; section 13.4 row R02-F12 "As built" in `docs/catalog/shared-feature-map.json` and
  `render_autocreator.py`
- [X] T-R02F12-008 Reference regression chunk 1 (`--name reference-1`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F12.reference-1.json (exit 0)
- [X] T-R02F12-009 Reference regression chunk 2 (`--name reference-2`) — Verified 2026-11-19: 2026-11-19 .autonomy/migration/checks/R02-F12.reference-2.json (exit 0)
- [ ] T-R02F12-010 Script tests (`--name script-tests`)
- [ ] T-R02F12-011 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record

## Device campaign (after ImplementationLock-100)

- [ ] T-R02F12-012 {device} Measure the cut time of the largest solid (1,024 faces) on D1–D3 and record it in the device
  campaign; never before `guard-device` passes

## Dependencies and parallel work

001 → 002 → 003 → (004 ∥ 005) → 006 → 007 → 008 → 009 → 010 → 011. Agents: A (002), B (003 after 002), C (004 and 005
after 003). Shared files stay with the lead. MVP: Stories 1 and 2 (002, 003, 004).
