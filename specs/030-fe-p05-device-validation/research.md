# Research: Fractal Explorer — Phase 05 Device precision and performance validation

## R1 — App modes in VisualCoreAutomation (G-AUTOMODE)

- **Decision**: `public typealias AppMode = @MainActor (RenderHost, inout AutomationReport, Int) -> Void` (host,
  report, frames); `AutomationRunner.appModes: [String: AppMode]`; `allModes` = built-in + app (sorted, built-ins
  first); `run` dispatches built-ins first; app modes then get `postRunCheck`/`checkNote`. `AutomationReport` gains
  `measurements: [String: Double]?` and `details: [String: String]?` (omitted when nil). `AutomationView` gains
  `appModes: [String: @MainActor (RenderScene, RenderHost, inout AutomationReport, Int) -> Void]`.
- **Rationale**: every app's device campaign needs app-specific measurements; one mechanism, one report format.

## R2 — Precision ladder

- **Decision**: `PrecisionLadder.zooms(steps: 24, factor: 4)` from zoom 1 at the Seahorse point; per step the app
  level (PrecisionMode.level with the device bits and display scale) and the clamp flag (unitsPerPoint below the
  advisor minimum); agreement measured by the app. `verdict(steps:)`: fail if any reliable step < 0.99; clamp step =
  first step clamped; breakdown step = first step with agreement < 0.99; fail if breakdown < clamp. Steps past the
  clamp are drawn unclamped (ladder framing bypasses `apply`) to locate the breakdown.

## R3 — Measurement build and Release check

- **Decision**: reuse `check_release_symbols.py` on the Release simulator build (absent) and on a Release build with
  `SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) VISUALCORE_AUTOMATION` (present).

## R4 — Bookmark reproduction

- **Decision**: 10 seeded random bookmarks (both modes, 5 palettes, caps 50…2000), each rendered 64 × 64 offscreen
  before saving and after reload into a fresh model at the same size (max channel difference ≤ 1); on a 2:1 canvas,
  classes at 64 sample points vs the CPU reference ≥ 99%.
