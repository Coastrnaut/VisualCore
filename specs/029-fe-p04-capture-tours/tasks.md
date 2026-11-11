---

description: "Task list for feature 029 — Fractal Explorer Phase 04 high-resolution capture and tours (ledger gate A03-P04)"
---

# Tasks: Fractal Explorer — Phase 04 High-resolution capture and tours

**Input**: `/specs/029-fe-p04-capture-tours/`: the spec (3 clarifications plus the checklist amendments), the plan,
research R1–R7, the data model, the contract and the quickstart.

**Tests are required**: host tests (VisualCore, FractalExplorerCore); VisualCoreRendering package tests and app unit
and UI tests on iOS 27.2 and 26.5 under the enumeration guard; the ProjectM regression and A01/A02 builds.

**Conventions**: IDs `T-A03-4##`, one commit per task through `scripts/tick_task.py`; commands through
`run-check --stage A03-P04`. Review checkpoint after each phase.

## Phase 1: Foundational — VisualCore G-COST, G-TOUR, G-CAPTURE and the spacing fixture

- [ ] T-A03-401 [P] Tests first, then `Packages/VisualCore/Sources/VisualCoreDiagnostics/RenderCostEstimate.swift` per research R1 (pixels/iterations/samples "> 0, else 1"; ratio; Level light "≤ 2" < moderate "≤ 10" < heavy; text two significant digits). `RenderCostEstimateTests` ≥ 5. Docs, README, baseline; `swift test` (FR-A03-401, SC-A03-401).
- [ ] T-A03-402 [P] Tests first, then `Packages/VisualCore/Sources/VisualCoreMath/FramingFlight.swift` with `FramingFlight` (log-span easing, proportional center, exact end, `route` via the containing framing "span = max(s₀, s₁, 2·|c₁ − c₀|)") and `TourTimeline` (stops with hold ≥ 0, flightDuration > 0, reduceMotion jumps; state framing/stopIndex/phase). `FramingFlightTests` ≥ 5, `TourTimelineTests` ≥ 4. Docs, README, baseline (FR-A03-402, SC-A03-402).
- [ ] T-A03-403 [P] Add `Packages/VisualCore/Tests/VisualCoreMathTests/PrecisionSpacingTests.swift`: for 48 magnitudes in 2⁻²⁰…4, `minimumPixelStep(23, m)` ∈ [1, 2] × `Float(m).ulp`, and for 10 bits ∈ [1, 2] × the true 16-bit spacing (`Float16` where available, else 2^(⌊log₂ m⌋ − 10)) (FR-A03-407, SC-A03-404).
- [ ] T-A03-404 Add `Packages/VisualCoreRendering/Sources/VisualCoreRendering/StillCapture.swift` per research R4 (target gains the pure VisualCorePersistence dependency; package-map line updated) and `StillCaptureTests` ≥ 4 (PNG of the requested size in the folder; replace; invalid size fails with the message and no file; removeFile). Docs, baseline; package tests on 27.2 and 26.5 with the guard (FR-A03-403).
- [ ] T-A03-405 After 401–404: ProjectM regression (reference-a 3/3, reference-b 4/4), A01 and A02 `build-for-testing`, `public-api dependencies docs compliance` (FR-A03-408, SC-A03-406).

**Checkpoint**: VisualCore additions reviewed; regression 7/7.

## Phase 2: User Story 1 — iteration cap and cost (P1) 🎯

- [ ] T-A03-406 [US1] Tests first, then `Apps/FractalExplorer/FractalExplorerCore/Sources/FractalExplorerCore/CapControl.swift` (position p ↔ "cap = round(50 · 200^p) clamped 50…10,000"; halve/double clamped) and in `FractalState.spokenDescription` the cap when ≠ 200 ("…, zoom 4×, 800 iterations"). In `ExplorerView.swift`: slider `fe.cap` ("Iterations: N"), `fe.cap.down`, `fe.cap.up`, cost line `fe.cost` "Render cost: N× the default view (level)" with "may be slow on this device" when heavy, using `RenderCostEstimate` (pixels = canvas pixels, reference cap 200). `CostAndCapTests` (ratio 1 at default, ×2 per doubling, heavy wording, slider mapping, description). Both runtimes (FR-A03-404, SC-A03-401).

## Phase 3: User Story 2 — capture (P1)

- [ ] T-A03-407 [US2] Tests first, then `FractalExplorerCore/.../CaptureSizing.swift` per research R5 (precision-limited long edge, never below the canvas long edge in pixels). In the model: `StillCapture` from `StillCapture.folder(named: "Captures")`, `capture()` freezes animation, sizes with `CaptureSizing` then `ExportGeometry(maxEdge: host.maxRenderSize)` at 4096, sets the message "Captured at N px — the precision limit allows no more detail here" when reduced; view: `fe.capture` (disabled without a size), `fe.capture.share` ShareLink, `fe.capture.message`, `fe.capture.error`; remove the file on leaving; empty the folder at launch in `FractalExplorerApp.swift`; `project.yml` `NSPhotoLibraryAddUsageDescription` and VisualCoreDiagnostics link. `CaptureSizingTests` (host) and `CaptureTests` (64-point CPU agreement ≥ 99%, aspect, precision-reduced size, failure leaves no file, file removed on close, the launch cleanup empties the folder (analyze G2)). Both runtimes (FR-A03-405, SC-A03-403).

## Phase 4: User Story 3 — tours (P2)

- [ ] T-A03-408 [US3] Tests first, then `FractalExplorerCore/.../FractalTours.swift` (three tours per research R7; stop centers "|x|,|y| ≤ 4", span > 0, captions "≤ 120 characters"); `FractalToursTests` (ids, stops valid, every stop reliable or near at 23 bits on a 3× display). Run `swift test`.
- [ ] T-A03-409 [US3] Add `Apps/FractalExplorer/App/TourPlayer.swift` (TourTimeline driven by `tick(now:)` from a `TimelineView(.animation)` in the explorer; framing applied through `apply`; caption `fe.tour.caption` announced once per stop; stops on touch, `fe.tour.stop`, leaving, background, mode change; switches to Mandelbrot) and `Apps/FractalExplorer/App/ToursView.swift` (sheet `fe.tours` with rows `fe.tour.<id>`). `TourPlayerTests` (tick sequence reaches each stop and finishes; Reduce Motion jumps; touch stops and keeps the view; caption announcements once per stop; a cap change during a tour applies and the tour
  continues (analyze G1)). Both runtimes (FR-A03-406, SC-A03-402).

## Phase 5: Polish

- [ ] T-A03-410 Add `Apps/FractalExplorer/Tests/UI/CaptureTourUITests.swift` (cap ×2 and the cost line, capture and share button, start a tour, see a caption, stop) and extend the audit (cap and cost controls, capture result, tours sheet, a playing tour) at default size and XXXL, both runtimes. Then the contract (gate A03-P04; M08 and M09 evidence; G-COST and G-TOUR closed; G-CAPTURE added closed; A02 adoption follow-up), regression baseline, lessons and fast checks (FR-A03-408, SC-A03-405, SC-A03-406).

## Dependencies

- 401, 402, 403 and 404 are independent; 405 follows them and must pass before the seal (stories do not wait for it;
  analyze D1).
- 406 needs 401. 407 needs 404. 408 needs 402; 409 needs 408.
- 410 runs last.

## Parallel examples

- 401 ∥ 402 ∥ 403 (different modules/files); 404 (Rendering package) alongside.
- 406 ∥ 408 after Phase 1.

## Implementation strategy

MVP = Phase 1 + US1 (cap and cost). Then capture, tours, polish. Each task committed after its tests pass.

## Analyze remediation (2026-11-11, applied under CLAUDE.md §2)

- D1: stories no longer wait for the regression task; it still gates the seal.
- G1: a cap change during a tour is tested in T-A03-409.
- G2: the launch cleanup is tested in T-A03-407.
- 0 critical issues.
