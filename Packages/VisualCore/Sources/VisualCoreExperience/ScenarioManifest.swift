// ScenarioManifest — feature 195 T-U09-005 (FR-U09-001, FR-U09-002, FR-U09-003, FR-U09-005; data-model section 2;
// contract specs/195-ua-f09-verification-runner/contracts/verification-api.md). The scenario manifest of one
// experience, schema 1: the named scenarios the verification runner plays, each a seed, a script of entries and the
// expectations the observation is compared against. The whole file compiles only under DEBUG or
// VISUALCORE_AUTOMATION, so a shipping release build contains none of it.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation

/// The scenario manifest of one experience (schema 1): which experience, what kind, and its named scenarios.
///
/// In JSON the manifest carries `schema`, `experience`, `kind`, `round` (left out when absent) and `scenarios`; a
/// seed is written as decimal text, as snapshots and diagnostics write it.
public struct ScenarioManifest: Sendable, Equatable, Codable {
    /// The kind of experience a manifest describes.
    public enum Kind: String, Sendable, Equatable, Codable {
        /// A creative experience: an original or a creative round entry.
        case creative
        /// A game of round 2, 3 or 4.
        case game
    }

    /// The schema version this build writes and reads.
    public static let schemaVersion = 1
    /// The largest manifest, in bytes, that `init(data:)` reads: 4 MiB.
    public static let maxBytes = 4 * 1024 * 1024
    /// The nine standard scenarios every experience has, in this order.
    public static let standardNames: [String] = [
        "launch-first-frame", "input-response", "completion", "rejection", "save-restore", "reset",
        "suspend-resume", "teardown-reentry", "cancel-prepare",
    ]

    /// The experience the manifest belongs to.
    public let experience: ExperienceID
    /// Whether the experience is creative or a game.
    public let kind: Kind
    /// The round of a game (2, 3 or 4); nil for a creative experience.
    public let round: Int?
    /// The scenarios, in the order they are listed.
    public let scenarios: [ScenarioSpec]

    /// Creates a manifest.
    public init(experience: ExperienceID, kind: Kind, round: Int? = nil, scenarios: [ScenarioSpec]) {
        self.experience = experience
        self.kind = kind
        self.round = round
        self.scenarios = scenarios
    }

    /// Reads a manifest from JSON. The size is checked before anything is decoded.
    ///
    /// Throws `tooLarge` above `maxBytes`, `unknownSchema` for a schema of 0 or below, `newerSchema` for a schema
    /// above `schemaVersion`, and `unreadable` for anything that is not a well-formed manifest.
    public init(data: Data) throws(ScenarioManifestError) {
        guard data.count <= Self.maxBytes else { throw .tooLarge(data.count) }
        let decoder = JSONDecoder()
        let header: SchemaHeader
        do {
            header = try decoder.decode(SchemaHeader.self, from: data)
        } catch {
            throw .unreadable(Self.reason(error))
        }
        guard header.schema >= 1 else { throw .unknownSchema(header.schema) }
        guard header.schema <= Self.schemaVersion else { throw .newerSchema(header.schema) }
        do {
            self = try decoder.decode(ScenarioManifest.self, from: data)
        } catch {
            throw .unreadable(Self.reason(error))
        }
    }

    /// The manifest as JSON with sorted keys. Returns empty data only when a value cannot be written as JSON (a
    /// value of an action that is not finite).
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    private enum CodingKeys: String, CodingKey { case schema, experience, kind, round, scenarios }

    /// Decodes a manifest; a schema other than `schemaVersion` is a decoding error.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema = try c.decode(Int.self, forKey: .schema)
        guard schema == Self.schemaVersion else {
            throw DecodingError.dataCorruptedError(forKey: .schema, in: c,
                                                   debugDescription: "schema \(schema) is not \(Self.schemaVersion)")
        }
        experience = try c.decode(ExperienceID.self, forKey: .experience)
        kind = try c.decode(Kind.self, forKey: .kind)
        round = try c.decodeIfPresent(Int.self, forKey: .round)
        scenarios = try c.decode([ScenarioSpec].self, forKey: .scenarios)
    }

    /// Encodes the manifest with `schema` 1; an absent round is left out.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schemaVersion, forKey: .schema)
        try c.encode(experience, forKey: .experience)
        try c.encode(kind, forKey: .kind)
        try c.encodeIfPresent(round, forKey: .round)
        try c.encode(scenarios, forKey: .scenarios)
    }

    /// The part of a manifest read first: only its schema.
    private struct SchemaHeader: Decodable {
        let schema: Int
    }

    /// A short text for a decoding error, at most 300 characters.
    private static func reason(_ error: any Error) -> String {
        let text = String(describing: error)
        return text.count > 300 ? String(text.prefix(300)) : text
    }
}

/// Why a scenario manifest was refused.
public enum ScenarioManifestError: Error, Sendable, Equatable {
    /// The data is not a well-formed manifest; the text names what is wrong.
    case unreadable(String)
    /// The manifest was written with a newer schema than this build reads.
    case newerSchema(Int)
    /// The schema is 0 or below, which no build ever wrote.
    case unknownSchema(Int)
    /// The manifest has more bytes than `ScenarioManifest.maxBytes`.
    case tooLarge(Int)

    /// The stable code of the error.
    public var code: String {
        switch self {
        case .unreadable: "manifest.unreadable"
        case .newerSchema: "manifest.newer-schema"
        case .unknownSchema: "manifest.unknown-schema"
        case .tooLarge: "manifest.too-large"
        }
    }
}

/// One named scenario of a manifest: a seed, a script of entries and what is expected of the run.
public struct ScenarioSpec: Sendable, Equatable, Codable {
    /// The name: 1 to 64 characters of `a-z`, `0-9` and `-`, unique in the manifest.
    public let name: String
    /// The seed the experience is prepared with; written as decimal text in JSON.
    public let seed: UInt64
    /// The entries, played in order.
    public let entries: [ScenarioStep]
    /// What the observation of the run is compared against.
    public let expect: ScenarioExpectations
    /// How many teardown and reentry cycles to run (`teardown-reentry`), 1 to 50.
    public let cycles: Int?
    /// How many seconds an endurance scenario runs, 1 to 600.
    public let seconds: Int?

    /// Creates a scenario.
    public init(name: String, seed: UInt64, entries: [ScenarioStep], expect: ScenarioExpectations = ScenarioExpectations(),
                cycles: Int? = nil, seconds: Int? = nil) {
        self.name = name
        self.seed = seed
        self.entries = entries
        self.expect = expect
        self.cycles = cycles
        self.seconds = seconds
    }

    /// The scenario as the script the experience engine runs: the seed and one entry per step of the scenario.
    public var scenario: ExperienceScenario {
        ExperienceScenario(seed: seed, entries: entries.map { ExperienceScenario.Entry(steps: $0.steps, action: $0.action) })
    }

    private enum CodingKeys: String, CodingKey { case name, seed, entries, expect, cycles, seconds }

    /// Decodes a scenario; the seed is read from decimal text.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        let text = try c.decode(String.self, forKey: .seed)
        guard let value = UInt64(text), String(value) == text else {
            throw DecodingError.dataCorruptedError(forKey: .seed, in: c,
                                                   debugDescription: "the seed is not the decimal text of a 64-bit number")
        }
        seed = value
        entries = try c.decode([ScenarioStep].self, forKey: .entries)
        expect = try c.decode(ScenarioExpectations.self, forKey: .expect)
        cycles = try c.decodeIfPresent(Int.self, forKey: .cycles)
        seconds = try c.decodeIfPresent(Int.self, forKey: .seconds)
    }

    /// Encodes the scenario; the seed is written as decimal text and absent items are left out.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(String(seed), forKey: .seed)
        try c.encode(entries, forKey: .entries)
        try c.encode(expect, forKey: .expect)
        try c.encodeIfPresent(cycles, forKey: .cycles)
        try c.encodeIfPresent(seconds, forKey: .seconds)
    }
}

/// One entry of a scenario: a number of fixed steps, then an optional action and what is expected of it.
public struct ScenarioStep: Sendable, Equatable, Codable {
    /// The fixed steps run before the action, 0 to 100,000.
    public let steps: Int
    /// The action carried out after the steps.
    public let action: ScriptedAction?
    /// The expected answer to the action: `accepted` or a rejection code such as `action.out-of-range`.
    public let result: String?
    /// The expected state digest after the entry: 64 lower-case hexadecimal digits.
    public let digest: String?

    /// Creates an entry.
    public init(steps: Int, action: ScriptedAction? = nil, result: String? = nil, digest: String? = nil) {
        self.steps = steps
        self.action = action
        self.result = result
        self.digest = digest
    }
}

/// What a scenario's run is expected to show; every absent item is not checked.
public struct ScenarioExpectations: Sendable, Equatable, Codable {
    /// The state digest right after preparation.
    public let initialDigest: String?
    /// The state digest at the end of the run.
    public let finalDigest: String?
    /// The outcome code the experience reports at the end, such as `target-reached`.
    public let outcome: String?
    /// The class each named frame probe is expected to show (probe name → `dark`, `light`, `red`, …).
    public let probes: [String: String]?
    /// Whether a reset must bring the state back to the initial digest.
    public let resetDigest: Bool?

    /// Creates expectations; nothing is expected by default.
    public init(initialDigest: String? = nil, finalDigest: String? = nil, outcome: String? = nil,
                probes: [String: String]? = nil, resetDigest: Bool? = nil) {
        self.initialDigest = initialDigest
        self.finalDigest = finalDigest
        self.outcome = outcome
        self.probes = probes
        self.resetDigest = resetDigest
    }
}

/// How much content an experience's manifest must cover, as the planning catalog gives it.
public struct ContentRequirement: Sendable, Equatable {
    /// The `fixture-…` scenarios a creative experience needs.
    public let fixtures: Int
    /// The `acceptance-…` scenarios a game needs.
    public let acceptance: Int
    /// The `fault-…` scenarios a game of round 3 or 4 needs.
    public let faults: Int
    /// The levels a game declares; carried for the driver, not checked by the validator.
    public let levels: Int

    /// Creates a requirement; every count is 0 by default.
    public init(fixtures: Int = 0, acceptance: Int = 0, faults: Int = 0, levels: Int = 0) {
        self.fixtures = fixtures
        self.acceptance = acceptance
        self.faults = faults
        self.levels = levels
    }
}
#endif
