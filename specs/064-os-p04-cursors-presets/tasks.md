# Tasks: Oscilloscope Studio — Phase 04 Cursors, freeze and presets

**Input**: [spec.md](spec.md), [plan.md](plan.md), [research.md](research.md), [data-model.md](data-model.md),
[contracts/api.md](contracts/api.md), [quickstart.md](quickstart.md). Gate A08-P04 (legacy). Evidence:
`python3 Tools/python/desktop_runbook.py run-check --stage A08-P04 --timeout 600 --name <check> -- <command>`. Commit after every task (no trailers). iOS 27 only; reference regression at X-A08
(owner, 2026-11-14). No VisualCore change.

## Phase 1: Setup

- [X] T-A08-401 Baseline: cite the A08-P03 evidence on the unchanged tree (`.autonomy/checks/A08-P03.scope-ios27.json`, `.autonomy/checks/A08-P03.app-unit.json`, `.autonomy/checks/A08-P03.verify-27.json`) instead of a rerun (owner ruling of 2026-11-14) — Verified 2026-11-14: 2026-11-14: tree unchanged since the A08-P03 record; cites .autonomy/checks/A08-P03.{scope-ios27,app-unit,verify-27}.json

## Phase 2: Foundational (core)

- [X] T-A08-402 [P] Core in `Packages/ExperiencesCreative/OscilloscopeStudio/Core/`: `ScopeState` schema 3 ("frozen: Bool, cursorsShown: Bool, cursorA, cursorB, frequencyCursor ∈ [0, 1], levelCursor ∈ [−1, 1] (finite; NaN refused)"; schema-2 payloads decode with "false, false, 0.25, 0.75, 0.5, 0.5"); `ScopeReadout.swift` (Δt rounded to the sample period, three significant digits, µs below 0.1 ms, "1 sample" wording; 1/Δt whole Hz, "(limited by the sample period)" under 10 samples; "cursors coincide" at Δt 0; level two decimals of full scale and dBFS to 0.1 dB; "at or beyond full scale" at |x| ≥ 1; spectrum cursor frequency rounded to the bin width with "± <bin width> Hz"); `ScopePreset.swift` (format 1, `scope-<lowercased uuid>.json`, "name 1…40 characters after trimming", settings without source, freeze or cursors; greater format → newer; three built-ins with ids `00000000-0000-4000-8000-0000000008a1…a3`: "Audio overview", "Bass detail", "Spectrum check"); `ScopeZoom.swift` (one timebase step per doubling of the pinch scale, clamped 0…5); tests `CoreTests/{ScopeStateTests,ScopeReadoutTests,ScopePresetTests,ScopeZoomTests}.swift` (FR-A08-402–404, 410, 411; SC-A08-402, 403, 405) — Verified 2026-11-14: 2026-11-14: ScopeState schema 3, ScopeReadout, ScopePreset, ScopeZoom + tests; OscilloscopeStudioCoreTests 74 tests pass on sim-27.2

## Phase 3: User Story 1 — freeze a moment and measure it (P1) 🎯

- [X] T-A08-403 [US1] Experience: `ScopeCore` schema 3 with migration 2 → 3 and `schemaTwoExample()` (registry passes schema-1 and schema-2 examples in `Apps/VisualCore/App/ExperienceRegistry.swift`); actions `freeze.set [0…1]`, `cursors.show [0…1]`, `cursor.a`, `cursor.b`, `cursor.frequency [0…1]`, `cursor.level [−1…1]`, `preset.apply [0…N−1]` (rule `a08.invalid-preset`); `ScopePresenter` holds the frozen window (refuses to freeze an empty window with a message; releases it on a source change; a restored frozen state freezes the next window), draws cursor lines, puts `ScopeReadout` text in `cursor.readout` and the description, feeds pointers to `PinchRecognizer` (`ScopeZoom` steps sent as `timebase.select`; ignored in the spectrum view) and drags the nearest cursor with one finger; `ScopeControls` adds Freeze, Cursors and cursor sliders with labels and identifiers per contracts/api.md; tests in `ExperienceTests/{ScopeCoreTests,ScopeSessionTests,ScopeRenderTests}.swift` (frozen window identical over 60 frames while ≥ 1,024 frames arrive; cursors one period apart on 100 Hz, 440 Hz, 1 kHz read the period and frequency; clipped sample reads "at or beyond full scale"; pinch 0.25/0.5/2/4 steps; restored frozen snapshot re-freezes; the spectrum frequency cursor reads its column's frequency "± <bin width> Hz" and level in dBFS (story 1 AC4); unfreeze resumes live drawing (story 1 AC5); freezing an empty window is refused; frozen and cursor frames non-blank) (FR-A08-401–404, 411, 412; SC-A08-401–403, 405) — Verified 2026-11-14: 2026-11-14: ScopeCore schema 3 (migration, 7 actions, schemaTwoExample), presenter freeze/cursors/pinch/drag, controls, registry examples; OscilloscopeStudioExperienceTests 51 pass on sim-27.2

## Phase 4: User Story 3 — save and reuse scope settings (P2)

- [X] T-A08-404 [US3] `Experience/ScopePresetStore.swift` mirroring `Packages/ExperiencesCreative/AudioOdyssey/Experience/JourneyPresetStore.swift` (built-ins first and read-only, save, rename, delete, reload; damaged and newer files kept unchanged and counted; failed writes leave nothing half-written); presenter and controls: preset list (`preset.<index>`), name field, save, rename, delete; tests `ExperienceTests/ScopePresetStoreTests.swift` (5 of 5 save/rename/apply/delete/reload cases; damaged and newer files byte-identical; a new session lists saved presets) (FR-A08-410; SC-A08-404) — Verified 2026-11-14: 2026-11-14: ScopePresetStore (built-ins first, save/rename/delete/reload, damaged/newer kept and counted) + presenter/controls list; ScopePresetStoreTests pass on sim-27.2

## Phase 5: User Story 4 — the precision fixture (P2)

- [X] T-A08-405 [US4] Extend `Experience/Adapter/ScopeManifest.swift` with fixtures for freeze with cursors, zoom steps (`timebase.select` as pinch would) and a built-in preset applied; regenerate `scenario-manifest.json` (`UPDATE_SCENARIO_MANIFEST=1 TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`); update `ExperienceTests/ScopeManifestTests.swift` (FR-A08-420) — Verified 2026-11-14: 2026-11-14: manifest fixtures 10 (freeze with cursors), 11 (zoom steps), 12 (preset applied); manifest regenerated (12 fixtures); ScopeManifestTests pass

## Phase 6: Polish & evidence

- [X] T-A08-406 Oscilloscope Studio tests on sim-27.2 (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P04 --timeout 600 --name scope-ios27 -- python3 scripts/xcodebuild_package.py --package Packages/ExperiencesCreative --scheme ExperiencesCreative-Package --destination sim-27.2 --action test --only-testing OscilloscopeStudioCoreTests OscilloscopeStudioExperienceTests`; each test < 10 s) (SC-A08-405) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A08-P04.scope-ios27.json exit 0 (core 74, experience 51, manifest 4; each test < 10 s)
- [X] T-A08-407 App build and unit (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P04 --timeout 600 --name app-unit -- python3 scripts/release_check.py --only app-build-for-testing-ios27 app-unit-ios27`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A08-P04.app-unit.json exit 0 (registry with schema-1 and schema-2 examples)
- [X] T-A08-408 Runner iOS 27 (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P04 --timeout 600 --name verify-27 -- python3 scripts/verify_experiences.py --only a08.oscilloscope-studio --runtime 27`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A08-P04.verify-27.json exit 0 (nine standard + twelve fixture scenarios)
- [X] T-A08-409 Experience package check and the no-network/no-recording scan (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P04 --timeout 600 --name experience-packages -- python3 scripts/check_experience_packages.py`; `python3 Tools/python/desktop_runbook.py run-check --stage A08-P04 --timeout 600 --name os-no-network -- /bin/sh -c "! grep -rnE 'URLSession|import Network|AVAudioRecorder|AVAssetWriter' Packages/ExperiencesCreative/OscilloscopeStudio"`) (FR-A08-430) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A08-P04.experience-packages.json and A08-P04.os-no-network.json exit 0
- [X] T-A08-410 Contract: G-SCOPEINTERACT closed by "A08-P04" (rows M13 and M14 available with the experience as example; M13 notes that capture is the frozen window with metadata and image export is a later idea; M21 notes `ScopePresetStore`) and `python3 Tools/python/desktop_runbook.py run-check --stage A08-P04 --timeout 600 --name contract -- python3 scripts/check_app_contract.py --app oscilloscope-studio --render` — Verified 2026-11-14: 2026-11-14: contract M13, M14 available, M21 notes ScopePresetStore, G-SCOPEINTERACT closed by A08-P04; .autonomy/checks/A08-P04.contract.json exit 0
- [X] T-A08-411 Script tests (`python3 Tools/python/desktop_runbook.py run-check --stage A08-P04 --timeout 600 --name script-tests -- python3 scripts/test_scripts.py`) — Verified 2026-11-14: 2026-11-14: .autonomy/checks/A08-P04.script-tests.json exit 0
- [ ] T-A08-412 Run `/speckit-converge` and `/speckit-implement` until nothing is appended; then seal and record A08-P04

## Dependencies

T-A08-401 → 402 → (403 ∥ 404, both need 402; 404's controls part after 403) → 405 → Polish.

## Parallel examples

Agent A: T-A08-402. Agent B: T-A08-404 store and tests after A. Agent C: T-A08-403 after A. Lead: registry examples,
405, contract, runs, commits.

## Implementation strategy

MVP: freeze and cursors with precise readouts (US1, US4 rules); then zoom and presets; evidence last.

## Phase 7: Convergence

- [ ] T-A08-413 Record in `specs/064-os-p04-cursors-presets/contracts/api.md` the presenter-only rule `a08.nothing-to-freeze` (an empty window cannot be frozen) and the identifiers `display.hint`, `preset.message` and `preset.skipped` that the controls use, per contracts/api.md (unrequested)
