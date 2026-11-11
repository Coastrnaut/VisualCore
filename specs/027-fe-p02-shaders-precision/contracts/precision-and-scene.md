# Contract: precision query and advisor (VisualCore); FractalScene and explorer UI (app)

```swift
// VisualCoreRendering
public struct ShaderPrecision: Sendable, Equatable, Codable { public var rangeMin, rangeMax, precisionBits: Int }
extension RenderCapabilities { public var fragmentHighp: ShaderPrecision?; public var fragmentMediump: ShaderPrecision? }

// VisualCoreMath
public enum PrecisionAdvisor {
    public enum Level: String, Sendable { case reliable, nearLimit, beyondLimit }
    public struct Status: Sendable, Equatable { public let level: Level; public let margin: Double; public let minimumPixelStep: Double }
    public static let nearLimitMargin = 16.0
    public static func assess(mantissaBits: Int, magnitude: Double, pixelStep: Double) -> Status
    public static func minimumPixelStep(mantissaBits: Int, magnitude: Double) -> Double
}
```

**PrecisionAdvisor tests** (at least 7):
- thresholds at 10, 16 and 23 bits;
- the magnitude-zero case;
- non-finite input;
- the minimum step is monotonic in magnitude;
- the reliable/near/beyond boundaries.

## App UI

- Canvas `fe.canvas` (RenderSurface), labelled with the spoken description plus the precision state.
- Buttons `fe.zoomIn`, `fe.zoomOut` and `fe.resetView`.
- Palette picker `fe.palette` and the `fe.animate` toggle.
- Precision banner `fe.precision`: "Near precision limit" or "Precision limit reached".
