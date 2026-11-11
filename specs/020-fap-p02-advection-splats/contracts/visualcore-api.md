# Contract: VisualCore additions (G-POINTERVEL, exact bilinear sampling)

```swift
// VisualCoreScenes
public struct PointerVelocityTracker: Sendable {
    public struct Sample: Sendable, Equatable { public let id: Int; public let position: Vec2; public let velocity: Vec2
                                                 public let timestamp: Double; public let phase: PointerPhase }
    public init(spacing: Double, maxSamplesPerUpdate: Int = 16, smoothing: Double = 0.5)
    public let spacing: Double, maxSamplesPerUpdate: Int, smoothing: Double
    public mutating func handle(_ event: PointerEvent) -> [Sample]
    public var activeCount: Int { get }
    public private(set) var ignoredPointers: Int, rejectedSamples: Int, cappedUpdates: Int
}

// VisualCoreSimulation
extension FieldGrid {
    public func sampleBilinear(cellX: Float, cellY: Float, channel: Int) -> Float
    public func sampleBilinear(cellX: Float, cellY: Float) -> [Float]
}

// VisualCoreRendering
extension ShaderBundle { public static let visualCoreIncludes: ShaderLibrary }   // vc/*.glsl
// FieldPass.init(registry:fragment:inputs:label:library: ShaderLibrary = ShaderBundle.visualCoreIncludes)
```

`vc/field.glsl`:

```glsl
vec4 vc_fieldTexel(sampler2D f, ivec2 cell);              // texelFetch with the index clamped to the edge
vec4 vc_fieldBilinear(sampler2D f, vec2 cellCoord);       // exact; cell centers at i + 0.5; same formula as the CPU
```

**Tests**:
- **Tracker (host, ≥ 8 cases)**: spacing, velocity convergence (500 pt/s), independence of 2 pointers, cap and
  counter, non-finite rejection, a zero Δt keeps the previous velocity, end sample, cancel emits nothing, 11th pointer
  ignored.
- **CPU bilinear (host)**: centers are exact, the midpoint is the mean, edges are clamped, and an outside coordinate
  gives the edge value.
- **GPU bilinear (simulator, both runtimes)**: a pass writing `vc_fieldBilinear` at offset coordinates matches
  `FieldGrid.sampleBilinear` within 1e-5 in RGBA16F (values exactly representable) for 64 coordinates, including
  outside ones.
