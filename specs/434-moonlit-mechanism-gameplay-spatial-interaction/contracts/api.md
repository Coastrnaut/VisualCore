# API contract: R02-G14-04

```swift
public struct MoonlitMechanismOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double   // radians
    public static let authored: MoonlitMechanismOrbit; public static let yawLimit: Double     // 25°
    public static let pitchRange: ClosedRange<Double>; public func clamped() -> MoonlitMechanismOrbit }   // −10° … +15°
extension MoonlitMechanismSceneGeometry {
    public static func camera(_ snapshot: MoonlitMechanismSceneSnapshot, aspect: Double,
                              orbit: MoonlitMechanismOrbit) -> MoonlitMechanismCamera }   // camera(_:aspect:) == authored
public enum MoonlitMechanismPick: Sendable, Equatable { case lamp, ladder, card(Int), gear(Int), empty }
public enum MoonlitMechanismPicker {
    public static let minimumTarget: Double        // 22 points
    public static let gearAllowance: Double        // 8 points beyond the outline circle
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>, camera: MoonlitMechanismCamera)
        -> SIMD2<Double>?                            // view points, origin top-left; nil behind the eye
    public static func segmentDistance(_ point: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double
    public static func gearCentre(_ gear: Int, size: SIMD2<Double>, snapshot: MoonlitMechanismSceneSnapshot,
                                  orbit: MoonlitMechanismOrbit) -> SIMD2<Double>?   // projected centre, view points
    public static func angle(of point: SIMD2<Double>, about centre: SIMD2<Double>) -> Double   // clockwise on screen, radians
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: MoonlitMechanismSceneSnapshot,
                            orbit: MoonlitMechanismOrbit) -> MoonlitMechanismPick }
public enum MoonlitMechanismGestureAction: Sendable, Equatable { case chooseGear(Int), pendingTurn(gear: Int, teeth: Int),
    turn(step: Int, count: Int), pendingLamp(steps: Int), lampStep(step: Int, count: Int), reseat(gear: Int),
    showFrame(Int), run, resetView }
public struct MoonlitMechanismGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, gearPress, gearDrag, lampPress, lampDrag, cardPress, emptyPress,
        orbiting, cancelled }
    public static let tapDistance, dragDistance, tapDuration, doubleTapWindow, doubleTapDistance: Double
    public static let centreDeadZone: Double       // 12 points
    public static let lampRungDistance: Double     // 24 points
    public private(set) var state: State; public private(set) var orbit: MoonlitMechanismOrbit
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: MoonlitMechanismSceneSnapshot)
        -> [MoonlitMechanismGestureAction]          // snapshot carries the gears, the stage and the actions left
    public func camera(viewSize: Vec2, snapshot: MoonlitMechanismSceneSnapshot) -> MoonlitMechanismCamera?
    public mutating func cancel(); public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); the scene draws with the controller's orbit; the panel gains
// "Reset view". turn, lampStep, reseat and run are sent only while playing; chooseGear, pendingTurn, pendingLamp and
// showFrame are presentation (showFrame through the adapter's `frame.show`, which never changes the play).
```
