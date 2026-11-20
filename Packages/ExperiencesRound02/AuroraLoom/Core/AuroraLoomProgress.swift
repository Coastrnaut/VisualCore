// AuroraLoomProgress — feature 305 (R02-G01-05) T-R02G0105-003 (FR-R02G0105-001, 004, 005, 006; clarifications Q2, Q3,
// Q4; research R3, R4, R5). Player teaching and progression of Aurora Loom: the three-step tutorial (wave, phase,
// harmony) that advances on the player's own records; the play mode (campaign, practice, daily); and the campaign
// progress — per solved level the best winning move count and the stars (3 at the certified shortest, 2 within
// shortest + 2, otherwise 1), and the open frontier (level 1 open; a recorded win opens the next level, up to 100). The
// daily level is a clock-free function of a calendar date: (days from 2026-01-01 × 37) mod 100 + 1, in integer
// arithmetic on the proleptic Gregorian calendar. Progress alone opens every level (FR-R02G0105-006: no other gate).
import Foundation

/// The step of the Aurora Loom tutorial.
///
/// The tutorial teaches the two controls, then the goal: `wave(ribbon:)` → `phase(ribbon:)` → `harmony` → `done`. The
/// ribbon named by `wave` and `phase` is supplied by the caller: the ribbon of the level-1 hint
/// (``AuroraLoomHints/hint(level:play:)``) for the current play, so the tutorial points at a ribbon whose change helps.
/// Ribbons are numbered 0 … 2 internally and shown to the player as 1 … 3.
public enum AuroraLoomTutorialStep: Sendable, Equatable, Hashable, Codable {
    /// Teaches the wave control of `ribbon` (0 … 2).
    case wave(ribbon: Int)
    /// Teaches the phase control of `ribbon` (0 … 2).
    case phase(ribbon: Int)
    /// Teaches the goal: every ribbon through the gold markers at all four gates.
    case harmony
    /// The tutorial is over.
    case done

    /// The first step: teach the wave control of `ribbon` (0 … 2).
    public static func first(ribbon: Int) -> Self { .wave(ribbon: ribbon) }

    /// The text shown for the step; the ribbon is named 1 … 3 (ribbon index + 1). Empty for `done`.
    public var text: String {
        switch self {
        case .wave(let ribbon): "Drag ribbon \(ribbon + 1)'s anchor up or down to change its wave."
        case .phase(let ribbon): "Turn ribbon \(ribbon + 1)'s dial to change its phase."
        case .harmony: "Bring every ribbon through the gold markers at all four gates."
        case .done: ""
        }
    }

    /// The step after the accepted action `record` that left the play in `stage`.
    ///
    /// A win (`stage == .won`) ends the tutorial from any step. Otherwise `wave` advances to `phase(ribbon:
    /// hintRibbon)` after a `.move` record of the wave control; `phase` advances to `harmony` after a `.move` record of
    /// the phase control. Undo and redo records never move the step (neither forward nor back); `done` stays `done`.
    ///
    /// - Parameters:
    ///   - record: the record of the accepted move, undo or redo.
    ///   - stage: the play's stage after the action.
    ///   - hintRibbon: the ribbon (0 … 2) of the level-1 hint after the action, named by the next `phase` step.
    public func advanced(by record: AuroraLoomRecord, stage: AuroraLoomStage, hintRibbon: Int) -> Self {
        if self == .done { return .done }
        if stage == .won { return .done }
        guard record.kind == .move else { return self }
        switch self {
        case .wave: return record.control == .wave ? .phase(ribbon: hintRibbon) : self
        case .phase: return record.control == .phase ? .harmony : self
        case .harmony, .done: return self
        }
    }
}

/// The mode a level is played in.
public enum AuroraLoomMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's allowance; a win records stars and opens the next level.
    case campaign
    /// Practice: the allowance raised to the kernel maximum (64); never awards stars or opens levels.
    case practice
    /// The daily level `level` (1 … 100), chosen by ``AuroraLoomProgress/dailyLevel(year:month:day:)``.
    case daily(level: Int)
}

/// The campaign progress of Aurora Loom: the solved levels with their best results and the open frontier.
public struct AuroraLoomProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one solved level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The fewest moves that won the level.
        public let bestMoves: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int

        /// A result of the given values (not checked).
        public init(bestMoves: Int, stars: Int) {
            self.bestMoves = bestMoves
            self.stars = stars
        }
    }

    /// The number of levels.
    public static let levelCount = 100
    /// The levels in each band (five bands of 20).
    public static let bandSize = 20
    /// The year of the daily level's day 0 (2026-01-01).
    public static let dailyEpochYear = 2026
    /// The calendar years accepted by the daily level.
    public static let dailyYears: ClosedRange<Int> = 1...9999

    /// The solved levels (1 … 100) and their best results.
    public private(set) var solved: [Int: Result]
    /// The highest open level, 1 … 100; every level 1 … `frontier` is open. Settable (a snapshot migration sets it).
    public var frontier: Int

    /// No level solved; level 1 open.
    public init() {
        solved = [:]
        frontier = 1
    }

    /// Whether `level` is open: 1 ≤ level ≤ ``frontier``.
    public func isOpen(_ level: Int) -> Bool { level >= 1 && level <= frontier }

    /// The stars of a win in `moves` moves on a level whose certified shortest solution is `shortest`: 3 when
    /// `moves ≤ shortest`, 2 when `moves ≤ shortest + 2`, otherwise 1 (research R5).
    public static func stars(moves: Int, shortest: Int) -> Int {
        if moves <= shortest { return 3 }
        if moves <= shortest + 2 { return 2 }
        return 1
    }

    /// Records a campaign win of `level` in `moves` moves (certified shortest `shortest`): keeps the fewer best moves
    /// and the more stars of the old and new result, and opens `level + 1` (at most 100). A level outside 1 … 100 is
    /// ignored. The caller records only campaign wins of open levels (practice never records).
    public mutating func record(level: Int, moves: Int, shortest: Int) {
        guard level >= 1 && level <= Self.levelCount else { return }
        let stars: Int = Self.stars(moves: moves, shortest: shortest)
        if let old = solved[level] {
            solved[level] = Result(bestMoves: min(old.bestMoves, moves), stars: max(old.stars, stars))
        } else {
            solved[level] = Result(bestMoves: moves, stars: stars)
        }
        frontier = max(frontier, min(level + 1, Self.levelCount))
    }

    /// The band (1 … 5) of `level`; a level outside 1 … 100 is clamped into that range first.
    public static func band(of level: Int) -> Int {
        let clamped: Int = min(max(level, 1), levelCount)
        return (clamped - 1) / bandSize + 1
    }

    /// The daily level (1 … 100) of a calendar date: (d × 37) mod 100 + 1, where d is the days from 2026-01-01 to the
    /// date (negative before it) and the modulo is non-negative, counted in integer arithmetic on the proleptic
    /// Gregorian calendar (no clock, no time zone, no Foundation calendar). Every valid date of the years 1 … 9999 maps
    /// to a level; nil only for an invalid date (year outside 1 … 9999, month outside 1 … 12, day outside the month).
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? {
        guard dailyYears.contains(year), month >= 1 && month <= 12 else { return nil }
        guard day >= 1 && day <= daysIn(month: month, year: year) else { return nil }
        let days: Int = daysFromCivil(year: year, month: month, day: day)
            - daysFromCivil(year: dailyEpochYear, month: 1, day: 1)
        return ((days * 37) % levelCount + levelCount) % levelCount + 1
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

    /// The stable bytes of the progress for a digest: the frontier (one byte), the number of solved levels (one byte),
    /// then for each solved level in increasing order the level (one byte), the best moves (two bytes, big-endian) and
    /// the stars (one byte). Equal progress gives equal bytes regardless of dictionary order.
    public var digestBytes: [UInt8] {
        var bytes: [UInt8] = [UInt8(truncatingIfNeeded: frontier), UInt8(truncatingIfNeeded: solved.count)]
        for level in solved.keys.sorted() {
            guard let result = solved[level] else { continue }
            bytes.append(UInt8(truncatingIfNeeded: level))
            bytes.append(UInt8(truncatingIfNeeded: result.bestMoves >> 8))
            bytes.append(UInt8(truncatingIfNeeded: result.bestMoves))
            bytes.append(UInt8(truncatingIfNeeded: result.stars))
        }
        return bytes
    }

    /// The JSON encoding with sorted keys; equal progress gives equal data (solved levels are an array sorted by level).
    public func encoded() throws -> Data {
        let encoder: JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// One solved level as encoded.
    private struct Entry: Codable {
        let level: Int
        let bestMoves: Int
        let stars: Int
    }

    private enum CodingKeys: String, CodingKey {
        case solved
        case frontier
    }

    /// Decodes progress; the solved levels are an array of `{level, bestMoves, stars}`.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for a frontier outside 1 … 100, a level outside 1 … 100 or repeated,
    ///   stars outside 1 … 3 or negative best moves.
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
            solved[entry.level] = Result(bestMoves: entry.bestMoves, stars: entry.stars)
        }
        self.solved = solved
        self.frontier = frontier
    }

    /// Encodes the frontier and the solved levels as an array sorted by level.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frontier, forKey: .frontier)
        var entries: [Entry] = []
        for level in solved.keys.sorted() {
            guard let result = solved[level] else { continue }
            entries.append(Entry(level: level, bestMoves: result.bestMoves, stars: result.stars))
        }
        try container.encode(entries, forKey: .solved)
    }
}
