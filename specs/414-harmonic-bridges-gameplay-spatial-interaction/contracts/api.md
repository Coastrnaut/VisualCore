# API contract: R02-G12-04

```swift
public struct HarmonicBridgesOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double   // radians
    public static let authored: HarmonicBridgesOrbit; public static let yawLimit: Double
    public static let pitchRange: ClosedRange<Double>; public func clamped() -> HarmonicBridgesOrbit }
extension HarmonicBridgesSceneGeometry {
    public static func camera(_ snapshot: HarmonicBridgesSceneSnapshot, aspect: Double,
                              orbit: HarmonicBridgesOrbit) -> HarmonicBridgesCamera }   // camera(_:aspect:) == authored
public enum HarmonicBridgesPick: Sendable, Equatable { case pip(Int), goal, string(Int), empty }
public enum HarmonicBridgesPicker {
    public static let minimumTarget: Double        // 22 points
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>, camera: HarmonicBridgesCamera)
        -> SIMD2<Double>?                            // view points, origin top-left; nil behind the eye
    public static func segmentDistance(_ point: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: HarmonicBridgesSceneSnapshot,
                            orbit: HarmonicBridgesOrbit) -> HarmonicBridgesPick }
public enum HarmonicBridgesGestureAction: Sendable, Equatable { case choose(string: Int, peg: Int),
    preview(string: Int, peg: Int), tune(string: Int, peg: Int), test, resetView }
public struct HarmonicBridgesGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, stringPress, pegDrag, targetPress, orbiting, cancelled }
    public static let tapDistance, dragDistance, tapDuration, doubleTapWindow, doubleTapDistance, pointsPerPeg: Double
    public private(set) var state: State; public private(set) var orbit: HarmonicBridgesOrbit
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: HarmonicBridgesSceneSnapshot)
        -> [HarmonicBridgesGestureAction]            // snapshot carries pegs, locks and stage
    public func camera(viewSize: Vec2, snapshot: HarmonicBridgesSceneSnapshot) -> HarmonicBridgesCamera?
    public static func previewedPeg(current: Int, upward: Double) -> Int   // round(upward / 24) half away from zero, 1 … 12
    public mutating func cancel(); public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); the scene draws with the controller's orbit; the panel gains
// "Reset view". tune and test are sent only while playing; choose and preview update the panel (presentation state).
```
