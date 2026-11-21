# API contract: R02-G02-04 (LissajousLabyrinthCore additions)

```swift
extension LissajousLabyrinthSceneGeometry {
    public static func stageBounds(level: LissajousLabyrinthLevel) -> (centre: Vec3, radius: Double)
    public static func contentBounds(level: LissajousLabyrinthLevel) -> (centre: Vec3, radius: Double)   // stage + rings
    public static func camera(aspect: Double, snapshot: LissajousLabyrinthSceneSnapshot,
                              orbit: LissajousLabyrinthOrbit) -> (eye: Vec3, target: Vec3, fovY: Double)
    // camera(aspect:snapshot:) == camera(aspect:snapshot:orbit: .authored); viewProjection, depthRange and project gain orbit: = .authored
}
public struct LissajousLabyrinthOrbit: Sendable, Equatable { public var azimuthOffset: Double; public var elevation: Double
    public static let authored: LissajousLabyrinthOrbit; public static let azimuthRange: ClosedRange<Double>
    public static let elevationRange: ClosedRange<Double>; public func clamped() -> LissajousLabyrinthOrbit
    public var eyeDirection: Vec3 }
public enum LissajousLabyrinthHandles {
    public static func ringCentre(_ dial: LissajousLabyrinthDial, level: LissajousLabyrinthLevel) -> Vec3
    public static func ringRadius(level: LissajousLabyrinthLevel) -> Double
    public static func knob(_ dial: LissajousLabyrinthDial, value: Int, level: LissajousLabyrinthLevel) -> Vec3
    public static func stepAngle(_ dial: LissajousLabyrinthDial) -> Double            // 40° or 22.5°
    public static func value(_ dial: LissajousLabyrinthDial, start: Int, turnedAngle: Double) -> Int   // clamped 1 … 9 or modulo 16
    public static func spatialHandles(level: LissajousLabyrinthLevel, dials: LissajousLabyrinthDials) throws -> [SpatialHandle]   // 4, id = dial index
}
public enum LissajousLabyrinthGesturePhase: Sendable, Equatable {
    case idle, turning(LissajousLabyrinthDial, start: Int, candidate: Int), orbiting, cancelled }
public struct LissajousLabyrinthGestureController: Sendable {
    public init()
    public private(set) var phase: LissajousLabyrinthGesturePhase; public private(set) var selectedDial: LissajousLabyrinthDial
    public private(set) var orbit: LissajousLabyrinthOrbit; public var preview: LissajousLabyrinthAction? { get }
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: LissajousLabyrinthSceneSnapshot,
                                playing: Bool) -> LissajousLabyrinthAction?
    public mutating func select(_ dial: LissajousLabyrinthDial); public mutating func resetOrbit(); public mutating func cancel()
}
public struct LissajousLabyrinthPending: Sendable, Equatable {
    public init(); public private(set) var values: [LissajousLabyrinthDial: Int]; public var isEmpty: Bool { get }
    public mutating func set(_ dial: LissajousLabyrinthDial, _ value: Int, current: LissajousLabyrinthDials)   // equal to current removes it
    public mutating func step(_ dial: LissajousLabyrinthDial, by delta: Int, current: LissajousLabyrinthDials) // wraps in range
    public mutating func clear()
    public func actions(from current: LissajousLabyrinthDials) -> [LissajousLabyrinthAction]                // research R7 order
}
```
