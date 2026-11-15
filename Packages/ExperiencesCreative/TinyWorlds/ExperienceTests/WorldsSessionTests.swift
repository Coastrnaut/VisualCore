// WorldsSessionTests — feature 089 (A12-P01) T-A12-104 (FR-A12-120, FR-A12-121, FR-A12-122; clarification 4;
// SC-A12-103). The A12 adapter inside the one app's session host on the simulator, short runs only (each test well
// under 10 s, no wall-clock assertion): the first frame draws the island and describes it in words, and actions change
// the description; a suspension of any length changes nothing and the resume continues from the same state; the state
// saved by the shell restores identically in a new session; newer and damaged saved states are refused and the
// default world opens; a context recreation rebuilds the renderers and keeps the digest; reopening keeps the drawing
// resources steady and closing leaves no GPU object behind.
import Foundation
import XCTest
import VisualCoreDiagnostics
@testable import TinyWorldsExperience
import TinyWorldsCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
final class WorldsSessionTests: XCTestCase {
    func testTheFirstFrameDrawsTheIslandAndDescribesIt() async throws {
        XCTAssertEqual(TinyWorldsExperience.id?.rawValue, "a12.tiny-worlds")
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session)
        let presenter = shell.presenter
        XCTAssertEqual(session.hostsAlive, 1, "the session's one render host")
        XCTAssertTrue(presenter.isLive)
        XCTAssertGreaterThan(shell.diagnostics.gpu?.objects ?? 0, 0, "drawn through the host's registry")
        let core = try WorldsTest.core(shell)
        XCTAssertEqual(core.state, WorldState.initial)
        XCTAssertEqual(presenter.lastPartsDrawn, 2, "the island's terrain and sea")
        XCTAssertEqual(presenter.renderers.count, 2)
        let builds = presenter.rebuildCount
        XCTAssertGreaterThanOrEqual(builds, 1)
        XCTAssertEqual(shell.accessibilitySummary,
                       "Tiny Worlds: Island, seed 1; view from the north-east, 35 degrees up, 18 metres away.")
        XCTAssertTrue(presenter.mirror.ready)
        XCTAssertEqual(presenter.mirror.presetIndex, 0)
        XCTAssertEqual(presenter.nativeActions, Set(WorldsCore.actionIDs))
        XCTAssertEqual(presenter.gestureActions, ["view.orbit", "view.zoom"], "drag and pinch (feature 090)")
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions),
                       [])

        XCTAssertTrue(shell.handle(control: "world.preset", values: [1]).isAccepted)
        XCTAssertTrue(shell.handle(control: "view.orbit", values: [-90, 10]).isAccepted)
        XCTAssertTrue(shell.handle(control: "view.zoom", values: [1.25]).isAccepted)
        XCTAssertEqual(shell.accessibilitySummary,
                       "Tiny Worlds: Asteroid garden, seed 1; view from the north-west, 45 degrees up, 14 metres away.")
        XCTAssertEqual(presenter.mirror.presetIndex, 1)
        try WorldsTest.frames(session, 1)
        XCTAssertEqual(presenter.lastPartsDrawn, 1, "the asteroid garden has no sea plane")
        XCTAssertEqual(presenter.rebuildCount, builds + 1, "a new terrain rebuilds the renderers")
        XCTAssertTrue(shell.handle(control: "world.seed").isAccepted)
        let seed = try WorldsTest.core(shell).seed
        XCTAssertTrue(shell.accessibilitySummary.contains("Asteroid garden, seed \(seed);"), shell.accessibilitySummary)
        XCTAssertEqual(presenter.mirror.seed, seed)

        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertFalse(presenter.isLive)
        XCTAssertEqual(presenter.renderers.count, 0, "the renderers are released in teardown")
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }

    func testASuspensionChangesNothing() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session)
        XCTAssertTrue(shell.handle(control: "view.orbit", values: [30, 0]).isAccepted)
        try WorldsTest.frames(session, 20)
        let before = try WorldsTest.core(shell)
        let digest = try shell.engine.digest()
        let stepIndex = shell.engine.stepIndex
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        for _ in 0..<10 { _ = session.renderHost?.renderOneFrame(present: false) }
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(try WorldsTest.core(shell), before, "nothing changes while suspended")
        XCTAssertEqual(shell.engine.stepIndex, stepIndex)

        session.setScenePhase(.active)
        XCTAssertEqual(shell.state, .active)
        XCTAssertEqual(try WorldsTest.core(shell), before, "the resume continues from the same state")
        try WorldsTest.frames(session, 5)
        XCTAssertEqual(try shell.engine.digest(), digest, "host steps change nothing")
        session.close()
    }

    func testTheSavedStateRestoresIdenticallyInANewSession() async throws {
        let first = ExperienceSession()
        let shell = try await WorldsTest.open(first)
        XCTAssertTrue(shell.handle(control: "world.preset", values: [2]).isAccepted)
        XCTAssertTrue(shell.handle(control: "world.seed").isAccepted)
        XCTAssertTrue(shell.handle(control: "view.orbit", values: [100, -15]).isAccepted)
        XCTAssertTrue(shell.handle(control: "view.zoom", values: [0.8]).isAccepted)
        try WorldsTest.frames(first, 3)
        let snapshot = try shell.snapshot()
        let saved = try WorldsTest.core(shell)
        first.close()

        let second = ExperienceSession()
        let restored = try await WorldsTest.open(second, seed: 3)
        try restored.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let core = try WorldsTest.core(restored)
        XCTAssertEqual(core.state, saved.state, "preset, seed, view and generator are identical")
        XCTAssertEqual(core.terrainDigest, saved.terrainDigest)
        try WorldsTest.frames(second, 1)
        XCTAssertEqual(restored.presenter.lastPartsDrawn, 2, "the miniature city's terrain and sea")
        XCTAssertEqual(restored.accessibilitySummary,
                       WorldsPresenter.description(preset: saved.preset, seed: saved.seed, view: saved.view))
        second.close()
    }

    func testANewerSavedStateIsRefusedAndTheDefaultWorldOpens() async throws {
        let first = ExperienceSession()
        let shell = try await WorldsTest.open(first)
        XCTAssertTrue(shell.handle(control: "world.preset", values: [1]).isAccepted)
        let saved = try shell.snapshot()
        first.close()
        let newerEnvelope = try worldsEnvelope(Data(saved.payload.utf8), like: saved, schema: 2)
        let newerPayload = try worldsEnvelope(worldsPayload(saved.payload) { $0["schema"] = 2 }, like: saved)

        for (name, newer) in [("envelope", newerEnvelope), ("payload", newerPayload)] {
            let second = ExperienceSession()
            let opened = try await WorldsTest.open(second, snapshot: newer)
            XCTAssertNotNil(second.lastRestoreRefusal, "the newer \(name) is refused")
            XCTAssertEqual(try WorldsTest.core(opened).state, WorldState.initial, "\(name): the default world opens")
            XCTAssertThrowsError(try opened.restore(newer), name)
            second.close()
        }
    }

    func testADamagedSavedStateIsRefusedAndTheDefaultWorldOpens() async throws {
        let first = ExperienceSession()
        let shell = try await WorldsTest.open(first)
        XCTAssertTrue(shell.handle(control: "world.preset", values: [2]).isAccepted)
        let saved = try shell.snapshot()
        first.close()
        let damaged = try worldsEnvelope(worldsPayload(saved.payload) { $0["presetIndex"] = 5 }, like: saved)

        let second = ExperienceSession()
        let opened = try await WorldsTest.open(second, snapshot: damaged)
        XCTAssertNotNil(second.lastRestoreRefusal, "a preset outside 0…2 is refused")
        XCTAssertEqual(try WorldsTest.core(opened).state, WorldState.initial, "the default world opens")
        XCTAssertThrowsError(try opened.restore(damaged))
        second.close()
    }

    func testAContextRecreationRebuildsTheRenderersAndKeepsTheDigest() async throws {
        let session = ExperienceSession()
        let shell = try await WorldsTest.open(session)
        XCTAssertTrue(shell.handle(control: "world.preset", values: [1]).isAccepted)
        try WorldsTest.frames(session, 1)
        let presenter = shell.presenter
        let builds = presenter.rebuildCount
        let digest = try shell.engine.digest()
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(try shell.engine.digest(), digest)
        try WorldsTest.frames(session, 1)
        XCTAssertEqual(presenter.rebuildCount, builds + 1, "the renderers are made again on the new context")
        XCTAssertEqual(presenter.lastPartsDrawn, 1)
        XCTAssertTrue(presenter.isLive)
        session.close()
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
    }

    func testReopeningFiveTimesKeepsTheDrawingResourcesSteady() async throws {
        var reference: ResourceLedger.Snapshot?
        for cycle in 1...5 {
            let session = ExperienceSession()
            let shell = try await WorldsTest.open(session)
            XCTAssertTrue(shell.handle(control: "view.orbit", values: [20, 0]).isAccepted)
            try WorldsTest.frames(session, 5)
            let stats = try XCTUnwrap(session.renderHost).resources.stats
            XCTAssertEqual(stats.leaked, 0, "cycle \(cycle)")
            if let reference {
                XCTAssertEqual(stats.liveCount, reference.liveCount, "cycle \(cycle): the same live objects per kind")
                XCTAssertEqual(stats.liveBytes, reference.liveBytes, "cycle \(cycle): the same live bytes per kind")
            } else {
                reference = stats
            }
            session.close()
            XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0, "cycle \(cycle)")
        }
    }
}
