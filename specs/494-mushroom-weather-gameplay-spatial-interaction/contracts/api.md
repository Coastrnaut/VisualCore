# API contract: R02-G20-04

```swift
public struct MushroomWeatherViewOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double  // rad
    public static let authored: MushroomWeatherViewOrbit; public static let yawLimit: Double   // 60°
    public static let pitchRange: ClosedRange<Double>; public func clamped() -> MushroomWeatherViewOrbit }  // −20…+35°
public enum MushroomWeatherPreviewKind: Sendable, Equatable { case pod(slot: Int, target: MushroomWeatherCell?)
    // nil target: removal
    case moonlight(level: Int) }
public struct MushroomWeatherPreview: Sendable, Equatable { public let kind: MushroomWeatherPreviewKind
    public let arrangement: MushroomWeatherArrangement; public let report: MushroomWeatherReport
    public let fields: [[Int]] }
extension MushroomWeatherSceneSnapshot {
    public var preview: MushroomWeatherPreview?
    public func previewing(_ kind: MushroomWeatherPreviewKind, level: MushroomWeatherLevel)
        -> MushroomWeatherSceneSnapshot }                                                 // presentation only
extension MushroomWeatherSceneGeometry {
    public static func camera(aspect: Double, orbit: MushroomWeatherViewOrbit) -> MushroomWeatherCamera
        // camera(aspect:) == camera(aspect:orbit: .authored)
    public static let scrubberY: Double            // −0.9
    public static func scrubberPoint(_ fraction: Double) -> SIMD3<Double>
    public static func podCentre(_ slot: Int, _ snapshot: MushroomWeatherSceneSnapshot) -> SIMD3<Double>?
    public static func ventCentre(_ index: Int, _ snapshot: MushroomWeatherSceneSnapshot) -> SIMD3<Double>
    public static func forestMesh(_ snapshot: MushroomWeatherSceneSnapshot, tier: MushroomWeatherTier,
                                  camera: MushroomWeatherCamera) throws -> Mesh   // (and glow, fallback parts likewise)
}
public enum MushroomWeatherPick: Sendable, Equatable { case pod(Int), site(Int), vent(Int), moon, scrubber, floor, empty }
public enum MushroomWeatherPicker {
    public static let markerAllowance: Double      // 12 points beyond a projected pod, site, vent or moon size
    public static let scrubberBand: Double         // 14 points around the projected track
    public static let siteReach: Double            // 24 points to snap a dragged pod to a site
    public static let moonStep: Double             // 40 points of vertical travel per moonlight level
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>, camera: MushroomWeatherCamera)
        -> SIMD2<Double>?                            // view points, origin top-left; nil behind the eye
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: MushroomWeatherSceneSnapshot,
                            orbit: MushroomWeatherViewOrbit) -> MushroomWeatherPick
    public static func floorPoint(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: MushroomWeatherSceneSnapshot,
                                  orbit: MushroomWeatherViewOrbit) -> SIMD2<Double>?   // world units on z = 0
    public static func dropTarget(_ point: SIMD2<Double>, slot: Int, size: SIMD2<Double>,
                                  snapshot: MushroomWeatherSceneSnapshot, orbit: MushroomWeatherViewOrbit)
        -> MushroomWeatherPreviewKind?              // nil: no change
    public static func moonLevel(start: Int, travel: Double) -> Int        // clamp(start + round(−travel / 40), 0, 3)
    public static func scrubCycle(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: MushroomWeatherSceneSnapshot,
                                  orbit: MushroomWeatherViewOrbit) -> Int }   // 0 … cycles run
public enum MushroomWeatherGestureAction: Sendable, Equatable { case place(slot: Int, cell: MushroomWeatherCell),
    move(slot: Int, cell: MushroomWeatherCell), remove(slot: Int), setVent(index: Int, open: Bool),
    setMoonlight(Int), showCycle(Int), preview(MushroomWeatherPreviewKind), clearPreview, selectSlot(Int), resetView,
    explain(String) }
public struct MushroomWeatherGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, sitePress, podPress, podDrag, ventPress, moonPress, moonDrag,
        scrubberPress, scrubDrag, floorPress, emptyPress, orbiting, cancelled }
    public static let tapDistance, dragDistance, tapDuration, doubleTapWindow, doubleTapDistance: Double
    public private(set) var state: State; public private(set) var orbit: MushroomWeatherViewOrbit
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: MushroomWeatherSceneSnapshot)
        -> [MushroomWeatherGestureAction]
    public func camera(viewSize: Vec2) -> MushroomWeatherCamera?
    public mutating func cancel(); public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); the scene draws with the controller's orbit and the preview; the
// panel gains "Reset view". Placements, removals, vent and moonlight changes are sent only while playing; the cycle in
// any stage.
```
