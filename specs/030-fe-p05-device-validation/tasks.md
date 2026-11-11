---

description: "Task list for feature 030 — Fractal Explorer Phase 05 device precision and performance validation (ledger gate A03-P05)"
---

# Tasks: Fractal Explorer — Phase 05 Device precision and performance validation

**Input**: `/specs/030-fe-p05-device-validation/`: the spec (3 clarifications plus checklist amendments), the plan,
research R1–R4, the data model, the contract and the quickstart.

**Tests are required**: VisualCoreAutomation package tests on 27.2/26.5; host tests for FractalExplorerCore; app
unit tests on both runtimes under the guard; simulator rehearsal (never device evidence); Release symbol checks; the
ProjectM regression and A01/A02 builds.

**Conventions**: IDs `T-A03-5##`, one commit per task through `scripts/tick_task.py`; commands through
`run-check --stage A03-P05`. No physical-device action in any task.

## Phase 1: Foundational — VisualCore G-AUTOMODE

- [X] T-A03-501 Tests first in `Packages/VisualCoreRendering/Tests/VisualCoreAutomationTests/AutomationRunnerTests.swift` (≥ 4 per the contract), then in `Packages/VisualCoreRendering/Sources/VisualCoreAutomation/`: `AutomationRunner.AppMode`, `appModes`, `allModes` (built-ins first; built-in names win, noted in the message), dispatch with `postRunCheck`/`checkNote`; `AutomationReport.measurements` and `details` (optional, omitted when nil); `AutomationView(…, appModes:)`. Docs, baseline; package tests on 27.2 and 26.5 with the guard; A02 builds and its AutomationTests still pass (FR-A03-501, SC-A03-501). — Verified 2026-11-11: — Verified 2026-11-11: VisualCoreAutomation app modes (AutomationRunner.AppMode, appModes, allModes; built-in names win and the message says so; app modes get postRunCheck/checkNote; unknown modes list all modes), AutomationReport.measurements/details (optional, omitted when nil), AutomationView(appModes:) passing the scene; documented and baselined. AutomationAppModeTests 4 (app mode fills frames/measurements/details, pass note, report round trip, allModes; domain check fails an app mode; built-in name wins and unknown lists app modes; old reports decode and nil fields are omitted) — run-check A03-P05/t501-rendering-27 and t501-rendering-26 TEST SUCCEEDED, enumeration 149/149 each; A02 AutomationTests 4/4 unchanged in t501-a02-automation; t501-checks 4/4
- [ ] T-A03-502 ProjectM regression (reference-a 3/3, reference-b 4/4), A01 and A02 `build-for-testing`, `public-api dependencies docs compliance` (FR-A03-507).

## Phase 2: User Story 3 — bookmark reproduction fixture (P1)

- [ ] T-A03-503 [P] [US3] Add `Apps/FractalExplorer/Tests/Unit/BookmarkReproductionTests.swift` per research R4: 10 seeded bookmarks (both modes, the 5 palettes, caps 50…2000) rendered 64 × 64 offscreen before saving and after reload into a fresh model at the same size ("every channel within 1 of 255"), and on a 2:1 canvas classes at 64 points vs the CPU reference ≥ 99%; every field equal after reload. Both runtimes (FR-A03-504, SC-A03-504).

## Phase 3: User Story 1 — precision mode (P1) 🎯

- [ ] T-A03-504 [P] [US1] Tests first, then `Apps/FractalExplorer/FractalExplorerCore/Sources/FractalExplorerCore/PrecisionLadder.swift` (zooms 4^i for "≤ 24 steps" from the Seahorse point; `Step` index/zoom/level/clamped/agreement; `verdict`: fail if a reliable step < 0.99, clamp step = first clamped, breakdown = first < 0.99, fail if breakdown < clamp; none-within-ladder cases; the plan ends early once PlaneViewport's own 1e-15 scale limit would be reached at the given canvas, analyze I1). `PrecisionLadderTests` ≥ 4. `swift test` (FR-A03-502, SC-A03-502).
- [ ] T-A03-505 [US1] Add `ExplorerModel(hosted: false)` (no own host; scene only) and `Apps/FractalExplorer/App/AppAutomation.swift` (`#if DEBUG || VISUALCORE_AUTOMATION`): AutomationView hosting `model.scene`, built-in modes with the check "no shader error", the `precision` app mode (capabilities, ladder rendered 64 × 64 unclamped through the scene, agreement vs CPU, level and clamp from the app's rules with the device bits and the view's display scale, measurements and details per the data model, verdict); route automation launches in `FractalExplorerApp.swift`; `project.yml` links VisualCoreAutomation. `AutomationModeTests` (precision mode against a recorder: pass, all measurements present, report decodes). Both runtimes (FR-A03-502, FR-A03-505).

## Phase 4: User Story 2 — tour mode (P1)

- [ ] T-A03-506 [US2] Add the `tour` app mode to `AppAutomation.swift`: all tours at 1/60 s tour steps (frames capped per tour by `VISUALCORE_AUTORUN_FRAMES` when set), `renderOneFrame(present: true)` timed per step, a still per stop at min(1024, the device's render limit) via `StillCapture` (analyze G1) compared at 64 points (≥ 99%), files removed, thermal state and Low Power Mode at start/end in details, frame-time statistics. `AutomationModeTests` gains the tour mode (capped frames: pass, stops 9, agreement measurements, no file left). Both runtimes (FR-A03-503, SC-A03-503).

## Phase 5: User Story 4 — rehearsal, release check and plan (P2)

- [ ] T-A03-507 [US4] Simulator rehearsal (not device evidence): build the Debug app, run `run_automation_sim.py` for smoke, launch, lifecycle, precision and tour on iOS 27.2 and 26.5 (reports under `.autonomy/logs/`); Release simulator build → `check_release_symbols.py` (absent), measurement build (Release + `VISUALCORE_AUTOMATION`) → `--expect-present` (FR-A03-505, FR-A03-506, SC-A03-503, SC-A03-505).
- [ ] T-A03-508 [US4] Write `docs/apps/fractal-explorer/device-campaign.md` (modes, variables, report fields, pass rules, rehearsal results labelled rehearsal, D1/D2/D3 rows "pending device campaign"); contract gate A03-P05 (G-AUTOMODE closed; M03/M10 device-measurement readiness), regression baseline, lessons, fast checks (FR-A03-506, FR-A03-507, SC-A03-506).

## Dependencies

- T-A03-501 → 502 (regression after the VisualCore change; gates the seal), 505, 506.
- T-A03-503 and T-A03-504 are independent of 501.
- 505 needs 501 and 504; 506 needs 505; 507 needs 506; 508 last.

## Parallel examples

- 503 ∥ 504 ∥ 501.

## Implementation strategy

VisualCore app modes first, then the fixtures and modes, then rehearsal and the plan. Each task committed after its
checks pass.

## Analyze remediation (2026-11-11, applied under CLAUDE.md §2)

- I1: the ladder stops before PlaneViewport's own scale limit.
- G1: tour captures use min(1024, the device limit).
- 0 critical issues.
