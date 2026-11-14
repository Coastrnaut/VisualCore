// OdysseyLongSessionTests — feature 058 (A07-P05) T-A07-504 (FR-A07-510, FR-A07-511; SC-A07-502, SC-A07-503; story 1,
// scenarios 1 and 2; clarifications 2 and 3; edge case "a restored journey far along the rail"). The measured long
// session without a soak: 3,600 frames of 1/60 s (60 s of simulated flight) at 7 units/s through the tunnel, drawn
// back to back at 64 × 64 points with no waiting: the live renderers never exceed the pool's 12, at most 2 pieces are
// built per frame, and the host registry's ledger after frame 3,600 equals the ledger right after the first complete
// window of 2 + 1 + 8 pieces (longer sessions are bounded by arithmetic: the per-frame work and the pool are constant).
// A journey restored at distance 10^9 draws its first frame with the camera of the rail pose at the wrapped distance,
// relative to the rebased origin, within 1e-3.
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

@MainActor
final class OdysseyLongSessionTests: XCTestCase {
    func testSixtySecondsAtFullSpeedKeepThePoolAndTheLedgerConstant() async throws {
        let session = ExperienceSession()
        let shell = try await P05.open(session)
        let presenter = shell.presenter
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertTrue(shell.handle(control: "speed.set", values: [7]).isAccepted)
        let capacity = TunnelStream<MeshRenderer>.capacity
        let fullWindow = TunnelStream<MeshRenderer>.behind + 1 + TunnelStream<MeshRenderer>.ahead
        var reference = host.resources.stats      // replaced by the ledger at the first full window
        var firstFullFrame: Int?
        var overCapacity = 0, overBuilt = 0, maxLive = 0
        for frame in 1...3_600 {
            XCTAssertTrue(host.renderOneFrame(present: false))
            if presenter.liveRendererCount > capacity { overCapacity += 1 }
            if presenter.tunnelBuiltLastFrame > SegmentWindow.maxBuildsPerStep { overBuilt += 1 }
            maxLive = max(maxLive, presenter.liveRendererCount)
            if firstFullFrame == nil, presenter.tunnel.isComplete, presenter.tunnel.liveCount == fullWindow {
                reference = host.resources.stats
                firstFullFrame = frame
            }
        }
        XCTAssertEqual(overCapacity, 0, "never more than \(capacity) live renderers")
        XCTAssertEqual(overBuilt, 0, "never more than \(SegmentWindow.maxBuildsPerStep) pieces built per frame")
        XCTAssertLessThanOrEqual(maxLive, capacity)
        let state = try XCTUnwrap(shell.engine.core).state
        XCTAssertEqual(state.world, .tunnel)
        XCTAssertGreaterThan(state.distance, 300, "about 60 s at up to 7 units/s: \(state.distance)")
        let fullFrame = try XCTUnwrap(firstFullFrame, "the window of 2 + 1 + 8 pieces was complete at some frame")
        XCTAssertLessThan(fullFrame, 3_600)
        XCTAssertTrue(presenter.tunnel.isComplete)
        XCTAssertEqual(presenter.tunnel.liveCount, fullWindow)
        let end = host.resources.stats
        XCTAssertEqual(end.liveCount, reference.liveCount, "the same live objects per kind")
        XCTAssertEqual(end.liveBytes, reference.liveBytes, "the same live bytes per kind")
        XCTAssertEqual(end, reference, "the ledger after frame 3,600 equals the ledger after the first full window")
        XCTAssertEqual(end.leaked, 0)
        session.close()
        XCTAssertEqual(presenter.liveRendererCount, 0)
    }

    func testAJourneyRestoredAtTenToTheNinthDrawsTheRebasedRailCameraOnItsFirstFrame() async throws {
        let distance = 1e9
        let session = ExperienceSession()
        let snapshot = try P05.snapshot(JourneyState(seed: 7, distance: distance, paused: true))
        let shell = try await P05.open(session, snapshot: snapshot)
        let presenter = shell.presenter
        XCTAssertNil(presenter.lastCamera, "no frame drawn yet")
        try P05.frames(session, 1)
        let core = try XCTUnwrap(shell.engine.core)
        XCTAssertEqual(core.state.distance, distance, "paused: the first frame keeps the distance")
        let camera = try XCTUnwrap(presenter.lastCamera)
        let rail = try XCTUnwrap(presenter.rail)
        let origin = presenter.rebase.origin
        let sway = core.flight.sway(limits: core.limits)
        let wrapped = distance.truncatingRemainder(dividingBy: rail.length)
        let pose = rail.pose(at: wrapped)
        let eye = pose.position + pose.right * sway - origin
        let target = pose.position + pose.direction + pose.right * sway - origin
        XCTAssertLessThan((camera.eye - eye).length, 1e-3, "the eye of the wrapped rail pose, rebased")
        XCTAssertLessThan((camera.target - target).length, 1e-3, "the target of the wrapped rail pose, rebased")
        // The rebase took effect on the first frame: the drawn eye lies within the rebase threshold of the origin.
        XCTAssertLessThanOrEqual(abs(camera.eye.x), OriginRebase.threshold)
        XCTAssertLessThanOrEqual(abs(camera.eye.y), OriginRebase.threshold)
        XCTAssertLessThanOrEqual(abs(camera.eye.z), OriginRebase.threshold)
        // The window streams around piece 1.25 × 10^8.
        let current = WorldPieces.pieceIndex(of: distance)
        XCTAssertEqual(current, 125_000_000)
        XCTAssertEqual(presenter.lastIndices, (current - 2)...(current + 8))
        XCTAssertEqual(presenter.tunnel.live.first, current, "the nearest piece is built first")
        XCTAssertLessThanOrEqual(presenter.tunnelBuiltLastFrame, SegmentWindow.maxBuildsPerStep)
        session.close()
    }
}
