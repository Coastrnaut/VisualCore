// SolarSessionTests — feature 103 (A14-P01) T-A14-103 (FR-A14-120…122; clarifications Q4, Q5; SC-A14-104). The A14
// adapter inside the one app's session host on the simulator, short runs only (each test well under 10 s, no
// wall-clock assertion): the session opens with nine bodies in catalog order and the Sun selected, draws them through
// the host and describes the line-up in words, and actions change the description and the fact card; a suspension
// changes nothing; the state saved by the shell restores identically in a new session; newer and damaged saved states
// are refused and the Sun opens; a context recreation makes the renderers once more and keeps the meshes and the
// digest; reopening keeps the drawing resources steady and closing leaves no GPU object behind.
import Foundation
import XCTest
import VisualCoreDiagnostics
@testable import SolarSystemExplorerExperience
import SolarSystemExplorerCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

@MainActor
final class SolarSessionTests: XCTestCase {
    func testTheSessionOpensWithNineBodiesInCatalogOrderAndTheSunSelected() async throws {
        XCTAssertEqual(SolarSystemExplorerExperience.id?.rawValue, "a14.solar-system-explorer")
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session)
        let presenter = shell.presenter
        XCTAssertEqual(session.hostsAlive, 1, "the session's one render host")
        XCTAssertTrue(presenter.isLive)
        XCTAssertGreaterThan(shell.diagnostics.gpu?.objects ?? 0, 0, "drawn through the host's registry")
        let core = try SolarTest.core(shell)
        XCTAssertEqual(core.state, SolarState.initial)
        XCTAssertEqual(presenter.lastBodiesDrawn, 9)
        XCTAssertTrue(presenter.lastRingDrawn)
        XCTAssertEqual(presenter.lastSelection, 0)
        XCTAssertEqual(presenter.bodyMeshes.count, 9)
        XCTAssertEqual(presenter.meshBuildCount, 1)
        XCTAssertEqual(SolarControls.bodyNames,
                       ["Sun", "Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"])
        XCTAssertEqual(shell.accessibilitySummary,
                       "Solar System Explorer: Sun in focus on 2000-01-01; 9 bodies. Distances and sizes not to scale.")
        XCTAssertTrue(presenter.mirror.ready)
        XCTAssertEqual(presenter.mirror.selection, 0)
        XCTAssertEqual(presenter.mirror.bodyCount, 9)
        XCTAssertEqual(presenter.mirror.bodyName, "Sun")
        XCTAssertEqual(presenter.mirror.status, "Sun selected, body 1 of 9")
        XCTAssertEqual(presenter.mirror.facts, try XCTUnwrap(BodyCatalog.bundled.factCard(for: 0)).facts.map(\.text))
        XCTAssertEqual(presenter.nativeActions.count, 8)
        XCTAssertEqual(presenter.nativeActions, Set(SolarCore.actionIDs), "every action has a native control")
        XCTAssertEqual(presenter.gestureActions, [])
        XCTAssertEqual(GestureAlternatives.missing(gesture: presenter.gestureActions, native: presenter.nativeActions),
                       [])

        let sunCard = presenter.mirror.facts
        XCTAssertTrue(shell.handle(control: "body.select", values: [3]).isAccepted)
        XCTAssertEqual(shell.accessibilitySummary, SolarCore.canvasDescription(selection: 3, dayOffset: 0))
        XCTAssertTrue(shell.accessibilitySummary.contains("Earth in focus on 2000-01-01, 0.983 AU ("))
        XCTAssertEqual(presenter.mirror.bodyName, "Earth", "the description syncs the controls")
        XCTAssertNotEqual(presenter.mirror.facts, sunCard, "the card follows the selection")
        XCTAssertTrue(presenter.mirror.facts.contains { $0.hasPrefix("Mean radius: 6,371 km — ") },
                      "\(presenter.mirror.facts)")
        try SolarTest.frames(session, 1)
        XCTAssertEqual(presenter.lastSelection, 3)
        let rings = presenter.ringBuildCount
        try SolarTest.frames(session, 3)
        XCTAssertEqual(presenter.ringBuildCount, rings, "an unchanged selection never remakes the ring")
        XCTAssertEqual(presenter.rendererBuildCount, 1, "the bodies are made once")
        XCTAssertTrue(shell.handle(control: "body.next").isAccepted)
        XCTAssertEqual(presenter.mirror.bodyName, "Mars")

        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertFalse(presenter.isLive)
        XCTAssertTrue(presenter.bodyRenderers.isEmpty, "the renderers are released in teardown")
        XCTAssertNil(presenter.ringRenderer)
        XCTAssertNil(presenter.depthPass)
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }

    func testASuspensionChangesNothing() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session)
        XCTAssertTrue(shell.handle(control: "body.select", values: [5]).isAccepted)
        try SolarTest.frames(session, 20)
        let before = try SolarTest.core(shell)
        let digest = try shell.engine.digest()
        let stepIndex = shell.engine.stepIndex
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        for _ in 0..<10 { _ = session.renderHost?.renderOneFrame(present: false) }
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertEqual(try SolarTest.core(shell), before, "nothing changes while suspended")
        XCTAssertEqual(shell.engine.stepIndex, stepIndex)

        session.setScenePhase(.active)
        XCTAssertEqual(shell.state, .active)
        XCTAssertEqual(try SolarTest.core(shell), before, "the resume continues from the same state")
        try SolarTest.frames(session, 5)
        XCTAssertEqual(try shell.engine.digest(), digest, "host steps change nothing")
        session.close()
    }

    func testTheSavedStateRestoresIdenticallyInANewSession() async throws {
        let first = ExperienceSession()
        let shell = try await SolarTest.open(first)
        XCTAssertTrue(shell.handle(control: "body.select", values: [6]).isAccepted)
        try SolarTest.frames(first, 3)
        let snapshot = try shell.snapshot()
        let saved = try SolarTest.core(shell)
        first.close()

        let second = ExperienceSession()
        let restored = try await SolarTest.open(second, seed: 3)
        try restored.restore(ExperienceSnapshot(data: snapshot.encoded()))
        let core = try SolarTest.core(restored)
        XCTAssertEqual(core.state, saved.state, "the selection is identical")
        try SolarTest.frames(second, 1)
        XCTAssertEqual(restored.presenter.lastSelection, 6)
        XCTAssertEqual(restored.accessibilitySummary, saved.canvasDescription)
        second.close()
    }

    func testANewerSavedStateIsRefusedAndTheSunOpens() async throws {
        let first = ExperienceSession()
        let shell = try await SolarTest.open(first)
        XCTAssertTrue(shell.handle(control: "body.select", values: [4]).isAccepted)
        let saved = try shell.snapshot()
        first.close()
        let newerEnvelope = try solarEnvelope(Data(saved.payload.utf8), like: saved, schema: 3)
        let newerPayload = try solarEnvelope(solarPayload(saved.payload) { $0["schema"] = 3 }, like: saved)

        let cases: [(String, ExperienceSnapshot)] = [("envelope", newerEnvelope), ("payload", newerPayload)]
        for (name, newer) in cases {
            let second = ExperienceSession()
            let opened = try await SolarTest.open(second, snapshot: newer)
            XCTAssertNotNil(second.lastRestoreRefusal, "the newer \(name) is refused")
            XCTAssertEqual(try SolarTest.core(opened).state, SolarState.initial, "\(name): the Sun opens")
            XCTAssertThrowsError(try opened.restore(newer), name)
            second.close()
        }
    }

    func testADamagedSavedStateIsRefusedAndTheSunOpens() async throws {
        let first = ExperienceSession()
        let shell = try await SolarTest.open(first)
        XCTAssertTrue(shell.handle(control: "body.select", values: [2]).isAccepted)
        let saved = try shell.snapshot()
        first.close()
        let damaged = try solarEnvelope(solarPayload(saved.payload) { $0["selection"] = 25 }, like: saved)

        let second = ExperienceSession()
        let opened = try await SolarTest.open(second, snapshot: damaged)
        XCTAssertNotNil(second.lastRestoreRefusal, "a selection outside 0…8 is refused")
        XCTAssertEqual(try SolarTest.core(opened).state, SolarState.initial, "the Sun opens")
        XCTAssertThrowsError(try opened.restore(damaged))
        second.close()
    }

    func testAContextRecreationMakesTheRenderersOnceMoreAndKeepsTheDigest() async throws {
        let session = ExperienceSession()
        let shell = try await SolarTest.open(session)
        XCTAssertTrue(shell.handle(control: "body.select", values: [7]).isAccepted)
        try SolarTest.frames(session, 1)
        let presenter = shell.presenter
        let renderers = presenter.rendererBuildCount
        let meshes = presenter.meshBuildCount
        let digest = try shell.engine.digest()
        session.recreateContext()
        XCTAssertEqual(session.state, .running)
        XCTAssertEqual(try shell.engine.digest(), digest)
        try SolarTest.frames(session, 2)
        XCTAssertEqual(presenter.rendererBuildCount, renderers + 1, "the renderers are made once on the new context")
        XCTAssertEqual(presenter.meshBuildCount, meshes, "the meshes are CPU data and survive")
        XCTAssertEqual(presenter.lastBodiesDrawn, 9)
        XCTAssertEqual(presenter.lastSelection, 7)
        XCTAssertTrue(presenter.isLive)
        XCTAssertEqual(try shell.engine.digest(), digest)
        session.close()
        XCTAssertEqual(session.diagnostics.lastCloseCounts?.objects, 0)
    }

    func testReopeningFiveTimesKeepsTheDrawingResourcesSteady() async throws {
        var reference: ResourceLedger.Snapshot?
        for cycle in 1...5 {
            let session = ExperienceSession()
            let shell = try await SolarTest.open(session)
            XCTAssertTrue(shell.handle(control: "body.select", values: [3]).isAccepted)
            try SolarTest.frames(session, 5)
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
