// PlaygroundRecoveryDrawTests — feature 087 (A11-P06) T-A11-604 (FR-A11-611, FR-A11-612; US2). Short runs only (each
// test well under 10 s, no wall-clock assertion). Through the one app's session host on the simulator: with an
// experiment saved in the experience's storage (`ExperimentStore` over a temporary storage) and opened in a session, a
// drawing failure injected with the presenter's seam (`failNextDraw`, which throws `PlaygroundDrawError.injected`)
// fails the session and leaves `experiment-<slot>.json` byte for byte; a new session over the same storage opens,
// draws a non-blank frame, lists and opens the saved experiment. The stored schema-1, 2, 3 and 4 examples restore in a
// new engine with the digests they name, to the current snapshot schema 5.
import Foundation
import XCTest
@testable import PhysicsPlaygroundExperience
import PhysicsPlaygroundCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreSimulation

@MainActor
final class PlaygroundRecoveryDrawTests: XCTestCase {
    private var temporary: TemporaryPlaygroundStorage!
    private let slot = 2

    override func setUp() async throws {
        temporary = TemporaryPlaygroundStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    private var storage: ExperienceStorage { temporary.storage }

    // The pendulum preset after 30 ticks, as a saved experiment.
    private func savedDocument() -> ExperimentDocument {
        var random = SeededRandom(seed: 7)
        var world = Presets.make(.pendulum, random: &random, catalog: PlaygroundCore.catalog)
        for _ in 0..<30 { _ = WorldSimulation.tick(&world, catalog: PlaygroundCore.catalog) }
        return ExperimentDocument(name: "Swing", origin: .preset(1), world: world, slot: slot)
    }

    func testADrawingFailureFailsTheSessionAndKeepsTheSavedExperiment() async throws {
        let fileName = ExperimentStore.fileName(slot: slot)
        XCTAssertEqual(fileName, "experiment-2.json")
        let document = savedDocument()
        XCTAssertNoThrow(try ExperimentStore(storage: storage).save(document, slot: slot).get())
        let bytes = try storage.read(fileName)
        XCTAssertEqual(bytes, document.encoded())

        let session = ExperienceSession()
        let shell = try await PlaygroundTest.open(session, store: ExperimentStore(storage: storage))
        XCTAssertEqual(shell.presenter.mirror.slotNames[slot], "Swing")
        XCTAssertEqual(shell.presenter.openExperiment(slot: slot), "Opened “Swing”.")
        try PlaygroundTest.frames(session, 2)
        XCTAssertEqual(session.state, .running)
        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session (FR-A11-611)")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        XCTAssertEqual(try storage.read(fileName), bytes, "experiment-2.json is unchanged")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertEqual(try storage.read(fileName), bytes, "experiment-2.json is unchanged after close")
        XCTAssertEqual(storage.list(), [fileName])

        let fresh = ExperienceSession()
        defer { fresh.close() }
        let again = try await PlaygroundTest.open(fresh, store: ExperimentStore(storage: storage))
        XCTAssertFalse(again.presenter === shell.presenter, "the new session builds a new presenter")
        XCTAssertNil(fresh.failure)
        let host = try XCTUnwrap(fresh.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false), "the new session draws a frame")
        let pixels = host.pixelSize
        XCTAssertTrue(FrameChecks.isNonBlank(host.readPixels(), width: pixels.width, height: pixels.height))
        XCTAssertEqual(fresh.state, .running)
        XCTAssertEqual(again.presenter.mirror.slotNames[slot], "Swing", "the new session lists the saved experiment")
        XCTAssertEqual(try again.presenter.store.read(slot: slot).get(), document)
        XCTAssertEqual(again.presenter.openExperiment(slot: slot), "Opened “Swing”.")
        XCTAssertEqual(try PlaygroundTest.core(again).world, document.world, "the saved world opens")
        try PlaygroundTest.frames(fresh, 2)
        XCTAssertEqual(fresh.state, .running)
        XCTAssertEqual(try storage.read(fileName), bytes, "experiment-2.json is unchanged")
    }

    func testTheStoredSchemaOneToFourExamplesRestore() async throws {
        XCTAssertEqual(PlaygroundCore.snapshotSchema, 5)
        let examples = [PlaygroundCore.schemaOneExample(), PlaygroundCore.schemaTwoExample(),
                        PlaygroundCore.schemaThreeExample(), PlaygroundCore.schemaFourExample()]
        for (index, made) in examples.enumerated() {
            let example = try XCTUnwrap(made, "schema \(index + 1) example")
            XCTAssertEqual(example.version, index + 1)
            let snapshot = try ExperienceSnapshot(data: example.snapshot)
            XCTAssertEqual(snapshot.schemaVersion, example.version)
            var engine = ExperienceEngine<PlaygroundCore>(id: PlaygroundTest.id)
            try await engine.prepare(seed: 3)
            try engine.activate()
            try engine.restore(snapshot)
            XCTAssertEqual(try engine.digest().hex, example.expectedDigest, "schema \(index + 1) (FR-A11-612)")
            let core = try XCTUnwrap(engine.core)
            for world in [core.world, core.startingWorld] {
                XCTAssertEqual(world.schema, PhysicsWorld.schemaVersion, "schema \(index + 1)")
                XCTAssertEqual(world.validate(), [], "schema \(index + 1)")
            }
            XCTAssertEqual(try engine.snapshot().schemaVersion, PlaygroundCore.snapshotSchema,
                           "schema \(index + 1) is written again at schema 5")
        }
    }
}
