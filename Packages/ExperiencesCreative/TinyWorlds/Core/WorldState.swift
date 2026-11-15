// WorldState — feature 089 (A12-P01) T-A12-103 (FR-A12-111, FR-A12-122; clarification 4; research D4; data-model
// "WorldState"). The saved state of Tiny Worlds at snapshot schema 1: the preset index (0…2), the seed (a 32-bit value,
// easy to read and say), the view and the state of the session's generator that draws new seeds.
//
// Written as JSON with sorted keys: `{"presetIndex", "random", "schema": 1, "seed", "view"}`, the generator as
// `SeededRandom.State` (`{"seed", "version": 1, "words": […]}`). `decode(_:)` reads the schema first and refuses, in this
// order:
// - `damaged`: not JSON, truncated, no integer `schema`, a schema below 1, a missing or malformed key, a preset index
//   outside 0…2, a seed outside the 32-bit range, a view outside its limits, or a generator state that does not
//   restore;
// - `newer-version`: a schema above 1 (whatever else the payload holds).
// A refusal changes nothing; the caller opens the default world (`WorldState.initial`).
//
// `newSeed()` draws the next seed as the top 32 bits of the generator's next 64-bit output, redrawing (at most 8
// times) while it equals the current seed, so a new seed changes the world.
//
// Feature 091 (A12-P03) T-A12-302 (FR-A12-320, FR-A12-323; clarifications Q2 and Q4; research D2 and D4; data-model
// "WorldState") raises the schema to 2: schema 1 plus the placed props (in placement order, at most 24), the selection
// (−1 for none, else a prop index) and the light. The JSON keys, sorted, are `{"light", "presetIndex", "props",
// "random", "schema": 2, "seed", "selection", "view"}`, a prop as `{"kind", "rotation", "scale", "x", "y", "z"}`.
// Doubles are written in Swift's shortest round-trip form, so every transform reads back bit-identical. `decode(_:)`
// now reads schema 1 (no props, selection −1, the default light; any schema-2 keys in it are ignored) and schema 2,
// refuses `newer-version` above 2, and also refuses as `damaged` a schema-2 payload without `props`, `selection` or
// `light`, more than 24 props, a prop of an unknown kind, with a non-finite coordinate, |x| or |z| above 5.5 m, y
// outside the height range, a rotation outside −π…π or a scale other than 1, a selection outside −1…count − 1, or a
// light outside its limits. (Spacing and ground rules are the editor's, `WorldEditing`; a decoded state is not
// re-validated against the terrain.) Choosing another preset or drawing a new seed clears the props and the
// selection, because their places belong to the old terrain.
import Foundation
import VisualCoreSimulation

/// Why a saved world state was refused.
public enum WorldStateRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing, malformed or out-of-range key.
    case damaged = "damaged"
    /// Written by a newer version (schema above ``WorldState/schemaVersion``).
    case newerVersion = "newer-version"
}

/// The state of a Tiny Worlds session: preset, seed, view, generator, props, selection and light.
public struct WorldState: Codable, Equatable, Sendable {
    /// The snapshot schema this code writes (2); it reads 1 and 2.
    public static let schemaVersion = 2
    /// The oldest schema this code reads.
    public static let oldestSchema = 1
    /// The selection value for "no prop selected".
    public static let noSelection = -1
    /// The allowed preset indices.
    public static let presetRange: ClosedRange<Int> = 0...2
    /// The seed of a new session's world.
    public static let defaultSeed: UInt32 = 1
    /// The seed of a new session's generator (ASCII "TINYWRLD").
    public static let generatorSeed: UInt64 = 0x5449_4E59_5752_4C44
    /// The default world: the island, seed 1, the default view and a fresh generator.
    public static let initial = WorldState(presetIndex: 0, seed: defaultSeed, view: .default,
                                           random: SeededRandom(seed: generatorSeed).state)

    /// The snapshot schema (always ``schemaVersion`` in memory; older payloads are migrated on decode).
    public private(set) var schema: Int
    /// The preset index, 0…2 (``WorldPresetID``).
    public private(set) var presetIndex: Int
    /// The world's seed.
    public private(set) var seed: UInt32
    /// The view.
    public var view: WorldView
    /// The state of the generator that draws new seeds.
    public private(set) var random: SeededRandom.State
    /// The placed props in placement order (changed through `WorldEditing`).
    public internal(set) var props: [PlacedProp]
    /// The selected prop's index, or ``noSelection`` (changed through `WorldEditing`).
    public internal(set) var selection: Int
    /// The world light.
    public var light: WorldLight

    /// A state at the current schema; a preset index outside 0…2 is clamped into it, a selection that names no prop
    /// becomes ``noSelection``. Props are taken as given (`WorldEditing` places them by its rules).
    public init(presetIndex: Int, seed: UInt32, view: WorldView, random: SeededRandom.State,
                props: [PlacedProp] = [], selection: Int = WorldState.noSelection, light: WorldLight = .default) {
        self.schema = Self.schemaVersion
        self.presetIndex = min(max(presetIndex, Self.presetRange.lowerBound), Self.presetRange.upperBound)
        self.seed = seed
        self.view = view
        self.random = random
        self.props = props
        self.selection = props.indices.contains(selection) ? selection : Self.noSelection
        self.light = light
    }

    /// The selected prop, if any.
    public var selectedProp: PlacedProp? { props.indices.contains(selection) ? props[selection] : nil }

    /// Removes every prop and the selection.
    mutating func clearProps() {
        props = []
        selection = Self.noSelection
    }

    /// The current preset.
    public var preset: WorldPreset { WorldPreset.preset(index: presetIndex) ?? .island }

    /// Chooses preset `index` (0…2), clearing the props and the selection when the preset changes; false, with
    /// nothing changed, for any other index.
    @discardableResult
    public mutating func choosePreset(_ index: Int) -> Bool {
        guard Self.presetRange.contains(index) else { return false }
        if index != presetIndex { clearProps() }
        presetIndex = index
        return true
    }

    /// Draws a new seed from the generator (see the file header), stores it and the advanced generator state, and
    /// returns it.
    @discardableResult
    public mutating func newSeed() -> UInt32 {
        var generator = (try? SeededRandom(restoring: random)) ?? SeededRandom(seed: Self.generatorSeed)
        var next = UInt32(truncatingIfNeeded: generator.next() >> 32)
        for _ in 0..<8 where next == seed { next = UInt32(truncatingIfNeeded: generator.next() >> 32) }
        seed = next
        random = generator.state
        clearProps()
        return next
    }

    private enum CodingKeys: String, CodingKey { case schema, presetIndex, seed, view, random, props, selection, light }

    /// Decodes a schema-1 or schema-2 state (schema 1 with no props, no selection and the default light), throwing for
    /// another schema or any value ``decode(_:)`` refuses as damaged (see the file header).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try c.decode(Int.self, forKey: .schema)
        presetIndex = try c.decode(Int.self, forKey: .presetIndex)
        seed = try c.decode(UInt32.self, forKey: .seed)
        view = try c.decode(WorldView.self, forKey: .view)
        random = try c.decode(SeededRandom.State.self, forKey: .random)
        if schema == Self.schemaVersion {
            props = try c.decode([PlacedProp].self, forKey: .props)
            selection = try c.decode(Int.self, forKey: .selection)
            light = try c.decode(WorldLight.self, forKey: .light)
        } else {
            props = []
            selection = Self.noSelection
            light = .default
        }
        self.schema = Self.schemaVersion
        guard (Self.oldestSchema...Self.schemaVersion).contains(schema), Self.presetRange.contains(presetIndex),
              (try? SeededRandom(restoring: random)) != nil, props.count <= WorldEditing.maxProps,
              props.allSatisfy(\.isValid), selection == Self.noSelection || props.indices.contains(selection) else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath,
                                                    debugDescription: "not a valid world state"))
        }
    }

    /// Encodes the state at the current schema (the keys of the file header).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(light, forKey: .light)
        try c.encode(presetIndex, forKey: .presetIndex)
        try c.encode(props, forKey: .props)
        try c.encode(random, forKey: .random)
        try c.encode(Self.schemaVersion, forKey: .schema)
        try c.encode(seed, forKey: .seed)
        try c.encode(selection, forKey: .selection)
        try c.encode(view, forKey: .view)
    }

    /// The state as JSON with sorted keys (deterministic bytes for equal states).
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// The state in `data`, or the reason it is refused (see the file header for the order of the checks).
    public static func decode(_ data: Data) -> Result<WorldState, WorldStateRefusal> {
        struct Header: Decodable { var schema: Int }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= oldestSchema else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        guard let state = try? decoder.decode(WorldState.self, from: data) else { return .failure(.damaged) }
        return .success(state)
    }
}
