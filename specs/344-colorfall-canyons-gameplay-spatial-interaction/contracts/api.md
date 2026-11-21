# API contract: R02-G05-04

```swift
public struct ColorfallCanyonsOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double   // radians
    public static let authored: ColorfallCanyonsOrbit; public static let yawLimit: Double; public static let pitchRange: ClosedRange<Double>
    public func clamped() -> ColorfallCanyonsOrbit }
extension ColorfallCanyonsSceneGeometry {
    public static func camera(_ snapshot: ColorfallCanyonsSceneSnapshot, aspect: Double,
                              orbit: ColorfallCanyonsOrbit) -> ColorfallCanyonsCamera }   // camera(_:aspect:) == authored
public enum ColorfallCanyonsPick: Sendable, Equatable { case cell(Int), spring(Int), empty }
public enum ColorfallCanyonsPicker {
    public static let minimumTarget: Double   // 22 points
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>, camera: ColorfallCanyonsCamera)
        -> (origin: SIMD3<Double>, direction: SIMD3<Double>)?
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ColorfallCanyonsSceneSnapshot,
                            orbit: ColorfallCanyonsOrbit) -> ColorfallCanyonsPick }
public enum ColorfallCanyonsGestureAction: Sendable, Equatable { case carve(Int), valve(Int), resetView }
public struct ColorfallCanyonsGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, dragging, orbiting, cancelled }
    public static let tapDistance: Double     // 10 points
    public static let dragDistance: Double    // 16 points
    public private(set) var state: State; public private(set) var orbit: ColorfallCanyonsOrbit
    public var highlightedCell: Int?
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: ColorfallCanyonsSceneSnapshot)
        -> [ColorfallCanyonsGestureAction]
    public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); scene outlines the highlighted cell; panel gains "Reset view".
```
