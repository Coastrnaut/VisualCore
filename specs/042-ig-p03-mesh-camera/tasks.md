# Tasks: Infinite Geometry — Phase 03 3D mesh and camera

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A05-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). No device task (no device-only claim).

## Phase 1: Setup

- [X] T-A05-301 Baseline: ExperiencesCreative on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name baseline -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P03.baseline.json (ExperiencesCreative sim-27.2, exit 0)

## Phase 2: Foundational (VisualCore, story 3)

- [X] T-A05-302 [P] [US3] Write `Packages/VisualCore/Tests/VisualCoreMathTests/OrbitViewBoundsTests.swift` first, then `Packages/VisualCore/Sources/VisualCoreMath/OrbitViewBounds.swift` per contracts/api.md (`OrbitViewBounds` with `minimumDistance(for:)` = "max(lower, |target| + clearance + 2·near)" and `clamp`; `OrbitCamera.forward/right/up`, `panned(by:within:)` with |target| ≤ targetRadius, `withFieldOfView(_:within:)`, `orbited`/`zoomed(within: OrbitViewBounds)`); tests: pan moves the target along right/up, 200 seeded random pan/zoom/fov/orbit sequences stay within every bound including the distance rule, non-finite inputs unchanged, clamp idempotent (FR-A05-321, SC-A05-304) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P03.camera-host-2.json (OrbitViewBoundsTests 9/9; attempt 1 failed on a test expectation contradicting the documented non-finite-clearance rule, test corrected)
- [X] T-A05-303 [P] [US3] Write `Packages/VisualCoreRendering/Sources/VisualCoreRendering/DepthMeshPass.swift` (owns a registry render target with depth at the context's pixel size; rebuild on size or registry generation change; clear colour+depth, depth test and write on, draw items through `MeshRenderer.draw`, restore state, blit colour to `context.framebuffer`; `release()`) and `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/DepthMeshPassTests.swift`: red and green cubes overlapping, both draw orders, nearer wins at every probe (larger channel > 0.25) on screen and through `renderOffscreen`; offscreen equals screen within 2/255; an offscreen capture at a different size (e.g. 64 × 48) still shows the nearer mesh at its probes; after `recreateContext()` the next frame matches and ledger counts are equal; empty item list clears; zero-size context draws nothing (FR-A05-320, SC-A05-301–303) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P03.rendering-ios27.json and .rendering-ios26.json (DepthMeshPassTests 6/6 each; mutation with depth test off fails the occlusion tests)

## Phase 3: User Story 1 — a solid composition that looks solid (P1) 🎯

- [ ] T-A05-304 [US1] Draw the 3D composition through `DepthMeshPass` in `Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryPresenter.swift` (pass created in setup, released in teardown; 2D presets unchanged) and write `Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/SolidOcclusionTests.swift`: the composition seen from yaw π shows the nearer petal at probe pixels (FR-A05-301–303)

## Phase 4: User Story 2 — move around without breaking the view (P2)

- [ ] T-A05-305 [US2] Write `Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/GeometryOrbitViewTests.swift` first, then extend `Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryCore.swift`: Orbit3D gains `target` ("|target| ≤ 1; default origin") and `fovDegrees` ("30…75; default 60"); `camera.pan` on the solid moves the target; `camera.fov [degrees]`; reset restores all; bounding radius from the built mesh; snapshot schema 3 with migration 2 → 3 (and 1 via 2); a restored camera outside the bounds is refused; camera in digest (FR-A05-310–314)
- [ ] T-A05-306 [US2] Map two-finger drag to 3D pan (centroid movement × 2·distance·tan(fov/2)/height, negated) alongside pinch in `GeometryPresenter.swift`; add "Wider"/"Narrower" (5°) buttons and enable pan buttons on the solid in `Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryControls.swift` with labels and identifiers; canvas accessibility value states the field of view on the solid, asserted in GeometryOrbitViewTests (FR-A05-315)
- [ ] T-A05-307 [US2] Extend fixture 3 in `Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryManifest.swift` (field of view at both bounds accepted, beyond refused; pan then maximum zoom stops at the distance rule), add the schema-2 example to `Apps/VisualCore/App/ExperienceRegistry.swift`, regenerate `Packages/ExperiencesCreative/InfiniteGeometry/scenario-manifest.json` (`TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) (FR-A05-330)

## Phase 5: Polish & evidence

- [X] T-A05-308 Orbit view bounds host tests (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name camera-host -- swift test --package-path Packages/VisualCore --filter OrbitViewBoundsTests`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P03.camera-host-2.json (exit 0)
- [X] T-A05-309 Rendering package on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name rendering-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P03.rendering-ios27.json (exit 0)
- [X] T-A05-310 Rendering package on sim-26.5 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name rendering-ios26 -- … --destination sim-26.5 --action test`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P03.rendering-ios26.json (exit 0)
- [ ] T-A05-311 Experiences package on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name experiences-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`)
- [ ] T-A05-312 Experiences package on sim-26.5 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name experiences-ios26 -- … --destination sim-26.5 --action test`)
- [ ] T-A05-313 App build and unit (`xcodegen generate --spec project.yml` first, then `python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`)
- [ ] T-A05-314 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 27`)
- [ ] T-A05-315 Runner iOS 26 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name verify-26 -- python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 26`) (SC-A05-305)
- [ ] T-A05-316 Public API and docs: `check_public_api.py --update`, `python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name public-api -- python3 scripts/check_public_api.py`; READMEs of VisualCore (OrbitViewBounds) and VisualCoreRendering (DepthMeshPass); Auto-Creator.md §13 rows (FR-A05-322, SC-A05-306)
- [ ] T-A05-317 Reference chunk 1 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`)
- [ ] T-A05-318 Reference chunk 2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`)
- [ ] T-A05-319 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P03 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A05-320 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A05-P03

## Dependencies

T-A05-301 → (302 ∥ 303) → 304 (needs 303) and 305/306 (need 302) → 307 → Polish.

## Parallel examples

Agent A: T-A05-302. Agent B: T-A05-303. Agent C: T-A05-304–306 (against contracts/api.md). Lead: 307, docs, runs, commits.

## Implementation strategy

MVP: depth-correct solid (US1) on the mesh pass (US3); then camera pan and field of view (US2); evidence last.
