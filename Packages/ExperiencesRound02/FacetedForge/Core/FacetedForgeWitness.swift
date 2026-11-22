// FacetedForgeWitness — feature 372 (R02-G08-02) T-R02G0802-005 (FR-R02G0802-004; SC-R02G0802-003, 005; clarification
// Q4). The solver witness of one generated level: the manifest number, the level's stored form, the cuts (the solver's
// first winning sequence of the smallest length), the 16-hex state digest of the pieces after every cut, the play
// fingerprints after `begin` (and `dismissTutorial` when the level has a tutorial) and after each cut, the smallest cut
// count with its lower-bound argument (every accepted cut turns one piece into two, so a target of P pieces needs at
// least P − 1 cuts), the near miss (the witness without its last cut: not won, one piece short), the difficulty and
// the candidates skipped. The stored form is JSON with sorted keys, pretty-printed, with one trailing newline. Making
// and decoding both rebuild the witness from its level by replaying the cuts on a `FacetedForgePlay`; decoding first
// replays the stored cuts, then re-runs `FacetedForgeSolver.solve` and refuses any stored value the rebuild does not
// reproduce. Exact fractions only; no clock, no random source.
import Foundation
import VisualCoreMath

/// A run of a witness that does not win: the accepted cuts replayed after `begin` (and `dismissTutorial`), how the run
/// ends and the cuts spent when that is decided.
///
/// The outcome is one of:
/// - `"open"`: the cuts leave the play `playing`, not won yet (the near miss).
/// - `"sliver"`: the last cut leaves a piece below the sliver limit; the play is `failed` with a sliver failure.
/// - `"budget"`: the last cut spends the budget without a win; the play is `failed` with a budget failure.
///
/// ``cut`` is the cuts spent when the outcome is decided, which is the number of actions.
public struct FacetedForgeCounterexample: Sendable, Equatable, Codable {
    /// The accepted cuts.
    public let actions: [FacetedForgeAction]
    /// How the run ends: `"open"`, `"sliver"` or `"budget"`.
    public let outcome: String
    /// The cuts spent when the outcome is decided.
    public let cut: Int

    /// A counterexample of the given values.
    public init(actions: [FacetedForgeAction], outcome: String, cut: Int) {
        self.actions = actions
        self.outcome = outcome
        self.cut = cut
    }
}

/// The replayable proof that a generated Faceted Forge level is won by its solver's smallest cut sequence, that no
/// shorter sequence can win (the lower bound) and that the witness without its last cut does not win (clarification
/// Q4).
public struct FacetedForgeWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: FacetedForgeLevel
    /// The solver's winning cuts; the last one completes the target.
    public let actions: [FacetedForgeAction]
    /// The state digest (``digest(_:)``) of the pieces after every cut 1 … ``smallest``.
    public let digests: [String]
    /// The play fingerprints after `begin` (and `dismissTutorial` when the level has a tutorial) and after each cut.
    public let fingerprints: [String]
    /// The smallest cut count, the number of actions.
    public let smallest: Int
    /// The lower bound on any winning sequence: the target's piece count minus one (each cut adds one piece).
    public let lowerBound: Int
    /// The witness without its last cut: outcome `"open"` at cut smallest − 1, one piece short of the target.
    public let nearMiss: FacetedForgeCounterexample
    /// The level's difficulty.
    public let difficulty: FacetedForgeDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: FacetedForgeLevel, actions: [FacetedForgeAction], digests: [String],
         fingerprints: [String], smallest: Int, lowerBound: Int, nearMiss: FacetedForgeCounterexample,
         difficulty: FacetedForgeDifficulty, skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.digests = digests
        self.fingerprints = fingerprints
        self.smallest = smallest
        self.lowerBound = lowerBound
        self.nearMiss = nearMiss
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The state digest of `pieces`: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8
    /// text of the pieces in canonical order (``FacetedForgePiece/canonical(_:)``), separated by `|`, each piece its
    /// sorted corners separated by `;`, each corner `x,y,z` with every coordinate as fraction text (`"3/2"`, `"-1"`).
    public static func digest(_ pieces: [FacetedForgePiece]) -> String {
        var text: String = ""
        for (p, piece) in FacetedForgePiece.canonical(pieces).enumerated() {
            if p > 0 { text += "|" }
            for (i, corner) in piece.corners.enumerated() {
                if i > 0 { text += ";" }
                text += corner.x.text + "," + corner.y.text + "," + corner.z.text
            }
        }
        return String(StableHash.sha256Hex(Array(text.utf8)).prefix(16))
    }

    /// The witness of a generated level, built by replaying its solution.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry or a level id that is
    ///   not `faceted-forge-NNN`), `"skipped"` (outside 0 … 255), `"candidate"` (the level is not candidate `skipped`
    ///   of its manifest entry), `"replay"` (a refused cut, no win, or a win or failure before the last cut),
    ///   `"smallest"` (the cuts are not the solution's smallest count, not the lower bound, or exceed the budget),
    ///   `"near-miss"` (the witness without its last cut wins, fails, is refused or is not one piece short) or
    ///   `"difficulty"` (not the difficulty of the level, cuts and solver work).
    public static func make(_ generated: FacetedForgeGenerated) throws(FacetedForgeError) -> Self {
        guard generated.entry.number >= 1 else { throw .witness("number") }
        let witness: Self = try build(number: generated.entry.number, level: generated.level,
                                      solution: generated.solution, skipped: generated.skipped)
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
            preconditionFailure("a Faceted Forge witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the stored cuts are replayed on a new play, then the level is
    /// re-solved with ``FacetedForgeSolver/solve(_:workBound:)`` and the witness rebuilt; every stored value must equal
    /// the rebuilt one.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed("schema")` for a schema below 1;
    ///   `.malformed("unreadable")` for damaged JSON, missing keys or values of the wrong type; `.witness("level")` for
    ///   a level the level rules refuse (an edited field breaks its fingerprint); `.witness("replay")` when the stored
    ///   cuts are refused or do not win; `.witness("solution")` when the solver no longer certifies the level; any part
    ///   ``make(_:)`` names; `.witness(part)` with `"actions"`, `"digests"`, `"fingerprints"`, `"smallest"`,
    ///   `"lower-bound"`, `"near-miss"` or `"difficulty"` for a stored value the rebuild does not reproduce.
    public static func decode(_ data: Data) throws(FacetedForgeError) -> Self {
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
        // The stored cuts must still replay to a win.
        guard let replayed = replay(stored.level, actions: stored.actions), replayed.play.stage == .won else {
            throw .witness("replay")
        }
        guard let solution = FacetedForgeSolver.solve(stored.level) else { throw .witness("solution") }
        let rebuilt: Self = try build(number: stored.number, level: stored.level, solution: solution,
                                      skipped: stored.skipped)
        guard rebuilt.actions == stored.actions else { throw .witness("actions") }
        guard rebuilt.digests == stored.digests else { throw .witness("digests") }
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.smallest == stored.smallest else { throw .witness("smallest") }
        guard rebuilt.lowerBound == stored.lowerBound else { throw .witness("lower-bound") }
        guard rebuilt.nearMiss == stored.nearMiss else { throw .witness("near-miss") }
        guard rebuilt.difficulty == stored.difficulty else { throw .witness("difficulty") }
        return stored
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the play shows a tutorial, as
    /// ``FacetedForgeGenerator/wins(_:actions:)`` does) and `actions`, each applied with the current fingerprint, with
    /// the fingerprint after the start and after each cut, the state digest after each cut and whether any cut before
    /// the last ended the play; nil when a stage event or a cut is refused.
    static func replay(_ level: FacetedForgeLevel, actions: [FacetedForgeAction])
        -> (play: FacetedForgePlay, fingerprints: [String], digests: [String], endedEarly: Bool)? {
        var play = FacetedForgePlay(level: level)
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
                digests.append(digest(play.pieces))
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests, endedEarly)
    }

    /// The run of `actions` on `level` that does not win: the outcome the play is in after them (`"open"` while
    /// playing, `"sliver"` or `"budget"` when failed); nil when a cut is refused or the run wins.
    static func counterexample(_ level: FacetedForgeLevel,
                               actions: [FacetedForgeAction]) -> FacetedForgeCounterexample? {
        guard let run = replay(level, actions: actions) else { return nil }
        switch run.play.stage {
        case .playing:
            return FacetedForgeCounterexample(actions: actions, outcome: "open", cut: run.play.cuts)
        case .failed:
            guard let failure = run.play.failure else { return nil }
            return FacetedForgeCounterexample(actions: actions, outcome: failure.code, cut: run.play.cuts)
        default:
            return nil
        }
    }

    /// Builds a witness from its level and the solver's solution, checking every part.
    private static func build(number: Int, level: FacetedForgeLevel, solution: FacetedForgeSolution,
                              skipped: Int) throws(FacetedForgeError) -> Self {
        // Provenance: the level is candidate `skipped` of manifest entry `number`.
        guard (1...FacetedForgeManifest.entries.count).contains(number),
              level.id == FacetedForgeGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<FacetedForgeGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        let entry: FacetedForgeManifestEntry = FacetedForgeManifest.entries[number - 1]
        guard entry.number == number, FacetedForgeGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        let actions: [FacetedForgeAction] = solution.actions
        // Replay on a new play: the witness must win on its last cut and not before.
        guard let run = replay(level, actions: actions), run.play.stage == .won, !run.endedEarly else {
            throw .witness("replay")
        }
        // Lower bound: each accepted cut adds one piece, so P target pieces need at least P − 1 cuts.
        let lowerBound: Int = FacetedForgeSolver.lowerBound(level)
        guard solution.smallest == actions.count, run.play.cuts == actions.count, actions.count == lowerBound,
              actions.count <= level.budget else { throw .witness("smallest") }
        // The near miss: the witness without its last cut, still playing and one piece short.
        guard let nearMiss = counterexample(level, actions: Array(actions.dropLast())), nearMiss.outcome == "open",
              nearMiss.cut == solution.smallest - 1,
              let nearRun = replay(level, actions: nearMiss.actions),
              nearRun.play.pieces.count == level.target.count - 1 else { throw .witness("near-miss") }
        let difficulty = FacetedForgeDifficulty(level: level, actions: actions, work: solution.work)
        return Self(number: number, level: level, actions: actions, digests: run.digests,
                    fingerprints: run.fingerprints, smallest: solution.smallest, lowerBound: lowerBound,
                    nearMiss: nearMiss, difficulty: difficulty, skipped: skipped)
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, digests, fingerprints, smallest, lowerBound, nearMiss, difficulty
        case skipped
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
        do { level = try c.decode(FacetedForgeLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([FacetedForgeAction].self, forKey: .actions)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        smallest = try c.decode(Int.self, forKey: .smallest)
        lowerBound = try c.decode(Int.self, forKey: .lowerBound)
        nearMiss = try c.decode(FacetedForgeCounterexample.self, forKey: .nearMiss)
        difficulty = try c.decode(FacetedForgeDifficulty.self, forKey: .difficulty)
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
        try c.encode(lowerBound, forKey: .lowerBound)
        try c.encode(nearMiss, forKey: .nearMiss)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}
