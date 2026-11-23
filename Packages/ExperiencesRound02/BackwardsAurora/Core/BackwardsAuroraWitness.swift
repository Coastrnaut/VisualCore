// BackwardsAuroraWitness — feature 392 (R02-G10-02) T-R02G1002-005 (FR-R02G1002-004; clarification Q4). The solver
// witness of one generated level: the manifest number, the level's stored form, the reversals (the solver's first
// winning sequence of the smallest length), the 16-hex state digest of the samples after every reversal, the play
// fingerprints after `begin` (and `dismissTutorial` when the level has a tutorial) and after each reversal, the smallest
// reversal count with its lower-bound argument (the opening's bad bends β and ⌈β / 4⌉), the near miss (the witness
// without its last reversal: not won, its bad bends still above 0), the difficulty and the candidates skipped. The
// stored form is JSON with sorted keys, pretty-printed, with one trailing newline. Making and decoding both rebuild the
// witness from its level by replaying the reversals on a fresh `BackwardsAuroraPlay` and recomputing the lower bound;
// decoding refuses any stored value the rebuild does not reproduce and re-runs the solver, refusing a witness whose
// reversals or solver work are not the solver's (feature 382's convergence lesson). Integers only; no clock, no random
// source.
import Foundation
import VisualCoreMath

/// The near miss of a witness: its reversals without the last one, replayed after `begin` (and `dismissTutorial`),
/// with the bad bends they leave.
///
/// A near miss is valid when the replay is accepted, does not win and ``badBends`` > 0 (so the wave is not smooth).
public struct BackwardsAuroraCounterexample: Sendable, Equatable, Codable {
    /// The witness's reversals without the last one.
    public let actions: [BackwardsAuroraAction]
    /// The interior bends above the bend limit after ``actions``.
    public let badBends: Int

    /// A near miss of the given values.
    public init(actions: [BackwardsAuroraAction], badBends: Int) {
        self.actions = actions
        self.badBends = badBends
    }
}

/// The replayable proof that a generated Backwards Aurora level is won by its solver's smallest reversal sequence, that
/// no shorter sequence can win (the seam-count bound) and that the witness without its last reversal does not win
/// (clarification Q4).
public struct BackwardsAuroraWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: BackwardsAuroraLevel
    /// The solver's winning reversals; the last one wins.
    public let actions: [BackwardsAuroraAction]
    /// The state digest (``digest(_:)``) of the wave after every reversal 1 … ``smallest``.
    public let digests: [String]
    /// The play fingerprints after `begin` (and `dismissTutorial` when the level has a tutorial) and after each
    /// reversal.
    public let fingerprints: [String]
    /// The smallest reversal count, the number of reversals.
    public let smallest: Int
    /// The seam-count lower bound; its ``BackwardsAuroraBound/smallest`` equals ``smallest``.
    public let bound: BackwardsAuroraBound
    /// The witness without its last reversal: not won, bad bends above 0.
    public let nearMiss: BackwardsAuroraCounterexample
    /// The level's difficulty, with the solver's work.
    public let difficulty: BackwardsAuroraDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: BackwardsAuroraLevel, actions: [BackwardsAuroraAction], digests: [String],
         fingerprints: [String], smallest: Int, bound: BackwardsAuroraBound, nearMiss: BackwardsAuroraCounterexample,
         difficulty: BackwardsAuroraDifficulty, skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.digests = digests
        self.fingerprints = fingerprints
        self.smallest = smallest
        self.bound = bound
        self.nearMiss = nearMiss
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The state digest of `wave`: the first 16 lowercase hex characters of `StableHash.sha256Hex` over one byte per
    /// sample, in order, each the sample (−64 … 64) as a two's-complement signed 8-bit integer (`Int8` bit pattern;
    /// 1 → 0x01, −1 → 0xFF).
    public static func digest(_ wave: BackwardsAuroraWave) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(wave.count)
        for sample in wave.samples { bytes.append(UInt8(bitPattern: Int8(sample))) }
        return String(StableHash.sha256Hex(bytes).prefix(16))
    }

    /// The witness of a generated level, built by replaying its solution on a fresh play.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry or a level id that is
    ///   not `backwards-aurora-NNN`), `"skipped"` (outside 0 … 255), `"candidate"` (the level is not candidate
    ///   `skipped` of its manifest entry), `"actions"` (a refused reversal, no win, a win or failure before the last
    ///   reversal, or more reversals than the budget), `"smallest"` (the reversals are not the bound's count or not the
    ///   solution's smallest), `"near-miss"` (the witness without its last reversal is refused, wins or is smooth),
    ///   `"bound"` (not the generated bound) or `"difficulty"` (not the difficulty of the level, reversals and solver
    ///   work).
    public static func make(_ generated: BackwardsAuroraGenerated) throws(BackwardsAuroraError) -> Self {
        let witness: Self = try build(number: generated.entry.number, level: generated.level,
                                      actions: generated.solution.actions, work: generated.solution.work,
                                      skipped: generated.skipped)
        guard witness.bound == generated.bound else { throw .witness("bound") }
        guard generated.solution.smallest == witness.smallest else { throw .witness("smallest") }
        guard witness.difficulty == generated.difficulty else { throw .witness("difficulty") }
        return witness
    }

    /// The stored form: JSON with sorted keys, pretty-printed, without escaped slashes, followed by one newline.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        do {
            var data: Data = try encoder.encode(self)
            data.append(0x0A)
            return data
        } catch {
            preconditionFailure("a Backwards Aurora witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the stored reversals are replayed on a fresh play, the lower bound
    /// is recomputed with ``BackwardsAuroraSolver/lowerBound(_:)``, the difficulty is recomputed with the stored solver
    /// work, every stored value must equal the rebuilt one, and the solver run again must find the stored reversals
    /// with the stored work.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed("schema")` for a schema below 1;
    ///   `.malformed("unreadable")` for damaged JSON, missing keys or values of the wrong type; `.witness("level")` for
    ///   a level the level rules refuse (an edited field breaks its fingerprint); any part ``make(_:)`` names;
    ///   `.witness(part)` with `"digests"`, `"fingerprints"`, `"smallest"`, `"bound"`, `"near-miss"` or `"difficulty"`
    ///   for a stored value the rebuild does not reproduce; `.witness("solution")` when the solver, run again on the
    ///   level, does not find exactly the stored reversals with the stored work.
    public static func decode(_ data: Data) throws(BackwardsAuroraError) -> Self {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema") }
        let stored: Self
        do {
            stored = try JSONDecoder().decode(Self.self, from: data)
        } catch is LevelRefusal {
            throw .witness("level")
        } catch {
            throw .malformed("unreadable")
        }
        let rebuilt: Self = try build(number: stored.number, level: stored.level, actions: stored.actions,
                                      work: stored.difficulty.work, skipped: stored.skipped)
        guard rebuilt.digests == stored.digests else { throw .witness("digests") }
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.smallest == stored.smallest else { throw .witness("smallest") }
        guard rebuilt.bound == stored.bound else { throw .witness("bound") }
        guard rebuilt.nearMiss == stored.nearMiss else { throw .witness("near-miss") }
        guard rebuilt.difficulty == stored.difficulty else { throw .witness("difficulty") }
        // The solver's own result (feature 382's convergence lesson): the stored reversals and work must be what the
        // solver finds on the level, so an edited work count or another winning sequence is refused too.
        guard let solution = BackwardsAuroraSolver.solve(stored.level), solution.actions == stored.actions,
              solution.work == stored.difficulty.work else { throw .witness("solution") }
        return stored
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the play shows a tutorial) and `actions`, each
    /// applied with the current fingerprint, with the fingerprint after the start and after each reversal, the state
    /// digest after each reversal and whether any reversal before the last ended the play; nil when a stage event or a
    /// reversal is refused.
    static func replay(_ level: BackwardsAuroraLevel, actions: [BackwardsAuroraAction])
        -> (play: BackwardsAuroraPlay, fingerprints: [String], digests: [String], endedEarly: Bool)? {
        var play = BackwardsAuroraPlay(level: level)
        var fingerprints: [String] = []
        var digests: [String] = []
        var endedEarly: Bool = false
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            fingerprints.append(play.fingerprint)
            for action in actions {
                if play.stage != .playing { endedEarly = true }
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                digests.append(digest(play.wave))
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests, endedEarly)
    }

    /// The near miss of `actions` on `level`: the bad bends after them; nil when a reversal is refused, the run wins
    /// or fails, or the wave is smooth.
    static func counterexample(_ level: BackwardsAuroraLevel,
                               actions: [BackwardsAuroraAction]) -> BackwardsAuroraCounterexample? {
        guard let run = replay(level, actions: actions), run.play.stage == .playing, !run.endedEarly else {
            return nil
        }
        let bad: Int = BackwardsAuroraSolver.badBends(run.play.wave, limit: level.bendLimit)
        guard bad > 0 else { return nil }
        return BackwardsAuroraCounterexample(actions: actions, badBends: bad)
    }

    /// Builds a witness from its level, reversals and solver work, checking every part.
    private static func build(number: Int, level: BackwardsAuroraLevel, actions: [BackwardsAuroraAction], work: Int,
                              skipped: Int) throws(BackwardsAuroraError) -> Self {
        // Provenance: the level is candidate `skipped` of manifest entry `number`.
        guard (1...BackwardsAuroraManifest.entries.count).contains(number),
              level.id == BackwardsAuroraGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<BackwardsAuroraGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        let entry: BackwardsAuroraManifestEntry = BackwardsAuroraManifest.entries[number - 1]
        guard entry.number == number, BackwardsAuroraGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        // Replay on a fresh play: the witness must win on its last reversal and not before, within the budget.
        guard !actions.isEmpty, actions.count <= level.budget, let run = replay(level, actions: actions),
              run.play.stage == .won, !run.endedEarly else {
            throw .witness("actions")
        }
        // The seam-count bound: ⌈β / 4⌉ reversals; the witness meets it.
        let bound: BackwardsAuroraBound = BackwardsAuroraSolver.lowerBound(level)
        guard bound.smallest == actions.count else { throw .witness("smallest") }
        // The near miss: the witness without its last reversal, not won and not smooth.
        guard let nearMiss = counterexample(level, actions: Array(actions.dropLast())) else {
            throw .witness("near-miss")
        }
        let difficulty = BackwardsAuroraDifficulty(level: level, actions: actions, work: work)
        return Self(number: number, level: level, actions: actions, digests: run.digests,
                    fingerprints: run.fingerprints, smallest: actions.count, bound: bound, nearMiss: nearMiss,
                    difficulty: difficulty, skipped: skipped)
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, digests, fingerprints, smallest, bound, nearMiss, difficulty, skipped
    }

    /// Decodes the stored fields without re-verifying them; ``decode(_:)`` decodes and re-verifies.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema: Int = try c.decode(Int.self, forKey: .schema)
        guard (1...Self.schema).contains(schema) else {
            throw DecodingError.dataCorruptedError(forKey: .schema, in: c, debugDescription: "schema \(schema)")
        }
        number = try c.decode(Int.self, forKey: .number)
        guard c.contains(.level) else {
            let context = DecodingError.Context(codingPath: c.codingPath, debugDescription: "level")
            throw DecodingError.keyNotFound(CodingKeys.level, context)
        }
        do { level = try c.decode(BackwardsAuroraLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([BackwardsAuroraAction].self, forKey: .actions)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        smallest = try c.decode(Int.self, forKey: .smallest)
        bound = try c.decode(BackwardsAuroraBound.self, forKey: .bound)
        nearMiss = try c.decode(BackwardsAuroraCounterexample.self, forKey: .nearMiss)
        difficulty = try c.decode(BackwardsAuroraDifficulty.self, forKey: .difficulty)
        skipped = try c.decode(Int.self, forKey: .skipped)
    }

    /// Encodes the stored form with ``schema``.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(number, forKey: .number)
        try c.encode(level, forKey: .level)
        try c.encode(actions, forKey: .actions)
        try c.encode(digests, forKey: .digests)
        try c.encode(fingerprints, forKey: .fingerprints)
        try c.encode(smallest, forKey: .smallest)
        try c.encode(bound, forKey: .bound)
        try c.encode(nearMiss, forKey: .nearMiss)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}
