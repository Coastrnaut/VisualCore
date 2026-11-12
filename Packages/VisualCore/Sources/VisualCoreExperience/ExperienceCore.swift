// ExperienceCore — feature 188 T-U02-013 (FR-U02-010, FR-U02-020, FR-U02-080; research R1 and R5; contract
// specs/188-ua-f02-experience-sdk/contracts/experience-core-api.md). The pure part of an experience: its domain state
// and the rules that change it. A core is a value that can be handed between threads; it never draws and never
// reads a clock. The engine drives it, the presenter of the experience draws it.
import Foundation
import VisualCoreDiagnostics
import VisualCorePersistence

/// The domain state of an experience and the rules that change it.
///
/// A conforming type is a value type. Everything that decides an outcome lives here; nothing here knows about
/// frames, pixels or wall-clock time. `ExperienceConformance` checks the obligations stated on each member.
public protocol ExperienceCore: Sendable {
    /// The migrations of the snapshot payload. The schema version of the experience is `migrations.currentVersion`.
    static var migrations: MigrationChain { get }
    /// The controls the experience accepts actions for.
    static var controls: [ExperienceControl] { get }
    /// The number of quality tiers (at least 1; tier 0 is the best). Default 1.
    static var qualityTiers: Int { get }
    /// What each quality tier means in numbers: one named level per tier with its budgets (feature 192, UA-F06).
    /// The profile has as many levels as `qualityTiers`; `ExperienceConformance` checks it. Default: levels named
    /// `level-0` … with every budget at its maximum, for an experience whose tiers change nothing measurable.
    static var qualityProfile: QualityProfile { get }
    /// The length of one fixed step in seconds. Default 1/120; used clamped to 1/240…1/30.
    static var stepDuration: Double { get }

    /// Builds the whole state from `seed` and from data shipped with the experience: the same seed gives the same
    /// state. Uses no clock, no other random source, no network and no stored user data. Checks `Task` cancellation
    /// between its units of work. Throws `ExperienceFailure` for its own failures.
    static func prepare(seed: UInt64) async throws -> Self

    /// Advances the state by one fixed step. `step` is the index of the step, starting at 0.
    mutating func update(step: Int)
    /// Carries out a well-formed action or rejects it by the rules of the experience. A rejected action must leave
    /// the state as it was.
    mutating func apply(_ action: ExperienceAction) -> ActionResult
    /// Returns to the state of a fresh preparation with the same seed.
    mutating func reset()
    /// Takes a quality tier (0 ..< `qualityTiers`). Must not change the digest. Default: nothing.
    mutating func setQualityTier(_ tier: Int)
    /// Drops caches that can be rebuilt. Must not change the digest. Default: nothing.
    mutating func shedCaches()

    /// Writes every field of the domain state into `builder`, in a fixed order. Caches, the quality tier and anything
    /// derived from the GPU or a clock stay out.
    func writeDigest(into builder: inout DigestBuilder) throws(DigestError)
    /// The state as the UTF-8 text of one JSON object, encoded deterministically. `Codable` cores get this for free.
    func snapshotPayload() throws -> Data
    /// Rebuilds a core from a payload of the current schema version. `Codable` cores get this for free.
    static func restore(payload: Data, seed: UInt64) throws -> Self
}

extension ExperienceCore {
    /// One quality tier.
    public static var qualityTiers: Int { 1 }
    /// `qualityTiers` uniform levels.
    public static var qualityProfile: QualityProfile { .uniform(levels: qualityTiers) }
    /// 1/120 s.
    public static var stepDuration: Double { 1.0 / 120 }
    /// Nothing depends on the tier.
    public mutating func setQualityTier(_ tier: Int) {}
    /// There are no caches.
    public mutating func shedCaches() {}
}

extension ExperienceCore where Self: Codable {
    /// The core as JSON with keys in sorted order.
    public func snapshotPayload() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// The core decoded from its JSON payload; the seed is part of the payload of such a core.
    public static func restore(payload: Data, seed: UInt64) throws -> Self {
        try JSONDecoder().decode(Self.self, from: payload)
    }
}
