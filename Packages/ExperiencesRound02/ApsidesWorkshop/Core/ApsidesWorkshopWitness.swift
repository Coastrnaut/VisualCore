// ApsidesWorkshopWitness — feature 472 (R02-G18-02) T-R02G1802-005 (FR-R02G1802-004; SC-R02G1802-003, 005;
// clarification Q4), on the rule kernel of feature 471 (R02-G18-01), modelled on `CelestialEclipseLabWitness`
// (feature 462). The solver witness of one generated level: the manifest number, the level's stored form, the actions
// (the plan's tunings in their valid order, then `play`), the 16-hex state digest of the orbit and the actions spent
// after every action, the play fingerprints after `begin`, after `dismissTutorial` (when the level has a tutorial) and
// after each action, the terminal report (the eight sector shares, the periapsis sector and distance, the apoapsis
// sector and distance, the largest Kepler residual, each target's deviation and the met count), the counterexample (the
// depth one below the plan and the number of orbits the solver judged at exactly that depth, none winning), the
// difficulty and the candidates skipped. The stored form is JSON with sorted keys, pretty-printed, with one trailing
// newline. Making and decoding both rebuild the witness from its level: the actions are replayed on a fresh
// `ApsidesWorkshopPlay`, the level is re-derived as candidate `skipped` of its manifest entry, and the solver is run
// again on the level, whose plan followed by `play` must be exactly the stored actions; the counterexample and the
// difficulty come from that plan. Decoding re-checks the level under `ApsidesWorkshopLevel.decode`'s rules (its
// `Codable` conformance) and refuses any stored value the rebuild does not reproduce. Integers only; no clock, no
// random source.
import Foundation
import VisualCoreMath

/// The proof that no plan of one tuning fewer than a witness plan wins (clarification Q4).
///
/// The solver judges every orbit reachable with fewer tunings than the plan, depth by depth, and none won. For a plan
/// of size `s ≥ 1`, ``depth`` is `s − 1` and ``orbits`` is the number of orbits judged at exactly that depth
/// (`plan.orbitsByDepth[s − 1]`; depth 0 is the start alone, 1 orbit); the orbits of all smaller depths together are
/// the difficulty's `orbitsSearched`.
public struct ApsidesWorkshopCounterexample: Sendable, Hashable, Codable {
    /// The depth one below the plan: the tunings of the orbits refuted.
    public let depth: Int
    /// The orbits the solver judged at exactly ``depth``, none winning.
    public let orbits: Int

    /// A counterexample of the given values, unchecked.
    public init(depth: Int, orbits: Int) {
        self.depth = depth
        self.orbits = orbits
    }
}

/// The terminal report of a witness: the winning orbit's readings after the play, in stored form.
public struct ApsidesWorkshopWitnessReport: Sendable, Hashable, Codable {
    /// The share of each sector 0 … 7 in tenths of a percent (rounded down).
    public let shares: [Int]
    /// The periapsis sector, 0 … 7.
    public let periapsisSector: Int
    /// The periapsis distance in twentieths of a lattice unit.
    public let periapsisDistance: Int
    /// The apoapsis sector, 0 … 7.
    public let apoapsisSector: Int
    /// The apoapsis distance in twentieths of a lattice unit.
    public let apoapsisDistance: Int
    /// The largest Kepler residual over the revolution (fixed point, 2^30 as one).
    public let largestResidual: Int64
    /// Each target's deviation (0 for every target of a winning orbit).
    public let deviations: [Int]
    /// The targets met in order (all of them on a win).
    public let met: Int

    /// A report of the given values, unchecked.
    public init(shares: [Int], periapsisSector: Int, periapsisDistance: Int, apoapsisSector: Int,
                apoapsisDistance: Int, largestResidual: Int64, deviations: [Int], met: Int) {
        self.shares = shares
        self.periapsisSector = periapsisSector
        self.periapsisDistance = periapsisDistance
        self.apoapsisSector = apoapsisSector
        self.apoapsisDistance = apoapsisDistance
        self.largestResidual = largestResidual
        self.deviations = deviations
        self.met = met
    }

    /// The stored form of `report` for `orbit` (its positions, event ticks and failure are not stored; a witness
    /// report always wins).
    public init(_ report: ApsidesWorkshopReport, orbit: ApsidesWorkshopOrbit) {
        self.init(shares: report.shares, periapsisSector: orbit.periapsisSector,
                  periapsisDistance: orbit.periapsisDistance, apoapsisSector: orbit.apoapsisSector,
                  apoapsisDistance: orbit.apoapsisDistance, largestResidual: report.largestResidual,
                  deviations: report.deviations, met: report.met)
    }
}

/// The replayable proof that a generated Apsides Workshop level is won by its solver's plan within the budget and
/// that no plan of one tuning fewer wins (clarification Q4).
public struct ApsidesWorkshopWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: ApsidesWorkshopLevel
    /// The witness actions: the plan's tunings in their valid order, then `play`.
    public let actions: [ApsidesWorkshopAction]
    /// The state digest (``digest(orbit:spent:)``) of the play after every action, in order.
    public let digests: [String]
    /// The play fingerprints after `begin`, after `dismissTutorial` when the level has a tutorial, and after each
    /// action.
    public let fingerprints: [String]
    /// The report of the play after the `play`.
    public let report: ApsidesWorkshopWitnessReport
    /// The proof that one tuning fewer cannot win.
    public let counterexample: ApsidesWorkshopCounterexample
    /// The level's difficulty, with the solver's orbits searched and work.
    public let difficulty: ApsidesWorkshopDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: ApsidesWorkshopLevel, actions: [ApsidesWorkshopAction], digests: [String],
         fingerprints: [String], report: ApsidesWorkshopWitnessReport, counterexample: ApsidesWorkshopCounterexample,
         difficulty: ApsidesWorkshopDifficulty, skipped: Int) {
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

    /// The canonical text of a play state: `orbit=` with the size, the eccentricity step and the direction step
    /// joined by `,`, then `;spent=` and the actions spent. Example: `orbit=24,5,6;spent=2`.
    public static func canonicalText(orbit: ApsidesWorkshopOrbit, spent: Int) -> String {
        "orbit=" + String(orbit.size) + "," + String(orbit.eccentricity) + "," + String(orbit.direction)
            + ";spent=" + String(spent)
    }

    /// The state digest: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8 bytes of
    /// ``canonicalText(orbit:spent:)``.
    public static func digest(orbit: ApsidesWorkshopOrbit, spent: Int) -> String {
        String(StableHash.sha256Hex(Array(canonicalText(orbit: orbit, spent: spent).utf8)).prefix(16))
    }

    /// The witness of a generated level, built by replaying its plan and the play on a fresh play.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry, an entry that is
    ///   not the manifest's, or a level id that is not `apsides-workshop-NNN`), `"skipped"` (outside 0 … 255),
    ///   `"actions"` (no tuning, more tunings than the budget, a tuning step out of range, or actions that do not end
    ///   with exactly one `play`), `"replay"` (a refused action or no win on the play), `"candidate"` (the level is
    ///   not candidate `skipped` of its manifest entry), `"solution"` (the solver, run again, does not find exactly
    ///   these tunings within the band's plan range), `"counterexample"` (the plan's orbits by depth are not the
    ///   solver's) and `"difficulty"` (not the difficulty of the level and the solver's plan, or another work).
    public static func make(_ generated: ApsidesWorkshopGenerated) throws(ApsidesWorkshopError) -> Self {
        guard generated.entry.number >= 1, generated.entry.number <= ApsidesWorkshopManifest.entries.count,
              ApsidesWorkshopManifest.entries[generated.entry.number - 1] == generated.entry else {
            throw .witness("number")
        }
        let (witness, plan): (Self, ApsidesWorkshopPlan) = try build(number: generated.entry.number,
                                                                     level: generated.level,
                                                                     actions: generated.plan.actions + [.play],
                                                                     skipped: generated.skipped)
        guard generated.plan.orbitsByDepth == plan.orbitsByDepth else { throw .witness("counterexample") }
        guard generated.difficulty == witness.difficulty, generated.plan.work == plan.work,
              generated.plan.orbit == plan.orbit else {
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
            preconditionFailure("an Apsides Workshop witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the level is re-checked under ``ApsidesWorkshopLevel/decode(_:)``'s
    /// rules, the stored actions are replayed on a fresh play, the level is re-derived from its manifest entry, the
    /// solver is run again, and every stored value must equal the rebuilt one.
    ///
    /// - Throws: `.witness("schema s")` for a schema above ``schema`` or below 1; `.witness("unreadable")` for damaged
    ///   JSON, missing keys or values of the wrong type; `.witness("level")` for a level the level rules refuse (an
    ///   edited field breaks its fingerprint); any part ``make(_:)`` names; `.witness(part)` with `"digests"`,
    ///   `"fingerprints"`, `"report"`, `"counterexample"` or `"difficulty"` for a stored value the rebuild does not
    ///   reproduce.
    public static func decode(_ data: Data) throws(ApsidesWorkshopError) -> Self {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .witness("unreadable") }
        guard (1...schema).contains(probe.schema) else { throw .witness("schema \(probe.schema)") }
        let stored: Self
        do {
            stored = try JSONDecoder().decode(Self.self, from: data)
        } catch is LevelRefusal {
            throw .witness("level")
        } catch {
            throw .witness("unreadable")
        }
        let (rebuilt, _): (Self, ApsidesWorkshopPlan) = try build(number: stored.number, level: stored.level,
                                                                  actions: stored.actions, skipped: stored.skipped)
        guard rebuilt.digests == stored.digests else { throw .witness("digests") }
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.report == stored.report else { throw .witness("report") }
        guard rebuilt.counterexample == stored.counterexample else { throw .witness("counterexample") }
        guard rebuilt.difficulty == stored.difficulty else { throw .witness("difficulty") }
        return stored
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the play shows a tutorial) and `actions`, each
    /// applied with the current fingerprint: the fingerprint after `begin`, after `dismissTutorial` and after each
    /// action, and the state digest after each action; nil when a stage event or an action is refused.
    static func replay(_ level: ApsidesWorkshopLevel, actions: [ApsidesWorkshopAction])
        -> (play: ApsidesWorkshopPlay, fingerprints: [String], digests: [String])? {
        var play = ApsidesWorkshopPlay(level: level)
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
                digests.append(digest(orbit: play.orbit, spent: play.actionsSpent))
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests)
    }

    /// Builds a witness from its level, actions and skipped count, checking every part, with the solver's plan.
    private static func build(number: Int, level: ApsidesWorkshopLevel, actions: [ApsidesWorkshopAction],
                              skipped: Int) throws(ApsidesWorkshopError) -> (Self, ApsidesWorkshopPlan) {
        // Provenance, first part: the number names a manifest entry and the level carries its id.
        guard (1...ApsidesWorkshopManifest.entries.count).contains(number),
              level.id == ApsidesWorkshopGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<ApsidesWorkshopGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        // Shape: at least one tuning, within the budget, each with its steps in range, followed by exactly one play.
        guard actions.count >= 2, actions.last == .play else { throw .witness("actions") }
        let tunings: [ApsidesWorkshopAction] = Array(actions.dropLast())
        guard tunings.count <= level.budget else { throw .witness("actions") }
        for action in tunings {
            switch action {
            case .periapsis(let eccentricity, let direction):
                guard ApsidesWorkshopOrbit.eccentricities.contains(eccentricity),
                      ApsidesWorkshopOrbit.directions.contains(direction) else { throw .witness("actions") }
            case .size(let size):
                guard ApsidesWorkshopOrbit.sizes.contains(size) else { throw .witness("actions") }
            case .play:
                throw .witness("actions")
            }
        }
        // Replay on a fresh play: the play must win.
        guard let run = replay(level, actions: actions), run.play.stage == .won else { throw .witness("replay") }
        // Provenance, second part: the level is candidate `skipped` of manifest entry `number`.
        let entry: ApsidesWorkshopManifestEntry = ApsidesWorkshopManifest.entries[number - 1]
        guard entry.number == number, ApsidesWorkshopGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        // The solver's own result: its plan must be exactly these tunings, to the replayed orbit, within the band's
        // plan range.
        let range: ClosedRange<Int> = ApsidesWorkshopBandProfile.of(band: entry.band).planRange
        guard let plan = ApsidesWorkshopSolver.plan(level), plan.actions == tunings, plan.orbit == run.play.orbit,
              range.contains(plan.size), plan.size >= 1, plan.orbitsByDepth.count == plan.size else {
            throw .witness("solution")
        }
        let depth: Int = plan.size - 1
        let counterexample = ApsidesWorkshopCounterexample(depth: depth, orbits: plan.orbitsByDepth[depth])
        let difficulty = ApsidesWorkshopDifficulty(level: level, plan: plan)
        let report = ApsidesWorkshopWitnessReport(run.play.report, orbit: run.play.orbit)
        let witness = Self(number: number, level: level, actions: actions, digests: run.digests,
                           fingerprints: run.fingerprints, report: report, counterexample: counterexample,
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
        do { level = try c.decode(ApsidesWorkshopLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([ApsidesWorkshopAction].self, forKey: .actions)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        report = try c.decode(ApsidesWorkshopWitnessReport.self, forKey: .report)
        counterexample = try c.decode(ApsidesWorkshopCounterexample.self, forKey: .counterexample)
        difficulty = try c.decode(ApsidesWorkshopDifficulty.self, forKey: .difficulty)
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
