# Tasks: R02-F05 — Procedural mesh compiler and mesh validation

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate R02-F05 (migration ledger). Evidence:
`python3 scripts/migration_ledger.py run-check --gate R02-F05 --name <check> -- <command>`. Commit after every task
(no trailers). No {device} or {owner} tasks: the feature is CPU-only and draws through the existing renderer.

## Phase 1: Setup

- [ ] T-R02F05-001 Record the baseline: host tests of Packages/VisualCore (`run-check --name baseline-host -- swift test --package-path Packages/VisualCore`)

## Phase 2: Foundational

- [ ] T-R02F05-002 Write `Packages/VisualCore/Tests/VisualCoreScenesTests/MeshBuilderTests.swift` first, then `Packages/VisualCore/Sources/VisualCoreScenes/MeshBuilder.swift`: `MeshBudget` ("default 262,144 vertices and 1,572,864 indices; both ≥ 0 and ≤ UInt32.max"), `MeshError` (.budget, .invalidInput), `MeshBuilder` with welding per research D1 and the clarified tolerances (relative 1e-9; positions-only option), budget refusal before growth, `build() -> Mesh`; tests: welding merges equal vertices only, insertion-order indices, a triangle with an out-of-range index is refused, budget refusal leaves the builder unchanged
- [ ] T-R02F05-003 [P] Write `Packages/VisualCore/Tests/VisualCoreScenesTests/MeshDigestTests.swift` first, then `Packages/VisualCore/Sources/VisualCoreScenes/MeshDigest.swift`: `Mesh.digest` per the clarification (little-endian counts, binary64 bit patterns with −0 as +0, indices; SHA-256 via `StableHash`; 64 lower-case hex); tests: equal meshes equal digests, any one-bit change differs, −0 equals +0
- [ ] T-R02F05-004 [P] Write `Packages/VisualCore/Tests/VisualCoreScenesTests/MeshBoundsTests.swift` first, then `Packages/VisualCore/Sources/VisualCoreScenes/MeshBounds.swift`: `MeshBounds` (.empty / .box(min:max:), `center`, `radius` of the enclosing sphere around the box centre, `contains(_:tolerance:)`), `Mesh.bounds`; tests: tight box (each face touches a vertex), every vertex contained, empty mesh gives .empty (FR-R02F05-040, SC-R02F05-004)

## Phase 3: User Story 2 — Refuse a bad mesh (P1)

- [ ] T-R02F05-005 [US2] Write `Packages/VisualCore/Tests/VisualCoreScenesTests/MeshValidationTests.swift` first: one planted defect per `MeshProblem.Kind` (14 kinds: indexOutOfRange, indexCountNotMultipleOfThree, arrayLengthMismatch, degenerateTriangle, nonFinitePosition, nonFiniteNormal, nonFiniteUV, nonUnitNormal, uvOutOfRange, nonManifoldEdge, inconsistentWinding, boundaryEdge (requireClosed), invertedFaces, budget) with exact kind and location; a valid closed cube reports none with its summary; 150 defects report 100 and count 50; text and JSON forms round-trip (FR-R02F05-030–032, 070; SC-R02F05-002)
- [ ] T-R02F05-006 [US2] Write `Packages/VisualCore/Sources/VisualCoreScenes/MeshValidation.swift`: `MeshProblem`, `MeshProblem.Kind`, `MeshSummary`, `MeshReport` (problemLimit 100, `moreProblems`, `isValid`, `description`, Codable), `Mesh.validate(requireClosed:budget:)` in the order of research D7; signed volume for closed meshes; validation never mutates; until T-R02F05-005 passes

## Phase 4: User Story 1 — Build a correct mesh (P1) 🎯

- [ ] T-R02F05-007 [P] [US1] Write `Packages/VisualCore/Tests/VisualCoreScenesTests/MeshNormalsTests.swift` first, then `Packages/VisualCore/Sources/VisualCoreScenes/MeshNormals.swift`: `withSmoothNormals(creaseAngle:)` (area- and angle-weighted; split by crease, research D2) and `withFlatNormals()`; tests: a cube with crease 30° keeps 24 corner normals sharp, with crease 100° shares 8; a sphere's smooth normals equal the radial direction within 1e-6; flat normals equal face normals; all unit
- [ ] T-R02F05-008 [US1] Write `Packages/VisualCore/Tests/VisualCoreScenesTests/MeshShapeTests.swift` first: for each shape (surface open and closed, revolution of a semicircle, extrusion with and without caps, tube straight capped, tube helix, tube closed loop, bevelled box radius 0 and r) at 3 resolutions: validator 0 problems (closed shapes requireClosed), exact faceted volume within 1e-6 relative, smooth volume within 1% at the highest resolution; boundary edges of open shapes equal the expected outline; edge cases of the spec (repeated path points, < 2 points refused, pole collapse, bevel clamp, clamped resolutions, self-intersecting outline refused, budget refusal); determinism (two builds equal digests); tube frames rotate by less than the path bend (FR-R02F05-010–015; SC-R02F05-001)
- [ ] T-R02F05-009 [US1] Write `Packages/VisualCore/Sources/VisualCoreScenes/MeshShapes.swift`: `Mesh.surface`, `.revolution`, `.extrusion`, `.tube` (double-reflection frames, closed-loop twist spread, research D3), `.bevelledBox` (research D6) through `MeshBuilder`, counter-clockwise from outside, unit normals, uvs in 0…1, exact-count budget check before building; until T-R02F05-008 passes

## Phase 5: User Story 3 — Bounds (P2)

- [ ] T-R02F05-010 [US3] Extend `Packages/VisualCore/Tests/VisualCoreScenesTests/MeshBoundsTests.swift` with every shape of T-R02F05-008: bounds contain 100% of vertices and each box face touches a vertex (SC-R02F05-004)

## Phase 6: User Story 4 — Existing meshes keep working (P3)

- [ ] T-R02F05-011 [US4] Write `Packages/VisualCore/Tests/VisualCoreScenesTests/MeshCompatibilityTests.swift`: plane, cube and sphere outputs equal digests committed in this task from the generators as they are (`git diff --exit-code Packages/VisualCore/Sources/VisualCoreScenes/MeshGenerators.swift` proves them unchanged), and pass the validator (cube and sphere with requireClosed: topology by welded position)
- [ ] T-R02F05-012 [US4] Write `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/MeshCompilerRuntimeTests.swift`: the committed digests of a fixed set of descriptions (one per shape) equal on the simulator; a capped tube drawn by `MeshRenderer` into an offscreen target covers at least 1% of the target's pixels with non-background colour and the context ends with 0 leaked objects

## Phase 7: Polish and evidence (one task per quickstart command)

- [ ] T-R02F05-013 Host tests (`run-check --name host -- swift test --package-path Packages/VisualCore`); a mesh at the budget builds and validates in < 1 s (printed timing) (SC-R02F05-006)
- [ ] T-R02F05-014 Rendering package on sim-27.2 (`run-check --name rendering-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test`)
- [ ] T-R02F05-015 Rendering package on sim-26.5 (`run-check --name rendering-ios26 -- … --destination sim-26.5 --action test`)
- [ ] T-R02F05-016 Experiences package on sim-27.2 (`run-check --name experiences-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`)
- [ ] T-R02F05-017 API baseline and documentation: `python3 scripts/check_public_api.py --update` then `run-check --name public-api -- python3 scripts/check_public_api.py`; `run-check --name documented-api -- python3 scripts/check_documented_api.py --sources Apps/VisualCore`; `Packages/VisualCore/README.md` mesh section; `docs/architecture/determinism.md` mesh digest entry; Auto-Creator.md §13 VisualCoreScenes row lists the new types
- [ ] T-R02F05-018 Reference regression chunk 1 (`run-check --name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`)
- [ ] T-R02F05-019 Reference regression chunk 2 (`run-check --name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`)
- [ ] T-R02F05-020 Script tests (`run-check --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-R02F05-021 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record R02-F05

## Dependencies

Setup → T-R02F05-002 → (003 ∥ 004 ∥ 005/006 ∥ 007) → 008/009 → 010 → 011/012 → Polish. Shapes depend on the builder;
validation is used by the shape tests.

## Parallel examples

Agent A: T-R02F05-002, 003, 004 (builder, digest, bounds). Agent B: T-R02F05-005, 006, 007 (validation, normals).
Agent C (after A's builder lands): T-R02F05-008, 009 (shapes). Lead: 011, 012, 017 and every run, tick and commit.

## Implementation strategy

MVP is the builder plus validation (US2) and the shapes (US1); bounds, compatibility and evidence follow.
