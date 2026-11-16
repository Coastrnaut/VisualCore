# Tasks: Molecular Explorer — Phase 02 Camera/atom/bond renderer

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/renderer.md](contracts/renderer.md), [quickstart.md](quickstart.md). Gate A15-P02 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A15-P02 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. Precedent:
`specs/110-me-p01-domain-parser/tasks.md`.

## Phase 1: Setup

- [X] T-A15-201 Baseline: cite the A15-P01 evidence on the unchanged tree (`.autonomy/checks/A15-P01.{me-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-15: cited .autonomy/checks/A15-P01.me-ios27.json, A15-P01.app-unit.json and A15-P01.verify-27.json (exit 0) on the tree recorded at A15-P01, unchanged since apart from spec documents (no rerun)

## Phase 2: Foundational — the core (stories 1–3)

- [X] T-A15-202 [US3] Add `VisualCoreMath` to `MolecularExplorerCore` (and its tests) in `Packages/ExperiencesCreative/Package.swift`; create `Packages/ExperiencesCreative/MolecularExplorer/Core/{DisplayMode,MoleculeScene}.swift` per contracts/renderer.md ("atom radius factor 0.30 / 1.00 of the van der Waals radius; sticks only in ball-and-stick, radius 0.12 Å"; atom items one per atom; bond halves "two per recorded bond, ball-and-stick only" from the atom centre to the bond midpoint coloured by that atom; centre = mean of atom positions; bounding radius includes display radii; "at most 1,500 items") with `CoreTests/MoleculeSceneTests.swift` (water 3 atoms and 2 bonds, ethanol 9 and 8 — the manual's regression fixture; every half of all five molecules ends at its atom's centre and the midpoint within 1e-9 Å; space-filling has no halves and radius factor 1.00; a one-atom molecule has no halves and a bounding radius equal to its atom's display radius; deterministic) (FR-A15-201, 202, 210; SC-A15-201) — Verified 2026-11-15: core depends on VisualCoreMath; Core/DisplayMode (0.30/1.00 of the van der Waals radius, 0.12 Å sticks) and MoleculeScene (atom items, two halves per bond from each atom centre to the midpoint, centre, bounding radius, budget 1,500) with MoleculeSceneTests (water 3 atoms and 4 halves, ethanol 9 and 16; every half of all five molecules ends at its atom centre and the midpoint within 1e-9 Å; space-filling without halves; one-atom molecule; deterministic); written by an agent, retested in .autonomy/checks/A15-P02.me-core.json exit 0 (62 core tests)
- [X] T-A15-203 [US2] Create `Core/CameraSettings.swift` ("turnSteps 0…23 (15° each, wraps), tiltSteps −8…8 (10° each), zoomSteps −4…4 (×0.85 each)", default 2, 2, 0; framed distance = bounding radius × 1.25 / sin(30°) on the narrower axis; `camera(centre:boundingRadius:aspect:)` returns the `OrbitCamera`) with `CoreTests/CameraSettingsTests.swift` (turn wraps; tilt and zoom refuse beyond limits; target is the centre at every step; at +4 zoom the camera stays outside the bounding sphere for every library molecule and both aspects 0.5 and 2) (FR-A15-220; SC-A15-203) — Verified 2026-11-15: Core/CameraSettings (turn 15° wrapping, tilt 10° within ±80°, zoom 0.85 within ±4, default 2/2/0, framed OrbitCamera with fovY 60°, near and far around the molecule) with CameraSettingsTests (wraps, refusals unchanged, target at the centre, camera outside the bounding sphere at +4 for all molecules, both modes and aspects 0.5 and 2; smallest distance 1.305 bounding radii); retested in .autonomy/checks/A15-P02.me-core.json exit 0
- [ ] T-A15-204 [US2] Move `Core/MoleculeState.swift` to schema 2 (selection, mode, camera; "schema 1 → 2 with defaults; damaged or newer refused"; choosing a molecule resets the camera and keeps the mode) with `CoreTests/MoleculeStateSchema2Tests.swift` and the existing state tests updated (FR-A15-221; SC-A15-204)

## Phase 3: Stories 1–2 — the experience

- [ ] T-A15-205 [US1] Update `Experience/Adapter/MoleculeCore.swift` (actions `display.mode [0/1]`, `camera.orbit [−1/+1]`, `camera.tilt [−1/+1]`, `camera.zoom [−1/+1]`, `view.reset`; refusal `a15.camera-limit`; migration of schema 1 to 2 through `MigrationChain`; canvas description ending with the mode), `Experience/MoleculePresenter.swift` (scene drawing with one unit sphere and one unit stick renderer, model matrices per item, made and released together; legend "Display radii, not measured sizes"), `Experience/MoleculeControls.swift` (mode picker, Turn left/right, Tilt up/down, Zoom in/out, Reset view with values, identifiers `display-mode`, `turn-left`, `turn-right`, `tilt-up`, `tilt-down`, `zoom-in`, `zoom-out`, `reset-view`, `legend`) and the experience tests (`ExperienceTests/{MoleculeSceneRenderTests,MoleculeCameraTests}.swift` new; existing tests updated): both modes draw non-blank frames for every molecule and differ; every camera step changes the frame and keeps the centre at the canvas centre; limits refused; a schema-1 snapshot restores in schema 2; context recreation keeps the drawing (FR-A15-202, 210, 220, 230; SC-A15-202, 203, 204)
- [ ] T-A15-206 [US1] Manifest: add fixtures `fixture-caffeine-space-filling` and `fixture-benzene-turned` (three turns, one tilt up, two zoom-ins) to `Experience/Adapter/MoleculeManifest.swift`, pin their digests, re-pin changed digests, regenerate `scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`) and update `ExperienceTests/MoleculeManifestTests.swift` (FR-A15-231)

## Phase 4: Records and evidence

- [ ] T-A15-207 Contract `docs/apps/molecular-explorer/visualcore-contract.json`: G-RENDER (instancing assessed, not needed), G-CAMERA and G-DISPLAY (moved from phase 3 to 2) closed by "A15-P02"; rows whose gaps are all closed become available (`--name contract -- python3 scripts/check_app_contract.py --app molecular-explorer --render`)
- [ ] T-A15-208 Molecular Explorer tests on sim-27.2 (`--name me-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing MolecularExplorerCoreTests MolecularExplorerExperienceTests`) and the documented-API check (`--name documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/MolecularExplorer`) (SC-A15-201–205)
- [ ] T-A15-209 App build and unit (`--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a15.molecular-explorer --runtime 27`) (SC-A15-205)
- [ ] T-A15-210 Packages and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A15-211 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A15-P02; update README.md in the record commit (rule 16) and `docs/automatedtesting.md` if a test tool, rule or lesson changed (rule 17)

## Dependencies

T-A15-201 → 202 → 203 → 204 → 205 → 206 → 207 → 208 → 209 → 210 → 211.

## Parallel examples

Agent A: T-A15-202–204 (core). Agent B: T-A15-205 (experience) after A. Lead: Package.swift, manifest (206), contract,
runs, commits.

## Implementation strategy

MVP: the scene with the count fixture (202), the camera (203) and the state (204); then both modes and the camera drawn
(205–206). Review checkpoints after 204 (core tests) and at 208.
