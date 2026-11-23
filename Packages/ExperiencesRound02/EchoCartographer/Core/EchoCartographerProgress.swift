// EchoCartographerProgress — feature 405 (R02-G11-05) T-R02G1105-003 (FR-R02G1105-001, 004, 005; SC-R02G1105-001, 004;
// clarifications Q2, Q3, Q4). Player teaching and progression of Echo Cartographer: the three-instruction tutorial
// (pulse, narrow, claim) shown on levels 1 … 3, which advances one step per event in order — an accepted pulse moves
// `pulse` to `narrow`, a located beacon moves `narrow` to `claim`, the end of the level moves any step to `done` — and
// never moves back on undo or redo; the play mode (campaign, practice, daily); and the campaign progress — per won
// level the least energy spent (every accepted pulse and claim record of the play, undone ones included: a pulse 1, a
// located beacon 0, a missed claim the energy it took) and the stars (3 at most the certified plan's pulse count, 2 at
// most that + 2, otherwise 1), and the open frontier (level 1 open; a campaign win opens the next level, up to 100).
// The daily level is a function of a calendar day without any clock: (days from 2026-01-01 × 79) mod 100 + 1, in
// integer arithmetic on the proleptic Gregorian calendar. Every type is Codable with a stable, explicit form. Modelled
// on feature 395's BackwardsAuroraProgress. Integers only; no clock, no random source.
// Feature 407 (R02-G11-07) T-R02G1107-002 (FR-R02G1107-001, 003; clarifications Q1, Q2, Q4): each result also keeps
// the trace of its win (the effective pulses, claims and marks as the kernel applied them; an undone action is left out
// unless redone) and whether it is verified (a win recorded with a trace); `drop(level:)` removes a result that failed
// reconciliation; the replay mode (a saved trace played back) awards nothing and opens nothing. Encodings without trace
// or verified (schema 1 and 2) decode as unverified results with an empty trace. Modelled on feature 397's
// BackwardsAuroraProgress.
import Foundation

/// The step of the Echo Cartographer tutorial (levels 1 … 3, the levels whose ``EchoCartographerLevel/tutorial`` is
/// set).
///
/// The tutorial shows one instruction at a time: `pulse` → `narrow` → `claim` → `done`. The steps advance one per
/// event, in order: `pulse` advances only on an accepted pulse (a beacon located before any pulse leaves it at
/// `pulse`, since the player has not yet learnt to pulse); `narrow` advances only on a located beacon (a further pulse
/// leaves it); `claim` lasts until the level ends. Every step ends when the level ends (won or failed), so a level
/// that ends before a step is reached goes straight to `done`. Dismissing ends it. Undo and redo never move the step,
/// in particular never back. Encoded as its raw name.
public enum EchoCartographerTutorialStep: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// Teaches sending a pulse from a lit floor cell and reading its echoes.
    case pulse
    /// Teaches narrowing the beacons down with markers and further pulses.
    case narrow
    /// Teaches claiming a beacon (a hold) and the cost of a miss.
    case claim
    /// The tutorial is over.
    case done

    /// The levels that carry the tutorial: 1 … 3 (``EchoCartographerLevel/tutorial``).
    public static let tutorialLevels: ClosedRange<Int> = 1...3

    /// The step a play starts at: `pulse` on a tutorial level, else `done`.
    ///
    /// - Parameter tutorial: whether the level carries the tutorial (``EchoCartographerLevel/tutorial``).
    public static func initial(tutorial: Bool) -> Self {
        tutorial ? .pulse : .done
    }

    /// The step a play of level number `level` starts at: `pulse` on the tutorial levels 1 … 3, else `done`.
    public static func initial(level: Int) -> Self {
        initial(tutorial: tutorialLevels.contains(level))
    }

    /// The instruction shown for the step (clarification Q2, word for word); empty for `done`.
    public var text: String {
        switch self {
        case .pulse:
            "Tap a lit floor cell to send a pulse (or use the panel) — the echoes tell how far each beacon is along "
                + "the open floor"
        case .narrow:
            "Drag markers onto cells where a beacon could be and pulse again to narrow them down — a hint shows where"
        case .claim:
            "Hold a cell to claim a beacon there; a miss costs energy — locate every beacon before the energy runs out"
        case .done: ""
        }
    }

    /// The step after an accepted action or the end of the level: one step per event, in order, never back.
    ///
    /// - Parameters:
    ///   - afterPulse: whether the accepted action was a pulse (``EchoCartographerRecordKind/pulse``); it moves
    ///     `pulse` to `narrow` and leaves every other step.
    ///   - located: whether the accepted action located a beacon (a claim that hit); it moves `narrow` to `claim` and
    ///     leaves every other step (on `pulse` the player must pulse first).
    ///   - ended: whether the level has ended (won or failed); then the step is `done` whatever the other flags are.
    ///   An undo, a redo or a marker passes false for both flags and never moves the step.
    public func advanced(afterPulse: Bool, located: Bool, ended: Bool) -> Self {
        if ended { return .done }
        switch self {
        case .pulse: return afterPulse ? .narrow : self
        case .narrow: return located ? .claim : self
        case .claim, .done: return self
        }
    }

    /// The step after the player dismissed the tutorial (`tutorial.dismiss`): always `done`.
    public func dismissed() -> Self { .done }
}

/// The mode a level is played in (clarification Q4).
public enum EchoCartographerMode: Sendable, Equatable, Hashable, Codable {
    /// The campaign: the level's energy; a win records the best result and stars and opens the next level.
    case campaign
    /// Practice: the energy raised to the kernel maximum (60); never awards stars or opens levels.
    case practice
    /// The daily level `level` (1 … 100) of ``EchoCartographerProgress/dailyLevel(year:month:day:)``: campaign rules
    /// (a win records the level's best result and stars), but a win never opens a level.
    case daily(level: Int)
    /// The replay of the saved verified trace of level `level` (1 … 100): the campaign energy; never awards stars or
    /// opens levels.
    case replay(level: Int)

    /// The energy of practice mode: the kernel's maximum, 60 (``EchoCartographerLevel/energies``).
    public static let practiceEnergy: Int = EchoCartographerLevel.energies.upperBound

    /// The energy a level with energy `base` is played with: ``practiceEnergy`` in practice, `base` otherwise
    /// (campaign, daily and replay).
    public func energy(base: Int) -> Int {
        self == .practice ? Self.practiceEnergy : base
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
            guard level >= 1 && level <= EchoCartographerProgress.levelCount else {
                throw DecodingError.dataCorruptedError(forKey: .level, in: container,
                                                       debugDescription: "daily level outside 1 … 100")
            }
            self = .daily(level: level)
        case "replay":
            let level: Int = try container.decode(Int.self, forKey: .level)
            guard level >= 1 && level <= EchoCartographerProgress.levelCount else {
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

/// The campaign progress of Echo Cartographer: the won levels with their best results and the open frontier.
///
/// Encoded as `{"frontier": n, "solved": [{"energySpent": e, "level": l, "stars": s, "trace": [...], "verified": v},
/// …]}` with the won levels as an array sorted by level, so equal progress gives equal JSON (``encoded()`` also sorts
/// the keys). An entry without `trace` or `verified` (schema 1 and 2) decodes with an empty trace, unverified.
public struct EchoCartographerProgress: Sendable, Equatable, Hashable, Codable {
    /// The best result of one won level.
    public struct Result: Sendable, Equatable, Hashable, Codable {
        /// The least energy spent at a win (``EchoCartographerProgress/energySpent(_:)``: every accepted pulse and
        /// claim record, undone ones included).
        public let energySpent: Int
        /// The stars of that best result, 1 … 3.
        public let stars: Int
        /// The effective actions (pulses, claims and marks with their cells) of the play that earned the result, in
        /// order, as the kernel applied them (``EchoCartographerReconciliation/netTrace(_:)``: an undone action is
        /// left out unless redone; never an undo or a redo); empty for a result recorded without a trace.
        public let trace: [EchoCartographerAction]
        /// Whether the result was recorded with a trace (reconciliation replays it on restore).
        public let verified: Bool

        /// A result of the given values without a trace, unverified (not checked).
        public init(energySpent: Int, stars: Int) {
            self.init(energySpent: energySpent, stars: stars, trace: [], verified: false)
        }

        /// A result of the given values (not checked).
        public init(energySpent: Int, stars: Int, trace: [EchoCartographerAction], verified: Bool) {
            self.energySpent = energySpent
            self.stars = stars
            self.trace = trace
            self.verified = verified
        }

        private enum CodingKeys: String, CodingKey {
            case energySpent
            case stars
            case trace
            case verified
        }

        /// Decodes a result; a missing `trace` is empty and a missing `verified` is false.
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            energySpent = try container.decode(Int.self, forKey: .energySpent)
            stars = try container.decode(Int.self, forKey: .stars)
            trace = try container.decodeIfPresent([EchoCartographerAction].self, forKey: .trace) ?? []
            verified = try container.decodeIfPresent(Bool.self, forKey: .verified) ?? false
        }

        /// Encodes every field, the trace and the verified flag included.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(energySpent, forKey: .energySpent)
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
    /// from the other round-two games' 37, 41, 43, 47, 53, 59, 61, 67, 71 and 73).
    public static let dailyMultiplier: Int = 79
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

    /// The stars of a win that spent `energySpent` energy on a level whose certified plan has `certified` pulses (its
    /// witness energy; claims on the beacons' own cells are free): 3 when `energySpent ≤ certified`, 2 when
    /// `energySpent ≤ certified + 2`, otherwise 1.
    public static func stars(energySpent: Int, certified: Int) -> Int {
        if energySpent <= certified { return 3 }
        if energySpent <= certified + 2 { return 2 }
        return 1
    }

    /// The energy spent in `play`: the sum over every accepted pulse and claim record, undone ones included, of the
    /// energy the action took when it was applied — 1 for a pulse, 0 for a claim that located a beacon, the miss cost
    /// (never more than the energy then left) for a missed claim. Marker, undo and redo records spend nothing.
    ///
    /// The records are replayed on a fresh play of the play's level to read each action's energy (a record trace
    /// always replays, ``EchoCartographerPlay/replay(level:records:)``); should a record not replay, it and every
    /// later record count at their largest cost (a pulse 1, a claim the level's miss cost).
    public static func energySpent(_ play: EchoCartographerPlay) -> Int {
        let level: EchoCartographerLevel = play.level
        var shadow: EchoCartographerPlay = EchoCartographerPlay(level: level)
        var replaying: Bool = true
        do {
            try shadow.handle(.begin)
            if level.tutorial { try shadow.handle(.dismissTutorial) }
        } catch {
            replaying = false
        }
        var spent: Int = 0
        for record in play.records {
            if replaying {
                if shadow.fingerprint != record.previous {
                    if shadow.stage == .playing {
                        try? shadow.handle(.pause)
                    } else if shadow.stage == .paused {
                        try? shadow.handle(.resume)
                    }
                }
                let before: Int = shadow.energy
                do {
                    switch record.kind {
                    case .pulse, .claim:
                        if let action = record.action {
                            try shadow.apply(action, expecting: record.previous)
                            spent += before - shadow.energy
                            continue
                        }
                        replaying = false
                    case .mark:
                        if let action = record.action { try shadow.apply(action, expecting: record.previous) }
                    case .undo: try shadow.undo()
                    case .redo: try shadow.redo()
                    }
                } catch {
                    replaying = false
                }
                if replaying { continue }
            }
            switch record.kind {
            case .pulse: spent += 1
            case .claim: spent += level.missCost
            case .mark, .undo, .redo: break
            }
        }
        return spent
    }

    /// Records a win of `level` that spent `energySpent` energy (certified plan of `certified` pulses).
    ///
    /// The result has no trace and is unverified. The caller records only campaign and daily wins (never practice or
    /// replay). The new result replaces a stored one only
    /// when it is better (less energy spent, then more stars); a worse or equal result keeps the stored one. When
    /// `opensNext` is true (a campaign win, the default) the frontier rises to `level + 1` (at most 100); it never
    /// falls; a daily win passes false and opens nothing. A level outside 1 … 100 is ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, energySpent: Int, certified: Int, opensNext: Bool = true) -> Bool {
        let result: Result = Result(energySpent: energySpent,
                                    stars: Self.stars(energySpent: energySpent, certified: certified))
        return store(result, level: level, opensNext: opensNext)
    }

    /// Records a win of `level` in `mode` under the rules of ``record(level:energySpent:certified:opensNext:)``:
    /// practice and replay record nothing, campaign opens the next level, daily opens nothing. The result has no trace
    /// and is unverified.
    ///
    /// - Returns: whether the stored result of `level` changed.
    @discardableResult
    public mutating func record(level: Int, energySpent: Int, certified: Int, mode: EchoCartographerMode) -> Bool {
        guard mode.awardsStars else { return false }
        return record(level: level, energySpent: energySpent, certified: certified, opensNext: mode.opensLevels)
    }

    /// Records a verified win of `level` that spent `energySpent` energy (certified plan of `certified` pulses) in
    /// `mode`, with `trace`, the effective actions of the winning play (``EchoCartographerReconciliation/netTrace(_:)``).
    ///
    /// The rules of ``record(level:energySpent:certified:mode:)`` apply: practice and replay record nothing; the result
    /// replaces a stored one only when it is better (less energy spent, then more stars), so a tie keeps the earlier
    /// result and its trace; a campaign win raises the frontier; a daily win opens nothing; a level outside 1 … 100 is
    /// ignored.
    ///
    /// - Returns: whether the stored result of `level` changed (a first or a better result).
    @discardableResult
    public mutating func record(level: Int, energySpent: Int, certified: Int, mode: EchoCartographerMode = .campaign,
                                trace: [EchoCartographerAction]) -> Bool {
        guard mode.awardsStars else { return false }
        let result: Result = Result(energySpent: energySpent,
                                    stars: Self.stars(energySpent: energySpent, certified: certified),
                                    trace: trace, verified: true)
        return store(result, level: level, opensNext: mode.opensLevels)
    }

    /// Removes the result of `level` (reconciliation drops a result whose trace does not replay); the frontier is
    /// unchanged. Nothing happens when `level` has no result.
    public mutating func drop(level: Int) {
        solved[level] = nil
    }

    /// Stores `result` for `level` under the rules of ``record(level:energySpent:certified:opensNext:)``.
    private mutating func store(_ result: Result, level: Int, opensNext: Bool) -> Bool {
        guard level >= 1 && level <= Self.levelCount else { return false }
        var improved: Bool = false
        if let old = solved[level] {
            let less: Bool = result.energySpent < old.energySpent
            let moreStars: Bool = result.energySpent == old.energySpent && result.stars > old.stars
            if less || moreStars {
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

    /// The daily level (1 … 100) of a calendar day: (d × 79) mod 100 + 1, where d is the days from 2026-01-01 to the
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
        let energySpent: Int
        let stars: Int
        let trace: [EchoCartographerAction]?
        let verified: Bool?
    }

    private enum CodingKeys: String, CodingKey {
        case solved
        case frontier
    }

    /// Decodes progress; the won levels are an array of `{level, energySpent, stars, trace, verified}`, where a missing
    /// trace is empty and a missing verified flag is false.
    ///
    /// - Throws: `DecodingError.dataCorrupted` for a frontier outside 1 … 100, a level outside 1 … 100 or repeated,
    ///   stars outside 1 … 3 or energy spent below 0.
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
                  entry.stars >= 1 && entry.stars <= 3, entry.energySpent >= 0 else {
                throw DecodingError.dataCorruptedError(forKey: .solved, in: container,
                                                       debugDescription: "invalid won level \(entry.level)")
            }
            solved[entry.level] = Result(energySpent: entry.energySpent, stars: entry.stars,
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
            entries.append(Entry(level: level, energySpent: result.energySpent, stars: result.stars,
                                 trace: result.trace, verified: result.verified))
        }
        try container.encode(entries, forKey: .solved)
    }
}
