// StarlitCartoucheProgress — feature 455 (R02-G16-05) T-R02G1605-003 (FR-R02G1605-001, 004, 005, 006;
// SC-R02G1605-001, 004; clarifications Q2, Q3, Q4). Player teaching and progression of Starlit Cartouche: the
// three-instruction tutorial (fly, symbol, recover) shown on levels 1 … 3 — an accepted leg moves `fly` to `symbol`,
// a second accepted leg moves `symbol` to `recover`, the end of the level (a winning leg, a failing leg or a spent
// budget) moves any step to `done` — which never moves back on undo or redo; the play mode (campaign, practice,
// daily); and the campaign progress — per won level the least actions spent (every accepted leg record of the play,
// undone ones included) and the stars (3 at most the certified witness's leg count, 2 at most that + 2, otherwise 1),
// and the open frontier (level 1 open; a campaign win opens the next level, up to 100). No level is ever gated by
// payment: locked means not yet unlocked. The daily level is a function of a calendar day without any clock: (days
// from 2026-01-01 × 37) mod 100 + 1, negative day counts wrapped, in integer arithmetic on the proleptic Gregorian
// calendar. Every type is Codable with a stable, explicit form. Modelled on feature 445's VoxelOrigamiProgress.
// Integers only; no clock, no random source.
// Feature 457 (R02-G16-07) T-R02G1607-002 (contracts/api.md; research R2, R5, R6, R7): each result also keeps the trace
// of its win (the effective legs, each `.leg(star, wait)` as the kernel applied it; an undone leg is left out unless
// redone) and whether it is verified (a win recorded with a trace); `drop(level:)` removes a result that failed
// reconciliation (``StarlitCartoucheReconciliation``); the replay mode (a saved trace played back with the campaign
// budget) awards nothing and opens nothing. Encodings without trace or verified (snapshot schema 1 and 2) decode as
// unverified results with an empty trace. Modelled on feature 447's VoxelOrigamiProgress.
import Foundation

/// The step of the Starlit Cartouche tutorial (levels 1 … 3, the levels whose ``StarlitCartoucheLevel/tutorial`` is
/// set).
///
/// The tutorial shows one instruction at a time: `fly` → `symbol` → `recover` → `done`. `fly` advances on the first
/// accepted leg, `symbol` on the second accepted leg, `recover` lasts until the level ends. Every step ends when the
/// level ends (won or failed), so a level that ends before a step is reached goes straight to `done` (a leg that wins
/// ends the level). Dismissing ends it. Undo and redo never move the step back. Encoded as its raw name.
public enum StarlitCartoucheTutorialStep: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// Teaches choosing a star, setting the wait and flying a leg that draws a stroke.
    case fly
    /// Teaches drawing the whole symbol and ending at the beacon before the deadline, with a hint.
    case symbol
    /// Teaches that a broken window, a hazard, the deadline or a stray stroke fails the level and how to undo it.
    case recover
    /// The tutorial is over.
    case done

    /// The levels that carry the tutorial: 1 … 3 (``StarlitCartoucheLevel/tutorial``).
    public static let tutorialLevels: ClosedRange<Int> = 1...3

    /// The step a play starts at: `fly` on a tutorial level, else `done`.
    ///
    /// - Parameter tutorial: whether the level carries the tutorial (``StarlitCartoucheLevel/tutorial``).
    public static func initial(tutorial: Bool) -> Self {
        tutorial ? .fly : .done
    }

    /// The step a play of level number `level` starts at: `fly` on the tutorial levels 1 … 3, else `done`.
    public static func initial(level: Int) -> Self {
        initial(tutorial: tutorialLevels.contains(level))
    }

    /// The instruction shown for the step (clarification Q2, word for word); empty for `done`.
    public var text: String {
        switch self {
        case .fly:
            "Tap a star to choose where to fly, set the wait on the slider (or Wait − and +) so the star is in range "
                + "at launch, then double-tap it (or press Fly): the trail draws a stroke of the symbol"
        case .symbol:
            "Draw every stroke of the symbol and end at the beacon ring before the deadline — a hint shows which leg "
                + "is next"
        case .recover:
            "A leg that misses a star's window, crosses an active hazard tube, arrives after the deadline or flies a "
                + "corridor outside the symbol fails the level: undo and choose another star or wait"
        case .done: ""
        }
    }

    /// The step after an accepted action or the end of the level, in order, never back.
    ///
    /// - Parameters:
    ///   - afterLeg: whether an accepted leg was just applied; it moves `fly` to `symbol` and `symbol` to `recover`,
    ///     and leaves `recover` and `done`.
    ///   - ended: whether the level has ended (won or failed); then the step is `done` whatever `afterLeg` is.
    ///   An undo or a redo passes false for `afterLeg` and the play's real end: an undo always lands before the end,
    ///   so it never ends the tutorial, while a redo that restores a won or failed play ends it; no call ever moves
    ///   the step back.
    public func advanced(afterLeg: Bool, ended: Bool) -> Self {
        if ended { return .done }
        guard afterLeg else { return self }
        switch self {
        case .fly: return .symbol
        case .symbol: return .recover
        case .recover, .done: return self
        }
    }

    /// The step after the player dismissed the tutorial (`tutorial.dismiss`): always `done`.
    public func dismissed() -> Self { .done }
}

/// The mode a level is played in (clarification Q4).
public enum StarlitCartoucheMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's budget; a win records the best result and stars and opens the next level.
    case campaign
    /// Practice: the budget raised to the kernel maximum (24); never awards stars or opens levels.
    case practice
    /// The daily level `level` (1 … 100) of ``StarlitCartoucheProgress/dailyLevel(year:month:day:)``: campaign rules
    /// (a win records the level's best result and stars), but a win never opens a level.
    case daily(level: Int)
    /// The replay of the saved verified trace of level `level` (1 … 100): the campaign budget; never awards stars or
    /// opens levels.
    case replay(level: Int)

    /// The budget of practice mode: the kernel's maximum, 24 (``StarlitCartoucheLevel/budgets``).
    public static let practiceBudget: Int = StarlitCartoucheLevel.budgets.upperBound

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

    /// The keys of the encoded mode.
    private enum CodingKeys: String, CodingKey {
        /// The mode name: `campaign`, `practice`, `daily` or `replay`.
        case mode
        /// The daily or replayed level, 1 … 100 (daily and replay only).
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
            guard level >= 1 && level <= StarlitCartoucheProgress.levelCount else {
                throw DecodingError.dataCorruptedError(forKey: .level, in: container,
                                                       debugDescription: "daily level outside 1 … 100")
            }
            self = .daily(level: level)
        case "replay":
            let level: Int = try container.decode(Int.self, forKey: .level)
            guard level >= 1 && level <= StarlitCartoucheProgress.levelCount else {
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

/// The campaign progress of Starlit Cartouche: the won levels with their best results and the open frontier.
///
/// Encoded as `{"frontier": n, "solved": [{"actionsSpent": a, "level": l, "stars": s, "trace": [...], "verified": v},
/// …]}` with the won levels as an array sorted by level, so equal progress gives equal JSON (``encoded()`` also sorts
/// the keys). An entry without `trace` or `verified` (snapshot schema 1 and 2) decodes with an empty trace, unverified.
public struct StarlitCartoucheProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one won level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The least actions spent at a win (``StarlitCartoucheProgress/actionsSpent(_:)``: every accepted leg record,
        /// undone ones included).
        public let actionsSpent: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int
        /// The effective legs of the winning play (``StarlitCartoucheReconciliation/netTrace(_:)``), each
        /// `.leg(star, wait)` as the kernel applied it (an undone leg left out unless redone; no undo or redo); empty
        /// for a result recorded without a trace.
        public let trace: [StarlitCartoucheAction]
        /// Whether the result was recorded with a trace (reconciliation replays it on restore).
        public let verified: Bool

        /// A result of the given values without a trace, unverified (not checked).
        public init(actionsSpent: Int, stars: Int) {
            self.init(actionsSpent: actionsSpent, stars: stars, trace: [], verified: false)
        }

        /// A result of the given values (not checked).
        public init(actionsSpent: Int, stars: Int, trace: [StarlitCartoucheAction], verified: Bool) {
            self.actionsSpent = actionsSpent
            self.stars = stars
            self.trace = trace
            self.verified = verified
        }

        /// The keys of an encoded result.
        private enum CodingKeys: String, CodingKey {
            /// The least actions spent.
            case actionsSpent
            /// The stars.
            case stars
            /// The effective legs of the win.
            case trace
            /// Whether the result was recorded with a trace.
            case verified
        }

        /// Decodes a result; a missing `trace` is empty and a missing `verified` is false.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            actionsSpent = try container.decode(Int.self, forKey: .actionsSpent)
            stars = try container.decode(Int.self, forKey: .stars)
            trace = try container.decodeIfPresent([StarlitCartoucheAction].self, forKey: .trace) ?? []
            verified = try container.decodeIfPresent(Bool.self, forKey: .verified) ?? false
        }

        /// Encodes every field, the trace and the verified flag included.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(actionsSpent, forKey: .actionsSpent)
            try container.encode(stars, forKey: .stars)
            try container.encode(trace, forKey: .trace)
            try container.encode(verified, forKey: .verified)
        }
    }

    /// The number of levels.
    public static let levelCount: Int = 100
    /// The number of levels per difficulty band.
    public static let levelsPerBand: Int = 20
    /// The difficulty bands, 1 … 5, of 20 levels each (the certified difficulty bands).
    public static let bands: ClosedRange<Int> = 1...5
    /// The year of the daily level's day 0 (2026-01-01).
    public static let dailyEpochYear: Int = 2026
    /// The multiplier of the daily level (coprime with 100, so 100 consecutive days visit every level once; it differs
    /// from the other round-two games' 31, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89 and 97).
    public static let dailyMultiplier: Int = 37
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

    /// The best (least) actions spent of won level `level`, or nil when it has not been won.
    public func best(_ level: Int) -> Int? { solved[level]?.actionsSpent }

    /// The stars of won level `level` (1 … 3), or 0 when it has not been won.
    public func stars(of level: Int) -> Int { solved[level]?.stars ?? 0 }

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

    /// The stars of a win that spent `actionsSpent` actions on a level whose certified witness has `certified` legs:
    /// 3 when `actionsSpent ≤ certified`, 2 when `actionsSpent ≤ certified + 2`, otherwise 1.
    public static func stars(actionsSpent: Int, certified: Int) -> Int {
        if actionsSpent <= certified { return 3 }
        if actionsSpent <= certified + 2 { return 2 }
        return 1
    }

    /// The actions spent in `play` for the stars: one per accepted leg record, undone ones included (a redo re-applies
    /// a leg already counted and spends nothing new; undo and redo records count 0). It can exceed
    /// ``StarlitCartouchePlay/actionsSpent``, which an undo restores.
    public static func actionsSpent(_ play: StarlitCartouchePlay) -> Int {
        var spent: Int = 0
        for record in play.records where record.kind == .leg {
            spent += 1
        }
        return spent
    }

    /// Records a win of `level` that spent `actionsSpent` actions (certified witness of `certified` legs).
    ///
    /// The result has no trace and is unverified. The caller records only campaign and daily wins (never practice or
    /// replay). The new result replaces a stored one only when it is better (fewer actions spent, then more stars); a
    /// worse or equal result keeps the stored one. When `opensNext` is true (a campaign win, the default) the frontier
    /// rises to `level + 1` (at most 100); it never falls; a daily win passes false and opens nothing. A level outside
    /// 1 … 100 is ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, opensNext: Bool = true) -> Bool {
        let result: Result = Result(actionsSpent: actionsSpent,
                                    stars: Self.stars(actionsSpent: actionsSpent, certified: certified))
        return store(result, level: level, opensNext: opensNext)
    }

    /// Records a win of `level` in `mode` under the rules of ``record(level:actionsSpent:certified:opensNext:)``:
    /// practice and replay record nothing, campaign opens the next level, daily opens nothing. The result has no trace
    /// and is unverified.
    ///
    /// - Returns: whether the stored result of `level` changed.
    @discardableResult
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: StarlitCartoucheMode) -> Bool {
        guard mode.awardsStars else { return false }
        return record(level: level, actionsSpent: actionsSpent, certified: certified, opensNext: mode.opensLevels)
    }

    /// Records a verified win of `level` that spent `actionsSpent` actions (certified witness of `certified` legs) in
    /// `mode`, with `trace`, the effective legs of the winning play (``StarlitCartoucheReconciliation/netTrace(_:)``).
    ///
    /// The rules of ``record(level:actionsSpent:certified:mode:)`` apply: practice and replay record nothing; the
    /// result replaces a stored one only when it is better (fewer actions spent, then more stars), so a tie keeps the
    /// earlier result and its trace; a campaign win raises the frontier; a daily win opens nothing; a level outside
    /// 1 … 100 is ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, actionsSpent: Int, certified: Int,
                                mode: StarlitCartoucheMode = .campaign,
                                trace: [StarlitCartoucheAction]) -> Bool {
        guard mode.awardsStars else { return false }
        let result: Result = Result(actionsSpent: actionsSpent,
                                    stars: Self.stars(actionsSpent: actionsSpent, certified: certified),
                                    trace: trace, verified: true)
        return store(result, level: level, opensNext: mode.opensLevels)
    }

    /// Removes the result of `level` (reconciliation drops a result whose trace does not replay); the frontier is
    /// unchanged. Nothing happens when `level` has no result.
    public mutating func drop(level: Int) {
        solved[level] = nil
    }

    /// Stores `result` for `level` under the rules of ``record(level:actionsSpent:certified:opensNext:)``.
    ///
    /// - Returns: whether the stored result of `level` changed.
    private mutating func store(_ result: Result, level: Int, opensNext: Bool) -> Bool {
        guard level >= 1 && level <= Self.levelCount else { return false }
        var improved: Bool = false
        if let old = solved[level] {
            let fewer: Bool = result.actionsSpent < old.actionsSpent
            let moreStars: Bool = result.actionsSpent == old.actionsSpent && result.stars > old.stars
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

    /// The daily level (1 … 100) of a calendar day: (d × 37) mod 100 + 1, where d is the days from 2026-01-01 to the
    /// given day (negative before it) and the modulo is wrapped into 0 … 99, counted in integer arithmetic on the
    /// proleptic Gregorian calendar (no clock, no time zone, no Foundation calendar). nil for an impossible day (year
    /// outside 1 … 9999, month outside 1 … 12, day outside the month, leap years included).
    public static func dailyLevel(year: Int, month: Int, day: Int) -> Int? {
        guard let days = daysFromEpoch(year: year, month: month, day: day) else { return nil }
        return ((days * dailyMultiplier) % levelCount + levelCount) % levelCount + 1
    }

    /// The days from 2026-01-01 to the given proleptic Gregorian day (negative before it), or nil for an impossible
    /// day (as ``dailyLevel(year:month:day:)``).
    public static func daysFromEpoch(year: Int, month: Int, day: Int) -> Int? {
        guard dailyYears.contains(year), month >= 1 && month <= 12 else { return nil }
        guard day >= 1 && day <= daysIn(month: month, year: year) else { return nil }
        return daysFromCivil(year: year, month: month, day: day) - daysFromCivil(year: dailyEpochYear, month: 1, day: 1)
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

    /// One won level as encoded; `trace` and `verified` are absent in snapshot schema 1 and 2 encodings.
    private struct Entry: Codable {
        /// The level, 1 … 100.
        let level: Int
        /// The least actions spent.
        let actionsSpent: Int
        /// The stars, 1 … 3.
        let stars: Int
        /// The effective legs of the win (absent before snapshot schema 3).
        let trace: [StarlitCartoucheAction]?
        /// Whether the result was recorded with a trace (absent before snapshot schema 3).
        let verified: Bool?
    }

    /// The keys of the encoded progress.
    private enum CodingKeys: String, CodingKey {
        /// The won levels, an array sorted by level.
        case solved
        /// The highest open level.
        case frontier
    }

    /// Decodes progress; the won levels are an array of `{level, actionsSpent, stars, trace, verified}`, where a
    /// missing trace is empty and a missing verified flag is false.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for a frontier outside 1 … 100, a level outside 1 … 100 or repeated,
    ///   stars outside 1 … 3 or actions spent below 0.
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
                  entry.stars >= 1 && entry.stars <= 3, entry.actionsSpent >= 0 else {
                throw DecodingError.dataCorruptedError(forKey: .solved, in: container,
                                                       debugDescription: "invalid won level \(entry.level)")
            }
            solved[entry.level] = Result(actionsSpent: entry.actionsSpent, stars: entry.stars,
                                         trace: entry.trace ?? [], verified: entry.verified ?? false)
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
            entries.append(Entry(level: level, actionsSpent: result.actionsSpent, stars: result.stars,
                                 trace: result.trace, verified: result.verified))
        }
        try container.encode(entries, forKey: .solved)
    }
}
