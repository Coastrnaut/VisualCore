// OdysseyStreamingTests — feature 055 (A07-P02) T-A07-205 (FR-A07-201, FR-A07-230; SC-A07-201, SC-A07-202; story 2).
// The streamed tunnel, short runs only (each test under 10 s, no wall-clock assertion): the presenter's `TunnelStream`
// over a 200-piece flight (and a jump far ahead) never holds more than its 12 slots, builds at most 2 pieces per step,
// hands every retired element back and reuses the slots; inside the one app's session host a fast flight through the
// tunnel keeps at most 12 live renderers and builds at most 2 per frame while pieces behind are retired; the tunnel
// pieces share one breathing model matrix per frame (watertight joins); and the far end of the window is closer to the
// fog colour than the floor next to the camera.
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes

/// A stand-in element that records whether it was retired.
private final class PieceToken: @unchecked Sendable {
    let index: Int
    var retired = false
    init(_ index: Int) { self.index = index }
}

@MainActor
final class OdysseyStreamingTests: XCTestCase {
    private var id: ExperienceID { AudioOdysseyExperience.id ?? ExperienceID(rawValue: "a07.unknown")! }

    func testTheStreamStaysWithinItsSlotsOverTwoHundredPieces() {
        var stream = TunnelStream<PieceToken>()
        var made: [PieceToken] = []
        let length = WorldPieces.pieceLength
        var distance = 0.0
        while distance < 200 * length {
            let step = stream.advance(to: distance, pieceLength: length, build: { index in
                let token = PieceToken(index)
                made.append(token)
                return token
            }, retire: { $0.retired = true })
            XCTAssertLessThanOrEqual(step.toBuild.count, SegmentWindow.maxBuildsPerStep)
            XCTAssertLessThanOrEqual(stream.liveCount, TunnelStream<PieceToken>.capacity)
            XCTAssertEqual(stream.liveCount + stream.available, TunnelStream<PieceToken>.capacity, "no slot lost")
            XCTAssertEqual(stream.liveCount, stream.live.count)
            for index in stream.live { XCTAssertEqual(stream.element(for: index)?.index, index) }
            distance += 0.37
        }
        XCTAssertGreaterThanOrEqual(made.count, 200, "every piece of the flight was built once")
        let alive = made.filter { !$0.retired }
        XCTAssertEqual(alive.count, stream.liveCount, "every element that left the window was retired")
        XCTAssertEqual(Set(alive.map(\.index)), Set(stream.live))
        XCTAssertTrue(stream.window.isComplete)

        // A jump far ahead retires everything at once and builds only the new window, 2 per step.
        let before = made.count
        var steps = 0
        repeat {
            let step = stream.advance(to: 1_000_000, pieceLength: length, build: { index in
                let token = PieceToken(index)
                made.append(token)
                return token
            }, retire: { $0.retired = true })
            XCTAssertLessThanOrEqual(step.toBuild.count, SegmentWindow.maxBuildsPerStep)
            steps += 1
        } while !stream.window.isComplete && steps < 20
        XCTAssertEqual(made.count - before, TunnelStream<PieceToken>.behind + TunnelStream<PieceToken>.ahead + 1,
                       "nothing is built for the skipped distance")
        XCTAssertEqual(made.filter { !$0.retired }.count, stream.liveCount)

        stream.reset { $0.retired = true }
        XCTAssertEqual(stream.liveCount, 0)
        XCTAssertEqual(stream.available, TunnelStream<PieceToken>.capacity)
        XCTAssertTrue(made.allSatisfy(\.retired))
    }

    private func open(_ session: ExperienceSession) async throws -> ExperienceShell<OdysseyPresenter> {
        let id = self.id
        var made: ExperienceShell<OdysseyPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = AudioOdysseyExperience.make(id: id)
            shell.presenter.demoMode = .silence
            made = shell
            return shell
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        if let view = session.renderHost?.view {
            view.frame = CGRect(x: 0, y: 0, width: 160, height: 240)
            view.layoutIfNeeded()
        }
        return try XCTUnwrap(made)
    }

    func testALongFastFlightKeepsAtMostTwelveRenderersAndBuildsAtMostTwoPerFrame() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let presenter = shell.presenter
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertTrue(shell.handle(control: "speed.select", values: [2]).isAccepted)
        // 720 frames of 1/60 s: about 68 units at up to 7 units/s, past eight piece boundaries.
        var maxLive = 0
        var retiredSeen = false
        for frame in 0..<720 {
            XCTAssertTrue(host.renderOneFrame(present: false))
            XCTAssertLessThanOrEqual(presenter.tunnelBuiltLastFrame, SegmentWindow.maxBuildsPerStep, "frame \(frame)")
            XCTAssertLessThanOrEqual(presenter.liveRendererCount, TunnelStream<MeshRenderer>.capacity, "frame \(frame)")
            maxLive = max(maxLive, presenter.liveRendererCount)
            if let first = presenter.tunnel.live.first, first > 0 { retiredSeen = true }
            if frame % 120 == 0 { await Task.yield() }
        }
        let state = try XCTUnwrap(shell.engine.core).state
        XCTAssertGreaterThan(state.distance, 5 * WorldPieces.pieceLength, "the flight crossed several pieces")
        XCTAssertTrue(retiredSeen, "pieces behind the camera were retired")
        XCTAssertEqual(presenter.tunnel.live, Array(WorldPieces.indices(around: state.distance)),
                       "the window follows the camera")
        XCTAssertLessThanOrEqual(maxLive, TunnelStream<MeshRenderer>.capacity)
        XCTAssertEqual(presenter.pieces.count, 0, "the tunnel uses only the stream")
        XCTAssertEqual(session.hostsAlive, 1)
        session.close()
        XCTAssertEqual(presenter.liveRendererCount, 0)
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testTunnelPiecesShareOneBreathingModelSoJoinsStayWatertight() async throws {
        // The model: radial scaling about the rail point, 1 along the rail direction, then the shift by -origin.
        let centre = Vec3(10, 2, -5), direction = Vec3(0.6, 0, 0.8), origin = Vec3(9, 1, -4)
        let model = OdysseyPresenter.breathingModel(scale: 1.2, centre: centre, direction: direction, origin: origin)
        func apply(_ p: Vec3) -> Vec3 {
            let v = model * Vec4(p, 1)
            return Vec3(v.x, v.y, v.z)
        }
        XCTAssertEqual((apply(centre) - (centre - origin)).length, 0, accuracy: 1e-12, "the centre stays")
        let along = centre + direction * 5
        XCTAssertEqual((apply(along) - (along - origin)).length, 0, accuracy: 1e-12, "1 along the direction")
        let across = centre + Vec3(0, 3, 0)
        XCTAssertEqual((apply(across) - (centre + Vec3(0, 3.6, 0) - origin)).length, 0, accuracy: 1e-12, "s across")
        let identity = OdysseyPresenter.breathingModel(scale: 1, centre: centre, direction: direction, origin: origin)
        XCTAssertEqual(identity, Mat4.translation(-origin), "scale 1 is the plain shift")

        // In the session every tunnel item of a frame uses the same matrix, so a shared edge maps to the same place.
        let session = ExperienceSession()
        let shell = try await open(session)
        let host = try XCTUnwrap(session.renderHost)
        for _ in 0..<8 { XCTAssertTrue(host.renderOneFrame(present: false)) }
        let tunnelModel = try XCTUnwrap(shell.presenter.lastTunnelModel)
        let state = try XCTUnwrap(shell.engine.core).state
        let rail = try XCTUnwrap(shell.presenter.rail)
        let pose = rail.pose(at: state.distance)
        let expected = OdysseyPresenter.breathingModel(scale: shell.presenter.response.breathingScale,
                                                       centre: pose.position, direction: pose.direction,
                                                       origin: shell.presenter.rebase.origin)
        XCTAssertEqual(tunnelModel, expected)
        session.close()
    }

    func testTheFarEndOfTheWindowIsCloserToTheFogColourThanTheNearFloor() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertTrue(shell.handle(control: "flight.pause").isAccepted)
        for _ in 0..<30 where !shell.presenter.tunnel.window.isComplete {
            XCTAssertTrue(host.renderOneFrame(present: false))
        }
        XCTAssertTrue(shell.presenter.tunnel.window.isComplete)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let pixels = host.readPixels()
        let size = host.pixelSize
        let fog = try XCTUnwrap(OdysseyPresenter.fog).color
        let fogRGB = [fog.x, fog.y, fog.z].map { $0 * 255 }
        /// The mean distance (0…255 per channel, Euclidean) to the fog colour over a block of rows and columns.
        func distanceToFog(rows: Range<Int>, columns: Range<Int>) -> Double {
            var total = 0.0, count = 0
            for y in rows {
                for x in columns {
                    let i = (y * size.width + x) * 4
                    let rgb = [Double(pixels[i]), Double(pixels[i + 1]), Double(pixels[i + 2])]
                    total += zip(rgb, fogRGB).map { ($0 - $1) * ($0 - $1) }.reduce(0, +).squareRoot()
                    count += 1
                }
            }
            return total / Double(max(1, count))
        }
        let cx = size.width / 2, cy = size.height / 2
        let far = distanceToFog(rows: (cy - 2)..<(cy + 3), columns: (cx - 2)..<(cx + 3))
        // Buffer rows run from the bottom (GL order): 96 % from the top is row height − 1 − 0.96 · height.
        let nearRow = max(1, size.height - 1 - size.height * 96 / 100)
        let near = distanceToFog(rows: (nearRow - 1)..<(nearRow + 2), columns: (cx - 8)..<(cx + 8))
        XCTAssertGreaterThan(near, 20, "the near floor is lit, unfogged: \(near)")
        // The rail bends, so the centre can show a mid-distance wall rather than the open end; the fog's exact
        // colour and linearity are proven by VisualCoreRendering's MeshFogTests. Here: farther is closer to the fog.
        XCTAssertLessThan(far, near, "the far end blends toward the fog: far \(far), near \(near)")
        session.close()
    }
}
