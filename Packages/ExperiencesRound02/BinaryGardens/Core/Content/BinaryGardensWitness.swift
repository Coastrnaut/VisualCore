// BinaryGardensWitness — feature 502 (R02-G21-02) T-R02G2102-005 (FR-R02G2102-004; SC-R02G2102-003, 005; clarification
// Q4; research R8, R9), on the rule kernel of feature 501 (R02-G21-01), modelled on `MushroomWeatherWitness` (feature
// 492). The solver witness of one generated level: the manifest number, the level's stored form (with its phase step),
// the actions (the plan — the winning arrangement's parent chain in the solver's sweep — then `run`), the 16-hex state
// digest of the arrangement and the actions spent after every action, the play fingerprints after `begin`, after
// `dismissTutorial` (when the level has a tutorial) and after each action, the terminal report (the truth metric: per
// world its integrated flux, its mean flux kept exact as the integral over 48 ticks — a whole part and a remainder —,
// its longest lethal run against the tolerance, its longest comfortable window with its start tick against the
// requirement and its bloom result; the minimum squared star separation and its tick; the outcome), the counterexample
// (the depth one below the plan, the number of arrangements the solver judged at exactly that depth, none winning, and
// the nearest miss: its loss, its arrangement and its first failure, with world and tick or measure), the difficulty
// and the candidates skipped. The stored form is JSON with sorted keys, pretty-printed, with one trailing newline.
// Making and decoding both rebuild the witness from its level: the actions are replayed on a fresh `BinaryGardensPlay`,
// the level is re-derived as candidate `skipped` of its manifest entry, and the solver is run again on the level (to
// the band's plan length), whose plan followed by `run` must be exactly the stored actions; the counterexample and the
// difficulty come from that plan. Decoding re-checks the level under `BinaryGardensLevel.decode`'s rules (its `Codable`
// conformance) and refuses any stored value the rebuild does not reproduce. Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// The proof that no arrangement reachable with one action fewer than a witness plan wins (clarification Q4).
///
/// The solver judges every arrangement at a depth smaller than the plan, depth by depth, and none won. For a plan of
/// size `s ≥ 1`, ``depth`` is `s − 1`, ``arrangements`` is the number of arrangements judged at exactly that depth
/// (`plan.arrangementsByDepth[s − 1]`; depth 0 is the start, 1 arrangement), ``nearestMiss`` is the smallest light loss
/// among all the arrangements judged at smaller depths (`plan.nearestMiss`), ``arrangement`` is the first arrangement
/// in judging order with that loss and ``failure`` is the judge's first failure of it.
public struct BinaryGardensCounterexample: Sendable, Hashable, Codable {
    /// The depth one below the plan: the arrangement actions of the deepest arrangements refuted.
    public let depth: Int
    /// The arrangements the solver judged at exactly ``depth``, none winning.
    public let arrangements: Int
    /// The smallest light loss among the arrangements judged below the plan, in milliflux.
    public let nearestMiss: Int
    /// The arrangement of ``nearestMiss``.
    public let arrangement: BinaryGardensArrangement
    /// Why ``arrangement`` fails: the judge's first failure, naming the world and the tick or the measure.
    public let failure: BinaryGardensFailure

    /// A counterexample of the given values, unchecked.
    public init(depth: Int, arrangements: Int, nearestMiss: Int, arrangement: BinaryGardensArrangement,
                failure: BinaryGardensFailure) {
        self.depth = depth
        self.arrangements = arrangements
        self.nearestMiss = nearestMiss
        self.arrangement = arrangement
        self.failure = failure
    }
}

/// The terminal report of a witness: the winning run's light after the `run`, in stored form (the truth metric).
public struct BinaryGardensWitnessReport: Sendable, Hashable, Codable {
    /// One world's light over the winning cycle, in stored form.
    public struct World: Sendable, Hashable, Codable {
        /// The integrated flux I: the sum of the flux over ticks 1 … 48, in milliflux.
        public let integral: Int
        /// The whole part of the mean flux, I / 48 (truncated).
        public let meanWhole: Int
        /// The remainder of the mean flux, I mod 48 (the mean is exactly `meanWhole + meanRemainder / 48`).
        public let meanRemainder: Int
        /// The longest run of consecutive lethal ticks, read cyclically.
        public let longestLethalRun: Int
        /// The lethal tolerance E of the level.
        public let tolerance: Int
        /// The longest cyclic comfortable window, in ticks.
        public let window: Int
        /// The start tick of ``window`` (1 … 48; 0 when no tick is comfortable).
        public let windowStart: Int
        /// The required window W of the world.
        public let requiredWindow: Int
        /// Where ``integral`` lies against the bloom band.
        public let bloom: BinaryGardensBloom

        /// A world of the given values, unchecked.
        public init(integral: Int, meanWhole: Int, meanRemainder: Int, longestLethalRun: Int, tolerance: Int,
                    window: Int, windowStart: Int, requiredWindow: Int, bloom: BinaryGardensBloom) {
            self.integral = integral
            self.meanWhole = meanWhole
            self.meanRemainder = meanRemainder
            self.longestLethalRun = longestLethalRun
            self.tolerance = tolerance
            self.window = window
            self.windowStart = windowStart
            self.requiredWindow = requiredWindow
            self.bloom = bloom
        }
    }

    /// Each world's light, by world index.
    public let worlds: [World]
    /// The smallest squared star separation over ticks 0 … 47, at scale 2^40.
    public let minimumSeparationSquared: Int
    /// The earliest tick 0 … 47 of ``minimumSeparationSquared``.
    public let minimumSeparationTick: Int
    /// The outcome: "won", or the failure's code for a report that does not win.
    public let outcome: String

    /// A report of the given values, unchecked.
    public init(worlds: [World], minimumSeparationSquared: Int, minimumSeparationTick: Int, outcome: String) {
        self.worlds = worlds
        self.minimumSeparationSquared = minimumSeparationSquared
        self.minimumSeparationTick = minimumSeparationTick
        self.outcome = outcome
    }

    /// The stored form of `report` on `level`: per world the integral, the exact mean as I / 48 and I mod 48, the
    /// longest lethal run with the level's tolerance, the window with its start and the world's requirement, the bloom;
    /// the minimum separation with its tick; "won" or the failure's code (positions, per-tick fluxes, shares and bands
    /// are not stored).
    public init(level: BinaryGardensLevel, report: BinaryGardensReport) {
        var worlds: [World] = []
        for (index, light) in report.worlds.enumerated() {
            let required: Int = index < level.worlds.count ? level.worlds[index].window : 0
            worlds.append(World(integral: light.integral, meanWhole: light.integral / BinaryGardensSky.cycle,
                                meanRemainder: light.integral % BinaryGardensSky.cycle,
                                longestLethalRun: light.longestLethalRun, tolerance: level.lethalTolerance,
                                window: light.window, windowStart: light.windowStart, requiredWindow: required,
                                bloom: light.bloom))
        }
        self.init(worlds: worlds, minimumSeparationSquared: report.minimumSeparationSquared,
                  minimumSeparationTick: report.minimumSeparationTick, outcome: report.failure?.code ?? "won")
    }
}

/// The replayable proof that a generated Binary Gardens level is won by its solver's plan within the budget and that
/// no arrangement reachable with one action fewer wins (clarification Q4).
public struct BinaryGardensWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form with its phase step.
    public let level: BinaryGardensLevel
    /// The witness actions: the plan's ring, phase, luminosity and tilt actions, then `run`.
    public let actions: [BinaryGardensAction]
    /// The state digest (``digest(arrangement:spent:)``) of the play after every action, in order.
    public let digests: [String]
    /// The play fingerprints after `begin`, after `dismissTutorial` when the level has a tutorial, and after each
    /// action.
    public let fingerprints: [String]
    /// The report of the play after the `run`.
    public let report: BinaryGardensWitnessReport
    /// The proof that one action fewer cannot win.
    public let counterexample: BinaryGardensCounterexample
    /// The level's difficulty, with the solver's arrangements searched, work and nearest miss.
    public let difficulty: BinaryGardensDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: BinaryGardensLevel, actions: [BinaryGardensAction], digests: [String],
         fingerprints: [String], report: BinaryGardensWitnessReport, counterexample: BinaryGardensCounterexample,
         difficulty: BinaryGardensDifficulty, skipped: Int) {
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

    /// The canonical text of a play state: `rings=a,b;phases=a,b;luminosities=a,b;tilt=t;spent=s` (ring and luminosity
    /// indices and phases as stored, star 1 first). Example: `rings=0,2;phases=8,24;luminosities=1,0;tilt=1;spent=2`.
    public static func canonicalText(arrangement: BinaryGardensArrangement, spent: Int) -> String {
        "rings=" + BinaryGardensPlay.list(arrangement.rings) + ";phases=" + BinaryGardensPlay.list(arrangement.phases)
            + ";luminosities=" + BinaryGardensPlay.list(arrangement.luminosities) + ";tilt="
            + String(arrangement.tilt) + ";spent=" + String(spent)
    }

    /// The state digest: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8 bytes of
    /// ``canonicalText(arrangement:spent:)``.
    public static func digest(arrangement: BinaryGardensArrangement, spent: Int) -> String {
        String(StableHash.sha256Hex(Array(canonicalText(arrangement: arrangement, spent: spent).utf8)).prefix(16))
    }

    /// The witness of a generated level, built by replaying its plan and the run on a fresh play.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry, an entry that is
    ///   not the manifest's, or a level id that is not `binary-gardens-NNN`), `"skipped"` (outside 0 … 63),
    ///   `"actions"` (no arrangement action, more than the budget, an action that is not a ring, phase, luminosity or
    ///   tilt setting within the level's ranges and phase grid, or actions that do not end with exactly one `run`),
    ///   `"replay <reason>"` (a refused action, with its reason code, or `"replay not won"` for a run that does not
    ///   win), `"candidate"` (the level is not candidate `skipped` of its manifest entry), `"solution"` (the solver,
    ///   run again to the band's plan length, does not find exactly these actions), `"counterexample"` (the plan's
    ///   arrangements by depth, nearest miss or its arrangement are not the solver's, or the nearest miss wins) and
    ///   `"difficulty"` (not the difficulty of the level and the solver's plan, another work or another arrangement).
    public static func make(_ generated: BinaryGardensGenerated) throws(BinaryGardensError) -> Self {
        guard generated.entry.number >= 1, generated.entry.number <= BinaryGardensManifest.entries.count,
              BinaryGardensManifest.entries[generated.entry.number - 1] == generated.entry else {
            throw .witness("number")
        }
        let (witness, plan): (Self, BinaryGardensPlan) = try build(number: generated.entry.number,
                                                                   level: generated.level,
                                                                   actions: generated.plan.actions + [.run],
                                                                   skipped: generated.skipped)
        guard generated.plan.arrangementsByDepth == plan.arrangementsByDepth,
              generated.plan.nearestMiss == plan.nearestMiss,
              generated.plan.nearestMissArrangement == plan.nearestMissArrangement else {
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
            preconditionFailure("a Binary Gardens witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the level is re-checked under ``BinaryGardensLevel/decode(_:)``'s
    /// rules, the stored actions are replayed on a fresh play, the level is re-derived from its manifest entry, the
    /// solver is run again, and every stored value must equal the rebuilt one.
    ///
    /// - Throws: `.newerSchema(s)` for a schema above ``schema``; `.witness("schema s")` for a schema below 1;
    ///   `.witness("unreadable")` for damaged JSON, missing keys or values of the wrong type; `.witness("level")` for a
    ///   level the level rules refuse (an edited field breaks its fingerprint); any part ``make(_:)`` names;
    ///   `.witness(part)` with `"digests"`, `"fingerprints"`, `"report"`, `"counterexample"` or `"difficulty"` for a
    ///   stored value the rebuild does not reproduce.
    public static func decode(_ data: Data) throws(BinaryGardensError) -> Self {
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
        let (rebuilt, _): (Self, BinaryGardensPlan) = try build(number: stored.number, level: stored.level,
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
        case played(play: BinaryGardensPlay, fingerprints: [String], digests: [String])
        /// A stage event or an action was refused with `error`.
        case refused(BinaryGardensError)
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the play shows a tutorial) and `actions`, each
    /// applied with the current fingerprint: the fingerprint after `begin`, after `dismissTutorial` and after each
    /// action, and the state digest after each action; or the refusal of a stage event or an action.
    static func replay(_ level: BinaryGardensLevel, actions: [BinaryGardensAction]) -> Replay {
        var play = BinaryGardensPlay(level: level)
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

    /// Whether `action` is an arrangement action of the witness shape on `level`: a ring, phase, luminosity or tilt
    /// setting of star 1 or 2 within the level's ranges, its phase on the level's grid.
    static func isShaped(_ action: BinaryGardensAction, level: BinaryGardensLevel) -> Bool {
        switch action {
        case .ring(let star, let index):
            return (0..<2).contains(star) && level.ringRadii.indices.contains(index)
        case .phase(let star, let step):
            return (0..<2).contains(star) && level.allowsPhase(step)
        case .luminosity(let star, let index):
            return (0..<2).contains(star) && level.luminosityLevels.indices.contains(index)
        case .tilt(let step):
            return (0...level.maxTilt).contains(step)
        case .run:
            return false
        }
    }

    /// Builds a witness from its level, actions and skipped count, checking every part, with the solver's plan.
    private static func build(number: Int, level: BinaryGardensLevel, actions: [BinaryGardensAction],
                              skipped: Int) throws(BinaryGardensError) -> (Self, BinaryGardensPlan) {
        // Provenance, first part: the number names a manifest entry and the level carries its id.
        guard (1...BinaryGardensManifest.entries.count).contains(number),
              level.id == BinaryGardensGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<BinaryGardensGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        // Shape: at least one arrangement action, within the budget, each of the witness shape, followed by exactly
        // one run.
        guard actions.count >= 2, actions.last == .run else { throw .witness("actions") }
        let arrangementActions: [BinaryGardensAction] = Array(actions.dropLast())
        guard arrangementActions.count <= level.budget else { throw .witness("actions") }
        for action in arrangementActions where !isShaped(action, level: level) { throw .witness("actions") }
        // Replay on a fresh play: every action must be accepted and the run must win.
        let play: BinaryGardensPlay
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
        let entry: BinaryGardensManifestEntry = BinaryGardensManifest.entries[number - 1]
        guard entry.number == number, BinaryGardensGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        // The solver's own result: its plan must be exactly these actions, with the band's plan length.
        let length: Int = BinaryGardensBandProfile.of(band: entry.band).plan
        guard let plan = BinaryGardensSolver.plan(level, maxDepth: length), plan.actions == arrangementActions,
              plan.size == length, plan.size >= 1, plan.arrangementsByDepth.count == plan.size else {
            throw .witness("solution")
        }
        let depth: Int = plan.size - 1
        let miss: BinaryGardensReport = BinaryGardensSky.report(level, arrangement: plan.nearestMissArrangement)
        guard let failure = miss.failure else { throw .witness("counterexample") }
        let counterexample = BinaryGardensCounterexample(depth: depth, arrangements: plan.arrangementsByDepth[depth],
                                                         nearestMiss: plan.nearestMiss,
                                                         arrangement: plan.nearestMissArrangement, failure: failure)
        let difficulty = BinaryGardensDifficulty(level: level, plan: plan)
        let report = BinaryGardensWitnessReport(level: level, report: play.report)
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
        do { level = try c.decode(BinaryGardensLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([BinaryGardensAction].self, forKey: .actions)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        report = try c.decode(BinaryGardensWitnessReport.self, forKey: .report)
        counterexample = try c.decode(BinaryGardensCounterexample.self, forKey: .counterexample)
        difficulty = try c.decode(BinaryGardensDifficulty.self, forKey: .difficulty)
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
