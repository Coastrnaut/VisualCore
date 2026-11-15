// ArcadeRecoveryDrawTests — feature 080 (A10-P06) T-A10-605 (FR-A10-611, FR-A10-612; SC-A10-602; US2). Short runs
// only. Through the one app's session host on the simulator: with a valid high-score table saved in the experience's
// storage (the committed valid sample), a drawing failure injected with the presenter's seam (`failNextDraw`, which
// throws `ArcadeDrawError.injected`) fails the session and leaves `high-scores.json` byte for byte; a new session over
// the same storage opens, draws a non-blank frame and shows the saved table. The stored schema-1, 2 and 3 examples
// restore in a new engine with the digests they name.
import Foundation
import XCTest
@testable import NeonArcadeExperience
import NeonArcadeCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class ArcadeRecoveryDrawTests: XCTestCase {
    private var temporary: TemporaryArcadeStorage!

    override func setUp() async throws {
        temporary = TemporaryArcadeStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    private var storage: ExperienceStorage { temporary.storage }

    func testADrawingFailureFailsTheSessionAndKeepsTheHighScores() async throws {
        let folder = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let bytes = try Data(contentsOf: folder.appendingPathComponent("high-scores-valid.json"))
        try storage.write(bytes, to: HighScoreStore.fileName)
        let store = HighScoreStore(storage: storage)
        XCTAssertNil(store.problem)
        let saved = store.table
        XCTAssertEqual(saved.entries.count, 3)

        let session = ExperienceSession()
        let experience = try await ArcadeTest.openExperience(session, highScores: store)
        try ArcadeTest.frames(session, 2)
        XCTAssertEqual(session.state, .running)
        experience.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session (FR-A10-611)")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(experience.presenter.failNextDraw, "the seam clears itself")
        XCTAssertEqual(try storage.read(HighScoreStore.fileName), bytes, "high-scores.json is unchanged")
        session.close()
        XCTAssertEqual(try storage.read(HighScoreStore.fileName), bytes, "high-scores.json is unchanged after close")

        let fresh = ExperienceSession()
        defer { fresh.close() }
        let reopened = HighScoreStore(storage: storage)
        let again = try await ArcadeTest.openExperience(fresh, highScores: reopened)
        XCTAssertFalse(again === experience, "the new session builds a new experience")
        XCTAssertNil(fresh.failure)
        let host = try XCTUnwrap(fresh.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false), "the new session draws a frame")
        let pixels = host.pixelSize
        XCTAssertTrue(FrameChecks.isNonBlank(host.readPixels(), width: pixels.width, height: pixels.height))
        XCTAssertEqual(fresh.state, .running)
        XCTAssertNil(again.presenter.highScores.problem)
        XCTAssertEqual(again.presenter.highScores.table, saved, "the new session shows the saved table")
        XCTAssertEqual(try storage.read(HighScoreStore.fileName), bytes, "high-scores.json is unchanged")
    }

    func testTheStoredSchemaOneToThreeExamplesRestore() async throws {
        let examples = [ArcadeCore.schemaOneExample(), ArcadeCore.schemaTwoExample(), ArcadeCore.schemaThreeExample()]
        for (index, made) in examples.enumerated() {
            let example = try XCTUnwrap(made, "schema \(index + 1) example")
            XCTAssertEqual(example.version, index + 1)
            var engine = ExperienceEngine<ArcadeCore>(id: ArcadeTest.id)
            try await engine.prepare(seed: 3)
            try engine.activate()
            try engine.restore(ExperienceSnapshot(data: example.snapshot))
            XCTAssertEqual(try engine.digest().hex, example.expectedDigest, "schema \(index + 1)")
            let core = try XCTUnwrap(engine.core)
            XCTAssertEqual(core.run.schema, GameRun.currentSchema, "schema \(index + 1)")
            XCTAssertEqual(core.run.validate(), [], "schema \(index + 1)")
        }
    }
}
