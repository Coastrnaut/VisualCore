// CanvasOverlayTests — feature 106 (A14-P04) T-A14-402 (FR-A14-420; contract
// specs/106-sse-p04-time-tours/contracts/canvas-overlay.md). The optional canvas overlay: a presenter without one gives
// nil through the protocol's default; a presenter's overlay reaches the shell through `Experience.canvasOverlay`; the
// host view builds for a running session with and without an overlay. Short, no GPU readback.
import XCTest
import SwiftUI
import UIKit
@testable import VisualCoreExperienceHost
import VisualCoreExperience
import VisualCoreRendering
import VisualCoreTestSupport

/// A presenter that keeps every default of `ExperiencePresenter`, to prove the overlay's default is nil.
@MainActor
private final class DefaultsPresenter: ExperiencePresenter {
    typealias Core = SampleExperienceCore<NoFault>
    func setup(_ context: RenderContext) throws {}
    func draw(_ core: Core, tier: Int, context: RenderContext, frame: FrameInfo) throws {}
    func teardown(_ context: RenderContext) {}
    func describe(_ core: Core) -> String { "defaults" }
    func makeControls(_ port: ExperienceActionPort) -> AnyView { AnyView(EmptyView()) }
}

@MainActor
final class CanvasOverlayTests: XCTestCase {
    func testThePresenterDefaultIsNoOverlay() {
        let presenter = DefaultsPresenter()
        let shell = ExperienceShell(id: SampleExperience.id, presenter: presenter)
        XCTAssertNil(presenter.makeCanvasOverlay(shell.port))
        XCTAssertNil(shell.canvasOverlay)
        let experience: any Experience = shell
        XCTAssertNil(experience.canvasOverlay)
    }

    func testAPresentersOverlayReachesTheShell() {
        let presenter = SamplePresenter<NoFault>()
        let shell = ExperienceShell(id: SampleExperience.id, presenter: presenter)
        XCTAssertNil(shell.canvasOverlay, "the sample has no overlay by default")
        presenter.overlay = AnyView(Text(verbatim: "Label"))
        XCTAssertNotNil(shell.canvasOverlay)
        XCTAssertEqual(presenter.overlayCalls, 2, "the shell asks the presenter each time")
    }

    private func present(_ view: some View) -> (window: UIWindow, controller: UIHostingController<AnyView>) {
        let frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        let window = UIWindow(frame: frame)
        let controller = UIHostingController(rootView: AnyView(view))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = frame
        window.layoutIfNeeded()
        controller.view.layoutIfNeeded()
        return (window, controller)
    }

    func testTheHostViewBuildsWithAndWithoutAnOverlay() async {
        let flags: [Bool] = [false, true]
        for withOverlay in flags {
            let presenter = SamplePresenter<NoFault>()
            if withOverlay { presenter.overlay = AnyView(Text(verbatim: "Mars").padding()) }
            let session = ExperienceSession()
            let request = ExperienceOpenRequest(id: SampleExperience.id, seed: 42, memoryPressureLimit: nil) {
                ExperienceShell(id: SampleExperience.id, presenter: presenter)
            }
            let result = await session.open(request)
            XCTAssertEqual(result, .running, "overlay \(withOverlay)")
            XCTAssertEqual(session.experience?.canvasOverlay != nil, withOverlay)
            let shown = present(ExperienceHostView(session: session))
            XCTAssertEqual(shown.controller.view.bounds.size, CGSize(width: 320, height: 568))
            XCTAssertGreaterThan(presenter.overlayCalls, 0, "the host view asked for the overlay")
            shown.window.isHidden = true
            session.close()
            XCTAssertEqual(session.state, .idle)
        }
    }
}
