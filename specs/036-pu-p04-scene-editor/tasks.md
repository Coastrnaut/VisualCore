# Tasks: Particle Universe — Phase 04 Scene editor and persistence

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/actions.md](contracts/actions.md), [quickstart.md](quickstart.md). PU = `Packages/ExperiencesCreative/ParticleUniverse`.

Evidence: `python3 Tools/python/desktop_runbook.py run-check --stage A04-P04 --name <check> -- <command>`. Commit after
each task. Tests before code. Owner-only items: none. One {device} task. No VisualCore change.

## Phase 1: Setup

- [X] T-A04-401 Baseline: ExperiencesCreative on sim-27.2 passes before the change (check `baseline-experiences`). — Verified 2026-11-13: ExperiencesCreative on sim-27.2 passed before the change (desktop_runbook check A04-P04/baseline-experiences)

## Phase 2: Foundational — saved-scene format

- [X] T-A04-402 Tests first in `PU/CoreTests/SceneDocumentTests.swift` with fixtures `PU/CoreTests/Fixtures/scene-v1.json`, — Verified 2026-11-13: SceneDocumentTests 9 tests with fixtures scene-v1/v2/newer/nan/truncated (round trip, v1 migration, newer refused, NaN and truncated refused, name 1-64, ranges, open actions within 11 and 8 values, inverse defines) pass in ParticleUniverseCoreTests 50/50 on sim-27.2 (A04-P04/core-tests-ios27)
  `scene-v2.json`, `scene-newer.json`, `scene-nan.json`, `scene-truncated.json`: v2 round trip; v1 migrates with "no
  force" and default looks; newer refused (`unsupportedVersion`); NaN and truncated refused; name "1…64 characters after
  trimming"; force x, y "∈ [−500, 500]" and strength in `PlacedForce.strengthRange`; `openActions()` gives
  `scene.begin`, one `emitter.define` per emitter, `force.define`, `look.define` (at most 11, each ≤ 8 values).
- [X] T-A04-403 Write `PU/Core/SceneDocument.swift` (`SceneDocument`, `SavedForce`, decode with v1 migration, — Verified 2026-11-13: PU/Core/SceneDocument.swift (SceneDocument v2, SavedForce, decode with v1 migration, encoded, openActions, index mappings, inverse defines) and SceneError.invalidDocument; tests pass (A04-P04/core-tests-ios27)
  `openActions()`), documented.

## Phase 3: User Story 1 — Save a scene and open it again (P1)

- [X] T-A04-404 [P] [US1] Tests first in `PU/ExperienceTests/ParticleEditorTests.swift`: the open actions applied to a — Verified 2026-11-13: ParticleEditorTests 9 tests (open reproduces emitters, force, looks and keeps seed/limit/time scale/scene forces; no-force open; document round trip; replay digest 3 of 3; invalid define and missing begin rejected; wrong counts; move clamps and survives; draw cap) pass on sim-27.2 and 26.5 (A04-P04/experiences-ios27, experiences-ios26)
  core reproduce the document's scene, force and looks; `ParticleCore.document` (current state as a `SceneDocument`)
  round-trips; replaying a log containing an open reaches the same digest 3 of 3 times; an invalid define rejects the
  whole open (`a04.invalid-open`) and leaves the scene unchanged; a define without `scene.begin` is rejected.
- [X] T-A04-405 [US1] Implement in `PU/Experience/Adapter/ParticleCore.swift`: controls `scene.begin`, — Verified 2026-11-13: ParticleCore controls scene.begin, emitter.define, force.define, look.define with a pending open outside the anchor and atomic commit; document(name:); save-and-open scenario added, no existing digest changed, scenario-manifest.json regenerated; package passes on both runtimes
  `emitter.define`, `force.define`, `look.define` per contracts/actions.md; pending open not part of the anchor;
  `document` accessor. Update `PU/Experience/Adapter/ParticleManifest.swift` with a "save and open" scenario and
  regenerate digests and `PU/scenario-manifest.json` only where they change.
- [X] T-A04-406 [P] [US1] Tests first in `PU/ExperienceTests/ParticleLibraryTests.swift` (temporary — Verified 2026-11-13: ParticleLibraryTests 8 tests (save, list, open, numbered suffix, 64-char suffix, rename refusals, remove, unreadable kept, relaunch, storage full leaves files unchanged) pass on sim-26.5 and in both package runs
  `ExperienceStorage`): save, list, open data, rename (refused on clash), delete, numbered suffix on name clash,
  unreadable files counted and kept, relaunch (new library over the same storage) lists the same entries; a
  save beyond the storage limits (65th file) fails with a message and leaves the existing files unchanged (FR-A04-414).
- [X] T-A04-407 [US1] Write `PU/Experience/ParticleLibrary.swift` (the `FractalBookmarks` pattern, files — Verified 2026-11-13: PU/Experience/ParticleLibrary.swift (scene-<uuid>.json over ExperienceStorage, FractalBookmarks pattern); tests pass (experiences-ios27/26)
  `scene-<uuid>.json`).
- [X] T-A04-408 [US1] Wire: `PU/Experience/ParticleExperience.swift` `make(id:storage:reduceMotion:reduceFlashing:)`; — Verified 2026-11-13: ParticleExperience.make(id:storage:reduceMotion:reduceFlashing:), presenter holds ParticleLibrary, controls Saved scenes and Move emitter sections with labels, identifiers and 44-point buttons, registry passes launch.storage; app builds and interface tests pass (ui-scene-library-r4, ui-pu-j4-r3)
  `PU/Experience/ParticlePresenter.swift` holds the library and sends the open actions; `PU/Experience/ParticleControls.swift`
  Library section (identifiers `pu.library.*` per contracts/actions.md, labels, 44-point targets);
  `Apps/VisualCore/App/ExperienceRegistry.swift` passes `launch.storage`.
- [X] T-A04-409 [US1] Write `Apps/VisualCore/Tests/UI/ParticleUniverse/PUSceneLibraryUITests.swift`: save "Nebula", — Verified 2026-11-13: PUSceneLibraryUITests (save, change, open; relaunch, rename, delete) pass on the iOS 27.2 phone (55.7 s and 120.4 s; ui-scene-library-r4) and as release-check chunk j4 (ui-pu-j4-r3)
  change the scene, open "Nebula", relaunch and open again, rename, delete; add it to release-check chunk j3 in
  `scripts/release_check.py`; `xcodegen generate`.
- [X] T-A04-410 [US1] Acceptance: ExperiencesCreative on sim-27.2 (check `experiences-ios27`) and the UI test on the — Verified 2026-11-13: ExperiencesCreative on sim-27.2 PASS (experiences-ios27); scene-library interface tests PASS on the iOS 27.2 phone (ui-scene-library-r4) (SC-A04-401, 402)
  iOS 27.2 phone (check `ui-scene-library`) (SC-A04-401, 402).

## Phase 4: User Story 2 — Saved scenes are safe to open (P1)

- [X] T-A04-411 [US2] Acceptance: SceneDocumentTests' bad-file cases and ParticleLibraryTests' unreadable-file case — Verified 2026-11-13: SceneDocumentTests bad files (newer, NaN, truncated) refused, v1 opens; ParticleLibraryTests unreadable files counted and kept; pass on sim-27.2 and sim-26.5 (experiences-ios27, experiences-ios26) (SC-A04-403)
  pass (4 of 4 refused, v1 opens) within the T-A04-410 runs and on sim-26.5 (check `experiences-ios26`) (SC-A04-403).

## Phase 5: User Story 3 — Move an emitter (P2)

- [X] T-A04-412 [US3] Tests first in `ParticleEditorTests.swift`: `emitter.move` sets the selected emitter's position — Verified 2026-11-13: ParticleEditorTests move cases (clamp to +-500, family and overrides kept, survives document and open) pass (experiences-ios27)
  clamped to ±500 and keeps family and overrides; the move survives `document` → open.
- [X] T-A04-413 [US3] Implement `emitter.move` in `ParticleCore.swift` and four direction buttons (step 50, — Verified 2026-11-13: emitter.move control in ParticleCore and four direction buttons (50 points, move.left/right/up/down) in the Move emitter section; the interface test presses move.right before saving (ui-scene-library-r4)
  identifiers `pu.move.left|right|up|down`, labels) in `ParticleControls.swift`; UI test presses one and saves.
- [ ] T-A04-414 [US3] Acceptance: tests pass on sim-27.2 (check `experiences-ios27`) (SC-A04-404).

## Phase 6: User Story 4 — Gates hold for opened scenes (P2)

- [ ] T-A04-415 [US4] Tests first in `PU/CoreTests/PlacedForceStabilityTests.swift` (extend): for each of the 7 scene
  force kinds placed exactly on an emitter in a document that is opened, 600 steps stay finite; a document with 8
  emitters respects each tier's draw cap (adapter test in `ParticleEditorTests.swift`).
- [ ] T-A04-416 [US4] Acceptance: tests pass (check `experiences-ios27`) (SC-A04-405).

## Phase 7: Polish

- [ ] T-A04-417 `python3 scripts/check_compliance.py` (check `compliance`), `python3 scripts/test_scripts.py`
  (check `script-tests`), and `git diff --stat` over `Packages/VisualCore` and `Packages/VisualCoreRendering` for the
  phase's commits showing no change (FR-A04-432, FR-A04-442).
- [ ] T-A04-418 App unit tests and the PU interface chunks j2/j3 on the iOS 27.2 phone stay green (checks `app-unit`,
  `ui-pu`); test durations under 10 s each (SC-A04-406).
- [ ] T-A04-419 Update `docs/apps/particle-universe/README.md` with the editor and library.
- [ ] T-A04-420 {device} In the device campaign: save and open timings and GPU behaviour of opened scenes on D1, D2, D3.
- [ ] T-A04-421 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then
  seal and record the gate with `python3 Tools/python/desktop_runbook.py seal --stage A04-P04` and `record`.

## Dependencies

401 → 402–403 (format) → {404–405, 412–413 (one writer of ParticleCore), 406–407 (library)} → 408 → 409 → 410–411,
414–416 → 417–419 → 421.

## Parallel execution

Agent A: 402–403. Then Agent B: 404–405, 412–413, 415 (ParticleCore, manifest, editor and stability tests); Agent C:
406–407 (library). Lead: 408–409, acceptances, 417–421.
