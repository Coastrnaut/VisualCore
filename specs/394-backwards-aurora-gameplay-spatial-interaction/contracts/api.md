# API contract: R02-G10-04

```swift
public struct BackwardsAuroraOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double   // radians
    public static let authored: BackwardsAuroraOrbit; public static let yawLimit: Double
    public static let pitchRange: ClosedRange<Double>; public func clamped() -> BackwardsAuroraOrbit }
extension BackwardsAuroraSceneGeometry {
    public static func camera(_ snapshot: BackwardsAuroraSceneSnapshot, aspect: Double,
                              orbit: BackwardsAuroraOrbit) -> BackwardsAuroraCamera }   // camera(_:aspect:) == authored
extension BackwardsAuroraSceneSnapshot { public let preview: [Int]   // would-be samples; empty when none
    public func withPreview(_ samples: [Int]) -> BackwardsAuroraSceneSnapshot }
public enum BackwardsAuroraPick: Sendable, Equatable { case start, end, band(Int), sample(Int), empty }
public enum BackwardsAuroraPicker {
    public static let minimumTarget: Double        // 22 points
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>, camera: BackwardsAuroraCamera)
        -> (origin: SIMD3<Double>, direction: SIMD3<Double>)?
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: BackwardsAuroraSceneSnapshot,
                            orbit: BackwardsAuroraOrbit) -> BackwardsAuroraPick
    public static func column(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: BackwardsAuroraSceneSnapshot,
                              orbit: BackwardsAuroraOrbit) -> Int? }   // the sample column under the point, clamped
public struct BackwardsAuroraFreezePreview: Sendable, Equatable { public let start: Int; public let end: Int
    public let samples: [Int]; public let kinks: [Int]; public let tear: Int?; public let matched: Int
    public static func make(play: BackwardsAuroraPlay, start: Int, end: Int) -> Self?
    public var text: String }   // "would match 3 of 4 checkpoints, worst bend 9 of 12" / "would tear at seam 5"
public enum BackwardsAuroraGestureAction: Sendable, Equatable { case setStart(Int), setEnd(Int), reverse(Int, Int),
    resetView }
public struct BackwardsAuroraGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, samplePress, endDrag, bandPress, swipe, freeze, orbiting,
        cancelled }
    public static let tapDistance, dragDistance, tapDuration, holdDuration, doubleTapWindow, doubleTapDistance: Double
    public private(set) var state: State; public private(set) var orbit: BackwardsAuroraOrbit
    public private(set) var preview: BackwardsAuroraFreezePreview?
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: BackwardsAuroraSceneSnapshot,
                                play: BackwardsAuroraPlay) -> [BackwardsAuroraGestureAction]
    public func camera(viewSize: Vec2, snapshot: BackwardsAuroraSceneSnapshot) -> BackwardsAuroraCamera?
    public mutating func tick(at time: Double, snapshot: BackwardsAuroraSceneSnapshot, play: BackwardsAuroraPlay)
        // a held press becomes a freeze after holdDuration
    public mutating func cancel(); public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); the scene draws the preview ribbon while it lasts; the panel
// gains "Reset view".
```
