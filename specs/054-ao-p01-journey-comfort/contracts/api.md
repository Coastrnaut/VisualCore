# Contract: A07-P01 framework and core additions

```swift
// VisualCoreMath (pure)
public struct RailPose: Sendable, Equatable { public let position, direction, right, up: Vec3 }
public struct CameraRail: Sendable, Equatable {
  public init?(controlPoints: [Vec3], samplesPerSpan: Int = 64)    // nil: < 4 points, non-finite, near-vertical tangent
  public var length: Double { get }
  public func pose(at distance: Double) -> RailPose                // distance wraps modulo length
  public func orbitCamera(at distance: Double, fovY: Double, near: Double, far: Double) -> OrbitCamera
  public func minimumTurnRadius() -> Double
}
public struct ComfortLimits: Sendable, Equatable, Codable {
  public var maxSpeed, maxAcceleration, maxTurnRate, swayAmplitude, maxRoll: Double
  public static let standard: ComfortLimits; public static let reducedMotion: ComfortLimits
}
public struct RailFlight: Sendable, Equatable, Codable {
  public static let maxStep: Double                                // 0.1 s
  public var distance: Double; public var speed: Double; public var targetSpeed: Double; public var paused: Bool
  public mutating func advance(by dt: Double, limits: ComfortLimits)  // eased, clamped; NaN/negative dt ignored
  public func sway(limits: ComfortLimits) -> Double                // lateral offset
}
public struct OriginRebase: Sendable, Equatable {
  public static let threshold: Double                              // 1,024
  public var origin: Vec3
  public mutating func update(camera: Vec3)
  public func local(_ p: Vec3) -> SIMD3<Float>
}
// AudioOdysseyCore (experience domain)
public enum JourneyWorld: Int, CaseIterable, Codable, Sendable { case tunnel, landscape, starCorridor }
public struct JourneyState: Codable, Equatable, Sendable { /* data-model.md */ }
public enum JourneyRail { public static func make(seed: UInt64) -> CameraRail }
public enum WorldPieces {
  public static let pieceLength: Double; public static let vertexBudget: Int
  public static func piece(_ world: JourneyWorld, index: Int, rail: CameraRail, seed: UInt64) -> Mesh
}
```
