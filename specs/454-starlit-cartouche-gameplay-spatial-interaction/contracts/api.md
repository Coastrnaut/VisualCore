# API contract: R02-G16-04

```swift
public struct StarlitCartoucheOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double   // radians
    public static let authored: StarlitCartoucheOrbit; public static let yawLimit: Double     // 60°
    public static let pitchRange: ClosedRange<Double>; public func clamped() -> StarlitCartoucheOrbit }   // −20° … +35°
extension StarlitCartoucheSceneSnapshot { public var launchBeat: Int; public var launchPositions: [StarlitCartoucheVector] }
extension StarlitCartoucheSceneGeometry {
    public static func camera(_ snapshot: StarlitCartoucheSceneSnapshot, aspect: Double,
                              orbit: StarlitCartoucheOrbit) -> StarlitCartoucheCamera     // camera(_:aspect:) == authored
    public static func launchCentre(_ index: Int, _ snapshot: StarlitCartoucheSceneSnapshot) -> SIMD3<Double>
    public static func previewEnds(_ snapshot: StarlitCartoucheSceneSnapshot) -> (start: SIMD3<Double>, end: SIMD3<Double>)?
    public static func chartMesh(_ snapshot: StarlitCartoucheSceneSnapshot, tier: StarlitCartoucheTier, glide: Double,
                                 camera: StarlitCartoucheCamera) throws -> Mesh   // billboards and order for camera
    public static func glowMesh(_ snapshot: StarlitCartoucheSceneSnapshot, tier: StarlitCartoucheTier, glide: Double,
                                camera: StarlitCartoucheCamera) throws -> Mesh }  // (and the fallback parts likewise)
public enum StarlitCartouchePick: Sendable, Equatable { case star(Int), ship, slider, empty }
public enum StarlitCartouchePicker {
    public static let starAllowance: Double        // 8 points beyond the projected ring radius
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>, camera: StarlitCartoucheCamera)
        -> SIMD2<Double>?                            // view points, origin top-left; nil behind the eye
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: StarlitCartoucheSceneSnapshot,
                            orbit: StarlitCartoucheOrbit) -> StarlitCartouchePick
    public static func sliderWait(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: StarlitCartoucheSceneSnapshot,
                                  orbit: StarlitCartoucheOrbit) -> Int }      // 0 … 8
public enum StarlitCartoucheGestureAction: Sendable, Equatable { case chooseDestination(Int), chooseWait(Int),
    fly(star: Int, wait: Int), preview(Int), clearPreview, resetView, explain(String) }
public struct StarlitCartoucheGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, starPress, shipPress, shipDrag, sliderDrag, emptyPress, orbiting,
        cancelled }
    public static let tapDistance, dragDistance, tapDuration, doubleTapWindow, doubleTapDistance: Double
    public private(set) var state: State; public private(set) var orbit: StarlitCartoucheOrbit
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: StarlitCartoucheSceneSnapshot)
        -> [StarlitCartoucheGestureAction]
    public func camera(viewSize: Vec2, snapshot: StarlitCartoucheSceneSnapshot) -> StarlitCartoucheCamera?
    public mutating func cancel(); public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); the scene draws with the controller's orbit; the panel gains
// "Reset view". fly is sent only while playing; the choices go through `route.choose` in any stage.
```
