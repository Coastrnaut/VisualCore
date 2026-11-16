// AnatomyAnnouncementTests — feature 127 (A17-P04) T-A17-406 (FR-A17-405, FR-A17-406; clarification Q3; SC-A17-403,
// SC-A17-405). Selection announcements and Reduce Motion through the one app's session host, short runs only (each test
// well under 10 s; the planner is timed by the host's frame clock, 1/60 s per test frame, so nothing waits on the wall
// clock): the first state announces nothing; five selections within one second of frames give at most the announcements
// the 0.5 s planner allows and the last selection is always announced after the flush frames; a clear says "Selection
// cleared."; with Reduce Motion on, selecting a part frames it in the very next frame and nothing has a transition.
import Foundation
import XCTest
@testable import InteractiveAnatomyExperience
import InteractiveAnatomyCore
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreMath

/// Announcements and Reduce Motion of Interactive Anatomy.
@MainActor
final class AnatomyAnnouncementTests: XCTestCase {
    /// The frames of 1/60 s in `seconds`.
    private func frameCount(_ seconds: Double) -> Int { Int((seconds * 60).rounded()) }

    func testTheFirstStateAnnouncesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        shell.presenter.announcementSink = { _ in }
        try AnatomyTest.frames(session, frameCount(1))
        XCTAssertEqual(shell.presenter.announced, [])
    }

    func testFiveQuickSelectionsAreRateLimitedAndTheLastIsAlwaysAnnounced() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        let presenter = shell.presenter
        presenter.announcementSink = { _ in }
        let names = try AnatomyTest.core(shell).scene.parts.map(\.englishName)
        let parts = [0, 3, 8, 9, 12]
        let start = presenter.clock
        for part in parts {
            AnatomyTest.accept(shell, "structure.select", [Double(part)])
            try AnatomyTest.frames(session, frameCount(0.2))
        }
        let burst = presenter.announced.count
        let burstSeconds = presenter.clock - start
        XCTAssertLessThanOrEqual(burstSeconds, 1.0 + 1e-9, "five selections within one second of frames")
        let allowed = Int(((burstSeconds + 1e-6) / AnatomyPresenter.announcementInterval).rounded(.down)) + 1
        XCTAssertLessThanOrEqual(burst, allowed, "at most one announcement per 0.5 s")
        XCTAssertLessThan(burst, parts.count, "the burst was merged")
        try AnatomyTest.frames(session, frameCount(0.6))
        let announced = presenter.announced
        let total = Int(((presenter.clock - start + 1e-6) / AnatomyPresenter.announcementInterval).rounded(.down)) + 1
        XCTAssertLessThanOrEqual(announced.count, total)
        XCTAssertEqual(announced.first, "\(names[parts[0]]) selected.")
        XCTAssertEqual(announced.last, "\(names[parts[4]]) selected.", "the last selection is always announced")
        let count = announced.count
        try AnatomyTest.frames(session, frameCount(1))
        XCTAssertEqual(presenter.announced.count, count, "nothing is announced twice")
    }

    func testAClearIsAnnounced() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session)
        shell.presenter.announcementSink = { _ in }
        AnatomyTest.accept(shell, "structure.select", [1])
        try AnatomyTest.frames(session, 1)
        AnatomyTest.accept(shell, "structure.clear")
        try AnatomyTest.frames(session, frameCount(0.6))
        let names = try AnatomyTest.core(shell).scene.parts.map(\.englishName)
        XCTAssertEqual(shell.presenter.announced, ["\(names[1]) selected.", "Selection cleared."])
    }

    func testWithReduceMotionSelectingFramesThePartInTheSameFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await AnatomyTest.open(session, reduceMotion: true)
        let presenter = shell.presenter
        XCTAssertTrue(presenter.reduceMotion)
        XCTAssertEqual(presenter.cameraTransitionSeconds, 0, "nothing animates")
        for part in [0, 8, 13] {
            AnatomyTest.accept(shell, "structure.select", [Double(part)])
            try AnatomyTest.frames(session, 1)
            let core = try AnatomyTest.core(shell)
            let camera = try XCTUnwrap(presenter.lastCamera)
            XCTAssertEqual(camera, core.camera(aspect: presenter.lastAspect), "part \(part): the framed camera at once")
            let center = core.scene.structureSphere(part).center
            XCTAssertEqual((camera.target - center).length, 0, accuracy: 1e-9, "part \(part) is the target")
        }
        AnatomyTest.accept(shell, "camera.zoom", [1])
        try AnatomyTest.frames(session, 1)
        let zoomed = try AnatomyTest.core(shell)
        XCTAssertEqual(presenter.lastCamera, zoomed.camera(aspect: presenter.lastAspect), "a zoom step cuts too")
    }

    func testWithoutReduceMotionNothingAnimatesEither() {
        let presenter = AnatomyPresenter(experienceID: AnatomyTest.id, reduceMotion: false)
        XCTAssertFalse(presenter.reduceMotion)
        XCTAssertEqual(presenter.cameraTransitionSeconds, 0)
        let reduced = AnatomyPresenter(experienceID: AnatomyTest.id, reduceMotion: true)
        XCTAssertEqual(reduced.cameraTransitionSeconds, 0)
    }
}
