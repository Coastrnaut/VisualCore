# API contract: R02-G09-04

```swift
public struct NocturneGardenOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double   // radians
    public static let authored: NocturneGardenOrbit; public static let yawLimit: Double
    public static let pitchRange: ClosedRange<Double>; public func clamped() -> NocturneGardenOrbit }
extension NocturneGardenSceneGeometry {
    public static func camera(_ snapshot: NocturneGardenSceneSnapshot, aspect: Double,
                              orbit: NocturneGardenOrbit) -> NocturneGardenCamera }   // camera(_:aspect:) == authored
extension NocturneGardenSceneSnapshot { public let preview: [Int]   // sorted would-be cells; empty when none
    public func withPreview(_ cells: [Int]) -> NocturneGardenSceneSnapshot }
public enum NocturneGardenPick: Sendable, Equatable { case lantern, bloom(Int), cell(Int), outside, empty }
public enum NocturneGardenPicker {
    public static let minimumTarget: Double        // 22 points
    public static let pointsPerSunStep: Double     // 48 points
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>, camera: NocturneGardenCamera)
        -> (origin: SIMD3<Double>, direction: SIMD3<Double>)?
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: NocturneGardenSceneSnapshot,
                            orbit: NocturneGardenOrbit) -> NocturneGardenPick
    public static func bedCell(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: NocturneGardenSceneSnapshot,
                               orbit: NocturneGardenOrbit) -> (column: Int, row: Int, inside: Bool)?
    public static func sunElevation(from elevation: Int, drag: Double, allowed: [Int]) -> Int
    public static func pinchSize(from size: Int, scale: Double, allowed: [Int]) -> Int }
public struct NocturneGardenDragPreview: Sendable, Equatable { public let bloom: Int; public let column: Int
    public let row: Int; public let removes: Bool; public let cells: [Int]; public let shared: Int
    public let either: Int; public let leak: Int
    public static func make(play: NocturneGardenPlay, bloom: Int, column: Int, row: Int, removes: Bool) -> Self?
    public var text: String }   // "would match 12/16, leak 0 cells"
public enum NocturneGardenGestureAction: Sendable, Equatable {
    case plant(NocturneGardenKind, Int, Int, Int), move(Int, Int, Int), remove(Int), resize(Int, Int), sun(Int),
         choose(Int), resetView }
public struct NocturneGardenGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, bedPress, bloomPress, bloomDrag, lanternDrag, pinch, orbiting,
        cancelled }
    public static let tapDistance, dragDistance, tapDuration, doubleTapWindow, doubleTapDistance: Double
    public private(set) var state: State; public private(set) var orbit: NocturneGardenOrbit
    public private(set) var preview: NocturneGardenDragPreview?
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: NocturneGardenSceneSnapshot,
                                play: NocturneGardenPlay, kind: NocturneGardenKind, size: Int)
        -> [NocturneGardenGestureAction]
    public func camera(viewSize: Vec2, snapshot: NocturneGardenSceneSnapshot) -> NocturneGardenCamera?
    public mutating func cancel(); public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); the scene draws the preview outline while dragging; the panel
// gains "Reset view".
```
