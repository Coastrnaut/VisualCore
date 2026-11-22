// NocturneGardenWitness — feature 382 (R02-G09-02) T-R02G0902-005 (FR-R02G0902-004; SC-R02G0902-003, 005; clarification
// Q4). The solver witness of one generated level: the manifest number, the level's stored form, the actions (the
// solver's first winning sequence of the smallest length), the 16-hex state digest of the shadow mask after every
// action, the play fingerprints after `begin` (and `dismissTutorial` when the level has a tutorial) and after each
// action, the smallest move count with its lower-bound argument (elevation, needed shared cells, single-plant cover and
// whether a sun move is needed: smallest = [sun move] + ⌈needed / cover⌉), the near miss (the witness without its last
// action: not won, its shared cells short of the need), the difficulty and the candidates skipped. The stored form is
// JSON with sorted keys, pretty-printed, with one trailing newline. Making and decoding both rebuild the witness from its
// level by replaying the actions on a fresh `NocturneGardenPlay` and recomputing the lower bound; decoding refuses any
// stored value the rebuild does not reproduce. The difficulty is recomputed from the level, the actions and the stored
// solver work. Exact integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// The near miss of a witness: its actions without the last one, replayed after `begin` (and `dismissTutorial`), with
/// the target cells they leave dark and the shared cells a win needs.
///
/// A near miss is valid when the replay is accepted, does not win and ``shared`` < ``needed`` (so the match fails).
public struct NocturneGardenCounterexample: Sendable, Equatable, Codable {
    /// The witness's actions without the last one.
    public let actions: [NocturneGardenAction]
    /// The target cells dark after ``actions``: |M ∩ T|.
    public let shared: Int
    /// The least shared cell count a win needs (``NocturneGardenSolver/needed(_:)``).
    public let needed: Int

    /// A near miss of the given values.
    public init(actions: [NocturneGardenAction], shared: Int, needed: Int) {
        self.actions = actions
        self.shared = shared
        self.needed = needed
    }
}

/// The replayable proof that a generated Nocturne Garden level is won by its solver's smallest move sequence, that no
/// shorter sequence can win (the lower bound) and that the witness without its last action does not win (clarification
/// Q4).
public struct NocturneGardenWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: NocturneGardenLevel
    /// The solver's winning actions; the last one wins.
    public let actions: [NocturneGardenAction]
    /// The state digest (``digest(_:)``) of the mask after every action 1 … ``smallest``.
    public let digests: [String]
    /// The play fingerprints after `begin` (and `dismissTutorial` when the level has a tutorial) and after each action.
    public let fingerprints: [String]
    /// The smallest move count, the number of actions.
    public let smallest: Int
    /// The lower-bound argument; its ``NocturneGardenBound/smallest`` equals ``smallest``.
    public let bound: NocturneGardenBound
    /// The witness without its last action: not won, shared cells short of the need.
    public let nearMiss: NocturneGardenCounterexample
    /// The level's difficulty.
    public let difficulty: NocturneGardenDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: NocturneGardenLevel, actions: [NocturneGardenAction], digests: [String],
         fingerprints: [String], smallest: Int, bound: NocturneGardenBound, nearMiss: NocturneGardenCounterexample,
         difficulty: NocturneGardenDifficulty, skipped: Int) {
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

    /// The state digest of `mask`: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8 text
    /// of the mask's cell indices sorted ascending, in decimal, separated by `,` with no spaces (`"3,5,17"`; the empty
    /// mask is the empty text).
    public static func digest(_ mask: NocturneGardenMask) -> String {
        let text: String = mask.cells.sorted().map { String($0) }.joined(separator: ",")
        return String(StableHash.sha256Hex(Array(text.utf8)).prefix(16))
    }

    /// The witness of a generated level, built by replaying its solution on a fresh play.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry or a level id that is
    ///   not `nocturne-garden-NNN`), `"skipped"` (outside 0 … 255), `"candidate"` (the level is not candidate `skipped`
    ///   of its manifest entry), `"actions"` (a refused action, no win, or a win or failure before the last action),
    ///   `"bound"` (no lower bound, or not the generated one), `"smallest"` (the actions are not the solution's
    ///   smallest count or not the bound's), `"near-miss"` (the witness without its last action is refused, wins or is
    ///   not short of the need) or `"difficulty"` (not the difficulty of the level, actions and solver work).
    public static func make(_ generated: NocturneGardenGenerated) throws(NocturneGardenError) -> Self {
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
            preconditionFailure("a Nocturne Garden witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the stored actions are replayed on a fresh play, the lower bound is
    /// recomputed with ``NocturneGardenSolver/lowerBound(_:)``, the difficulty is recomputed with the stored solver
    /// work, every stored value must equal the rebuilt one, and the solver run again must find the stored actions with
    /// the stored work.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed("schema")` for a schema below 1;
    ///   `.malformed("unreadable")` for damaged JSON, missing keys or values of the wrong type; `.witness("level")` for
    ///   a level the level rules refuse (an edited field breaks its fingerprint); any part ``make(_:)`` names; and
    ///   `.witness(part)` with `"digests"`, `"fingerprints"`, `"smallest"`, `"bound"`, `"near-miss"` or `"difficulty"`
    ///   for a stored value the rebuild does not reproduce; `.witness("solution")` when the solver, run again on the
    ///   level, does not find exactly the stored actions with the stored work.
    public static func decode(_ data: Data) throws(NocturneGardenError) -> Self {
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
        // The solver's own result (feature 382 convergence, T-R02G0902-013): the stored actions and work must be what
        // the solver finds on the level, so an edited work count or another winning sequence is refused too.
        guard let solution = NocturneGardenSolver.solve(stored.level), solution.actions == stored.actions,
              solution.work == stored.difficulty.work else { throw .witness("solution") }
        return stored
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the play shows a tutorial, as
    /// ``NocturneGardenSolver/wins(_:actions:)`` does) and `actions`, each applied with the current fingerprint, with
    /// the fingerprint after the start and after each action, the state digest after each action and whether any action
    /// before the last ended the play; nil when a stage event or an action is refused.
    static func replay(_ level: NocturneGardenLevel, actions: [NocturneGardenAction])
        -> (play: NocturneGardenPlay, fingerprints: [String], digests: [String], endedEarly: Bool)? {
        var play = NocturneGardenPlay(level: level)
        var fingerprints: [String] = []
        var digests: [String] = []
        var endedEarly = false
        do {
            try play.handle(.begin)
            if play.stage == .tutorial { try play.handle(.dismissTutorial) }
            fingerprints.append(play.fingerprint)
            for action in actions {
                if play.stage != .playing { endedEarly = true }
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                digests.append(digest(play.mask))
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests, endedEarly)
    }

    /// The near miss of `actions` on `level`: the shared cells after them and the need; nil when an action is refused,
    /// the run wins or the shared cells reach the need.
    static func counterexample(_ level: NocturneGardenLevel,
                               actions: [NocturneGardenAction]) -> NocturneGardenCounterexample? {
        guard let run = replay(level, actions: actions), run.play.stage != .won else { return nil }
        let shared: Int = run.play.match.shared
        let needed: Int = NocturneGardenSolver.needed(level)
        guard shared < needed else { return nil }
        return NocturneGardenCounterexample(actions: actions, shared: shared, needed: needed)
    }

    /// Builds a witness from its level, actions and solver work, checking every part.
    private static func build(number: Int, level: NocturneGardenLevel, actions: [NocturneGardenAction], work: Int,
                              skipped: Int) throws(NocturneGardenError) -> Self {
        // Provenance: the level is candidate `skipped` of manifest entry `number`.
        guard (1...NocturneGardenManifest.entries.count).contains(number),
              level.id == NocturneGardenGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<NocturneGardenGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        let entry: NocturneGardenManifestEntry = NocturneGardenManifest.entries[number - 1]
        guard entry.number == number, NocturneGardenGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        // Replay on a fresh play: the witness must win on its last action and not before.
        guard !actions.isEmpty, let run = replay(level, actions: actions), run.play.stage == .won, !run.endedEarly,
              actions.count <= level.budget else {
            throw .witness("actions")
        }
        // Lower bound: [sun move] + ⌈needed / cover⌉ moves; the witness meets it.
        guard let bound = NocturneGardenSolver.lowerBound(level) else { throw .witness("bound") }
        guard bound.smallest == actions.count else { throw .witness("smallest") }
        // The near miss: the witness without its last action, not won and short of the need.
        guard let nearMiss = counterexample(level, actions: Array(actions.dropLast())) else {
            throw .witness("near-miss")
        }
        let difficulty = NocturneGardenDifficulty(level: level, actions: actions, work: work)
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
        do { level = try c.decode(NocturneGardenLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([NocturneGardenAction].self, forKey: .actions)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        smallest = try c.decode(Int.self, forKey: .smallest)
        bound = try c.decode(NocturneGardenBound.self, forKey: .bound)
        nearMiss = try c.decode(NocturneGardenCounterexample.self, forKey: .nearMiss)
        difficulty = try c.decode(NocturneGardenDifficulty.self, forKey: .difficulty)
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
