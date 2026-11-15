// HighScoreTable — feature 078 (A10-P04) T-A10-402 (FR-A10-410, FR-A10-412; clarification 2; research D2; data-model
// "HighScoreEntry", "HighScoreTable"; edge cases "Equal scores", "A run that scores 0"). The local table of the best
// ten runs: board version 1, at most 10 `HighScoreEntry(score, wave, run)` with score 1…9,999,999, wave ≥ 1 and run
// ≥ 1, highest score first, equal scores in order of arrival (earlier run first), and `lastRun` (≥ 0), the highest
// run number whose end was processed. No date, name or device data is kept.
//
// `enter(_:)` processes one finished run:
// 1. A run number below 1 or not above `lastRun` is refused and nothing changes (a run is entered once, even when its
//    end is seen again after a restore).
// 2. Otherwise `lastRun` becomes the run number, whether or not the entry ranks, so the run is not processed again.
// 3. An entry with a score outside 1…9,999,999 (a run that scores 0) or a wave below 1 is not entered.
// 4. A valid entry is inserted after every entry with a higher or equal score; the table keeps its first ten. The
//    entry's 0-based rank is returned, or nil when it did not make the table (an entry equal to the tenth is cut).
//
// The file form is JSON with sorted keys (`encoded()`); `decode(_:)` reads the board version first and refuses a newer
// version, then decodes and validates: undecodable bytes (damaged or truncated) → `.damaged`, a later board version
// → `.newerVersion(v)`, a broken rule (order, count, limits, duplicate runs, an older version) → `.invalid(problems)`.
import Foundation

/// One entry of the high-score table.
public struct HighScoreEntry: Codable, Equatable, Sendable {
    /// The highest score an entry may have (``GameRun/maxScore``).
    public static let maxScore = GameRun.maxScore

    /// The run's final score, 1…9,999,999.
    public var score: Int
    /// The wave the run reached, ≥ 1.
    public var wave: Int
    /// The run's number (runs are counted from 1), ≥ 1.
    public var run: Int

    /// Creates an entry (validity is checked by ``validate()``).
    public init(score: Int, wave: Int, run: Int) {
        self.score = score; self.wave = wave; self.run = run
    }

    /// The entry's problems, empty when score is 1…9,999,999, wave ≥ 1 and run ≥ 1.
    public func validate() -> [String] {
        var problems: [String] = []
        if score < 1 || score > Self.maxScore { problems.append("score \(score) is outside 1…\(Self.maxScore)") }
        if wave < 1 { problems.append("wave \(wave) is below 1") }
        if run < 1 { problems.append("run \(run) is below 1") }
        return problems
    }

    /// True when `self` ranks above `other`: a higher score, or an equal score from an earlier run.
    public func ranksAbove(_ other: HighScoreEntry) -> Bool {
        score != other.score ? score > other.score : run < other.run
    }
}

/// Why a stored table could not be read.
public enum HighScoreTableError: Error, Equatable, Sendable {
    /// The bytes are not a table (damaged or truncated JSON, wrong types, missing fields).
    case damaged
    /// The table was written by a later board version.
    case newerVersion(Int)
    /// The table decodes but breaks the rules; the problems are listed.
    case invalid([String])

    /// A short reason for reports and logs.
    public var reason: String {
        switch self {
        case .damaged: return "the high-score file is damaged"
        case .newerVersion(let version):
            return "the high-score file has board version \(version), newer than \(HighScoreTable.boardVersion)"
        case .invalid(let problems): return "the high-score file is invalid: " + problems.joined(separator: "; ")
        }
    }
}

/// The local table of the best runs (see the file header).
public struct HighScoreTable: Codable, Equatable, Sendable {
    /// The board version this code writes and reads.
    public static let boardVersion = 1
    /// The most entries kept.
    public static let maxEntries = 10

    /// The table's board version (``HighScoreTable/boardVersion`` for a valid table).
    public var boardVersion: Int
    /// The entries, best first (at most ``maxEntries``).
    public private(set) var entries: [HighScoreEntry]
    /// The highest run number whose end was processed, ≥ 0.
    public private(set) var lastRun: Int

    /// An empty table.
    public init() {
        boardVersion = Self.boardVersion; entries = []; lastRun = 0
    }

    /// Creates a table from all of its fields as given (validity is checked by ``validate()``).
    public init(boardVersion: Int = HighScoreTable.boardVersion, entries: [HighScoreEntry], lastRun: Int) {
        self.boardVersion = boardVersion; self.entries = entries; self.lastRun = lastRun
    }

    /// The best entry, or nil for an empty table.
    public var best: HighScoreEntry? { entries.first }

    /// Processes the end of a run (see the file header) and returns the entry's 0-based rank, or nil when the run was
    /// refused (run below 1 or already processed), its entry is invalid (score 0, wave below 1) or it did not rank.
    @discardableResult
    public mutating func enter(_ entry: HighScoreEntry) -> Int? {
        guard entry.run >= 1, entry.run > lastRun else { return nil }
        lastRun = entry.run
        guard entry.validate().isEmpty else { return nil }
        let rank = entries.firstIndex(where: { entry.ranksAbove($0) }) ?? entries.count
        guard rank < Self.maxEntries else { return nil }
        entries.insert(entry, at: rank)
        if entries.count > Self.maxEntries { entries.removeLast(entries.count - Self.maxEntries) }
        return rank
    }

    /// The table's problems, empty when it is valid: board version 1, at most 10 entries, each valid, best first with
    /// equal scores by earlier run, no run twice, `lastRun` ≥ 0 and not below any entry's run.
    public func validate() -> [String] {
        var problems: [String] = []
        if boardVersion != Self.boardVersion {
            problems.append("board version \(boardVersion) is not \(Self.boardVersion)")
        }
        if entries.count > Self.maxEntries {
            problems.append("\(entries.count) entries exceed \(Self.maxEntries)")
        }
        for (index, entry) in entries.enumerated() {
            problems += entry.validate().map { "entry \(index): \($0)" }
        }
        for index in entries.indices.dropFirst() where !entries[index - 1].ranksAbove(entries[index]) {
            problems.append("entry \(index) is out of order")
        }
        if Set(entries.map(\.run)).count != entries.count { problems.append("a run appears more than once") }
        if lastRun < 0 { problems.append("last run \(lastRun) is negative") }
        if let highest = entries.map(\.run).max(), highest > lastRun {
            problems.append("run \(highest) is after the last run \(lastRun)")
        }
        return problems
    }

    /// The table as JSON with sorted keys (the file form). Encoding plain integers cannot fail; an empty `Data` would
    /// only result from an encoder failure and reads back as `.damaged`.
    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(self)) ?? Data()
    }

    /// Reads a table from its file form: `.damaged` for bytes that do not decode, `.newerVersion` for a later board
    /// version, `.invalid` for a table that breaks the rules of ``validate()``.
    public static func decode(_ data: Data) -> Result<HighScoreTable, HighScoreTableError> {
        struct VersionProbe: Decodable { var boardVersion: Int }
        let decoder = JSONDecoder()
        guard let probe = try? decoder.decode(VersionProbe.self, from: data) else { return .failure(.damaged) }
        if probe.boardVersion > boardVersion { return .failure(.newerVersion(probe.boardVersion)) }
        guard let table = try? decoder.decode(HighScoreTable.self, from: data) else { return .failure(.damaged) }
        let problems = table.validate()
        return problems.isEmpty ? .success(table) : .failure(.invalid(problems))
    }
}
