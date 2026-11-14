// OdysseyRenderTests — feature 054 (A07-P01) T-A07-104 (FR-A07-121; SC-A07-105; story 1). The three worlds rendered
// inside the one app's session host on the simulator, short runs only (each test under 10 s, no wall-clock
// assertion): every world draws a non-blank picture on the dark clear colour, the three pictures differ pairwise (by
// their pixel hash and in at least a tenth of a 16 × 16 sampling grid), the declared frame probes hold, a paused
// journey draws the same picture frame after frame, and a failed draw reaches the session as a failure.
import Foundation
import XCTest
@testable import AudioOdysseyExperience
import AudioOdysseyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering

@MainActor
final class OdysseyRenderTests: XCTestCase {
    private var id: ExperienceID { AudioOdysseyExperience.id ?? ExperienceID(rawValue: "a07.unknown")! }

    private func open(_ session: ExperienceSession) async throws -> ExperienceShell<OdysseyPresenter> {
        let id = self.id
        var made: ExperienceShell<OdysseyPresenter>?
        let request = ExperienceOpenRequest(id: id, seed: 7, snapshot: nil, refusedSnapshotFails: false) {
            let shell = AudioOdysseyExperience.make(id: id)
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

    /// Draws `count` frames about 16 ms apart.
    private func frames(_ session: ExperienceSession, _ count: Int = 10) async throws {
        for _ in 0..<count {
            XCTAssertTrue(session.renderHost?.renderOneFrame(present: false) ?? false)
            try await Task.sleep(for: .milliseconds(16))
        }
    }

    /// The pixels of a freshly drawn frame with the frame's width and height.
    private func picture(_ session: ExperienceSession) throws -> (rgba: [UInt8], width: Int, height: Int) {
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertTrue(host.renderOneFrame(present: false))
        let size = host.pixelSize
        return (host.readPixels(), size.width, size.height)
    }

    /// The RGB of a 16 × 16 grid of points over the picture.
    private func grid(_ p: (rgba: [UInt8], width: Int, height: Int)) -> [[UInt8]] {
        var out: [[UInt8]] = []
        for gy in 0..<16 {
            for gx in 0..<16 {
                let x = (gx * 2 + 1) * p.width / 32, y = (gy * 2 + 1) * p.height / 32
                let i = (y * p.width + x) * 4
                out.append([p.rgba[i], p.rgba[i + 1], p.rgba[i + 2]])
            }
        }
        return out
    }

    private func differingShare(_ a: [[UInt8]], _ b: [[UInt8]]) -> Double {
        let differing = zip(a, b).filter { p, q in zip(p, q).contains { abs(Int($0) - Int($1)) > 16 } }.count
        return Double(differing) / Double(a.count)
    }

    func testTheThreeWorldsDrawDifferentNonBlankPictures() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        try await frames(session, 5)
        XCTAssertTrue(shell.handle(control: "flight.pause").isAccepted)
        var pictures: [(rgba: [UInt8], width: Int, height: Int)] = []
        for world in JourneyWorld.allCases {
            XCTAssertTrue(shell.handle(control: "world.select", values: [Double(world.rawValue)]).isAccepted)
            try await frames(session, 3)
            XCTAssertEqual(shell.presenter.lastWorld, world)
            let p = try picture(session)
            XCTAssertGreaterThan(p.width, 0)
            XCTAssertTrue(FrameChecks.isNonBlank(p.rgba, width: p.width, height: p.height), "\(world) is not blank")
            XCTAssertFalse(FrameChecks.isBlack(p.rgba, width: p.width, height: p.height), "\(world) is not black")
            for probe in shell.frameProbes {
                XCTAssertEqual(FrameChecks.probe(probe, rgba: p.rgba, width: p.width, height: p.height)?.rawValue,
                               probe.expected, "\(world) \(probe.name)")
            }
            pictures.append(p)
        }
        let hashes = pictures.map { StableHash.sha256Hex($0.rgba) }
        XCTAssertEqual(Set(hashes).count, 3, "three different pixel hashes")
        for i in 0..<3 {
            for j in (i + 1)..<3 {
                XCTAssertGreaterThanOrEqual(differingShare(grid(pictures[i]), grid(pictures[j])), 0.10,
                                            "worlds \(i) and \(j)")
            }
        }
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }

    func testAPausedJourneyDrawsTheSamePictureOnceAtRest() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        XCTAssertTrue(shell.handle(control: "flight.pause").isAccepted)
        // From near rest the speed reaches 0 within a few frames (1.5 units/s² at most); wait for it, bounded.
        for _ in 0..<120 {
            if try XCTUnwrap(shell.engine.core).state.speed == 0 { break }
            try await frames(session, 1)
        }
        XCTAssertEqual(try XCTUnwrap(shell.engine.core).state.speed, 0)
        let first = try picture(session)
        try await frames(session, 3)
        let second = try picture(session)
        XCTAssertEqual(first.rgba, second.rgba, "a journey at rest draws the same picture")
        session.close()
    }

    func testAFailedDrawReachesTheSession() async throws {
        let session = ExperienceSession()
        let shell = try await open(session)
        try await frames(session, 2)
        shell.presenter.failNextDraw = true
        _ = session.renderHost?.renderOneFrame(present: false)
        XCTAssertEqual(session.state, .failed, "a drawing failure fails the session")
        XCTAssertNotNil(session.failure)
        XCTAssertFalse(shell.presenter.failNextDraw, "the seam clears itself")
        session.close()
        XCTAssertEqual(session.hostsAlive, 0)
    }
}
