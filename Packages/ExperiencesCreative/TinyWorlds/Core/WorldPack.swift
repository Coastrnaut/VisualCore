// WorldPack — feature 092 (A12-P04) T-A12-402 (FR-A12-401, FR-A12-403–406; clarifications Q1–Q5; research
// D1–D3; data-model "WorldPack"; SC-A12-402–404). The three environment packs of Tiny Worlds, one per preset
// (pack i uses preset i), as Swift data: a finished composition of the preset's terrain at a fixed seed, its props in
// placement order (kind, x, z and turn), its light, its camera limits and its default view, by "VisualCore project"
// under "MIT".
//
// - island (preset 0): seed 11; 3 trees, 2 rocks, 1 house, 1 lantern; light 120°/45°/0.35 (azimuth, elevation,
//   ambient); pitch 15°…70°, distance 12…28 m; default view yaw 45°, pitch 35°, 18 m;
// - asteroid-garden (preset 1): seed 7; 5 rocks, 3 lanterns; light 300°/30°/0.25; pitch 20°…75°, distance 12…30 m;
//   default view 135°, 40°, 20 m;
// - miniature-city (preset 2): seed 5; 6 houses, 4 lanterns, 2 trees; light 210°/60°/0.40; pitch 25°…75°, distance
//   10…24 m; default view 315°, 45°, 16 m.
//
// The prop positions were found at authoring time by placing each prop through `WorldEditing.place` on that seed's
// terrain and are fixed numbers here: the island's trees stand near the shore above sea level, its house and lantern
// on the high ground; the asteroid garden's rocks ring the disc around three lanterns near its centre; the miniature
// city's six houses face each other across a street along x (doors towards it), lit by four lanterns, with a tree at
// two corners of the plateau.
//
// `apply(to:)` replaces a state with the pack's composition: the preset, the seed, a fresh seed generator
// (`WorldState.generatorSeed`), no props, the light and the default view (passed through the camera policy with the
// preset's limits and the pack's props; it already keeps them); then each prop is placed in order through
// `WorldEditing.place` (so the placement rules and the drawn-surface height apply, and the new prop is selected) and
// turned through `WorldEditing.rotate`; finally the selection is cleared, so a pack opens with none. The first refusal
// refuses the whole pack: it is returned and the state is left unchanged. The result depends only on the pack, so
// opening a pack after any edits ("reset to pack") gives the same state, bytes and digest.
//
// Budgets per pack (clarification Q4): at most 16 props, at most 30,000 vertices in all (the world's parts — terrain
// and sea — and every placed prop's model counted per placement) and at most 18 draws (one per part and one per prop,
// 2 + props at most).
import Foundation
import VisualCoreScenes
import VisualCoreSimulation

/// One prop of a pack: its kind, the centre of its base in x–z and its turn about +y.
public struct PackProp: Equatable, Sendable {
    /// The kind.
    public var kind: PropKind
    /// Base centre x in metres.
    public var x: Double
    /// Base centre z in metres.
    public var z: Double
    /// The turn about +y in degrees, −180…180 (as `WorldEditing.rotate(degrees:in:)` takes it).
    public var turn: Double

    /// Creates a pack prop (no validation; ``WorldPack/apply(to:field:)`` places it by the editor's rules).
    public init(_ kind: PropKind, x: Double, z: Double, turn: Double = 0) {
        self.kind = kind; self.x = x; self.z = z; self.turn = turn
    }
}

/// An environment pack: a finished composition of one preset (see the file header).
public struct WorldPack: Equatable, Sendable, Identifiable {
    /// The most props a pack holds.
    public static let maxProps = 16
    /// The most vertices a pack draws (terrain, sea and every placed prop's model).
    public static let maxVertices = 30_000
    /// The most draws a pack makes (terrain, sea and one per prop).
    public static let maxDraws = 18

    /// The content id (kebab-case), equal to its preset's id.
    public var id: String
    /// The display name ("Island").
    public var name: String
    /// The preset index, 0…2.
    public var presetIndex: Int
    /// The terrain seed.
    public var seed: UInt32
    /// The props in placement order.
    public var props: [PackProp]
    /// The light.
    public var light: WorldLight
    /// The camera limits of the pack's preset (inside the global limits).
    public var limits: CameraLimits
    /// The view a pack opens with.
    public var defaultView: WorldView
    /// The author ("VisualCore project").
    public var author: String
    /// The license, one of `ContentCatalog.allowedLicenses`.
    public var license: String

    /// Creates a pack from all of its fields (no validation; ``apply(to:field:)`` refuses a pack whose props break the
    /// placement rules).
    public init(id: String, name: String, presetIndex: Int, seed: UInt32, props: [PackProp], light: WorldLight,
                limits: CameraLimits, defaultView: WorldView, author: String = ContentCatalog.projectAuthor,
                license: String = "MIT") {
        self.id = id; self.name = name; self.presetIndex = presetIndex; self.seed = seed; self.props = props
        self.light = light; self.limits = limits; self.defaultView = defaultView; self.author = author
        self.license = license
    }

    /// The pack's preset.
    public var preset: WorldPreset { WorldPreset.preset(index: presetIndex) ?? .island }

    /// The number of props of `kind`.
    public func count(_ kind: PropKind) -> Int { props.filter { $0.kind == kind }.count }

    /// The island: seed 11; 3 trees, 2 rocks, 1 house, 1 lantern; light 120°/45°/0.35; pitch 15°…70°, distance
    /// 12…28 m; default view 45°, 35°, 18 m.
    public static let island = WorldPack(
        id: WorldPresetID.island.contentId, name: WorldPresetID.island.name, presetIndex: 0, seed: 11,
        props: [
            PackProp(.tree, x: -3.5, z: -1.0, turn: 0),
            PackProp(.tree, x: -2.5, z: -3.25, turn: 35),
            PackProp(.tree, x: 3.0, z: 2.5, turn: 70),
            PackProp(.rock, x: 2.5, z: -1.75, turn: 20),
            PackProp(.rock, x: -2.25, z: 2.5, turn: -40),
            PackProp(.house, x: -0.5, z: 0.75, turn: 45),
            PackProp(.lantern, x: 0.5, z: 1.5, turn: 0),
        ],
        light: WorldLight(azimuth: 120, elevation: 45, ambient: 0.35),
        limits: CameraLimits(pitchDegrees: 15...70, distance: 12...28),
        defaultView: WorldView(yaw: 45 * WorldView.radiansPerDegree, pitch: 35 * WorldView.radiansPerDegree,
                               distance: 18))

    /// The asteroid garden: seed 7; 5 rocks, 3 lanterns; light 300°/30°/0.25; pitch 20°…75°, distance 12…30 m;
    /// default view 135°, 40°, 20 m.
    public static let asteroidGarden = WorldPack(
        id: WorldPresetID.asteroidGarden.contentId, name: WorldPresetID.asteroidGarden.name, presetIndex: 1, seed: 7,
        props: [
            PackProp(.rock, x: -3.0, z: -1.5, turn: 15),
            PackProp(.rock, x: 2.75, z: -2.75, turn: 60),
            PackProp(.rock, x: 3.25, z: 1.75, turn: -30),
            PackProp(.rock, x: -1.5, z: 3.5, turn: 105),
            PackProp(.rock, x: 0.5, z: -4.0, turn: -75),
            PackProp(.lantern, x: -0.75, z: -0.75, turn: 0),
            PackProp(.lantern, x: 1.0, z: -0.25, turn: 120),
            PackProp(.lantern, x: 0.0, z: 1.0, turn: -120),
        ],
        light: WorldLight(azimuth: 300, elevation: 30, ambient: 0.25),
        limits: CameraLimits(pitchDegrees: 20...75, distance: 12...30),
        defaultView: WorldView(yaw: 135 * WorldView.radiansPerDegree, pitch: 40 * WorldView.radiansPerDegree,
                               distance: 20))

    /// The miniature city: seed 5; 6 houses, 4 lanterns, 2 trees; light 210°/60°/0.40; pitch 25°…75°, distance
    /// 10…24 m; default view 315°, 45°, 16 m.
    public static let miniatureCity = WorldPack(
        id: WorldPresetID.miniatureCity.contentId, name: WorldPresetID.miniatureCity.name, presetIndex: 2, seed: 5,
        props: [
            PackProp(.house, x: -1.4, z: -0.9, turn: 0),
            PackProp(.house, x: 0.0, z: -0.9, turn: 0),
            PackProp(.house, x: 1.4, z: -0.9, turn: 0),
            PackProp(.house, x: -1.4, z: 0.9, turn: 180),
            PackProp(.house, x: 0.0, z: 0.9, turn: 180),
            PackProp(.house, x: 1.4, z: 0.9, turn: 180),
            PackProp(.lantern, x: -2.1, z: 0.0, turn: 0),
            PackProp(.lantern, x: -0.7, z: 0.0, turn: 0),
            PackProp(.lantern, x: 0.7, z: 0.0, turn: 0),
            PackProp(.lantern, x: 2.1, z: 0.0, turn: 0),
            PackProp(.tree, x: -3.0, z: -2.5, turn: 0),
            PackProp(.tree, x: 2.6, z: 2.4, turn: 45),
        ],
        light: WorldLight(azimuth: 210, elevation: 60, ambient: 0.40),
        limits: CameraLimits(pitchDegrees: 25...75, distance: 10...24),
        defaultView: WorldView(yaw: 315 * WorldView.radiansPerDegree, pitch: 45 * WorldView.radiansPerDegree,
                               distance: 16))

    /// The packs in preset order.
    public static let all: [WorldPack] = [island, asteroidGarden, miniatureCity]

    /// The pack with `index` (0…2, its preset index), or nil.
    public static func pack(index: Int) -> WorldPack? { all.indices.contains(index) ? all[index] : nil }

    /// The pack of preset `id`.
    public static func pack(for id: WorldPresetID) -> WorldPack { all[id.rawValue] }

    /// The pack with content id `id`, if any.
    public static func pack(id: String) -> WorldPack? { all.first { $0.id == id } }

    /// Replaces `state` with this pack's composition (see the file header); nil on success, else the first refusal,
    /// with `state` unchanged. `field`, when given, must be the level-0 height field of the pack's preset and seed.
    @discardableResult
    public func apply(to state: inout WorldState, field: HeightField? = nil) -> WorldEditRefusal? {
        guard WorldState.presetRange.contains(presetIndex) else { return .invalidChoice }
        guard props.count <= Self.maxProps else { return .propCap }
        var next = WorldState(presetIndex: presetIndex, seed: seed, view: defaultView,
                              random: SeededRandom(seed: WorldState.generatorSeed).state, light: light)
        guard let field = field ?? WorldEditing.groundField(of: next) else { return .underWater }
        for prop in props {
            if let refusal = WorldEditing.place(kind: prop.kind.rawValue, x: prop.x, z: prop.z, in: &next,
                                                field: field) {
                return refusal
            }
            if prop.turn != 0, let refusal = WorldEditing.rotate(degrees: prop.turn, in: &next) { return refusal }
        }
        WorldEditing.select(WorldState.noSelection, in: &next)
        next.view = CameraPolicy.clamp(defaultView, field: field, limits: limits, props: next.props)
        state = next
        return nil
    }

    /// The state this pack opens as (``apply(to:field:)`` on the default state), or the refusal.
    public func state() -> Result<WorldState, WorldEditRefusal> {
        var state = WorldState.initial
        if let refusal = apply(to: &state) { return .failure(refusal) }
        return .success(state)
    }

    /// The vertices the opened pack draws: its world's parts (terrain and, with a sea, the sea plane) plus every placed
    /// prop's model per placement; nil when the pack is refused or its terrain cannot be built.
    public func vertexCount() -> Int? {
        guard case .success(let state) = state(),
              let parts = try? TerrainGenerator.parts(preset: preset, seed: seed) else { return nil }
        return parts.reduce(0) { $0 + $1.mesh.positions.count }
            + state.props.reduce(0) { $0 + PropCatalog.model($1.kind).mesh.positions.count }
    }

    /// The draws the opened pack makes: one per world part (terrain, sea) and one per prop.
    public var drawCount: Int { (preset.hasSea ? 2 : 1) + props.count }
}
