# API contract: R02-G13-04

```swift
public struct AcousticConstellatorOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double   // radians
    public static let authored: AcousticConstellatorOrbit; public static let yawLimit: Double
    public static let pitchRange: ClosedRange<Double>; public func clamped() -> AcousticConstellatorOrbit }
extension AcousticConstellatorSceneGeometry {
    public static func camera(_ snapshot: AcousticConstellatorSceneSnapshot, aspect: Double,
                              orbit: AcousticConstellatorOrbit) -> AcousticConstellatorCamera   // camera(_:aspect:) == authored
    public static func filamentMesh(from star: Int, to point: SIMD3<Double>, _ snapshot: AcousticConstellatorSceneSnapshot)
        throws(MeshError) -> Mesh }                  // the drag preview strip, constellation material teal
public enum AcousticConstellatorPick: Sendable, Equatable { case coherence(Int), hold(Int), star(Int), link(Int), empty }
public enum AcousticConstellatorPicker {
    public static let minimumTarget: Double        // 22 points
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>, camera: AcousticConstellatorCamera)
        -> SIMD2<Double>?                            // view points, origin top-left; nil behind the eye
    public static func segmentDistance(_ point: SIMD2<Double>, _ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double
    public static func starAt(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: AcousticConstellatorSceneSnapshot,
                              orbit: AcousticConstellatorOrbit, excluding: Int?) -> Int?   // nearest within 22 points
    public static func fingerPoint(_ point: SIMD2<Double>, size: SIMD2<Double>, camera: AcousticConstellatorCamera,
                                   height: Double) -> SIMD3<Double>?   // on the plane y = height; nil when the ray misses
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: AcousticConstellatorSceneSnapshot,
                            orbit: AcousticConstellatorOrbit) -> AcousticConstellatorPick }
public enum AcousticConstellatorGestureAction: Sendable, Equatable { case choose(star: Int), choosePair(Int, Int),
    preview(from: Int, target: Int?, point: SIMD2<Double>), link(Int, Int), unlink(Int, Int), nudge(star: Int),
    listen, resetView }
public struct AcousticConstellatorGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, starPress, linkDrag, targetPress, linkPress, orbiting, cancelled }
    public static let tapDistance, dragDistance, tapDuration, doubleTapWindow, doubleTapDistance: Double
    public private(set) var state: State; public private(set) var orbit: AcousticConstellatorOrbit
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: AcousticConstellatorSceneSnapshot)
        -> [AcousticConstellatorGestureAction]       // snapshot carries links, fixed links and stage
    public func camera(viewSize: Vec2, snapshot: AcousticConstellatorSceneSnapshot) -> AcousticConstellatorCamera?
    public mutating func cancel(); public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); the scene draws with the controller's orbit and the drag filament;
// the panel gains "Reset view". link, unlink, nudge and listen are sent only while playing; choose, choosePair and
// preview update the panel (presentation state).
```
