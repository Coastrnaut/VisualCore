# API contract: R02-G06-04

```swift
public struct ChronoConstellatorOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double   // radians
    public static let authored: ChronoConstellatorOrbit; public static let yawLimit: Double; public static let pitchRange: ClosedRange<Double>
    public var eyeDirection: SIMD3<Double>   // unit, from the target towards the eye
    public func clamped() -> ChronoConstellatorOrbit }
extension ChronoConstellatorSceneGeometry {
    public static func camera(_ snapshot: ChronoConstellatorSceneSnapshot, aspect: Double,
                              orbit: ChronoConstellatorOrbit) -> ChronoConstellatorCamera   // camera(_:aspect:) == authored
    public static func candidatePart(_ cell: Int, _ snapshot: ChronoConstellatorSceneSnapshot) throws(MeshError)
        -> ChronoConstellatorColouredMesh }   // the pearl ring of the drag highlight
public enum ChronoConstellatorPick: Sendable, Equatable { case star(Int), cell(Int), timeline(Double), empty }
public enum ChronoConstellatorPicker {
    public static let minimumTarget: Double   // 22 points
    public static let timelineBand: Double    // 0.25 · u inside the near edge
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>, camera: ChronoConstellatorCamera)
        -> (origin: SIMD3<Double>, direction: SIMD3<Double>)?
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ChronoConstellatorSceneSnapshot,
                            orbit: ChronoConstellatorOrbit) -> ChronoConstellatorPick
    public static func loopIndex(star: Int, at point: SIMD2<Double>, size: SIMD2<Double>,
                                 snapshot: ChronoConstellatorSceneSnapshot, orbit: ChronoConstellatorOrbit) -> Int?
    public static func tick(at point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ChronoConstellatorSceneSnapshot,
                            orbit: ChronoConstellatorOrbit) -> Int? }
public enum ChronoConstellatorGestureAction: Sendable, Equatable {
    case phase(Int, Int), step(Int), rewind, hold(Int, Int, Int), release(Int, Int), select(Int), resetView }
public struct ChronoConstellatorGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, starDrag, scrub, orbiting, cancelled }
    public static let tapDistance: Double     // 10 points
    public static let dragDistance: Double    // 16 points
    public static let pressDuration: Double   // 0.5 s
    public static let holdStart: Int; public static let holdLength: Int   // 1, 10
    public static let doubleTapWindow: Double   // 0.35 s
    public static let barReach: Double          // 22 points: a touch this near the tick bar scrubs
    public static let yawPerViewWidth: Double; public static let pitchPerViewHeight: Double   // 90°, 60°
    public private(set) var state: State; public private(set) var orbit: ChronoConstellatorOrbit
    public private(set) var candidateCell: Int?; public private(set) var scrubTick: Int?
    public private(set) var draggedStar: Int?   // the star of a star gesture, for the description
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: ChronoConstellatorSceneSnapshot)
        -> [ChronoConstellatorGestureAction]
    public func camera(viewSize: Vec2, snapshot: ChronoConstellatorSceneSnapshot) -> ChronoConstellatorCamera?
    public mutating func cancel()
    public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); scene outlines the candidate cell; panel gains "Reset view".
```
