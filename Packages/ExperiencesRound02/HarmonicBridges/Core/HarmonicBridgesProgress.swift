// HarmonicBridgesProgress — feature 415 (R02-G12-05) T-R02G1205-003 (FR-R02G1205-001, 004, 005; SC-R02G1205-001, 004;
// clarifications Q2, Q3, Q4). Player teaching and progression of Harmonic Bridges: the three-instruction tutorial
// (tune, bridge, test) shown on levels 1 … 3 — an accepted tuning moves `tune` to `bridge` (or straight on to `test`
// when that tuning already bridges every step), the pegs joining the start to the goal in every step move `bridge` to
// `test`, the end of the level moves any step to `done` — which never moves back on undo or redo; the play mode
// (campaign, practice, daily); and the campaign progress — per won level the least actions spent (every accepted
// tuning and test record of the play, undone ones included) and the stars (3 at most the certified witness's action
// count, its tunings plus the test, 2 at most that + 2, otherwise 1), and the open frontier (level 1 open; a campaign
// win opens the next level, up to 100). The daily level is a function of a calendar day without any clock:
// (days from 2026-01-01 × 83) mod 100 + 1, negative day counts wrapped, in integer arithmetic on the proleptic
// Gregorian calendar. Every type is Codable with a stable, explicit form. Modelled on feature 405's
// EchoCartographerProgress. Integers only; no clock, no random source.
import Foundation

/// The step of the Harmonic Bridges tutorial (levels 1 … 3, the levels whose ``HarmonicBridgesLevel/tutorial`` is set).
///
/// The tutorial shows one instruction at a time: `tune` → `bridge` → `test` → `done`. `tune` advances on an accepted
/// tuning — to `bridge`, or straight on to `test` when that tuning already joins the start to the goal in every step;
/// `bridge` advances when the current pegs join the start to the goal in every step; `test` lasts until the level
/// ends. Every step ends when the level ends (won or failed), so a level that ends before a step is reached goes
/// straight to `done`. Dismissing ends it. Undo and redo never move the step, in particular never back (an undo that
/// unbridges a step leaves `test`). Encoded as its raw name.
public enum HarmonicBridgesTutorialStep: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// Teaches tuning a string's peg until one of its harmonics matches a tone of the step.
    case tune
    /// Teaches bridging a path from the start to the goal in every step.
    case bridge
    /// Teaches testing the crossing and undoing a broken step.
    case test
    /// The tutorial is over.
    case done

    /// The levels that carry the tutorial: 1 … 3 (``HarmonicBridgesLevel/tutorial``).
    public static let tutorialLevels: ClosedRange<Int> = 1...3

    /// The step a play starts at: `tune` on a tutorial level, else `done`.
    ///
    /// - Parameter tutorial: whether the level carries the tutorial (``HarmonicBridgesLevel/tutorial``).
    public static func initial(tutorial: Bool) -> Self {
        tutorial ? .tune : .done
    }

    /// The step a play of level number `level` starts at: `tune` on the tutorial levels 1 … 3, else `done`.
    public static func initial(level: Int) -> Self {
        initial(tutorial: tutorialLevels.contains(level))
    }

    /// The instruction shown for the step (clarification Q2, word for word); empty for `done`.
    public var text: String {
        switch self {
        case .tune:
            "Drag a string's peg up or down (or use the panel's peg steppers and Tune) — when one of its harmonics "
                + "matches a tone of the step it swings and its samples fill"
        case .bridge:
            "A string whose five samples all fill becomes a cyan bridge: bridge a path from the start to the violet "
                + "goal in every step — a hint shows which string"
        case .test:
            "Tap the goal or a step pip to test the crossing; if a step breaks, undo it"
        case .done: ""
        }
    }

    /// The step after an accepted action or the end of the level, in order, never back.
    ///
    /// - Parameters:
    ///   - afterTune: whether the accepted action was a tuning (``HarmonicBridgesRecordKind/tune``); it moves `tune` to
    ///     `bridge`, or to `test` when `bridged` is also true, and leaves every other step.
    ///   - bridged: whether the current pegs join the start to the goal in every step
    ///     (``HarmonicBridgesReport/goalReachedInEveryStep``); it moves `bridge` to `test` (on `tune` only together
    ///     with an accepted tuning).
    ///   - ended: whether the level has ended (won or failed); then the step is `done` whatever the other flags are.
    ///   An undo or a redo passes false for `afterTune` and `ended` and never moves the step back.
    public func advanced(afterTune: Bool, bridged: Bool, ended: Bool) -> Self {
        if ended { return .done }
        switch self {
        case .tune:
            guard afterTune else { return self }
            return bridged ? .test : .bridge
        case .bridge: return bridged ? .test : self
        case .test, .done: return self
        }
    }

    /// The step after the player dismissed the tutorial (`tutorial.dismiss`): always `done`.
    public func dismissed() -> Self { .done }
}

/// The mode a level is played in (clarification Q4).
public enum HarmonicBridgesMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's budget; a win records the best result and stars and opens the next level.
    case campaign
    /// Practice: the budget raised to the kernel maximum (60); never awards stars or opens levels.
    case practice
    /// The daily level `level` (1 … 100) of ``HarmonicBridgesProgress/dailyLevel(year:month:day:)``: campaign rules
    /// (a win records the level's best result and stars), but a win never opens a level.
    case daily(level: Int)

    /// The budget of practice mode: the kernel's maximum, 60 (``HarmonicBridgesLevel/budgets``).
    public static let practiceBudget: Int = HarmonicBridgesLevel.budgets.upperBound

    /// The budget a level with budget `base` is played with: ``practiceBudget`` in practice, `base` otherwise.
    public func budget(base: Int) -> Int {
        self == .practice ? Self.practiceBudget : base
    }

    /// Whether a win in this mode records a result and stars: campaign and daily (never practice).
    public var awardsStars: Bool { self != .practice }

    /// Whether a win in this mode opens the next level: campaign only.
    public var opensLevels: Bool { self == .campaign }

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
            guard level >= 1 && level <= HarmonicBridgesProgress.levelCount else {
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

/// The campaign progress of Harmonic Bridges: the won levels with their best results and the open frontier.
///
/// Encoded as `{"frontier": n, "solved": [{"actionsSpent": a, "level": l, "stars": s}, …]}` with the won levels as an
/// array sorted by level, so equal progress gives equal JSON (``encoded()`` also sorts the keys).
public struct HarmonicBridgesProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one won level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The least actions spent at a win (``HarmonicBridgesProgress/actionsSpent(_:)``: every accepted tuning and
        /// test record, undone ones included).
        public let actionsSpent: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int

        /// A result of the given values (not checked).
        public init(actionsSpent: Int, stars: Int) {
            self.actionsSpent = actionsSpent
            self.stars = stars
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
    /// from the other round-two games' 37, 41, 43, 47, 53, 59, 61, 67, 71, 73 and 79).
    public static let dailyMultiplier: Int = 83
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

    /// The stars of a win that spent `actionsSpent` actions on a level whose certified witness has `certified` actions
    /// (its tunings plus the test): 3 when `actionsSpent ≤ certified`, 2 when `actionsSpent ≤ certified + 2`,
    /// otherwise 1.
    public static func stars(actionsSpent: Int, certified: Int) -> Int {
        if actionsSpent <= certified { return 3 }
        if actionsSpent <= certified + 2 { return 2 }
        return 1
    }

    /// The actions spent in `play` for the stars: one per accepted tuning and test record, undone ones included (a
    /// redo re-applies an action already counted and spends nothing new; undo and redo records count 0).
    public static func actionsSpent(_ play: HarmonicBridgesPlay) -> Int {
        var spent: Int = 0
        for record in play.records {
            switch record.kind {
            case .tune, .test: spent += 1
            case .undo, .redo: break
            }
        }
        return spent
    }

    /// Records a win of `level` that spent `actionsSpent` actions (certified witness of `certified` actions).
    ///
    /// The caller records only campaign and daily wins (never practice). The new result replaces a stored one only
    /// when it is better (fewer actions spent, then more stars); a worse or equal result keeps the stored one. When
    /// `opensNext` is true (a campaign win, the default) the frontier rises to `level + 1` (at most 100); it never
    /// falls; a daily win passes false and opens nothing. A level outside 1 … 100 is ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, opensNext: Bool = true) -> Bool {
        guard level >= 1 && level <= Self.levelCount else { return false }
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
        if opensNext { frontier = max(frontier, min(level + 1, Self.levelCount)) }
        return improved
    }

    /// Records a win of `level` in `mode` under the rules of ``record(level:actionsSpent:certified:opensNext:)``:
    /// practice records nothing, campaign opens the next level, daily opens nothing.
    ///
    /// - Returns: whether the stored result of `level` changed.
    @discardableResult
    public mutating func record(level: Int, actionsSpent: Int, certified: Int, mode: HarmonicBridgesMode) -> Bool {
        guard mode.awardsStars else { return false }
        return record(level: level, actionsSpent: actionsSpent, certified: certified, opensNext: mode.opensLevels)
    }

    /// The daily level (1 … 100) of a calendar day: (d × 83) mod 100 + 1, where d is the days from 2026-01-01 to the
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

    /// One won level as encoded.
    private struct Entry: Codable {
        /// The level, 1 … 100.
        let level: Int
        /// The least actions spent.
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
