# Data Model: Fluid Art Playground — Phase 05

## SyntheticGestureScript (VisualCoreScenes)

| Field | Type | Rule |
|---|---|---|
| seed | UInt64 | 0 → 1 |
| pointerCount | Int | clamped 1…10 |
| strokeSamples | Int | moved samples per stroke, clamped 1…240 |
| speed | Double | points per second, finite, clamped 0…20,000 |
| viewSize | Vec2 | finite, > 0, else 1×1 |
| frameInterval | Double | default 1/60 s |

- `events(forFrame:) -> [PointerEvent]` gives the events of one frame.
- Strokes repeat: began, then `strokeSamples` moved, then ended, then a new stroke from a new seeded start point.
- Pointer i starts at frame i, so the strokes are staggered.
- Locations are clamped inside the view.
- Timestamps are `frame × frameInterval` plus a per-pointer offset below the interval, so they are strictly
  increasing per pointer.
- The output is pure and deterministic.

## FluidDetail (FluidArtPlaygroundCore)

`enum FluidDetail: String, CaseIterable { case low, medium, high }`:
- `edge`: 64, 128, 256.
- `name`: "Low", "Medium", "High".
- `init(grid:)` gives the nearest level.
- `apply(to:)` sets `gridWidth` and `gridHeight`.

## SimulationControl (FluidArtPlaygroundCore)

- `paused: Bool`.
- `stepEnabled` (equals `paused`).
- The labels and hints:
  - `pauseLabel` is "Pause" or "Resume";
  - `stepHint` is "Pause first to step one frame" when running, else "Advances the fluid by one frame";
  - `announcement` is "Paused", "Resumed", "Stepped one frame" or "Reset to the starting picture".

## Scene additions (app)

- `requestStep()`, `resetFields()`, `rebuildFields(configuration:)`.
- `fieldCheck() -> FieldCheck` returns `{finite: Bool, maxVelocity, maxDye, firstBad: String?}`. It reads velocity,
  pressure and dye back with `readFloatPixels()` and decodes 8-bit velocity with the encoding.
- `appliedSplats` and `stepCount` (existing).

## Automation report (existing schema 1)

No schema change. The post-run check uses `result` and `message`. The fluid app's message on pass is
`"digest=<sha256 hex> maxVelocity=<cells/s> maxDye=<v>"`.
