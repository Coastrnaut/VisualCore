// MyceliumArchitectWitness — feature 512 (R02-G22-02) T-R02G2202-006 (FR-R02G2202-004; SC-R02G2202-003; clarification
// Q5; research R6), on the rule kernel of feature 511 (R02-G22-01), modelled on `BinaryGardensWitness` (feature 502).
// The solver witness of one generated level: the manifest number, the level's stored form, the actions (the solver's
// plan, then `run`), the 16-hex state digest of the arrangement and the actions spent after every action, the play
// fingerprints after `begin`, after `dismissTutorial` (when the level has a tutorial) and after each action, the
// terminal report (each terminal reached with its pulse and path weight, the total branch cost against the nutrient
// budget and the weight limit, the node count, the first toxic entry or none, the outcome), the counterexample (the
// depth one below the plan, the number of arrangements the solver judged at exactly that depth, none winning, and the
// nearest miss: its loss, its arrangement and its failure, also in words), the difficulty and the candidates skipped.
// The stored form is JSON with sorted keys, pretty-printed, with one trailing newline. `verify()` rebuilds every part:
// the actions are replayed on a fresh `MyceliumArchitectPlay`, the level is re-derived as candidate `skipped` of its
// manifest entry, whose solver plan must be exactly the stored actions; the counterexample and the difficulty come from
// that plan. Decoding re-checks the level under `MyceliumArchitectLevel.decode`'s rules and then verifies. Integers
// only; no clock, no random source.
import Foundation
import VisualCoreMath

/// The proof that no arrangement reachable with one action fewer than a witness plan wins (clarification Q5).
///
/// The solver judges every arrangement at a depth smaller than the plan, depth by depth, and none won. For a plan
/// of length `p ≥ 1`, ``depth`` is `p − 1`, ``arrangements`` is the number of arrangements judged at exactly that depth
/// (`countsByDepth[p − 1]`; depth 0 is the start, 1 arrangement), ``nearestMiss`` is the smallest loss among all the
/// arrangements judged at smaller depths, ``arrangement`` is that nearest miss and ``failure`` its first failure.
public struct MyceliumArchitectCounterexample: Sendable, Hashable, Codable {
    /// The depth one below the plan: the arrangement actions of the deepest arrangements refuted.
    public let depth: Int
    /// The arrangements the solver judged at exactly ``depth``, none winning.
    public let arrangements: Int
    /// The smallest loss (``MyceliumArchitectSolver/loss(_:_:)``) among the arrangements judged below the plan.
    public let nearestMiss: Int
    /// The arrangement of ``nearestMiss``.
    public let arrangement: MyceliumArchitectArrangement
    /// Why ``arrangement`` fails: the judge's first failure.
    public let failure: MyceliumArchitectFailure
    /// ``failure`` in words (``MyceliumArchitectLevel/failureDescription(_:)``).
    public let failureWords: String

    /// A counterexample of the given values, unchecked.
    public init(depth: Int, arrangements: Int, nearestMiss: Int, arrangement: MyceliumArchitectArrangement,
                failure: MyceliumArchitectFailure, failureWords: String) {
        self.depth = depth
        self.arrangements = arrangements
        self.nearestMiss = nearestMiss
        self.arrangement = arrangement
        self.failure = failure
        self.failureWords = failureWords
    }

    /// The counterexample of `solution` on `level`, or nil when the solution has no plan, its counts do not cover
    /// every depth below the plan or its nearest miss has no failure.
    public init?(level: MyceliumArchitectLevel, solution: MyceliumArchitectSolution) {
        let length: Int = solution.length
        guard length >= 1, solution.countsByDepth.count == length,
              let failure = solution.nearestMissFailure else { return nil }
        self.init(depth: length - 1, arrangements: solution.countsByDepth[length - 1],
                  nearestMiss: solution.nearestMissLoss, arrangement: solution.nearestMiss, failure: failure,
                  failureWords: level.failureDescription(failure))
    }
}

/// The terminal report of a witness: the winning run's growth after the `run`, in stored form (the truth metric).
public struct MyceliumArchitectWitnessReport: Sendable, Hashable, Codable {
    /// One terminal of the level after the run.
    public struct Terminal: Sendable, Hashable, Codable {
        /// The terminal's index in the level, from 0.
        public let index: Int
        /// The terminal's cell.
        public let cell: MyceliumArchitectCell
        /// The pulse on which the network reached it, or nil when it was not reached.
        public let pulse: Int?
        /// The branch weight of the path from the root to it, or nil when it was not reached.
        public let pathWeight: Int?

        /// A terminal of the given values, unchecked.
        public init(index: Int, cell: MyceliumArchitectCell, pulse: Int?, pathWeight: Int?) {
            self.index = index
            self.cell = cell
            self.pulse = pulse
            self.pathWeight = pathWeight
        }
    }

    /// The first step of the run into a toxin.
    public struct ToxicEntry: Sendable, Hashable, Codable {
        /// The pulse of the entry.
        public let pulse: Int
        /// The tip that grew into the toxin, from 0.
        public let tip: Int
        /// The toxic cell.
        public let cell: MyceliumArchitectCell

        /// A toxic entry of the given values, unchecked.
        public init(pulse: Int, tip: Int, cell: MyceliumArchitectCell) {
            self.pulse = pulse
            self.tip = tip
            self.cell = cell
        }
    }

    /// Each terminal, by index.
    public let terminals: [Terminal]
    /// The network's total branch cost.
    public let totalWeight: Int
    /// The level's nutrient budget.
    public let nutrientBudget: Int
    /// The level's weight limit.
    public let weightLimit: Int
    /// The grown cells, the root included.
    public let nodeCount: Int
    /// The first toxic entry, or nil (stored as `null`) when the run entered no toxin.
    public let firstToxic: ToxicEntry?
    /// The outcome: "won", or the failure's code for a report that does not win.
    public let outcome: String

    /// A report of the given values, unchecked.
    public init(terminals: [Terminal], totalWeight: Int, nutrientBudget: Int, weightLimit: Int, nodeCount: Int,
                firstToxic: ToxicEntry?, outcome: String) {
        self.terminals = terminals
        self.totalWeight = totalWeight
        self.nutrientBudget = nutrientBudget
        self.weightLimit = weightLimit
        self.nodeCount = nodeCount
        self.firstToxic = firstToxic
        self.outcome = outcome
    }

    /// The stored form of `report` on `level`: per terminal its cell, pulse and path weight; the total branch cost
    /// with the level's budget and limit; the node count; the toxic entry of a toxic failure; "won" or the failure's
    /// code (the field, the steps and the grown cells are not stored).
    public init(level: MyceliumArchitectLevel, report: MyceliumArchitectReport) {
        var terminals: [Terminal] = []
        for (index, cell) in level.terminals.enumerated() {
            let pulse: Int? = index < report.terminalPulses.count ? report.terminalPulses[index] : nil
            let weight: Int? = index < report.terminalPathWeights.count ? report.terminalPathWeights[index] : nil
            terminals.append(Terminal(index: index, cell: cell, pulse: pulse, pathWeight: weight))
        }
        var toxic: ToxicEntry?
        if case .toxic(let pulse, let tip, let cell) = report.failure {
            toxic = ToxicEntry(pulse: pulse, tip: tip, cell: cell)
        }
        self.init(terminals: terminals, totalWeight: report.totalWeight, nutrientBudget: level.nutrientBudget,
                  weightLimit: level.weightLimit, nodeCount: report.nodeCount, firstToxic: toxic,
                  outcome: report.failure?.code ?? "won")
    }

    private enum CodingKeys: String, CodingKey {
        case terminals, totalWeight, nutrientBudget, weightLimit, nodeCount, firstToxic, outcome
    }

    /// Decodes the stored fields; a `null` or missing ``firstToxic`` is none.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        terminals = try c.decode([Terminal].self, forKey: .terminals)
        totalWeight = try c.decode(Int.self, forKey: .totalWeight)
        nutrientBudget = try c.decode(Int.self, forKey: .nutrientBudget)
        weightLimit = try c.decode(Int.self, forKey: .weightLimit)
        nodeCount = try c.decode(Int.self, forKey: .nodeCount)
        firstToxic = try c.decodeIfPresent(ToxicEntry.self, forKey: .firstToxic)
        outcome = try c.decode(String.self, forKey: .outcome)
    }

    /// Encodes every field, ``firstToxic`` as `null` when there is none.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(terminals, forKey: .terminals)
        try c.encode(totalWeight, forKey: .totalWeight)
        try c.encode(nutrientBudget, forKey: .nutrientBudget)
        try c.encode(weightLimit, forKey: .weightLimit)
        try c.encode(nodeCount, forKey: .nodeCount)
        if let firstToxic {
            try c.encode(firstToxic, forKey: .firstToxic)
        } else {
            try c.encodeNil(forKey: .firstToxic)
        }
        try c.encode(outcome, forKey: .outcome)
    }
}

/// The replayable proof that a generated Mycelium Architect level is won by its solver's plan within the budget and
/// that no arrangement reachable with one action fewer wins (clarification Q5).
public struct MyceliumArchitectWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: MyceliumArchitectLevel
    /// The witness actions: the plan's nutrient, blocker and seed actions, then `run`.
    public let actions: [MyceliumArchitectAction]
    /// The state digest (``digest(arrangement:spent:)``) of the play after every action, in order.
    public let digests: [String]
    /// The play fingerprints after `begin`, after `dismissTutorial` when the level has a tutorial, and after each
    /// action.
    public let fingerprints: [String]
    /// The report of the play after the `run`.
    public let report: MyceliumArchitectWitnessReport
    /// The proof that one action fewer cannot win.
    public let counterexample: MyceliumArchitectCounterexample
    /// The level's difficulty, from the solver's actual work.
    public let difficulty: MyceliumArchitectDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``verify()`` and ``decode(_:)`` check).
    init(number: Int, level: MyceliumArchitectLevel, actions: [MyceliumArchitectAction], digests: [String],
         fingerprints: [String], report: MyceliumArchitectWitnessReport,
         counterexample: MyceliumArchitectCounterexample, difficulty: MyceliumArchitectDifficulty, skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.digests = digests
        self.fingerprints = fingerprints
        self.report = report
        self.counterexample = counterexample
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The witness of a generated level, built by replaying its plan and the run on a fresh play.
    ///
    /// The generator certifies that the plan wins through the play and that the solution carries its proof, so a
    /// generated level always yields a witness; anything else is a programming error.
    public init(generated: MyceliumArchitectGeneratedLevel) {
        let replayed: Replay = Self.replay(generated.level, actions: generated.solution.actions)
        guard case .played(let play, let fingerprints, let digests) = replayed, play.stage == .won else {
            preconditionFailure("a generated Mycelium Architect level always replays to a win")
        }
        guard let counterexample = MyceliumArchitectCounterexample(level: generated.level,
                                                                   solution: generated.solution) else {
            preconditionFailure("a generated Mycelium Architect solution always carries its counterexample")
        }
        self.init(number: generated.entry.number, level: generated.level, actions: generated.solution.actions,
                  digests: digests, fingerprints: fingerprints,
                  report: MyceliumArchitectWitnessReport(level: generated.level, report: play.report),
                  counterexample: counterexample, difficulty: generated.difficulty, skipped: generated.skipped)
    }

    /// The canonical text of a play state: `nutrients=[c,r],…;blockers=[c,r],…;seeds=d,…;spent=s` (cells and direction
    /// numbers in the arrangement's sorted order). Example: `nutrients=[3,4];blockers=;seeds=0,2;spent=2`.
    public static func canonicalText(arrangement: MyceliumArchitectArrangement, spent: Int) -> String {
        "nutrients=" + MyceliumArchitectPlay.cells(arrangement.nutrients) + ";blockers="
            + MyceliumArchitectPlay.cells(arrangement.blockers) + ";seeds="
            + MyceliumArchitectPlay.directions(arrangement.seeds) + ";spent=" + String(spent)
    }

    /// The state digest: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8 bytes of
    /// ``canonicalText(arrangement:spent:)``.
    public static func digest(arrangement: MyceliumArchitectArrangement, spent: Int) -> String {
        String(StableHash.sha256Hex(Array(canonicalText(arrangement: arrangement, spent: spent).utf8)).prefix(16))
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
            preconditionFailure("a Mycelium Architect witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and verifies it (``verify()``).
    ///
    /// - Throws: `.malformed("unreadable")` for damaged JSON, missing keys or values of the wrong type;
    ///   `.newerSchema(s)` for a schema above ``schema``; `.malformed("schema s")` for a schema below 1;
    ///   `.malformed("level")` for a level the level rules refuse (an edited field breaks its fingerprint); any
    ///   `.witness(part)` that ``verify()`` names.
    public static func decode(_ data: Data) throws(MyceliumArchitectError) -> MyceliumArchitectWitness {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: MyceliumArchitectWitness
        do {
            stored = try JSONDecoder().decode(MyceliumArchitectWitness.self, from: data)
        } catch is LevelRefusal {
            throw .malformed("level")
        } catch {
            throw .malformed("unreadable")
        }
        try stored.verify()
        return stored
    }

    /// Rebuilds every part of the witness and compares it with the stored one: the actions are replayed on a fresh
    /// play from `begin` (and `dismissTutorial` when the level has a tutorial), the level is re-derived as candidate
    /// ``skipped`` of manifest entry ``number`` and its solver plan, counterexample and difficulty are recomputed.
    ///
    /// - Throws: `.witness(part)` for the first part that does not hold, in this order: `"number"` (no manifest entry,
    ///   or a level id that is not `mycelium-architect-NNN`), `"skipped"` (outside 0 … candidate bound − 1),
    ///   `"actions"` (no arrangement action, more than the budget, an action that is not a nutrient, blocker or seed,
    ///   or actions that do not end with exactly one `run`), `"replay <reason code>"` (a refused event or action) or
    ///   `"replay not won"`, `"digests"`, `"fingerprints"`, `"report"`, `"candidate"` (the level is not candidate
    ///   ``skipped`` of its entry), `"solution"` (the solver's plan is not these actions), `"counterexample"` (another
    ///   depth, count, nearest miss, arrangement or failure, or a nearest miss that wins) and `"difficulty"`.
    public func verify() throws(MyceliumArchitectError) {
        let entries: [MyceliumArchitectManifestEntry] = MyceliumArchitectManifest.entries
        guard number >= 1, number <= entries.count,
              level.id == String(format: "mycelium-architect-%03d", number) else { throw .witness("number") }
        guard skipped >= 0, skipped < MyceliumArchitectGenerator.candidateBound else { throw .witness("skipped") }
        guard actions.count >= 2, actions.last == .run, actions.count - 1 <= level.budget else {
            throw .witness("actions")
        }
        for action in actions.dropLast() where !Self.isShaped(action) { throw .witness("actions") }
        let play: MyceliumArchitectPlay
        let replayedFingerprints: [String]
        let replayedDigests: [String]
        switch Self.replay(level, actions: actions) {
        case .refused(let error):
            throw .witness("replay " + error.reasonCode)
        case .played(let p, let f, let d):
            play = p
            replayedFingerprints = f
            replayedDigests = d
        }
        guard play.stage == .won else { throw .witness("replay not won") }
        guard replayedDigests == digests else { throw .witness("digests") }
        guard replayedFingerprints == fingerprints else { throw .witness("fingerprints") }
        guard MyceliumArchitectWitnessReport(level: level, report: play.report) == report else {
            throw .witness("report")
        }
        let entry: MyceliumArchitectManifestEntry = entries[number - 1]
        guard entry.number == number,
              let regenerated = MyceliumArchitectGenerator.candidate(entry, index: skipped, previous: nil),
              regenerated.level == level else { throw .witness("candidate") }
        guard regenerated.solution.actions == actions else { throw .witness("solution") }
        guard let rebuilt = MyceliumArchitectCounterexample(level: level, solution: regenerated.solution),
              rebuilt == counterexample,
              !MyceliumArchitectGrowth.report(level, arrangement: rebuilt.arrangement).wins else {
            throw .witness("counterexample")
        }
        guard MyceliumArchitectDifficulty(level: level, solution: regenerated.solution) == difficulty,
              regenerated.difficulty == difficulty else { throw .witness("difficulty") }
    }

    /// The outcome of a replay: the play with its fingerprints and digests, or the refusal that stopped it.
    enum Replay {
        /// Every event and action was accepted.
        case played(play: MyceliumArchitectPlay, fingerprints: [String], digests: [String])
        /// A stage event or an action was refused with `error`.
        case refused(MyceliumArchitectError)
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the play shows a tutorial) and `actions`, each
    /// applied with the current fingerprint: the fingerprint after `begin`, after `dismissTutorial` and after each
    /// action, and the state digest after each action; or the refusal of a stage event or an action.
    static func replay(_ level: MyceliumArchitectLevel, actions: [MyceliumArchitectAction]) -> Replay {
        var play = MyceliumArchitectPlay(level: level)
        var fingerprints: [String] = []
        var digests: [String] = []
        do {
            try play.handle(.begin)
            fingerprints.append(play.fingerprint)
            if play.stage == .tutorial {
                try play.handle(.dismissTutorial)
                fingerprints.append(play.fingerprint)
            }
            for action in actions {
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
                digests.append(digest(arrangement: play.arrangement, spent: play.actionsSpent))
            }
        } catch {
            return .refused(error)
        }
        return .played(play: play, fingerprints: fingerprints, digests: digests)
    }

    /// Whether `action` is an arrangement action of the witness shape: a nutrient, a blocker or a seed (a minimal plan
    /// from the start never clears, unseeds or runs early).
    static func isShaped(_ action: MyceliumArchitectAction) -> Bool {
        switch action {
        case .nutrient, .blocker, .seed: true
        case .clear, .unseed, .run: false
        }
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, digests, fingerprints, report, counterexample, difficulty, skipped
    }

    /// Decodes the stored fields without verifying them (the level is re-checked by its own rules); ``decode(_:)``
    /// decodes and verifies.
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
        do { level = try c.decode(MyceliumArchitectLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([MyceliumArchitectAction].self, forKey: .actions)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        report = try c.decode(MyceliumArchitectWitnessReport.self, forKey: .report)
        counterexample = try c.decode(MyceliumArchitectCounterexample.self, forKey: .counterexample)
        difficulty = try c.decode(MyceliumArchitectDifficulty.self, forKey: .difficulty)
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
        try c.encode(report, forKey: .report)
        try c.encode(counterexample, forKey: .counterexample)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}
