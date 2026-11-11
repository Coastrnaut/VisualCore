# Contract: VisualCoreSimulation additions (G-CPUFIELD)

These types are pure Swift, `Sendable` and host-testable with `swift test --package-path Packages/VisualCore`.

```swift
public enum StoragePrecision: String, Sendable, Codable, CaseIterable {
    case float32, float16, unorm8
    public func round(_ x: Float) -> Float     // float16: Float(Float16(x)); unorm8: round(clamp(x,0,1)*255)/255
    public var tolerance: Float { get }        // float32 1e-6, float16 1e-3 (values <= 1), unorm8 1.5/255
}

public struct FieldGrid: Sendable, Equatable {
    public let width: Int, height: Int, channels: Int    // channels 1...4
    public var values: [Float]                           // row-major, bottom row first
    public init(width: Int, height: Int, channels: Int, fill: Float = 0)
    public init?(width: Int, height: Int, channels: Int, values: [Float])
    public subscript(x: Int, y: Int, c: Int) -> Float { get set }
    public func rounded(to precision: StoragePrecision) -> FieldGrid
    public func maxAbsDifference(_ other: FieldGrid) -> Float?   // nil when the shapes differ
    public var isFinite: Bool { get }
    public var minValue: Float { get }
    public func padded(toChannels: Int, fill: Float = 0) -> FieldGrid   // e.g. 2-channel velocity -> RGBA upload
}

public struct SignedRangeEncoding: Sendable, Equatable {
    public init?(range: Float)                 // range > 0 and finite
    public func encode(_ v: Float) -> Float    // clamp(v/range*0.5+0.5, 0, 1)
    public func decode(_ u: Float) -> Float    // (u-0.5)*2*range
}

public struct TimeStepPolicy: Sendable, Equatable {
    public init(minStep: Double = 1.0/240, maxStep: Double = 1.0/30)   // invalid -> defaults
    public mutating func clamp(_ delta: Double) -> Double
    public private(set) var clampedCount: Int, invalidCount: Int
}
```

**Tests**:
- rounding: identity for float32, half-precision steps, unorm8 stall behavior;
- grid shape validation, subscripts, difference and `isFinite`;
- encoding round trip within 1/255·2·range;
- the time-step clamp, including NaN, negative, zero and 10-second inputs.
