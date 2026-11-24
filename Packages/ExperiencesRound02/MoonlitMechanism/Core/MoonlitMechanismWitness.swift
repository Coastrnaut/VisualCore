// MoonlitMechanismWitness — feature 432 (R02-G14-02) T-R02G1402-005 (FR-R02G1402-004; SC-R02G1402-003, 005;
// clarification Q4). The solver witness of one generated level: the manifest number, the level's stored form, the
// actions (the plan's |t| turns, then each gear's |rᵢ| re-seats in gear order, then its |h| lamp steps, then one run),
// the 16-hex state digest of the play's phases and lamp height after every action, the play fingerprints after
// `begin`, after `dismissTutorial` (when the level has a tutorial) and after each action, the counterexample (the norm
// one below the plan and the number of vectors of that norm the solver tried, none winning), the difficulty and the
// candidates skipped. The stored form is JSON with sorted keys, pretty-printed, with one trailing newline. Making and
// decoding both rebuild the witness from its level by replaying the actions on a fresh `MoonlitMechanismPlay` and
// recounting the vectors of every smaller norm in closed form; decoding refuses any stored value the rebuild does not
// reproduce and re-runs the solver, refusing a witness whose actions, smaller vectors or solver work are not the
// solver's (feature 382's convergence lesson). Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// The proof that no plan of one action fewer than a witness plan wins (clarification Q4).
///
/// A plan is a vector (t, h, r₁ … rₙ₋₁) of dimension `gears + 1` and its length is the vector's L1 norm. The solver
/// tries every vector of norm 0, 1, 2, … in a fixed order and counts each one it tries (a vector whose lamp height
/// leaves the range or that leaves a mesh misaligned counts as tried and lost without a run), so the vectors it tried
/// at norm c are exactly the integer vectors of that dimension with L1 norm c (``MoonlitMechanismWitness/vectors(dimensions:norm:)``).
/// For a plan of size `s ≥ 1`, ``norm`` is `s − 1` and ``vectors`` is the count at that norm, none winning; the
/// vectors of all norms below `s` together are the difficulty's `smallerVectors`. A plan of size 0 (a start that
/// already wins) has no witness: the generator never certifies one and ``MoonlitMechanismWitness/make(_:)`` refuses
/// it (`"actions"`).
public struct MoonlitMechanismCounterexample: Sendable, Hashable, Codable {
    /// The norm one below the plan: the actions (before the run) of the vectors refuted.
    public let norm: Int
    /// The vectors of ``norm`` the solver tried, none winning.
    public let vectors: Int

    /// A counterexample of the given values, unchecked.
    public init(norm: Int, vectors: Int) {
        self.norm = norm
        self.vectors = vectors
    }
}

/// The replayable proof that a generated Moonlit Mechanism level is won by its solver's plan and that no plan of one
/// action fewer wins (clarification Q4).
public struct MoonlitMechanismWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: MoonlitMechanismLevel
    /// The witness actions: the plan's turns, its re-seats in gear order, its lamp steps, then one run, which wins.
    public let actions: [MoonlitMechanismAction]
    /// The state digest (``digest(phases:height:)``) of the play's phases and lamp height after every action, in order.
    public let digests: [String]
    /// The play fingerprints after `begin`, after `dismissTutorial` when the level has a tutorial, and after each
    /// action.
    public let fingerprints: [String]
    /// The proof that one action fewer cannot win.
    public let counterexample: MoonlitMechanismCounterexample
    /// The level's difficulty, with the solver's smaller vectors and work.
    public let difficulty: MoonlitMechanismDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: MoonlitMechanismLevel, actions: [MoonlitMechanismAction], digests: [String],
         fingerprints: [String], counterexample: MoonlitMechanismCounterexample,
         difficulty: MoonlitMechanismDifficulty, skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.digests = digests
        self.fingerprints = fingerprints
        self.counterexample = counterexample
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The canonical text of a state: `phases=` and the phases in gear order joined by `,`, then `;height=` and the
    /// lamp height. Example: `phases=3,0,11;height=2`.
    public static func canonicalText(phases: [Int], height: Int) -> String {
        var values: [String] = []
        for phase in phases { values.append(String(phase)) }
        return "phases=" + values.joined(separator: ",") + ";height=" + String(height)
    }

    /// The state digest: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8 bytes of
    /// ``canonicalText(phases:height:)`` (the phases and the lamp height).
    public static func digest(phases: [Int], height: Int) -> String {
        String(StableHash.sha256Hex(Array(canonicalText(phases: phases, height: height).utf8)).prefix(16))
    }

    /// The number of integer vectors of `dimensions` coordinates whose L1 norm is exactly `norm`: the vectors the
    /// solver tries at that norm.
    ///
    /// A vector of norm c ≥ 1 with exactly k non-zero coordinates picks those k of the `dimensions` positions
    /// (C(d, k)), splits c into k positive magnitudes (C(c − 1, k − 1)) and gives each a sign (2ᵏ), so the count is
    /// Σₖ₌₁^min(d, c) 2ᵏ · C(d, k) · C(c − 1, k − 1); norm 0 has the one zero vector; a negative norm or no dimension
    /// has none (except norm 0).
    public static func vectors(dimensions: Int, norm: Int) -> Int {
        guard norm >= 0, dimensions >= 0 else { return 0 }
        if norm == 0 { return 1 }
        var total: Int = 0
        var k: Int = 1
        while k <= min(dimensions, norm) {
            total += (1 << k) * binomial(dimensions, k) * binomial(norm - 1, k - 1)
            k += 1
        }
        return total
    }

    /// The witness of a generated level, built by replaying its actions on a fresh play.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry, an entry that is
    ///   not the manifest's, or a level id that is not `moonlit-mechanism-NNN`), `"skipped"` (outside 0 … 255),
    ///   `"actions"` (not the solver's action order for some plan vector of size 1 or more — turns of one sign, then
    ///   re-seats of one sign per gear in gear order, never the driver, then lamp steps of one sign, all ±1 — followed
    ///   by one run), `"replay"` (a refused action, no win on the last action or a win or failure before it),
    ///   `"candidate"` (the level is not candidate `skipped` of its manifest entry), `"counterexample"` (the plan's
    ///   `smallerVectors` is not the count of every vector of a smaller norm) and `"difficulty"` (not the difficulty
    ///   of the level and plan).
    public static func make(_ generated: MoonlitMechanismGenerated) throws(MoonlitMechanismError) -> Self {
        guard generated.entry.number >= 1, generated.entry.number <= MoonlitMechanismManifest.entries.count,
              MoonlitMechanismManifest.entries[generated.entry.number - 1] == generated.entry else {
            throw .witness("number")
        }
        let witness: Self = try build(number: generated.entry.number, level: generated.level,
                                      actions: generated.actions, work: generated.plan.work,
                                      skipped: generated.skipped)
        guard witness.difficulty.smallerVectors == generated.plan.smallerVectors else {
            throw .witness("counterexample")
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
            preconditionFailure("a Moonlit Mechanism witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the stored actions are replayed on a fresh play, the vectors of
    /// every smaller norm are recounted, the difficulty is recomputed with the stored solver work, every stored value
    /// must equal the rebuilt one, and the solver run again must find the stored actions, smaller vectors and work.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.witness("schema")` for a schema below 1;
    ///   `.witness("unreadable")` for damaged JSON, missing keys or values of the wrong type; `.witness("level")` for
    ///   a level the level rules refuse (an edited field breaks its fingerprint); any part ``make(_:)`` names;
    ///   `.witness(part)` with `"digests"`, `"fingerprints"`, `"counterexample"` or `"difficulty"` for a stored value
    ///   the rebuild does not reproduce; `.witness("solution")` when the solver, run again on the level, does not find
    ///   exactly the stored actions with the stored smaller vectors and work.
    public static func decode(_ data: Data) throws(MoonlitMechanismError) -> Self {
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
        guard rebuilt.digests == stored.digests else { throw .witness("digests") }
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.counterexample == stored.counterexample else { throw .witness("counterexample") }
        guard rebuilt.difficulty == stored.difficulty else { throw .witness("difficulty") }
        // The solver's own result (feature 382's convergence lesson): another winning plan of the same size or an
        // edited work count is refused too.
        let range: ClosedRange<Int> = MoonlitMechanismBandProfile.of(band: stored.level.difficulty).planRange
        guard let plan = MoonlitMechanismSolver.plan(stored.level, maxActions: range.upperBound),
              MoonlitMechanismSolver.actions(plan) == stored.actions,
              plan.smallerVectors == stored.difficulty.smallerVectors,
              plan.work == stored.difficulty.work else { throw .witness("solution") }
        return stored
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the play shows a tutorial) and `actions`, each
    /// applied with the current fingerprint: the fingerprint after `begin`, after `dismissTutorial` and after each
    /// action, the state digest after each action and whether any action before the last found the play no longer
    /// playing; nil when a stage event or an action is refused.
    static func replay(_ level: MoonlitMechanismLevel, actions: [MoonlitMechanismAction])
        -> (play: MoonlitMechanismPlay, fingerprints: [String], digests: [String], endedEarly: Bool)? {
        var play = MoonlitMechanismPlay(level: level)
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
                digests.append(digest(phases: play.phases, height: play.height))
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests, endedEarly)
    }

    /// The plan vector of `actions` (net turns, lamp steps and re-seats of a level of `gears` gears), or nil when an
    /// action other than the last is a run, the last is not a run, a step is not ±1, a re-seat names the driver or an
    /// unknown gear, or the actions are not exactly ``MoonlitMechanismSolver/actions(_:)`` of that vector.
    static func vector(_ actions: [MoonlitMechanismAction], gears: Int)
        -> (turns: Int, lamp: Int, reseats: [Int])? {
        guard gears >= 1, let last = actions.last, last == .run else { return nil }
        var turns: Int = 0
        var lamp: Int = 0
        var reseats: [Int] = Array(repeating: 0, count: gears)
        for action in actions.dropLast() {
            switch action {
            case .turn(let step):
                guard step == 1 || step == -1 else { return nil }
                turns += step
            case .reseat(let gear, let step):
                guard gear >= 1, gear < gears, step == 1 || step == -1 else { return nil }
                reseats[gear] += step
            case .lamp(let step):
                guard step == 1 || step == -1 else { return nil }
                lamp += step
            case .run:
                return nil
            }
        }
        let plan = MoonlitMechanismPlan(turns: turns, lamp: lamp, reseats: reseats, smallerVectors: 0, work: 0)
        guard MoonlitMechanismSolver.actions(plan) == actions else { return nil }
        return (turns, lamp, reseats)
    }

    /// Builds a witness from its level, actions and solver work, checking every part.
    private static func build(number: Int, level: MoonlitMechanismLevel, actions: [MoonlitMechanismAction],
                              work: Int, skipped: Int) throws(MoonlitMechanismError) -> Self {
        // Provenance, first part: the number names a manifest entry and the level carries its id.
        guard (1...MoonlitMechanismManifest.entries.count).contains(number),
              level.id == MoonlitMechanismGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<MoonlitMechanismGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        // Shape: the solver's action order for a plan vector of at least one action, then one run.
        guard let vector = vector(actions, gears: level.gears.count), actions.count >= 2 else {
            throw .witness("actions")
        }
        // Replay on a fresh play: the witness must win on its last action and not before.
        guard let run = replay(level, actions: actions), run.play.stage == .won, !run.endedEarly else {
            throw .witness("replay")
        }
        // Provenance, second part: the level is candidate `skipped` of manifest entry `number`.
        let entry: MoonlitMechanismManifestEntry = MoonlitMechanismManifest.entries[number - 1]
        guard entry.number == number, MoonlitMechanismGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        // Recount: every vector of every norm below the plan's size was tried; the last of those norms is the
        // counterexample.
        let size: Int = actions.count - 1
        let dimensions: Int = level.gears.count + 1
        var smaller: Int = 0
        for norm in 0..<size { smaller += vectors(dimensions: dimensions, norm: norm) }
        let counterexample = MoonlitMechanismCounterexample(norm: size - 1,
                                                            vectors: vectors(dimensions: dimensions, norm: size - 1))
        let plan = MoonlitMechanismPlan(turns: vector.turns, lamp: vector.lamp, reseats: vector.reseats,
                                        smallerVectors: smaller, work: work)
        let difficulty = MoonlitMechanismDifficulty(level: level, plan: plan)
        return Self(number: number, level: level, actions: actions, digests: run.digests,
                    fingerprints: run.fingerprints, counterexample: counterexample, difficulty: difficulty,
                    skipped: skipped)
    }

    /// C(n, k), 0 outside 0 … n.
    private static func binomial(_ n: Int, _ k: Int) -> Int {
        guard k >= 0, n >= 0, k <= n else { return 0 }
        var result: Int = 1
        var i: Int = 0
        while i < min(k, n - k) {
            result = result * (n - i) / (i + 1)
            i += 1
        }
        return result
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, digests, fingerprints, counterexample, difficulty, skipped
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
        do { level = try c.decode(MoonlitMechanismLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([MoonlitMechanismAction].self, forKey: .actions)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        counterexample = try c.decode(MoonlitMechanismCounterexample.self, forKey: .counterexample)
        difficulty = try c.decode(MoonlitMechanismDifficulty.self, forKey: .difficulty)
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
        try c.encode(counterexample, forKey: .counterexample)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}
