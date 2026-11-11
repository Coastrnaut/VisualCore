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
- [X] T-A03-502 ProjectM regression (reference-a 3/3, reference-b 4/4), A01 and A02 `build-for-testing`, `public-api dependencies docs compliance` (FR-A03-507). — Verified 2026-11-11: — Verified 2026-11-11: ProjectM regression after the VisualCoreAutomation app modes: run-check A03-P05/t502-reference-a 3/3 (pin d93edd1 unchanged) and t502-reference-b 4/4; A01 t502-build-GenerativeArtStudio and A02 t502-build-FluidArtPlayground TEST BUILD SUCCEEDED from clean derived data; public-api/dependencies/docs/compliance 4/4 in t501-checks

## Phase 2: User Story 3 — bookmark reproduction fixture (P1)

- [X] T-A03-503 [P] [US3] Add `Apps/FractalExplorer/Tests/Unit/BookmarkReproductionTests.swift` per research R4: 10 seeded bookmarks (both modes, the 5 palettes, caps 50…2000) rendered 64 × 64 offscreen before saving and after reload into a fresh model at the same size ("every channel within 1 of 255"), and on a 2:1 canvas classes at 64 points vs the CPU reference ≥ 99%; every field equal after reload. Both runtimes (FR-A03-504, SC-A03-504). — Verified 2026-11-11: — Verified 2026-11-11: BookmarkReproductionTests (10 seeded bookmarks over both modes, the 5 palettes and caps 50...2000): reopened in a fresh model after reload at the same 300x300 canvas, every field equal and the 64x64 picture within 1 per channel; on a 600x300 canvas rendered 128x64 the 4,096 shared plane points agree >= 99% with the original picture's classes. First runs t503-app-ios27 and -2 compared against the CPU reference (64, then 1,024 points) and failed on legitimate float32-vs-double iteration divergence at high caps (spec implementation finding recorded); run-check A03-P05/t503-app-ios27-3 and t503-app-ios26-3 TEST SUCCEEDED, enumeration 60/60 each

## Phase 3: User Story 1 — precision mode (P1) 🎯

- [X] T-A03-504 [P] [US1] Tests first, then `Apps/FractalExplorer/FractalExplorerCore/Sources/FractalExplorerCore/PrecisionLadder.swift` (zooms 4^i for "≤ 24 steps" from the Seahorse point; `Step` index/zoom/level/clamped/agreement; `verdict`: fail if a reliable step < 0.99, clamp step = first clamped, breakdown = first < 0.99, fail if breakdown < clamp; none-within-ladder cases; the plan ends early once PlaneViewport's own 1e-15 scale limit would be reached at the given canvas, analyze I1). `PrecisionLadderTests` ≥ 4. `swift test` (FR-A03-502, SC-A03-502). — Verified 2026-11-11: — Verified 2026-11-11: FractalExplorerCore PrecisionLadder (Seahorse center, x4 per step, <= 24 steps, stopping before PlaneViewport's 1e-15 scale; canvasViewport, 64-pixel patchViewport at the canvas's plane step per device pixel, isClamped from the advisor and display scale; verdict: fail if a reliable step < 99% or a breakdown without any clamp; near-limit breakdowns recorded, not judged — spec implementation finding recorded). PrecisionLadderTests 7 (clamp before breakdown, reliable step failing, breakdown without clamp, no breakdown, zooms stop before the scale limit, patch step, 10-bit clamps earlier than 23-bit). First run t504-core-test failed to compile (pow without Foundation in the test); run-check A03-P05/t504-core-test-2 26 Swift Testing passed
- [X] T-A03-505 [US1] Add `ExplorerModel(hosted: false)` (no own host; scene only) and `Apps/FractalExplorer/App/AppAutomation.swift` (`#if DEBUG || VISUALCORE_AUTOMATION`): AutomationView hosting `model.scene`, built-in modes with the check "no shader error", the `precision` app mode (capabilities, ladder rendered 64 × 64 unclamped through the scene, agreement vs CPU, level and clamp from the app's rules with the device bits and the view's display scale, measurements and details per the data model, verdict); route automation launches in `FractalExplorerApp.swift`; `project.yml` links VisualCoreAutomation. `AutomationModeTests` (precision mode against a recorder: pass, all measurements present, report decodes). Both runtimes (FR-A03-502, FR-A03-505). — Verified 2026-11-11: — Verified 2026-11-11: ExplorerModel(hosted: false) (no own host, no fallback previews); App/AppAutomation.swift (DEBUG||VISUALCORE_AUTOMATION; AutomationView hosts the explorer's scene, check 'no shader error', app mode precision: reported highp/mediump bits and range, render limit, display scale, ladder of 64x64 device-pixel patches drawn unclamped, explained agreement vs CPU (match or CPU class change within one pixel — spec finding: plain matching gave 97.4% at a reliable step because of boundary filaments, run t505-app-ios27 failed), level/clamp from the app's rules, measurements/details per the data model, PrecisionLadder verdict); FractalExplorerApp routes automation launches; project.yml links VisualCoreAutomation. AutomationModeTests 2 (precision report complete and decodes, pass, exit code 0; built-in smoke on the explorer scene). Simulator rehearsal values (not device evidence): 22 steps, reliable steps >= 99.17%, breakdown step 7 (16,384x, near limit), clamp step 8 (65,536x). run-check A03-P05/t505-app-ios27-2 and t505-app-ios26-2 TEST SUCCEEDED, enumeration 62/62 each

## Phase 4: User Story 2 — tour mode (P1)

- [X] T-A03-506 [US2] Add the `tour` app mode to `AppAutomation.swift`: all tours at 1/60 s tour steps (frames capped per tour by `VISUALCORE_AUTORUN_FRAMES` when set), `renderOneFrame(present: true)` timed per step, a still per stop at min(1024, the device's render limit) via `StillCapture` (analyze G1) compared at 64 points (≥ 99%), files removed, thermal state and Low Power Mode at start/end in details, frame-time statistics. `AutomationModeTests` gains the tour mode (capped frames: pass, stops 9, agreement measurements, no file left). Both runtimes (FR-A03-503, SC-A03-503). — Verified 2026-11-11: — Verified 2026-11-11: AppAutomation tour mode (every curated tour at 60 tour steps per second through the model's apply, a timed presented frame per step, frames per tour capped by VISUALCORE_AUTORUN_FRAMES when given, a still per stop at min(1024 px, device limit) via StillCapture checked at 64 points with the explained-agreement rule, files removed, thermal state and Low Power Mode at start and end, per-tour agreements, frame-time statistics); TourModeTests 1 (30-frame cap: pass, 90 frames, 9 stops, min stop agreement >= 0.99, capture long edge 1024, all details, no file left). Simulator rehearsal (not device evidence): 9/9 stops agreement 1.0. run-check A03-P05/t506-app-ios27 and t506-app-ios26 TEST SUCCEEDED, enumeration 63/63 each

## Phase 5: User Story 4 — rehearsal, release check and plan (P2)

- [X] T-A03-507 [US4] Simulator rehearsal (not device evidence): build the Debug app, run `run_automation_sim.py` for smoke, launch, lifecycle, precision and tour on iOS 27.2 and 26.5 (reports under `.autonomy/logs/`); Release simulator build → `check_release_symbols.py` (absent), measurement build (Release + `VISUALCORE_AUTOMATION`) → `--expect-present` (FR-A03-505, FR-A03-506, SC-A03-503, SC-A03-505). — Verified 2026-11-11: — Verified 2026-11-11 (simulator rehearsal, NOT device evidence): run_automation_sim.py with the Debug simulator app ran smoke, launch, lifecycle, precision and tour on iOS 27.2 and 26.5 — all 10 reports result=pass (run-check A03-P05/t507-rehearse-<mode>-27 and -26; reports in .autonomy/logs/a03p05-automation-27/-26, gitignored): precision 22 steps, highp 23 bits, clamp step 8, breakdown step 7, min reliable agreement 0.9917 on both; tour 3,780 frames; reports carry model and OS only. Release build (t507-release-build) has 0 automation symbols and 0 trigger strings (t507-release-symbols); the measurement build with VISUALCORE_AUTOMATION (t507-measure-build) has 501 (t507-measure-symbols --expect-present)
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
