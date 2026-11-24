// MoonlitMechanismProgress — feature 435 (R02-G14-05) T-R02G1405-003 (FR-R02G1405-001, 004, 005; SC-R02G1405-001,
// 004; clarifications Q2, Q3, Q4). Player teaching and progression of Moonlit Mechanism: the three-instruction tutorial
// (change, align, run) shown on levels 1 … 3 — an accepted turn, re-seat or lamp step moves `change` to `align` (or
// straight on to `run` when that change makes the run report of the current set-up win), a winning run report moves
// `align` to `run`, the end of the level moves any step to `done` — which never moves back on undo or redo; the play
// mode (campaign, practice, daily); and the campaign progress — per won level the least actions spent (every accepted
// turn, re-seat, lamp step and run record of the play, undone ones included) and the stars (3 at most the certified
// witness's action count, its turns, re-seats and lamp steps plus the run, 2 at most that + 2, otherwise 1), and the
// open frontier (level 1 open; a campaign win opens the next level, up to 100). The daily level is a function of a
// calendar day without any clock: (days from 2026-01-01 × 97) mod 100 + 1, negative day counts wrapped, in integer
// arithmetic on the proleptic Gregorian calendar. Every type is Codable with a stable, explicit form. Modelled on
// feature 425's AcousticConstellatorProgress. Integers only; no clock, no random source.
// Feature 437 (R02-G14-07) T-R02G1407-002 (FR-R02G1407-001, 003; clarifications Q1, Q2, Q3): each result also keeps
// the trace of its win (the effective turns, re-seats and lamp steps and the run as the kernel applied them; an undone
// action is left out unless redone) and whether it is verified (a win recorded with a trace); `drop(level:)` removes a
// result that failed reconciliation; the replay mode (a saved trace played back) awards nothing and opens nothing.
// Encodings without trace or verified (schema 1 and 2) decode as unverified results with an empty trace. Modelled on
// feature 427's AcousticConstellatorProgress.
import Foundation

/// The step of the Moonlit Mechanism tutorial (levels 1 … 3, the levels whose ``MoonlitMechanismLevel/tutorial`` is
/// set).
///
/// The tutorial shows one instruction at a time: `change` → `align` → `run` → `done`. `change` advances on an accepted
/// turn, re-seat or lamp step — to `align`, or straight on to `run` when that change makes the run report of the
/// current set-up win (``isAligned(_:)``); `align` advances when the run report of the current set-up wins; `run`
/// lasts until the level ends. Every step ends when the level ends (won or failed), so a level that ends before a step
/// is reached goes straight to `done`. Dismissing ends it. Undo and redo never move the step back (an undo of the
/// change that made the set-up win leaves `run`). Encoded as its raw name.
public enum MoonlitMechanismTutorialStep: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// Teaches turning the handle and re-seating a gear, and watching its shadow move.
    case change
    /// Teaches moving the lamp to slide the shadows onto their targets, with a hint.
    case align
    /// Teaches running the machine through every key frame and undoing a failed run.
    case run
    /// The tutorial is over.
    case done

    /// The levels that carry the tutorial: 1 … 3 (``MoonlitMechanismLevel/tutorial``).
    public static let tutorialLevels: ClosedRange<Int> = 1...3

    /// The step a play starts at: `change` on a tutorial level, else `done`.
    ///
    /// - Parameter tutorial: whether the level carries the tutorial (``MoonlitMechanismLevel/tutorial``).
    public static func initial(tutorial: Bool) -> Self {
        tutorial ? .change : .done
    }

    /// The step a play of level number `level` starts at: `change` on the tutorial levels 1 … 3, else `done`.
    public static func initial(level: Int) -> Self {
        initial(tutorial: tutorialLevels.contains(level))
    }

    /// Whether the run report of `play`'s current set-up wins (``MoonlitMechanismPlay/report``, its outcome
    /// ``MoonlitMechanismOutcome/won``): a run now would win the level. This is the `aligned` argument of
    /// ``advanced(afterChange:aligned:ended:)``. It is not ``MoonlitMechanismRunReport/aligned`` (every mesh aligned),
    /// which can hold while a key frame still misses its target or shadows a forbidden cell.
    public static func isAligned(_ play: MoonlitMechanismPlay) -> Bool {
        isAligned(report: play.report)
    }

    /// Whether `report` wins (its outcome is ``MoonlitMechanismOutcome/won``).
    public static func isAligned(report: MoonlitMechanismRunReport) -> Bool {
        report.outcome == .won
    }

    /// Whether `action` is a change of the set-up: a turn, a re-seat or a lamp step (never a run). This is the
    /// `afterChange` argument of ``advanced(afterChange:aligned:ended:)`` for an accepted action.
    public static func isChange(_ action: MoonlitMechanismAction) -> Bool {
        switch action {
        case .turn, .reseat, .lamp: true
        case .run: false
        }
    }

    /// The instruction shown for the step (clarification Q2, word for word); empty for `done`.
    public var text: String {
        switch self {
        case .change:
            "Drag a gear around (or use Turn − and +) to turn the handle, or double-tap a gear (or use Re-seat) to "
                + "shift it by a tooth: watch its shadow move on the paper"
        case .align:
            "Drag the lamp up or down (or use Lamp − and +) to slide the shadows onto their targets — a hint shows "
                + "which change is next"
        case .run:
            "Tap the lamp (or Run) to run the machine through every key frame; if it fails, undo"
        case .done: ""
        }
    }

    /// The step after an accepted action or the end of the level, in order, never back.
    ///
    /// - Parameters:
    ///   - afterChange: whether the accepted action was a turn, a re-seat or a lamp step (``isChange(_:)``); it moves
    ///     `change` to `align`, or to `run` when `aligned` is also true, and leaves every other step.
    ///   - aligned: whether the run report of the play's current set-up wins (``isAligned(_:)``: the caller reads
    ///     `play.report.outcome == .won` after applying the action); it moves `align` to `run` (on `change` only
    ///     together with an accepted change).
    ///   - ended: whether the level has ended (won or failed); then the step is `done` whatever the other flags are.
    ///   An undo or a redo passes false for `afterChange` and the play's real end: an undo always lands before the end,
    ///   so it never ends the tutorial, while a redo that restores a won or failed play ends it (the adapter's
    ///   `advanceTutorial`); no call ever moves the step back.
    public func advanced(afterChange: Bool, aligned: Bool, ended: Bool) -> Self {
        if ended { return .done }
        switch self {
        case .change:
            guard afterChange else { return self }
            return aligned ? .run : .align
        case .align: return aligned ? .run : self
        case .run, .done: return self
        }
    }

    /// The step after the player dismissed the tutorial (`tutorial.dismiss`): always `done`.
    public func dismissed() -> Self { .done }
}

/// The mode a level is played in (clarification Q4).
public enum MoonlitMechanismMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's budget; a win records the best result and stars and opens the next level.
    case campaign
    /// Practice: the budget raised to the kernel maximum (40); never awards stars or opens levels.
    case practice
    /// The daily level `level` (1 … 100) of ``MoonlitMechanismProgress/dailyLevel(year:month:day:)``: campaign rules
    /// (a win records the level's best result and stars), but a win never opens a level.
    case daily(level: Int)
    /// The replay of the saved verified trace of level `level` (1 … 100): the campaign budget; never awards stars or
    /// opens levels.
    case replay(level: Int)

    /// The budget of practice mode: the kernel's maximum, 40 (``MoonlitMechanismLevel/budgets``).
    public static let practiceBudget: Int = MoonlitMechanismLevel.budgets.upperBound

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
            guard level >= 1 && level <= MoonlitMechanismProgress.levelCount else {
                throw DecodingError.dataCorruptedError(forKey: .level, in: container,
                                                       debugDescription: "daily level outside 1 … 100")
            }
            self = .daily(level: level)
        case "replay":
            let level: Int = try container.decode(Int.self, forKey: .level)
            guard level >= 1 && level <= MoonlitMechanismProgress.levelCount else {
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

/// The campaign progress of Moonlit Mechanism: the won levels with their best results and the open frontier.
///
/// Encoded as `{"frontier": n, "solved": [{"actionsSpent": a, "level": l, "stars": s, "trace": [...], "verified": v},
/// …]}` with the won levels as an array sorted by level, so equal progress gives equal JSON (``encoded()`` also sorts
/// the keys). An entry without `trace` or `verified` (schema 1 and 2) decodes with an empty trace, unverified.
public struct MoonlitMechanismProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one won level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The least actions spent at a win (``MoonlitMechanismProgress/actionsSpent(_:)``: every accepted turn,
        /// re-seat, lamp step and run record, undone ones included).
        public let actionsSpent: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int
        /// The effective actions (turns with their step, re-seats with their gear and step, lamp steps with their
        /// step, and the run) of the play that earned the result, in order, as the kernel applied them
        /// (``MoonlitMechanismReconciliation/netTrace(_:)``: an undone action is left out unless redone; never an undo
        /// or a redo); empty for a result recorded without a trace.
        public let trace: [MoonlitMechanismAction]
        /// Whether the result was recorded with a trace (reconciliation replays it on restore).
        public let verified: Bool

        /// A result of the given values without a trace, unverified (not checked).
        public init(actionsSpent: Int, stars: Int) {
            self.init(actionsSpent: actionsSpent, stars: stars, trace: [], verified: false)
        }

        /// A result of the given values (not checked).
        public init(actionsSpent: Int, stars: Int, trace: [MoonlitMechanismAction], verified: Bool) {
            self.actionsSpent = actionsSpent
            self.stars = stars
            self.trace = trace
            self.verified = verified
        }

        /// The keys of an encoded result.
        private enum CodingKeys: String, CodingKey {
            /// The least actions spent.
            case actionsSpent
            /// The stars, 1 … 3.
            case stars
            /// The effective actions of the winning play.
            case trace
            /// Whether the result was recorded with a trace.
            case verified
        }

        /// Decodes a result; a missing `trace` is empty and a missing `verified` is false.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            actionsSpent = try container.decode(Int.self, forKey: .actionsSpent)
            stars = try container.decode(Int.self, forKey: .stars)
            trace = try container.decodeIfPresent([MoonlitMechanismAction].self, forKey: .trace) ?? []
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
    /// from the other round-two games' 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83 and 89).
    public static let dailyMultiplier: Int = 97
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

    /// The stars of a win that spent `actionsSpent` actions on a level whose certified witness has `certified` actions
    /// (its turns, re-seats and lamp steps plus the run): 3 when `actionsSpent ≤ certified`, 2 when
    /// `actionsSpent ≤ certified + 2`, otherwise 1.
    public static func stars(actionsSpent: Int, certified: Int) -> Int {
        if actionsSpent <= certified { return 3 }
        if actionsSpent <= certified + 2 { return 2 }
        return 1
    }

    /// The actions spent in `play` for the stars: one per accepted turn, re-seat, lamp step and run record, undone
    /// ones included (a redo re-applies an action already counted and spends nothing new; undo and redo records count
    /// 0).
    public static func actionsSpent(_ play: MoonlitMechanismPlay) -> Int {
        var spent: Int = 0
        for record in play.records {
            switch record.kind {
            case .turn, .reseat, .lamp, .run: spent += 1
            case .undo, .redo: break
            }
        }
        return spent
    }

    /// Records a win of `level` that spent `actionsSpent` actions (certified witness of `certified` actions).
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
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: MoonlitMechanismMode) -> Bool {
        guard mode.awardsStars else { return false }
        return record(level: level, actionsSpent: actionsSpent, certified: certified, opensNext: mode.opensLevels)
    }

    /// Records a verified win of `level` that spent `actionsSpent` actions (certified witness of `certified` actions)
    /// in `mode`, with `trace`, the effective actions of the winning play
    /// (``MoonlitMechanismReconciliation/netTrace(_:)``).
    ///
    /// The rules of ``record(level:actionsSpent:certified:mode:)`` apply: practice and replay record nothing; the
    /// result replaces a stored one only when it is better (fewer actions spent, then more stars), so a tie keeps the
    /// earlier result and its trace; a campaign win raises the frontier; a daily win opens nothing; a level outside
    /// 1 … 100 is ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, actionsSpent: Int, certified: Int,
                                mode: MoonlitMechanismMode = .campaign,
                                trace: [MoonlitMechanismAction]) -> Bool {
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

    /// The daily level (1 … 100) of a calendar day: (d × 97) mod 100 + 1, where d is the days from 2026-01-01 to the
    /// given day (negative before it) and the modulo is wrapped into 0 … 99, counted in integer arithmetic on the
    /// proleptic Gregorian calendar (no clock, no time zone, no Foundation calendar). nil for an impossible day (year
    /// outside 1 … 9999, month outside 1 … 12, day outside the month, leap years included).
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
        /// The level, 1 … 100.
        let level: Int
        /// The least actions spent.
        let actionsSpent: Int
        /// The stars, 1 … 3.
        let stars: Int
        /// The effective actions of the winning play (absent before schema 3).
        let trace: [MoonlitMechanismAction]?
        /// Whether the result was recorded with a trace (absent before schema 3).
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
