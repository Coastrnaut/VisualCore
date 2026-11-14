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
import Foundation
import InfiniteGeometryCore
import VisualCoreExperience
import VisualCoreMath
import VisualCorePersistence

/// The state of Infinite Geometry: the preparation seed, the selected curated preset, the current preset with the
/// composition it builds and the two cameras. Schema version 2.
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

    /// The orbit camera of the 3D composition: yaw (−π…π), pitch and distance to the origin.
    public struct Orbit3D: Sendable, Equatable, Codable {
        /// The yaw in radians, wrapped into −π…π.
        public var yaw: Double
        /// The pitch in radians.
        public var pitch: Double
        /// The eye's distance to the origin.
        public var distance: Double

        /// The preset's default: yaw 0, pitch 0.5, distance 6 (the Phase 01 camera).
        public static let `default` = Orbit3D(yaw: 0, pitch: 0.5, distance: 6)

        /// Creates the camera from its angles and distance.
        public init(yaw: Double, pitch: Double, distance: Double) {
            self.yaw = yaw
            self.pitch = pitch
            self.distance = distance
        }

        /// The angles and distance of `camera`.
        public init(_ camera: OrbitCamera) {
            self.init(yaw: camera.yaw, pitch: camera.pitch, distance: camera.distance)
        }

        /// The VisualCoreMath orbit camera looking at the origin.
        public var camera: OrbitCamera { OrbitCamera(distance: distance, yaw: yaw, pitch: pitch) }
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
    /// The rule code of `camera.pan` on the 3D composition (it orbits instead).
    public static let panPlaneOnlyCode = "a05.pan-plane-only"
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
    /// The orbit camera, always within `orbitBounds`.
    public private(set) var orbit3D: Orbit3D = .default

    // MARK: Contract

    /// Schema 2 (cameras added); the step from schema 1 fills the preset's default cameras (FR-A05-213).
    public static var migrations: MigrationChain {
        MigrationChain(currentVersion: 2, steps: [1: { payload in
            var upgraded = payload
            let view = View2D.default, orbit = Orbit3D.default
            upgraded[CodingKeys.view2D.rawValue] = ["centerX": view.centerX, "centerY": view.centerY, "zoom": view.zoom]
            upgraded[CodingKeys.orbit3D.rawValue] = ["yaw": orbit.yaw, "pitch": orbit.pitch, "distance": orbit.distance]
            return upgraded
        }])
    }

    /// The six actions of FR-A05-120 with the ranges of `GeometryPreset`, then the four camera actions of
    /// FR-A05-210. Whole-number controls round their value.
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
    /// with the error's code otherwise, or `a05.invalid-state` when a camera lies outside its bounds.
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
        case .failure(let rejection):
            throw ExperienceFailure(code: Self.invalidStateCode, message: rejection.code)
        }
        let finite = [view.centerX, view.centerY, view.zoom, orbit.yaw, orbit.pitch, orbit.distance].allSatisfy(\.isFinite)
        guard finite, View2D(Self.viewBounds(scale: self.preset.scale).clamp(view.camera)) == view,
              Orbit3D(Self.orbitBounds.clamp(orbit.camera)) == orbit else {
            throw ExperienceFailure(code: Self.invalidStateCode, message: "camera out of bounds")
        }
        view2D = view
        orbit3D = orbit
    }

    /// Nothing: a composition is static, so a step changes nothing (the digest depends only on the actions).
    public mutating func update(step: Int) {}

    /// Carries out a well-formed action: the candidate preset must differ from the current one, validate and build;
    /// otherwise the action is refused and the state is unchanged.
    public mutating func apply(_ action: ExperienceAction) -> ActionResult {
        if action.control.hasPrefix("camera.") { return applyCamera(action) }
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
            }
            preset = built.preset
            presetIndex = nextIndex
            compositionDigest = built.composition.digest
            elementCount = built.composition.elementCount
            return .accepted
        case .failure(let rejection):
            return .rejected(rejection)
        }
    }

    /// Carries out a camera action (FR-A05-210, FR-A05-211): pan and orbit need the matching kind, zoom acts on the
    /// 2D zoom or on the orbit distance, reset restores both default cameras. Every result is clamped by the
    /// framework bounds; an action that would change nothing (a camera at its bound, a reset at the default) is
    /// refused as unchanged, so a refusal never changes the digest.
    private mutating func applyCamera(_ action: ExperienceAction) -> ActionResult {
        let v = action.values
        if let index = v.firstIndex(where: { !$0.isFinite }) { return .rejected(.nonFinite(index: index)) }
        let solid = preset.kind == .solid
        let bounds = Self.viewBounds(scale: preset.scale)
        var view = view2D, orbit = orbit3D
        switch action.control {
        case "camera.pan":
            guard !solid else { return .rejected(.rule(code: Self.panPlaneOnlyCode)) }
            guard v.count == 2 else { return .rejected(.wrongValueCount(expected: 2, found: v.count)) }
            // `panned(by:)` takes a camera-space delta and moves the centre by −delta / zoom; the action moves the
            // view centre by (dx, dy) world units.
            let camera = view.camera
            view = View2D(camera.panned(by: Vec2(-v[0] * camera.zoom, -v[1] * camera.zoom), within: bounds))
        case "camera.zoom":
            guard v.count == 1 else { return .rejected(.wrongValueCount(expected: 1, found: v.count)) }
            guard v[0] > 0 else { return .rejected(.outOfRange(index: 0)) }
            if solid {
                orbit = Orbit3D(orbit.camera.zoomed(by: v[0], within: Self.orbitBounds))
            } else {
                view = View2D(view.camera.zoomed(by: v[0], within: bounds))
            }
        case "camera.orbit":
            guard solid else { return .rejected(.rule(code: Self.orbitSolidOnlyCode)) }
            guard v.count == 2 else { return .rejected(.wrongValueCount(expected: 2, found: v.count)) }
            orbit = Orbit3D(orbit.camera.orbited(yaw: v[0], pitch: v[1], within: Self.orbitBounds))
        case "camera.reset":
            guard v.isEmpty else { return .rejected(.wrongValueCount(expected: 0, found: v.count)) }
            view = .default
            orbit = .default
        default:
            return .rejected(.unknownControl(action.control))
        }
        guard view != view2D || orbit != orbit3D else { return .rejected(.rule(code: Self.unchangedCode)) }
        view2D = view
        orbit3D = orbit
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
    /// the 2D camera (centre, zoom) and the orbit camera (yaw, pitch, distance).
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
    }

    // MARK: Validation

    /// A validated preset and its composition.
    struct Built {
        /// The preset as `validated()` returned it.
        var preset: GeometryPreset
        /// The composition it builds.
        var composition: Composition
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

    /// Decodes the seed, the preset index, the preset and the two cameras (schema 2; a schema-1 payload gains the
    /// default cameras through `migrations` first), then validates and rebuilds; a payload whose preset does not
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
}
