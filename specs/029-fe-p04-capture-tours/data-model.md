# Data Model: Fractal Explorer — Phase 04

## RenderCostEstimate (VisualCoreDiagnostics)

| Field | Type | Rule |
|---|---|---|
| pixels | Double | > 0, else 1 |
| iterations | Double | > 0, else 1 |
| samples | Double | > 0, else 1 |

`relative(to:)` ratio; `Level` light ≤ 2 < moderate ≤ 10 < heavy.

## FramingFlight / TourTimeline (VisualCoreMath)

- FramingFlight: from, to (PlaneFraming); `framing(at:curve:)`; `static route(from:to:) -> [FramingFlight]`.
- TourTimeline.Stop: framing, hold (s ≥ 0). Timeline: start framing, stops (≥ 1), flightDuration (s > 0), reduceMotion.
- TourTimeline.State: framing, stopIndex (0-based, the stop being approached or held), phase (flying | holding |
  finished).

## StillCapture (VisualCoreRendering, @MainActor)

state: idle | done(URL) | failed(String); lastImage: StillImage?; folder: TemporaryFolder.

## Tour (FractalExplorerCore)

| Field | Type | Rule |
|---|---|---|
| id | String | stable (seahorse, elephant, mini) |
| name | String | display |
| stops | [TourStop] | ≥ 1; each center |x|,|y| ≤ 4, span > 0 |
| TourStop.caption | String | ≤ 120 characters |

## CapControl (FractalExplorerCore)

slider position p ∈ [0, 1] ↔ cap = round(50 · 200^p) clamped 50…10,000; halve/double clamped.
