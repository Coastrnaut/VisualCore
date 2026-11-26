# API contract: R02-G19-04

```swift
public struct MicroscopicAuroraViewOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double  // rad
    public static let authored: MicroscopicAuroraViewOrbit; public static let yawLimit: Double   // 60°
    public static let pitchRange: ClosedRange<Double>; public func clamped() -> MicroscopicAuroraViewOrbit }  // −20…+35°
public enum MicroscopicAuroraPreviewTarget: Sendable, Equatable { case site(MicroscopicAuroraCell), removal }
public struct MicroscopicAuroraPreview: Sendable, Equatable { public let slot: Int
    public let target: MicroscopicAuroraPreviewTarget; public let wells: [MicroscopicAuroraWell?]
    public let report: MicroscopicAuroraReport; public let positions: [[MicroscopicAuroraPoint]] }
extension MicroscopicAuroraSceneSnapshot {
    public var preview: MicroscopicAuroraPreview?; public var frozen: Bool
    public func previewing(slot: Int, target: MicroscopicAuroraPreviewTarget, level: MicroscopicAuroraLevel)
        -> MicroscopicAuroraSceneSnapshot                                                  // presentation only
    public func freezing(_ frozen: Bool) -> MicroscopicAuroraSceneSnapshot }
extension MicroscopicAuroraSceneGeometry {
    public static func camera(aspect: Double, orbit: MicroscopicAuroraViewOrbit) -> MicroscopicAuroraCamera
        // camera(aspect:) == camera(aspect:orbit: .authored)
    public static let scrubberY: Double            // −1.31
    public static func scrubberPoint(_ fraction: Double) -> SIMD3<Double>
    public static func wellCentre(_ slot: Int, _ snapshot: MicroscopicAuroraSceneSnapshot) -> SIMD3<Double>?
    public static func dishMesh(_ snapshot: MicroscopicAuroraSceneSnapshot, tier: MicroscopicAuroraTier,
                                camera: MicroscopicAuroraCamera) throws -> Mesh   // (and glow, fallback parts likewise)
}
public enum MicroscopicAuroraPick: Sendable, Equatable { case well(Int), site(Int), scrubber, field, empty }
public enum MicroscopicAuroraPicker {
    public static let markerAllowance: Double      // 12 points beyond a projected well or site radius
    public static let scrubberBand: Double         // 14 points around the projected track
    public static let siteReach: Double            // 24 points to snap a dragged well to a site
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>, camera: MicroscopicAuroraCamera)
        -> SIMD2<Double>?                            // view points, origin top-left; nil behind the eye
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: MicroscopicAuroraSceneSnapshot,
                            orbit: MicroscopicAuroraViewOrbit) -> MicroscopicAuroraPick
    public static func dishPoint(_ point: SIMD2<Double>, size: SIMD2<Double>, orbit: MicroscopicAuroraViewOrbit)
        -> SIMD2<Double>?                            // dish units on the plane z = 0
    public static func dropTarget(_ point: SIMD2<Double>, slot: Int, size: SIMD2<Double>,
                                  snapshot: MicroscopicAuroraSceneSnapshot, orbit: MicroscopicAuroraViewOrbit)
        -> MicroscopicAuroraPreviewTarget?           // nil: no change
    public static func scrubTick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: MicroscopicAuroraSceneSnapshot,
                                 orbit: MicroscopicAuroraViewOrbit) -> Int }   // 0 … ticks swum
public enum MicroscopicAuroraGestureAction: Sendable, Equatable { case place(slot: Int, well: MicroscopicAuroraWell),
    move(slot: Int, well: MicroscopicAuroraWell), remove(slot: Int), showTick(Int),
    preview(slot: Int, target: MicroscopicAuroraPreviewTarget), clearPreview, toggleFreeze, selectSlot(Int), resetView,
    explain(String) }
public struct MicroscopicAuroraGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, sitePress, wellPress, wellDrag, scrubberPress, scrubDrag,
        fieldPress, emptyPress, orbiting, cancelled }
    public static let tapDistance, dragDistance, tapDuration, doubleTapWindow, doubleTapDistance: Double
    public private(set) var state: State; public private(set) var orbit: MicroscopicAuroraViewOrbit
    public var strength: Int; public var sense: MicroscopicAuroraSense
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: MicroscopicAuroraSceneSnapshot)
        -> [MicroscopicAuroraGestureAction]
    public func camera(viewSize: Vec2) -> MicroscopicAuroraCamera?
    public mutating func cancel(); public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(), toggleFreeze(); the scene draws with the controller's orbit, the
// preview and the freeze; the panel gains "Freeze" and "Reset view". Placements and removals are sent only while
// playing; the tick in any stage.
```
