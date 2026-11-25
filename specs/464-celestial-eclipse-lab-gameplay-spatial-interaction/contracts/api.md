# API contract: R02-G17-04

```swift
public struct CelestialEclipseLabOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double  // radians
    public static let authored: CelestialEclipseLabOrbit; public static let yawLimit: Double   // 60°
    public static let pitchRange: ClosedRange<Double>; public func clamped() -> CelestialEclipseLabOrbit }  // −20° … +35°
extension CelestialEclipseLabSceneSnapshot {
    public var previewBody: Int?; public var previewOffset: Int?
    public var previewIntervals: [CelestialEclipseLabInterval]; public var previewMatched: Int
    public func previewing(body: Int, offset: Int) -> CelestialEclipseLabSceneSnapshot }   // presentation only
extension CelestialEclipseLabSceneGeometry {
    public static func camera(_ snapshot: CelestialEclipseLabSceneSnapshot, aspect: Double,
                              orbit: CelestialEclipseLabOrbit) -> CelestialEclipseLabCamera   // camera(_:aspect:) == authored
    public static func ghostCentre(_ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double>?
    public static func ringPosition(_ body: Int, offset: Int, _ snapshot: CelestialEclipseLabSceneSnapshot) -> SIMD3<Double>
    public static func skyMesh(_ snapshot: CelestialEclipseLabSceneSnapshot, tier: CelestialEclipseLabTier,
                               camera: CelestialEclipseLabCamera) throws -> Mesh   // billboards and order for camera
    public static func glowMesh(_ snapshot: CelestialEclipseLabSceneSnapshot, tier: CelestialEclipseLabTier,
                                camera: CelestialEclipseLabCamera) throws -> Mesh }  // (and the fallback parts likewise)
public enum CelestialEclipseLabPick: Sendable, Equatable { case body(Int), dial, empty }
public enum CelestialEclipseLabPicker {
    public static let bodyAllowance: Double        // 8 points beyond the projected disc radius
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>, camera: CelestialEclipseLabCamera)
        -> SIMD2<Double>?                            // view points, origin top-left; nil behind the eye
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: CelestialEclipseLabSceneSnapshot,
                            orbit: CelestialEclipseLabOrbit) -> CelestialEclipseLabPick
    public static func dialTick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: CelestialEclipseLabSceneSnapshot,
                                orbit: CelestialEclipseLabOrbit) -> Int       // 0 … horizon − 1
    public static func ringOffset(_ point: SIMD2<Double>, body: Int, size: SIMD2<Double>,
                                  snapshot: CelestialEclipseLabSceneSnapshot, orbit: CelestialEclipseLabOrbit) -> Int }
public enum CelestialEclipseLabGestureAction: Sendable, Equatable { case choosePlanet(Int), showTick(Int),
    setPhase(body: Int, offset: Int), preview(body: Int, offset: Int), clearPreview, resetView, explain(String) }
public struct CelestialEclipseLabGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, planetPress, planetDrag, dialDrag, emptyPress, orbiting,
        cancelled }
    public static let tapDistance, dragDistance, tapDuration, doubleTapWindow, doubleTapDistance: Double
    public private(set) var state: State; public private(set) var orbit: CelestialEclipseLabOrbit
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: CelestialEclipseLabSceneSnapshot)
        -> [CelestialEclipseLabGestureAction]
    public func camera(viewSize: Vec2, snapshot: CelestialEclipseLabSceneSnapshot) -> CelestialEclipseLabCamera?
    public mutating func cancel(); public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); the scene draws with the controller's orbit and the preview; the
// panel gains "Reset view". setPhase is sent only while playing; choose and show in any stage.
```
