// WorldsRecoveryDrawTests — feature 094 (A12-P06) T-A12-605/606 (FR-A12-610–612; SC-A12-602; clarification Q5;
// research D3). Short runs only (each test well under 10 s, no wall-clock assertion). Through the one app's session
// host on the simulator: with a world saved to slot 0 (`WorldStore` over a temporary storage, with its thumbnail), a
// drawing failure injected with the presenter's seam (`failNextDraw`, which throws `WorldsDrawError.injected` once)
// fails the session and leaves `world-0.json` and `world-0.png` byte for byte; a new session over the same storage
// draws, lists and opens the saved world. The stored schema-1 example (`WorldsCore.schemaOneExample()`) still restores
// in a session, without a restore refusal, to the current schema 2.
import Foundation
import XCTest
@testable import TinyWorldsExperience
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
final class WorldsRecoveryDrawTests: XCTestCase {
    private var temporary: TemporaryWorldsStorage!

    override func setUp() async throws {
        temporary = TemporaryWorldsStorage()
    }

    override func tearDown() async throws {
        temporary.remove()
    }

    private var storage: ExperienceStorage { temporary.storage }

    func testAFailedDrawLeavesSavedWorldsUntouched() async throws {
        let json = WorldStore.fileName(slot: 0), png = WorldStore.pictureName(slot: 0)
        XCTAssertEqual([json, png], ["world-0.json", "world-0.png"])
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session, store: WorldStore(storage: storage))
        XCTAssertTrue(shell.handle(control: "prop.place", values: [0, 0, 0]).isAccepted)
        try WorldsTest.frames(session, 1)
        let saved = try WorldsTest.core(shell)
        XCTAssertEqual(shell.presenter.saveWorld(slot: 0, still: WorldsTest.stillRenderer(session)),
                       "Saved “Island, seed 1”.")
        let jsonBytes = try storage.read(json)
        let pngBytes = try storage.read(png)
        XCTAssertEqual(jsonBytes, try WorldDocument(state: saved.state).encode().get())
        XCTAssertFalse(pngBytes.isEmpty)
        XCTAssertEqual(session.state, .running)

        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session (FR-A12-611)")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        XCTAssertEqual(try storage.read(json), jsonBytes, "world-0.json is unchanged")
        XCTAssertEqual(try storage.read(png), pngBytes, "world-0.png is unchanged")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertEqual(try storage.read(json), jsonBytes, "world-0.json is unchanged after close")
        XCTAssertEqual(try storage.read(png), pngBytes, "world-0.png is unchanged after close")
        XCTAssertEqual(storage.list(), [json, png])

        let fresh = ExperienceSession()
        defer { fresh.close() }
        let again = try await WorldsTest.open(fresh, store: WorldStore(storage: storage))
        XCTAssertFalse(again.presenter === shell.presenter, "the new session builds a new presenter")
        XCTAssertNil(fresh.failure)
        let host = try XCTUnwrap(fresh.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false), "the new session draws a frame")
        XCTAssertGreaterThan(again.presenter.lastPartsDrawn, 0)
        XCTAssertEqual(fresh.state, .running)
        XCTAssertEqual(again.presenter.mirror.slotNames[0], "Island, seed 1", "the new session lists the saved world")
        XCTAssertEqual(again.presenter.mirror.slotStatus[0], "Holds “Island, seed 1”.")
        XCTAssertEqual(again.presenter.openWorld(slot: 0), "Opened “Island, seed 1”.")
        XCTAssertEqual(try WorldsTest.core(again).state, saved.state, "the saved world opens")
        try WorldsTest.frames(fresh, 1)
        XCTAssertEqual(again.presenter.lastPropsDrawn, 1)
        XCTAssertEqual(fresh.state, .running)
        XCTAssertEqual(try storage.read(json), jsonBytes, "opening never rewrites world-0.json")
        XCTAssertEqual(try storage.read(png), pngBytes, "opening never rewrites world-0.png")
    }

    func testTheSchemaOneExampleStillRestores() async throws {
        let example = try XCTUnwrap(WorldsCore.schemaOneExample())
        XCTAssertEqual(example.version, 1)
        let snapshot = try ExperienceSnapshot(data: example.snapshot)
        XCTAssertEqual(snapshot.schemaVersion, 1)
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await WorldsTest.open(session, seed: snapshot.seed, snapshot: snapshot)
        XCTAssertNil(session.lastRestoreRefusal, "the schema-1 example is not refused (FR-A12-612)")
        XCTAssertNil(session.failure)
        let core = try WorldsTest.core(shell)
        XCTAssertEqual(core.preset, .asteroidGarden)
        XCTAssertTrue(core.props.isEmpty)
        XCTAssertEqual(core.selection, WorldState.noSelection)
        XCTAssertEqual(core.light, .default)
        XCTAssertEqual(try shell.engine.digest().hex, example.expectedDigest)
        let current = try shell.snapshot()
        XCTAssertEqual(current.schemaVersion, WorldState.schemaVersion)
        XCTAssertEqual(WorldState.schemaVersion, 2)
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(current.payload.utf8))
                                    as? [String: Any])
        XCTAssertEqual(payload["schema"] as? Int, 2, "written again at schema 2")
        try WorldsTest.frames(session, 1)
        XCTAssertGreaterThan(shell.presenter.lastPartsDrawn, 0)
        XCTAssertEqual(session.state, .running)
    }
}
