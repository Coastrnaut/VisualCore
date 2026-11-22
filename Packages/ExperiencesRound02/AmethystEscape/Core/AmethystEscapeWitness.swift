// AmethystEscapeWitness — feature 362 (R02-G07-02) T-R02G0702-005 (FR-R02G0702-004; SC-R02G0702-003, 005; clarification
// Q4). The solver witness of one generated level: the manifest number, the level's stored form, the actions (the solver's
// shortest sequence, its last action the advance through the exit gap), the 16-hex state digest after every move, the
// play fingerprints after `begin` (and `dismissTutorial` when the level has a tutorial) and after each action, the
// smallest move count with the states first reached at each depth below it, the unedited counterexample (the pearl
// advanced from the opening with no shell turned) and the near miss (the witness without its last action, which has not
// escaped), the difficulty and the candidates skipped. The stored form is JSON with sorted keys, pretty-printed, with one
// trailing newline. Making and decoding both rebuild the witness from its level by replaying the actions on an
// `AmethystEscapePlay`; decoding first replays the stored actions, then re-runs `AmethystEscapeSolver.solve` and refuses
// any stored value the rebuild does not reproduce. Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// A run of a witness that does not escape: the accepted actions replayed after `begin` (and `dismissTutorial`), how
/// the run ends and the moves spent when that is decided.
///
/// The outcome is one of:
/// - `"stuck"`: the actions are accepted and leave the play `playing`; one more advance is refused with `.stuck`.
/// - `"wedge"`: the last action drops the pearl into a blocked wedge; the play is `failed` with a wedge failure.
/// - `"budget"`: the last action spends the budget without a win; the play is `failed` with a budget failure.
/// - `"open"`: the actions leave the play `playing`, not escaped yet (the near miss).
///
/// ``move`` is the moves spent when the outcome is decided, which is the number of actions.
public struct AmethystEscapeCounterexample: Sendable, Equatable, Codable {
    /// The accepted actions.
    public let actions: [AmethystEscapeAction]
    /// How the run ends: `"stuck"`, `"wedge"`, `"budget"` or `"open"`.
    public let outcome: String
    /// The moves spent when the outcome is decided.
    public let move: Int

    /// A counterexample of the given values.
    public init(actions: [AmethystEscapeAction], outcome: String, move: Int) {
        self.actions = actions
        self.outcome = outcome
        self.move = move
    }
}

/// The replayable proof that a generated Amethyst Escape level is escaped by its solver's shortest sequence, is not
/// escaped by advances alone and is not escaped by the witness without its last action (clarification Q4).
public struct AmethystEscapeWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: AmethystEscapeLevel
    /// The solver's shortest action sequence; the last action is the advance through the exit gap.
    public let actions: [AmethystEscapeAction]
    /// The state digest (``digest(_:)``) of the crystal after every move 1 … ``smallest``.
    public let digests: [String]
    /// The play fingerprints after `begin` (and `dismissTutorial` when the level has a tutorial) and after each action.
    public let fingerprints: [String]
    /// The smallest move count, the number of actions.
    public let smallest: Int
    /// The states first reached at each depth 0 … smallest − 1 (the proof that no shorter sequence escapes).
    public let depths: [Int]
    /// The pearl advanced from the opening with no shell turned, which does not escape.
    public let unedited: AmethystEscapeCounterexample
    /// The witness without its last action: outcome `"open"` at move smallest − 1.
    public let nearMiss: AmethystEscapeCounterexample
    /// The level's difficulty.
    public let difficulty: AmethystEscapeDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: AmethystEscapeLevel, actions: [AmethystEscapeAction], digests: [String],
         fingerprints: [String], smallest: Int, depths: [Int], unedited: AmethystEscapeCounterexample,
         nearMiss: AmethystEscapeCounterexample, difficulty: AmethystEscapeDifficulty, skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.digests = digests
        self.fingerprints = fingerprints
        self.smallest = smallest
        self.depths = depths
        self.unedited = unedited
        self.nearMiss = nearMiss
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The state digest of `crystal`: the first 16 lowercase hex characters of `StableHash.sha256Hex` over, in order, the
    /// shell count (one byte), every shell's offset innermost first (one byte each), the pearl's shell (one byte) and the
    /// pearl's absolute sector (one byte). A level has at most 5 shells and 12 sectors, so every value fits one byte.
    public static func digest(_ crystal: AmethystEscapeCrystal) -> String {
        var bytes: [UInt8] = [UInt8(truncatingIfNeeded: crystal.offsets.count)]
        for offset in crystal.offsets { bytes.append(UInt8(truncatingIfNeeded: offset)) }
        bytes.append(UInt8(truncatingIfNeeded: crystal.pearl.shell))
        bytes.append(UInt8(truncatingIfNeeded: crystal.pearl.sector))
        return String(StableHash.sha256Hex(bytes).prefix(16))
    }

    /// The witness of a generated level, built by replaying its solution.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry or a level id that is
    ///   not `amethyst-escape-NNN`), `"skipped"` (outside 0 … 511), `"candidate"` (the level is not candidate `skipped`
    ///   of its manifest entry), `"replay"` (a refused action, no win, or a win after other than the last action),
    ///   `"smallest"` (the actions are not the smallest move count or exceed the budget), `"depths"` (not one count per
    ///   depth below the smallest), `"unedited"` or `"near-miss"` (a counterexample that escapes or is refused), or
    ///   `"difficulty"` (not the difficulty of the level and solution).
    public static func make(_ generated: AmethystEscapeGenerated) throws(AmethystEscapeError) -> Self {
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
            preconditionFailure("an Amethyst Escape witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the stored actions are replayed on a new play, then the level is
    /// re-solved with ``AmethystEscapeSolver/solve(_:)`` and the witness rebuilt; every stored value must equal the
    /// rebuilt one.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.witness("schema")` for a schema below 1; `.witness("unreadable")`
    ///   for damaged JSON or missing keys; `.witness("level")` for a level the level rules refuse (an edited field breaks
    ///   its fingerprint); `.witness("replay")` when the stored actions are refused or do not win; `.witness("solution")`
    ///   when the solver no longer finds an escape; any part ``make(_:)`` names; `.witness(part)` with `"actions"`,
    ///   `"digests"`, `"fingerprints"`, `"smallest"`, `"depths"`, `"unedited"`, `"near-miss"` or `"difficulty"` for a
    ///   stored value the rebuild does not reproduce.
    public static func decode(_ data: Data) throws(AmethystEscapeError) -> Self {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .witness("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .witness("schema") }
        let stored: Self
        do {
            stored = try JSONDecoder().decode(Self.self, from: data)
        } catch is LevelRefusal {
            throw .witness("level")
        } catch {
            throw .witness("unreadable")
        }
        // The stored actions must still replay to a win.
        guard let replayed = replay(stored.level, actions: stored.actions), replayed.play.stage == .won else {
            throw .witness("replay")
        }
        guard let solution = AmethystEscapeSolver.solve(stored.level) else { throw .witness("solution") }
        let rebuilt: Self = try build(number: stored.number, level: stored.level, solution: solution,
                                      skipped: stored.skipped)
        guard rebuilt.actions == stored.actions else { throw .witness("actions") }
        guard rebuilt.digests == stored.digests else { throw .witness("digests") }
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.smallest == stored.smallest else { throw .witness("smallest") }
        guard rebuilt.depths == stored.depths else { throw .witness("depths") }
        guard rebuilt.unedited == stored.unedited else { throw .witness("unedited") }
        guard rebuilt.nearMiss == stored.nearMiss else { throw .witness("near-miss") }
        guard rebuilt.difficulty == stored.difficulty else { throw .witness("difficulty") }
        return stored
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the level has a tutorial) and `actions`, each applied
    /// with the current fingerprint, with the fingerprint after the start and after each action, the state digest after
    /// each action and whether any action before the last ended the play; nil when a stage event or an action is refused.
    static func replay(_ level: AmethystEscapeLevel, actions: [AmethystEscapeAction])
        -> (play: AmethystEscapePlay, fingerprints: [String], digests: [String], endedEarly: Bool)? {
        var play = AmethystEscapePlay(level: level)
        var fingerprints: [String] = []
        var digests: [String] = []
        var endedEarly = false
        do {
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            fingerprints.append(play.fingerprint)
            for action in actions {
                if play.stage != .playing { endedEarly = true }
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                digests.append(digest(play.crystal))
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests, endedEarly)
    }

    /// The near-miss run of `actions` on `level`: the outcome the play is in after them (`"open"` while playing,
    /// `"wedge"` or `"budget"` when failed); nil when an action is refused or the run escapes.
    static func counterexample(_ level: AmethystEscapeLevel,
                               actions: [AmethystEscapeAction]) -> AmethystEscapeCounterexample? {
        guard let run = replay(level, actions: actions) else { return nil }
        switch run.play.stage {
        case .playing:
            return AmethystEscapeCounterexample(actions: actions, outcome: "open", move: run.play.moves)
        case .failed:
            guard let failure = run.play.failure else { return nil }
            return AmethystEscapeCounterexample(actions: actions, outcome: failure.code, move: run.play.moves)
        default:
            return nil
        }
    }

    /// The unedited run of `level`: the pearl advanced from the opening with no shell turned until an advance is refused
    /// as stuck (`"stuck"`), the pearl falls into a blocked wedge (`"wedge"`) or the budget is spent (`"budget"`); nil
    /// when it escapes or a stage event is refused. The run is bounded by the budget.
    static func uneditedRun(_ level: AmethystEscapeLevel) -> AmethystEscapeCounterexample? {
        var play = AmethystEscapePlay(level: level)
        var actions: [AmethystEscapeAction] = []
        do {
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
        } catch {
            return nil
        }
        while play.stage == .playing {
            do {
                try play.apply(.advance, expecting: play.fingerprint)
            } catch {
                guard error == .stuck else { return nil }
                return AmethystEscapeCounterexample(actions: actions, outcome: "stuck", move: play.moves)
            }
            actions.append(.advance)
        }
        guard play.stage == .failed, let failure = play.failure else { return nil }
        return AmethystEscapeCounterexample(actions: actions, outcome: failure.code, move: play.moves)
    }

    /// Builds a witness from its level and the solver's solution, checking every part.
    private static func build(number: Int, level: AmethystEscapeLevel, solution: AmethystEscapeSolution,
                              skipped: Int) throws(AmethystEscapeError) -> Self {
        // Provenance: the level is candidate `skipped` of manifest entry `number`.
        guard (1...AmethystEscapeManifest.entries.count).contains(number),
              level.id == AmethystEscapeGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<AmethystEscapeGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        let entry: AmethystEscapeManifestEntry = AmethystEscapeManifest.entries[number - 1]
        guard entry.number == number, AmethystEscapeGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        let actions: [AmethystEscapeAction] = solution.actions
        // Replay on a new play: the witness must win on its last action and not before.
        guard let run = replay(level, actions: actions), run.play.stage == .won, !run.endedEarly else {
            throw .witness("replay")
        }
        guard solution.smallest == actions.count, run.play.moves == actions.count,
              actions.count <= level.budget else { throw .witness("smallest") }
        guard solution.depths.count == solution.smallest, solution.depths.first == 1 else { throw .witness("depths") }
        // Counterexamples: advances alone, and the witness without its last action.
        guard let unedited = uneditedRun(level) else { throw .witness("unedited") }
        guard let nearMiss = counterexample(level, actions: Array(actions.dropLast())), nearMiss.outcome == "open",
              nearMiss.move == solution.smallest - 1 else { throw .witness("near-miss") }
        let difficulty = AmethystEscapeDifficulty(level: level, solution: solution)
        return Self(number: number, level: level, actions: actions, digests: run.digests,
                    fingerprints: run.fingerprints, smallest: solution.smallest, depths: solution.depths,
                    unedited: unedited, nearMiss: nearMiss, difficulty: difficulty, skipped: skipped)
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, digests, fingerprints, smallest, depths, unedited, nearMiss, difficulty
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
            throw DecodingError.keyNotFound(CodingKeys.level, .init(codingPath: c.codingPath, debugDescription: "level"))
        }
        do { level = try c.decode(AmethystEscapeLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([AmethystEscapeAction].self, forKey: .actions)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        smallest = try c.decode(Int.self, forKey: .smallest)
        depths = try c.decode([Int].self, forKey: .depths)
        unedited = try c.decode(AmethystEscapeCounterexample.self, forKey: .unedited)
        nearMiss = try c.decode(AmethystEscapeCounterexample.self, forKey: .nearMiss)
        difficulty = try c.decode(AmethystEscapeDifficulty.self, forKey: .difficulty)
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
        try c.encode(depths, forKey: .depths)
        try c.encode(unedited, forKey: .unedited)
        try c.encode(nearMiss, forKey: .nearMiss)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}
