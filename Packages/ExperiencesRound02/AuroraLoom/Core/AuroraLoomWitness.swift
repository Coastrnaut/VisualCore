// AuroraLoomWitness — feature 302 (R02-G01-02) T-R02G0102-005 (FR-R02G0102-004; clarification Q4; research R6, R7). The
// solver witness of one generated level: the actions of its shortest solution, the play fingerprint after the start and
// after every action, the terminal (worst, within tolerance) mismatch of the winning setting, and a counterexample (the
// winning setting with ribbon 0's phase one step further) whose worst mismatch exceeds the tolerance. The stored form is
// JSON with sorted keys, pretty-printed, with one trailing newline; decoding rebuilds the witness by replay and refuses any
// stored value that the replay does not reproduce.
import Foundation

/// A setting that does not win and the worst mismatch that proves it.
public struct AuroraLoomCounterexample: Sendable, Equatable, Codable {
    /// The losing setting.
    public let setting: AuroraLoomSteps
    /// Its worst mismatch, whose |residual| exceeds the level's tolerance.
    public let mismatch: AuroraLoomMismatch

    /// A counterexample of the given values (not checked; ``AuroraLoomWitness`` checks it).
    public init(setting: AuroraLoomSteps, mismatch: AuroraLoomMismatch) {
        self.setting = setting
        self.mismatch = mismatch
    }
}

/// The replayable proof that a generated Aurora Loom level is won by its shortest solution and lost by a near miss.
public struct AuroraLoomWitness: Sendable, Equatable {
    /// The stored-form schema.
    public static var schema: Int { 1 }

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level.
    public let level: AuroraLoomLevel
    /// The moves of the shortest solution, in order.
    public let actions: [AuroraLoomMove]
    /// The play fingerprint after `begin` (and `dismissTutorial` when the level has a tutorial), then after each action.
    public let fingerprints: [String]
    /// The worst mismatch of the winning setting (its |residual| is within the tolerance).
    public let terminal: AuroraLoomMismatch
    /// The winning setting with ribbon 0's phase moved by one step, and its worst mismatch (beyond the tolerance).
    public let counterexample: AuroraLoomCounterexample
    /// The level's difficulty.
    public let difficulty: AuroraLoomDifficulty
    /// How the solver reached the solution.
    public let method: AuroraLoomSolveMethod
    /// The candidates the generator skipped before accepting this level.
    public let skipped: Int

    /// The witness of a generated level, built by replaying its solution on a new play.
    ///
    /// - Throws: `.witness("replay")` when a move is refused or the moves do not end in a win; `.witness("counterexample")`
    ///   when the near-miss setting wins.
    public init(_ generated: AuroraLoomGenerated) throws(AuroraLoomError) {
        let level: AuroraLoomLevel = generated.level
        let actions: [AuroraLoomMove] = generated.solution.moves
        let replayed: Replay = try Self.replay(level: level, actions: actions)
        guard replayed.play.stage == .won else { throw .witness("replay") }
        let counterexample: AuroraLoomCounterexample = Self.counterexample(of: replayed.play.steps, level: level)
        guard !AuroraLoomHarmony.wins(counterexample.setting, level: level) else { throw .witness("counterexample") }
        number = generated.entry.number
        self.level = level
        self.actions = actions
        fingerprints = replayed.fingerprints
        terminal = AuroraLoomHarmony.worst(replayed.play.steps, level: level)
        self.counterexample = counterexample
        difficulty = generated.difficulty
        method = generated.solution.method
        skipped = generated.skipped
    }

    /// A witness of the given values, used by ``decode(_:)`` after its checks.
    private init(number: Int, level: AuroraLoomLevel, actions: [AuroraLoomMove], fingerprints: [String],
                 terminal: AuroraLoomMismatch, counterexample: AuroraLoomCounterexample,
                 difficulty: AuroraLoomDifficulty, method: AuroraLoomSolveMethod, skipped: Int) {
        self.number = number
        self.level = level
        self.actions = actions
        self.fingerprints = fingerprints
        self.terminal = terminal
        self.counterexample = counterexample
        self.difficulty = difficulty
        self.method = method
        self.skipped = skipped
    }

    /// The stored form: JSON with sorted keys, pretty-printed, without escaped slashes, followed by one newline.
    public func encoded() -> Data {
        let stored = Stored(schema: Self.schema, number: number, level: level, actions: actions,
                            fingerprints: fingerprints, terminal: terminal, counterexample: counterexample,
                            difficulty: difficulty, method: method, skipped: skipped)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        do {
            var data: Data = try encoder.encode(stored)
            data.append(0x0A)
            return data
        } catch {
            preconditionFailure("an Aurora Loom witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and rebuilds it: the actions are replayed on a new play of the stored level and every
    /// stored value must be reproduced.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.malformed(description)` for unreadable JSON, missing keys, a schema
    ///   below 1 or a level the level rules refuse; `.witness(reason)` with `"replay"` (a refused action or no win),
    ///   `"fingerprints"`, `"terminal"`, `"counterexample"` or `"difficulty"` for a value the replay does not reproduce.
    public static func decode(_ data: Data) throws(AuroraLoomError) -> AuroraLoomWitness {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .malformed("unreadable") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .malformed("schema \(probe.schema)") }
        let stored: Stored
        do { stored = try JSONDecoder().decode(Stored.self, from: data) } catch { throw .malformed("unreadable") }
        let level: AuroraLoomLevel = stored.level
        let replayed: Replay = try replay(level: level, actions: stored.actions)
        guard replayed.fingerprints == stored.fingerprints else { throw .witness("fingerprints") }
        guard replayed.play.stage == .won else { throw .witness("replay") }
        guard AuroraLoomHarmony.worst(replayed.play.steps, level: level) == stored.terminal else {
            throw .witness("terminal")
        }
        let counterexample: AuroraLoomCounterexample = Self.counterexample(of: replayed.play.steps, level: level)
        guard counterexample == stored.counterexample,
              !AuroraLoomHarmony.wins(counterexample.setting, level: level) else { throw .witness("counterexample") }
        let difficulty: AuroraLoomDifficulty = stored.difficulty
        guard stored.actions.count == difficulty.shortest, difficulty.tolerance == level.tolerance,
              difficulty.omega == level.omega else { throw .witness("difficulty") }
        return AuroraLoomWitness(number: stored.number, level: level, actions: stored.actions,
                                 fingerprints: stored.fingerprints, terminal: stored.terminal,
                                 counterexample: stored.counterexample, difficulty: difficulty, method: stored.method,
                                 skipped: stored.skipped)
    }

    /// A finished replay: the play and the fingerprints after the start and after each action.
    private struct Replay {
        let play: AuroraLoomPlay
        let fingerprints: [String]
    }

    /// Replays `actions` on a new play of `level` after `begin` (and `dismissTutorial` when the level has a tutorial).
    ///
    /// - Throws: `.witness("replay")` when an event or an action is refused.
    private static func replay(level: AuroraLoomLevel, actions: [AuroraLoomMove]) throws(AuroraLoomError) -> Replay {
        var play = AuroraLoomPlay(level: level)
        var fingerprints: [String] = []
        do {
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            fingerprints.append(play.fingerprint)
            for move in actions {
                try play.apply(move, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
            }
        } catch {
            throw .witness("replay")
        }
        return Replay(play: play, fingerprints: fingerprints)
    }

    /// The near miss of a winning setting: ribbon 0's phase one step further (mod 16), with its worst mismatch.
    private static func counterexample(of steps: AuroraLoomSteps, level: AuroraLoomLevel) -> AuroraLoomCounterexample {
        var setting: AuroraLoomSteps = steps
        setting.phase[0] = (setting.phase[0] + 1) % 16
        return AuroraLoomCounterexample(setting: setting, mismatch: AuroraLoomHarmony.worst(setting, level: level))
    }

    /// The stored form.
    private struct Stored: Codable {
        let schema: Int
        let number: Int
        let level: AuroraLoomLevel
        let actions: [AuroraLoomMove]
        let fingerprints: [String]
        let terminal: AuroraLoomMismatch
        let counterexample: AuroraLoomCounterexample
        let difficulty: AuroraLoomDifficulty
        let method: AuroraLoomSolveMethod
        let skipped: Int
    }
}
