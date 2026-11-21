// ColorfallCanyonsProgress — feature 345 (R02-G05-05) T-R02G0505-003 (FR-R02G0505-001, 004, 005; SC-R02G0505-001, 004;
// clarifications Q2, Q3, Q4). Player teaching and progression of Colorfall Canyons: the three-instruction tutorial
// (steer, run, fill) shown on levels 1 … 3 in every mode, which advances when an edit was accepted and the hint's plan is
// empty, on an accepted step and at the end of the level, and never moves back on undo; the play mode (campaign,
// practice, daily); and the campaign progress — per won level the fewest actions spent (carves and valve toggles) and the
// stars (3 at most the certified smallest edit count, 2 at most that + 2, otherwise 1), and the open frontier (level 1
// open; a campaign win opens the next level, up to 100). The daily level is a clock-free function of a calendar date:
// (days from 2026-01-01 × 53) mod 100 + 1, in integer arithmetic on the proleptic Gregorian calendar. Progress alone
// opens every level. Every type is Codable with a stable, explicit form. Modelled on feature 335's HueCompassProgress.
// Feature 347 (R02-G05-07) T-R02G0507-002 (FR-R02G0507-001, 003, 004; clarifications Q1–Q4; research R2, R6): each
// result also keeps its winning trace (the ordered net actions of the play that earned it: carves, valve toggles and
// steps, an undone action left out unless redone) and whether it is `verified`; a traced win replaces the result only
// when it is better (fewer actions or more stars; ties keep the earlier trace); `drop(level:)` removes a result for
// reconciliation; the mode gains `replay(level:)`, which records nothing and opens nothing. Encoded results carry `trace`
// and `verified`; an encoding without them (schema 1 or 2) decodes as an unverified result without a trace. Modelled on
// feature 337's HueCompassProgress.
import Foundation

/// The step of the Colorfall Canyons tutorial (levels 1 … 3, in every mode).
///
/// The tutorial shows one instruction at a time: `steer` → `run` → `fill` → `done`. `steer` advances once an edit (a
/// carve or a valve toggle) was accepted and the hint's plan of the new state is empty; `run` advances on an accepted
/// step; every step ends when the level ends (won or failed). Dismissing ends it. Undo and redo never move the step.
/// Encoded as its raw name.
public enum ColorfallCanyonsTutorialStep: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// Teaches steering the fluid: carve channels and switch valves until the plan is empty.
    case steer
    /// Teaches running the fluid with Step or Run.
    case run
    /// Teaches the goal: fill every basin with its colours without overflow.
    case fill
    /// The tutorial is over.
    case done

    /// The step a play of level `level` starts at: `steer` on the tutorial levels 1 … 3 (in every mode), else `done`.
    public static func initial(level: Int) -> Self {
        ColorfallCanyonsGenerator.tutorialLevels.contains(level) ? .steer : .done
    }

    /// The instruction shown for the step (clarification Q2); empty for `done`.
    public var text: String {
        switch self {
        case .steer:
            "Drag across a sandstone cell (or use Carve) to cut a channel, and tap a spring (or its valve button) to open "
                + "or close it, until the fluid will reach the right basins; a hint shows how"
        case .run: "Let the fluid run with Step or Run and watch the basins fill"
        case .fill: "Fill every basin with its colours without overflow; undo any change that sends a wrong colour in"
        case .done: ""
        }
    }

    /// The step after an accepted record of `kind` (nil when no record was made) or the end of the level.
    ///
    /// - Parameters:
    ///   - kind: the kind of the accepted record: a carve or valve on `steer` with `planEmpty` advances to `run`; a step
    ///     on `run` advances to `fill`; an undo or redo never moves the step (undo never moves it back).
    ///   - planEmpty: whether the hint's plan of the new state is empty (the caller computes it from the hints).
    ///   - ended: whether the level has ended (won or failed); then the step is `done` whatever `kind` is.
    public func advanced(after kind: ColorfallCanyonsRecordKind?, planEmpty: Bool, ended: Bool) -> Self {
        if ended { return .done }
        switch (self, kind) {
        case (.steer, .carve?), (.steer, .valve?): return planEmpty ? .run : .steer
        case (.run, .step?): return .fill
        default: return self
        }
    }

    /// The step after the player dismissed the tutorial: always `done`.
    public func dismissed() -> Self { .done }
}

/// The mode a level is played in (clarification Q4).
public enum ColorfallCanyonsMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's budget; a win records stars and opens the next level.
    case campaign
    /// Practice: the budget raised to the kernel maximum (30); never awards stars or opens levels.
    case practice
    /// The daily level `level` (1 … 100) of ``ColorfallCanyonsProgress/dailyLevel(year:month:day:)``: campaign rules,
    /// but a win never opens a level (a level still locked in the campaign is playable as the daily level).
    case daily(level: Int)
    /// The replay of the stored winning trace of `level` (1 … 100) on a fresh play (feature 347); never records a
    /// result, awards no stars and opens no level.
    case replay(level: Int)

    /// The action budget of practice mode: the kernel's maximum, 30.
    public static let practiceBudget: Int = 30

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
    /// - Throws: `DecodingError.dataCorrupted` for an unknown mode name or a daily or replay level outside 1 … 100.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name: String = try container.decode(String.self, forKey: .mode)
        switch name {
        case "campaign": self = .campaign
        case "practice": self = .practice
        case "daily":
            let level: Int = try container.decode(Int.self, forKey: .level)
            guard level >= 1 && level <= ColorfallCanyonsProgress.levelCount else {
                throw DecodingError.dataCorruptedError(forKey: .level, in: container,
                                                       debugDescription: "daily level outside 1 … 100")
            }
            self = .daily(level: level)
        case "replay":
            let level: Int = try container.decode(Int.self, forKey: .level)
            guard level >= 1 && level <= ColorfallCanyonsProgress.levelCount else {
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

/// The campaign progress of Colorfall Canyons: the won levels with their best results and the open frontier.
///
/// Encoded as `{"frontier": n, "solved": [{"bestActions": a, "level": l, "stars": s, "trace": [action, …],
/// "verified": v}, …]}` with the won levels as an array sorted by level, so equal progress gives equal JSON (``encoded()`` also sorts the keys).
public struct ColorfallCanyonsProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one won level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The fewest actions (carves and valve toggles) spent in a win.
        public let bestActions: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int
        /// The winning actions of the play that earned the result, in order (its net carves, valve toggles and steps;
        /// an undone action left out unless redone, so never an undo or a redo); empty for a result without a trace.
        public let trace: [ColorfallCanyonsAction]
        /// Whether the result was recorded with its trace (``ColorfallCanyonsReconciliation`` replays it); false for a
        /// result restored from a save without traces.
        public let verified: Bool

        /// A result of the given values (not checked); by default without a trace and unverified.
        public init(bestActions: Int, stars: Int, trace: [ColorfallCanyonsAction] = [], verified: Bool = false) {
            self.bestActions = bestActions
            self.stars = stars
            self.trace = trace
            self.verified = verified
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
    /// from the other round-two games' 37, 41, 43 and 47).
    public static let dailyMultiplier: Int = 53
    /// The calendar years accepted by the daily level.
    public static let dailyYears: ClosedRange<Int> = 1...9999
    /// The most carves and valve toggles a trace may hold and still verify (research R6): the largest budget, 30.
    public static let maximumTraceEdits: Int = ColorfallCanyonsLevel.budgets.upperBound
    /// The most steps a trace may hold and still verify (research R6): the largest tick limit, 3 600 (every accepted
    /// step runs at least one tick).
    public static let maximumTraceSteps: Int = ColorfallCanyonsLevel.tickLimits.upperBound

    /// Whether `trace` lies within the bound of research R6: at most ``maximumTraceEdits`` carves and valve toggles and
    /// at most ``maximumTraceSteps`` steps.
    public static func withinTraceBound(_ trace: [ColorfallCanyonsAction]) -> Bool {
        var edits: Int = 0
        var steps: Int = 0
        for action in trace {
            switch action {
            case .carve, .valve: edits += 1
            case .step: steps += 1
            }
        }
        return edits <= maximumTraceEdits && steps <= maximumTraceSteps
    }

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

    /// The stars of a win spending `actions` actions on a level whose certified smallest edit count is `smallest`: 3
    /// when `actions ≤ smallest`, 2 when `actions ≤ smallest + 2`, otherwise 1.
    public static func stars(actions: Int, smallest: Int) -> Int {
        if actions <= smallest { return 3 }
        if actions <= smallest + 2 { return 2 }
        return 1
    }

    /// Records a win of `level` spending `actions` actions (certified smallest edit count `smallest`) in `mode`.
    ///
    /// Practice and replay record nothing. The result has no trace and is unverified. In campaign and daily mode the new
    /// result replaces a stored one only when it is better (fewer actions or more stars); a worse or equal result keeps
    /// the stored one. A campaign win raises the frontier
    /// to `level + 1` (at most 100); it never falls; a daily win opens nothing. A level outside 1 … 100 is ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, actions: Int, smallest: Int,
                                mode: ColorfallCanyonsMode = .campaign) -> Bool {
        guard level >= 1 && level <= Self.levelCount, mode.awardsStars else { return false }
        let result: Result = Result(bestActions: actions, stars: Self.stars(actions: actions, smallest: smallest))
        var improved: Bool = false
        if let old = solved[level] {
            if result.bestActions < old.bestActions || result.stars > old.stars {
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

    /// Records a win of `level` spending `actions` actions (certified smallest edit count `smallest`) in `mode` with its
    /// winning `trace`: a verified result (feature 347, clarification Q1).
    ///
    /// Practice and replay record nothing. In campaign and daily mode the new result replaces a stored one only when it
    /// is better (fewer actions or more stars); an equal or worse result keeps the stored one (ties keep the earlier
    /// trace). A campaign win raises the frontier to `level + 1` (at most 100); it never falls; a daily win opens
    /// nothing. A level outside 1 … 100 is ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, actions: Int, smallest: Int, mode: ColorfallCanyonsMode = .campaign,
                                trace: [ColorfallCanyonsAction]) -> Bool {
        guard level >= 1 && level <= Self.levelCount, mode.awardsStars else { return false }
        let result: Result = Result(bestActions: actions, stars: Self.stars(actions: actions, smallest: smallest),
                                    trace: trace, verified: true)
        var improved: Bool = false
        if let old = solved[level] {
            // Ties keep the earlier trace.
            if result.bestActions < old.bestActions || result.stars > old.stars {
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

    /// Removes the result of `level` (reconciliation drops a result that does not replay); the frontier is unchanged.
    public mutating func drop(level: Int) {
        solved[level] = nil
    }

    /// The daily level (1 … 100) of a calendar date: (d × 53) mod 100 + 1, where d is the days from 2026-01-01 to the
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

    /// One won level as encoded; `trace` and `verified` are absent in schema-1 and schema-2 encodings.
    private struct Entry: Codable {
        let level: Int
        let bestActions: Int
        let stars: Int
        let trace: [ColorfallCanyonsAction]?
        let verified: Bool?
    }

    private enum CodingKeys: String, CodingKey {
        case solved
        case frontier
    }

    /// Decodes progress; the won levels are an array of `{level, bestActions, stars, trace, verified}` (a missing trace
    /// is empty, a missing `verified` false, so schema-1 and schema-2 saves stay readable). A trace is not checked here:
    /// an illegal or over-long trace decodes and is dropped (and counted) by ``ColorfallCanyonsReconciliation``.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for a frontier outside 1 … 100, a level outside 1 … 100 or repeated, stars
    ///   outside 1 … 3 or best actions below 0.
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
                  entry.stars >= 1 && entry.stars <= 3, entry.bestActions >= 0 else {
                throw DecodingError.dataCorruptedError(forKey: .solved, in: container,
                                                       debugDescription: "invalid won level \(entry.level)")
            }
            solved[entry.level] = Result(bestActions: entry.bestActions, stars: entry.stars, trace: entry.trace ?? [],
                                         verified: entry.verified ?? false)
        }
        self.solved = solved
        self.frontier = frontier
    }

    /// Encodes the frontier and the won levels as an array sorted by level, each with its trace and `verified`.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frontier, forKey: .frontier)
        var entries: [Entry] = []
        for level in solved.keys.sorted() {
            guard let result = solved[level] else { continue }
            entries.append(Entry(level: level, bestActions: result.bestActions, stars: result.stars,
                                 trace: result.trace, verified: result.verified))
        }
        try container.encode(entries, forKey: .solved)
    }
}
