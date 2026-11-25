// CelestialEclipseLabWitness — feature 462 (R02-G17-02) T-R02G1702-005 (FR-R02G1702-004; SC-R02G1702-003, 005;
// clarification Q4), modelled on `StarlitCartoucheWitness` (feature 452). The solver witness of one generated level:
// the manifest number, the level's stored form, the actions (the plan's phase changes in body order, then `run`), the
// 16-hex state digest of the phases and the actions spent after every action, the play fingerprints after `begin`,
// after `dismissTutorial` (when the level has a tutorial) and after each action, the terminal timeline (each interval's
// front, back, first and last tick and visibility class, and the matched count), the counterexample (the depth one
// below the plan and the number of settings the solver judged at exactly that depth, none winning), the difficulty and
// the candidates skipped. The stored form is JSON with sorted keys, pretty-printed, with one trailing newline. Making
// and decoding both rebuild the witness from its level: the actions are replayed on a fresh `CelestialEclipseLabPlay`,
// the level is re-derived as candidate `skipped` of its manifest entry, and the solver is run again on the level,
// whose plan followed by `run` must be exactly the stored actions; the counterexample and the difficulty come from that
// plan. Decoding re-checks the level under `CelestialEclipseLabLevel.decode`'s rules (its `Codable` conformance) and
// refuses any stored value the rebuild does not reproduce. Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// The proof that no plan of one phase change fewer than a witness plan wins (clarification Q4).
///
/// The solver judges every setting reachable with fewer phase changes than the plan, depth by depth, and none won. For
/// a plan of size `s ≥ 1`, ``depth`` is `s − 1` and ``settings`` is the number of settings judged at exactly that depth
/// (`plan.settingsByDepth[s − 1]`); the settings of all smaller depths together are the difficulty's
/// `settingsSearched`.
public struct CelestialEclipseLabCounterexample: Sendable, Hashable, Codable {
    /// The depth one below the plan: the phase changes of the settings refuted.
    public let depth: Int
    /// The settings the solver judged at exactly ``depth``, none winning.
    public let settings: Int

    /// A counterexample of the given values, unchecked.
    public init(depth: Int, settings: Int) {
        self.depth = depth
        self.settings = settings
    }
}

/// One eclipse interval of a witness's terminal timeline, in stored form.
public struct CelestialEclipseLabWitnessInterval: Sendable, Hashable, Codable {
    /// The body in front.
    public let front: Int
    /// The body behind.
    public let back: Int
    /// The first eclipse tick (the event).
    public let first: Int
    /// The last eclipse tick of the run.
    public let last: Int
    /// The deepest visibility class over the run's ticks, stored as its raw value.
    public let visibility: CelestialEclipseLabVisibility

    /// An interval of the given values, unchecked.
    public init(front: Int, back: Int, first: Int, last: Int, visibility: CelestialEclipseLabVisibility) {
        self.front = front
        self.back = back
        self.first = first
        self.last = last
        self.visibility = visibility
    }

    /// The stored form of `interval`.
    public init(_ interval: CelestialEclipseLabInterval) {
        self.init(front: interval.front, back: interval.back, first: interval.first, last: interval.last,
                  visibility: interval.visibility)
    }
}

/// The terminal timeline of a witness: the intervals of the winning setting in timeline order and the matched count.
public struct CelestialEclipseLabWitnessTimeline: Sendable, Hashable, Codable {
    /// The eclipse intervals, ordered by first tick, then front body, then back body.
    public let intervals: [CelestialEclipseLabWitnessInterval]
    /// How many target eclipses the events matched, in order.
    public let matched: Int

    /// A timeline of the given values, unchecked.
    public init(intervals: [CelestialEclipseLabWitnessInterval], matched: Int) {
        self.intervals = intervals
        self.matched = matched
    }

    /// The stored form of `timeline` (its failure is not stored; a witness timeline always wins).
    public init(_ timeline: CelestialEclipseLabTimeline) {
        var intervals: [CelestialEclipseLabWitnessInterval] = []
        for interval in timeline.intervals { intervals.append(CelestialEclipseLabWitnessInterval(interval)) }
        self.init(intervals: intervals, matched: timeline.matched)
    }
}

/// The replayable proof that a generated Celestial Eclipse Lab level is won by its solver's plan within the budget and
/// that no plan of one phase change fewer wins (clarification Q4).
public struct CelestialEclipseLabWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: CelestialEclipseLabLevel
    /// The witness actions: the plan's phase changes in body order, then `run`.
    public let actions: [CelestialEclipseLabAction]
    /// The state digest (``digest(phases:spent:)``) of the play after every action, in order.
    public let digests: [String]
    /// The play fingerprints after `begin`, after `dismissTutorial` when the level has a tutorial, and after each
    /// action.
    public let fingerprints: [String]
    /// The timeline of the play after the run.
    public let timeline: CelestialEclipseLabWitnessTimeline
    /// The proof that one phase change fewer cannot win.
    public let counterexample: CelestialEclipseLabCounterexample
    /// The level's difficulty, with the solver's settings searched and work.
    public let difficulty: CelestialEclipseLabDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: CelestialEclipseLabLevel, actions: [CelestialEclipseLabAction], digests: [String],
         fingerprints: [String], timeline: CelestialEclipseLabWitnessTimeline,
         counterexample: CelestialEclipseLabCounterexample, difficulty: CelestialEclipseLabDifficulty, skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.digests = digests
        self.fingerprints = fingerprints
        self.timeline = timeline
        self.counterexample = counterexample
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The canonical text of a play state: `phases=` with every body's phase in body order joined by `,`, then
    /// `;spent=` and the actions spent. Example: `phases=0,3,5;spent=2`.
    public static func canonicalText(phases: [Int], spent: Int) -> String {
        var values: [String] = []
        for phase in phases { values.append(String(phase)) }
        return "phases=" + values.joined(separator: ",") + ";spent=" + String(spent)
    }

    /// The state digest: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8 bytes of
    /// ``canonicalText(phases:spent:)``.
    public static func digest(phases: [Int], spent: Int) -> String {
        String(StableHash.sha256Hex(Array(canonicalText(phases: phases, spent: spent).utf8)).prefix(16))
    }

    /// The witness of a generated level, built by replaying its plan and the run on a fresh play.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry, an entry that is
    ///   not the manifest's, or a level id that is not `celestial-eclipse-lab-NNN`), `"skipped"` (outside 0 … 255),
    ///   `"actions"` (no phase change, more phase changes than the budget, a phase change of an unknown or fixed body
    ///   or to an offset outside its period, or actions that do not end with exactly one `run`), `"replay"` (a refused
    ///   action or no win on the run), `"candidate"` (the level is not candidate `skipped` of its manifest entry),
    ///   `"solution"` (the solver, run again, does not find exactly these phase changes), `"counterexample"` (the
    ///   plan's settings by depth are not the solver's) and `"difficulty"` (not the difficulty of the level and the
    ///   solver's plan).
    public static func make(_ generated: CelestialEclipseLabGenerated) throws(CelestialEclipseLabError) -> Self {
        guard generated.entry.number >= 1, generated.entry.number <= CelestialEclipseLabManifest.entries.count,
              CelestialEclipseLabManifest.entries[generated.entry.number - 1] == generated.entry else {
            throw .witness("number")
        }
        let (witness, plan): (Self, CelestialEclipseLabPlan) = try build(number: generated.entry.number,
                                                                          level: generated.level,
                                                                          actions: generated.plan.actions + [.run],
                                                                          skipped: generated.skipped)
        guard generated.plan.settingsByDepth == plan.settingsByDepth else { throw .witness("counterexample") }
        guard generated.difficulty == witness.difficulty, generated.plan.work == plan.work else {
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
            preconditionFailure("a Celestial Eclipse Lab witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the level is re-checked under
    /// ``CelestialEclipseLabLevel/decode(_:)``'s rules, the stored actions are replayed on a fresh play, the level is
    /// re-derived from its manifest entry, the solver is run again, and every stored value must equal the rebuilt one.
    ///
    /// - Throws: `.witness("schema s")` for a schema above ``schema`` or below 1; `.witness("unreadable")` for damaged
    ///   JSON, missing keys or values of the wrong type; `.witness("level")` for a level the level rules refuse (an
    ///   edited field breaks its fingerprint); any part ``make(_:)`` names; `.witness(part)` with `"digests"`,
    ///   `"fingerprints"`, `"timeline"`, `"counterexample"` or `"difficulty"` for a stored value the rebuild does not
    ///   reproduce.
    public static func decode(_ data: Data) throws(CelestialEclipseLabError) -> Self {
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
        let (rebuilt, _): (Self, CelestialEclipseLabPlan) = try build(number: stored.number, level: stored.level,
                                                                       actions: stored.actions,
                                                                       skipped: stored.skipped)
        guard rebuilt.digests == stored.digests else { throw .witness("digests") }
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.timeline == stored.timeline else { throw .witness("timeline") }
        guard rebuilt.counterexample == stored.counterexample else { throw .witness("counterexample") }
        guard rebuilt.difficulty == stored.difficulty else { throw .witness("difficulty") }
        return stored
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the play shows a tutorial) and `actions`, each
    /// applied with the current fingerprint: the fingerprint after `begin`, after `dismissTutorial` and after each
    /// action, and the state digest after each action; nil when a stage event or an action is refused.
    static func replay(_ level: CelestialEclipseLabLevel, actions: [CelestialEclipseLabAction])
        -> (play: CelestialEclipseLabPlay, fingerprints: [String], digests: [String])? {
        var play = CelestialEclipseLabPlay(level: level)
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
                digests.append(digest(phases: play.phases, spent: play.actionsSpent))
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests)
    }

    /// Builds a witness from its level, actions and skipped count, checking every part, with the solver's plan.
    private static func build(number: Int, level: CelestialEclipseLabLevel, actions: [CelestialEclipseLabAction],
                              skipped: Int) throws(CelestialEclipseLabError) -> (Self, CelestialEclipseLabPlan) {
        // Provenance, first part: the number names a manifest entry and the level carries its id.
        guard (1...CelestialEclipseLabManifest.entries.count).contains(number),
              level.id == CelestialEclipseLabGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<CelestialEclipseLabGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        // Shape: at least one phase change, within the budget, each of a movable body to an offset in its period,
        // followed by exactly one run.
        guard actions.count >= 2, actions.last == .run else { throw .witness("actions") }
        let changes: [CelestialEclipseLabAction] = Array(actions.dropLast())
        guard changes.count <= level.budget else { throw .witness("actions") }
        for action in changes {
            switch action {
            case .phase(let body, let offset):
                guard body >= 0, body < level.bodies.count, !level.bodies[body].fixed, offset >= 0,
                      offset < level.bodies[body].period else { throw .witness("actions") }
            case .run:
                throw .witness("actions")
            }
        }
        // Replay on a fresh play: the run must win.
        guard let run = replay(level, actions: actions), run.play.stage == .won else { throw .witness("replay") }
        // Provenance, second part: the level is candidate `skipped` of manifest entry `number`.
        let entry: CelestialEclipseLabManifestEntry = CelestialEclipseLabManifest.entries[number - 1]
        guard entry.number == number, CelestialEclipseLabGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        // The solver's own result: its plan must be exactly these phase changes, within the band's range.
        let range: ClosedRange<Int> = CelestialEclipseLabBandProfile.of(band: entry.band).planRange
        guard let plan = CelestialEclipseLabSolver.plan(level, maxChanges: range.upperBound), plan.actions == changes,
              range.contains(plan.size), plan.size >= 1, plan.settingsByDepth.count == plan.size else {
            throw .witness("solution")
        }
        let depth: Int = plan.size - 1
        let counterexample = CelestialEclipseLabCounterexample(depth: depth, settings: plan.settingsByDepth[depth])
        let difficulty = CelestialEclipseLabDifficulty(level: level, plan: plan)
        let timeline = CelestialEclipseLabWitnessTimeline(run.play.timeline)
        let witness = Self(number: number, level: level, actions: actions, digests: run.digests,
                           fingerprints: run.fingerprints, timeline: timeline, counterexample: counterexample,
                           difficulty: difficulty, skipped: skipped)
        return (witness, plan)
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, digests, fingerprints, timeline, counterexample, difficulty, skipped
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
        do { level = try c.decode(CelestialEclipseLabLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([CelestialEclipseLabAction].self, forKey: .actions)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        timeline = try c.decode(CelestialEclipseLabWitnessTimeline.self, forKey: .timeline)
        counterexample = try c.decode(CelestialEclipseLabCounterexample.self, forKey: .counterexample)
        difficulty = try c.decode(CelestialEclipseLabDifficulty.self, forKey: .difficulty)
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
        try c.encode(timeline, forKey: .timeline)
        try c.encode(counterexample, forKey: .counterexample)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}
