# API contract: R02-G15-04

```swift
public struct VoxelOrigamiOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double   // radians
    public static let authored: VoxelOrigamiOrbit; public static let yawLimit: Double     // 60°
    public static let pitchRange: ClosedRange<Double>; public func clamped() -> VoxelOrigamiOrbit }   // −20° … +35°
extension VoxelOrigamiSceneGeometry {
    public static func camera(_ snapshot: VoxelOrigamiSceneSnapshot, aspect: Double,
                              orbit: VoxelOrigamiOrbit) -> VoxelOrigamiCamera     // camera(_:aspect:) == authored
    public static func voxelMesh(_ snapshot: VoxelOrigamiSceneSnapshot, tier: VoxelOrigamiTier, reduceMotion: Bool,
                                 camera: VoxelOrigamiCamera) throws -> Mesh       // billboards, order, culling for camera
    public static func glowMesh(_ snapshot: VoxelOrigamiSceneSnapshot, tier: VoxelOrigamiTier,
                                camera: VoxelOrigamiCamera) throws -> Mesh }      // (and the fallback parts likewise)
public enum VoxelOrigamiPick: Sendable, Equatable { case cube(Int), empty }
public struct VoxelOrigamiTurnPrediction: Sendable, Equatable { public let hinge: Int
    public let plus: SIMD2<Double>; public let minus: SIMD2<Double>              // view points
    public func step(for travel: SIMD2<Double>, threshold: Double) -> Int? }     // ±1 once the projection reaches it
public enum VoxelOrigamiPicker {
    public static let cubeAllowance: Double        // 8 points beyond the projected outline
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>, camera: VoxelOrigamiCamera)
        -> SIMD2<Double>?                            // view points, origin top-left; nil behind the eye
    public static func outline(_ cube: Int, size: SIMD2<Double>, snapshot: VoxelOrigamiSceneSnapshot,
                               camera: VoxelOrigamiCamera) -> [SIMD2<Double>]   // convex hull, counter-clockwise
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: VoxelOrigamiSceneSnapshot,
                            orbit: VoxelOrigamiOrbit) -> VoxelOrigamiPick
    public static func prediction(_ hinge: Int, size: SIMD2<Double>, snapshot: VoxelOrigamiSceneSnapshot,
                                  orbit: VoxelOrigamiOrbit) -> VoxelOrigamiTurnPrediction? }
public enum VoxelOrigamiGestureAction: Sendable, Equatable { case chooseHinge(Int), pendingTurn(hinge: Int, step: Int),
    clearPending, turn(hinge: Int, step: Int), resetView, explain(String) }
public struct VoxelOrigamiGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, cubePress, cubeDrag, emptyPress, orbiting, cancelled }
    public static let tapDistance, dragDistance, tapDuration, doubleTapWindow, doubleTapDistance: Double
    public static let turnDistance: Double         // 24 points
    public private(set) var state: State; public private(set) var orbit: VoxelOrigamiOrbit
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: VoxelOrigamiSceneSnapshot)
        -> [VoxelOrigamiGestureAction]
    public func camera(viewSize: Vec2, snapshot: VoxelOrigamiSceneSnapshot) -> VoxelOrigamiCamera?
    public mutating func cancel(); public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); the scene draws with the controller's orbit; the panel gains
// "Reset view". turn is sent only while playing; chooseHinge goes through `hinge.choose` in any stage.
```
