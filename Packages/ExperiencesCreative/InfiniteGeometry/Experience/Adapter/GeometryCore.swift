// GeometryCore — feature 040 (A05-P01) T-A05-104 (FR-A05-120, FR-A05-130; data-model GeometryCore; clarifications).
// The state of Infinite Geometry as an experience: the preparation seed, the curated preset last selected and the
// current preset with the digest and element count of the composition it builds. Every change is checked twice
// before it is taken: the preset must validate (`GeometryPreset.validated()`) and its composition must build within
// its budget (`Composition.build`); a failure refuses the action with the error's code and changes nothing, so an
// accepted state always builds and the outcome `composition-built` holds after the preparation and after every
// accepted change (clarification 5).
//
// Compositions are static: nothing moves with time, so `update(step:)` does nothing and the digest depends only on
// the preparation seed and the accepted actions. The snapshot is the core itself as JSON (seed, preset index,
// preset); decoding rebuilds the composition, so a damaged or foreign payload that no longer builds is refused.
//
// Feature 041 (A05-P02) T-A05-206 (FR-A05-210, FR-A05-211, FR-A05-213; data-model "Camera state"): the camera is
// part of the state. `view2D` (centre and zoom of the tilings and the kaleidoscope) and `orbit3D` (yaw, pitch and
// distance of the 3D composition) change only through `camera.pan`, `camera.zoom`, `camera.orbit` and
// `camera.reset`, each clamped by VisualCoreMath's `ViewBounds2D` (zoom 0.5…8, centre within ±1/scale) and
// `OrbitBounds` (pitch ±80°, distance 3…12), so the state never holds an out-of-bounds camera. Selecting a preset
// returns both cameras to the preset's default; a new scale clamps the centre into the new extent. Snapshot schema 2
// adds the two cameras; a schema-1 payload (Phase 01) is migrated by the shared `MigrationChain` with the defaults.
//
// Feature 042 (A05-P03) T-A05-305 (FR-A05-310–314; data-model "GeometryCore.Orbit3D (schema 3)"): the orbit camera
// gains a target (|target| ≤ 1, default the origin) and a vertical field of view (30…75°, default 60°). On the 3D
// composition `camera.pan [dx, dy]` moves the target along the camera's right and up vectors, `camera.fov [degrees]`
// sets the field of view, and pan, zoom and orbit are clamped by VisualCoreMath's `OrbitViewBounds`, whose distance
// rule keeps the eye outside the composition's bounding sphere: minimum distance = max(3, |target| + R + 2 · near),
// R = |bounds centre| + bounds radius of the built solid (derived, never stored; 0 for a 2D preset). Snapshot schema 3
// adds target and field of view; the chain 1 → 2 → 3 fills the defaults.
//
// Feature 043 (A05-P04) T-A05-402 (FR-A05-401, FR-A05-402; contracts/api.md): `composition.open` replaces the whole
// composition at once with the 18 values of a `GeometryDocument` (`openValues`). Every value is checked before anything
// changes: a wrong count, a non-finite value or a value outside its range (or not whole where it must be) is refused
// with its index, a preset that does not build with its rule code, a camera outside the bounds of the built composition
// with `a05.open-out-of-bounds` (the same clamp-equality rule as a restore), the current state as unchanged; otherwise
// preset index, preset, composition and both cameras are replaced together.
import Foundation
import InfiniteGeometryCore
import VisualCoreExperience
import VisualCoreMath
import VisualCorePersistence
import VisualCoreScenes

/// The state of Infinite Geometry: the preparation seed, the selected curated preset, the current preset with the
/// composition it builds and the two cameras. Schema version 3.
public struct GeometryCore: ExperienceCore, Equatable, Codable {
    /// The 2D camera of the tilings and the kaleidoscope: the view centre in world units and the zoom relative to
    /// the preset's fit (the square −1…1 on the view's shorter side).
    public struct View2D: Sendable, Equatable, Codable {
        /// The view centre's x in world units.
        public var centerX: Double
        /// The view centre's y in world units.
        public var centerY: Double
        /// The magnification relative to the preset's fit.
        public var zoom: Double

        /// The preset's default: centre 0, zoom 1.
        public static let `default` = View2D(centerX: 0, centerY: 0, zoom: 1)

        /// Creates the camera from its centre and zoom.
        public init(centerX: Double, centerY: Double, zoom: Double) {
            self.centerX = centerX
            self.centerY = centerY
            self.zoom = zoom
        }

        /// The values of `camera` (its rotation is always 0 here).
        public init(_ camera: Camera2D) {
            self.init(centerX: camera.center.x, centerY: camera.center.y, zoom: camera.zoom)
        }

        /// The VisualCoreMath camera with this centre and zoom.
        public var camera: Camera2D { Camera2D(center: Vec2(centerX, centerY), zoom: zoom) }
    }

    /// The orbit camera of the 3D composition: yaw (−π…π), pitch, distance to the target, the target (|target| ≤ 1)
    /// and the vertical field of view in degrees (30…75).
    public struct Orbit3D: Sendable, Equatable, Codable {
        /// The yaw in radians, wrapped into −π…π.
        public var yaw: Double
        /// The pitch in radians.
        public var pitch: Double
        /// The eye's distance to the target.
        public var distance: Double
        /// The target's x in world units.
        public var targetX: Double
        /// The target's y in world units.
        public var targetY: Double
        /// The target's z in world units.
        public var targetZ: Double
        /// The vertical field of view in degrees.
        public var fovDegrees: Double

        /// The preset's default: yaw 0, pitch 0.5, distance 6 (the Phase 01 camera), target at the origin, 60°.
        public static let `default` = Orbit3D(yaw: 0, pitch: 0.5, distance: 6)

        /// Creates the camera from its angles, distance, target and field of view in degrees.
        public init(yaw: Double, pitch: Double, distance: Double, target: Vec3 = .zero, fovDegrees: Double = 60) {
            self.yaw = yaw
            self.pitch = pitch
            self.distance = distance
            targetX = target.x
            targetY = target.y
            targetZ = target.z
            self.fovDegrees = fovDegrees
        }

        /// The angles, distance and target of `camera` with the field of view `fovDegrees`, which is carried as
        /// given (never converted back from radians, so a field of view keeps its exact value).
        public init(_ camera: OrbitCamera, fovDegrees: Double) {
            self.init(yaw: camera.yaw, pitch: camera.pitch, distance: camera.distance, target: camera.target,
                      fovDegrees: fovDegrees)
        }

        /// The target as a vector.
        public var target: Vec3 { Vec3(targetX, targetY, targetZ) }

        /// The VisualCoreMath orbit camera looking at `target` with the field of view in radians.
        public var camera: OrbitCamera {
            OrbitCamera(target: target, distance: distance, yaw: yaw, pitch: pitch, fovY: fovDegrees * Double.pi / 180)
        }

        /// All seven values, in declaration order.
        var values: [Double] { [yaw, pitch, distance, targetX, targetY, targetZ, fovDegrees] }

        /// Whether every value equals the one of `other` within `tolerance` relative to its magnitude (at least 1),
        /// so a clamp that rescales the target at its limit by one rounding step counts as no change.
        func isNearlyEqual(to other: Orbit3D, tolerance: Double = 1e-12) -> Bool {
            zip(values, other.values).allSatisfy { abs($0 - $1) <= tolerance * max(1, abs($0), abs($1)) }
        }
    }

    /// The experience's id in the catalog.
    public static let experienceID = "a05.infinite-geometry"
    /// The step `reseed` adds to the motif seed (the golden-ratio increment, as Particle Universe's "New seed").
    public static let seedStep: UInt64 = 0x9E37_79B9_7F4A_7C15
    /// The outcome code reached while the current preset builds.
    public static let outcomeCode = "composition-built"
    /// The rule code of `symmetry.order` on a tiling: the lattice fixes the symmetry (FR-A05-120).
    public static let orderFixedCode = "a05.order-fixed-by-lattice"
    /// The rule code of an action that would leave the preset as it is.
    public static let unchangedCode = "a05.unchanged"
    /// The rule code of a preparation or a restore whose preset does not build or whose camera is out of bounds.
    public static let invalidStateCode = "a05.invalid-state"
    /// The rule code `camera.pan` on the 3D composition had in Phase 02; since Phase 03 (FR-A05-310) a pan on the
    /// solid moves the orbit target and this code is no longer returned. Kept so recorded results stay readable.
    public static let panPlaneOnlyCode = "a05.pan-plane-only"
    /// The rule code of `composition.open` whose camera lies outside the bounds of the composition it builds, or whose
    /// kind is not the kind of the curated preset it names (FR-A05-402).
    public static let openOutOfBoundsCode = "a05.open-out-of-bounds"
    /// The rule code of `camera.fov` on a 2D preset (the field of view belongs to the 3D composition).
    public static let fovSolidOnlyCode = "a05.fov-solid-only"
    /// The rule code of `camera.orbit` on a 2D preset (it pans instead).
    public static let orbitSolidOnlyCode = "a05.orbit-solid-only"
    /// The 2D zoom range relative to the preset's fit (FR-A05-210).
    public static let zoomRange: ClosedRange<Double> = 0.5...8
    /// The bounds of the orbit camera: pitch ±80°, distance 3…12, yaw free (FR-A05-210).
    public static let orbitBounds = OrbitBounds(pitchLimit: 80 * Double.pi / 180, distanceRange: 3...12)
    /// The control ranges of the camera actions: pan in world units, zoom factor (> 0), orbit in radians.
    public static let panRange: ClosedRange<Double> = -8...8
    /// The accepted zoom factors of one `camera.zoom` (strictly positive).
    public static let zoomFactorRange: ClosedRange<Double> = 0.01...100
    /// The accepted angle of one `camera.orbit` step, per axis.
    public static let orbitRange: ClosedRange<Double> = -2 * Double.pi...2 * Double.pi
    /// The field of view of the orbit camera in degrees (FR-A05-311); `camera.fov` outside it is refused.
    public static let fovRange: ClosedRange<Double> = 30...75
    /// The largest distance of the orbit target from the origin, in world units (FR-A05-310).
    public static let targetRadius = 1.0

    /// The bounds of the orbit camera on a composition of bounding radius `clearance` (FR-A05-310–312): the
    /// Phase 02 `orbitBounds`, the target within `targetRadius`, the field of view within `fovRange` (in radians)
    /// and the distance rule max(3, |target| + clearance + 2 · near).
    public static func orbitViewBounds(clearance: Double) -> OrbitViewBounds {
        OrbitViewBounds(orbit: orbitBounds, targetRadius: targetRadius,
                        fovRange: fovRange.lowerBound * Double.pi / 180...fovRange.upperBound * Double.pi / 180,
                        clearance: clearance)
    }

    /// The bounding radius of `composition` about the origin: |bounds centre| + bounds radius of the solid's mesh,
    /// 0 for a plane or an empty mesh.
    public static func boundingRadius(of composition: Composition) -> Double {
        guard case .solid(let mesh) = composition, let centre = mesh.bounds.center, let radius = mesh.bounds.radius
        else { return 0 }
        return centre.length + radius
    }

    /// The bounds of the 2D camera for a preset of `scale`: zoom 0.5…8, centre within the composition's extent ±1/scale.
    public static func viewBounds(scale: Double) -> ViewBounds2D {
        ViewBounds2D(zoomRange: zoomRange, extent: 1 / scale)
    }

    /// The preparation seed; `reset()` returns to curated preset 0 with it.
    public private(set) var seed: UInt64
    /// The index of the curated preset last selected (0 ..< `GeometryPreset.curated.count`).
    public private(set) var presetIndex: Int
    /// The current, validated preset.
    public private(set) var preset: GeometryPreset
    /// The digest of the composition `preset` builds (derived; not encoded, rebuilt on decoding).
    public private(set) var compositionDigest: String
    /// The number of elements of that composition: polygons for a plane, triangles for a solid (derived).
    public private(set) var elementCount: Int
    /// The 2D camera, always within `viewBounds(scale: preset.scale)`.
    public private(set) var view2D: View2D = .default
    /// The orbit camera, always within `orbitViewBounds`.
    public private(set) var orbit3D: Orbit3D = .default
    /// The bounding radius of the current composition (derived from the built mesh; 0 for a 2D preset).
    public private(set) var boundingRadius: Double = 0

    /// The bounds of the orbit camera on the current composition.
    public var orbitViewBounds: OrbitViewBounds { Self.orbitViewBounds(clearance: boundingRadius) }

    // MARK: Contract

    /// Schema 3 (target and field of view added). The step from schema 1 fills the preset's default cameras as
    /// Phase 02 stored them (FR-A05-213); the step from schema 2 adds the default target (the origin) and field of
    /// view (60°) to the orbit camera (FR-A05-314), so a Phase 01 payload passes through both.
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: 3, steps: [
            1: { payload in
                var upgraded = payload
                let view = View2D.default, orbit = Orbit3D.default
                upgraded[CodingKeys.view2D.rawValue] = ["centerX": view.centerX, "centerY": view.centerY,
                                                        "zoom": view.zoom]
                upgraded[CodingKeys.orbit3D.rawValue] = ["yaw": orbit.yaw, "pitch": orbit.pitch,
                                                         "distance": orbit.distance]
                return upgraded
            },
            2: { payload in
                var upgraded = payload
                let orbit = Orbit3D.default
                var camera = payload[CodingKeys.orbit3D.rawValue] as? [String: Any] ?? [:]
                camera["targetX"] = orbit.targetX
                camera["targetY"] = orbit.targetY
                camera["targetZ"] = orbit.targetZ
                camera["fovDegrees"] = orbit.fovDegrees
                upgraded[CodingKeys.orbit3D.rawValue] = camera
                return upgraded
            },
        ])
    }

    /// The six actions of FR-A05-120 with the ranges of `GeometryPreset`, then the four camera actions of
    /// FR-A05-210 and the field of view of FR-A05-311. Whole-number controls round their value.
    public static var controls: [ExperienceControl] {
        [
            ExperienceControl(id: "preset.select", ranges: [0...Double(GeometryPreset.curated.count - 1)]),
            ExperienceControl(id: "symmetry.order", ranges: [range(GeometryPreset.orderRange)]),
            ExperienceControl(id: "repeats.set", ranges: [range(GeometryPreset.repeatsRange)]),
            ExperienceControl(id: "scale.set", ranges: [GeometryPreset.scaleRange]),
            ExperienceControl(id: "palette.set", ranges: [range(GeometryPreset.paletteRange)]),
            ExperienceControl(id: "reseed"),
            ExperienceControl(id: "camera.pan", ranges: [panRange, panRange]),
            ExperienceControl(id: "camera.zoom", ranges: [zoomFactorRange]),
            ExperienceControl(id: "camera.orbit", ranges: [orbitRange, orbitRange]),
            ExperienceControl(id: "camera.reset"),
            ExperienceControl(id: "camera.fov", ranges: [fovRange]),
            ExperienceControl(id: "composition.open", ranges: GeometryDocument.openRanges),
        ]
    }

    /// An integer range as the closed range of doubles a control declares.
    private static func range(_ r: ClosedRange<Int>) -> ClosedRange<Double> {
        Double(r.lowerBound)...Double(r.upperBound)
    }

    /// Curated preset 0 with `seed` as its motif seed, built once to prove it fits its budget.
    public static func prepare(seed: UInt64) async throws -> GeometryCore {
        try Task.checkCancellation()
        return try GeometryCore(seed: seed)
    }

    /// The preparation: curated preset 0 with `seed` as motif seed. Throws `ExperienceFailure` when it does not build.
    init(seed: UInt64) throws(ExperienceFailure) {
        var start = GeometryPreset.curated[0]
        start.seed = seed
        try self.init(seed: seed, presetIndex: 0, preset: start)
    }

    /// The state of `preset` with the cameras `view` and `orbit`, validated and built; throws `ExperienceFailure`
    /// with the error's code otherwise, or `a05.invalid-state` when a camera lies outside its bounds (the orbit
    /// camera against `orbitViewBounds` of the built composition, the field of view against `fovRange`).
    private init(seed: UInt64, presetIndex: Int, preset: GeometryPreset, view: View2D = .default,
                 orbit: Orbit3D = .default) throws(ExperienceFailure) {
        guard GeometryPreset.curated.indices.contains(presetIndex) else {
            throw ExperienceFailure(code: Self.invalidStateCode, message: "preset index \(presetIndex)")
        }
        switch Self.build(preset) {
        case .success(let built):
            self.seed = seed
            self.presetIndex = presetIndex
            self.preset = built.preset
            compositionDigest = built.composition.digest
            elementCount = built.composition.elementCount
            boundingRadius = built.boundingRadius
        case .failure(let rejection):
            throw ExperienceFailure(code: Self.invalidStateCode, message: rejection.code)
        }
        guard Self.camerasFit(view: view, orbit: orbit, scale: self.preset.scale, clearance: boundingRadius) else {
            throw ExperienceFailure(code: Self.invalidStateCode, message: "camera out of bounds")
        }
        view2D = view
        orbit3D = orbit
    }

    /// Whether `view` and `orbit` are finite and already within their bounds for a preset of `scale` and a composition
    /// of bounding radius `clearance`: the 2D camera equals its clamp by `viewBounds(scale:)`, the field of view lies
    /// in `fovRange` and the orbit camera equals its clamp by `orbitViewBounds(clearance:)` within 1e-9 (the rule of
    /// a restore and of `composition.open`).
    static func camerasFit(view: View2D, orbit: Orbit3D, scale: Double, clearance: Double) -> Bool {
        let finite = ([view.centerX, view.centerY, view.zoom] + orbit.values).allSatisfy(\.isFinite)
        return finite && View2D(viewBounds(scale: scale).clamp(view.camera)) == view
            && fovRange.contains(orbit.fovDegrees)
            && Orbit3D(orbitViewBounds(clearance: clearance).clamp(orbit.camera), fovDegrees: orbit.fovDegrees)
                .isNearlyEqual(to: orbit, tolerance: 1e-9)
    }

    /// Nothing: a composition is static, so a step changes nothing (the digest depends only on the actions).
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action: the candidate preset must differ from the current one, validate and build;
    /// otherwise the action is refused and the state is unchanged.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        if action.control.hasPrefix("camera.") { return applyCamera(action) }
        if action.control == "composition.open" { return applyOpen(action.values) }
        let v = action.values
        var next = preset
        var nextIndex = presetIndex
        switch action.control {
        case "preset.select":
            guard let i = v.first.map({ Int($0.rounded()) }), GeometryPreset.curated.indices.contains(i) else {
                return .rejected(.outOfRange(index: 0))
            }
            next = GeometryPreset.curated[i]
            next.seed = preset.seed          // the motif seed carries over; only `reseed` moves it
            nextIndex = i
        case "symmetry.order":
            guard preset.usesOrder else { return .rejected(.rule(code: Self.orderFixedCode)) }
            guard let n = v.first else { return .rejected(.wrongValueCount(expected: 1, found: 0)) }
            next.order = Int(n.rounded())
        case "repeats.set":
            guard let n = v.first else { return .rejected(.wrongValueCount(expected: 1, found: 0)) }
            next.repeats = Int(n.rounded())
        case "scale.set":
            guard let x = v.first else { return .rejected(.wrongValueCount(expected: 1, found: 0)) }
            next.scale = x
        case "palette.set":
            guard let n = v.first else { return .rejected(.wrongValueCount(expected: 1, found: 0)) }
            next.palette = Int(n.rounded())
        case "reseed":
            next.seed = preset.seed &+ Self.seedStep
        default:
            return .rejected(.unknownControl(action.control))
        }
        guard next != preset || nextIndex != presetIndex else { return .rejected(.rule(code: Self.unchangedCode)) }
        switch Self.build(next) {
        case .success(let built):
            if action.control == "preset.select" {
                view2D = .default            // a new preset starts from its default cameras (FR-A05-211)
                orbit3D = .default
            } else {
                view2D = View2D(Self.viewBounds(scale: built.preset.scale).clamp(view2D.camera))
                // A new solid may be larger: the distance rule of its bounding radius applies at once.
                let bounds = Self.orbitViewBounds(clearance: built.boundingRadius)
                orbit3D = Orbit3D(bounds.clamp(orbit3D.camera), fovDegrees: orbit3D.fovDegrees)
            }
            preset = built.preset
            presetIndex = nextIndex
            compositionDigest = built.composition.digest
            elementCount = built.composition.elementCount
            boundingRadius = built.boundingRadius
            return .accepted
        case .failure(let rejection):
            return .rejected(rejection)
        }
    }

    /// Carries out a camera action (FR-A05-210, FR-A05-211, FR-A05-310–313): pan moves the 2D centre or the orbit
    /// target, orbit and field of view need the 3D composition, zoom acts on the 2D zoom or on the orbit distance,
    /// reset restores both default cameras (target and field of view included). Every result is clamped by the
    /// framework bounds (`ViewBounds2D`, `OrbitViewBounds` with the composition's bounding radius); an action that
    /// would change nothing (a camera at its bound, a reset at the default) is refused as unchanged, so a refusal
    /// never changes the digest.
    private mutating func applyCamera(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        if let index = v.firstIndex(where: { !$0.isFinite }) { return .rejected(.nonFinite(index: index)) }
        let solid = preset.kind == .solid
        let bounds = Self.viewBounds(scale: preset.scale)
        let orbitBounds = orbitViewBounds
        var view = view2D, orbit = orbit3D
        let fov = orbit.fovDegrees
        switch action.control {
        case "camera.pan":
            guard v.count == 2 else { return .rejected(.wrongValueCount(expected: 2, found: v.count)) }
            if solid {
                // The target moves by dx along the camera's right vector and dy along its up vector (world units),
                // clamped to |target| ≤ 1 and the distance rule.
                orbit = Orbit3D(orbit.camera.panned(by: Vec2(v[0], v[1]), within: orbitBounds), fovDegrees: fov)
            } else {
                // `panned(by:)` takes a camera-space delta and moves the centre by −delta / zoom; the action moves
                // the view centre by (dx, dy) world units.
                let camera = view.camera
                view = View2D(camera.panned(by: Vec2(-v[0] * camera.zoom, -v[1] * camera.zoom), within: bounds))
            }
        case "camera.zoom":
            guard v.count == 1 else { return .rejected(.wrongValueCount(expected: 1, found: v.count)) }
            guard v[0] > 0 else { return .rejected(.outOfRange(index: 0)) }
            if solid {
                orbit = Orbit3D(orbit.camera.zoomed(by: v[0], within: orbitBounds), fovDegrees: fov)
            } else {
                view = View2D(view.camera.zoomed(by: v[0], within: bounds))
            }
        case "camera.orbit":
            guard solid else { return .rejected(.rule(code: Self.orbitSolidOnlyCode)) }
            guard v.count == 2 else { return .rejected(.wrongValueCount(expected: 2, found: v.count)) }
            orbit = Orbit3D(orbit.camera.orbited(yaw: v[0], pitch: v[1], within: orbitBounds), fovDegrees: fov)
        case "camera.fov":
            guard solid else { return .rejected(.rule(code: Self.fovSolidOnlyCode)) }
            guard v.count == 1 else { return .rejected(.wrongValueCount(expected: 1, found: v.count)) }
            guard Self.fovRange.contains(v[0]) else { return .rejected(.outOfRange(index: 0)) }
            // The degrees are kept exactly as sent; the rest of the camera is re-clamped with the new angle.
            orbit.fovDegrees = v[0]
            orbit = Orbit3D(orbitBounds.clamp(orbit.camera), fovDegrees: v[0])
        case "camera.reset":
            guard v.isEmpty else { return .rejected(.wrongValueCount(expected: 0, found: v.count)) }
            view = .default
            orbit = .default
        default:
            return .rejected(.unknownControl(action.control))
        }
        guard view != view2D || !orbit.isNearlyEqual(to: orbit3D) else {
            return .rejected(.rule(code: Self.unchangedCode))
        }
        view2D = view
        orbit3D = orbit
        return .accepted
    }

    /// Carries out `composition.open` (FR-A05-402): the 18 values of `GeometryDocument.openValues` are checked together
    /// and either replace the preset index, the preset, the composition and both cameras at once or change nothing.
    /// Refusals, in this order: a count other than 18 (`wrongValueCount`), the first non-finite value (`nonFinite`),
    /// the first value outside `GeometryDocument.openRanges` or not whole where it must be (`outOfRange`), a kind that
    /// is not the named curated preset's or a camera outside the bounds of the built composition
    /// (`openOutOfBoundsCode`), a preset that does not build (its rule code), the current state (`unchangedCode`).
    private mutating func applyOpen(_ v: [Double]) -> ActionResult {
        guard v.count == GeometryDocument.openValueCount else {
            return .rejected(.wrongValueCount(expected: GeometryDocument.openValueCount, found: v.count))
        }
        if let index = v.firstIndex(where: { !$0.isFinite }) { return .rejected(.nonFinite(index: index)) }
        if let index = GeometryDocument.firstInvalidIndex(in: v) { return .rejected(.outOfRange(index: index)) }
        guard let document = GeometryDocument(openValues: v, name: "") else { return .rejected(.outOfRange(index: 0)) }
        guard GeometryPreset.curated[document.presetIndex].kind == document.preset.kind else {
            return .rejected(.rule(code: Self.openOutOfBoundsCode))
        }
        let built: Built
        switch Self.build(document.preset) {
        case .success(let value): built = value
        case .failure(let rejection): return .rejected(rejection)
        }
        guard Self.camerasFit(view: document.view2D, orbit: document.orbit3D, scale: built.preset.scale,
                              clearance: built.boundingRadius) else {
            return .rejected(.rule(code: Self.openOutOfBoundsCode))
        }
        guard built.preset != preset || document.presetIndex != presetIndex || document.view2D != view2D
                || document.orbit3D != orbit3D else {
            return .rejected(.rule(code: Self.unchangedCode))
        }
        preset = built.preset
        presetIndex = document.presetIndex
        compositionDigest = built.composition.digest
        elementCount = built.composition.elementCount
        boundingRadius = built.boundingRadius
        view2D = document.view2D
        orbit3D = document.orbit3D
        return .accepted
    }

    /// Back to the preparation: curated preset 0 with the preparation seed (it built when it was prepared).
    public mutating func reset() {
        if let fresh = try? GeometryCore(seed: seed) { self = fresh }
    }

    /// `composition-built`: every state this core holds was built from a validated preset (clarification 5).
    public var outcome: ExperienceOutcome? {
        compositionDigest.isEmpty ? nil : ExperienceOutcome(code: Self.outcomeCode)
    }

    /// The preparation seed, the preset index, every preset field, the composition's digest and element count, then
    /// the 2D camera (centre, zoom) and the orbit camera (yaw, pitch, distance, target x, y, z, field of view).
    public func writeDigest(into builder: inout DigestBuilder) throws(DigestError) {
        builder.add(seed)
        builder.add(presetIndex)
        builder.add(Self.kindName(preset.kind))
        builder.add(preset.order)
        builder.add(preset.repeats)
        try builder.add(preset.scale)
        builder.add(preset.palette)
        builder.add(preset.seed)
        builder.add(preset.schemaVersion)
        builder.add(compositionDigest)
        builder.add(elementCount)
        try builder.add(view2D.centerX)
        try builder.add(view2D.centerY)
        try builder.add(view2D.zoom)
        try builder.add(orbit3D.yaw)
        try builder.add(orbit3D.pitch)
        try builder.add(orbit3D.distance)
        try builder.add(orbit3D.targetX)
        try builder.add(orbit3D.targetY)
        try builder.add(orbit3D.targetZ)
        try builder.add(orbit3D.fovDegrees)
    }

    // MARK: Validation

    /// A validated preset and its composition.
    struct Built {
        /// The preset as `validated()` returned it.
        var preset: GeometryPreset
        /// The composition it builds.
        var composition: Composition
        /// The composition's bounding radius about the origin (`boundingRadius(of:)`).
        var boundingRadius: Double { GeometryCore.boundingRadius(of: composition) }
    }

    /// Validates `preset` and builds its composition; a failure is a rule rejection with the error's code.
    static func build(_ preset: GeometryPreset) -> Result<Built, ActionRejection> {
        let valid: GeometryPreset
        do throws(PresetError) {
            valid = try preset.validated()
        } catch {
            return .failure(.rule(code: error.code))
        }
        do throws(CompositionError) {
            return .success(Built(preset: valid, composition: try Composition.build(valid)))
        } catch {
            return .failure(.rule(code: error.code))
        }
    }

    /// The current composition, rebuilt from the preset (it built when the preset was accepted).
    public func composition() -> Composition? {
        try? Composition.build(preset)
    }

    // MARK: Names

    /// The spoken and displayed name of a preset kind.
    public static func kindName(_ kind: GeometryPreset.Kind) -> String {
        switch kind {
        case .squareTiling: "Square tiling"
        case .hexTiling: "Hexagonal tiling"
        case .kaleidoscope: "Kaleidoscope"
        case .solid: "3D composition"
        }
    }

    /// The symmetry in words: the lattice's fixed symmetry for a tiling, the order otherwise.
    public static func symmetryText(_ preset: GeometryPreset) -> String {
        switch preset.kind {
        case .squareTiling: "square lattice symmetry p4m"
        case .hexTiling: "hexagonal lattice symmetry p6m"
        case .kaleidoscope: "\(preset.order)-fold mirror symmetry"
        case .solid: "\(preset.order)-fold rotational symmetry"
        }
    }

    // MARK: Snapshot

    private enum CodingKeys: String, CodingKey {
        case seed, presetIndex, preset, view2D, orbit3D
    }

    /// Decodes the seed, the preset index, the preset and the two cameras (schema 3; a schema-1 or schema-2 payload
    /// gains the default cameras, target and field of view through `migrations` first), then validates and rebuilds; a payload whose preset does not
    /// build or whose camera lies outside its bounds fails with `ExperienceFailure` (`a05.invalid-state`).
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(seed: try c.decode(UInt64.self, forKey: .seed),
                      presetIndex: try c.decode(Int.self, forKey: .presetIndex),
                      preset: try c.decode(GeometryPreset.self, forKey: .preset),
                      view: try c.decode(View2D.self, forKey: .view2D),
                      orbit: try c.decode(Orbit3D.self, forKey: .orbit3D))
    }

    /// Encodes the seed, the preset index, the preset and the two cameras; the composition is derived and rebuilt
    /// on decoding.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(seed, forKey: .seed)
        try c.encode(presetIndex, forKey: .presetIndex)
        try c.encode(preset, forKey: .preset)
        try c.encode(view2D, forKey: .view2D)
        try c.encode(orbit3D, forKey: .orbit3D)
    }

    // MARK: Migration example

    /// The stored example of schema 1 for `SnapshotMigrationCheck` (the app registry's `examples`): the Phase 01
    /// payload of the state prepared with `seed` (seed, preset index 0 and curated preset 0, no cameras) in a
    /// schema-1 snapshot, with the digest its restore must give — the prepared state with the default cameras. Nil
    /// only if the preparation or the encoding failed.
    public static func schemaOneExample(seed: UInt64 = 7) -> MigrationExample? {
        guard let id = ExperienceID(rawValue: experienceID), let core = try? GeometryCore(seed: seed),
              let preset = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(core.preset)) else { return nil }
        let payload: [String: Any] = [CodingKeys.seed.rawValue: seed, CodingKeys.presetIndex.rawValue: 0,
                                      CodingKeys.preset.rawValue: preset]
        var builder = DigestBuilder(domain: id.rawValue)
        guard (try? core.writeDigest(into: &builder)) != nil,
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let snapshot = try? ExperienceSnapshot(experience: id, schemaVersion: 1, seed: seed, stepIndex: 0,
                                                     digest: builder.finish(), payload: data),
              let encoded = try? snapshot.encoded() else { return nil }
        return MigrationExample(version: 1, snapshot: encoded, expectedDigest: builder.finish().hex)
    }

    /// The stored example of schema 2 for `SnapshotMigrationCheck` (FR-A05-314): the Phase 02 payload of the state
    /// prepared with `seed` with an orbit camera that is not the default (yaw 0.5, pitch 0.25, distance 5; no target,
    /// no field of view) in a schema-2 snapshot, with the digest its restore must give — that camera with the
    /// default target and field of view. Nil only if the preparation or the encoding failed.
    public static func schemaTwoExample(seed: UInt64 = 7) -> MigrationExample? {
        let orbit = Orbit3D(yaw: 0.5, pitch: 0.25, distance: 5)
        guard let id = ExperienceID(rawValue: experienceID), let prepared = try? GeometryCore(seed: seed),
              let core = try? GeometryCore(seed: seed, presetIndex: 0, preset: prepared.preset, orbit: orbit),
              let preset = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(core.preset)),
              let view = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(core.view2D)) else { return nil }
        let payload: [String: Any] = [CodingKeys.seed.rawValue: seed, CodingKeys.presetIndex.rawValue: 0,
                                      CodingKeys.preset.rawValue: preset, CodingKeys.view2D.rawValue: view,
                                      CodingKeys.orbit3D.rawValue: ["yaw": orbit.yaw, "pitch": orbit.pitch,
                                                                    "distance": orbit.distance]]
        var builder = DigestBuilder(domain: id.rawValue)
        guard (try? core.writeDigest(into: &builder)) != nil,
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let snapshot = try? ExperienceSnapshot(experience: id, schemaVersion: 2, seed: seed, stepIndex: 0,
                                                     digest: builder.finish(), payload: data),
              let encoded = try? snapshot.encoded() else { return nil }
        return MigrationExample(version: 2, snapshot: encoded, expectedDigest: builder.finish().hex)
    }
}
