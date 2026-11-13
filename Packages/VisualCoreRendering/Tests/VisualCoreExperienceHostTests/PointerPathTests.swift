// PointerPathTests — feature 193 (UA-F07) T-U07-003 (FR-U07-019; clarification 5; contract
// specs/193-ua-f07-legacy-adoption/contracts/adoption-api.md). Canvas touches reach the open experience's presenter
// with the view size, become actions through the port, never reach a closed experience, and the default presenter
// ignores them. Test-only.
import SwiftUI
import XCTest
import VisualCoreExperience
@testable import VisualCoreExperienceHost
import VisualCoreMath
import VisualCoreRendering
import VisualCoreScenes
import VisualCoreTestSupport

@MainActor
final class PointerPathTests: XCTestCase {
    private func tap(_ handler: ((PointerEvent) -> Void)?, x: Double, y: Double = 32, id: Int = 1) {
        handler?(PointerEvent(id: id, phase: .began, location: Vec2(x, y), timestamp: 1))
        handler?(PointerEvent(id: id, phase: .ended, location: Vec2(x, y), timestamp: 1.1))
    }

    func testAnEventReachesThePresenterWithTheViewSize() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = sampleRequest()
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        layOut(session)
        let host = try XCTUnwrap(session.renderHost)
        XCTAssertNotNil(host.pointerHandler, "an open experience receives the canvas touches")
        tap(host.pointerHandler, x: 10)
        let presenter = try XCTUnwrap(probe.presenter)
        XCTAssertEqual(presenter.pointerEvents.map(\.phase), [.began, .ended])
        XCTAssertEqual(presenter.pointerEvents.first?.location, Vec2(10, 32))
        XCTAssertEqual(presenter.lastViewSize, Vec2(64, 64), "the size of the host's view in points")
    }

    func testAnActionSentByThePresenterChangesTheState() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let (request, probe) = sampleRequest()
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        layOut(session)
        let host = try XCTUnwrap(session.renderHost)
        let shell = try XCTUnwrap(probe.shell)
        let before = try probe.digest()
        let revision = shell.port.revision
        // Right half → one cell right, unless the marker is at the wall; then the left half moves it left.
        tap(host.pointerHandler, x: 60)
        if case .rejected = try XCTUnwrap(probe.presenter?.lastPointerResult) { tap(host.pointerHandler, x: 4) }
        XCTAssertEqual(probe.presenter?.lastPointerResult, .accepted)
        XCTAssertNotEqual(try probe.digest(), before, "the action the port accepted changed the state")
        XCTAssertGreaterThan(shell.port.revision, revision, "the controls were refreshed")
    }

    func testNoEventReachesAClosedExperience() async throws {
        let session = ExperienceSession()
        let (request, probe) = sampleRequest()
        let opened = await session.open(request)
        XCTAssertEqual(opened, .running)
        layOut(session)
        let host = try XCTUnwrap(session.renderHost)
        let handler = try XCTUnwrap(host.pointerHandler)
        let presenter = try XCTUnwrap(probe.presenter)
        let shell = try XCTUnwrap(probe.shell)
        session.close()
        XCTAssertNil(host.pointerHandler, "the close cleared the handler")
        // A handler captured before the close (a touch already in flight) reaches nothing.
        tap(handler, x: 60)
        shell.handlePointer(PointerEvent(id: 9, phase: .ended, location: Vec2(60, 32), timestamp: 2),
                            viewSize: Vec2(64, 64))
        XCTAssertTrue(presenter.pointerEvents.isEmpty)
    }

    func testTheHandlerIsClearedAtEveryCloseAndReplacedAtTheNextOpen() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        var hosts: [RenderHost] = []
        for _ in 0..<3 {
            let (request, probe) = sampleRequest()
            let opened = await session.open(request)
            XCTAssertEqual(opened, .running)
            layOut(session)
            let host = try XCTUnwrap(session.renderHost)
            XCTAssertFalse(hosts.contains { $0 === host }, "every open has its own host")
            XCTAssertNotNil(host.pointerHandler)
            tap(host.pointerHandler, x: 10)
            XCTAssertEqual(probe.presenter?.pointerEvents.count, 2, "only the open experience receives events")
            hosts.append(host)
            session.close()
            XCTAssertNil(host.pointerHandler)
        }
        XCTAssertTrue(hosts.allSatisfy { $0.pointerHandler == nil })
    }

    func testTheDefaultPresenterIgnoresEvents() {
        var sent: [String] = []
        let port = ExperienceActionPort(accessibilityPrefix: "experience.test") { control, _ in
            sent.append(control)
            return .accepted
        }
        let presenter = PlainPresenter()
        presenter.pointer(PointerEvent(id: 1, phase: .ended, location: Vec2(10, 10), timestamp: 1),
                          viewSize: Vec2(64, 64), port: port)
        XCTAssertTrue(sent.isEmpty, "the default sends nothing")
    }
}

/// A presenter that keeps every default (feature 193): it does not override `pointer`.
@MainActor
private final class PlainPresenter: ExperiencePresenter {
    typealias Core = SampleExperienceCore<NoFault>
    func setup(_ context: RenderContext) throws {}
    func draw(_ core: Core, tier: Int, context: RenderContext, frame: FrameInfo) throws {}
    func teardown(_ context: RenderContext) {}
    func describe(_ core: Core) -> String { "" }
    func makeControls(_ port: ExperienceActionPort) -> AnyView { AnyView(EmptyView()) }
}
