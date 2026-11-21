// WaveKnotKeeperProgress — feature 325 (R02-G03-05) T-R02G0305-003 (FR-R02G0305-001, 004, 005, 006; clarifications
// Q2–Q4). Player teaching and progression of Wave Knot Keeper: the three-instruction tutorial (move a point, match the
// signature, hints) that advances on accepted moves, a hint request and a win; the play mode (campaign, practice, daily);
// and the campaign progress — per solved level the best winning move count and the stars (3 at the certified shortest, 2
// within shortest + 2, otherwise 1), and the open frontier (level 1 open; a campaign win opens the next level, up to 100).
// The daily level is a clock-free function of a calendar date: (days from 2026-01-01 × 43) mod 100 + 1, in integer
// arithmetic on the proleptic Gregorian calendar. Progress alone opens every level (FR-R02G0305-006: no other gate). Every
// type is Codable with a stable, explicit form so a later feature can extend it. Modelled on feature 315's
// LissajousLabyrinthProgress. Feature 327 (R02-G03-07) T-R02G0307-002 (FR-R02G0307-001, 003, 004; clarifications Q1–Q4):
// each result also keeps its winning trace (the ordered net moves of the play that earned it, at most 64) and whether it
// is `verified`; a traced win replaces the result only with fewer moves (ties keep the earlier trace); `drop(level:)`
// removes a result for reconciliation; the mode gains `replay(level:)`. Encoded results carry `trace` and `verified`; an
// encoding without them (schema 2) decodes as an unverified result without a trace. Modelled on feature 317's
// LissajousLabyrinthProgress.
import Foundation

/// The step of the Wave Knot Keeper tutorial (levels 1 … 3).
///
/// The tutorial shows one instruction at a time: `move(point)` → `signature` → `hints` → `done`. The point of `move` is
/// the 0-based control-point index (as in ``WaveKnotKeeperMove/point``) of the level-1 hint for the current play,
/// supplied by the caller; the text shows it 1-based ("point 2" for index 1), as the panel does. Undo never moves the
/// step back: the caller simply does not advance it on undo or redo.
public enum WaveKnotKeeperTutorialStep: Sendable, Equatable, Hashable, Codable {
    /// Teaches moving: drag the control point with this 0-based index one step.
    case move(Int)
    /// Teaches the goal: the target's crossings and writhe, and the blue gates.
    case signature
    /// Teaches the hints.
    case hints
    /// The tutorial is over.
    case done

    /// The first step: teach moving the control point with 0-based index `point`.
    public static func first(point: Int) -> Self { .move(point) }

    /// The instruction shown for the step (clarification Q2); empty for `done`. The point of `move` is shown 1-based.
    public var text: String {
        switch self {
        case .move(let point): "Drag point \(point + 1) one step (or use the panel)"
        case .signature:
            "Match the target's crossings and twist (writhe); strands pass through each other only inside the blue gates"
        case .hints: "Ask for a hint whenever you are stuck"
        case .done: ""
        }
    }

    /// The step after an accepted move (or redo) that left the play in `stage`.
    ///
    /// A win (`stage == .won`) ends the tutorial from any step. Otherwise `move` advances to `signature`, `signature` to
    /// `hints`; `hints` and `done` stay. Call it only for accepted moves (never for undo).
    public func advancedByAction(stage: WaveKnotKeeperStage) -> Self {
        if stage == .won { return .done }
        switch self {
        case .move: return .signature
        case .signature: return .hints
        case .hints, .done: return self
        }
    }

    /// The step after the player asked for a hint: `signature` advances to `hints`; every other step stays.
    public func advancedByHint() -> Self {
        self == .signature ? .hints : self
    }

    /// The step after the player dismissed the tutorial: always `done`.
    public var dismissed: Self { .done }

    private enum CodingKeys: String, CodingKey {
        case step
        case point
    }

    /// Decodes `{"step": "move", "point": i}`, `{"step": "signature"}`, `{"step": "hints"}` or `{"step": "done"}`.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for an unknown step name or a negative point; a missing point for `move`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name: String = try container.decode(String.self, forKey: .step)
        switch name {
        case "move":
            let point: Int = try container.decode(Int.self, forKey: .point)
            guard point >= 0 else {
                throw DecodingError.dataCorruptedError(forKey: .point, in: container,
                                                       debugDescription: "negative tutorial point")
            }
            self = .move(point)
        case "signature": self = .signature
        case "hints": self = .hints
        case "done": self = .done
        default:
            throw DecodingError.dataCorruptedError(forKey: .step, in: container,
                                                   debugDescription: "unknown tutorial step \(name)")
        }
    }

    /// Encodes the step as `{"step": <name>}`, with `"point"` (the 0-based index) for `move`.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .move(let point):
            try container.encode("move", forKey: .step)
            try container.encode(point, forKey: .point)
        case .signature: try container.encode("signature", forKey: .step)
        case .hints: try container.encode("hints", forKey: .step)
        case .done: try container.encode("done", forKey: .step)
        }
    }
}

/// The mode a level is played in (clarification Q4).
public enum WaveKnotKeeperMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's allowance; a win records stars and opens the next level.
    case campaign
    /// Practice: the allowance raised to the kernel maximum (64); never awards stars or opens levels.
    case practice
    /// The daily level `level` (1 … 100) of ``WaveKnotKeeperProgress/dailyLevel(year:month:day:)``: campaign rules, but
    /// a win never opens a level.
    case daily(level: Int)
    /// The replay of the stored winning trace of `level` (1 … 100) on a fresh play (feature 327); never records.
    case replay(level: Int)

    private enum CodingKeys: String, CodingKey {
        case mode
        case level
    }

    /// Decodes `{"mode": "campaign"}`, `{"mode": "practice"}`, `{"mode": "daily", "level": n}` or
    /// `{"mode": "replay", "level": n}`.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for an unknown mode name or a daily or replay level outside 1 … 100.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name: String = try container.decode(String.self, forKey: .mode)
        switch name {
        case "campaign": self = .campaign
        case "practice": self = .practice
        case "daily":
            let level: Int = try container.decode(Int.self, forKey: .level)
            guard level >= 1 && level <= WaveKnotKeeperProgress.levelCount else {
                throw DecodingError.dataCorruptedError(forKey: .level, in: container,
                                                       debugDescription: "daily level outside 1 … 100")
            }
            self = .daily(level: level)
        case "replay":
            let level: Int = try container.decode(Int.self, forKey: .level)
            guard level >= 1 && level <= WaveKnotKeeperProgress.levelCount else {
                throw DecodingError.dataCorruptedError(forKey: .level, in: container,
                                                       debugDescription: "replay level outside 1 … 100")
            }
            self = .replay(level: level)
        default:
            throw DecodingError.dataCorruptedError(forKey: .mode, in: container,
                                                   debugDescription: "unknown mode \(name)")
        }
    }

    /// Encodes the mode as `{"mode": <name>}`, with `"level"` for `daily` and `replay`.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .campaign: try container.encode("campaign", forKey: .mode)
        case .practice: try container.encode("practice", forKey: .mode)
        case .daily(let level):
            try container.encode("daily", forKey: .mode)
            try container.encode(level, forKey: .level)
        case .replay(let level):
            try container.encode("replay", forKey: .mode)
            try container.encode(level, forKey: .level)
        }
    }
}

/// The campaign progress of Wave Knot Keeper: the solved levels with their best results and the open frontier.
///
/// Encoded as `{"frontier": n, "solved": [{"bestMoves": m, "level": l, "stars": s, "trace": [{"direction": d,
/// "point": p}, …], "verified": b}, …]}` with the solved levels as an array sorted by level, so equal progress gives
/// equal JSON (``encoded()`` also sorts the keys).
public struct WaveKnotKeeperProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one solved level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The fewest moves that won the level.
        public let bestMoves: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int
        /// The winning moves of the play that earned the result, in order (its undo stack of net moves; empty for a
        /// result without a trace).
        public let trace: [WaveKnotKeeperMove]
        /// Whether the result was recorded with its trace (``WaveKnotKeeperReconciliation`` replays it); false for a
        /// result restored from a save without traces.
        public let verified: Bool

        /// A result of the given values (not checked); by default without a trace and unverified.
        public init(bestMoves: Int, stars: Int, trace: [WaveKnotKeeperMove] = [], verified: Bool = false) {
            self.bestMoves = bestMoves
            self.stars = stars
            self.trace = trace
            self.verified = verified
        }
    }

    /// The number of levels.
    public static let levelCount = 100
    /// The most moves a stored trace may hold (the kernel's largest allowance).
    public static let maximumTraceLength = 64
    /// The year of the daily level's day 0 (2026-01-01).
    public static let dailyEpochYear = 2026
    /// The multiplier of the daily level (coprime with 100, so 100 consecutive days visit every level once).
    public static let dailyMultiplier = 43
    /// The calendar years accepted by the daily level.
    public static let dailyYears: ClosedRange<Int> = 1...9999

    /// The solved levels (1 … 100) and their best results.
    public private(set) var solved: [Int: Result]
    /// The highest open level, 1 … 100; every level 1 … `frontier` is open.
    public private(set) var frontier: Int

    /// No level solved; level 1 open.
    public init() {
        solved = [:]
        frontier = 1
    }

    /// Opens every level up to `level` (clamped to 1 … 100); the frontier never falls. The adapter opens the level a seed
    /// chose, so a session that starts beyond level 1 can play it.
    public mutating func open(through level: Int) {
        frontier = max(frontier, min(max(level, 1), Self.levelCount))
    }

    /// Whether `level` is open: 1 ≤ level ≤ ``frontier``.
    public func isOpen(_ level: Int) -> Bool { level >= 1 && level <= frontier }

    /// The next open level after `level` (`level + 1` when it is open), or nil when there is none.
    public func nextOpen(after level: Int) -> Int? {
        let next: Int = max(level + 1, 1)
        return isOpen(next) ? next : nil
    }

    /// The stars of a win in `moves` moves on a level whose certified shortest solution is `shortest`: 3 when
    /// `moves ≤ shortest`, 2 when `moves ≤ shortest + 2`, otherwise 1.
    public static func stars(moves: Int, shortest: Int) -> Int {
        if moves <= shortest { return 3 }
        if moves <= shortest + 2 { return 2 }
        return 1
    }

    /// Records a win of `level` in `moves` moves (certified shortest `shortest`).
    ///
    /// The new result replaces a stored one only when it is better (fewer moves or more stars); a worse or equal result
    /// keeps the stored one. When `opensNext` (a campaign win), the frontier rises to `level + 1` (at most 100) and never
    /// falls; daily wins pass `false`. Practice never calls this. A level outside 1 … 100 is ignored.
    public mutating func record(level: Int, moves: Int, shortest: Int, opensNext: Bool) {
        guard level >= 1 && level <= Self.levelCount else { return }
        let result: Result = Result(bestMoves: moves, stars: Self.stars(moves: moves, shortest: shortest))
        if let old = solved[level] {
            if result.bestMoves < old.bestMoves || result.stars > old.stars { solved[level] = result }
        } else {
            solved[level] = result
        }
        if opensNext { frontier = max(frontier, min(level + 1, Self.levelCount)) }
    }

    /// Records a win of `level` in `moves` moves (certified shortest `shortest`) with its winning `trace`: a verified
    /// result (feature 327, clarification Q1).
    ///
    /// The new result replaces a stored one only when it uses fewer moves; a result with equal or more moves keeps the
    /// stored one (ties keep the earlier trace). When `opensNext` (a campaign win), the frontier rises to `level + 1` (at
    /// most 100) and never falls; daily wins pass `false`. Practice and replay never call this. A level outside 1 … 100
    /// is ignored.
    public mutating func record(level: Int, moves: Int, shortest: Int, opensNext: Bool,
                                trace: [WaveKnotKeeperMove]) {
        guard level >= 1 && level <= Self.levelCount else { return }
        let result: Result = Result(bestMoves: moves, stars: Self.stars(moves: moves, shortest: shortest),
                                    trace: trace, verified: true)
        if let old = solved[level] {
            // Ties keep the earlier trace.
            if result.bestMoves < old.bestMoves { solved[level] = result }
        } else {
            solved[level] = result
        }
        if opensNext { frontier = max(frontier, min(level + 1, Self.levelCount)) }
    }

    /// Removes the result of `level` (reconciliation drops a result that does not replay); the frontier is unchanged.
    public mutating func drop(level: Int) {
        solved[level] = nil
    }

    /// The daily level (1 … 100) of a calendar date: (d × 43) mod 100 + 1, where d is the days from 2026-01-01 to the
    /// date (negative before it) and the modulo is non-negative, counted in integer arithmetic on the proleptic
    /// Gregorian calendar (no clock, no time zone, no Foundation calendar). nil for an impossible date (year outside
    /// 1 … 9999, month outside 1 … 12, day outside the month, leap years included).
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? {
        guard dailyYears.contains(year), month >= 1 && month <= 12 else { return nil }
        guard day >= 1 && day <= daysIn(month: month, year: year) else { return nil }
        let days: Int = daysFromCivil(year: year, month: month, day: day)
            - daysFromCivil(year: dailyEpochYear, month: 1, day: 1)
        return ((days * dailyMultiplier) % levelCount + levelCount) % levelCount + 1
    }

    /// The days in `month` (1 … 12) of `year` in the proleptic Gregorian calendar.
    static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2:
            let leap: Bool = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            return leap ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    /// The days from 1970-01-01 to the proleptic Gregorian date (H. Hinnant's days-from-civil; years 1 … 9999).
    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y: Int = month <= 2 ? year - 1 : year
        let era: Int = y / 400
        let yoe: Int = y - era * 400
        let mp: Int = (month + 9) % 12
        let doy: Int = (153 * mp + 2) / 5 + day - 1
        let doe: Int = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    /// The JSON encoding with sorted keys; equal progress gives equal data.
    public func encoded() throws -> Data {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// One solved level as encoded; `trace` and `verified` are absent in schema-2 encodings.
    private struct Entry: Codable {
        let level: Int
        let bestMoves: Int
        let stars: Int
        let trace: [WaveKnotKeeperMove]?
        let verified: Bool?
    }

    private enum CodingKeys: String, CodingKey {
        case solved
        case frontier
    }

    /// Decodes progress; the solved levels are an array of `{level, bestMoves, stars, trace, verified}` (a missing trace
    /// is empty, a missing `verified` false, so schema-2 saves stay readable).
    ///
    /// - Throws: `DecodingError.dataCorrupted` for a frontier outside 1 … 100, a level outside 1 … 100 or repeated, stars
    ///   outside 1 … 3, negative best moves, a trace longer than 64 moves or a trace move with a negative point.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let frontier: Int = try container.decode(Int.self, forKey: .frontier)
        let entries: [Entry] = try container.decode([Entry].self, forKey: .solved)
        guard frontier >= 1 && frontier <= Self.levelCount else {
            throw DecodingError.dataCorruptedError(forKey: .frontier, in: container,
                                                   debugDescription: "frontier outside 1 … 100")
        }
        var solved: [Int: Result] = [:]
        for entry in entries {
            guard entry.level >= 1 && entry.level <= Self.levelCount, solved[entry.level] == nil,
                  entry.stars >= 1 && entry.stars <= 3, entry.bestMoves >= 0 else {
                throw DecodingError.dataCorruptedError(forKey: .solved, in: container,
                                                       debugDescription: "invalid solved level \(entry.level)")
            }
            let trace: [WaveKnotKeeperMove] = entry.trace ?? []
            guard trace.count <= Self.maximumTraceLength, trace.allSatisfy({ move in move.point >= 0 }) else {
                throw DecodingError.dataCorruptedError(forKey: .solved, in: container,
                                                       debugDescription: "invalid trace of level \(entry.level)")
            }
            solved[entry.level] = Result(bestMoves: entry.bestMoves, stars: entry.stars, trace: trace,
                                         verified: entry.verified ?? false)
        }
        self.solved = solved
        self.frontier = frontier
    }

    /// Encodes the frontier and the solved levels as an array sorted by level, each with its trace and `verified`.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frontier, forKey: .frontier)
        var entries: [Entry] = []
        for level in solved.keys.sorted() {
            guard let result = solved[level] else { continue }
            entries.append(Entry(level: level, bestMoves: result.bestMoves, stars: result.stars,
                                 trace: result.trace, verified: result.verified))
        }
        try container.encode(entries, forKey: .solved)
    }
}
