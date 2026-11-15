// ContentQA — feature 100 (A13-P05) T-A13-503 (FR-A13-510, FR-A13-511; SC-A13-503; clarification Q4; research D4).
// The release content QA of the Light Maze level catalog. Every level is checked with the search (`Solver.solve`) and
// the tracer (`BeamTracer.trace`), and each failed check is named, in this order:
// 1. `unsolvable`: the search finds no orientation set that solves the board (or refuses the board).
// 2. `wrong-solution`: the recorded solution does not fit the turnable tiles or does not light every target.
// 3. `longer-solution`: the recorded solution needs more turns from the start than the fewest the search found (no
//    level has an allowance).
// 4. `solved-start`: the start already lights every target.
// 5. `no-license`: the level has a license problem by the rule of `LicenseAudit` (`LevelCatalog.licenseError`: author
//    or license missing after trimming whitespace, or a license outside the allowed list).
// The result of a level holds its id, the fewest turns (nil when the search found no solution), the recorded turns
// (`Solver.turns(from:to:)` from the start orientations to the recorded solution) and the failed checks. The Markdown
// text of `docs/apps/light-maze/content-qa.md` is deterministic (no dates), so regenerating it from an unchanged
// catalog gives the same bytes; `ContentQATests` compares the committed document with it.
import Foundation

/// One content QA check of a level; the raw values are the names used in documents and tests.
public enum QACheck: String, CaseIterable, Sendable {
    /// The search finds no orientation set that solves the board.
    case unsolvable
    /// The recorded solution does not light every target.
    case wrongSolution = "wrong-solution"
    /// The recorded solution needs more turns than the fewest possible.
    case longerSolution = "longer-solution"
    /// The start already lights every target.
    case solvedStart = "solved-start"
    /// The level's author or license is missing, or its license is not allowed.
    case noLicense = "no-license"
}

/// The content QA result of one level.
public struct LevelQA: Equatable, Sendable {
    /// The level id (`lm-01` …).
    public let id: String
    /// The fewest turns that solve the level from its start, or nil when the search found no solution.
    public let fewestTurns: Int?
    /// The turns of the recorded solution from the start orientations.
    public let recordedTurns: Int
    /// The failed checks in the order of ``QACheck/allCases``; empty when the level passes.
    public let failures: [QACheck]

    /// Creates a result from its fields.
    public init(id: String, fewestTurns: Int?, recordedTurns: Int, failures: [QACheck]) {
        self.id = id; self.fewestTurns = fewestTurns; self.recordedTurns = recordedTurns; self.failures = failures
    }

    /// Whether every check passed.
    public var passes: Bool { failures.isEmpty }
}

/// The release content QA of a Light Maze level catalog (see the file header).
public enum ContentQA {
    /// The document title.
    public static let title = "Light Maze — content QA"

    /// Checks `level`: searches its board, traces its recorded solution and its start, and checks its license.
    public static func check(_ level: Level) -> LevelQA {
        let fewest: Int?
        switch Solver.solve(level.board) {
        case .solved(_, let turns, _): fewest = turns
        case .unsolvable, .refused: fewest = nil
        }
        let recorded = Solver.turns(from: level.startOrientations, to: level.solution)
        var failures: [QACheck] = []
        if fewest == nil { failures.append(.unsolvable) }
        if !(level.solvedBoard.map { BeamTracer.trace($0).isSolved } ?? false) { failures.append(.wrongSolution) }
        if let fewest, recorded > fewest { failures.append(.longerSolution) }
        if BeamTracer.trace(level.board).isSolved { failures.append(.solvedStart) }
        if LevelCatalog.licenseError(author: level.author, license: level.license) != nil {
            failures.append(.noLicense)
        }
        return LevelQA(id: level.id, fewestTurns: fewest, recordedTurns: recorded, failures: failures)
    }

    /// One result per level in catalog order.
    public static func results(_ catalog: LevelCatalog) -> [LevelQA] { catalog.levels.map(check) }

    /// The Markdown document: the title, a short note, a table `Level | Name | Fewest turns | Recorded turns | Result`
    /// with every level ("pass" or the failed check names joined by ", "; "—" for no fewest turns) and a totals line
    /// "P of N levels pass.". Cell text has `|` escaped and line breaks replaced by spaces; an empty cell shows "—".
    public static func markdown(_ catalog: LevelCatalog) -> String {
        var lines: [String] = [
            "# \(title)",
            "",
            "Every Light Maze level is checked by the bounded search and the beam tracer: solvable, recorded solution",
            "lights every target, recorded solution no longer than the fewest turns, start not solved, author and",
            "license present. This table is generated from `LevelCatalog.bundled` by `ContentQA.markdown(_:)` and",
            "checked by `ContentQATests`; regenerate it with `UPDATE_CONTENT_QA=1` (on the simulator",
            "`TEST_RUNNER_UPDATE_CONTENT_QA=1`).",
            "",
            "| Level | Name | Fewest turns | Recorded turns | Result |",
            "|---|---|---|---|---|",
        ]
        let all = results(catalog)
        for (level, result) in zip(catalog.levels, all) {
            let verdict = result.passes ? "pass" : result.failures.map(\.rawValue).joined(separator: ", ")
            let cells = [result.id, level.name, result.fewestTurns.map(String.init) ?? "", String(result.recordedTurns),
                         verdict].map(cell)
            lines.append("| " + cells.joined(separator: " | ") + " |")
        }
        lines.append("")
        lines.append("\(all.filter(\.passes).count) of \(all.count) levels pass.")
        return lines.joined(separator: "\n") + "\n"
    }

    /// `text` safe for a Markdown table cell.
    private static func cell(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        let escaped = flat.replacingOccurrences(of: "|", with: "\\|")
        return escaped.isEmpty ? "—" : escaped
    }
}
