# API contract: R02-G08-04

```swift
public struct FacetedForgeOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double   // radians
    public static let authored: FacetedForgeOrbit; public static let yawLimit: Double; public static let pitchRange: ClosedRange<Double>
    public var eyeDirection: SIMD3<Double>   // unit, from the target towards the eye
    public func clamped() -> FacetedForgeOrbit }
extension FacetedForgeSceneGeometry {
    public static func camera(_ snapshot: FacetedForgeSceneSnapshot, aspect: Double,
                              orbit: FacetedForgeOrbit) -> FacetedForgeCamera }   // camera(_:aspect:) == authored
public enum FacetedForgePick: Sendable, Equatable { case rim, plane, piece(Int), empty }
public enum FacetedForgePicker {
    public static let minimumTarget: Double   // 22 points
    public static let pointsPerDepthStep: Double   // 24 points
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>, camera: FacetedForgeCamera)
        -> (origin: SIMD3<Double>, direction: SIMD3<Double>)?
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: FacetedForgeSceneSnapshot,
                            orbit: FacetedForgeOrbit, reduceMotion: Bool) -> FacetedForgePick
    public static func tilt(_ choice: FacetedForgePreviewChoice, drag: SIMD2<Double>, size: SIMD2<Double>,
                            snapshot: FacetedForgeSceneSnapshot, play: FacetedForgePlay, orbit: FacetedForgeOrbit)
        -> FacetedForgePreviewChoice
    public static func depthSteps(drag: SIMD2<Double>, size: SIMD2<Double>, snapshot: FacetedForgeSceneSnapshot,
                                  orbit: FacetedForgeOrbit, reduceMotion: Bool) -> Int }
public enum FacetedForgeGestureAction: Sendable, Equatable {
    case choose(FacetedForgePreviewChoice), cut(Int, Int, Int), resetView }
public struct FacetedForgeGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, rimDrag, depthDrag, planePress, piecePress, orbiting, cancelled }
    public static let tapDistance: Double     // 10 points
    public static let dragDistance: Double    // 16 points
    public static let tapDuration: Double     // 0.5 s
    public static let doubleTapWindow: Double   // 0.35 s
    public static let yawPerViewWidth: Double; public static let pitchPerViewHeight: Double   // 90°, 60°
    public private(set) var state: State; public private(set) var orbit: FacetedForgeOrbit
    public private(set) var candidate: FacetedForgePreviewChoice?
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: FacetedForgeSceneSnapshot,
                                play: FacetedForgePlay) -> [FacetedForgeGestureAction]
    public func camera(viewSize: Vec2, snapshot: FacetedForgeSceneSnapshot) -> FacetedForgeCamera?
    public mutating func cancel()
    public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); the scene draws the candidate choice while dragging; the panel
// gains "Reset view".
```
