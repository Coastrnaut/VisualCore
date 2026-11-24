// VoxelOrigamiWitness — feature 442 (R02-G15-02) T-R02G1502-005 (FR-R02G1502-004; SC-R02G1502-003, 005;
// clarification Q4), modelled on MoonlitMechanismWitness (feature 432). The solver witness of one generated level: the
// manifest number, the level's stored form, the actions (the plan's quarter turns in order; the last one wins), the
// 16-hex state digest of the play's quarter turns after every action, the play fingerprints after `begin`, after
// `dismissTutorial` (when the level has a tutorial) and after each action, the counterexample (the depth one below the
// plan and the number of states the solver reached at exactly that depth, none matching), the difficulty and the
// candidates skipped. The stored form is JSON with sorted keys, pretty-printed, with one trailing newline. Making and
// decoding both rebuild the witness from its level: the actions are replayed on a fresh `VoxelOrigamiPlay`, the level
// is re-derived as candidate `skipped` of its manifest entry, and the solver is run again on the level, whose plan must
// be exactly the stored actions; the counterexample and the difficulty come from that plan. Decoding re-checks the
// level under `VoxelOrigamiLevel.decode`'s rules (its `Codable` conformance) and refuses any stored value the rebuild
// does not reproduce (feature 382's convergence lesson). Integers only; no clock, no random source.
import Foundation
import VisualCoreMath

/// The proof that no plan of one turn fewer than a witness plan matches (clarification Q4).
///
/// The solver is a breadth-first search over quarter-turn states: every state reachable in fewer turns than the plan
/// was reached, and none matched the target. For a plan of size `s ≥ 1`, ``depth`` is `s − 1` and ``states`` is the
/// number of states reached at exactly that depth (`plan.statesByDepth[s − 1]`); the states of all smaller depths
/// together are the difficulty's `statesSearched`.
public struct VoxelOrigamiCounterexample: Sendable, Hashable, Codable {
    /// The depth one below the plan: the turns of the states refuted.
    public let depth: Int
    /// The states the solver reached at exactly ``depth``, none matching.
    public let states: Int

    /// A counterexample of the given values, unchecked.
    public init(depth: Int, states: Int) {
        self.depth = depth
        self.states = states
    }
}

/// The replayable proof that a generated Voxel Origami level is won by its solver's plan and that no plan of one turn
/// fewer matches (clarification Q4).
public struct VoxelOrigamiWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: VoxelOrigamiLevel
    /// The witness actions: the plan's quarter turns in order; the last one wins.
    public let actions: [VoxelOrigamiAction]
    /// The state digest (``digest(turns:)``) of the play's quarter turns after every action, in order.
    public let digests: [String]
    /// The play fingerprints after `begin`, after `dismissTutorial` when the level has a tutorial, and after each
    /// action.
    public let fingerprints: [String]
    /// The proof that one turn fewer cannot match.
    public let counterexample: VoxelOrigamiCounterexample
    /// The level's difficulty, with the solver's states searched and work.
    public let difficulty: VoxelOrigamiDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: VoxelOrigamiLevel, actions: [VoxelOrigamiAction], digests: [String],
         fingerprints: [String], counterexample: VoxelOrigamiCounterexample, difficulty: VoxelOrigamiDifficulty,
         skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.digests = digests
        self.fingerprints = fingerprints
        self.counterexample = counterexample
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The canonical text of a state: `turns=` and the quarter turns in cube order joined by `,`.
    /// Example: `turns=0,1,3,0`.
    public static func canonicalText(turns: [Int]) -> String {
        var values: [String] = []
        for turn in turns { values.append(String(turn)) }
        return "turns=" + values.joined(separator: ",")
    }

    /// The state digest: the first 16 lowercase hex characters of `StableHash.sha256Hex` over the UTF-8 bytes of
    /// ``canonicalText(turns:)``.
    public static func digest(turns: [Int]) -> String {
        String(StableHash.sha256Hex(Array(canonicalText(turns: turns).utf8)).prefix(16))
    }

    /// The witness of a generated level, built by replaying its plan on a fresh play.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"number"` (no manifest entry, an entry that is
    ///   not the manifest's, or a level id that is not `voxel-origami-NNN`), `"skipped"` (outside 0 … 255),
    ///   `"actions"` (no action, more actions than the budget, or a turn of an unknown hinge or a step other than ±1),
    ///   `"replay"` (a refused action, no win on the last action or a win or failure before it), `"candidate"` (the
    ///   level is not candidate `skipped` of its manifest entry), `"solution"` (the solver, run again, does not find
    ///   exactly these actions), `"counterexample"` (the plan's states by depth are not the solver's) and
    ///   `"difficulty"` (not the difficulty of the level and the solver's plan).
    public static func make(_ generated: VoxelOrigamiGenerated) throws(VoxelOrigamiError) -> Self {
        guard generated.entry.number >= 1, generated.entry.number <= VoxelOrigamiManifest.entries.count,
              VoxelOrigamiManifest.entries[generated.entry.number - 1] == generated.entry else {
            throw .witness("number")
        }
        let (witness, plan): (Self, VoxelOrigamiPlan) = try build(number: generated.entry.number,
                                                                   level: generated.level,
                                                                   actions: generated.plan.turns,
                                                                   skipped: generated.skipped)
        guard generated.plan.statesByDepth == plan.statesByDepth else { throw .witness("counterexample") }
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
            preconditionFailure("a Voxel Origami witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the level is re-checked under ``VoxelOrigamiLevel/decode(_:)``'s
    /// rules, the stored actions are replayed on a fresh play, the level is re-derived from its manifest entry, the
    /// solver is run again, and every stored value must equal the rebuilt one.
    ///
    /// - Throws: `.witness("schema s")` for a schema above ``schema`` or below 1; `.witness("unreadable")` for damaged
    ///   JSON, missing keys or values of the wrong type; `.witness("level")` for a level the level rules refuse (an
    ///   edited field breaks its fingerprint); any part ``make(_:)`` names; `.witness(part)` with `"digests"`,
    ///   `"fingerprints"`, `"counterexample"` or `"difficulty"` for a stored value the rebuild does not reproduce.
    public static func decode(_ data: Data) throws(VoxelOrigamiError) -> Self {
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
        let (rebuilt, _): (Self, VoxelOrigamiPlan) = try build(number: stored.number, level: stored.level,
                                                                actions: stored.actions, skipped: stored.skipped)
        guard rebuilt.digests == stored.digests else { throw .witness("digests") }
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.counterexample == stored.counterexample else { throw .witness("counterexample") }
        guard rebuilt.difficulty == stored.difficulty else { throw .witness("difficulty") }
        return stored
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the play shows a tutorial) and `actions`, each
    /// applied with the current fingerprint: the fingerprint after `begin`, after `dismissTutorial` and after each
    /// action, the state digest after each action and whether any action found the play no longer playing; nil when a
    /// stage event or an action is refused.
    static func replay(_ level: VoxelOrigamiLevel, actions: [VoxelOrigamiAction])
        -> (play: VoxelOrigamiPlay, fingerprints: [String], digests: [String], endedEarly: Bool)? {
        var play = VoxelOrigamiPlay(level: level)
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
                digests.append(digest(turns: play.turns))
            }
        } catch {
            return nil
        }
        return (play, fingerprints, digests, endedEarly)
    }

    /// Builds a witness from its level, actions and skipped count, checking every part, with the solver's plan.
    private static func build(number: Int, level: VoxelOrigamiLevel, actions: [VoxelOrigamiAction],
                              skipped: Int) throws(VoxelOrigamiError) -> (Self, VoxelOrigamiPlan) {
        // Provenance, first part: the number names a manifest entry and the level carries its id.
        guard (1...VoxelOrigamiManifest.entries.count).contains(number),
              level.id == VoxelOrigamiGenerator.levelID(number) else { throw .witness("number") }
        guard (0..<VoxelOrigamiGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        // Shape: at least one turn, within the budget, each of a known hinge by ±1.
        guard !actions.isEmpty, actions.count <= level.budget else { throw .witness("actions") }
        for action in actions {
            switch action {
            case .turn(let hinge, let step):
                guard hinge >= 1, hinge < level.cubes.count, step == 1 || step == -1 else {
                    throw .witness("actions")
                }
            }
        }
        // Replay on a fresh play: the witness must win on its last action and not before.
        guard let run = replay(level, actions: actions), run.play.stage == .won, !run.endedEarly else {
            throw .witness("replay")
        }
        // Provenance, second part: the level is candidate `skipped` of manifest entry `number`.
        let entry: VoxelOrigamiManifestEntry = VoxelOrigamiManifest.entries[number - 1]
        guard entry.number == number, VoxelOrigamiGenerator.candidate(entry, index: skipped) == level else {
            throw .witness("candidate")
        }
        // The solver's own result: its plan must be exactly these actions.
        let range: ClosedRange<Int> = VoxelOrigamiBandProfile.of(band: level.difficulty).planRange
        guard let plan = VoxelOrigamiSolver.plan(level, maxTurns: range.upperBound), plan.turns == actions,
              plan.statesByDepth.count == plan.size else { throw .witness("solution") }
        let depth: Int = plan.size - 1
        let counterexample = VoxelOrigamiCounterexample(depth: depth, states: plan.statesByDepth[depth])
        let difficulty = VoxelOrigamiDifficulty(level: level, plan: plan)
        let witness = Self(number: number, level: level, actions: actions, digests: run.digests,
                           fingerprints: run.fingerprints, counterexample: counterexample, difficulty: difficulty,
                           skipped: skipped)
        return (witness, plan)
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, digests, fingerprints, counterexample, difficulty, skipped
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
        do { level = try c.decode(VoxelOrigamiLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([VoxelOrigamiAction].self, forKey: .actions)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        counterexample = try c.decode(VoxelOrigamiCounterexample.self, forKey: .counterexample)
        difficulty = try c.decode(VoxelOrigamiDifficulty.self, forKey: .difficulty)
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
