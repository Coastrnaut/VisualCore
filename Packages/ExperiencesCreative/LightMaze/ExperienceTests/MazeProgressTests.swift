// MazeProgressTests — feature 098 (A13-P03) T-A13-304 (FR-A13-301, FR-A13-302, FR-A13-310, FR-A13-320; SC-A13-301,
// SC-A13-302; clarifications Q1, Q3 and Q4; contract contracts/progress.md). Level progress through the one app's
// session host and the presenter, short runs only (each test well under 10 s, no wall-clock assertion):
//   - solving levels 1–3 in order (the Level choice, then `tile.select` and `tile.turn` of each level's recorded
//     solution, frames drawn between) records them solved with their move counts as best, opens level 4 and leaves
//     level 5 locked; each solve is saved once;
//   - undoing to unsolved and solving again records nothing new and saves nothing;
//   - choosing a locked level is refused in words ("Level 5 is locked; solve level 4 first.") and the engine's level
//     stays as it was; Next level is disabled while the next level is locked;
//   - a new presenter over the same storage loads equal progress;
//   - a damaged progress file opens with fresh progress, reports `damaged`, stays byte for byte until the next solve
//     replaces it.
import Foundation
import XCTest
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreExperience
import VisualCoreExperienceHost

@MainActor
final class MazeProgressTests: XCTestCase {
    private var temporary: TemporaryMazeStorage!

    override func setUp() async throws {
        temporary = TemporaryMazeStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    /// The `tile.select` and `tile.turn` actions of level index `level`'s recorded solution (the entries of
    /// `MazeCore.fixtureEntries(level:)` after the level choice).
    private func solutionActions(level: Int) -> [(control: String, values: [Double])] {
        var actions: [(control: String, values: [Double])] = []
        for entry in MazeCore.fixtureEntries(level: level).dropFirst() {
            if let action = entry.action { actions.append((action.control, action.values)) }
        }
        return actions
    }

    /// The number of turns in level index `level`'s recorded solution.
    private func turns(level: Int) -> Int {
        var count = 0
        for action in solutionActions(level: level) where action.control == "tile.turn" { count += 1 }
        return count
    }

    /// Chooses level index `level` as a person does, draws a frame, plays its recorded solution and draws a frame.
    private func solve(level: Int, shell: ExperienceShell<MazePresenter>, session: ExperienceSession) throws {
        XCTAssertEqual(shell.presenter.chooseLevel(level, port: shell.port), "", "level \(level + 1) is open")
        try MazeTest.frames(session, 1)
        XCTAssertFalse(try MazeTest.core(shell).isSolved, "level \(level + 1) starts unsolved")
        for action in solutionActions(level: level) {
            XCTAssertTrue(shell.handle(control: action.control, values: action.values).isAccepted,
                          "level \(level + 1): \(action.control)")
        }
        try MazeTest.frames(session, 1)
        XCTAssertTrue(try MazeTest.core(shell).isSolved, "level \(level + 1) solved")
    }

    func testSolvingLevelsOneToThreeInOrderOpensLevelFourAndLeavesFiveLocked() async throws {
        let store = ProgressStore(storage: temporary.storage)
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, progressStore: store)
        let presenter = shell.presenter
        XCTAssertNil(presenter.progressRefusal, "no file yet")
        XCTAssertEqual(presenter.progress, LightMazeCore.Progress.fresh())
        XCTAssertTrue(presenter.progress.isOpen(0))
        XCTAssertFalse(presenter.progress.isOpen(1))
        XCTAssertFalse(MazeControls.nextEnabled(index: 0, count: 20, progress: presenter.mirror.progress),
                       "Next level is disabled while level 2 is locked")

        for level in 0..<3 {
            try solve(level: level, shell: shell, session: session)
            XCTAssertEqual(store.writes, level + 1, "each solve is saved once")
            XCTAssertTrue(MazeControls.nextEnabled(index: level, count: 20, progress: presenter.mirror.progress),
                          "Next level is enabled once level \(level + 2) is open")
        }
        let progress = presenter.progress
        for level in 0..<3 {
            XCTAssertTrue(progress.isSolved(level), "level \(level + 1) solved")
            XCTAssertEqual(progress.best(level), max(1, turns(level: level)), "level \(level + 1) best")
        }
        XCTAssertTrue(progress.isOpen(3), "level 4 open")
        XCTAssertFalse(progress.isSolved(3))
        XCTAssertNil(progress.best(3))
        XCTAssertFalse(progress.isOpen(4), "level 5 locked")
        XCTAssertEqual(presenter.recordedSolves, 3)
        XCTAssertNil(presenter.lastSaveRefusal)
        XCTAssertEqual(presenter.mirror.progress, progress, "the controls see the progress")
        XCTAssertEqual(try temporary.storage.read(ProgressStore.fileName), progress.encoded())
        XCTAssertEqual(MazeControls.menuWords(index: 4, name: "Name", progress: progress), "5. Name (locked)")
        XCTAssertEqual(MazeControls.menuWords(index: 3, name: "Name", progress: progress), "4. Name")
        XCTAssertEqual(MazeControls.menuWords(index: 0, name: "Name", progress: progress),
                       "1. Name (solved, best \(max(1, turns(level: 0))))")

        // More frames of the solved level record nothing again.
        try MazeTest.frames(session, 3)
        XCTAssertEqual(store.writes, 3)
        session.close()
    }

    func testUndoToUnsolvedAndBackDoesNotCountTwice() async throws {
        let store = ProgressStore(storage: nil)
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, progressStore: store)
        let presenter = shell.presenter
        try solve(level: 0, shell: shell, session: session)
        XCTAssertEqual(presenter.progress.best(0), 1)
        XCTAssertEqual(store.writes, 1)
        XCTAssertEqual(presenter.mirror.moveCount, 1, "Undo shows 1 move")
        XCTAssertEqual(MazeControls.movesWords(presenter.mirror.moveCount), "1 move")

        XCTAssertTrue(shell.handle(control: "move.undo").isAccepted)
        try MazeTest.frames(session, 1)
        XCTAssertFalse(try MazeTest.core(shell).isSolved, "unsolved after the undo")
        XCTAssertEqual(presenter.mirror.moveCount, 0)
        XCTAssertEqual(MazeControls.movesWords(0), "0 moves")
        XCTAssertEqual(shell.handle(control: "move.undo"), .rejected(.rule(code: MazeRule.noMoves)))
        XCTAssertEqual(MazePresenter.answerWords(control: "move.undo",
                                                 result: .rejected(.rule(code: MazeRule.noMoves))),
                       "There is no move to undo.")
        XCTAssertTrue(shell.handle(control: "tile.turn").isAccepted, "the mirror is still selected")
        try MazeTest.frames(session, 1)
        XCTAssertTrue(try MazeTest.core(shell).isSolved)
        XCTAssertEqual(presenter.recordedSolves, 1, "solving again in as many moves changes nothing")
        XCTAssertEqual(store.writes, 1, "nothing new is saved")
        XCTAssertEqual(presenter.progress.best(0), 1)
        XCTAssertTrue(presenter.progress.isOpen(1))
        XCTAssertFalse(presenter.progress.isOpen(2))
        session.close()
    }

    func testChoosingALockedLevelIsRefusedInWordsAndTheLevelStays() async throws {
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session)
        let presenter = shell.presenter
        let before = try MazeTest.core(shell)
        XCTAssertEqual(presenter.chooseLevel(4, port: shell.port), "Level 5 is locked; solve level 4 first.")
        XCTAssertEqual(presenter.mirror.message, "Level 5 is locked; solve level 4 first.")
        XCTAssertEqual(presenter.chooseLevel(1, port: shell.port), "Level 2 is locked; solve level 1 first.")
        XCTAssertEqual(try MazeTest.core(shell), before, "the engine's level is unchanged")
        XCTAssertEqual(try MazeTest.core(shell).state.levelIndex, 0)
        var sent: [String] = []
        XCTAssertEqual(presenter.chooseLevel(19) { control, _ in
            sent.append(control)
            return .accepted
        }, "Level 20 is locked; solve level 19 first.")
        XCTAssertEqual(sent, [], "a locked choice sends nothing")
        XCTAssertEqual(presenter.chooseLevel(0, port: shell.port), "", "level 1 is always open")
        XCTAssertEqual(presenter.mirror.message, "")
        XCTAssertNil(presenter.lockedWords(0))
        XCTAssertEqual(presenter.lockedWords(6), "Level 7 is locked; solve level 6 first.")
        XCTAssertNil(presenter.lockedWords(20), "outside the catalog the engine answers")
        session.close()
    }

    func testANewPresenterOverTheSameStorageLoadsEqualProgress() async throws {
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, progressStore: ProgressStore(storage: temporary.storage))
        try solve(level: 0, shell: shell, session: session)
        try solve(level: 1, shell: shell, session: session)
        let saved = shell.presenter.progress
        session.close()

        let id = try XCTUnwrap(LightMazeExperience.id)
        let reopened = MazePresenter(experienceID: id, progressStore: ProgressStore(storage: temporary.storage))
        XCTAssertNil(reopened.progressRefusal)
        XCTAssertEqual(reopened.progress, saved)
        XCTAssertEqual(reopened.progress.encoded(), saved.encoded())
        XCTAssertEqual(reopened.mirror.progress, saved)
        XCTAssertTrue(reopened.progress.isOpen(2))
        XCTAssertFalse(reopened.progress.isOpen(3))
    }

    func testADamagedProgressFileOpensWithFreshProgressAndReportsTheRefusal() async throws {
        let storage = temporary.storage
        let damaged = Data("{\"levels\":[{\"id\":\"lm-01\"".utf8)
        try storage.write(damaged, to: ProgressStore.fileName)
        let store = ProgressStore(storage: storage)
        let session = ExperienceSession()
        let shell = try await MazeTest.open(session, progressStore: store)
        let presenter = shell.presenter
        XCTAssertEqual(presenter.progressRefusal, ProgressRefusal.damaged.rawValue)
        XCTAssertEqual(presenter.progressRefusal, "damaged")
        XCTAssertEqual(presenter.progress, LightMazeCore.Progress.fresh(), "play starts from fresh progress")
        try MazeTest.frames(session, 2)
        XCTAssertEqual(try storage.read(ProgressStore.fileName), damaged, "the refused file is left untouched")
        XCTAssertEqual(store.writes, 0)

        try solve(level: 0, shell: shell, session: session)
        XCTAssertEqual(store.writes, 1, "the next real change replaces the file")
        XCTAssertEqual(try storage.read(ProgressStore.fileName), presenter.progress.encoded())
        session.close()
    }
}
