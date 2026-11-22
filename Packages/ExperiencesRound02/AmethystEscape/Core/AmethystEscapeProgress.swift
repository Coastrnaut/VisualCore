// AmethystEscapeProgress — feature 365 (R02-G07-05) T-R02G0705-003 (FR-R02G0705-001, 004, 005; SC-R02G0705-001, 004;
// clarifications Q2, Q3, Q4). Player teaching and progression of Amethyst Escape: the three-instruction tutorial (turn,
// advance, escape) shown on levels 1 … 3 in every mode, which advances on any accepted move (a turn or an advance), then
// on an accepted advance, and at the end of the level, and never moves back on undo or redo; the play mode (campaign,
// practice, daily); and the campaign progress — per won level the fewest moves at the win and the stars (3 at most the
// certified smallest move count, 2 at most that + 2, otherwise 1), and the open frontier (level 1 open; a campaign win
// opens the next level, up to 100). The daily level is a clock-free function of a calendar date: (days from 2026-01-01
// × 61) mod 100 + 1, in integer arithmetic on the proleptic Gregorian calendar. Every type is Codable with a stable,
// explicit form. Modelled on feature 355's ChronoConstellatorProgress.
// Feature 367 (R02-G07-07) T-R02G0707-002 (clarifications Q1 … Q3): a result carries the net trace of its win and
// whether it is verified (a win recorded with a trace); `drop(level:)` removes a result that failed reconciliation;
// the replay mode (a saved trace played back) awards nothing and opens nothing. Encodings without trace or verified
// (schema 1 and 2) decode as unverified results with an empty trace. Modelled on feature 357's
// ChronoConstellatorProgress.
import Foundation

/// The step of the Amethyst Escape tutorial (levels 1 … 3, in every mode).
///
/// The tutorial shows one instruction at a time: `turn` → `advance` → `escape` → `done`. `turn` advances on any accepted
/// move (a turn or an advance); `advance` advances on an accepted advance; every step ends when the level ends (won or
/// failed), so a level that ends before a step is reached goes straight to `done`. Dismissing ends it. Undo and redo
/// never move the step. Encoded as its raw name.
public enum AmethystEscapeTutorialStep: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// Teaches turning a shell to line an opening up with the pearl.
    case turn
    /// Teaches rolling the pearl one pocket with a tap or Advance.
    case advance
    /// Teaches the goal: lead the pearl out through the outer exit gap within the budget, avoiding dark wedges.
    case escape
    /// The tutorial is over.
    case done

    /// The levels that carry the tutorial: 1 … 3.
    public static let tutorialLevels: ClosedRange<Int> = 1...3

    /// The step a play of level `level` starts at: `turn` on the tutorial levels 1 … 3 (in every mode), else `done`.
    public static func initial(level: Int) -> Self {
        tutorialLevels.contains(level) ? .turn : .done
    }

    /// The instruction shown for the step (clarification Q2, word for word); empty for `done`.
    public var text: String {
        switch self {
        case .turn:
            "Drag a shell round the centre (or use Turn − and +) to line an opening up with the pearl, or roll the "
                + "pearl when its way is open; a hint shows which"
        case .advance:
            "Tap the pearl (or Advance) to roll it one pocket: out through an opening, else clockwise until a wall "
                + "stops it"
        case .escape:
            "Lead the pearl out through the exit gap of the outer shell before the moves run out; dark wedges with a "
                + "cross end the play"
        case .done: ""
        }
    }

    /// The step after an accepted record of `kind` (nil when no record was made) or the end of the level.
    ///
    /// - Parameters:
    ///   - kind: the kind of the accepted record: a rotate or an advance on `turn` advances to `advance`; an advance on
    ///     `advance` advances to `escape`; an undo or redo never moves the step.
    ///   - ended: whether the level has ended (won or failed); then the step is `done` whatever `kind` is.
    public func advanced(after kind: AmethystEscapeRecordKind?, ended: Bool) -> Self {
        if ended { return .done }
        switch (self, kind) {
        case (.turn, .rotate?), (.turn, .advance?): return .advance
        case (.advance, .advance?): return .escape
        default: return self
        }
    }

    /// The step after the player dismissed the tutorial: always `done`.
    public func dismissed() -> Self { .done }
}

/// The mode a level is played in (clarification Q4).
public enum AmethystEscapeMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's budget; a win records stars and opens the next level.
    case campaign
    /// Practice: the budget raised to the kernel maximum (60); never awards stars or opens levels.
    case practice
    /// The daily level `level` (1 … 100) of ``AmethystEscapeProgress/dailyLevel(year:month:day:)``: campaign rules, but
    /// a win never opens a level.
    case daily(level: Int)
    /// The replay of the saved verified trace of level `level` (1 … 100): the campaign budget; never awards stars or
    /// opens levels.
    case replay(level: Int)

    /// The move budget of practice mode: the kernel's maximum, 60.
    public static let practiceBudget: Int = 60

    /// The budget a level with budget `base` is played with: ``practiceBudget`` in practice, `base` otherwise.
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
            guard level >= 1 && level <= AmethystEscapeProgress.levelCount else {
                throw DecodingError.dataCorruptedError(forKey: .level, in: container,
                                                       debugDescription: "daily level outside 1 … 100")
            }
            self = .daily(level: level)
        case "replay":
            let level: Int = try container.decode(Int.self, forKey: .level)
            guard level >= 1 && level <= AmethystEscapeProgress.levelCount else {
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

/// The campaign progress of Amethyst Escape: the won levels with their best results and the open frontier.
///
/// Encoded as `{"frontier": n, "solved": [{"bestMoves": m, "level": l, "stars": s, "trace": [...], "verified": v}, …]}`
/// with the won levels as an array sorted by level, so equal progress gives equal JSON (``encoded()`` also sorts the
/// keys). An entry without `trace` or `verified` (schema 1 and 2) decodes with an empty trace, unverified.
public struct AmethystEscapeProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one won level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The fewest moves spent at a win.
        public let bestMoves: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int
        /// The net actions of the winning play (no undo or redo); empty for a result recorded without a trace.
        public let trace: [AmethystEscapeAction]
        /// Whether the result was recorded with a trace (reconciliation replays it on restore).
        public let verified: Bool

        /// A result of the given values without a trace, unverified (not checked).
        public init(bestMoves: Int, stars: Int) {
            self.init(bestMoves: bestMoves, stars: stars, trace: [], verified: false)
        }

        /// A result of the given values (not checked).
        public init(bestMoves: Int, stars: Int, trace: [AmethystEscapeAction], verified: Bool) {
            self.bestMoves = bestMoves
            self.stars = stars
            self.trace = trace
            self.verified = verified
        }

        private enum CodingKeys: String, CodingKey {
            case bestMoves
            case stars
            case trace
            case verified
        }

        /// Decodes a result; a missing `trace` is empty and a missing `verified` is false.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            bestMoves = try container.decode(Int.self, forKey: .bestMoves)
            stars = try container.decode(Int.self, forKey: .stars)
            trace = try container.decodeIfPresent([AmethystEscapeAction].self, forKey: .trace) ?? []
            verified = try container.decodeIfPresent(Bool.self, forKey: .verified) ?? false
        }

        /// Encodes every field, the trace and the verified flag included.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(bestMoves, forKey: .bestMoves)
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
    /// from the other round-two games' 37, 41, 43, 47, 53 and 59).
    public static let dailyMultiplier: Int = 61
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

    /// The stars of a win with `moves` moves spent on a level whose certified smallest move count is `smallest`: 3
    /// when `moves ≤ smallest`, 2 when `moves ≤ smallest + 2`, otherwise 1.
    public static func stars(moves: Int, smallest: Int) -> Int {
        if moves <= smallest { return 3 }
        if moves <= smallest + 2 { return 2 }
        return 1
    }

    /// Records a win of `level` with `moves` moves spent (certified smallest move count `smallest`) in `mode`.
    ///
    /// The result has no trace and is unverified. Practice and replay record nothing. In campaign and daily mode the
    /// new result replaces a stored one only when it is better (fewer moves or more stars); a worse or equal result
    /// keeps the stored one. A campaign win raises the frontier to `level + 1` (at most 100); it never falls; a daily
    /// win opens nothing. A level outside 1 … 100 is ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, moves: Int, smallest: Int, mode: AmethystEscapeMode = .campaign) -> Bool {
        let result: Result = Result(bestMoves: moves, stars: Self.stars(moves: moves, smallest: smallest))
        return store(result, level: level, mode: mode)
    }

    /// Records a verified win of `level` with `moves` moves spent (certified smallest move count `smallest`) in `mode`,
    /// with `trace`, the net actions of the winning play.
    ///
    /// The rules of ``record(level:moves:smallest:mode:)`` apply: practice and replay record nothing; the result
    /// replaces a stored one only when it is better (fewer moves or more stars), so a tie keeps the earlier trace; a
    /// campaign win raises the frontier; a level outside 1 … 100 is ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, moves: Int, smallest: Int, mode: AmethystEscapeMode = .campaign,
                                trace: [AmethystEscapeAction]) -> Bool {
        let result: Result = Result(bestMoves: moves, stars: Self.stars(moves: moves, smallest: smallest),
                                    trace: trace, verified: true)
        return store(result, level: level, mode: mode)
    }

    /// Removes the result of `level` (reconciliation drops a result whose trace does not replay); the frontier is
    /// unchanged. Nothing happens when `level` has no result.
    public mutating func drop(level: Int) {
        solved[level] = nil
    }

    /// Stores `result` for `level` in `mode` under the rules of ``record(level:moves:smallest:mode:)``.
    private mutating func store(_ result: Result, level: Int, mode: AmethystEscapeMode) -> Bool {
        guard level >= 1 && level <= Self.levelCount, mode.awardsStars else { return false }
        var improved: Bool = false
        if let old = solved[level] {
            if result.bestMoves < old.bestMoves || result.stars > old.stars {
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

    /// The daily level (1 … 100) of a calendar date: (d × 61) mod 100 + 1, where d is the days from 2026-01-01 to the
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

    /// One won level as encoded; `trace` and `verified` are absent in schema 1 and 2 encodings.
    private struct Entry: Codable {
        let level: Int
        let bestMoves: Int
        let stars: Int
        let trace: [AmethystEscapeAction]?
        let verified: Bool?
    }

    private enum CodingKeys: String, CodingKey {
        case solved
        case frontier
    }

    /// Decodes progress; the won levels are an array of `{level, bestMoves, stars, trace, verified}`, where a missing
    /// trace is empty and a missing verified flag is false.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for a frontier outside 1 … 100, a level outside 1 … 100 or repeated,
    ///   stars outside 1 … 3 or best moves below 0.
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
                                                       debugDescription: "invalid won level \(entry.level)")
            }
            solved[entry.level] = Result(bestMoves: entry.bestMoves, stars: entry.stars, trace: entry.trace ?? [],
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
            entries.append(Entry(level: level, bestMoves: result.bestMoves, stars: result.stars, trace: result.trace,
                                 verified: result.verified))
        }
        try container.encode(entries, forKey: .solved)
    }
}
