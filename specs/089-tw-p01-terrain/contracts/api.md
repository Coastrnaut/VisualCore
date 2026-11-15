# Contract: public API added to VisualCoreScenes (A12-P01)

```swift
public struct GradientNoise2D: Sendable, Equatable {
    public let seed: UInt64
    public init(seed: UInt64)
    /// Noise at (x, y) in −1…1; deterministic and bit-identical on every supported device.
    public func value(x: Double, y: Double) -> Double
}

public struct FractalNoise2D: Sendable, Equatable {
    public let seed: UInt64, octaves: Int, frequency: Double, lacunarity: Double, gain: Double
    /// nil for octaves outside 1…8, non-positive or non-finite frequency, lacunarity outside 1…4 or gain outside 0…1.
    public init?(seed: UInt64, octaves: Int, frequency: Double, lacunarity: Double = 2, gain: Double = 0.5)
    /// Sum of octaves normalised by the amplitude sum, in −1…1.
    public func value(x: Double, y: Double) -> Double
}

public struct HeightField: Sendable, Equatable {
    public static let countRange: ClosedRange<Int>   // 1...512
    public let columns: Int, rows: Int, cellSize: Double, originX: Double, originZ: Double
    /// Throws MeshError.invalidInput for counts outside countRange, a non-positive or non-finite cell size, or a
    /// non-finite height.
    public init(columns: Int, rows: Int, cellSize: Double, originX: Double = 0, originZ: Double = 0,
                height: (Double, Double) -> Double) throws(MeshError)
    public func height(column: Int, row: Int) -> Double          // grid value (clamped indices)
    public func height(atX x: Double, z: Double) -> Double       // bilinear, clamped to the grid
    public func normal(column: Int, row: Int) -> Vec3            // from the field incl. one ring beyond
    public func mesh(budget: MeshBudget = .default) throws(MeshError) -> Mesh
}
```

All declarations carry `///` documentation; the API baseline is updated; no existing declaration changes.
