// MicroscopicAuroraWitness — feature 482 (R02-G19-02) T-R02G1902-005 (FR-R02G1902-004; SC-R02G1902-003, 005;
// clarification Q4), on the rule kernel of feature 481 (R02-G19-01), modelled on `ApsidesWorkshopWitness` (feature
// 472). The solver witness of one generated level: the manifest number, the level's stored form (with its sites), the
// actions (the plan's placements in slot order, then `play`), the 16-hex state digest of the wells and the actions
// spent after every action, the play fingerprints after `begin`, after `dismissTutorial` (when the level has a
// tutorial) and after each action, the terminal report (the lit stencil cells, the coverage, the group count, the
// smallest coherence and its tick, the ticks swum), the counterexample (the depth one below the plan, the number of
// well sets the solver judged at exactly that depth, none winning, and the nearest miss), the difficulty and the
// candidates skipped. The stored form is JSON with sorted keys, pretty-printed, with one trailing newline. Making and
// decoding both rebuild the witness from its level: the actions are replayed on a fresh `MicroscopicAuroraPlay`, the
// level is re-derived as candidate `skipped` of its manifest entry, and the solver is run again on the level, whose
// plan followed by `play` must be exactly the stored actions; the counterexample and the difficulty come from that
// plan. Decoding re-checks the level under `MicroscopicAuroraLevel.decode`'s rules (its `Codable` conformance) and
// refuses any stored value the rebuild does not reproduce. Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// The proof that no setting of one placement fewer than a witness plan wins (clarification Q4).
///
/// The solver judges every set of wells on distinct sites smaller than the plan, depth by depth, and none won. For a
/// plan of size `s ≥ 1`, ``depth`` is `s − 1`, ``sets`` is the number of sets judged at exactly that depth
/// (`plan.setsByDepth[s − 1]`; depth 0 is no well, 1 set) and ``nearestMiss`` is the smallest shape loss among all
/// the sets judged at smaller depths (`plan.nearestMiss`).
public struct MicroscopicAuroraCounterexample: Sendable, Hashable, Codable {
    /// The depth one below the plan: the wells of the sets refuted.
    public let depth: Int
    /// The sets the solver judged at exactly ``depth``, none winning.
    public let sets: Int
    /// The smallest shape loss among the sets judged below the plan.
    public let nearestMiss: Int

    /// A counterexample of the given values, unchecked.
    public init(depth: Int, sets: Int, nearestMiss: Int) {
        self.depth = depth
        self.sets = sets
        self.nearestMiss = nearestMiss
    }
}

/// The terminal report of a witness: the winning swim's readings after the play, in stored form.
public struct MicroscopicAuroraWitnessReport: Sendable, Hashable, Codable {
    /// The stencil cells lit at the level's threshold, in the report's order.
    public let litStencil: [MicroscopicAuroraCell]
    /// The stencil coverage in tenths of a percent.
    public let coverage: Int
    /// The four-neighbour groups of the lit stencil cells (1 on a win).
    public let groups: Int
    /// The smallest largest-linked-group size of the swarm over the swim.
    public let smallestCoherence: Int
    /// The tick of ``smallestCoherence``.
    public let smallestCoherenceTick: Int
    /// The ticks swum.
    public let ticks: Int

    /// A report of the given values, unchecked.
    public init(litStencil: [MicroscopicAuroraCell], coverage: Int, groups: Int, smallestCoherence: Int,
                smallestCoherenceTick: Int, ticks: Int) {
        self.litStencil = litStencil
        self.coverage = coverage
        self.groups = groups
        self.smallestCoherence = smallestCoherence
        self.smallestCoherenceTick = smallestCoherenceTick
        self.ticks = ticks
    }

    /// The stored form of `report` (its density, final swimmers and failure are not stored; a witness report always
    /// wins).
    public init(_ report: MicroscopicAuroraReport) {
        self.init(litStencil: report.litStencil, coverage: report.coverage, groups: report.groups,
                  smallestCoherence: report.smallestCoherence, smallestCoherenceTick: report.smallestCoherenceTick,
                  ticks: report.ticks)
    }
}

/// The replayable proof that a generated Microscopic Aurora level is won by its solver's plan within the budget and
/// that no setting of one placement fewer wins (clarification Q4).
public struct MicroscopicAuroraWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form with its sites.
    public let level: MicroscopicAuroraLevel
    /// The witness actions: the plan's placements in slot order, then `play`.
    public let actions: [MicroscopicAuroraAction]
    /// The state digest (``digest(wells:spent:)``) of the play after every action, in order.
    public let digests: [String]
    /// The play fingerprints after `begin`, after `dismissTutorial` when the level has a tutorial, and after each
    /// action.
    public let fingerprints: [String]
    /// The report of the play after the `play`.
    public let report: MicroscopicAuroraWitnessReport
    /// The proof that one placement fewer cannot win.
    public let counterexample: MicroscopicAuroraCounterexample
    /// The level's difficulty, with the solver's sets searched, work and nearest miss.
    public let difficulty: MicroscopicAuroraDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: MicroscopicAuroraLevel, actions: [MicroscopicAuroraAction], digests: [String],
         fingerprints: [String], report: MicroscopicAuroraWitnessReport,
         counterexample: MicroscopicAuroraCounterexample, difficulty: MicroscopicAuroraDifficulty, skipped: Int) {
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

    /// The canonical text of a play state: `wells=` with the slots in order joined by `,`, each `row column strength
    /// sense` (single spaces, the sense's raw value) or `none`, then `;spent=` and the actions spent. Example:
    /// `wells=9 14 3 clockwise,none,none;spent=1`.
    public static func canonicalText(wells: [MicroscopicAuroraWell?], spent: Int) -> String {
        var slots: [String] = []
        for slot in wells {
            if let well = slot {
                slots.append(String(well.cell.row) + " " + String(well.cell.column) + " " + String(well.strength)
                             + " " + well.sense.rawValue)
            } else {
                slots.append("none")
            }
        }
        return "wells=" + slots.joined(separator: ",") + ";spent=" + String(spent)
    }

    /// The state digest: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8 bytes of
    /// ``canonicalText(wells:spent:)``.
    public static func digest(wells: [MicroscopicAuroraWell?], spent: Int) -> String {
        String(StableHash.sha256Hex(Array(canonicalText(wells: wells, spent: spent).utf8)).prefix(16))
    }

    /// The witness of a generated level, built by replaying its plan and the play on a fresh play.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry, an entry that is
    ///   not the manifest's, or a level id that is not `microscopic-aurora-NNN`), `"skipped"` (outside 0 … 63),
    ///   `"actions"` (no placement, more placements than the budget, an action that is not a placement into slot
    ///   0 … 2 of a well on one of the level's sites with a strength 1 … 4, or actions that do not end with exactly
    ///   one `play`), `"replay"` (a refused action or no win on the play), `"candidate"` (the level is not candidate
    ///   `skipped` of its manifest entry), `"solution"` (the solver, run again, does not find exactly these
    ///   placements with the band's plan length), `"counterexample"` (the plan's sets by depth or nearest miss are not
    ///   the solver's) and `"difficulty"` (not the difficulty of the level and the solver's plan, another work or
    ///   other wells).
    public static func make(_ generated: MicroscopicAuroraGenerated) throws(MicroscopicAuroraError) -> Self {
        guard generated.entry.number >= 1, generated.entry.number <= MicroscopicAuroraManifest.entries.count,
              MicroscopicAuroraManifest.entries[generated.entry.number - 1] == generated.entry else {
            throw .witness("number")
        }
        let (witness, plan): (Self, MicroscopicAuroraPlan) = try build(number: generated.entry.number,
                                                                       level: generated.level,
                                                                       actions: generated.plan.actions + [.play],
                                                                       skipped: generated.skipped)
        guard generated.plan.setsByDepth == plan.setsByDepth, generated.plan.nearestMiss == plan.nearestMiss else {
            throw .witness("counterexample")
        }
        guard generated.difficulty == witness.difficulty, generated.plan.work == plan.work,
              generated.plan.wells == plan.wells else {
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
            preconditionFailure("a Microscopic Aurora witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the level is re-checked under
    /// ``MicroscopicAuroraLevel/decode(_:)``'s rules, the stored actions are replayed on a fresh play, the level is
    /// re-derived from its manifest entry, the solver is run again, and every stored value must equal the rebuilt one.
    ///
    /// - Throws: `.witness("schema s")` for a schema above ``schema`` or below 1; `.witness("unreadable")` for damaged
    ///   JSON, missing keys or values of the wrong type; `.witness("level")` for a level the level rules refuse (an
    ///   edited field breaks its fingerprint); any part ``make(_:)`` names; `.witness(part)` with `"digests"`,
    ///   `"fingerprints"`, `"report"`, `"counterexample"` or `"difficulty"` for a stored value the rebuild does not
    ///   reproduce.
    public static func decode(_ data: Data) throws(MicroscopicAuroraError) -> Self {
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
        let (rebuilt, _): (Self, MicroscopicAuroraPlan) = try build(number: stored.number, level: stored.level,
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
    static func replay(_ level: MicroscopicAuroraLevel, actions: [MicroscopicAuroraAction])
        -> (play: MicroscopicAuroraPlay, fingerprints: [String], digests: [String])? {
        var play = MicroscopicAuroraPlay(level: level)
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
                digests.append(digest(wells: play.wells, spent: play.actionsSpent))
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests)
    }

    /// Builds a witness from its level, actions and skipped count, checking every part, with the solver's plan.
    private static func build(number: Int, level: MicroscopicAuroraLevel, actions: [MicroscopicAuroraAction],
                              skipped: Int) throws(MicroscopicAuroraError) -> (Self, MicroscopicAuroraPlan) {
        // Provenance, first part: the number names a manifest entry and the level carries its id.
        guard (1...MicroscopicAuroraManifest.entries.count).contains(number),
              level.id == MicroscopicAuroraGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<MicroscopicAuroraGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        // Shape: at least one placement, within the budget, each into a slot on a site with a strength in range,
        // followed by exactly one play.
        guard actions.count >= 2, actions.last == .play else { throw .witness("actions") }
        let placements: [MicroscopicAuroraAction] = Array(actions.dropLast())
        guard placements.count <= level.budget else { throw .witness("actions") }
        let sites: [MicroscopicAuroraCell] = level.sites ?? []
        for action in placements {
            switch action {
            case .place(let slot, let well):
                guard (0..<MicroscopicAuroraLevel.slots).contains(slot),
                      MicroscopicAuroraWell.strengths.contains(well.strength),
                      sites.contains(well.cell) else { throw .witness("actions") }
            case .remove, .play:
                throw .witness("actions")
            }
        }
        // Replay on a fresh play: the play must win.
        guard let run = replay(level, actions: actions), run.play.stage == .won else { throw .witness("replay") }
        // Provenance, second part: the level is candidate `skipped` of manifest entry `number`.
        let entry: MicroscopicAuroraManifestEntry = MicroscopicAuroraManifest.entries[number - 1]
        guard entry.number == number, MicroscopicAuroraGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        // The solver's own result: its plan must be exactly these placements, with the band's plan length.
        let length: Int = MicroscopicAuroraBandProfile.of(band: entry.band).plan
        guard let plan = MicroscopicAuroraSolver.plan(level), plan.actions == placements, plan.size == length,
              plan.size >= 1, plan.setsByDepth.count == plan.size else {
            throw .witness("solution")
        }
        let depth: Int = plan.size - 1
        let counterexample = MicroscopicAuroraCounterexample(depth: depth, sets: plan.setsByDepth[depth],
                                                             nearestMiss: plan.nearestMiss)
        let difficulty = MicroscopicAuroraDifficulty(level: level, plan: plan)
        let report = MicroscopicAuroraWitnessReport(run.play.report)
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
        do { level = try c.decode(MicroscopicAuroraLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([MicroscopicAuroraAction].self, forKey: .actions)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        report = try c.decode(MicroscopicAuroraWitnessReport.self, forKey: .report)
        counterexample = try c.decode(MicroscopicAuroraCounterexample.self, forKey: .counterexample)
        difficulty = try c.decode(MicroscopicAuroraDifficulty.self, forKey: .difficulty)
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
