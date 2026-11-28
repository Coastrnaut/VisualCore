// MyceliumArchitectProgress — feature 515 (R02-G22-05) T-R02G2205-003 (FR-R02G2205-001, 004, 005, 006, 009;
// SC-R02G2205-001, 004; clarifications Q2, Q3, Q4; research R4, R5). Player teaching and progression of Mycelium
// Architect: the three-instruction tutorial (place, grow, recover) shown on levels 1 … 3 — an accepted arrangement
// action moves `place` to `grow`, a second accepted arrangement action in the opening moves `grow` to `recover`, the
// end of the level (a won or a failed run, or a redo that restores one) moves any step to `done` — which never moves
// back on undo or redo and is never moved by `growth.show`; the play mode (campaign, practice, daily); and the
// campaign progress — per won level the least actions spent (every accepted nutrient, blocker, clear, seed and unseed
// record of the play, undone ones included) and the stars (3 at most the certified witness's action count, 2 at most
// that + 2, otherwise 1), and the open frontier (level 1 open; a campaign win opens the next level, up to 100). No
// level is ever gated by payment: locked means not yet unlocked (FR-R02G2205-006). The daily level is a function of a
// calendar day given as integers: (days from 2026-01-01 × 11) mod 100 + 1, negative day counts wrapped into 0 … 99, in
// integer arithmetic on the proleptic Gregorian calendar. Every type is Codable with a stable, explicit form, and the
// validation helpers let the adapter refuse a damaged payload (level and frontier 1 … 100, stars 1 … 3, actions spent
// ≥ 1). Modelled on feature 505's BinaryGardensProgress. Integers only; no clock, no random source.
import Foundation

/// The step of the Mycelium Architect tutorial (levels 1 … 3, the levels whose ``MyceliumArchitectLevel/tutorial`` is
/// set).
///
/// The tutorial shows one instruction at a time: `place` → `grow` → `recover` → `done`. `place` advances on the first
/// accepted arrangement action (a nutrient, blocker, clear, seed or unseed), `grow` on a second accepted arrangement
/// action in the opening, `recover` lasts until the level ends. Every step ends when the level ends (the run won or
/// failed, or a redo restores a won or failed moment), so a level that ends before a step is reached goes straight to
/// `done`. Dismissing ends it. Undo and redo never move the step back; `growth.show` never moves it. Encoded as its
/// raw name.
public enum MyceliumArchitectTutorialStep: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// Teaches changing the growth: placing a nutrient or a blocker on a site, or seeding a filament from the root,
    /// and reading the ghost veins.
    case place
    /// Teaches reaching every terminal without toxin and within the weight limit, then running, with a hint.
    case grow
    /// Teaches what fails the run (toxin, running out of nutrient, an unreached terminal, an overweight network) and
    /// how to undo it.
    case recover
    /// The tutorial is over.
    case done

    /// The levels that carry the tutorial: 1 … 3 (``MyceliumArchitectLevel/tutorial``).
    public static let tutorialLevels: ClosedRange<Int> = 1...3

    /// The step a play starts at: `place` on a tutorial level, else `done`.
    ///
    /// - Parameter tutorial: whether the level carries the tutorial (``MyceliumArchitectLevel/tutorial``).
    public static func initial(tutorial: Bool) -> Self {
        tutorial ? .place : .done
    }

    /// The step a play of level number `level` starts at: `place` on the tutorial levels 1 … 3, else `done`.
    public static func initial(level: Int) -> Self {
        initial(tutorial: tutorialLevels.contains(level))
    }

    /// The instruction shown for the step (clarification Q2, word for word); empty for `done`.
    public var text: String {
        switch self {
        case .place:
            "Change the growth: tap an empty site to place a nutrient (choose Blocker to turn growth away), or drag "
                + "from the root to seed a filament; the ghost veins show where the growth will go"
        case .grow:
            "Reach every terminal without growing into toxin and keep the network's weight within its limit, then "
                + "press Run — a hint shows what to change"
        case .recover:
            "A tip that grows into toxin or runs out of nutrient, a terminal left unreached, or a network heavier than "
                + "its limit fails the run: undo and try another change"
        case .done: ""
        }
    }

    /// The step after an accepted arrangement action or the end of the level, in order, never back.
    ///
    /// - Parameters:
    ///   - afterAction: whether an accepted arrangement action (a nutrient, blocker, clear, seed or unseed, not the
    ///     run) was just applied.
    ///   - actionsThisOpening: the accepted arrangement actions of this opening so far, the one just applied and undone
    ///     ones included (``MyceliumArchitectProgress/actionsSpent(_:)``); `grow` moves to `recover` only when it is at
    ///     least 2. Ignored when `afterAction` is false.
    ///   - ended: whether the level has ended (the run won or failed); then the step is `done` whatever the other
    ///     values are.
    ///   An undo or a redo passes false for `afterAction` and the play's real end: an undo always lands before the
    ///   end, so it never ends the tutorial, while a redo that restores a won or failed moment ends it; `growth.show`
    ///   calls nothing; no call ever moves the step back.
    public func advanced(afterAction: Bool, actionsThisOpening: Int, ended: Bool) -> Self {
        if ended { return .done }
        guard afterAction else { return self }
        switch self {
        case .place: return .grow
        case .grow: return actionsThisOpening >= 2 ? .recover : .grow
        case .recover, .done: return self
        }
    }

    /// The step after the player dismissed the tutorial (`tutorial.dismiss`): always `done`.
    public func dismissed() -> Self { .done }
}

/// The mode a level is played in (clarification Q4).
public enum MyceliumArchitectMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's budget; a win records the best result and stars and opens the next level.
    case campaign
    /// Practice: the budget raised to the kernel maximum (24) on a copy of the level; never awards stars or opens
    /// levels.
    case practice
    /// The daily level `level` (1 … 100) of ``MyceliumArchitectProgress/dailyLevel(year:month:day:)``: campaign rules
    /// (a win records the level's best result and stars), but a win never opens a level.
    case daily(level: Int)

    /// The budget of practice mode: the kernel's maximum, 24 (``MyceliumArchitectLevel/budgets``).
    public static let practiceBudget: Int = MyceliumArchitectLevel.budgets.upperBound

    /// The budget a level with budget `base` is played with: ``practiceBudget`` in practice, `base` otherwise
    /// (campaign and daily).
    public func budget(base: Int) -> Int {
        self == .practice ? Self.practiceBudget : base
    }

    /// Whether a win in this mode records a result and stars: campaign and daily (never practice).
    public var awardsStars: Bool { self != .practice }

    /// Whether a win in this mode opens the next level: campaign only.
    public var opensLevels: Bool { self == .campaign }

    /// Whether the mode is well formed: always for campaign and practice; a daily level within 1 … 100.
    public var isValid: Bool {
        switch self {
        case .campaign, .practice: true
        case .daily(let level): MyceliumArchitectProgress.isValid(level: level)
        }
    }

    /// The keys of the encoded mode.
    private enum CodingKeys: String, CodingKey {
        /// The mode name: `campaign`, `practice` or `daily`.
        case mode
        /// The daily level, 1 … 100 (daily only).
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
            guard MyceliumArchitectProgress.isValid(level: level) else {
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

/// The campaign progress of Mycelium Architect: the won levels with their best results and the open frontier.
///
/// Encoded as `{"frontier": n, "solved": [{"actionsSpent": a, "level": l, "stars": s}, …]}` with the won levels as an
/// array sorted by level, so equal progress gives equal JSON (``encoded()`` also sorts the keys).
public struct MyceliumArchitectProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one won level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The least actions spent at a win (``MyceliumArchitectProgress/actionsSpent(_:)``: every accepted nutrient,
        /// blocker, clear, seed and unseed record, undone ones included), at least 1.
        public let actionsSpent: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int

        /// A result of the given values (not checked; see ``isValid``).
        public init(actionsSpent: Int, stars: Int) {
            self.actionsSpent = actionsSpent
            self.stars = stars
        }

        /// Whether the result is well formed: actions spent at least 1 and stars 1 … 3.
        public var isValid: Bool {
            MyceliumArchitectProgress.isValidResult(actionsSpent: actionsSpent, stars: stars)
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
    /// from the other round-two games' 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89 and
    /// 97).
    public static let dailyMultiplier: Int = 11
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

    /// The actions spent in `play` for the stars: one per accepted nutrient, blocker, clear, seed or unseed record,
    /// undone ones included (the run spends nothing; a redo re-applies an action already counted and spends nothing
    /// new; undo, redo and event records count 0). It can exceed ``MyceliumArchitectPlay/actionsSpent``, which an undo
    /// restores.
    public static func actionsSpent(_ play: MyceliumArchitectPlay) -> Int {
        var spent: Int = 0
        for record in play.records {
            switch record.kind {
            case .nutrient, .blocker, .clear, .seed, .unseed: spent += 1
            case .run, .undo, .redo, .begin, .dismissTutorial, .pause, .resume, .showResult: break
            }
        }
        return spent
    }

    /// Records a win of `level` that spent `actionsSpent` actions (certified witness of `certified` arrangement
    /// actions).
    ///
    /// The caller records only campaign and daily wins (never practice). The new result replaces a stored one only
    /// when it is better (fewer actions spent, then more stars); a worse or equal result keeps the stored one. When
    /// `opens` is true (a campaign win, the default) the frontier rises to `level + 1` (at most 100); it never falls; a
    /// daily win passes false and opens nothing. A level outside 1 … 100 or actions spent below 1 are ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, opens: Bool = true) -> Bool {
        guard Self.isValid(level: level), actionsSpent >= 1 else { return false }
        let result: Result = Result(actionsSpent: actionsSpent,
                                    stars: Self.stars(actionsSpent: actionsSpent, certified: certified))
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

    /// Records a win of `level` in `mode` under the rules of ``record(level:actionsSpent:certified:opens:)``:
    /// practice records nothing, campaign opens the next level, daily opens nothing.
    ///
    /// - Returns: whether the stored result of `level` changed.
    @discardableResult
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: MyceliumArchitectMode) -> Bool {
        guard mode.awardsStars else { return false }
        return record(level: level, actionsSpent: actionsSpent, certified: certified, opens: mode.opensLevels)
    }

    /// The daily level (1 … 100) of a calendar day: (d × 11) mod 100 + 1, where d is the days from 2026-01-01 to the
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

    /// One won level as encoded.
    private struct Entry: Codable {
        /// The level, 1 … 100.
        let level: Int
        /// The least actions spent, at least 1.
        let actionsSpent: Int
        /// The stars, 1 … 3.
        let stars: Int
    }

    /// The keys of the encoded progress.
    private enum CodingKeys: String, CodingKey {
        /// The won levels, an array sorted by level.
        case solved
        /// The highest open level.
        case frontier
    }

    /// Decodes progress; the won levels are an array of `{level, actionsSpent, stars}`.
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
            solved[entry.level] = Result(actionsSpent: entry.actionsSpent, stars: entry.stars)
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
            entries.append(Entry(level: level, actionsSpent: result.actionsSpent, stars: result.stars))
        }
        try container.encode(entries, forKey: .solved)
    }
}
