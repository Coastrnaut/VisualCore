// ContentQATests — feature 100 (A13-P05) T-A13-503 (FR-A13-510, FR-A13-511; SC-A13-503; clarification Q4; research
// D4). The content QA, host-free and short: 20 of 20 bundled levels pass with recorded turns equal to the fewest; one
// damaged fixture per check, built from catalog level lm-01 (or, for a longer solution, a small built board), fails
// with its named check; the Markdown document has the title, the table and the totals line, names failures and is
// deterministic; and the committed `docs/apps/light-maze/content-qa.md` equals the generated document.
import Foundation
import LightMazeCore
import Testing

@Suite struct ContentQATests {
    private let catalog = LevelCatalog.bundled

    @Test func everyBundledLevelPasses() {
        let results: [LevelQA] = ContentQA.results(catalog)
        #expect(results.count == 20)
        #expect(results.map(\.id) == catalog.levels.map(\.id))
        for result: LevelQA in results {
            #expect(result.passes, "\(result.id): \(result.failures.map(\.rawValue))")
            #expect(result.fewestTurns == result.recordedTurns, "\(result.id) recorded turns are the fewest")
        }
        #expect(results.filter(\.passes).count == 20)
    }

    @Test func theCheckCodesAreInReportOrder() {
        let codes: [String] = QACheck.allCases.map(\.rawValue)
        #expect(codes == ["unsolvable", "wrong-solution", "longer-solution", "solved-start", "no-license"])
    }

    /// A wall directly in front of lm-01's emitter (0, 2) facing east: no orientation set lights the target. The
    /// recorded solution then cannot light it either, so `wrong-solution` follows necessarily (a recorded solution
    /// that lit every target would be a set the search finds); the list is exactly these two, in order.
    @Test func aBlockedEmitterIsUnsolvable() {
        var level: Level = catalog.levels[0]
        level.board.tiles.append(.wall(1, 2))
        #expect(Solver.solve(level.board) == .unsolvable(examined: 2))
        let result: LevelQA = ContentQA.check(level)
        #expect(result.fewestTurns == nil)
        #expect(result.failures == [.unsolvable, .wrongSolution])
    }

    /// lm-01's one mirror starts `\` and is solved `/`; recording `\` (the start) lights nothing. The recorded
    /// solution then has 0 turns, fewer than the fewest 1, so only `wrong-solution` fails.
    @Test func aFlippedSolutionEntryIsWrong() {
        var level: Level = catalog.levels[0]
        #expect(level.startOrientations != level.solution)
        level.solution[0] = level.solution[0].toggled
        let result: LevelQA = ContentQA.check(level)
        #expect(result.fewestTurns == 1 && result.recordedTurns == 0)
        #expect(result.failures == [.wrongSolution])
    }

    /// A built 4×4 board: emitter (0, 0) east, a mirror at (2, 0) starting `\` (the beam leaves the board) that must
    /// turn to `/` to send it to the target (2, 3), and a mirror at (0, 2) the beam never touches. Recorded with both
    /// mirrors turned: it lights the target, but with 2 turns where 1 is enough.
    @Test func aLongerRecordedSolutionIsNamed() {
        let board = Board(width: 4, height: 4, tiles: [.emitter(0, 0, .east), .mirror(2, 0, .backslash),
                                                       .mirror(0, 2, .slash), .target(2, 3)])
        let level = Level(id: "qa-longer", name: "Longer", board: board, solution: [.slash, .backslash],
                          author: LevelCatalog.projectAuthor, license: "MIT")
        #expect(!BeamTracer.trace(board).isSolved)
        let result: LevelQA = ContentQA.check(level)
        #expect(result.fewestTurns == 1 && result.recordedTurns == 2)
        #expect(result.failures == [.longerSolution])
    }

    @Test func aStartEqualToTheSolutionIsSolved() throws {
        var level: Level = catalog.levels[0]
        level.board = try #require(level.solvedBoard)
        let result: LevelQA = ContentQA.check(level)
        #expect(result.fewestTurns == 0 && result.recordedTurns == 0)
        #expect(result.failures.contains(.solvedStart))
        #expect(result.failures == [.solvedStart])
    }

    @Test func anEmptyLicenseIsNamed() {
        var level: Level = catalog.levels[0]
        level.license = ""
        let result: LevelQA = ContentQA.check(level)
        #expect(result.failures == [.noLicense])
        var unsupported: Level = catalog.levels[1]
        unsupported.license = "GPL-3.0"
        #expect(ContentQA.check(unsupported).failures == [.noLicense])
        var blankAuthor: Level = catalog.levels[2]
        blankAuthor.author = "  "
        #expect(ContentQA.check(blankAuthor).failures == [.noLicense])
    }

    @Test func theMarkdownListsEveryLevelDeterministically() {
        let text: String = ContentQA.markdown(catalog)
        #expect(text.hasPrefix("# Light Maze — content QA\n"))
        #expect(text.contains("UPDATE_CONTENT_QA=1"))
        #expect(text.contains("| Level | Name | Fewest turns | Recorded turns | Result |\n|---|---|---|---|---|\n"))
        #expect(text.contains("| lm-01 | First light | 1 | 1 | pass |"))
        for result: LevelQA in ContentQA.results(catalog) {
            let turns = String(result.recordedTurns)
            #expect(text.contains("| \(result.id) | "), "\(result.id) is listed")
            #expect(text.contains(" | \(turns) | \(turns) | pass |"))
        }
        #expect(text.hasSuffix("\n20 of 20 levels pass.\n"))
        #expect(ContentQA.markdown(catalog) == text)
        var damaged = catalog
        damaged.levels[0].board.tiles.append(.wall(1, 2))
        damaged.levels[1].name = "Around|the\ncorner"
        damaged.levels[1].license = ""
        let damagedText: String = ContentQA.markdown(damaged)
        #expect(damagedText.contains("| lm-01 | First light | — | 1 | unsolvable, wrong-solution |"))
        #expect(damagedText.contains("| lm-02 | Around\\|the corner | 2 | 2 | no-license |"))
        #expect(damagedText.hasSuffix("\n18 of 20 levels pass.\n"))
    }

    /// The committed `docs/apps/light-maze/content-qa.md` equals the generated document; run the package tests with
    /// `UPDATE_CONTENT_QA=1` (on the simulator `TEST_RUNNER_UPDATE_CONTENT_QA=1`) to rewrite it. Reads the repository
    /// through `#filePath`, so it runs from the repository's own package, not from a symlinked scratch copy.
    @Test func theCommittedQADocumentMatchesTheCatalog() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let file = root.appendingPathComponent("docs/apps/light-maze/content-qa.md")
        let text: String = ContentQA.markdown(catalog)
        let environment = ProcessInfo.processInfo.environment
        if environment["UPDATE_CONTENT_QA"] == "1" || environment["TEST_RUNNER_UPDATE_CONTENT_QA"] == "1" {
            try Data(text.utf8).write(to: file)
        }
        let committed = try String(contentsOf: file, encoding: .utf8)
        #expect(committed == text, "run with UPDATE_CONTENT_QA=1 and commit the document")
        for level: Level in catalog.levels { #expect(committed.contains(level.id), "\(level.id) is listed") }
    }
}
