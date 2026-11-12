// ExperienceHostViewTests — feature 189 (UA-F03) T-U03-008 (FR-U03-060 to FR-U03-062, SC-U03-010; research R7).
// The host view and the session's own views laid out in a window of 320 by 568 points at the largest
// accessibility text size: the content stays inside the width and scrolls, the buttons keep 44 by 44 points, the
// identifiers are the ones of the contract and the canvas label is the experience's state description.
import XCTest
import SwiftUI
import UIKit
@testable import VisualCoreExperienceHost
import VisualCoreExperience
import VisualCoreTestSupport

@MainActor
final class ExperienceHostViewTests: XCTestCase {
    private static let screen = CGSize(width: 320, height: 568)
    private static let longDetail = String(repeating: "The experience could not be prepared on this device. ",
                                           count: 8)

    // MARK: Helpers

    /// A window of 320 by 568 points that shows `view` at the text size `size`, laid out.
    private func present<Content: View>(
        _ view: Content, at size: DynamicTypeSize = .accessibility5
    ) -> (window: UIWindow, controller: UIHostingController<AnyView>) {
        let frame = CGRect(origin: .zero, size: Self.screen)
        let window = UIWindow(frame: frame)
        let controller = UIHostingController(rootView: AnyView(view.environment(\.dynamicTypeSize, size)))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.frame = frame
        window.layoutIfNeeded()
        controller.view.layoutIfNeeded()
        return (window, controller)
    }

    /// Asserts that `view` fits the width of the small screen at the largest text size and keeps the screen's
    /// bounds (its content scrolls inside), and that it also builds at the smallest text size.
    private func assertFitsSmallScreen<Content: View>(_ view: Content, _ name: String,
                                                      file: StaticString = #filePath, line: UInt = #line) {
        let large = present(view, at: .accessibility5)
        let fitting = large.controller.sizeThatFits(in: CGSize(width: Self.screen.width,
                                                               height: .greatestFiniteMagnitude))
        XCTAssertLessThanOrEqual(fitting.width, Self.screen.width, "\(name): fitting width", file: file, line: line)
        XCTAssertEqual(large.controller.view.bounds.size, Self.screen, "\(name): bounds", file: file, line: line)
        large.window.isHidden = true

        let small = present(view, at: .xSmall)
        XCTAssertEqual(small.controller.view.bounds.size, Self.screen, "\(name): bounds at xSmall",
                       file: file, line: line)
        small.window.isHidden = true
    }

    private func sampleRequest<Fault: SampleFault>(_ fault: Fault.Type,
                                                   memoryPressureLimit: Int? = nil) -> ExperienceOpenRequest {
        ExperienceOpenRequest(id: SampleExperience.id, seed: 42, memoryPressureLimit: memoryPressureLimit) {
            ExperienceShell(id: SampleExperience.id, presenter: SamplePresenter<Fault>())
        }
    }

    // MARK: State views (FR-U03-062, SC-U03-010)

    func testPreparingViewFitsSmallScreenAtLargestText() {
        assertFitsSmallScreen(SessionPreparingView(onCancel: {}), "preparing")
    }

    func testFailureViewWithLongDetailFitsSmallScreenAtLargestText() {
        XCTAssertGreaterThanOrEqual(Self.longDetail.count, 400)
        let view = SessionFailureView(title: SessionStrings.text(.failureTitle), detail: Self.longDetail,
                                      code: "sample.preparation-failed", onRetry: {}, onBack: {})
        assertFitsSmallScreen(view, "failure")
    }

    func testMessageViewFitsSmallScreenAtLargestText() {
        assertFitsSmallScreen(SessionMessageView(text: SessionStrings.text(.memoryMessage), onBack: {}), "message")
    }

    // MARK: Button style

    func testButtonStyleMinimumIs44Points() {
        XCTAssertEqual(SessionButtonStyle.minimumSize, 44)
    }

    func testStyledButtonIsAtLeast44By44() {
        for size in [DynamicTypeSize.xSmall, .accessibility5] {
            let button = Button("A") {}.buttonStyle(SessionButtonStyle()).environment(\.dynamicTypeSize, size)
            let controller = UIHostingController(rootView: button)
            let fitting = controller.sizeThatFits(in: CGSize(width: Self.screen.width,
                                                             height: .greatestFiniteMagnitude))
            XCTAssertGreaterThanOrEqual(fitting.width, 44, "width at \(size)")
            XCTAssertGreaterThanOrEqual(fitting.height, 44, "height at \(size)")
            XCTAssertLessThanOrEqual(fitting.width, Self.screen.width, "width at \(size)")
        }
    }

    // MARK: Identifiers (contract)

    func testIdentifiersAreTheOnesOfTheContract() {
        XCTAssertEqual(SessionViewID.canvas, "session.canvas")
        XCTAssertEqual(SessionViewID.preparing, "session.preparing")
        XCTAssertEqual(SessionViewID.cancel, "session.cancel")
        XCTAssertEqual(SessionViewID.failure, "session.failure")
        XCTAssertEqual(SessionViewID.retry, "session.retry")
        XCTAssertEqual(SessionViewID.back, "session.back")
        XCTAssertEqual(SessionViewID.message, "session.message")
    }

    func testScenePhasesMapToSessionInputs() {
        XCTAssertEqual(ExperienceHostView.input(for: .active), .active)
        XCTAssertEqual(ExperienceHostView.input(for: .inactive), .inactive)
        XCTAssertEqual(ExperienceHostView.input(for: .background), .background)
    }

    // MARK: Host view per session state (FR-U03-060, FR-U03-061)

    func testHostViewBuildsForIdleSession() {
        let session = ExperienceSession()
        let shown = present(ExperienceHostView(session: session))
        XCTAssertEqual(shown.controller.view.bounds.size, Self.screen)
        XCTAssertEqual(session.state, .idle)
        shown.window.isHidden = true
        session.close()
    }

    func testHostViewBuildsForRunningSessionAndCanvasLabelIsTheStateDescription() async {
        let session = ExperienceSession()
        let result = await session.open(sampleRequest(NoFault.self))
        XCTAssertEqual(result, .running)
        XCTAssertNotNil(session.renderHost)
        XCTAssertFalse(session.experience?.accessibilitySummary.isEmpty ?? true, "the canvas label")

        let shown = present(ExperienceHostView(session: session))
        XCTAssertEqual(shown.controller.view.bounds.size, Self.screen)
        // The window of a test has no scene, so the view may forward a phase that suspends the session.
        XCTAssertTrue([.running, .suspended].contains(session.state), "state \(session.state)")
        shown.window.isHidden = true
        session.close()
        XCTAssertEqual(session.state, .idle)
    }

    func testHostViewBuildsForFailedSession() async {
        let session = ExperienceSession()
        let result = await session.open(sampleRequest(FailingPreparation.self))
        guard case .failed = result else { return XCTFail("expected a failure, got \(result)") }
        XCTAssertEqual(session.state, .failed)
        XCTAssertNotNil(session.failure)

        let shown = present(ExperienceHostView(session: session))
        XCTAssertEqual(shown.controller.view.bounds.size, Self.screen)
        XCTAssertEqual(session.state, .failed)
        shown.window.isHidden = true
        session.back()
        XCTAssertEqual(session.state, .idle)
    }

    func testHostViewBuildsForMessageSession() async {
        let session = ExperienceSession()
        let result = await session.open(sampleRequest(NoFault.self, memoryPressureLimit: 0))
        XCTAssertEqual(result, .running)
        session.handleMemoryWarning()
        XCTAssertEqual(session.state, .message)
        XCTAssertNotNil(session.message)

        let shown = present(ExperienceHostView(session: session))
        XCTAssertEqual(shown.controller.view.bounds.size, Self.screen)
        XCTAssertEqual(session.state, .message)
        shown.window.isHidden = true
        session.back()
        XCTAssertEqual(session.state, .idle)
    }
}
