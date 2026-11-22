// NocturneGardenProgress — feature 385 (R02-G09-05) T-R02G0905-003 (FR-R02G0905-001, 004, 005; SC-R02G0905-001, 004;
// clarifications Q2, Q3, Q4). Player teaching and progression of Nocturne Garden: the three-instruction tutorial
// (plant, shape, finish) shown on levels 1 … 3, which advances on an accepted move, then on a second accepted move or
// the end of the level, and at the end of the level, and never moves back on undo or redo; the play mode (campaign,
// practice, daily); and the campaign progress — per won level the fewest moves made (the play's action records: plant,
// move, resize, remove and sun, undone ones included) and the stars (3 at most the certified smallest move count, 2 at
// most that + 2, otherwise 1), and the open frontier (level 1 open; a campaign win opens the next level, up to 100).
// The daily level is a function of a calendar day without any clock: (days from 2026-01-01 × 71) mod 100 + 1, in
// integer arithmetic on the proleptic Gregorian calendar. Every type is Codable with a stable, explicit form. Modelled
// on feature 375's FacetedForgeProgress.
import Foundation

/// The step of the Nocturne Garden tutorial (levels 1 … 3).
///
/// The tutorial shows one instruction at a time: `plant` → `shape` → `finish` → `done`. `plant` advances on an accepted
/// move; `shape` advances on a second accepted move; every step ends when the level ends (won or failed), so a level
/// that ends before a step is reached goes straight to `done`. Dismissing ends it. Undo and redo never move the step.
/// Encoded as its raw name.
public enum NocturneGardenTutorialStep: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// Teaches planting a bloom on the mist and its black shadow.
    case plant
    /// Teaches shaping the shadow: moving, resizing, the lantern, the gold outline and the coral cells.
    case shape
    /// Teaches finishing: reach the required match before the moves run out.
    case finish
    /// The tutorial is over.
    case done

    /// The levels that carry the tutorial: 1 … 3.
    public static let tutorialLevels: ClosedRange<Int> = 1...3

    /// The step a play starts at: `plant` on a tutorial level, else `done`.
    ///
    /// - Parameter tutorial: whether the level carries the tutorial (``NocturneGardenLevel/tutorial``).
    public static func initial(tutorial: Bool) -> Self {
        tutorial ? .plant : .done
    }

    /// The step a play of level number `level` starts at: `plant` on the tutorial levels 1 … 3, else `done`.
    public static func initial(level: Int) -> Self {
        initial(tutorial: tutorialLevels.contains(level))
    }

    /// The instruction shown for the step (clarification Q2, word for word); empty for `done`.
    public var text: String {
        switch self {
        case .plant:
            "Tap a cell of the mist to plant a bloom there (or use the panel); its black shadow falls on the mist — a "
                + "hint shows where"
        case .shape:
            "Drag a bloom to move it, pinch it to resize it, drag the lantern to lengthen every shadow; match the gold "
                + "outline without letting the shadow touch the coral cells"
        case .finish:
            "Reach the required match before the moves run out"
        case .done: ""
        }
    }

    /// The step after an accepted action or the end of the level.
    ///
    /// - Parameters:
    ///   - afterMove: whether the accepted action was a move (plant, move, resize, remove or sun); an undo or redo
    ///     passes false and never moves the step.
    ///   - ended: whether the level has ended (won or failed); then the step is `done` whatever `afterMove` is.
    public func advanced(afterMove: Bool, ended: Bool) -> Self {
        if ended { return .done }
        guard afterMove else { return self }
        switch self {
        case .plant: return .shape
        case .shape: return .finish
        case .finish, .done: return self
        }
    }

    /// The step after the player dismissed the tutorial: always `done`.
    public func dismissed() -> Self { .done }
}

/// The mode a level is played in (clarification Q4).
public enum NocturneGardenMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's budget; a win records stars and opens the next level.
    case campaign
    /// Practice: the budget raised to the kernel maximum (40); never awards stars or opens levels.
    case practice
    /// The daily level `level` (1 … 100) of ``NocturneGardenProgress/dailyLevel(year:month:day:)``: campaign rules,
    /// but a win never opens a level.
    case daily(level: Int)

    /// The move budget of practice mode: the kernel's maximum, 40 (``NocturneGardenLevel/budgets``).
    public static let practiceBudget: Int = NocturneGardenLevel.budgets.upperBound

    /// The budget a level with budget `base` is played with: ``practiceBudget`` in practice, `base` otherwise
    /// (campaign and daily).
    public func budget(base: Int) -> Int {
        self == .practice ? Self.practiceBudget : base
    }

    /// Whether a win in this mode records a result and stars: campaign and daily (never practice).
    public var awardsStars: Bool { self != .practice }

    /// Whether a win in this mode opens the next level: campaign only.
    public var opensLevels: Bool { self == .campaign }

    private enum CodingKeys: String, CodingKey {
        case mode
        case level
    }

    /// Decodes `{"mode": "campaign"}`, `{"mode": "practice"}` or `{"mode": "daily", "level": n}`.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for an unknown mode name or a daily level outside 1 … 100;
    ///   `DecodingError.keyNotFound` for a daily mode without a level.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name: String = try container.decode(String.self, forKey: .mode)
        switch name {
        case "campaign": self = .campaign
        case "practice": self = .practice
        case "daily":
            let level: Int = try container.decode(Int.self, forKey: .level)
            guard level >= 1 && level <= NocturneGardenProgress.levelCount else {
                throw DecodingError.dataCorruptedError(forKey: .level, in: container,
                                                       debugDescription: "daily level outside 1 … 100")
            }
            self = .daily(level: level)
        default:
            throw DecodingError.dataCorruptedError(forKey: .mode, in: container,
                                                   debugDescription: "unknown mode \(name)")
        }
    }

    /// Encodes the mode as `{"mode": <name>}`, with `"level"` for `daily`.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .campaign: try container.encode("campaign", forKey: .mode)
        case .practice: try container.encode("practice", forKey: .mode)
        case .daily(let level):
            try container.encode("daily", forKey: .mode)
            try container.encode(level, forKey: .level)
        }
    }
}

/// The campaign progress of Nocturne Garden: the won levels with their best results and the open frontier.
///
/// Encoded as `{"frontier": n, "solved": [{"level": l, "movesMade": m, "stars": s}, …]}` with the won levels as an
/// array sorted by level, so equal progress gives equal JSON (``encoded()`` also sorts the keys).
public struct NocturneGardenProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one won level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The fewest moves made at a win (the play's action records, undone moves included).
        public let movesMade: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int

        /// A result of the given values (not checked).
        public init(movesMade: Int, stars: Int) {
            self.movesMade = movesMade
            self.stars = stars
        }
    }

    /// The number of levels.
    public static let levelCount: Int = 100
    /// The number of levels per difficulty band.
    public static let levelsPerBand: Int = 20
    /// The difficulty bands, 1 … 5, of 20 levels each.
    public static let bands: ClosedRange<Int> = 1...5
    /// The year of the daily level's day 0 (2026-01-01).
    public static let dailyEpochYear: Int = 2026
    /// The multiplier of the daily level (coprime with 100, so 100 consecutive days visit every level once; it differs
    /// from the other round-two games' 37, 41, 43, 47, 53, 59, 61 and 67).
    public static let dailyMultiplier: Int = 71
    /// The calendar years accepted by the daily level.
    public static let dailyYears: ClosedRange<Int> = 1...9999

    /// The won levels (1 … 100) and their best results.
    public private(set) var solved: [Int: Result]
    /// The highest open level, 1 … 100; every level 1 … `frontier` is open.
    public private(set) var frontier: Int

    /// No level won; level 1 open.
    public init() {
        solved = [:]
        frontier = 1
    }

    /// The band (1 … 5) of level `level` (1 … 100): levels 1 … 20 are band 1, …, 81 … 100 band 5; clamped outside.
    public static func band(of level: Int) -> Int {
        let clamped: Int = min(max(level, 1), levelCount)
        return (clamped - 1) / levelsPerBand + 1
    }

    /// Opens every level up to `level` (clamped to 1 … 100); the frontier never falls. The adapter opens the level a
    /// seed chose, so a session that starts beyond level 1 can play it.
    public mutating func open(through level: Int) {
        frontier = max(frontier, min(max(level, 1), Self.levelCount))
    }

    /// Whether `level` is open: 1 ≤ level ≤ ``frontier``.
    public func isOpen(_ level: Int) -> Bool { level >= 1 && level <= frontier }

    /// The next open level after `level` (`level + 1` when it is open), or nil when there is none (never past 100).
    public func nextOpen(after level: Int) -> Int? {
        let next: Int = max(level + 1, 1)
        return isOpen(next) ? next : nil
    }

    /// The stars of a win with `movesMade` moves made on a level whose certified smallest move count is `smallest`: 3
    /// when `movesMade ≤ smallest`, 2 when `movesMade ≤ smallest + 2`, otherwise 1.
    public static func stars(movesMade: Int, smallest: Int) -> Int {
        if movesMade <= smallest { return 3 }
        if movesMade <= smallest + 2 { return 2 }
        return 1
    }

    /// The moves made in `play`: the number of its action records (plant, move, resize, remove and sun; undone moves
    /// included; undo and redo records are not moves).
    public static func movesMade(_ play: NocturneGardenPlay) -> Int {
        var count: Int = 0
        for record in play.records where record.kind != .undo && record.kind != .redo { count += 1 }
        return count
    }

    /// Records a win of `level` with `movesMade` moves made (certified smallest move count `smallest`).
    ///
    /// The caller records only campaign and daily wins (never practice). The new result replaces a stored one only
    /// when it is better (fewer moves made, then more stars); a worse or equal result keeps the stored one. When
    /// `opensNext` is true (a campaign win) the frontier rises to `level + 1` (at most 100); it never falls; a daily
    /// win passes false and opens nothing. A level outside 1 … 100 is ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, movesMade: Int, smallest: Int, opensNext: Bool) -> Bool {
        guard level >= 1 && level <= Self.levelCount else { return false }
        let result: Result = Result(movesMade: movesMade, stars: Self.stars(movesMade: movesMade, smallest: smallest))
        var improved: Bool = false
        if let old = solved[level] {
            let fewer: Bool = result.movesMade < old.movesMade
            let moreStars: Bool = result.movesMade == old.movesMade && result.stars > old.stars
            if fewer || moreStars {
                solved[level] = result
                improved = true
            }
        } else {
            solved[level] = result
            improved = true
        }
        if opensNext { frontier = max(frontier, min(level + 1, Self.levelCount)) }
        return improved
    }

    /// Records a win of `level` in `mode` under the rules of ``record(level:movesMade:smallest:opensNext:)``:
    /// practice records nothing, campaign opens the next level, daily opens nothing.
    ///
    /// - Returns: whether the stored result of `level` changed.
    @discardableResult
    public mutating func record(level: Int, movesMade: Int, smallest: Int, mode: NocturneGardenMode) -> Bool {
        guard mode.awardsStars else { return false }
        return record(level: level, movesMade: movesMade, smallest: smallest, opensNext: mode.opensLevels)
    }

    /// The daily level (1 … 100) of a calendar day: (d × 71) mod 100 + 1, where d is the days from 2026-01-01 to the
    /// given day (negative before it) and the modulo is non-negative, counted in integer arithmetic on the proleptic
    /// Gregorian calendar (no clock, no time zone, no Foundation calendar). nil for an impossible day (year outside
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

    /// The days from 1970-01-01 to the proleptic Gregorian day (H. Hinnant's days-from-civil; years 1 … 9999).
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

    /// One won level as encoded.
    private struct Entry: Codable {
        let level: Int
        let movesMade: Int
        let stars: Int
    }

    private enum CodingKeys: String, CodingKey {
        case solved
        case frontier
    }

    /// Decodes progress; the won levels are an array of `{level, movesMade, stars}`.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for a frontier outside 1 … 100, a level outside 1 … 100 or repeated,
    ///   stars outside 1 … 3 or moves made below 0.
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
                  entry.stars >= 1 && entry.stars <= 3, entry.movesMade >= 0 else {
                throw DecodingError.dataCorruptedError(forKey: .solved, in: container,
                                                       debugDescription: "invalid won level \(entry.level)")
            }
            solved[entry.level] = Result(movesMade: entry.movesMade, stars: entry.stars)
        }
        self.solved = solved
        self.frontier = frontier
    }

    /// Encodes the frontier and the won levels as an array sorted by level.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frontier, forKey: .frontier)
        var entries: [Entry] = []
        for level in solved.keys.sorted() {
            guard let result = solved[level] else { continue }
            entries.append(Entry(level: level, movesMade: result.movesMade, stars: result.stars))
        }
        try container.encode(entries, forKey: .solved)
    }
}
