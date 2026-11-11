# Contract: QualityPolicy (VisualCore) and the fluid solver passes (app)

## VisualCoreDiagnostics

```swift
public struct QualityPolicy: Sendable, Equatable {
    public init(tierCount: Int, lowPowerCeiling: Int = 1, decisionInterval: Double = 2, calmPeriod: Double = 10)
    public let tierCount: Int, lowPowerCeiling: Int, decisionInterval: Double, calmPeriod: Double
    public private(set) var tier: Int
    public private(set) var stepsDown: Int, stepsUp: Int
    public mutating func decide(thermal: FramePacing.Thermal, lowPower: Bool, now: Double) -> Int
    public mutating func reset()
}
```

**Tests** (≥ 8):
- serious and critical step down;
- one step per interval;
- calm-period recovery one tier at a time;
- an interrupted calm period restarts;
- the Low Power ceiling;
- the floor;
- oscillating input does not oscillate the tier;
- invalid configuration falls back;
- a non-finite `now`.

## App shaders (all `#include "vc/field.glsl"`, `texelFetch` only, explicit edge branches)

| Pass | Inputs | Output |
|---|---|---|
| diffuse | `uX` (current), `uB` (before diffusion); `uAlpha`, `uWalls`, encoding | velocity scratch |
| divergence | `uVelocity`; `uWalls`, encoding | divergence (R) |
| pressure | `uPressure`, `uDivergence`; encoding | pressure (R) |
| gradient | `uVelocity`, `uPressure`; `uWalls`, encoding | projected velocity |

## App UI

- The Adjust button (`fap.adjust`) opens a sheet (`fap.adjust.sheet`) with:
  - sliders `fap.adjust.viscosity`, `fap.adjust.dyeFade`, `fap.adjust.motionFade`, `fap.adjust.quality`
    (iterations 1…80);
  - a segmented picker `fap.adjust.edges` (Walls, Open);
  - the label `fap.adjust.tier` ("Quality: Full (automatic)");
  - the button `fap.adjust.reset`.
- Each slider's accessibility value shows its value and unit.
