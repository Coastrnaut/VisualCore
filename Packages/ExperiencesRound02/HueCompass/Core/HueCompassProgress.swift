// HueCompassProgress — feature 335 (R02-G04-05) T-R02G0405-003 (FR-R02G0405-001, 004, 005; clarifications Q2, Q3, Q4).
// Player teaching and progression of Hue Compass: the three-instruction tutorial (aim, probe, select) shown on levels
// 1 … 3 in every mode, which advances on an accepted turn, an accepted probe and the end of the level and never moves
// back on undo; the play mode (campaign, practice, daily); and the campaign progress — per won level the fewest units
// spent and the stars (3 at most the certified smallest probe count + 1, 2 at most + 2, otherwise 1), and the open
// frontier (level 1 open; a campaign win opens the next level, up to 100). The daily level is a clock-free function of a
// calendar date: (days from 2026-01-01 × 47) mod 100 + 1, in integer arithmetic on the proleptic Gregorian calendar.
// Progress alone opens every level. Every type is Codable with a stable, explicit form so a later feature can extend it.
// Modelled on feature 325's WaveKnotKeeperProgress.
import Foundation

/// The step of the Hue Compass tutorial (levels 1 … 3, in every mode).
///
/// The tutorial shows one instruction at a time: `aim` → `probe` → `select` → `done`. `aim` advances on an accepted
/// turn, `probe` on an accepted probe, and every step ends when the level ends (won or failed). Dismissing ends it.
/// Undo never moves the step back: the caller does not advance it on undo. Encoded as its raw name.
public enum HueCompassTutorialStep: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// Teaches aiming: swipe the compass or use Turn.
    case aim
    /// Teaches probing and reading a clue.
    case probe
    /// Teaches the selection.
    case select
    /// The tutorial is over.
    case done

    /// The step a play of level `level` starts at: `aim` on the tutorial levels 1 … 3 (in every mode), else `done`.
    public static func initial(level: Int) -> Self {
        HueCompassGenerator.tutorialLevels.contains(level) ? .aim : .done
    }

    /// The instruction shown for the step (clarification Q2); empty for `done`.
    public var text: String {
        switch self {
        case .aim: "Swipe the compass, or use Turn, to aim the needle"
        case .probe: "Tap the hub to probe: the hue gap counts bands to the target, the fog depth sums the fog between"
        case .select: "When one bearing and band fit every clue, choose the band and Select"
        case .done: ""
        }
    }

    /// The step after an accepted turn (or redo of one): `aim` advances to `probe`; every other step stays.
    public func afterTurn() -> Self {
        self == .aim ? .probe : self
    }

    /// The step after an accepted probe that left the play in `stage`.
    ///
    /// A probe that ends the level (it spent the last unit, so `stage` is `failed`) ends the tutorial. Otherwise `probe`
    /// advances to `select`; every other step stays (a probe before any turn keeps `aim`).
    public func afterProbe(stage: HueCompassStage) -> Self {
        if stage == .won || stage == .failed { return .done }
        return self == .probe ? .select : self
    }

    /// The step after the level ended (won or failed): always `done`.
    public func afterEnd() -> Self { .done }

    /// The step after the player dismissed the tutorial: always `done`.
    public func afterDismiss() -> Self { .done }

    /// The step after an accepted record of `kind` that left the play in `stage`: a turn or redo as ``afterTurn()``, a
    /// probe as ``afterProbe(stage:)``, a selection as ``afterEnd()``; an undo never moves the step.
    public func after(_ kind: HueCompassRecordKind, stage: HueCompassStage) -> Self {
        switch kind {
        case .turn, .redo:
            if stage == .won || stage == .failed { return .done }
            return afterTurn()
        case .probe: return afterProbe(stage: stage)
        case .select: return afterEnd()
        case .undo: return self
        }
    }
}

/// The mode a level is played in (clarification Q4).
public enum HueCompassMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's allowance; a win records stars and opens the next level.
    case campaign
    /// Practice: the allowance raised to the kernel maximum (24); never awards stars or opens levels.
    case practice
    /// The daily level `level` (1 … 100) of ``HueCompassProgress/dailyLevel(year:month:day:)``: campaign rules, but a
    /// win never opens a level (a level still locked in the campaign is playable as the daily level).
    case daily(level: Int)

    /// The allowance a level with allowance `base` is played with: ``HueCompassProgress/practiceAllowance`` in
    /// practice, `base` otherwise.
    public func allowance(base: Int) -> Int {
        self == .practice ? HueCompassProgress.practiceAllowance : base
    }

    /// Whether a win in this mode records a result and stars: campaign and daily.
    public var awardsStars: Bool { self != .practice }

    /// Whether a win in this mode opens the next level: campaign only.
    public var opensLevels: Bool { self == .campaign }

    private enum CodingKeys: String, CodingKey {
        case mode
        case level
    }

    /// Decodes `{"mode": "campaign"}`, `{"mode": "practice"}` or `{"mode": "daily", "level": n}`.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for an unknown mode name or a daily level outside 1 … 100.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name: String = try container.decode(String.self, forKey: .mode)
        switch name {
        case "campaign": self = .campaign
        case "practice": self = .practice
        case "daily":
            let level: Int = try container.decode(Int.self, forKey: .level)
            guard level >= 1 && level <= HueCompassProgress.levelCount else {
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

/// The campaign progress of Hue Compass: the won levels with their best results and the open frontier.
///
/// Encoded as `{"frontier": n, "solved": [{"bestUnits": u, "level": l, "stars": s}, …]}` with the won levels as an array
/// sorted by level, so equal progress gives equal JSON (``encoded()`` also sorts the keys).
public struct HueCompassProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one won level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The fewest units (probes and the selection) spent in a win.
        public let bestUnits: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int

        /// A result of the given values (not checked).
        public init(bestUnits: Int, stars: Int) {
            self.bestUnits = bestUnits
            self.stars = stars
        }
    }

    /// The number of levels.
    public static let levelCount: Int = 100
    /// The number of levels per difficulty band.
    public static let levelsPerBand: Int = 20
    /// The difficulty bands, 1 … 5, of 20 levels each.
    public static let bands: ClosedRange<Int> = 1...5
    /// The allowance of practice mode: the kernel's maximum.
    public static let practiceAllowance: Int = 24
    /// The year of the daily level's day 0 (2026-01-01).
    public static let dailyEpochYear: Int = 2026
    /// The multiplier of the daily level (coprime with 100, so 100 consecutive days visit every level once).
    public static let dailyMultiplier: Int = 47
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

    /// The stars of a win spending `units` units on a level whose certified smallest probe count is `smallest`: 3 when
    /// `units ≤ smallest + 1` (the probes and the selection), 2 when `units ≤ smallest + 2`, otherwise 1.
    public static func stars(units: Int, smallest: Int) -> Int {
        if units <= smallest + 1 { return 3 }
        if units <= smallest + 2 { return 2 }
        return 1
    }

    /// Records a win of `level` spending `units` units (certified smallest probe count `smallest`) in `mode`.
    ///
    /// Practice records nothing. In campaign and daily mode the new result replaces a stored one only when it is better
    /// (fewer units or more stars); a worse or equal result keeps the stored one. A campaign win raises the frontier to
    /// `level + 1` (at most 100); it never falls; a daily win opens nothing. A level outside 1 … 100 is ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, units: Int, smallest: Int, mode: HueCompassMode = .campaign) -> Bool {
        guard level >= 1 && level <= Self.levelCount, mode.awardsStars else { return false }
        let result: Result = Result(bestUnits: units, stars: Self.stars(units: units, smallest: smallest))
        var improved: Bool = false
        if let old = solved[level] {
            if result.bestUnits < old.bestUnits || result.stars > old.stars {
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

    /// The daily level (1 … 100) of a calendar date: (d × 47) mod 100 + 1, where d is the days from 2026-01-01 to the
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

    /// One won level as encoded.
    private struct Entry: Codable {
        let level: Int
        let bestUnits: Int
        let stars: Int
    }

    private enum CodingKeys: String, CodingKey {
        case solved
        case frontier
    }

    /// Decodes progress; the won levels are an array of `{level, bestUnits, stars}`.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for a frontier outside 1 … 100, a level outside 1 … 100 or repeated, stars
    ///   outside 1 … 3 or best units below 1.
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
                  entry.stars >= 1 && entry.stars <= 3, entry.bestUnits >= 1 else {
                throw DecodingError.dataCorruptedError(forKey: .solved, in: container,
                                                       debugDescription: "invalid won level \(entry.level)")
            }
            solved[entry.level] = Result(bestUnits: entry.bestUnits, stars: entry.stars)
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
            entries.append(Entry(level: level, bestUnits: result.bestUnits, stars: result.stars))
        }
        try container.encode(entries, forKey: .solved)
    }
}
