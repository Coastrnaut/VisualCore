# API contract: R02-G04-04

```swift
public struct HueCompassOrbit: Sendable, Equatable { public var yaw: Double; public var tilt: Double   // radians
    public static let authored: HueCompassOrbit; public static let yawLimit, tiltRange; public func clamped() -> HueCompassOrbit }
extension HueCompassSceneGeometry {
    public static func camera(aspect: Double, orbit: HueCompassOrbit) -> HueCompassCamera }   // camera(aspect:) == authored orbit
public enum HueCompassDial {
    public static let deadZone: Double                 // 20 points
    public static let tapDistance: Double              // 10 points
    public static let minimumHubRadius: Double         // 30 points
    public static func centre(camera: HueCompassCamera, size: SIMD2<Double>) -> SIMD2<Double>?
    public static func hubRadius(camera: HueCompassCamera, size: SIMD2<Double>) -> Double
    public static func angle(of point: SIMD2<Double>, centre: SIMD2<Double>) -> Double?   // nil inside the dead zone; atan2(−dy, dx)
    public static func steps(forAngle radians: Double) -> Int                             // round(radians · 96 / 2π)
    public static func wrapped(_ steps: Int) -> Int }                                     // into −47 … 48
public struct HueCompassGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, swiping, orbiting, cancelled }
    public private(set) var state: State; public private(set) var orbit: HueCompassOrbit
    public var previewBearing: Int?
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: HueCompassSceneSnapshot) -> [HueCompassGestureAction]
    public mutating func resetView() }
public enum HueCompassGestureAction: Sendable, Equatable { case turn(Int), probe, resetView }
// Presenter: pointer(_:), resetView(), ghost needle at the preview; panel gains "Reset view".
```
