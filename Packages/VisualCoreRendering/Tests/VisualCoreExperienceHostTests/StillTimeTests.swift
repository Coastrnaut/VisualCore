// StillTimeTests — feature 139 (A19-P02) T-A19-204 (G-STILLTIME; research D3; contracts/still.md). A timed still
// draws the open experience at the asked scene time; the two-argument forms stay at time 0, and the registry's live
// counts are unchanged afterwards. The sample presenter ignores time, so a test-local presenter clears to a colour
// that follows the frame time. Test-only.
import SwiftUI
import XCTest
import CVisualCoreGL
import VisualCoreExperience
@testable import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreTestSupport

/// Clears to (fract(time / 10), 0.5, 0.25, 1): the red channel follows the frame time, so stills at different
/// times differ. Creates no GPU objects.
@MainActor
private final class TimedClearPresenter: ExperiencePresenter {
    typealias Core = SampleExperienceCore<NoFault>

    func setup(_ context: RenderContext) throws {}

    func draw(_ core: Core, tier: Int, context: RenderContext, frame: FrameInfo) throws {
        let red = frame.time / 10 - (frame.time / 10).rounded(.down)
        vcglClearColor(Float(red), 0.5, 0.25, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }

    func teardown(_ context: RenderContext) {}

    func describe(_ core: Core) -> String { "timed clear" }

    func makeControls(_ port: ExperienceActionPort) -> AnyView { AnyView(EmptyView()) }
}

@MainActor
final class StillTimeTests: XCTestCase {
    /// A session with the timed presenter open and laid out.
    private func openTimedSession() async -> ExperienceSession {
        let session = ExperienceSession()
        let request = ExperienceOpenRequest(id: SampleExperience.id, seed: 42) {
            ExperienceShell(id: SampleExperience.id, presenter: TimedClearPresenter())
        }
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        layOut(session)
        return session
    }

    func testTimedStillsDifferAcrossTimesAndRepeatForTheSameTime() async throws {
        let session = await openTimedSession()
        defer { session.close() }
        let one = try session.renderStill(width: 16, height: 12, time: 1)
        let seven = try session.renderStill(width: 16, height: 12, time: 7)
        let oneAgain = try session.renderStill(width: 16, height: 12, time: 1)
        XCTAssertNotEqual(one, seven)
        XCTAssertEqual(one, oneAgain)
        XCTAssertEqual(Int(one.pixel(x: 8, y: 6).x), 26, accuracy: 2)
        XCTAssertEqual(Int(seven.pixel(x: 8, y: 6).x), 179, accuracy: 2)
    }

    func testTheTwoArgumentFormIsTimeZero() async throws {
        let session = await openTimedSession()
        defer { session.close() }
        let untimed = try session.renderStill(width: 16, height: 12)
        XCTAssertEqual(untimed, try session.renderStill(width: 16, height: 12, time: 0))
        XCTAssertNotEqual(untimed, try session.renderStill(width: 16, height: 12, time: 7))
    }

    func testATimedStillLeavesTheLiveCountsUnchanged() async throws {
        let session = await openTimedSession()
        defer { session.close() }
        XCTAssertTrue(drawFrame(session))
        let host = try XCTUnwrap(session.renderHost)
        let before = host.resources.stats.liveCount
        _ = try session.renderStill(width: 32, height: 24, time: 3)
        XCTAssertEqual(session.renderHost!.resources.stats.liveCount, before)
        XCTAssertEqual(session.hostsAlive, 1, "no second render host")
    }

    func testTheTimedRendererPassesItsTimeAndTheOldInitMapsToZero() async throws {
        let session = await openTimedSession()
        defer { session.close() }
        let timed = ExperienceStillRenderer(timed: { [session]
            (width: Int, height: Int, time: Double) throws(OffscreenRenderError) -> StillImage in
            try session.renderStill(width: width, height: height, time: time)
        })
        XCTAssertEqual(try timed(width: 16, height: 12, time: 7),
                       try session.renderStill(width: 16, height: 12, time: 7))
        XCTAssertEqual(try timed(width: 16, height: 12), try session.renderStill(width: 16, height: 12, time: 0))

        let legacy = ExperienceStillRenderer { [session]
            (width: Int, height: Int) throws(OffscreenRenderError) -> StillImage in
            try session.renderStill(width: width, height: height)
        }
        let atZero = try session.renderStill(width: 16, height: 12, time: 0)
        XCTAssertEqual(try legacy(width: 16, height: 12), atZero)
        XCTAssertEqual(try legacy(width: 16, height: 12, time: 7), atZero, "the old init ignores the time")
    }
}
