# API contract: R02-G01-04 (AuroraLoomCore additions)

```swift
public struct AuroraLoomOrbit: Sendable, Equatable { public var azimuthOffset: Double; public var elevation: Double
    public static let authored: AuroraLoomOrbit; public static let azimuthRange: ClosedRange<Double>; public static let elevationRange: ClosedRange<Double>
    public func clamped() -> AuroraLoomOrbit }
extension AuroraLoomSceneGeometry {
    public static func camera(aspect: Double, orbit: AuroraLoomOrbit) -> (view: Mat4, projection: Mat4)   // camera(aspect:) == camera(aspect:orbit: .authored)
}
public struct AuroraLoomHandleID: Sendable, Equatable, Hashable { public let ribbon: Int; public let control: AuroraLoomControl; public var raw: Int }
public enum AuroraLoomHandles {
    public static func anchorPosition(ribbon: Int, wave: Int) -> Vec3
    public static func dialCentre(ribbon: Int) -> Vec3
    public static func dialKnob(ribbon: Int, phase: Int) -> Vec3
    public static func waveStep(atHeight y: Double) -> Int                 // clamped 0 … 15
    public static func phaseStep(start: Int, turnedAngle: Double) -> Int  // modulo 16
    public static func spatialHandles(steps: AuroraLoomSteps) throws -> [SpatialHandle]   // 6, id = AuroraLoomHandleID.raw
}
public enum AuroraLoomGesturePhase: Sendable, Equatable { case idle, dragging(AuroraLoomHandleID, start: Int, candidate: Int), orbiting, cancelled }
public struct AuroraLoomGestureController: Sendable {
    public init()
    public private(set) var phase: AuroraLoomGesturePhase; public private(set) var selectedRibbon: Int; public private(set) var orbit: AuroraLoomOrbit
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, steps: AuroraLoomSteps, playing: Bool) -> AuroraLoomMove?
    public mutating func select(ribbon: Int); public mutating func resetOrbit(); public mutating func cancel()
}
```
