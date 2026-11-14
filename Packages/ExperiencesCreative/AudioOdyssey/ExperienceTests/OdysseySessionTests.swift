// OdysseySessionTests — feature 054 (A07-P01) T-A07-104 (FR-A07-121, FR-A07-122; story 1, story 2, edge cases). The
// A07 adapter inside the one app's session host on the simulator, short runs only (each test well under 10 s, no
// wall-clock assertion): the first frame draws the tunnel window of 2 + 1 + 8 pieces through the host's registry and
// describes it in words; world switches and a new journey rebuild exactly the window's pieces, and rapid switches end
// with the last world drawn; the camera sways sideways along the level right axis by the flight's sway, and not at all
// under Reduce Motion (mirrored into the core after the first frame); leaving for the background suspends the
// experience so the journey holds still and returning continues it; closing releases every piece with no leak; and
// the experience's sources never create a graphics context of their own (only the host's context is used).
// Feature 055 (A07-P02) T-A07-205: the tunnel streams (at most 2 pieces built per frame until the window of 2 + 1 + 8
// is complete) and the description names the source and the response.
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

@MainActor
final class OdysseySessionTests: XCTestCase {
    private var id: ExperienceID { AudioOdysseyExperience.id ?? ExperienceID(rawValue: "a07.unknown")! }

    private func open(_ session: ExperienceSession, reduceMotion: Bool = false) async throws
        -> ExperienceShell<OdysseyPresenter> {
        let id = self.id
        var made: ExperienceShell<OdysseyPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = AudioOdysseyExperience.make(id: id, reduceMotion: reduceMotion)
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        let shell = try XCTUnwrap(made)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        return shell
    }

    /// Draws `count` frames about 16 ms apart.
    private func frames(_ session: ExperienceSession, _ count: Int = 10) async throws {
        for _ in 0..<count {
            XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
            try await Task.sleep(for: .milliseconds(16))
        }
    }

    private func core(_ shell: ExperienceShell<OdysseyPresenter>) throws -> OdysseyCore {
        try XCTUnwrap(shell.engine.core)
    }

    func testTheFirstFrameDrawsTheTunnelWindowThroughTheHostAndDescribesIt() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        XCTAssertEqual(session.hostsAlive, 1, "the session's one render host")
        XCTAssertTrue(presenter.isLive)
        XCTAssertEqual(presenter.lastWorld, .tunnel)
        let state = try core(shell).state
        let window = WorldPieces.indices(around: state.distance)
        XCTAssertEqual(presenter.lastIndices, window)
        XCTAssertEqual(window.count, 1 + WorldPieces.windowAhead, "at the start nothing lies behind piece 0")
        let live = presenter.tunnel.live
        XCTAssertGreaterThanOrEqual(live.count, 2, "the nearest pieces are built first")
        XCTAssertEqual(live, Array(0..<live.count), "nearest first, from piece 0")
        XCTAssertLessThanOrEqual(presenter.tunnelBuiltLastFrame, 2)
        XCTAssertGreaterThan(shell.diagnostics.gpu?.objects ?? 0, 0, "the pieces live in the host's registry")
        XCTAssertTrue(shell.accessibilitySummary.hasPrefix("Audio Odyssey: Tunnel, medium speed, flying, demo signal, "),
                      shell.accessibilitySummary)
        XCTAssertEqual(presenter.mirror.world, .tunnel)
        XCTAssertEqual(presenter.mirror.speedChoice, .medium)
        XCTAssertFalse(presenter.mirror.paused)

        try await frames(session, 20)
        XCTAssertGreaterThan(try core(shell).state.distance, 0, "the camera advances with no prompt")
        let streamed = WorldPieces.indices(around: try core(shell).state.distance)
        XCTAssertEqual(presenter.tunnel.live, Array(streamed), "the whole window is streamed in")
        XCTAssertEqual(presenter.lastDrawnPieces, Array(streamed))
        XCTAssertTrue(shell.handle(control: "flight.pause").isAccepted)
        XCTAssertTrue(shell.accessibilitySummary.hasPrefix("Audio Odyssey: Tunnel, medium speed, paused, demo signal, "),
                      shell.accessibilitySummary)
        XCTAssertTrue(presenter.mirror.paused)

        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
        XCTAssertTrue(presenter.pieces.isEmpty, "every piece released")
        XCTAssertEqual(presenter.liveRendererCount, 0, "every tunnel piece released")
        XCTAssertEqual(presenter.tunnel.available, TunnelStream<MeshRenderer>.capacity, "every slot free")
        XCTAssertFalse(presenter.isLive)
        XCTAssertEqual(shell.state, .inactive, "closed without a GPU leak")
    }

    func testWorldSwitchesAndANewJourneyRebuildTheWindowAndTheLastSwitchWins() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        try await frames(session, 5)
        let before = try core(shell).state
        let made = presenter.piecesMade
        XCTAssertTrue(shell.handle(control: "world.select", values: [1]).isAccepted)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        XCTAssertEqual(presenter.lastWorld, .landscape)
        let window = try XCTUnwrap(presenter.lastIndices)
        XCTAssertEqual(presenter.piecesMade - made, window.count, "the landscape window was built")
        XCTAssertEqual(Set(presenter.pieces.keys), Set(window))
        XCTAssertGreaterThanOrEqual(try core(shell).state.distance, before.distance, "the same rail position, onward")
        XCTAssertTrue(shell.accessibilitySummary.hasPrefix("Audio Odyssey: Landscape, medium speed, flying, demo signal, "),
                      shell.accessibilitySummary)
        XCTAssertEqual(presenter.tunnel.liveCount, 0, "leaving the tunnel empties the stream")

        // Rapid switches with no frame between: exactly the last world is drawn.
        for world in [2.0, 0, 1, 2] {
            XCTAssertTrue(shell.handle(control: "world.select", values: [world]).isAccepted)
        }
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        XCTAssertEqual(presenter.lastWorld, .starCorridor)
        XCTAssertEqual(presenter.mirror.world, .starCorridor)

        // A new journey: a new rail for the new seed and a rebuilt window.
        let seed = try core(shell).state.seed
        let madeBefore = presenter.piecesMade
        XCTAssertTrue(shell.handle(control: "journey.reseed").isAccepted)
        XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
        XCTAssertEqual(presenter.railSeed, seed &+ JourneyState.seedStep)
        XCTAssertEqual(presenter.piecesMade - madeBefore, try XCTUnwrap(presenter.lastIndices).count)
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testTheCameraSwaysAlongTheLevelRightAxisAndNotAtAllUnderReduceMotion() async throws {
        for reduce in [false, true] {
            let session = ExperienceSession()
            let shell = try await open(session, reduceMotion: reduce)
            let presenter = shell.presenter
            // The mirror is sent after the first frame; wait for it (bounded) while frames run.
            for _ in 0..<50 {
                if try core(shell).reduceMotion == reduce { break }
                try await frames(session, 1)
            }
            XCTAssertEqual(try core(shell).reduceMotion, reduce)
            try await frames(session, 20)
            let core = try core(shell)
            let rail = try XCTUnwrap(presenter.rail)
            let camera = try XCTUnwrap(presenter.lastCamera)
            let plain = rail.orbitCamera(at: core.state.distance, fovY: OdysseyPresenter.fovY,
                                         near: OdysseyPresenter.near, far: OdysseyPresenter.far)
            let offset = camera.target + presenter.rebase.origin - plain.target
            let right = rail.pose(at: core.state.distance).right
            let sway = core.flight.sway(limits: core.limits)
            XCTAssertEqual(right.y, 0, accuracy: 1e-12, "the horizon stays level")
            XCTAssertEqual(offset.dot(right), sway, accuracy: 1e-9)
            XCTAssertEqual((offset - right * sway).length, 0, accuracy: 1e-9, "only sideways")
            XCTAssertEqual(camera.yaw, plain.yaw)
            XCTAssertEqual(camera.pitch, plain.pitch)
            if reduce {
                XCTAssertEqual(sway, 0)
                XCTAssertLessThanOrEqual(core.state.speed, ComfortLimits.reducedMotion.maxSpeed)
            } else {
                XCTAssertNotEqual(sway, 0, "a gentle sway while the standard limits apply")
            }
            session.close()
        }
    }

    func testLeavingSuspendsTheJourneyAndReturningContinuesIt() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        try await frames(session, 10)
        session.setScenePhase(.background)
        XCTAssertEqual(shell.state, .suspended)
        let away = try core(shell)
        for _ in 0..<5 {
            _ = session.renderHost?.renderOneFrame(present: false)
            try await Task.sleep(for: .milliseconds(16))
        }
        XCTAssertEqual(try core(shell), away, "no step runs while away")
        session.setScenePhase(.active)
        XCTAssertEqual(shell.state, .active)
        try await frames(session, 15)
        let back = try core(shell).state
        XCTAssertGreaterThan(back.distance, away.state.distance, "the flight continues from the saved state")
        XCTAssertEqual(back.world, away.state.world)
        XCTAssertEqual(back.seed, away.state.seed)
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    /// The experience draws only through the `RenderContext` the host hands it: none of its sources creates a
    /// context, a display, a device or a render host, or calls GL directly.
    func testTheExperienceNeverCreatesAGraphicsContextOfItsOwn() throws {
        let directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Experience")
        let files = try XCTUnwrap(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThanOrEqual(files.count, 5)
        // Split so the repository's own source scanners do not read this list as a use.
        let forbidden = ["egl" + "CreateContext", "egl" + "GetDisplay", "egl" + "GetPlatformDisplay", "EAGL" + "Context",
                         "MTL" + "CreateSystemDefaultDevice", "RenderHost" + "(", "CVisualCore" + "GL", "vc" + "gl"]
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for word in forbidden {
                XCTAssertFalse(text.contains(word), "\(file.lastPathComponent) mentions \(word)")
            }
        }
    }
}
