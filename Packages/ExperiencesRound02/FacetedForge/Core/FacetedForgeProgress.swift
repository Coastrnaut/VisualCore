// FacetedForgeProgress — feature 375 (R02-G08-05) T-R02G0805-003 (FR-R02G0805-001, 004, 005; SC-R02G0805-001, 004;
// clarifications Q2, Q3, Q4). Player teaching and progression of Faceted Forge: the three-instruction tutorial (aim,
// match, finish) shown on levels 1 … 3, which advances on an accepted cut, then on a second accepted cut, and at the
// end of the level, and never moves back on undo or redo; the play mode (campaign, practice, daily); and the campaign
// progress — per won level the fewest cuts made (the play's cut records, undone ones included) and the stars (3 at
// most the certified smallest cut count, 2 at most that + 2, otherwise 1), and the open frontier (level 1 open; a
// campaign win opens the next level, up to 100). The daily level is a function of a calendar day without any clock:
// (days from 2026-01-01 × 67) mod 100 + 1, in integer arithmetic on the proleptic Gregorian calendar. Every type is
// Codable with a stable, explicit form. Modelled on feature 365's AmethystEscapeProgress.
// Feature 377 (R02-G08-07) T-R02G0807-002 (FR-R02G0807-001, 002; clarifications Q1, Q2): a result carries the trace of
// its win (the effective cuts: undone cuts left out unless redone) and whether it is verified (a win recorded with a
// trace); `drop(level:)` removes a result that failed reconciliation; the replay mode (a saved trace played back)
// awards nothing and opens nothing. Encodings without trace or verified (schema 1 and 2) decode as unverified results
// with an empty trace. Modelled on feature 367's AmethystEscapeProgress.
import Foundation

/// The step of the Faceted Forge tutorial (levels 1 … 3).
///
/// The tutorial shows one instruction at a time: `aim` → `match` → `finish` → `done`. `aim` advances on an accepted
/// cut; `match` advances on a second accepted cut; every step ends when the level ends (won or failed), so a level that
/// ends before a step is reached goes straight to `done`. Dismissing ends it. Undo and redo never move the step.
/// Encoded as its raw name.
public enum FacetedForgeTutorialStep: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// Teaches choosing a piece, aiming the ruby plane and cutting.
    case aim
    /// Teaches the goal of each cut: match the target's shares and face counts; slivers end the play.
    case match
    /// Teaches finishing: match every target piece before the cuts run out.
    case finish
    /// The tutorial is over.
    case done

    /// The levels that carry the tutorial: 1 … 3.
    public static let tutorialLevels: ClosedRange<Int> = 1...3

    /// The step a play starts at: `aim` on a tutorial level, else `done`.
    ///
    /// - Parameter tutorial: whether the level carries the tutorial (``FacetedForgeLevel/tutorial``).
    public static func initial(tutorial: Bool) -> Self {
        tutorial ? .aim : .done
    }

    /// The step a play of level number `level` starts at: `aim` on the tutorial levels 1 … 3, else `done`.
    public static func initial(level: Int) -> Self {
        initial(tutorial: tutorialLevels.contains(level))
    }

    /// The instruction shown for the step (clarification Q2, word for word); empty for `done`.
    public var text: String {
        switch self {
        case .aim:
            "Choose a piece and aim the ruby plane — drag its rim to tilt it, drag inside it to slide it, or use the "
                + "panel — then tap the plane (or Cut) to split the piece; a hint shows where"
        case .match:
            "Each cut adds one piece: match the target's shares and face counts exactly; a piece thinner than 1/64 of "
                + "the crystal ends the play"
        case .finish:
            "Match every target piece before the cuts run out"
        case .done: ""
        }
    }

    /// The step after an accepted action or the end of the level.
    ///
    /// - Parameters:
    ///   - afterCut: whether the accepted action was a cut (an undo or redo passes false and never moves the step).
    ///   - ended: whether the level has ended (won or failed); then the step is `done` whatever `afterCut` is.
    public func advanced(afterCut: Bool, ended: Bool) -> Self {
        if ended { return .done }
        guard afterCut else { return self }
        switch self {
        case .aim: return .match
        case .match: return .finish
        case .finish, .done: return self
        }
    }

    /// The step after the player dismissed the tutorial: always `done`.
    public func dismissed() -> Self { .done }
}

/// The mode a level is played in (clarification Q4).
public enum FacetedForgeMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's budget; a win records stars and opens the next level.
    case campaign
    /// Practice: the budget raised to the kernel maximum (20); never awards stars or opens levels.
    case practice
    /// The daily level `level` (1 … 100) of ``FacetedForgeProgress/dailyLevel(year:month:day:)``: campaign rules, but
    /// a win never opens a level.
    case daily(level: Int)
    /// The replay of the saved verified trace of level `level` (1 … 100): the campaign budget; never awards stars or
    /// opens levels.
    case replay(level: Int)

    /// The cut budget of practice mode: the kernel's maximum, 20 (``FacetedForgeLevel/budgets``).
    public static let practiceBudget: Int = FacetedForgeLevel.budgets.upperBound

    /// The budget a level with budget `base` is played with: ``practiceBudget`` in practice, `base` otherwise
    /// (campaign, daily and replay).
    public func budget(base: Int) -> Int {
        self == .practice ? Self.practiceBudget : base
    }

    /// Whether a win in this mode records a result and stars: campaign and daily (never practice or replay).
    public var awardsStars: Bool {
        switch self {
        case .campaign, .daily: true
        case .practice, .replay: false
        }
    }

    /// Whether a win in this mode opens the next level: campaign only.
    public var opensLevels: Bool { self == .campaign }

    private enum CodingKeys: String, CodingKey {
        case mode
        case level
    }

    /// Decodes `{"mode": "campaign"}`, `{"mode": "practice"}`, `{"mode": "daily", "level": n}` or
    /// `{"mode": "replay", "level": n}`.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for an unknown mode name or a daily or replay level outside 1 … 100;
    ///   `DecodingError.keyNotFound` for a daily or replay mode without a level.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name: String = try container.decode(String.self, forKey: .mode)
        switch name {
        case "campaign": self = .campaign
        case "practice": self = .practice
        case "daily":
            let level: Int = try container.decode(Int.self, forKey: .level)
            guard level >= 1 && level <= FacetedForgeProgress.levelCount else {
                throw DecodingError.dataCorruptedError(forKey: .level, in: container,
                                                       debugDescription: "daily level outside 1 … 100")
            }
            self = .daily(level: level)
        case "replay":
            let level: Int = try container.decode(Int.self, forKey: .level)
            guard level >= 1 && level <= FacetedForgeProgress.levelCount else {
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

/// The campaign progress of Faceted Forge: the won levels with their best results and the open frontier.
///
/// Encoded as `{"frontier": n, "solved": [{"cutsMade": c, "level": l, "stars": s, "trace": [...], "verified": v}, …]}`
/// with the won levels as an array sorted by level, so equal progress gives equal JSON (``encoded()`` also sorts the
/// keys). An entry without `trace` or `verified` (schema 1 and 2) decodes with an empty trace, unverified.
public struct FacetedForgeProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one won level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The fewest cuts made at a win (the play's cut records, undone cuts included).
        public let cutsMade: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int
        /// The effective cuts of the winning play (undone cuts left out unless redone); empty for a result recorded
        /// without a trace.
        public let trace: [FacetedForgeAction]
        /// Whether the result was recorded with a trace (reconciliation replays it on restore).
        public let verified: Bool

        /// A result of the given values without a trace, unverified (not checked).
        public init(cutsMade: Int, stars: Int) {
            self.init(cutsMade: cutsMade, stars: stars, trace: [], verified: false)
        }

        /// A result of the given values (not checked).
        public init(cutsMade: Int, stars: Int, trace: [FacetedForgeAction], verified: Bool) {
            self.cutsMade = cutsMade
            self.stars = stars
            self.trace = trace
            self.verified = verified
        }

        private enum CodingKeys: String, CodingKey {
            case cutsMade
            case stars
            case trace
            case verified
        }

        /// Decodes a result; a missing `trace` is empty and a missing `verified` is false.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            cutsMade = try container.decode(Int.self, forKey: .cutsMade)
            stars = try container.decode(Int.self, forKey: .stars)
            trace = try container.decodeIfPresent([FacetedForgeAction].self, forKey: .trace) ?? []
            verified = try container.decodeIfPresent(Bool.self, forKey: .verified) ?? false
        }

        /// Encodes every field, the trace and the verified flag included.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(cutsMade, forKey: .cutsMade)
            try container.encode(stars, forKey: .stars)
            try container.encode(trace, forKey: .trace)
            try container.encode(verified, forKey: .verified)
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
    /// from the other round-two games' 37, 41, 43, 47, 53, 59 and 61).
    public static let dailyMultiplier: Int = 67
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

    /// The stars of a win with `cutsMade` cuts made on a level whose certified smallest cut count is `smallest`: 3
    /// when `cutsMade ≤ smallest`, 2 when `cutsMade ≤ smallest + 2`, otherwise 1.
    public static func stars(cutsMade: Int, smallest: Int) -> Int {
        if cutsMade <= smallest { return 3 }
        if cutsMade <= smallest + 2 { return 2 }
        return 1
    }

    /// The cuts made in `play`: the number of its cut records (undone cuts included; undo and redo records are not
    /// cuts).
    public static func cutsMade(_ play: FacetedForgePlay) -> Int {
        var count: Int = 0
        for record in play.records where record.kind == .cut { count += 1 }
        return count
    }

    /// Records a win of `level` with `cutsMade` cuts made (certified smallest cut count `smallest`) in `mode`.
    ///
    /// The result has no trace and is unverified. Practice and replay record nothing. In campaign and daily mode the
    /// new result replaces a stored one only when it is better (fewer cuts made, then more stars); a worse or equal
    /// result keeps the stored one. A campaign win raises the frontier to `level + 1` (at most 100); it never falls; a
    /// daily win opens nothing. A level outside 1 … 100 is ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, cutsMade: Int, smallest: Int, mode: FacetedForgeMode = .campaign) -> Bool {
        let result: Result = Result(cutsMade: cutsMade, stars: Self.stars(cutsMade: cutsMade, smallest: smallest))
        return store(result, level: level, mode: mode)
    }

    /// Records a verified win of `level` with `cutsMade` cuts made (certified smallest cut count `smallest`) in `mode`,
    /// with `trace`, the effective cuts of the winning play (``FacetedForgeReconciliation/netTrace(_:)``).
    ///
    /// The rules of ``record(level:cutsMade:smallest:mode:)`` apply: practice and replay record nothing; the result
    /// replaces a stored one only when it is better (fewer cuts made, then more stars), so a tie keeps the earlier
    /// result and its trace; a campaign win raises the frontier; a level outside 1 … 100 is ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, cutsMade: Int, smallest: Int, mode: FacetedForgeMode = .campaign,
                                trace: [FacetedForgeAction]) -> Bool {
        let result: Result = Result(cutsMade: cutsMade, stars: Self.stars(cutsMade: cutsMade, smallest: smallest),
                                    trace: trace, verified: true)
        return store(result, level: level, mode: mode)
    }

    /// Removes the result of `level` (reconciliation drops a result whose trace does not replay); the frontier is
    /// unchanged. Nothing happens when `level` has no result.
    public mutating func drop(level: Int) {
        solved[level] = nil
    }

    /// Stores `result` for `level` in `mode` under the rules of ``record(level:cutsMade:smallest:mode:)``.
    private mutating func store(_ result: Result, level: Int, mode: FacetedForgeMode) -> Bool {
        guard level >= 1 && level <= Self.levelCount, mode.awardsStars else { return false }
        var improved: Bool = false
        if let old = solved[level] {
            let fewer: Bool = result.cutsMade < old.cutsMade
            let moreStars: Bool = result.cutsMade == old.cutsMade && result.stars > old.stars
            if fewer || moreStars {
                solved[level] = result
                improved = true
            }
        } else {
            solved[level] = result
            improved = true
        }
        if mode.opensLevels { frontier = max(frontier, min(level + 1, Self.levelCount)) }
        return improved
    }

    /// The daily level (1 … 100) of a calendar day: (d × 67) mod 100 + 1, where d is the days from 2026-01-01 to the
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

    /// One won level as encoded; `trace` and `verified` are absent in schema 1 and 2 encodings.
    private struct Entry: Codable {
        let level: Int
        let cutsMade: Int
        let stars: Int
        let trace: [FacetedForgeAction]?
        let verified: Bool?
    }

    private enum CodingKeys: String, CodingKey {
        case solved
        case frontier
    }

    /// Decodes progress; the won levels are an array of `{level, cutsMade, stars, trace, verified}`, where a missing
    /// trace is empty and a missing verified flag is false.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for a frontier outside 1 … 100, a level outside 1 … 100 or repeated,
    ///   stars outside 1 … 3 or cuts made below 0.
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
                  entry.stars >= 1 && entry.stars <= 3, entry.cutsMade >= 0 else {
                throw DecodingError.dataCorruptedError(forKey: .solved, in: container,
                                                       debugDescription: "invalid won level \(entry.level)")
            }
            solved[entry.level] = Result(cutsMade: entry.cutsMade, stars: entry.stars, trace: entry.trace ?? [],
                                         verified: entry.verified ?? false)
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
            entries.append(Entry(level: level, cutsMade: result.cutsMade, stars: result.stars, trace: result.trace,
                                 verified: result.verified))
        }
        try container.encode(entries, forKey: .solved)
    }
}
