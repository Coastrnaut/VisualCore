// OdysseyQualityTests — feature 058 (A07-P05) T-A07-504 (FR-A07-502; SC-A07-501; story 2, scenarios 1 and 2; edge
// case "a quality level change while pieces are being built"). The presenter applies the forced quality level, short
// runs only (frames of 1/60 s drawn back to back at 64 × 64 points, each test well under 10 s, no wall-clock
// assertion): at levels 0, 1 and 2 the streamed tunnel holds 8/6/4 pieces ahead and 2/2/1 behind, the fog ends at
// 64/48/32 units (starting at 40 % of it) and the star corridor's pieces carry 48/29/17 stars; a shrinking window
// retires its far pieces in the frame of the change and builds nothing, a growing one builds at most two pieces per
// frame and never beyond the new window; and a flight with level changes ends with exactly the digest and journey of
// the same flight without them.
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreScenes

@MainActor
final class OdysseyQualityTests: XCTestCase {
    /// Pieces ahead and behind, fog end and stars per piece of levels 0, 1 and 2 (clarification 1).
    private let ahead = [8, 6, 4], behind = [2, 2, 1], fogEnd = [64.0, 48.0, 32.0], stars = [48, 29, 17]

    /// A paused journey at distance 100 (piece 12) in `world`, so the window has pieces behind and stays put.
    private func pausedSnapshot(_ world: JourneyWorld = .tunnel) throws -> ExperienceSnapshot {
        try P05.snapshot(JourneyState(seed: 7, world: world, distance: 100, paused: true))
    }

    /// Draws frames until the streamed tunnel is complete (at most `limit`), checking the build limit and the window.
    private func fillTunnel(_ session: ExperienceSession, _ presenter: OdysseyPresenter, level: Int,
                            limit: Int = 20) throws {
        let host = try XCTUnwrap(session.renderHost)
        var frames = 0
        repeat {
            XCTAssertTrue(host.renderOneFrame(present: false))
            frames += 1
            XCTAssertLessThanOrEqual(presenter.tunnelBuiltLastFrame, SegmentWindow.maxBuildsPerStep, "level \(level)")
            let window = OdysseyPresenter.indices(around: 100, level: level)
            XCTAssertTrue(presenter.tunnel.live.allSatisfy { window.contains($0) }, "nothing beyond the new window")
        } while !presenter.tunnel.isComplete && frames < limit
        XCTAssertTrue(presenter.tunnel.isComplete, "level \(level) filled within \(limit) frames")
    }

    func testEachLevelShrinksTheTunnelWindowAndTheFog() async throws {
        let session = ExperienceSession()
        let shell = try await P05.open(session, snapshot: try pausedSnapshot())
        let presenter = shell.presenter
        let digest = try shell.engine.digest()
        let current = WorldPieces.pieceIndex(of: 100)
        XCTAssertEqual(current, 12)
        for level in 0...2 {
            presenter.forceTierForTesting = level
            try fillTunnel(session, presenter, level: level)
            let live = presenter.tunnel.live
            XCTAssertEqual(live, Array(OdysseyPresenter.indices(around: 100, level: level)), "level \(level)")
            XCTAssertEqual(live.filter { $0 > current }.count, ahead[level], "pieces ahead at level \(level)")
            XCTAssertEqual(live.filter { $0 < current }.count, behind[level], "pieces behind at level \(level)")
            XCTAssertEqual(presenter.liveRendererCount, behind[level] + 1 + ahead[level])
            XCTAssertLessThanOrEqual(presenter.liveRendererCount, TunnelStream<MeshRenderer>.capacity)
            XCTAssertEqual(presenter.lastLevel, level)
            let fog = try XCTUnwrap(presenter.lastFog)
            XCTAssertEqual(fog.end, fogEnd[level], accuracy: 1e-12, "fog end = draw distance at level \(level)")
            XCTAssertEqual(fog.start, 0.4 * fogEnd[level], accuracy: 1e-12)
            XCTAssertLessThanOrEqual(fog.end, OdysseyPresenter.far, "the far plane lies beyond the fog")
            XCTAssertEqual(presenter.lastIndices, OdysseyPresenter.indices(around: 100, level: level))
            XCTAssertEqual(try shell.engine.digest(), digest, "the level never changes the journey")
        }
        // Forced tiers outside the levels are clamped; nil falls back to the host's tier (0 here).
        presenter.forceTierForTesting = 9
        try P05.frames(session, 1)
        XCTAssertEqual(presenter.lastLevel, 2)
        presenter.forceTierForTesting = nil
        try P05.frames(session, 1)
        XCTAssertEqual(presenter.lastLevel, 0)
        session.close()
        XCTAssertEqual(presenter.liveRendererCount, 0)
    }

    func testTheWindowShrinksAtOnceAndGrowsAtMostTwoPiecesPerFrame() async throws {
        let session = ExperienceSession()
        let shell = try await P05.open(session, snapshot: try pausedSnapshot())
        let presenter = shell.presenter
        let host = try XCTUnwrap(session.renderHost)
        presenter.forceTierForTesting = 0
        try fillTunnel(session, presenter, level: 0)
        let madeBefore = presenter.piecesMade

        // 0 → 2: the far pieces go in the frame of the change; the kept ones are not rebuilt.
        presenter.forceTierForTesting = 2
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertEqual(presenter.tunnel.live, Array(OdysseyPresenter.indices(around: 100, level: 2)))
        XCTAssertEqual(presenter.tunnelBuiltLastFrame, 0, "a shrink builds nothing")
        XCTAssertEqual(presenter.piecesMade, madeBefore)
        XCTAssertTrue(presenter.tunnel.isComplete)
        XCTAssertEqual(presenter.liveRendererCount, 1 + 1 + 4)

        // 2 → 0: the missing pieces come at most two per frame; the count never falls.
        presenter.forceTierForTesting = 0
        var previous = presenter.liveRendererCount
        var frames = 0
        repeat {
            XCTAssertTrue(host.renderOneFrame(present: false))
            frames += 1
            XCTAssertLessThanOrEqual(presenter.tunnelBuiltLastFrame, SegmentWindow.maxBuildsPerStep)
            XCTAssertLessThanOrEqual(presenter.liveRendererCount - previous, SegmentWindow.maxBuildsPerStep)
            XCTAssertGreaterThanOrEqual(presenter.liveRendererCount, previous)
            previous = presenter.liveRendererCount
        } while !presenter.tunnel.isComplete && frames < 20
        XCTAssertTrue(presenter.tunnel.isComplete)
        XCTAssertGreaterThan(frames, 1, "five missing pieces need more than one frame")
        XCTAssertEqual(presenter.tunnel.live, Array(OdysseyPresenter.indices(around: 100, level: 0)))
        XCTAssertEqual(presenter.piecesMade - madeBefore, 5, "only the missing pieces were built")
        session.close()
    }

    func testTheStarCorridorCarriesTheLevelsStarCount() async throws {
        let session = ExperienceSession()
        let shell = try await P05.open(session, snapshot: try pausedSnapshot(.starCorridor))
        let presenter = shell.presenter
        let seed = try XCTUnwrap(shell.engine.core).state.seed
        var vertexCounts: [Int] = []
        for level in 0...2 {
            presenter.forceTierForTesting = level
            try P05.frames(session, 1)
            XCTAssertEqual(OdysseyQuality.starCount(level: level), stars[level])
            XCTAssertEqual(presenter.cacheStarCount, stars[level], "level \(level)")
            let window = OdysseyPresenter.indices(around: 100, level: level)
            XCTAssertEqual(Set(presenter.pieces.keys), Set(window), "the fixed window of level \(level)")
            let rail = try XCTUnwrap(presenter.rail)
            let index = window.lowerBound
            let renderer = try XCTUnwrap(presenter.pieces[index])
            let expected = WorldPieces.piece(.starCorridor, index: index, rail: rail, seed: seed,
                                             starCount: stars[level])
            XCTAssertEqual(renderer.mesh, expected, "the piece was built with \(stars[level]) stars")
            vertexCounts.append(renderer.mesh.positions.count)
            let fog = try XCTUnwrap(presenter.lastFog)
            XCTAssertEqual(fog.end, fogEnd[level], accuracy: 1e-12)
        }
        XCTAssertEqual(vertexCounts, vertexCounts.sorted(by: >), "fewer stars from level to level")
        XCTAssertEqual(Set(vertexCounts).count, 3)
        session.close()
        XCTAssertEqual(presenter.liveRendererCount, 0)
    }

    /// Flies 180 frames at the fast speed with the level changed every 30 frames per `levels` (nil: no change) and
    /// returns the digest and the journey state at the end.
    private func flight(levels: [Int]?) async throws -> (StateDigest, JourneyState) {
        let session = ExperienceSession()
        let shell = try await P05.open(session)
        XCTAssertTrue(shell.handle(control: "speed.select", values: [2]).isAccepted)
        for block in 0..<6 {
            if let levels { shell.presenter.forceTierForTesting = levels[block] }
            try P05.frames(session, 30)
        }
        let result = (try shell.engine.digest(), try XCTUnwrap(shell.engine.core).state)
        session.close()
        return result
    }

    func testLevelChangesMidFlightLeaveTheJourneyAndItsDigestUnchanged() async throws {
        let plain = try await flight(levels: nil)
        let changed = try await flight(levels: [0, 2, 1, 2, 0, 1])
        XCTAssertGreaterThan(plain.1.distance, 0, "the journey flew")
        XCTAssertEqual(changed.1, plain.1, "world, distance, speed and mappings are untouched by the levels")
        XCTAssertEqual(changed.0, plain.0)
    }
}
