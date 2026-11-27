# API contract: R02-G21-04

All in `BinaryGardensCore` unless marked; every new public name gets `///` documentation. Existing signatures keep
their behaviour (the camera-free overloads equal the camera-taking ones at the authored camera).

```swift
public struct BinaryGardensViewOrbit: Sendable, Equatable { public var yaw: Double; public var pitch: Double  // rad
    public init(yaw: Double, pitch: Double)
    public static let authored: BinaryGardensViewOrbit; public static let yawLimit: Double          // 60°
    public static let yawRange: ClosedRange<Double>; public static let pitchRange: ClosedRange<Double>  // −20…+35°
    public func clamped() -> BinaryGardensViewOrbit; public var isWithinBounds: Bool
    public static let corners: [BinaryGardensViewOrbit] }

public struct BinaryGardensStarFreedom: Sendable, Equatable { public let ring: Bool; public let phase: Bool
    public let luminosity: Bool; public init(ring: Bool, phase: Bool, luminosity: Bool) }

public struct BinaryGardensPreview: Sendable, Equatable {
    public enum Outcome: Sendable, Equatable { case accepted(arrangement: BinaryGardensArrangement,
                                                             report: BinaryGardensReport)
                                               case refused(BinaryGardensError) }
    public let change: BinaryGardensAction            // .ring, .phase, .luminosity or .tilt
    public let outcome: Outcome
    public var report: BinaryGardensReport? { get }   // nil when refused
    public var wins: Bool? { get }                    // the previewed verdict; nil when refused
    public static func of(_ change: BinaryGardensAction, arrangement: BinaryGardensArrangement, actionsLeft: Int,
                          level: BinaryGardensLevel) -> BinaryGardensPreview? }
    // kernel `BinaryGardensSky.changed`, then `.budget` when actionsLeft ≤ 0, then `BinaryGardensSky.report`;
    // nil for .run or an unchanged value

public struct BinaryGardensSceneSnapshot {           // additions only (stored properties in the struct)
    public let starSpeed: Int                         // ω (stored; set by init(play:…), default 1 when unchecked)
    public let freedoms: [BinaryGardensStarFreedom]   // stored; default all adjustable when unchecked
    public private(set) var preview: BinaryGardensPreview?        // nil from every initialiser
    public private(set) var inspectedWorld: Int?                  // nil from every initialiser
    public func starStep(_ star: Int, tick: Int) -> Int           // (θ + ω·tick) mod 48
    public func previewing(_ change: BinaryGardensAction, level: BinaryGardensLevel) -> BinaryGardensSceneSnapshot
    public func clearingPreview() -> BinaryGardensSceneSnapshot
    public func inspecting(_ world: Int?) -> BinaryGardensSceneSnapshot }   // out of range → nil; presentation only

extension BinaryGardensSceneGeometry {
    public static let refitMargin: Double                         // 0.06
    public static let inspectRingRadius: Double                   // 0.115
    public static let bracketWidth: Double; public static let bracketHalf: Double   // 0.006; 0.05
    public static let bracketLeft: Double; public static let bracketRight: Double   // −0.962; 1.232
    public static let ghostCellWidth: Double                      // 0.003 (outline strips)
    public static func camera(aspect: Double, orbit: BinaryGardensViewOrbit) -> BinaryGardensCamera
        // camera(aspect:) == camera(aspect:orbit: .authored), bit for bit
    public static func paintOrder(_ snapshot: BinaryGardensSceneSnapshot, eye: SIMD3<Double>) -> [BinaryGardensElement]
    public static func luminosityPips(_ star: Int, _ snapshot: BinaryGardensSceneSnapshot,
                                      eye: SIMD3<Double>) -> [(centre: SIMD3<Double>, lit: Bool)]
    public static func worldPips(_ world: Int, _ snapshot: BinaryGardensSceneSnapshot,
                                 eye: SIMD3<Double>) -> [SIMD3<Double>]
    public static func starRadius(_ star: Int, _ snapshot: BinaryGardensSceneSnapshot) -> Double   // made public
    public static func drawnSnapshot(_ snapshot: BinaryGardensSceneSnapshot) -> BinaryGardensSceneSnapshot
        // the preview applied (research R5); itself without a preview
    public static func ghostStars(_ snapshot: BinaryGardensSceneSnapshot)
        -> [(star: Int, centre: SIMD3<Double>, radius: Double, refused: Bool)]   // empty without a preview
    public static func systemMesh(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier,
                                  camera: BinaryGardensCamera) throws(MeshError) -> Mesh
    public static func glowMesh(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier,
                                camera: BinaryGardensCamera) throws(MeshError) -> Mesh
    public static func systemPart(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier, wonLevel: Bool?,
                                  camera: BinaryGardensCamera) throws(MeshError) -> BinaryGardensColouredMesh
    public static func glowPart(_ snapshot: BinaryGardensSceneSnapshot, tier: BinaryGardensTier, wonLevel: Bool?,
                                camera: BinaryGardensCamera) throws(MeshError) -> BinaryGardensColouredMesh }

// BinaryGardensMaterial gains: ghostStar = 38 (quad, dashed ring of the star's colour; broken when refused),
// ghostCell = 39 (outline strips, the committed band's cell colour; value = band index / 4), inspectRing = 40 (quad,
// ring, marker colour), inspectBracket = 41 (strip, marker colour); BinaryGardensShaders.maxMaterial = 41.

public enum BinaryGardensPick: Sendable, Equatable {
    case gauge(Int), pips(Int), star(Int), world(Int), ring(Int), dial, disc, empty }
public enum BinaryGardensStarDragMode: Sendable, Equatable { case ring, phase }
public enum BinaryGardensPicker {
    public static let markerAllowance: Double         // 12 points
    public static let stepTravel: Double              // 32 points of horizontal travel per luminosity or tilt step
    public static let tangentFloor: Double            // 0.5 points
    public static func camera(size: SIMD2<Double>, orbit: BinaryGardensViewOrbit) -> BinaryGardensCamera?
    public static func viewPoint(_ point: SIMD3<Double>, size: SIMD2<Double>, camera: BinaryGardensCamera)
        -> SIMD2<Double>?                               // view points, origin top-left; nil behind the eye
    public static func projectedExtent(_ extent: Double, at centre: SIMD3<Double>, size: SIMD2<Double>,
                                       camera: BinaryGardensCamera) -> Double?
    public static func pick(_ point: SIMD2<Double>, size: SIMD2<Double>, snapshot: BinaryGardensSceneSnapshot,
                            orbit: BinaryGardensViewOrbit) -> BinaryGardensPick
    public static func planePoint(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                  orbit: BinaryGardensViewOrbit) -> SIMD2<Double>?   // world units on z = 0
    public static func tangent(star: Int, size: SIMD2<Double>, snapshot: BinaryGardensSceneSnapshot,
                               orbit: BinaryGardensViewOrbit) -> SIMD2<Double>?
    public static func dragMode(travel: SIMD2<Double>, star: Int, size: SIMD2<Double>,
                                snapshot: BinaryGardensSceneSnapshot, orbit: BinaryGardensViewOrbit)
        -> BinaryGardensStarDragMode?                   // nil: ring and phase both locked
    public static func ringTarget(_ point: SIMD2<Double>, star: Int, size: SIMD2<Double>,
                                  snapshot: BinaryGardensSceneSnapshot, orbit: BinaryGardensViewOrbit) -> Int
    public static func phaseTarget(_ point: SIMD2<Double>, star: Int, size: SIMD2<Double>,
                                   snapshot: BinaryGardensSceneSnapshot, orbit: BinaryGardensViewOrbit) -> Int
    public static func nearestPip(_ point: SIMD2<Double>, star: Int, size: SIMD2<Double>,
                                  snapshot: BinaryGardensSceneSnapshot, orbit: BinaryGardensViewOrbit) -> Int
    public static func nearestTiltPip(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                      snapshot: BinaryGardensSceneSnapshot, orbit: BinaryGardensViewOrbit) -> Int
    public static func stepValue(start: Int, travel: Double, upper: Int) -> Int   // clamp(start + round(dx/32), 0, upper)
    public static func gaugeX(_ point: SIMD2<Double>, size: SIMD2<Double>, orbit: BinaryGardensViewOrbit) -> Double?
    public static func gaugeTick(_ point: SIMD2<Double>, size: SIMD2<Double>,
                                 orbit: BinaryGardensViewOrbit) -> Int?          // 1 … 48, x clamped to the cells
}

public enum BinaryGardensGestureAction: Sendable, Equatable {
    case setRing(star: Int, index: Int), setPhase(star: Int, step: Int), setLuminosity(star: Int, index: Int),
         setTilt(Int), showTick(Int), inspectWorld(Int?), selectStar(Int), preview(BinaryGardensAction), clearPreview,
         resetView, explain(String) }
public struct BinaryGardensGestureController: Sendable {
    public enum State: Sendable, Equatable { case idle, starPress, ringDrag, phaseDrag, pipsPress, luminosityDrag,
        dialPress, tiltDrag, gaugePress, scrubDrag, worldPress, ringPress, discPress, emptyPress, orbiting, cancelled }
    public static let tapDistance: Double             // 10
    public static let dragDistance: Double            // 16
    public static let tapDuration: Double             // 0.5 s
    public static let doubleTapWindow: Double         // 0.35 s
    public static let doubleTapDistance: Double       // 22
    public static let yawPerViewWidth: Double         // π / 2
    public static let pitchPerViewHeight: Double      // π / 3
    public static let finishedReason: String          // "The play is over: undo or go to the next level"
    public static let notRunningReason: String        // "The level is not being played"
    public static let starReason: String              // "Drag a star along its orbit to shift its phase, or across the rings to move it"
    public static let ringReason: String              // "Drag a star across the rings to move it to another ring"
    public static let fixedReason: String             // "This star's ring and phase are fixed"
    public static let luminosityLockedReason: String  // "This star's brightness is fixed"
    public static let singleLevelReason: String       // "This level has a single brightness"
    public private(set) var state: State; public private(set) var orbit: BinaryGardensViewOrbit
    public init()
    public mutating func handle(_ event: PointerEvent, viewSize: Vec2, snapshot: BinaryGardensSceneSnapshot)
        -> [BinaryGardensGestureAction]
    public func camera(viewSize: Vec2) -> BinaryGardensCamera?
    public mutating func cancel(); public mutating func resetView() }
```

Experience (`BinaryGardensExperience`, internal):

- `BinaryGardensPresenter.pointer(_:viewSize:port:)` routes through the controller with the drawn snapshot (the core's
  snapshot with the mirror's preview and inspection applied) and sends `star.ring [star, index]`, `star.phase [star,
  step]`, `star.luminosity [star, index]`, `orbit.tilt [step]` (each dropping the preview) and `clock.show [tick]`;
  keeps `preview`, `inspectedWorld` and the selected star in the mirror; shows explanations and refusals in words;
  keeps every refused action's bare code in `refusalLog` (at most 64). `resetView()`, `cancelPointers()`, `orbit`,
  `gestureState`, `gestureActions` = `["star.ring", "star.phase", "star.luminosity", "orbit.tilt", "clock.show"]`,
  `nativeActions` = every declared control. An opening, `level.next`, reset or restore clears the preview, the
  inspection and the orbit.
- `BinaryGardensSystemScene.orbit` and the inspection and preview in its geometry key; meshes from the camera-taking
  builders at `camera(aspect:orbit:)`.
- `BinaryGardensControls` keeps every row and gains: Ring (picker, ring 1 … n), Luminosity (picker, level 1 … L), Phase
  target (stepper by g) with "Set phase", Tilt (picker 0 … T_max, when T_max > 0), "Inspect" (none, world 1 … W) and
  "Reset view"; each choice sends one action; the inspected world's words below the Inspect row.
