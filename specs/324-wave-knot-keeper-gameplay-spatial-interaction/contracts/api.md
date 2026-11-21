# API contract: R02-G03-04

```swift
public struct WaveKnotKeeperOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double
    public static let authored: WaveKnotKeeperOrbit; public func clamped() -> WaveKnotKeeperOrbit }
extension WaveKnotKeeperSceneGeometry {
    public static func camera(for: WaveKnotKeeperSceneSnapshot, aspect: Double, orbit: WaveKnotKeeperOrbit) -> WaveKnotKeeperCamera }
public enum WaveKnotKeeperHandles {
    public static let touchRadius: Double              // 22 points
    public static func pick(_ location: SIMD2<Double>, snapshot:, camera:, size:) -> Int?
    public static func candidate(point: Int, drag: SIMD2<Double>, snapshot:, camera:, size:) -> WaveKnotKeeperDirection? }
public struct WaveKnotKeeperGestureController { /* pointer down/move/up/cancel → [ExperienceAction-like (control, values)], preview, selection, orbit */ }
// Presenter (experience): pointer(_:), resetView(), ghost preview; panel gains "Reset view".
```
