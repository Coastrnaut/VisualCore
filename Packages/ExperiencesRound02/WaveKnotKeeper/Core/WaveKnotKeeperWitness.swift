// WaveKnotKeeperWitness — feature 322 (R02-G03-02) T-R02G0302-005 (FR-R02G0302-004; SC-R02G0302-005; clarification Q4).
// The solver witness of one generated level: the moves of its shortest solution, the play fingerprint after the start
// (and the tutorial) and after every move, the terminal summary of the winning rope (crossings, writhe, tension), the
// near miss (from the winning rope, the first legal move in the rules' order whose rope does not win, with that rope's
// summary) and the crossing counterexample (the first rope the solver explored, in search order, with a move the rules
// refuse with `r02-g03.move("crossing")`). The stored form is JSON with sorted keys, pretty-printed, with one trailing
// newline; decoding rebuilds the witness by replay (and by re-running the solver to the stored depth) and refuses any
// stored value that the rebuild does not reproduce.
import Foundation

/// The terminal summary of a winning rope.
public struct WaveKnotKeeperTerminal: Sendable, Equatable, Codable {
    /// The crossing count of the xy-projection.
    public let crossings: Int
    /// The writhe of the xy-projection.
    public let writhe: Int
    /// The rope's tension (``WaveKnotKeeperGeometry/tension(_:)``).
    public let tension: Int

    /// A terminal summary of the given values.
    public init(crossings: Int, writhe: Int, tension: Int) {
        self.crossings = crossings
        self.writhe = writhe
        self.tension = tension
    }

    /// The terminal summary of `points`.
    public init(_ points: [WaveKnotKeeperPoint]) {
        let summary: WaveKnotKeeperSummary = WaveKnotKeeperGeometry.summary(points)
        self.init(crossings: summary.crossings, writhe: summary.writhe,
                  tension: WaveKnotKeeperGeometry.tension(points))
    }
}

/// The near miss of a winning rope: one legal move that loses, and the summary of the rope it reaches.
public struct WaveKnotKeeperNearMiss: Sendable, Equatable, Codable {
    /// The single move from the winning rope.
    public let move: WaveKnotKeeperMove
    /// The crossing count of the losing rope's projection.
    public let crossings: Int
    /// The writhe of the losing rope's projection.
    public let writhe: Int
    /// Whether the losing rope's projection is degenerate.
    public let degenerate: Bool

    /// A near miss of the given values (not checked; ``WaveKnotKeeperWitness`` checks it).
    public init(move: WaveKnotKeeperMove, crossings: Int, writhe: Int, degenerate: Bool) {
        self.move = move
        self.crossings = crossings
        self.writhe = writhe
        self.degenerate = degenerate
    }

    /// The near miss of `move` reaching the rope `points`.
    public init(move: WaveKnotKeeperMove, points: [WaveKnotKeeperPoint]) {
        let summary: WaveKnotKeeperSummary = WaveKnotKeeperGeometry.summary(points)
        self.init(move: move, crossings: summary.crossings, writhe: summary.writhe, degenerate: summary.degenerate)
    }
}

/// The replayable proof that a generated Wave Knot Keeper level is won by its shortest solution, lost by a near miss and
/// guarded by the crossing rule.
public struct WaveKnotKeeperWitness: Sendable, Equatable, Codable {
    /// The stored-form schema.
    public static var schema: Int { 1 }

    /// The manifest number of the level, 1 … 100.
    public let number: Int
    /// The level.
    public let level: WaveKnotKeeperLevel
    /// The moves of the shortest solution, in order.
    public let moves: [WaveKnotKeeperMove]
    /// The play fingerprint after `begin` (and `dismissTutorial` when the level has a tutorial), then after each move.
    public let fingerprints: [String]
    /// The summary and tension of the winning rope.
    public let terminal: WaveKnotKeeperTerminal
    /// The first legal move from the winning rope, in the rules' order, whose rope does not win.
    public let nearMiss: WaveKnotKeeperNearMiss
    /// The first explored rope with a move the rules refuse as a crossing, and that move.
    public let crossing: WaveKnotKeeperCrossingExample
    /// The level's difficulty.
    public let difficulty: WaveKnotKeeperDifficulty
    /// The candidates the generator skipped before accepting this level.
    public let skipped: Int

    /// A witness of the given values (not checked).
    private init(number: Int, level: WaveKnotKeeperLevel, moves: [WaveKnotKeeperMove], fingerprints: [String],
                 terminal: WaveKnotKeeperTerminal, nearMiss: WaveKnotKeeperNearMiss,
                 crossing: WaveKnotKeeperCrossingExample, difficulty: WaveKnotKeeperDifficulty, skipped: Int) {
        self.number = number
        self.level = level
        self.moves = moves
        self.fingerprints = fingerprints
        self.terminal = terminal
        self.nearMiss = nearMiss
        self.crossing = crossing
        self.difficulty = difficulty
        self.skipped = skipped
    }

    /// The witness of a generated level, built by replaying its solution on a new play.
    ///
    /// - Throws: `.witness("replay")` when an event or move is refused, the moves do not end in a win or the play's final
    ///   rope is not the solution's; `.witness("near-miss")` when every legal move from the winning rope still wins;
    ///   `.witness("crossing")` when the solution has no crossing counterexample or the rules do not refuse it as a
    ///   crossing.
    public static func make(_ generated: WaveKnotKeeperGenerated) throws(WaveKnotKeeperError) -> Self {
        let level: WaveKnotKeeperLevel = generated.level
        let moves: [WaveKnotKeeperMove] = generated.solution.moves
        let replayed: Replay = try replay(level: level, moves: moves)
        guard replayed.play.stage == .won, replayed.play.points == generated.solution.final else {
            throw .witness("replay")
        }
        let winning: [WaveKnotKeeperPoint] = replayed.play.points
        guard let nearMiss = nearMiss(of: winning, level: level, moves: moves) else { throw .witness("near-miss") }
        guard let crossing = generated.solution.crossing, isRefused(crossing, level: level) else {
            throw .witness("crossing")
        }
        return Self(number: generated.entry.number, level: level, moves: moves, fingerprints: replayed.fingerprints,
                    terminal: WaveKnotKeeperTerminal(winning), nearMiss: nearMiss, crossing: crossing,
                    difficulty: generated.difficulty, skipped: generated.skipped)
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
            preconditionFailure("a Wave Knot Keeper witness of checked values always encodes: \(error)")
        }
    }

    /// Decodes a stored witness and re-verifies it: the moves are replayed on a new play of the stored level, the solver is
    /// re-run to the stored depth, and every stored value must be reproduced.
    ///
    /// - Throws: `.newerSchema(s)` above ``schema``; `.witness("damaged")` for unreadable JSON, missing keys or a schema
    ///   below 1; `.witness("level")` for a level the level rules refuse (an edited field breaks its fingerprint);
    ///   `.witness(part)` with `"replay"` (a refused move, no win), `"fingerprints"`, `"terminal"`, `"nearMiss"`,
    ///   `"crossing"` or `"difficulty"` for a value the rebuild does not reproduce.
    public static func decode(_ data: Data) throws(WaveKnotKeeperError) -> Self {
        struct Probe: Decodable { let schema: Int }
        let probe: Probe
        do { probe = try JSONDecoder().decode(Probe.self, from: data) } catch { throw .witness("damaged") }
        guard probe.schema <= schema else { throw .newerSchema(probe.schema) }
        guard probe.schema >= 1 else { throw .witness("damaged") }
        let stored: Self
        do {
            stored = try JSONDecoder().decode(Self.self, from: data)
        } catch is LevelRefusal {
            throw .witness("level")
        } catch {
            throw .witness("damaged")
        }
        try stored.verify()
        return stored
    }

    /// Re-verifies every stored value by replay and by re-running the solver to the stored depth.
    private func verify() throws(WaveKnotKeeperError) {
        let replayed: Replay = try Self.replay(level: level, moves: moves)
        guard replayed.fingerprints == fingerprints else { throw .witness("fingerprints") }
        guard replayed.play.stage == .won else { throw .witness("replay") }
        let winning: [WaveKnotKeeperPoint] = replayed.play.points
        guard WaveKnotKeeperTerminal(winning) == terminal else { throw .witness("terminal") }
        guard let recomputed = Self.nearMiss(of: winning, level: level, moves: moves), recomputed == nearMiss else {
            throw .witness("nearMiss")
        }
        guard Self.isRefused(crossing, level: level) else { throw .witness("crossing") }
        // The solver to the stored depth must find exactly these moves, this crossing example and this work.
        guard let solution = WaveKnotKeeperSolver.solve(level, depth: moves.count), solution.moves == moves,
              solution.final == winning else {
            throw .witness("difficulty")
        }
        guard solution.crossing == crossing else { throw .witness("crossing") }
        guard difficulty == WaveKnotKeeperDifficulty(level: level, solution: solution) else {
            throw .witness("difficulty")
        }
    }

    /// A finished replay: the play and the fingerprints after the start and after each move.
    private struct Replay {
        let play: WaveKnotKeeperPlay
        let fingerprints: [String]
    }

    /// Replays `moves` on a new play of `level` after `begin` (and `dismissTutorial` when the level has a tutorial).
    ///
    /// - Throws: `.witness("replay")` when an event or a move is refused.
    private static func replay(level: WaveKnotKeeperLevel,
                               moves: [WaveKnotKeeperMove]) throws(WaveKnotKeeperError) -> Replay {
        var play = WaveKnotKeeperPlay(level: level)
        var fingerprints: [String] = []
        do {
            try play.handle(.begin)
            if level.tutorial { try play.handle(.dismissTutorial) }
            fingerprints.append(play.fingerprint)
            for move in moves {
                try play.apply(move, expecting: play.fingerprint)
                fingerprints.append(play.fingerprint)
            }
        } catch {
            throw .witness("replay")
        }
        return Replay(play: play, fingerprints: fingerprints)
    }

    /// The near miss of the winning rope `winning` on `level` (``WaveKnotKeeperGenerator/nearMiss(_:solution:)``); nil
    /// when every legal move still wins.
    static func nearMiss(of winning: [WaveKnotKeeperPoint], level: WaveKnotKeeperLevel,
                         moves: [WaveKnotKeeperMove]) -> WaveKnotKeeperNearMiss? {
        let solution = WaveKnotKeeperSolution(shortest: moves.count, moves: moves, final: winning, work: 0,
                                              crossing: nil)
        guard let found = WaveKnotKeeperGenerator.nearMiss(level, solution: solution) else { return nil }
        return WaveKnotKeeperNearMiss(move: found.move, points: found.points)
    }

    /// Whether `example` is a rope of `level`'s point count whose move the rules refuse with `move("crossing")`.
    static func isRefused(_ example: WaveKnotKeeperCrossingExample, level: WaveKnotKeeperLevel) -> Bool {
        example.points.count == level.points.count
            && WaveKnotKeeperPlay.refusal(of: example.move, points: example.points, level: level) == .move("crossing")
    }

    /// The error a stored level that the level rules refuse raises while decoding.
    private struct LevelRefusal: Error {}

    private enum CodingKeys: String, CodingKey {
        case schema, number, level, moves, fingerprints, terminal, nearMiss, crossing, difficulty, skipped
    }

    /// Decodes the stored fields without re-verifying them; ``decode(_:)`` decodes and re-verifies.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let schema: Int = try c.decode(Int.self, forKey: .schema)
        guard (1...Self.schema).contains(schema) else {
            throw DecodingError.dataCorruptedError(forKey: .schema, in: c, debugDescription: "schema \(schema)")
        }
        number = try c.decode(Int.self, forKey: .number)
        do { level = try c.decode(WaveKnotKeeperLevel.self, forKey: .level) } catch { throw LevelRefusal() }
        moves = try c.decode([WaveKnotKeeperMove].self, forKey: .moves)
        fingerprints = try c.decode([String].self, forKey: .fingerprints)
        terminal = try c.decode(WaveKnotKeeperTerminal.self, forKey: .terminal)
        nearMiss = try c.decode(WaveKnotKeeperNearMiss.self, forKey: .nearMiss)
        crossing = try c.decode(WaveKnotKeeperCrossingExample.self, forKey: .crossing)
        difficulty = try c.decode(WaveKnotKeeperDifficulty.self, forKey: .difficulty)
        skipped = try c.decode(Int.self, forKey: .skipped)
    }

    /// Encodes the stored form with ``schema``.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.schema, forKey: .schema)
        try c.encode(number, forKey: .number)
        try c.encode(level, forKey: .level)
        try c.encode(moves, forKey: .moves)
        try c.encode(fingerprints, forKey: .fingerprints)
        try c.encode(terminal, forKey: .terminal)
        try c.encode(nearMiss, forKey: .nearMiss)
        try c.encode(crossing, forKey: .crossing)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(skipped, forKey: .skipped)
    }
}
