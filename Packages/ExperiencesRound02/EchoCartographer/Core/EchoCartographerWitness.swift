// EchoCartographerWitness — feature 402 (R02-G11-02) T-R02G1102-005 (FR-R02G1102-004; SC-R02G1102-003, 005;
// clarifications Q4, Q5). The solver witness of one generated level: the manifest number, the level's stored form, the
// actions (the plan's pulses, then one claim on each beacon's cell in beacon order), the 16-hex echo digest of every
// pulse, the placements fitting after every pulse, the play fingerprints after `begin`, after `dismissTutorial` (when the
// level has a tutorial) and after each action, the counterexample (the first two placements, in enumeration order, that
// fit every pulse but the last), the placements fitting before the last pulse, the difficulty and the candidates
// skipped. The stored form is JSON with sorted keys, pretty-printed, with one trailing newline. Making and decoding both
// rebuild the witness from its level by replaying the actions on a fresh `EchoCartographerPlay` and recounting the
// fitting placements with `EchoCartographerSolver.fitting`; decoding refuses any stored value the rebuild does not
// reproduce and re-runs the solver, refusing a witness whose actions or solver work are not the solver's (feature 382's
// convergence lesson). Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// The replayable proof that a generated Echo Cartographer level is won by its solver's pulse plan, that exactly one
/// beacon placement fits after the plan's pulses and that at least two fit one pulse short (clarification Q4).
public struct EchoCartographerWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: EchoCartographerLevel
    /// The witness actions: the plan's pulses, then one claim on each beacon's cell in beacon order; the last one wins.
    public let actions: [EchoCartographerAction]
    /// The echo digest (``digest(_:)``) of every pulse, in order.
    public let echoDigests: [String]
    /// The placements fitting after every pulse (capped at ``EchoCartographerSolver/placementCap``); the last is 1.
    public let placements: [Int]
    /// The play fingerprints after `begin`, after `dismissTutorial` when the level has a tutorial, and after each
    /// action.
    public let fingerprints: [String]
    /// The first two placements, in enumeration order, that fit every pulse but the last.
    public let counterexample: [[EchoCartographerCell]]
    /// The placements fitting every pulse but the last (capped), at least 2.
    public let placementsBeforeLast: Int
    /// The level's difficulty, with the solver's work.
    public let difficulty: EchoCartographerDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: EchoCartographerLevel, actions: [EchoCartographerAction], echoDigests: [String],
         placements: [Int], fingerprints: [String], counterexample: [[EchoCartographerCell]],
         placementsBeforeLast: Int, difficulty: EchoCartographerDifficulty, skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.echoDigests = echoDigests
        self.placements = placements
        self.fingerprints = fingerprints
        self.counterexample = counterexample
        self.placementsBeforeLast = placementsBeforeLast
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The canonical text of `echo`: `e=<x>,<y>`, then for each ray in order `;<direction>=<distance>,<x>,<y>` (the
    /// wall it entered) or `;<direction>=<distance>,none` (it left the grid), then `;b=` and the beacon distances,
    /// ascending, separated by commas. Example: `e=1,2;north=3,none;east=1,2,2;south=2,1,4;west=2,none;b=1,4`.
    public static func canonicalText(_ echo: EchoCartographerEcho) -> String {
        var text: String = "e=\(echo.emitter.x),\(echo.emitter.y)"
        for ray in echo.rays {
            text += ";\(ray.direction.rawValue)=\(ray.distance),"
            if let wall = ray.wall { text += "\(wall.x),\(wall.y)" } else { text += "none" }
        }
        var distances: [String] = []
        for distance in echo.beaconDistances.sorted() { distances.append(String(distance)) }
        text += ";b=" + distances.joined(separator: ",")
        return text
    }

    /// The echo digest of `echo`: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8 bytes
    /// of ``canonicalText(_:)`` (the emitter, each ray's direction, distance and wall or none, and the sorted beacon
    /// distances).
    public static func digest(_ echo: EchoCartographerEcho) -> String {
        String(StableHash.sha256Hex(Array(canonicalText(echo).utf8)).prefix(16))
    }

    /// The witness of a generated level, built by replaying its actions on a fresh play.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry or a level id that is
    ///   not `echo-cartographer-NNN`), `"skipped"` (outside 0 … 255), `"candidate"` (the level is not candidate
    ///   `skipped` of its manifest entry), `"replay"` (a refused action, no win on the last action, a win or failure
    ///   before it, or no pulse), `"placements"`, `"counterexample"` or `"placements-before-last"` (the recount does
    ///   not reproduce the plan's values) and `"difficulty"` (not the difficulty of the level and plan).
    public static func make(_ generated: EchoCartographerGenerated) throws(EchoCartographerError) -> Self {
        let witness: Self = try build(number: generated.entry.number, level: generated.level,
                                      actions: generated.actions, work: generated.plan.work,
                                      skipped: generated.skipped)
        guard witness.placements == generated.plan.placements else { throw .witness("placements") }
        guard witness.counterexample == generated.plan.counterexample else { throw .witness("counterexample") }
        guard witness.placementsBeforeLast == generated.plan.placementsBeforeLast else {
            throw .witness("placements-before-last")
        }
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
            preconditionFailure("an Echo Cartographer witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the stored actions are replayed on a fresh play, the fitting
    /// placements are recounted over the observations heard so far, the difficulty is recomputed with the stored
    /// solver work, every stored value must equal the rebuilt one, and the solver run again must find the stored
    /// actions, placements, counterexample and work.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.witness("schema")` for a schema below 1;
    ///   `.witness("unreadable")` for damaged JSON, missing keys or values of the wrong type; `.witness("level")` for
    ///   a level the level rules refuse (an edited field breaks its fingerprint); any part ``make(_:)`` names;
    ///   `.witness(part)` with `"echo-digests"`, `"fingerprints"`, `"placements"`, `"counterexample"`,
    ///   `"placements-before-last"` or `"difficulty"` for a stored value the rebuild does not reproduce;
    ///   `.witness("solution")` when the solver, run again on the level, does not find exactly the stored actions and
    ///   values with the stored work.
    public static func decode(_ data: Data) throws(EchoCartographerError) -> Self {
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
        guard rebuilt.echoDigests == stored.echoDigests else { throw .witness("echo-digests") }
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.placements == stored.placements else { throw .witness("placements") }
        guard rebuilt.counterexample == stored.counterexample else { throw .witness("counterexample") }
        guard rebuilt.placementsBeforeLast == stored.placementsBeforeLast else {
            throw .witness("placements-before-last")
        }
        guard rebuilt.difficulty == stored.difficulty else { throw .witness("difficulty") }
        // The solver's own result (feature 382's convergence lesson): the stored actions, counts and work must be what
        // the solver finds on the level, so an edited work count or another identifying plan is refused too.
        guard let plan = EchoCartographerSolver.plan(stored.level),
              EchoCartographerSolver.actions(stored.level, plan: plan) == stored.actions,
              plan.placements == stored.placements, plan.counterexample == stored.counterexample,
              plan.placementsBeforeLast == stored.placementsBeforeLast,
              plan.work == stored.difficulty.work else { throw .witness("solution") }
        return stored
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the play shows a tutorial) and `actions`, each
    /// applied with the current fingerprint: the fingerprint after `begin`, after `dismissTutorial` and after each
    /// action, the echo of each pulse and whether any action before the last found the play no longer playing; nil
    /// when a stage event or an action is refused.
    static func replay(_ level: EchoCartographerLevel, actions: [EchoCartographerAction])
        -> (play: EchoCartographerPlay, fingerprints: [String], echoes: [EchoCartographerEcho], endedEarly: Bool)? {
        var play = EchoCartographerPlay(level: level)
        var fingerprints: [String] = []
        var echoes: [EchoCartographerEcho] = []
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
                if case .pulse = action {
                    guard let echo = play.lastEcho else { return nil }
                    echoes.append(echo)
                }
            }
        } catch {
            return nil
        }
        return (play, fingerprints, echoes, endedEarly)
    }

    /// Builds a witness from its level, actions and solver work, checking every part.
    private static func build(number: Int, level: EchoCartographerLevel, actions: [EchoCartographerAction], work: Int,
                              skipped: Int) throws(EchoCartographerError) -> Self {
        // Provenance: the level is candidate `skipped` of manifest entry `number`.
        guard (1...EchoCartographerManifest.entries.count).contains(number),
              level.id == EchoCartographerGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<EchoCartographerGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        let entry: EchoCartographerManifestEntry = EchoCartographerManifest.entries[number - 1]
        guard entry.number == number, EchoCartographerGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        // Replay on a fresh play: the witness must win on its last action and not before.
        guard !actions.isEmpty, let run = replay(level, actions: actions), run.play.stage == .won, !run.endedEarly,
              !run.echoes.isEmpty else {
            throw .witness("replay")
        }
        // Recount: the placements fitting the observations heard after each pulse.
        var observations: [EchoCartographerObservation] = []
        var placements: [Int] = []
        var digests: [String] = []
        var spent: Int = 0
        for echo in run.echoes {
            observations.append(EchoCartographerObservation(emitter: echo.emitter, echoes: echo.beaconDistances))
            digests.append(digest(echo))
            let count: Int = EchoCartographerSolver.fitting(level, observations: observations,
                                                            cap: EchoCartographerSolver.placementCap,
                                                            work: &spent).count
            placements.append(count)
        }
        guard placements.last == 1 else { throw .witness("placements") }
        // The counterexample: the first two placements fitting every pulse but the last; both fit those pulses.
        let short: [EchoCartographerObservation] = Array(observations.dropLast())
        let before = EchoCartographerSolver.fitting(level, observations: short,
                                                    cap: EchoCartographerSolver.placementCap, work: &spent,
                                                    collect: 2)
        guard before.count >= 2, before.first.count == 2 else { throw .witness("placements-before-last") }
        for placement in before.first {
            guard fits(level, placement: placement, observations: short) else { throw .witness("counterexample") }
        }
        let plan = EchoCartographerPlan(pulses: run.echoes.map(\.emitter), placements: placements,
                                        placementsBeforeLast: before.count, counterexample: before.first, work: work)
        let difficulty = EchoCartographerDifficulty(level: level, plan: plan)
        return Self(number: number, level: level, actions: actions, echoDigests: digests, placements: placements,
                    fingerprints: run.fingerprints, counterexample: before.first,
                    placementsBeforeLast: before.count, difficulty: difficulty, skipped: skipped)
    }

    /// Whether `placement` (beacon-count distinct region cells) fits every observation: for each, the sorted path
    /// lengths from its emitter to the placement's cells equal its echoes.
    static func fits(_ level: EchoCartographerLevel, placement: [EchoCartographerCell],
                     observations: [EchoCartographerObservation]) -> Bool {
        let region: Set<EchoCartographerCell> = Set(EchoCartographerSolver.region(level))
        guard placement.count == level.beacons.count, Set(placement).count == placement.count,
              placement.allSatisfy({ region.contains($0) }) else { return false }
        let chamber: EchoCartographerChamber = level.chamber
        for observation in observations {
            let lengths: [Int?] = chamber.pathLengths(from: observation.emitter)
            var heard: [Int] = []
            for cell in placement {
                guard let length = lengths[chamber.index(cell)] else { return false }
                heard.append(length)
            }
            if heard.sorted() != observation.echoes { return false }
        }
        return true
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, echoDigests, placements, fingerprints, counterexample
        case placementsBeforeLast, difficulty, skipped
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
        do { level = try c.decode(EchoCartographerLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([EchoCartographerAction].self, forKey: .actions)
        echoDigests = try c.decode([String].self, forKey: .echoDigests)
        placements = try c.decode([Int].self, forKey: .placements)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        counterexample = try c.decode([[EchoCartographerCell]].self, forKey: .counterexample)
        placementsBeforeLast = try c.decode(Int.self, forKey: .placementsBeforeLast)
        difficulty = try c.decode(EchoCartographerDifficulty.self, forKey: .difficulty)
        skipped = try c.decode(Int.self, forKey: .skipped)
    }

    /// Encodes the stored form with ``schema``.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(number, forKey: .number)
        try c.encode(level, forKey: .level)
        try c.encode(actions, forKey: .actions)
        try c.encode(echoDigests, forKey: .echoDigests)
        try c.encode(placements, forKey: .placements)
        try c.encode(fingerprints, forKey: .fingerprints)
        try c.encode(counterexample, forKey: .counterexample)
        try c.encode(placementsBeforeLast, forKey: .placementsBeforeLast)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}
