# API contract: R02-G07-04

```swift
public struct AmethystEscapeOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double   // radians
    public static let authored: AmethystEscapeOrbit; public static let yawLimit: Double; public static let pitchRange: ClosedRange<Double>
    public var eyeDirection: SIMD3<Double>   // unit, from the target towards the eye
    public func clamped() -> AmethystEscapeOrbit }
extension AmethystEscapeSceneGeometry {
    public static func camera(_ snapshot: AmethystEscapeSceneSnapshot, aspect: Double,
                              orbit: AmethystEscapeOrbit) -> AmethystEscapeCamera   // camera(_:aspect:) == authored
    public static func crystalPart(_ snapshot: AmethystEscapeSceneSnapshot, tier: AmethystEscapeTier,
                                   isolated: Int?) throws(MeshError) -> AmethystEscapeColouredMesh }   // others at shade 0.25
extension AmethystEscapeSceneSnapshot {
    public func previewing(shell: Int, sectors: Int) -> AmethystEscapeSceneSnapshot }   // offset (and pearl) turned
public enum AmethystEscapePick: Sendable, Equatable { case pearl, shell(Int), empty }
public enum AmethystEscapePicker {
    public static let minimumTarget: Double   // 22 points
    public static func ray(_ point: SIMD2<Double>, size: SIMD2<Double>, camera: AmethystEscapeCamera)
        -> (origin: SIMD3<Double>, direction: SIMD3<Double>)?
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: AmethystEscapeSceneSnapshot,
                            orbit: AmethystEscapeOrbit) -> AmethystEscapePick
    public static func angle(shell: Int, at point: SIMD2<Double>, size: SIMD2<Double>,
                             snapshot: AmethystEscapeSceneSnapshot, orbit: AmethystEscapeOrbit) -> Double? }   // atan2(z, x) on y = h_k
public enum AmethystEscapeGestureAction: Sendable, Equatable {
    case turn(Int, Int), advance, select(Int), isolate(Int?), resetView }
public struct AmethystEscapeGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, shellDrag, pearlPress, orbiting, cancelled }
    public static let tapDistance: Double     // 10 points
    public static let dragDistance: Double    // 16 points
    public static let tapDuration: Double     // 0.5 s
    public static let doubleTapWindow: Double   // 0.35 s
    public static let yawPerViewWidth: Double; public static let pitchPerViewHeight: Double   // 90°, 60°
    public private(set) var state: State; public private(set) var orbit: AmethystEscapeOrbit
    public private(set) var draggedShell: Int?; public private(set) var candidateSectors: Int
    public private(set) var isolated: Int?
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: AmethystEscapeSceneSnapshot)
        -> [AmethystEscapeGestureAction]
    public func camera(viewSize: Vec2, snapshot: AmethystEscapeSceneSnapshot) -> AmethystEscapeCamera?
    public mutating func cancel()
    public mutating func resetView()
    public mutating func clearIsolation() }
// Presenter: pointer(_:viewSize:port:), resetView(), showAllLayers(); scene draws the preview and isolation; panel
// gains "Show all layers" and "Reset view".
```
