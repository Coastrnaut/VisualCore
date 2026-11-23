// HarmonicBridgesWitness — feature 412 (R02-G12-02) T-R02G1202-005 (FR-R02G1202-004; SC-R02G1202-003, 005;
// clarifications Q4, Q5). The solver witness of one generated level: the manifest number, the level's stored form, the
// actions (the plan's tunings in string order, then one test), the 16-hex bridge digest of the play's report after
// every tuning, the play fingerprints after `begin`, after `dismissTutorial` (when the level has a tutorial) and after
// each action, the counterexample (the size one below the plan and the count of every choice of at most that size
// tried, none winning; for a one-tuning plan also the starting pegs' break), the difficulty and the candidates skipped.
// The stored form is JSON with sorted keys, pretty-printed, with one trailing newline. Making and decoding both rebuild
// the witness from its level by replaying the actions on a fresh `HarmonicBridgesPlay` and recounting every smaller
// choice over the solver's options; decoding refuses any stored value the rebuild does not reproduce and re-runs the
// solver, refusing a witness whose actions, smaller choices or solver work are not the solver's (feature 382's
// convergence lesson). Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// The proof that no choice of one tuning fewer than a witness plan wins (clarification Q4).
public struct HarmonicBridgesCounterexample: Sendable, Hashable, Codable {
    /// The size one below the plan: the most tunings of the choices tried.
    public let size: Int
    /// The choices of 1 … ``size`` tunings tried (the solver's `smallerChoices`), none winning.
    public let choices: Int
    /// For a one-tuning plan (``size`` 0), where the crossing at the starting pegs breaks; nil otherwise.
    public let start: HarmonicBridgesBreak?

    /// A counterexample of the given values, unchecked.
    public init(size: Int, choices: Int, start: HarmonicBridgesBreak?) {
        self.size = size
        self.choices = choices
        self.start = start
    }
}

/// The replayable proof that a generated Harmonic Bridges level is won by its solver's plan and that no choice of one
/// tuning fewer wins (clarification Q4).
public struct HarmonicBridgesWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: HarmonicBridgesLevel
    /// The witness actions: the plan's tunings in ascending string order, then one test, which wins.
    public let actions: [HarmonicBridgesAction]
    /// The bridge digest (``digest(_:)``) of the play's report after every tuning, in order.
    public let bridgeDigests: [String]
    /// The play fingerprints after `begin`, after `dismissTutorial` when the level has a tutorial, and after each
    /// action.
    public let fingerprints: [String]
    /// The proof that one tuning fewer cannot win.
    public let counterexample: HarmonicBridgesCounterexample
    /// The level's difficulty, with the solver's work.
    public let difficulty: HarmonicBridgesDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: HarmonicBridgesLevel, actions: [HarmonicBridgesAction], bridgeDigests: [String],
         fingerprints: [String], counterexample: HarmonicBridgesCounterexample, difficulty: HarmonicBridgesDifficulty,
         skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.bridgeDigests = bridgeDigests
        self.fingerprints = fingerprints
        self.counterexample = counterexample
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The canonical text of the bridges of `report`: for each step in order, `<step>=` followed by one character per
    /// string in string order (`1` a bridge, `0` not), steps separated by `;`. Example: `0=101;1=011`.
    public static func canonicalText(_ report: HarmonicBridgesReport) -> String {
        var parts: [String] = []
        for (step, bridges) in report.bridges.enumerated() {
            var text: String = String(step) + "="
            for bridge in bridges { text += bridge ? "1" : "0" }
            parts.append(text)
        }
        return parts.joined(separator: ";")
    }

    /// The bridge digest of `report`: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8
    /// bytes of ``canonicalText(_:)`` (the bridges per step).
    public static func digest(_ report: HarmonicBridgesReport) -> String {
        String(StableHash.sha256Hex(Array(canonicalText(report).utf8)).prefix(16))
    }

    /// The witness of a generated level, built by replaying its actions on a fresh play.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry or a level id that is
    ///   not `harmonic-bridges-NNN`), `"skipped"` (outside 0 … 255), `"candidate"` (the level is not candidate
    ///   `skipped` of its manifest entry), `"actions"` (not one or more tunings in ascending string order followed by
    ///   one test), `"replay"` (a refused action, no win on the last action or a win or failure before it),
    ///   `"counterexample"` (a choice of fewer tunings wins, the starting pegs win, or the recount is not the plan's
    ///   `smallerChoices`) and `"difficulty"` (not the difficulty of the level and plan).
    public static func make(_ generated: HarmonicBridgesGenerated) throws(HarmonicBridgesError) -> Self {
        guard generated.entry.number >= 1, generated.entry.number <= HarmonicBridgesManifest.entries.count,
              HarmonicBridgesManifest.entries[generated.entry.number - 1] == generated.entry else {
            throw .witness("number")
        }
        let witness: Self = try build(number: generated.entry.number, level: generated.level,
                                      actions: generated.actions, work: generated.plan.work,
                                      skipped: generated.skipped)
        guard witness.counterexample.choices == generated.plan.smallerChoices else { throw .witness("counterexample") }
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
            preconditionFailure("a Harmonic Bridges witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the stored actions are replayed on a fresh play, every smaller
    /// choice is recounted, the difficulty is recomputed with the stored solver work, every stored value must equal
    /// the rebuilt one, and the solver run again must find the stored actions, smaller choices and work.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.witness("schema")` for a schema below 1;
    ///   `.witness("unreadable")` for damaged JSON, missing keys or values of the wrong type; `.witness("level")` for
    ///   a level the level rules refuse (an edited field breaks its fingerprint); any part ``make(_:)`` names;
    ///   `.witness(part)` with `"bridge-digests"`, `"fingerprints"`, `"counterexample"` or `"difficulty"` for a stored
    ///   value the rebuild does not reproduce; `.witness("solution")` when the solver, run again on the level, does
    ///   not find exactly the stored actions with the stored smaller choices and work.
    public static func decode(_ data: Data) throws(HarmonicBridgesError) -> Self {
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
        let rebuilt: Self = try build(number: stored.number, level: stored.level, actions: stored.actions,
                                      work: stored.difficulty.work, skipped: stored.skipped)
        guard rebuilt.bridgeDigests == stored.bridgeDigests else { throw .witness("bridge-digests") }
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.counterexample == stored.counterexample else { throw .witness("counterexample") }
        guard rebuilt.difficulty == stored.difficulty else { throw .witness("difficulty") }
        // The solver's own result (feature 382's convergence lesson): another winning plan of the same size or an
        // edited work count is refused too.
        guard let plan = HarmonicBridgesSolver.plan(stored.level),
              HarmonicBridgesSolver.actions(plan) == stored.actions,
              plan.smallerChoices == stored.counterexample.choices,
              plan.work == stored.difficulty.work else { throw .witness("solution") }
        return stored
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the play shows a tutorial) and `actions`, each
    /// applied with the current fingerprint: the fingerprint after `begin`, after `dismissTutorial` and after each
    /// action, the bridge digest after each tuning and whether any action before the last found the play no longer
    /// playing; nil when a stage event or an action is refused.
    static func replay(_ level: HarmonicBridgesLevel, actions: [HarmonicBridgesAction])
        -> (play: HarmonicBridgesPlay, fingerprints: [String], digests: [String], endedEarly: Bool)? {
        var play = HarmonicBridgesPlay(level: level)
        var fingerprints: [String] = []
        var digests: [String] = []
        var endedEarly: Bool = false
        do {
            try play.handle(.begin)
            fingerprints.append(play.fingerprint)
            if play.stage == .tutorial {
                try play.handle(.dismissTutorial)
                fingerprints.append(play.fingerprint)
            }
            for action in actions {
                if play.stage != .playing { endedEarly = true }
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                if case .tune = action { digests.append(digest(play.report)) }
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests, endedEarly)
    }

    /// The count of every choice of 1 … `size` retuned strings over the solver's options (subsets of the strings with
    /// an option, each with the product of its options), or nil when any of them, or the starting pegs, wins, or when
    /// more than ``HarmonicBridgesSolver/workBound`` choices would be counted.
    static func smallerChoices(_ level: HarmonicBridgesLevel, size: Int) -> Int? {
        var current: [Int] = []
        for string in 0..<level.strings.count {
            current.append(HarmonicBridgesSolver.mask(HarmonicBridgesSolver.pattern(level, string: string,
                                                                                     peg: level.strings[string].peg)))
        }
        if HarmonicBridgesSolver.winsAll(level, masks: current) { return nil }
        var useful: [Int] = []
        var optionMasks: [[Int]] = []
        for string in 0..<level.strings.count {
            let choices: [HarmonicBridgesTuning] = HarmonicBridgesSolver.options(level, string: string)
            if choices.isEmpty { continue }
            useful.append(string)
            var masks: [Int] = []
            for choice in choices {
                masks.append(HarmonicBridgesSolver.mask(HarmonicBridgesSolver.pattern(level, string: string,
                                                                                       peg: choice.peg)))
            }
            optionMasks.append(masks)
        }
        var count: Int = 0
        let largest: Int = min(size, useful.count)
        if largest < 1 { return 0 }
        for chosen in 1...largest {
            var subset: [Int] = Array(0..<chosen)
            while true {
                var digits: [Int] = Array(repeating: 0, count: chosen)
                while true {
                    count += 1
                    if count > HarmonicBridgesSolver.workBound { return nil }
                    var trial: [Int] = current
                    for position in 0..<chosen {
                        let slot: Int = subset[position]
                        trial[useful[slot]] = optionMasks[slot][digits[position]]
                    }
                    if HarmonicBridgesSolver.winsAll(level, masks: trial) { return nil }
                    if !nextDigits(&digits, subset: subset, counts: optionMasks) { break }
                }
                if !HarmonicBridgesSolver.nextSubset(&subset, of: useful.count) { break }
            }
        }
        return count
    }

    /// Advances the option digits of `subset` like an odometer, the last position fastest; false after the last.
    private static func nextDigits(_ digits: inout [Int], subset: [Int], counts: [[Int]]) -> Bool {
        var position: Int = digits.count - 1
        while position >= 0 {
            digits[position] += 1
            if digits[position] < counts[subset[position]].count { return true }
            digits[position] = 0
            position -= 1
        }
        return false
    }

    /// Builds a witness from its level, actions and solver work, checking every part.
    private static func build(number: Int, level: HarmonicBridgesLevel, actions: [HarmonicBridgesAction], work: Int,
                              skipped: Int) throws(HarmonicBridgesError) -> Self {
        // Provenance: the level is candidate `skipped` of manifest entry `number`.
        guard (1...HarmonicBridgesManifest.entries.count).contains(number),
              level.id == HarmonicBridgesGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<HarmonicBridgesGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        let entry: HarmonicBridgesManifestEntry = HarmonicBridgesManifest.entries[number - 1]
        guard entry.number == number, HarmonicBridgesGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        // Shape: one or more tunings in ascending string order, then one test.
        guard actions.count >= 2, actions[actions.count - 1] == .test else { throw .witness("actions") }
        var tunings: [HarmonicBridgesTuning] = []
        for action in actions.dropLast() {
            guard case .tune(let string, let peg) = action else { throw .witness("actions") }
            if let previous = tunings.last, previous.string >= string { throw .witness("actions") }
            tunings.append(HarmonicBridgesTuning(string: string, peg: peg))
        }
        // Replay on a fresh play: the witness must win on its last action and not before.
        guard let run = replay(level, actions: actions), run.play.stage == .won, !run.endedEarly else {
            throw .witness("replay")
        }
        // Recount: every choice of one tuning fewer and below fails; a one-tuning plan names the starting break.
        let size: Int = tunings.count - 1
        guard let choices = smallerChoices(level, size: size) else { throw .witness("counterexample") }
        var start: HarmonicBridgesBreak?
        if size == 0 {
            guard let broken = level.firstBreak(level.report(pegs: level.startingPegs)) else {
                throw .witness("counterexample")
            }
            start = broken
        }
        let counterexample = HarmonicBridgesCounterexample(size: size, choices: choices, start: start)
        let plan = HarmonicBridgesPlan(tunings: tunings, smallerChoices: choices, work: work)
        let difficulty = HarmonicBridgesDifficulty(level: level, plan: plan)
        return Self(number: number, level: level, actions: actions, bridgeDigests: run.digests,
                    fingerprints: run.fingerprints, counterexample: counterexample, difficulty: difficulty,
                    skipped: skipped)
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, bridgeDigests, fingerprints, counterexample, difficulty, skipped
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
        do { level = try c.decode(HarmonicBridgesLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([HarmonicBridgesAction].self, forKey: .actions)
        bridgeDigests = try c.decode([String].self, forKey: .bridgeDigests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        counterexample = try c.decode(HarmonicBridgesCounterexample.self, forKey: .counterexample)
        difficulty = try c.decode(HarmonicBridgesDifficulty.self, forKey: .difficulty)
        skipped = try c.decode(Int.self, forKey: .skipped)
    }

    /// Encodes the stored form with ``schema``.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(number, forKey: .number)
        try c.encode(level, forKey: .level)
        try c.encode(actions, forKey: .actions)
        try c.encode(bridgeDigests, forKey: .bridgeDigests)
        try c.encode(fingerprints, forKey: .fingerprints)
        try c.encode(counterexample, forKey: .counterexample)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}
