// ChronoConstellatorWitness — feature 352 (R02-G06-02) T-R02G0602-005 (FR-R02G0602-004; SC-R02G0602-003, 005;
// clarification Q4). The solver witness of one generated level: the actions (the solution's phase changes in star order,
// then `step(tick limit)`), the win tick, the 16-hex position digest after every tick 1 … win, the play fingerprints
// after `begin` (and `dismissTutorial`) and after each action, the solver's lower bound m*, its window and the windows
// considered and blocked, the unedited counterexample (the default timeline) and the near miss (the witness without its
// last phase change), each with its failure reason and tick, the difficulty and the candidates skipped. The stored form is
// JSON with sorted keys, pretty-printed, with one trailing newline. Making and decoding both rebuild the witness from its
// level by replaying the actions on a `ChronoConstellatorPlay`; decoding first replays the stored actions, then re-runs
// `ChronoConstellatorSolver.solve` and refuses any stored value the rebuild does not reproduce.
import Foundation
import VisualCoreMath

/// A failing run of a witness: the actions replayed after `begin`, why the play fails and at which tick.
public struct ChronoConstellatorCounterexample: Sendable, Equatable, Codable {
    /// The phase changes in star order, then `step(tick limit)`.
    public let actions: [ChronoConstellatorAction]
    /// Why the play fails.
    public let reason: ChronoConstellatorFailure
    /// The tick at which the failure is decided.
    public let tick: Int

    /// A counterexample of the given values.
    public init(actions: [ChronoConstellatorAction], reason: ChronoConstellatorFailure, tick: Int) {
        self.actions = actions
        self.reason = reason
        self.tick = tick
    }
}

/// The replayable proof that a generated Chrono Constellator level is won by its solver's phase-only timeline, lost by
/// the default timeline and lost by the near miss (clarification Q4).
public struct ChronoConstellatorWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static let schema: Int = 1

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level, stored in its own fingerprinted form.
    public let level: ChronoConstellatorLevel
    /// The actions: `.phase(star, offset)` for each star whose solution phase differs from its default, in star order,
    /// then `.step(level.tickLimit)`.
    public let actions: [ChronoConstellatorAction]
    /// The tick at which the actions win.
    public let winTick: Int
    /// The position digest (``digest(_:)``) of the witness timeline after every tick 1 … ``winTick``.
    public let digests: [String]
    /// The play fingerprints after `begin` (and `dismissTutorial` when the level has a tutorial) and after each action.
    public let fingerprints: [String]
    /// The solver's lower bound m*, which equals the number of phase changes.
    public let lowerBound: Int
    /// The first unblocked window, the tick the witness timeline is built for.
    public let window: Int
    /// The windows considered (ticks with the smallest misaligned count).
    public let windows: Int
    /// The windows blocked by a collision.
    public let blocked: Int
    /// The default timeline (no edits) run to the tick limit, which fails.
    public let unedited: ChronoConstellatorCounterexample
    /// The witness without its last phase change, which fails (equal to ``unedited`` when m* is 1).
    public let nearMiss: ChronoConstellatorCounterexample
    /// The level's difficulty.
    public let difficulty: ChronoConstellatorDifficulty
    /// The candidates the generator skipped before this level.
    public let skipped: Int

    /// A witness of the given values, unchecked (``make(_:)`` and ``decode(_:)`` check).
    init(number: Int, level: ChronoConstellatorLevel, actions: [ChronoConstellatorAction], winTick: Int,
         digests: [String], fingerprints: [String], lowerBound: Int, window: Int, windows: Int, blocked: Int,
         unedited: ChronoConstellatorCounterexample, nearMiss: ChronoConstellatorCounterexample,
         difficulty: ChronoConstellatorDifficulty, skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.winTick = winTick
        self.digests = digests
        self.fingerprints = fingerprints
        self.lowerBound = lowerBound
        self.window = window
        self.windows = windows
        self.blocked = blocked
        self.unedited = unedited
        self.nearMiss = nearMiss
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The phase-change actions of `solution` on `level`: `.phase(star, offset)` for each star whose solution phase
    /// differs from the level's default phase, in star order.
    public static func phaseChanges(for solution: ChronoConstellatorSolution,
                                    level: ChronoConstellatorLevel) -> [ChronoConstellatorAction] {
        var result: [ChronoConstellatorAction] = []
        for star in level.stars.indices where star < solution.phases.count
            && solution.phases[star] != level.stars[star].phase {
            result.append(.phase(star, solution.phases[star]))
        }
        return result
    }

    /// The actions of `solution` on `level`: its phase changes in star order, then `.step(level.tickLimit)` (a level's
    /// tick limit, at most 1,200, is always one step).
    public static func actions(for solution: ChronoConstellatorSolution,
                               level: ChronoConstellatorLevel) -> [ChronoConstellatorAction] {
        phaseChanges(for: solution, level: level) + [.step(level.tickLimit)]
    }

    /// The position digest of the star cells `positions`: the first 16 lowercase hex characters of
    /// `StableHash.sha256Hex` over every star's cell in star order, each cell as two bytes big-endian (a grid has at
    /// most 120 cells, so every cell fits).
    public static func digest(_ positions: [Int]) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(positions.count * 2)
        for cell in positions {
            bytes.append(UInt8(truncatingIfNeeded: cell >> 8))
            bytes.append(UInt8(truncatingIfNeeded: cell))
        }
        return String(StableHash.sha256Hex(bytes).prefix(16))
    }

    /// The witness of a generated level, built by replaying its solution.
    ///
    /// - Throws: `.witness(part)` for any part the rebuild refuses: `"replay"` (a refused action or no win),
    ///   `"lower-bound"` (the phase changes are not m*), `"unedited"` or `"near-miss"` (a counterexample that wins or is
    ///   refused), `"difficulty"` (not the difficulty of the solution and replay), `"number"` or `"skipped"`.
    public static func make(_ generated: ChronoConstellatorGenerated) throws(ChronoConstellatorError) -> Self {
        let witness: Self = try build(number: generated.entry.number, level: generated.level,
                                      solution: generated.solution, skipped: generated.skipped)
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
            preconditionFailure("a Chrono Constellator witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the stored actions are replayed on a new play, then the level is
    /// re-solved with ``ChronoConstellatorSolver/solve(_:)`` and the witness rebuilt; every stored value must equal the
    /// rebuilt one.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.witness("schema")` for a schema below 1; `.witness("unreadable")`
    ///   for damaged JSON or missing keys; `.witness("level")` for a level the level rules refuse (an edited field breaks
    ///   its fingerprint); `.witness("replay")` when the stored actions are refused or do not win; `.witness("solution")`
    ///   when the solver no longer certifies the level; `.witness(part)` with `"actions"`, `"win-tick"`, `"digests"`,
    ///   `"fingerprints"`, `"lower-bound"`, `"window"`, `"windows"`, `"blocked"`, `"unedited"`, `"near-miss"`,
    ///   `"difficulty"`, `"number"` or `"skipped"` for a value the rebuild does not reproduce.
    public static func decode(_ data: Data) throws(ChronoConstellatorError) -> Self {
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
        // The stored actions must still replay to a win.
        guard let replayed = replay(stored.level, actions: stored.actions), replayed.play.stage == .won else {
            throw .witness("replay")
        }
        guard let solution = ChronoConstellatorSolver.solve(stored.level) else { throw .witness("solution") }
        let rebuilt: Self = try build(number: stored.number, level: stored.level, solution: solution,
                                      skipped: stored.skipped)
        guard rebuilt.actions == stored.actions else { throw .witness("actions") }
        guard rebuilt.winTick == stored.winTick else { throw .witness("win-tick") }
        guard rebuilt.digests == stored.digests else { throw .witness("digests") }
        guard rebuilt.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard rebuilt.lowerBound == stored.lowerBound else { throw .witness("lower-bound") }
        guard rebuilt.window == stored.window else { throw .witness("window") }
        guard rebuilt.windows == stored.windows else { throw .witness("windows") }
        guard rebuilt.blocked == stored.blocked else { throw .witness("blocked") }
        guard rebuilt.unedited == stored.unedited else { throw .witness("unedited") }
        guard rebuilt.nearMiss == stored.nearMiss else { throw .witness("near-miss") }
        guard rebuilt.difficulty == stored.difficulty else { throw .witness("difficulty") }
        return stored
    }

    /// A play of `level` after `begin` (and `dismissTutorial` when the level has a tutorial) and `actions`, each applied
    /// with the current fingerprint, with the fingerprint after the start and after each action; nil when a stage event
    /// or an action is refused.
    static func replay(_ level: ChronoConstellatorLevel,
                       actions: [ChronoConstellatorAction]) -> (play: ChronoConstellatorPlay, fingerprints: [String])? {
        var play = ChronoConstellatorPlay(level: level)
        var fingerprints: [String] = []
        do {
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            fingerprints.append(play.fingerprint)
            for action in actions {
                try play.apply(action, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
            }
        } catch {
            return nil
        }
        return (play, fingerprints)
    }

    /// The failing run of `changes` then `step(tick limit)` on `level` as a counterexample, or nil when an action is
    /// refused or the run does not fail.
    static func counterexample(_ level: ChronoConstellatorLevel,
                               changes: [ChronoConstellatorAction]) -> ChronoConstellatorCounterexample? {
        let actions: [ChronoConstellatorAction] = changes + [.step(level.tickLimit)]
        guard let run = replay(level, actions: actions), run.play.stage == .failed,
              let reason = run.play.failure else { return nil }
        return ChronoConstellatorCounterexample(actions: actions, reason: reason, tick: run.play.tick)
    }

    /// Builds a witness from its level and the solver's solution, checking every part.
    private static func build(number: Int, level: ChronoConstellatorLevel, solution: ChronoConstellatorSolution,
                              skipped: Int) throws(ChronoConstellatorError) -> Self {
        guard solution.phases.count == level.stars.count else { throw .witness("replay") }
        let changes: [ChronoConstellatorAction] = phaseChanges(for: solution, level: level)
        let actions: [ChronoConstellatorAction] = changes + [.step(level.tickLimit)]
        // Replay on a new play: the witness must win.
        guard let run = replay(level, actions: actions), run.play.stage == .won else { throw .witness("replay") }
        let winTick: Int = run.play.tick
        guard changes.count == solution.lowerBound else { throw .witness("lower-bound") }
        // Per-tick digests of the witness timeline; every tick before the win is undecided.
        let timeline: ChronoConstellatorTimeline = run.play.timeline
        var digests: [String] = []
        digests.reserveCapacity(winTick)
        for tick in 1...winTick {
            let positions: [Int] = timeline.positions(at: tick, level: level)
            let verdict = ChronoConstellatorEvaluation.verdict(positions: positions, tick: tick, level: level)
            guard verdict == (tick == winTick ? .won : .running) else { throw .witness("digests") }
            digests.append(digest(positions))
        }
        // Counterexamples: the default timeline, and the witness without its last phase change.
        guard let unedited = counterexample(level, changes: []) else { throw .witness("unedited") }
        guard let nearMiss = counterexample(level, changes: Array(changes.dropLast())) else {
            throw .witness("near-miss")
        }
        let difficulty = ChronoConstellatorDifficulty(
            smallest: solution.lowerBound, winTick: winTick, stars: level.stars.count,
            loopLengths: level.stars.map(\.length), windows: solution.windows, blocked: solution.blocked)
        guard (1...100).contains(number) else { throw .witness("number") }
        guard (0..<ChronoConstellatorGenerator.maxCandidates).contains(skipped) else { throw .witness("skipped") }
        return Self(number: number, level: level, actions: actions, winTick: winTick, digests: digests,
                    fingerprints: run.fingerprints, lowerBound: solution.lowerBound, window: solution.window,
                    windows: solution.windows, blocked: solution.blocked, unedited: unedited, nearMiss: nearMiss,
                    difficulty: difficulty, skipped: skipped)
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, actions, winTick, digests, fingerprints, lowerBound, window, windows, blocked
        case unedited, nearMiss, difficulty, skipped
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
            throw DecodingError.keyNotFound(CodingKeys.level, .init(codingPath: c.codingPath, debugDescription: "level"))
        }
        do { level = try c.decode(ChronoConstellatorLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        actions = try c.decode([ChronoConstellatorAction].self, forKey: .actions)
        winTick = try c.decode(Int.self, forKey: .winTick)
        digests = try c.decode([String].self, forKey: .digests)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        lowerBound = try c.decode(Int.self, forKey: .lowerBound)
        window = try c.decode(Int.self, forKey: .window)
        windows = try c.decode(Int.self, forKey: .windows)
        blocked = try c.decode(Int.self, forKey: .blocked)
        unedited = try c.decode(ChronoConstellatorCounterexample.self, forKey: .unedited)
        nearMiss = try c.decode(ChronoConstellatorCounterexample.self, forKey: .nearMiss)
        difficulty = try c.decode(ChronoConstellatorDifficulty.self, forKey: .difficulty)
        skipped = try c.decode(Int.self, forKey: .skipped)
    }

    /// Encodes the stored form with ``schema``.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(number, forKey: .number)
        try c.encode(level, forKey: .level)
        try c.encode(actions, forKey: .actions)
        try c.encode(winTick, forKey: .winTick)
        try c.encode(digests, forKey: .digests)
        try c.encode(fingerprints, forKey: .fingerprints)
        try c.encode(lowerBound, forKey: .lowerBound)
        try c.encode(window, forKey: .window)
        try c.encode(windows, forKey: .windows)
        try c.encode(blocked, forKey: .blocked)
        try c.encode(unedited, forKey: .unedited)
        try c.encode(nearMiss, forKey: .nearMiss)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}
