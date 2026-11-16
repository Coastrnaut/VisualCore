# Tasks: Molecular Explorer — Phase 03 Selection and display styles

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/selection.md](contracts/selection.md), [quickstart.md](quickstart.md). Gate A15-P03 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A15-P03 --timeout 600 --name <check> -- <command>`. Commit
after every task (no trailers); read every check's exit before ticking. iOS 27 only. Precedent:
`specs/111-me-p02-renderer/tasks.md`.

## Phase 1: Setup

- [ ] T-A15-301 Baseline: cite the A15-P02 evidence on the unchanged tree (`.autonomy/checks/A15-P02.{me-ios27,app-unit,verify-27}.json`) instead of a rerun (owner ruling of 2026-11-14)

## Phase 2: Foundational — the core (stories 1–3)

- [ ] T-A15-302 [US2] Create `Packages/ExperiencesCreative/MolecularExplorer/Core/AtomPicker.swift` ("nearest positive hit against drawn radii; deterministic") with `CoreTests/AtomPickerTests.swift` (a ray through an atom's centre picks it in both modes; overlapping atoms give the nearest; a miss gives none; for all five molecules, both modes and eight camera positions (four turns × two tilts) the ray through each atom's projected centre picks the nearest atom along it — the manual's regression fixture) (FR-A15-310; SC-A15-301)
- [ ] T-A15-303 [US3] Create `Core/LabelLayout.swift` ("24 × 18 pt box 6 pt right/up of the projected centre; selected first, then by distance to the eye; no overlaps; off-canvas none") and `Core/BondStyle.swift` ("stick count (1, 2, 3), stick radius (0.12, 0.07, 0.06; inferred 0.06), offsets (0; ±0.09; 0, ±0.12 Å)"; side direction in the plane of a neighbouring bond, else perpendicular to the least-aligned axis), and extend `Core/MoleculeScene.swift` so each bond half carries its styled sticks, with `CoreTests/{LabelLayoutTests,BondStyleTests}.swift` and the scene tests updated (no overlaps for any molecule at the default view; off-canvas atoms unlabelled; the selected atom labelled first; caffeine's four double bonds give two sticks per half; benzene's double-bond sticks lie in the ring's plane; inferred bonds one thin stick; the item count stays within 1,500) (FR-A15-320, 321; SC-A15-303)
- [ ] T-A15-304 [US1] Extend `Core/CameraSettings.swift` with the pan ("panX, panY −10…10 (steps of 0.1 × bounding radius along view right/up)"; reset zeroes them; the camera target applies the pan) and move `Core/MoleculeState.swift` to schema 3 (selectedAtom "none or 0…atoms−1"; "schema 2 → 3 with no selection and no pan; molecule change clears selection and resets camera and pan; mode change keeps both"; selectAtom, nextAtom, previousAtom, clearAtom) with `CoreTests/MoleculeStateSchema3Tests.swift` and updated camera and state tests (FR-A15-302, 311, 330; SC-A15-304)

## Phase 3: Stories 1–3 — the experience

- [ ] T-A15-305 [US1] Create `Experience/MoleculeGestures.swift` (drag, pinch, two-finger pan and tap over `GestureArbiter` with the thresholds of clarification Q1; `reset()`), wire `MoleculePresenter.pointer(_:viewSize:port:)`, add the actions to `Experience/Adapter/MoleculeCore.swift` (`camera.pan [dx, dy]`, `atom.select [0…499]`, `atom.next`, `atom.previous`, `atom.clear`; refusals `a15.camera-limit`, `a15.invalid-choice`; migration chain 1 → 2 → 3) and the controls (Pan left/right/up/down, Previous atom, Next atom, Clear selection) to `Experience/MoleculeControls.swift`, with `ExperienceTests/{MoleculeGestureTests,MoleculePickingTests}.swift` (synthetic drags, pinches and two-finger moves give the same states as the buttons; a tap on an atom's projected centre selects it, on empty space clears; suspension mid-gesture sends nothing more; `camera.pan [0, 0]` and values other than −1, 0, 1 refused with `a15.invalid-choice`; schema-1 and schema-2 snapshots both open in schema 3 with no selection and no pan) (FR-A15-301, 302, 310, 311; SC-A15-301, 302)
- [ ] T-A15-306 [US3] Create `Experience/MoleculeOverlay.swift` (labels and the selection ring, hit testing off, size reported) returned by `makeCanvasOverlay`, draw the bond styles in `MoleculePresenter.swift`, add the panel lines, the description suffix and one announcement per action (selection changes announced), with `ExperienceTests/MoleculePanelTests.swift` and updated render tests (panel and description name the selected atom and its bonds with order and provenance; caffeine's double bonds change the drawn pixels compared with single sticks; at most one announcement per action) (FR-A15-320–323; SC-A15-303, 304)
- [ ] T-A15-307 [US2] Manifest: add `fixture-caffeine-picked` (atom 3 selected) and `fixture-water-panned` (two pans right, one up) to `Experience/Adapter/MoleculeManifest.swift`, re-pin every digest, regenerate `scenario-manifest.json` and update `ExperienceTests/MoleculeManifestTests.swift` (FR-A15-331)

## Phase 4: Records and evidence

- [ ] T-A15-308 Contract `docs/apps/molecular-explorer/visualcore-contract.json`: G-PICK and G-PANEL closed by "A15-P03"; rows whose gaps are all closed become available (`--name contract -- python3 scripts/check_app_contract.py --app molecular-explorer --render`)
- [ ] T-A15-309 Molecular Explorer tests on sim-27.2 (`--name me-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing MolecularExplorerCoreTests MolecularExplorerExperienceTests`) and the documented-API check (`--name documented-api -- python3 scripts/check_documented_api.py --sources Packages/ExperiencesCreative/MolecularExplorer`) (SC-A15-301–305)
- [ ] T-A15-310 App build and unit (`--name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) and runner (`--name verify-27 -- python3 scripts/verify_experiences.py --only a15.molecular-explorer --runtime 27`) (SC-A15-305)
- [ ] T-A15-311 Packages and script tests (`--name experience-packages -- python3 scripts/check_experience_packages.py`; `--name script-tests -- python3 scripts/test_scripts.py`)
- [ ] T-A15-312 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A15-P03; update README.md in the record commit (rule 16) and `docs/automatedtesting.md` if a test tool, rule or lesson changed (rule 17)

## Dependencies

T-A15-301 → 302 → 303 → 304 → 305 → 306 → 307 → 308 → 309 → 310 → 311 → 312.

## Parallel examples

Agent A: T-A15-302–304 (core). Agent B: T-A15-305–306 (experience) after A. Lead: manifest (307), contract, runs,
commits.

## Implementation strategy

MVP: picking with the occlusion fixture (302), then gestures and controls (305); labels, bond styles and the panel
(303, 306) complete the phase. Review checkpoints after 304 (core tests) and at 309.
