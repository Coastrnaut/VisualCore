# API contract: R02-G11-04

```swift
public struct EchoCartographerOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double   // radians
    public static let authored: EchoCartographerOrbit; public static let yawLimit: Double
    public static let pitchRange: ClosedRange<Double>; public func clamped() -> EchoCartographerOrbit }
extension EchoCartographerSceneGeometry {
    public static func camera(_ snapshot: EchoCartographerSceneSnapshot, aspect: Double,
                              orbit: EchoCartographerOrbit) -> EchoCartographerCamera }   // camera(_:aspect:) == authored
public enum EchoCartographerPick: Sendable, Equatable { case marker(EchoCartographerCell), cell(EchoCartographerCell), empty }
public enum EchoCartographerPicker {
    public static let minimumTarget: Double        // 22 points
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>, camera: EchoCartographerCamera)
        -> (origin: SIMD3<Double>, direction: SIMD3<Double>)?
    public static func floorCell(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: EchoCartographerSceneSnapshot,
                                 orbit: EchoCartographerOrbit) -> EchoCartographerCell?   // inside the chamber, or nil
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: EchoCartographerSceneSnapshot,
                            orbit: EchoCartographerOrbit) -> EchoCartographerPick }
public enum EchoCartographerGestureAction: Sendable, Equatable { case pulse(Int, Int), claim(Int, Int), mark(Int, Int),
    moveCursor(Int, Int), resetView }
public struct EchoCartographerGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, cellPress, markerDrag, cellDrag, held, orbiting, cancelled }
    public static let tapDistance, dragDistance, tapDuration, holdDuration, doubleTapWindow, doubleTapDistance: Double
    public private(set) var state: State; public private(set) var orbit: EchoCartographerOrbit
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: EchoCartographerSceneSnapshot,
                                play: EchoCartographerPlay) -> [EchoCartographerGestureAction]
    public func camera(viewSize: Vec2, snapshot: EchoCartographerSceneSnapshot) -> EchoCartographerCamera?
    public mutating func tick(at time: Double)   // a still press arms its claim after holdDuration
    public mutating func cancel(); public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); the scene draws with the controller's orbit; the panel gains
// "Reset view".
```
