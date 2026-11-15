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
import Foundation
import VisualCoreSimulation

/// Why a saved world state was refused.
public enum WorldStateRefusal: String, CaseIterable, Codable, Error, Sendable {
    /// Not JSON, truncated, or a missing, malformed or out-of-range key.
    case damaged = "damaged"
    /// Written by a newer version (schema above 1).
    case newerVersion = "newer-version"
}

/// The state of a Tiny Worlds session: preset, seed, view and generator.
public struct WorldState: Codable, Equatable, Sendable {
    /// The snapshot schema this code writes and reads.
    public static let schemaVersion = 1
    /// The allowed preset indices.
    public static let presetRange: ClosedRange<Int> = 0...2
    /// The seed of a new session's world.
    public static let defaultSeed: UInt32 = 1
    /// The seed of a new session's generator (ASCII "TINYWRLD").
    public static let generatorSeed: UInt64 = 0x5449_4E59_5752_4C44
    /// The default world: the island, seed 1, the default view and a fresh generator.
    public static let initial = WorldState(presetIndex: 0, seed: defaultSeed, view: .default,
                                           random: SeededRandom(seed: generatorSeed).state)

    /// The snapshot schema (1).
    public private(set) var schema: Int
    /// The preset index, 0…2 (``WorldPresetID``).
    public private(set) var presetIndex: Int
    /// The world's seed.
    public private(set) var seed: UInt32
    /// The view.
    public var view: WorldView
    /// The state of the generator that draws new seeds.
    public private(set) var random: SeededRandom.State

    /// A schema-1 state; a preset index outside 0…2 is clamped into it.
    public init(presetIndex: Int, seed: UInt32, view: WorldView, random: SeededRandom.State) {
        self.schema = Self.schemaVersion
        self.presetIndex = min(max(presetIndex, Self.presetRange.lowerBound), Self.presetRange.upperBound)
        self.seed = seed
        self.view = view
        self.random = random
    }

    /// The current preset.
    public var preset: WorldPreset { WorldPreset.preset(index: presetIndex) ?? .island }

    /// Chooses preset `index` (0…2); false, with nothing changed, for any other index.
    @discardableResult
    public mutating func choosePreset(_ index: Int) -> Bool {
        guard Self.presetRange.contains(index) else { return false }
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
        return next
    }

    private enum CodingKeys: String, CodingKey { case schema, presetIndex, seed, view, random }

    /// Decodes a schema-1 state, throwing for another schema, a preset index outside 0…2, a view outside its limits
    /// or a generator state that does not restore (``decode(_:)`` names the reason).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = try c.decode(Int.self, forKey: .schema)
        presetIndex = try c.decode(Int.self, forKey: .presetIndex)
        seed = try c.decode(UInt32.self, forKey: .seed)
        view = try c.decode(WorldView.self, forKey: .view)
        random = try c.decode(SeededRandom.State.self, forKey: .random)
        guard schema == Self.schemaVersion, Self.presetRange.contains(presetIndex),
              (try? SeededRandom(restoring: random)) != nil else {
            throw DecodingError.dataCorrupted(.init(codingPath: c.codingPath,
                                                    debugDescription: "not a valid schema-1 world state"))
        }
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
        struct Body: Decodable {
            var presetIndex: Int
            var seed: UInt32
            var view: WorldView
            var random: SeededRandom.State
        }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(Header.self, from: data), header.schema >= 1 else {
            return .failure(.damaged)
        }
        guard header.schema <= schemaVersion else { return .failure(.newerVersion) }
        guard let body = try? decoder.decode(Body.self, from: data), presetRange.contains(body.presetIndex),
              (try? SeededRandom(restoring: body.random)) != nil else { return .failure(.damaged) }
        return .success(WorldState(presetIndex: body.presetIndex, seed: body.seed, view: body.view,
                                   random: body.random))
    }
}
