# Contract: VisualCoreMath.KeplerOrbit (feature 104)

```swift
/// An elliptical Kepler orbit from classical elements (angles in radians, mean motion in radians per time unit).
public struct KeplerOrbit: Sendable, Equatable {
    public let semiMajorAxis: Double, eccentricity: Double, inclination: Double
    public let ascendingNode: Double, argumentOfPeriapsis: Double, meanAnomalyAtEpoch: Double, meanMotion: Double
    public init?(semiMajorAxis: Double, eccentricity: Double, inclination: Double, ascendingNode: Double,
                 argumentOfPeriapsis: Double, meanAnomalyAtEpoch: Double, meanMotion: Double)
    public static let maxIterations = 32
    public static let tolerance = 1e-12
    public static func eccentricAnomaly(meanAnomaly: Double, eccentricity: Double) -> Double
    public func meanAnomaly(at time: Double) -> Double        // normalised to (−π, π]
    public func position(at time: Double) -> Vec3              // reference frame; z toward the plane's north
    public var period: Double                                  // 2π / meanMotion
}
```

Tests (`KeplerOrbitTests`, host): refusals; residual < 1e-10 for e ∈ {0, 0.2056, 0.5, 0.9, 0.95} at 24 anomalies;
circular orbit radius constant; perihelion a(1−e) at M = 0 and aphelion a(1+e) at M = π; period return; inclination
rotates out of plane; a non-finite time is treated as the epoch (documented), so the result is always finite.
