# Tasks: Infinite Geometry — Phase 02 2D kaleidoscope renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A05-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). No {device} task (no device-only claim).

## Phase 1: Setup

- [X] T-A05-201 Baseline: ExperiencesCreative on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name baseline -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.baseline.json (ExperiencesCreative sim-27.2, exit 0)

## Phase 2: Foundational — framework (US3)

- [X] T-A05-202 [P] [US3] Write `Packages/VisualCore/Tests/VisualCoreMathTests/CameraBoundsTests.swift` first, then `Packages/VisualCore/Sources/VisualCoreMath/CameraBounds.swift` per contracts/api.md (`ViewBounds2D` clamp, `Camera2D.panned(by:within:)`, `zoomed(by:within:)`, `OrbitBounds` clamp, `OrbitCamera.orbited(yaw:pitch:within:)`, `zoomed(by:within:)`); tests: 200 seeded random action sequences stay within bounds, non-finite inputs leave the camera unchanged, reset equality, pitch never beyond the limit (FR-A05-221, SC-A05-203) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.camera-host.json (CameraBoundsTests 7/7, exit 0)
- [X] T-A05-203 [P] [US3] Add `vc_sdCircle`, `vc_sdBox2`, `vc_sdSegment`, `vc_foldDihedral` to `Packages/VisualCoreRendering/Sources/VisualCoreRendering/GLSL/vc/sdf.glsl` and write `Packages/VisualCoreRendering/Tests/VisualCoreRenderingTests/SymmetryParityTests.swift`: GPU fold of a 16 × 16 grid encoded as colours equals `PointGroup.fold` within 1/255 for orders 1, 3, 6, 12; SDF signs inside/outside for each helper (FR-A05-220, SC-A05-202) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.rendering-ios27.json (SymmetryParityTests 2/2 on sim-27.2, exit 0)

## Phase 3: User Story 1 — the shader kaleidoscope (P1) 🎯

- [X] T-A05-204 [US1] Write `Packages/ExperiencesCreative/InfiniteGeometry/Experience/KaleidoscopeShader.swift` (fragment source including `vc/sdf.glsl`: motif polygon distance from `vc_sdSegment` with an inside test, folded by `vc_foldDihedral`, repeats rings, palette colour, one-pixel smoothstep; parameter mapping `u_order`, `u_repeats`, `u_scale`, `u_count`, `u_p0x`…`u_p6y`, `u_centerX`, `u_centerY`, `u_zoom`) and switch `Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryPresenter.swift` to draw the kaleidoscope with `FullScreenShaderScene` (setup/teardown/recreate; compile error → session failure) (FR-A05-201, 203) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.experiences-ios27.json and .experiences-ios26.json (exit 0); KaleidoscopeRenderTests
- [X] T-A05-205 [US1] Write `Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/KaleidoscopeRenderTests.swift`: render the kaleidoscope at orders 1, 3, 6, 12 through the session and read 64 point/image pixel pairs; ≥ 95% match within 2/255 (mirror-line pixels excluded); order 1 shows only motif and mirror (FR-A05-202, SC-A05-201) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.experiences-ios27.json and .experiences-ios26.json (exit 0); KaleidoscopeRenderTests orders 1/3/6/12 pass

## Phase 4: User Story 2 — camera (P1)

- [X] T-A05-206 [US2] Write `Packages/ExperiencesCreative/InfiniteGeometry/ExperienceTests/GeometryCameraTests.swift` first, then add camera state and actions to `Packages/ExperiencesCreative/InfiniteGeometry/Experience/Adapter/GeometryCore.swift` ("2D zoom 0.5…8 relative, centre within ±1/scale; 3D pitch ±80°, distance 3…12, yaw free"; `camera.pan [dx, dy]`, `camera.zoom [factor > 0]`, `camera.orbit [dyaw, dpitch]`, `camera.reset []`; snapshot schema 2 with a migration step from schema 1 using the preset's default camera; digest includes the camera) (FR-A05-210, 211, 213) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.experiences-ios27.json and .experiences-ios26.json (exit 0); GeometryCameraTests 6/6
- [X] T-A05-207 [US2] Map gestures in `Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryPresenter.swift` (`pointer`, `gestureActions`, `nativeActions`: drag → pan or orbit, pinch → zoom, double tap → reset) and add buttons in `Packages/ExperiencesCreative/InfiniteGeometry/Experience/GeometryControls.swift` (pan arrows, zoom in/out, orbit arrows, reset; labels and identifiers); apply the camera to the 2D primitive and shader paths and to the orbit camera (FR-A05-212) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.experiences-ios27.json and .experiences-ios26.json (exit 0)
- [X] T-A05-208 [US2] Regenerate `Packages/ExperiencesCreative/InfiniteGeometry/scenario-manifest.json` (`TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) and keep the five fixtures valid (FR-A05-230) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.experiences-ios27.json and .experiences-ios26.json (exit 0); manifest regenerated with TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1

## Phase 5: Polish and evidence (one task per quickstart command)

- [X] T-A05-209 Camera bounds host tests (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name camera-host -- swift test --package-path Packages/VisualCore --filter CameraBoundsTests`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.camera-host.json (exit 0)
- [X] T-A05-210 Rendering package on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name rendering-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/VisualCoreRendering --scheme VisualCoreRendering-Package --destination sim-27.2 --action test`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.rendering-ios27.json (424 cases, exit 0)
- [X] T-A05-211 Rendering package on sim-26.5 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name rendering-ios26 -- … --destination sim-26.5 --action test`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.rendering-ios26.json (424 cases, exit 0)
- [X] T-A05-212 Experiences package on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name experiences-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.experiences-ios27.json (exit 0)
- [X] T-A05-213 Experiences package on sim-26.5 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name experiences-ios26 -- … --destination sim-26.5 --action test`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.experiences-ios26.json (exit 0)
- [X] T-A05-214 App build and unit (`xcodegen generate --spec project.yml` first, then `python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.app-unit.json (xcodegen, build-for-testing and app unit on sim-27.2, exit 0)
- [X] T-A05-215 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 27`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.verify-27.json (0 failures)
- [ ] T-A05-216 Runner iOS 26 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name verify-26 -- python3 scripts/verify_experiences.py --only a05.infinite-geometry --runtime 26`) (SC-A05-204)
- [ ] T-A05-217 Public API and docs: `check_public_api.py --update`, `python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name public-api -- python3 scripts/check_public_api.py`; READMEs of VisualCore (camera bounds) and VisualCoreRendering (sdf.glsl helpers); Auto-Creator.md §13 rows (FR-A05-222, SC-A05-205)
- [X] T-A05-218 Reference chunk 1 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name reference-1 -- python3 scripts/release_check.py --only reference-engine-xcframework reference-build-projectm-ios-sim reference-clean`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.reference-1.json (exit 0)
- [X] T-A05-219 Reference chunk 2 (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name reference-2 -- python3 scripts/release_check.py --only reference-test-anglerendering-ios27 reference-test-anglerendering-ios26 projectm-reference-ios27 projectm-reference-ios26`) — Verified 2026-11-13: 2026-11-13 .autonomy/checks/A05-P02.reference-2.json (exit 0)
- [ ] T-A05-220 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A05-P02 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A05-221 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A05-P02

## Dependencies

T-A05-201 → (202 ∥ 203) → 204/205 (needs 203) and 206/207 (needs 202) → 208 → Polish.

## Parallel examples

Agent A: T-A05-202. Agent B: T-A05-203. Agent C: T-A05-204–207 (against contracts/api.md). Lead: 208, docs, runs, commits.

## Implementation strategy

MVP: shader kaleidoscope (US1) and camera (US2) on the framework pieces (US3); evidence last.
