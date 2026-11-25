# API contract: R02-G18-04

```swift
public struct ApsidesWorkshopViewOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double  // rad
    public static let authored: ApsidesWorkshopViewOrbit; public static let yawLimit: Double   // 60°
    public static let pitchRange: ClosedRange<Double>; public func clamped() -> ApsidesWorkshopViewOrbit }  // −20…+35°
extension ApsidesWorkshopSceneSnapshot {
    public var previewOrbit: ApsidesWorkshopOrbit?; public var previewPositions: [ApsidesWorkshopPoint]
    public var previewGauges: [ApsidesWorkshopGauge]
    public func previewing(_ orbit: ApsidesWorkshopOrbit) -> ApsidesWorkshopSceneSnapshot }   // presentation only
extension ApsidesWorkshopSceneGeometry {
    public static func camera(aspect: Double, orbit: ApsidesWorkshopViewOrbit) -> ApsidesWorkshopCamera
        // camera(aspect:) == camera(aspect:orbit: .authored)
    public static func knobCentre(_ snapshot: ApsidesWorkshopSceneSnapshot) -> SIMD3<Double>    // P(0)
    public static func handleCentre(_ snapshot: ApsidesWorkshopSceneSnapshot) -> SIMD3<Double>  // P(T/2)
    public static func compassMesh(_ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier,
                                   camera: ApsidesWorkshopCamera) throws -> Mesh   // billboards for camera
    public static func glowMesh(_ snapshot: ApsidesWorkshopSceneSnapshot, tier: ApsidesWorkshopTier,
                                camera: ApsidesWorkshopCamera) throws -> Mesh }  // (and the fallback parts likewise)
public enum ApsidesWorkshopPick: Sendable, Equatable { case orbiter, sizeHandle, knob, loop, empty }
public enum ApsidesWorkshopPicker {
    public static let orbiterAllowance: Double     // 8 points beyond the projected disc radius
    public static let markerAllowance: Double      // 12 points beyond the projected marker half-size
    public static let loopBand: Double             // 10 points around the projected chords
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>, camera: ApsidesWorkshopCamera)
        -> SIMD2<Double>?                            // view points, origin top-left; nil behind the eye
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ApsidesWorkshopSceneSnapshot,
                            orbit: ApsidesWorkshopViewOrbit) -> ApsidesWorkshopPick
    public static func skyPoint(_ point: SIMD2<Double>, size: SIMD2<Double>, orbit: ApsidesWorkshopViewOrbit)
        -> SIMD2<Double>?                            // lattice units on the plane z = 0
    public static func knobSteps(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ApsidesWorkshopSceneSnapshot,
                                 orbit: ApsidesWorkshopViewOrbit) -> ApsidesWorkshopOrbit?   // size kept; unclamped valid?
    public static func handleSize(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ApsidesWorkshopSceneSnapshot,
                                  orbit: ApsidesWorkshopViewOrbit) -> ApsidesWorkshopOrbit?  // knob kept
    public static func crankTick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: ApsidesWorkshopSceneSnapshot,
                                 orbit: ApsidesWorkshopViewOrbit) -> Int }    // 0 … period − 1
public enum ApsidesWorkshopGestureAction: Sendable, Equatable { case tunePeriapsis(eccentricity: Int, direction: Int),
    tuneSize(Int), showTick(Int), preview(ApsidesWorkshopOrbit), clearPreview, resetView, explain(String) }
public struct ApsidesWorkshopGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, knobPress, knobDrag, handlePress, handleDrag, orbiterPress,
        crankDrag, emptyPress, orbiting, cancelled }
    public static let tapDistance, dragDistance, tapDuration, doubleTapWindow, doubleTapDistance: Double
    public private(set) var state: State; public private(set) var orbit: ApsidesWorkshopViewOrbit
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: ApsidesWorkshopSceneSnapshot)
        -> [ApsidesWorkshopGestureAction]
    public func camera(viewSize: Vec2) -> ApsidesWorkshopCamera?
    public mutating func cancel(); public mutating func resetView() }
// Presenter: pointer(_:viewSize:port:), resetView(); the scene draws with the controller's orbit and the preview; the
// panel gains "Reset view", "Set periapsis" and "Set size" (− and + move the previewed pending orbit). Tunings are sent
// only while playing; the tick in any stage.
```
