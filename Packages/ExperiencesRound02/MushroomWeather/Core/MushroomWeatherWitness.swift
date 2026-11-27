// MushroomWeatherWitness — feature 492 (R02-G20-02) T-R02G2002-005 (FR-R02G2002-004; SC-R02G2002-003, 005;
// clarification Q4), on the rule kernel of feature 491 (R02-G20-01), modelled on `MicroscopicAuroraWitness` (feature
// 482). The solver witness of one generated level: the manifest number, the level's stored form (with its sites), the
// actions (the plan's placements in slot order, then its vent toggles, then its moonlight change, then `run`), the
// 16-hex state digest of the arrangement and the actions spent after every action, the play fingerprints after
// `begin`, after `dismissTutorial` (when the level has a tutorial) and after each action, the terminal report (the
// ledger totals of the run — total at the start, released, evaporated, total at the end — each colony's final run,
// longest run and first cycle out of band, and the cycles run), the counterexample (the depth one below the plan, the
// number of arrangements the solver judged at exactly that depth, none winning, and the nearest miss), the difficulty
// and the candidates skipped. The stored form is JSON with sorted keys, pretty-printed, with one trailing newline.
// Making and decoding both rebuild the witness from its level: the actions are replayed on a fresh
// `MushroomWeatherPlay`, the level is re-derived as candidate `skipped` of its manifest entry, and the solver is run
// again on the level, whose plan followed by `run` must be exactly the stored actions; the counterexample and the
// difficulty come from that plan. Decoding re-checks the level under `MushroomWeatherLevel.decode`'s rules (its
// `Codable` conformance) and refuses any stored value the rebuild does not reproduce. Integers only; no clock, no
// random source.
import Foundation
import VisualCoreMath

/// The proof that no arrangement one action short of a witness plan wins (clarification Q4).
///
/// The solver judges every arrangement at a distance smaller than the plan, depth by depth, and none won. For a plan of
/// size `s ≥ 1`, ``depth`` is `s − 1`, ``arrangements`` is the number of arrangements judged at exactly that depth
/// (`plan.arrangementsByDepth[s − 1]`; depth 0 is the start, 1 arrangement) and ``nearestMiss`` is the smallest band
/// loss among all the arrangements judged at smaller depths (`plan.nearestMiss`).
public struct MushroomWeatherCounterexample: Sendable, Hashable, Codable {
    /// The depth one below the plan: the arrangement actions of the arrangements refuted.
    public let depth: Int
    /// The arrangements the solver judged at exactly ``depth``, none winning.
    public let arrangements: Int
    /// The smallest band loss among the arrangements judged below the plan.
    public let nearestMiss: Int

    /// A counterexample of the given values, unchecked.
    public init(depth: Int, arrangements: Int, nearestMiss: Int) {
        self.depth = depth
        self.arrangements = arrangements
        self.nearestMiss = nearestMiss
    }
}

/// The terminal report of a witness: the winning run's readings after the `run`, in stored form.
public struct MushroomWeatherWitnessReport: Sendable, Hashable, Codable {
    /// One colony's in-band runs over the winning run, in stored form.
    public struct Colony: Sendable, Hashable, Codable {
        /// The consecutive cycles in band ending at the last cycle run.
        public let finalRun: Int
        /// The longest run of consecutive cycles in band.
        public let longestRun: Int
        /// The first cycle at whose end the colony was out of band, nil (omitted from the JSON) when it never was.
        public let firstOutOfBand: Int?

        /// Colony runs of the given values, unchecked.
        public init(finalRun: Int, longestRun: Int, firstOutOfBand: Int?) {
            self.finalRun = finalRun
            self.longestRun = longestRun
            self.firstOutOfBand = firstOutOfBand
        }

        /// The stored form of `runs`.
        public init(_ runs: MushroomWeatherColonyRuns) {
            self.init(finalRun: runs.finalRun, longestRun: runs.longestRun, firstOutOfBand: runs.firstOutOfBand)
        }
    }

    /// The total humidity of the floor before the first cycle.
    public let start: Int
    /// The humidity released by pods over the run.
    public let released: Int
    /// The humidity evaporated over the run.
    public let evaporated: Int
    /// The total humidity of the floor after the last cycle run.
    public let end: Int
    /// Each colony's runs, by colony index.
    public let colonies: [Colony]
    /// The cycles run.
    public let cycles: Int

    /// A report of the given values, unchecked.
    public init(start: Int, released: Int, evaporated: Int, end: Int, colonies: [Colony], cycles: Int) {
        self.start = start
        self.released = released
        self.evaporated = evaporated
        self.end = end
        self.colonies = colonies
        self.cycles = cycles
    }

    /// The stored form of `report`: the ledger totals (the first cycle's total before, the sums released and
    /// evaporated, the last cycle's total after; all 0 for an empty ledger), the colony runs and the cycles run (the
    /// humidity field, the per-cycle ledger, the growth cycles and the failure are not stored; a witness report always
    /// wins).
    public init(_ report: MushroomWeatherReport) {
        var released: Int = 0
        var evaporated: Int = 0
        for entry in report.ledger {
            released += entry.released
            evaporated += entry.evaporated
        }
        var colonies: [Colony] = []
        for runs in report.colonies { colonies.append(Colony(runs)) }
        self.init(start: report.ledger.first?.before ?? 0, released: released, evaporated: evaporated,
                  end: report.ledger.last?.after ?? 0, colonies: colonies, cycles: report.cycles)
    }

    /// Whether the totals balance: end = start + released − evaporated.
    public var balances: Bool { end == start + released - evaporated }
}

/// The replayable proof that a generated Mushroom Weather level is won by its solver's plan within the budget and that
/// no arrangement one action short wins (clarification Q4).
public struct MushroomWeatherWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form with its sites.
    public let level: MushroomWeatherLevel
    /// The witness actions: the plan's placements in slot order, its vent toggles and its moonlight change, then `run`.
    public let actions: [MushroomWeatherAction]
    /// The state digest (``digest(arrangement:spent:)``) of the play after every action, in order.
    public let digests: [String]
    /// The play fingerprints after `begin`, after `dismissTutorial` when the level has a tutorial, and after each
    /// action.
    public let fingerprints: [String]
    /// The report of the play after the `run`.
    public let report: MushroomWeatherWitnessReport
    /// The proof that one action fewer cannot win.
    public let counterexample: MushroomWeatherCounterexample
    /// The level's difficulty, with the solver's arrangements searched, work and nearest miss.
    public let difficulty: MushroomWeatherDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: MushroomWeatherLevel, actions: [MushroomWeatherAction], digests: [String],
         fingerprints: [String], report: MushroomWeatherWitnessReport, counterexample: MushroomWeatherCounterexample,
         difficulty: MushroomWeatherDifficulty, skipped: Int) {
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

    /// The canonical text of a play state: `pods=` with the slots in order joined by `,`, each `row column` (single
    /// space) or `none`; `;vents=` with the vents in order joined by `,`, each `open` or `closed`; `;moonlight=` and the
    /// moonlight; `;spent=` and the actions spent. Example: `pods=2 3,none;vents=open;moonlight=1;spent=1`.
    public static func canonicalText(arrangement: MushroomWeatherArrangement, spent: Int) -> String {
        var pods: [String] = []
        for slot in arrangement.pods {
            if let cell = slot {
                pods.append(String(cell.row) + " " + String(cell.column))
            } else {
                pods.append("none")
            }
        }
        var vents: [String] = []
        for open in arrangement.ventsOpen { vents.append(open ? "open" : "closed") }
        return "pods=" + pods.joined(separator: ",") + ";vents=" + vents.joined(separator: ",") + ";moonlight="
            + String(arrangement.moonlight) + ";spent=" + String(spent)
    }

    /// The state digest: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8 bytes of
    /// ``canonicalText(arrangement:spent:)``.
    public static func digest(arrangement: MushroomWeatherArrangement, spent: Int) -> String {
        String(StableHash.sha256Hex(Array(canonicalText(arrangement: arrangement, spent: spent).utf8)).prefix(16))
    }

    /// The witness of a generated level, built by replaying its plan and the run on a fresh play.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry, an entry that is
    ///   not the manifest's, or a level id that is not `mushroom-weather-NNN`), `"skipped"` (outside 0 … 63),
    ///   `"actions"` (no arrangement action, more than the budget, an action that is not a placement into a slot on
    ///   one of the level's sites, a vent setting of an existing vent or a moonlight setting in range, or actions that
    ///   do not end with exactly one `run`), `"replay <reason>"` (a refused action, with its reason code, or
    ///   `"replay not won"` for a run that does not win), `"candidate"` (the level is not candidate `skipped` of its
    ///   manifest entry), `"solution"` (the solver, run again, does not find exactly these actions with the band's
    ///   plan length), `"counterexample"` (the plan's arrangements by depth or nearest miss are not the solver's) and
    ///   `"difficulty"` (not the difficulty of the level and the solver's plan, another work or another arrangement).
    public static func make(_ generated: MushroomWeatherGenerated) throws(MushroomWeatherError) -> Self {
        guard generated.entry.number >= 1, generated.entry.number <= MushroomWeatherManifest.entries.count,
              MushroomWeatherManifest.entries[generated.entry.number - 1] == generated.entry else {
            throw .witness("number")
        }
        let (witness, plan): (Self, MushroomWeatherPlan) = try build(number: generated.entry.number,
                                                                     level: generated.level,
                                                                     actions: generated.plan.actions + [.run],
                                                                     skipped: generated.skipped)
        guard generated.plan.arrangementsByDepth == plan.arrangementsByDepth,
              generated.plan.nearestMiss == plan.nearestMiss else {
            throw .witness("counterexample")
        }
        guard generated.difficulty == witness.difficulty, generated.plan.work == plan.work,
              generated.plan.arrangement == plan.arrangement else {
            throw .witness("difficulty")
        }
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
            preconditionFailure("a Mushroom Weather witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the level is re-checked under ``MushroomWeatherLevel/decode(_:)``'s
    /// rules, the stored actions are replayed on a fresh play, the level is re-derived from its manifest entry, the
    /// solver is run again, and every stored value must equal the rebuilt one.
    ///
    /// - Throws: `.newerSchema(s)` for a schema above ``schema``; `.witness("schema s")` for a schema below 1;
    ///   `.witness("unreadable")` for damaged JSON, missing keys or values of the wrong type; `.witness("level")` for a
    ///   level the level rules refuse (an edited field breaks its fingerprint); any part ``make(_:)`` names;
    ///   `.witness(part)` with `"digests"`, `"fingerprints"`, `"report"`, `"counterexample"` or `"difficulty"` for a
    ///   stored value the rebuild does not reproduce.
    public static func decode(_ data: Data) throws(MushroomWeatherError) -> Self {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .witness("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .witness("schema \(probe.schema)") }
        let stored: Self
        do {
            stored = try JSONDecoder().decode(Self.self, from: data)
        } catch is LevelRefusal {
            throw .witness("level")
        } catch {
            throw .witness("unreadable")
        }
        let (rebuilt, _): (Self, MushroomWeatherPlan) = try build(number: stored.number, level: stored.level,
                                                                  actions: stored.actions, skipped: stored.skipped)
        guard rebuilt.digests == stored.digests else { throw .witness("digests") }
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.report == stored.report else { throw .witness("report") }
        guard rebuilt.counterexample == stored.counterexample else { throw .witness("counterexample") }
        guard rebuilt.difficulty == stored.difficulty else { throw .witness("difficulty") }
        return stored
    }

    /// The outcome of a replay: the play with its fingerprints and digests, or the refusal that stopped it.
    enum Replay {
        /// Every event and action was accepted.
        case played(play: MushroomWeatherPlay, fingerprints: [String], digests: [String])
        /// A stage event or an action was refused with `error`.
        case refused(MushroomWeatherError)
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the play shows a tutorial) and `actions`, each
    /// applied with the current fingerprint: the fingerprint after `begin`, after `dismissTutorial` and after each
    /// action, and the state digest after each action; or the refusal of a stage event or an action.
    static func replay(_ level: MushroomWeatherLevel, actions: [MushroomWeatherAction]) -> Replay {
        var play = MushroomWeatherPlay(level: level)
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

    /// Whether `action` is an arrangement action of the witness shape on `level`: a placement into a slot on one of
    /// its sites, a setting of one of its vents or a moonlight setting in range.
    static func isShaped(_ action: MushroomWeatherAction, level: MushroomWeatherLevel) -> Bool {
        switch action {
        case .place(let slot, let cell):
            return (0..<level.podRules.slots).contains(slot) && (level.sites ?? []).contains(cell)
        case .vent(let index, _):
            return level.vents.indices.contains(index)
        case .moonlight(let value):
            return MushroomWeatherLevel.moonlightLevels.contains(value)
        case .remove, .run:
            return false
        }
    }

    /// Builds a witness from its level, actions and skipped count, checking every part, with the solver's plan.
    private static func build(number: Int, level: MushroomWeatherLevel, actions: [MushroomWeatherAction],
                              skipped: Int) throws(MushroomWeatherError) -> (Self, MushroomWeatherPlan) {
        // Provenance, first part: the number names a manifest entry and the level carries its id.
        guard (1...MushroomWeatherManifest.entries.count).contains(number),
              level.id == MushroomWeatherGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<MushroomWeatherGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        // Shape: at least one arrangement action, within the budget, each of the witness shape, followed by exactly
        // one run.
        guard actions.count >= 2, actions.last == .run else { throw .witness("actions") }
        let arrangementActions: [MushroomWeatherAction] = Array(actions.dropLast())
        guard arrangementActions.count <= level.budget else { throw .witness("actions") }
        for action in arrangementActions where !isShaped(action, level: level) { throw .witness("actions") }
        // Replay on a fresh play: every action must be accepted and the run must win.
        let play: MushroomWeatherPlay
        let fingerprints: [String]
        let digests: [String]
        switch replay(level, actions: actions) {
        case .refused(let error):
            throw .witness("replay " + error.reasonCode)
        case .played(let p, let f, let d):
            play = p
            fingerprints = f
            digests = d
        }
        guard play.stage == .won else { throw .witness("replay not won") }
        // Provenance, second part: the level is candidate `skipped` of manifest entry `number`.
        let entry: MushroomWeatherManifestEntry = MushroomWeatherManifest.entries[number - 1]
        guard entry.number == number, MushroomWeatherGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        // The solver's own result: its plan must be exactly these actions, with the band's plan length.
        let length: Int = MushroomWeatherBandProfile.of(band: entry.band).plan
        guard let plan = MushroomWeatherSolver.plan(level), plan.actions == arrangementActions, plan.size == length,
              plan.size >= 1, plan.arrangementsByDepth.count == plan.size else {
            throw .witness("solution")
        }
        let depth: Int = plan.size - 1
        let counterexample = MushroomWeatherCounterexample(depth: depth, arrangements: plan.arrangementsByDepth[depth],
                                                           nearestMiss: plan.nearestMiss)
        let difficulty = MushroomWeatherDifficulty(level: level, plan: plan)
        let report = MushroomWeatherWitnessReport(play.report)
        let witness = Self(number: number, level: level, actions: actions, digests: digests,
                           fingerprints: fingerprints, report: report, counterexample: counterexample,
                           difficulty: difficulty, skipped: skipped)
        return (witness, plan)
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, digests, fingerprints, report, counterexample, difficulty, skipped
    }

    /// Decodes the stored fields without re-verifying them (the level is re-checked by its own rules);
    /// ``decode(_:)`` decodes and re-verifies.
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
        do { level = try c.decode(MushroomWeatherLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([MushroomWeatherAction].self, forKey: .actions)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        report = try c.decode(MushroomWeatherWitnessReport.self, forKey: .report)
        counterexample = try c.decode(MushroomWeatherCounterexample.self, forKey: .counterexample)
        difficulty = try c.decode(MushroomWeatherDifficulty.self, forKey: .difficulty)
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
