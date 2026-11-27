// BinaryGardensProgress — feature 505 (R02-G21-05) T-R02G2105-003 (FR-R02G2105-001, 004, 005, 006;
// SC-R02G2105-001, 004; clarifications Q2, Q3, Q4). Player teaching and progression of Binary Gardens: the
// three-instruction tutorial (adjust, balance, recover) shown on levels 1 … 3 — an accepted arrangement action moves
// `adjust` to `balance`, a second accepted arrangement action in the opening moves `balance` to `recover`, the end of
// the level (a won or a failed run, or a redo that restores one) moves any step to `done` — which never moves back on
// undo or redo and is never moved by `clock.show`; the play mode (campaign, practice, daily); and the campaign progress
// — per won level the least actions spent (every accepted ring, phase, luminosity and tilt record of the play, undone
// ones included) and the stars (3 at most the certified witness's action count, 2 at most that + 2, otherwise 1), and
// the open frontier (level 1 open; a campaign win opens the next level, up to 100). No level is ever gated by payment:
// locked means not yet unlocked (FR-R02G2105-006). The daily level is a function of a calendar day without any clock:
// (days from 2026-01-01 × 13) mod 100 + 1, negative day counts wrapped into 0 … 99, in integer arithmetic on the
// proleptic Gregorian calendar. Every type is Codable with a stable, explicit form, and the validation helpers let the
// adapter refuse a damaged payload (level and frontier 1 … 100, stars 1 … 3, actions spent ≥ 1). Modelled on feature
// 495's MushroomWeatherProgress. Integers only; no clock, no random source.
// Feature 507 (R02-G21-07) T-R02G2107-002 (FR-R02G2107-003; clarifications Q1 … Q3; research R2 … R4, R6, R7): each
// result also keeps the trace of its win (the effective ring, phase, luminosity and tilt actions, each
// `.ring(star:index:)`, `.phase(star:step:)`, `.luminosity(star:index:)` or `.tilt(step:)` as the kernel applied it, an
// undone action left out unless redone, then the closing `.run`) and whether it is verified (a win recorded with a
// trace); `drop(level:)` removes a result that failed reconciliation (``BinaryGardensReconciliation``); the replay mode
// (a saved trace played back with the campaign budget) awards nothing and opens nothing. Encodings without trace or
// verified (snapshot schema 1 and 2) decode as unverified results with an empty trace; an untraced, unverified result
// is encoded without both keys, exactly as before, so its encoding (and every digest over it) is unchanged. Modelled on
// feature 497's MushroomWeatherProgress.
import Foundation

/// The step of the Binary Gardens tutorial (levels 1 … 3, the levels whose ``BinaryGardensLevel/tutorial`` is set).
///
/// The tutorial shows one instruction at a time: `adjust` → `balance` → `recover` → `done`. `adjust` advances on the
/// first accepted arrangement action (a ring, phase, luminosity or tilt change), `balance` on a second accepted
/// arrangement action in the opening, `recover` lasts until the level ends. Every step ends when the level ends (the
/// run won or failed, or a redo restores a won or failed moment), so a level that ends before a step is reached goes
/// straight to `done`. Dismissing ends it. Undo and redo never move the step back; `clock.show` never moves it.
/// Encoded as its raw name.
public enum BinaryGardensTutorialStep: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// Teaches changing a star (its orbit, ring, brightness) or the tilt and reading the gauges.
    case adjust
    /// Teaches keeping every world's light comfortable, never frozen or scorched too long, inside its bloom band, then
    /// running, with a hint.
    case balance
    /// Teaches what fails the run (freezing or scorching too long, too short a comfortable window, too little or too
    /// much light in total) and how to undo it.
    case recover
    /// The tutorial is over.
    case done

    /// The levels that carry the tutorial: 1 … 3 (``BinaryGardensLevel/tutorial``).
    public static let tutorialLevels: ClosedRange<Int> = 1...3

    /// The step a play starts at: `adjust` on a tutorial level, else `done`.
    ///
    /// - Parameter tutorial: whether the level carries the tutorial (``BinaryGardensLevel/tutorial``).
    public static func initial(tutorial: Bool) -> Self {
        tutorial ? .adjust : .done
    }

    /// The step a play of level number `level` starts at: `adjust` on the tutorial levels 1 … 3, else `done`.
    public static func initial(level: Int) -> Self {
        initial(tutorial: tutorialLevels.contains(level))
    }

    /// The instruction shown for the step (clarification Q2, word for word); empty for `done`.
    public var text: String {
        switch self {
        case .adjust:
            "Change a star: drag it along its orbit or across its rings, tap a brightness pip or the tilt dial, or use "
                + "the panel; the gauges show every world's light over the whole cycle"
        case .balance:
            "Keep every world's light comfortable for its window, never frozen or scorched for too long, with its "
                + "total light inside its bloom band, then press Run — a hint shows what to change"
        case .recover:
            "A world that freezes or scorches for too many ticks, has too short a comfortable window, or gets too "
                + "little or too much light in total fails the run: undo and try another change"
        case .done: ""
        }
    }

    /// The step after an accepted arrangement action or the end of the level, in order, never back.
    ///
    /// - Parameters:
    ///   - afterAction: whether an accepted arrangement action (a ring, phase, luminosity or tilt change, not the run)
    ///     was just applied.
    ///   - actionsThisOpening: the accepted arrangement actions of this opening so far, the one just applied and undone
    ///     ones included (``BinaryGardensProgress/actionsSpent(_:)``); `balance` moves to `recover` only when it is at
    ///     least 2. Ignored when `afterAction` is false.
    ///   - ended: whether the level has ended (the run won or failed); then the step is `done` whatever the other
    ///     values are.
    ///   An undo or a redo passes false for `afterAction` and the play's real end: an undo always lands before the
    ///   end, so it never ends the tutorial, while a redo that restores a won or failed moment ends it; `clock.show`
    ///   calls nothing; no call ever moves the step back.
    public func advanced(afterAction: Bool, actionsThisOpening: Int, ended: Bool) -> Self {
        if ended { return .done }
        guard afterAction else { return self }
        switch self {
        case .adjust: return .balance
        case .balance: return actionsThisOpening >= 2 ? .recover : .balance
        case .recover, .done: return self
        }
    }

    /// The step after the player dismissed the tutorial (`tutorial.dismiss`): always `done`.
    public func dismissed() -> Self { .done }
}

/// The mode a level is played in (clarification Q4).
public enum BinaryGardensMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's budget; a win records the best result and stars and opens the next level.
    case campaign
    /// Practice: the budget raised to the kernel maximum (24) on a copy of the level; never awards stars or opens
    /// levels.
    case practice
    /// The daily level `level` (1 … 100) of ``BinaryGardensProgress/dailyLevel(year:month:day:)``: campaign rules
    /// (a win records the level's best result and stars), but a win never opens a level.
    case daily(level: Int)
    /// The replay of the saved verified trace of level `level` (1 … 100, feature 507): the campaign budget; never
    /// awards stars or opens levels.
    case replay(level: Int)

    /// The budget of practice mode: the kernel's maximum, 24 (``BinaryGardensLevel/budgets``).
    public static let practiceBudget: Int = BinaryGardensLevel.budgets.upperBound

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

    /// Whether the mode is well formed: always for campaign and practice; a daily or replayed level within 1 … 100.
    public var isValid: Bool {
        switch self {
        case .campaign, .practice: true
        case .daily(let level), .replay(let level): BinaryGardensProgress.isValid(level: level)
        }
    }

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
            guard BinaryGardensProgress.isValid(level: level) else {
                throw DecodingError.dataCorruptedError(forKey: .level, in: container,
                                                       debugDescription: "daily level outside 1 … 100")
            }
            self = .daily(level: level)
        case "replay":
            let level: Int = try container.decode(Int.self, forKey: .level)
            guard BinaryGardensProgress.isValid(level: level) else {
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

/// The campaign progress of Binary Gardens: the won levels with their best results and the open frontier.
///
/// Encoded as `{"frontier": n, "solved": [{"actionsSpent": a, "level": l, "stars": s, "trace": [...], "verified": v},
/// …]}` with the won levels as an array sorted by level, so equal progress gives equal JSON (``encoded()`` also sorts
/// the keys). `trace` is written only when it is not empty and `verified` only when it is true, so an untraced,
/// unverified result keeps the snapshot schema 2 form; an entry without them decodes with an empty trace, unverified.
public struct BinaryGardensProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one won level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The least actions spent at a win (``BinaryGardensProgress/actionsSpent(_:)``: every accepted ring, phase,
        /// luminosity and tilt record, undone ones included), at least 1.
        public let actionsSpent: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int
        /// The effective actions of the winning play (``BinaryGardensReconciliation/netTrace(_:)``): each
        /// `.ring(star:index:)`, `.phase(star:step:)`, `.luminosity(star:index:)` or `.tilt(step:)` as the kernel
        /// applied it (an undone action left out unless redone), then the closing `.run`; no undo or redo; empty for a
        /// result recorded without a trace (feature 507).
        public let trace: [BinaryGardensAction]
        /// Whether the result was recorded with a trace (reconciliation replays it on restore; feature 507).
        public let verified: Bool

        /// A result of the given values without a trace, unverified (not checked; see ``isValid``).
        public init(actionsSpent: Int, stars: Int) {
            self.init(actionsSpent: actionsSpent, stars: stars, trace: [], verified: false)
        }

        /// A result of the given values (not checked; see ``isValid``).
        public init(actionsSpent: Int, stars: Int, trace: [BinaryGardensAction], verified: Bool) {
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
            /// The effective actions of the win (absent when empty).
            case trace
            /// Whether the result was recorded with a trace (absent when false).
            case verified
        }

        /// Decodes a result; a missing `trace` is empty and a missing `verified` is false.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            actionsSpent = try container.decode(Int.self, forKey: .actionsSpent)
            stars = try container.decode(Int.self, forKey: .stars)
            trace = try container.decodeIfPresent([BinaryGardensAction].self, forKey: .trace) ?? []
            verified = try container.decodeIfPresent(Bool.self, forKey: .verified) ?? false
        }

        /// Encodes the actions spent and the stars, the trace when it is not empty and the verified flag when true.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(actionsSpent, forKey: .actionsSpent)
            try container.encode(stars, forKey: .stars)
            if !trace.isEmpty { try container.encode(trace, forKey: .trace) }
            if verified { try container.encode(verified, forKey: .verified) }
        }

        /// Whether the result is well formed: actions spent at least 1 and stars 1 … 3.
        public var isValid: Bool {
            BinaryGardensProgress.isValidResult(actionsSpent: actionsSpent, stars: stars)
        }
    }

    /// The number of levels.
    public static let levelCount: Int = 100
    /// The level numbers, 1 … 100.
    public static let levels: ClosedRange<Int> = 1...100
    /// The number of levels per difficulty band.
    public static let levelsPerBand: Int = 20
    /// The difficulty bands, 1 … 5, of 20 levels each (the certified difficulty bands).
    public static let bands: ClosedRange<Int> = 1...5
    /// The stars a result can hold, 1 … 3.
    public static let starRange: ClosedRange<Int> = 1...3
    /// The year of the daily level's day 0 (2026-01-01).
    public static let dailyEpochYear: Int = 2026
    /// The multiplier of the daily level (coprime with 100, so 100 consecutive days visit every level once; it differs
    /// from the other round-two games' 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89 and 97).
    public static let dailyMultiplier: Int = 13
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

    /// Whether `level` is a level number, 1 … 100 (also the range of a valid frontier and a daily level).
    public static func isValid(level: Int) -> Bool { levels.contains(level) }

    /// Whether a stored result is well formed: actions spent at least 1 and stars 1 … 3.
    public static func isValidResult(actionsSpent: Int, stars: Int) -> Bool {
        actionsSpent >= 1 && starRange.contains(stars)
    }

    /// Whether the whole progress is well formed: a frontier 1 … 100 and every won level 1 … 100 with a valid result.
    /// Progress built through this type's API or decoded is always valid; the adapter uses this before trusting a
    /// restored payload.
    public var isValid: Bool {
        guard Self.isValid(level: frontier) else { return false }
        for (level, result) in solved where !Self.isValid(level: level) || !result.isValid { return false }
        return true
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

    /// Opens every level up to `level` (clamped to 1 … 100); the frontier never falls. The adapter opens the level an
    /// opening chose (a fresh opening of level N opens 1 … N), so a session that starts beyond level 1 can play it.
    public mutating func open(through level: Int) {
        frontier = max(frontier, min(max(level, 1), Self.levelCount))
    }

    /// Whether `level` is open: 1 ≤ level ≤ ``frontier``.
    public func isOpen(_ level: Int) -> Bool { level >= 1 && level <= frontier }

    /// The next open level after `level` (`level + 1` when it is open), or nil when there is none (never past 100; no
    /// wrap to 1).
    public func nextOpen(after level: Int) -> Int? {
        let next: Int = max(level + 1, 1)
        return isOpen(next) ? next : nil
    }

    /// The stars of a win that spent `actionsSpent` actions on a level whose certified witness has `certified`
    /// arrangement actions (the run excluded): 3 when `actionsSpent ≤ certified`, 2 when
    /// `actionsSpent ≤ certified + 2`, otherwise 1.
    public static func stars(actionsSpent: Int, certified: Int) -> Int {
        if actionsSpent <= certified { return 3 }
        if actionsSpent <= certified + 2 { return 2 }
        return 1
    }

    /// The actions spent in `play` for the stars: one per accepted ring, phase, luminosity or tilt record, undone ones
    /// included (the run spends nothing; a redo re-applies an action already counted and spends nothing new; undo,
    /// redo and event records count 0). It can exceed ``BinaryGardensPlay/actionsSpent``, which an undo restores.
    public static func actionsSpent(_ play: BinaryGardensPlay) -> Int {
        var spent: Int = 0
        for record in play.records {
            switch record.kind {
            case .ring, .phase, .luminosity, .tilt: spent += 1
            case .run, .undo, .redo, .begin, .dismissTutorial, .pause, .resume, .showResult: break
            }
        }
        return spent
    }

    /// Records a win of `level` that spent `actionsSpent` actions (certified witness of `certified` arrangement
    /// actions).
    ///
    /// The result has no trace and is unverified. The caller records only campaign and daily wins (never practice or
    /// replay). The new result replaces a stored one only when it is better (fewer actions spent, then more stars); a
    /// worse or equal result keeps the stored one. When `opens` is true (a campaign win, the default) the frontier
    /// rises to `level + 1` (at most 100); it never falls; a daily win passes false and opens nothing. A level outside
    /// 1 … 100 or actions spent below 1 are ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, opens: Bool = true) -> Bool {
        let result: Result = Result(actionsSpent: actionsSpent,
                                    stars: Self.stars(actionsSpent: actionsSpent, certified: certified))
        return store(result, level: level, opens: opens)
    }

    /// Records a win of `level` in `mode` under the rules of ``record(level:actionsSpent:certified:opens:)``:
    /// practice and replay record nothing, campaign opens the next level, daily opens nothing. The result has no trace
    /// and is unverified.
    ///
    /// - Returns: whether the stored result of `level` changed.
    @discardableResult
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: BinaryGardensMode) -> Bool {
        guard mode.awardsStars else { return false }
        return record(level: level, actionsSpent: actionsSpent, certified: certified, opens: mode.opensLevels)
    }

    /// Records a verified win of `level` that spent `actionsSpent` actions (certified witness of `certified`
    /// arrangement actions) in `mode`, with `trace`, the effective actions of the winning play
    /// (``BinaryGardensReconciliation/netTrace(_:)``: its ring, phase, luminosity and tilt actions, then the run).
    ///
    /// The rules of ``record(level:actionsSpent:certified:mode:)`` apply: practice and replay record nothing; the
    /// result replaces a stored one only when it is better (fewer actions spent, then more stars), so a tie keeps the
    /// earlier result and its trace; a campaign win raises the frontier; a daily win opens nothing; a level outside
    /// 1 … 100 or actions spent below 1 are ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: BinaryGardensMode = .campaign,
                                trace: [BinaryGardensAction]) -> Bool {
        guard mode.awardsStars else { return false }
        let result: Result = Result(actionsSpent: actionsSpent,
                                    stars: Self.stars(actionsSpent: actionsSpent, certified: certified),
                                    trace: trace, verified: true)
        return store(result, level: level, opens: mode.opensLevels)
    }

    /// Removes the result of `level` (reconciliation drops a result whose trace does not replay); the frontier is
    /// unchanged. Nothing happens when `level` has no result.
    public mutating func drop(level: Int) {
        solved[level] = nil
    }

    /// Stores `result` for `level` under the rules of ``record(level:actionsSpent:certified:opens:)``.
    ///
    /// - Returns: whether the stored result of `level` changed.
    private mutating func store(_ result: Result, level: Int, opens: Bool) -> Bool {
        guard Self.isValid(level: level), result.actionsSpent >= 1 else { return false }
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
        if opens { frontier = max(frontier, min(level + 1, Self.levelCount)) }
        return improved
    }

    /// The daily level (1 … 100) of a calendar day: (d × 13) mod 100 + 1, where d is the days from 2026-01-01 to the
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

    /// One won level as encoded; `trace` and `verified` are absent in snapshot schema 1 and 2 encodings and for an
    /// untraced, unverified result.
    private struct Entry: Codable {
        /// The level, 1 … 100.
        let level: Int
        /// The least actions spent, at least 1.
        let actionsSpent: Int
        /// The stars, 1 … 3.
        let stars: Int
        /// The effective actions of the win (absent when empty).
        let trace: [BinaryGardensAction]?
        /// Whether the result was recorded with a trace (absent when false; the synthesized encoding leaves a nil
        /// optional out).
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
    ///   stars outside 1 … 3 or actions spent below 1.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let frontier: Int = try container.decode(Int.self, forKey: .frontier)
        let entries: [Entry] = try container.decode([Entry].self, forKey: .solved)
        guard Self.isValid(level: frontier) else {
            throw DecodingError.dataCorruptedError(forKey: .frontier, in: container,
                                                   debugDescription: "frontier outside 1 … 100")
        }
        var solved: [Int: Result] = [:]
        for entry in entries {
            guard Self.isValid(level: entry.level), solved[entry.level] == nil,
                  Self.isValidResult(actionsSpent: entry.actionsSpent, stars: entry.stars) else {
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
                                 trace: result.trace.isEmpty ? nil : result.trace,
                                 verified: result.verified ? true : nil))
        }
        try container.encode(entries, forKey: .solved)
    }
}
