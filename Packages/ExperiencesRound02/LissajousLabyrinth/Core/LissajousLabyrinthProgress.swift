// LissajousLabyrinthProgress — feature 315 (R02-G02-05) T-R02G0205-003 (FR-R02G0205-001, 004, 005, 006; clarifications
// Q2–Q4; research R3–R6). Player teaching and progression of Lissajous Labyrinth: the three-instruction tutorial (turn a
// ring, checkpoints and obstacles, hints) that advances on accepted dial actions, a hint request and a win; the play mode
// (campaign, practice, daily); and the campaign progress — per solved level the best winning action count and the stars
// (3 at the certified shortest, 2 within shortest + 2, otherwise 1), and the open frontier (level 1 open; a campaign win
// opens the next level, up to 100). The daily level is a clock-free function of a calendar date: (days from 2026-01-01 ×
// 41) mod 100 + 1, in integer arithmetic on the proleptic Gregorian calendar. Progress alone opens every level
// (FR-R02G0205-006: no other gate). Every type is Codable with a stable, explicit form so a later feature can extend it.
import Foundation

/// The step of the Lissajous Labyrinth tutorial (levels 1 … 3).
///
/// The tutorial shows one instruction at a time: `turn(dial)` → `checkpoints` → `hints` → `done`. The dial named by
/// `turn` is supplied by the caller (the dial of the level-1 hint for the current play). Undo never moves the step back:
/// the caller simply does not advance it on undo or redo.
public enum LissajousLabyrinthTutorialStep: Sendable, Equatable, Hashable, Codable {
    /// Teaches the rings: turn the named dial's ring to change the path.
    case turn(LissajousLabyrinthDial)
    /// Teaches the goal: the copper checkpoints in order, away from the violet spheres.
    case checkpoints
    /// Teaches the hints.
    case hints
    /// The tutorial is over.
    case done

    /// The first step: teach the ring of `dial`.
    public static func first(dial: LissajousLabyrinthDial) -> Self { .turn(dial) }

    /// The title of `dial` as shown to the player: Frequency A, Frequency B, Phase A or Phase C.
    public static func title(of dial: LissajousLabyrinthDial) -> String {
        switch dial {
        case .frequencyA: "Frequency A"
        case .frequencyB: "Frequency B"
        case .phaseA: "Phase A"
        case .phaseC: "Phase C"
        }
    }

    /// The instruction shown for the step (clarification Q2); empty for `done`.
    public var text: String {
        switch self {
        case .turn(let dial): "Turn the \(Self.title(of: dial)) ring to change the path."
        case .checkpoints:
            "Copper checkpoints light up when the lap reaches them in order; keep the path off the violet spheres."
        case .hints: "Ask for a hint whenever you are stuck."
        case .done: ""
        }
    }

    /// The step after an accepted dial action that left the play in `stage`.
    ///
    /// A win (`stage == .won`) ends the tutorial from any step. Otherwise `turn` advances to `checkpoints`, `checkpoints`
    /// to `hints`; `hints` and `done` stay. Call it only for accepted actions (never for undo or redo).
    public func advancedByAction(stage: LissajousLabyrinthStage) -> Self {
        if stage == .won { return .done }
        switch self {
        case .turn: return .checkpoints
        case .checkpoints: return .hints
        case .hints, .done: return self
        }
    }

    /// The step after the player asked for a hint: `checkpoints` advances to `hints`; every other step stays.
    public func advancedByHint() -> Self {
        self == .checkpoints ? .hints : self
    }

    /// The step after the player dismissed the tutorial: always `done`.
    public var dismissed: Self { .done }

    private enum CodingKeys: String, CodingKey {
        case step
        case dial
    }

    /// Decodes `{"step": "turn", "dial": "<dial>"}`, `{"step": "checkpoints"}`, `{"step": "hints"}` or
    /// `{"step": "done"}`.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for an unknown step name; a missing or unknown dial for `turn`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name: String = try container.decode(String.self, forKey: .step)
        switch name {
        case "turn": self = .turn(try container.decode(LissajousLabyrinthDial.self, forKey: .dial))
        case "checkpoints": self = .checkpoints
        case "hints": self = .hints
        case "done": self = .done
        default:
            throw DecodingError.dataCorruptedError(forKey: .step, in: container,
                                                   debugDescription: "unknown tutorial step \(name)")
        }
    }

    /// Encodes the step as `{"step": <name>}`, with `"dial"` (the dial's raw value) for `turn`.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .turn(let dial):
            try container.encode("turn", forKey: .step)
            try container.encode(dial, forKey: .dial)
        case .checkpoints: try container.encode("checkpoints", forKey: .step)
        case .hints: try container.encode("hints", forKey: .step)
        case .done: try container.encode("done", forKey: .step)
        }
    }
}

/// The mode a level is played in (clarification Q4).
public enum LissajousLabyrinthMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's allowance; a win records stars and opens the next level.
    case campaign
    /// Practice: the allowance raised to the kernel maximum (64); never awards stars or opens levels.
    case practice
    /// The daily level `level` (1 … 100) of ``LissajousLabyrinthProgress/dailyLevel(year:month:day:)``: campaign rules,
    /// but a win never opens a level.
    case daily(level: Int)

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
            guard level >= 1 && level <= LissajousLabyrinthProgress.levelCount else {
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

/// The campaign progress of Lissajous Labyrinth: the solved levels with their best results and the open frontier.
///
/// Encoded as `{"frontier": n, "solved": [{"bestActions": a, "level": l, "stars": s}, …]}` with the solved levels as an
/// array sorted by level, so equal progress gives equal JSON (``encoded()`` also sorts the keys).
public struct LissajousLabyrinthProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one solved level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The fewest actions that won the level.
        public let bestActions: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int

        /// A result of the given values (not checked).
        public init(bestActions: Int, stars: Int) {
            self.bestActions = bestActions
            self.stars = stars
        }
    }

    /// The number of levels.
    public static let levelCount = 100
    /// The year of the daily level's day 0 (2026-01-01).
    public static let dailyEpochYear = 2026
    /// The multiplier of the daily level (coprime with 100, so 100 consecutive days visit every level once).
    public static let dailyMultiplier = 41
    /// The calendar years accepted by the daily level.
    public static let dailyYears: ClosedRange<Int> = 1...9999

    /// The solved levels (1 … 100) and their best results.
    public private(set) var solved: [Int: Result]
    /// The highest open level, 1 … 100; every level 1 … `frontier` is open.
    public private(set) var frontier: Int

    /// No level solved; level 1 open.
    public init() {
        solved = [:]
        frontier = 1
    }

    /// Opens every level up to `level` (clamped to 1 … 100); the frontier never falls. The adapter opens the level a seed
    /// chose, so a session that starts beyond level 1 can play it (feature 315, T-R02G0205-004).
    public mutating func open(through level: Int) {
        frontier = max(frontier, min(max(level, 1), Self.levelCount))
    }

    /// Whether `level` is open: 1 ≤ level ≤ ``frontier``.
    public func isOpen(_ level: Int) -> Bool { level >= 1 && level <= frontier }

    /// The stars of a win in `actions` actions on a level whose certified shortest solution is `shortest`: 3 when
    /// `actions ≤ shortest`, 2 when `actions ≤ shortest + 2`, otherwise 1 (research R6).
    public static func stars(actions: Int, shortest: Int) -> Int {
        if actions <= shortest { return 3 }
        if actions <= shortest + 2 { return 2 }
        return 1
    }

    /// Records a win of `level` in `actions` actions (certified shortest `shortest`).
    ///
    /// The new result replaces a stored one only when it is better (fewer actions or more stars); a worse or equal result
    /// keeps the stored one. When `opensNext` (a campaign win), the frontier rises to `level + 1` (at most 100) and
    /// never falls; daily wins pass `false`. Practice never calls this. A level outside 1 … 100 is ignored.
    public mutating func record(level: Int, actions: Int, shortest: Int, opensNext: Bool) {
        guard level >= 1 && level <= Self.levelCount else { return }
        let result: Result = Result(bestActions: actions, stars: Self.stars(actions: actions, shortest: shortest))
        if let old = solved[level] {
            if result.bestActions < old.bestActions || result.stars > old.stars { solved[level] = result }
        } else {
            solved[level] = result
        }
        if opensNext { frontier = max(frontier, min(level + 1, Self.levelCount)) }
    }

    /// The daily level (1 … 100) of a calendar date: (d × 41) mod 100 + 1, where d is the days from 2026-01-01 to the
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

    /// One solved level as encoded.
    private struct Entry: Codable {
        let level: Int
        let bestActions: Int
        let stars: Int
    }

    private enum CodingKeys: String, CodingKey {
        case solved
        case frontier
    }

    /// Decodes progress; the solved levels are an array of `{level, bestActions, stars}`.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for a frontier outside 1 … 100, a level outside 1 … 100 or repeated,
    ///   stars outside 1 … 3 or negative best actions.
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
                                                       debugDescription: "invalid solved level \(entry.level)")
            }
            solved[entry.level] = Result(bestActions: entry.bestActions, stars: entry.stars)
        }
        self.solved = solved
        self.frontier = frontier
    }

    /// Encodes the frontier and the solved levels as an array sorted by level.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frontier, forKey: .frontier)
        var entries: [Entry] = []
        for level in solved.keys.sorted() {
            guard let result = solved[level] else { continue }
            entries.append(Entry(level: level, bestActions: result.bestActions, stars: result.stars))
        }
        try container.encode(entries, forKey: .solved)
    }
}
