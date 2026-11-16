// PointerCancelTests — feature 112 (A15-P03) T-A15-313. The optional `ExperiencePresenter.cancelPointers()`: its
// default does nothing, and `ExperienceShell.suspend()` calls it once the experience is suspended, so a presenter that
// tracks touches forgets them (pointer events are dropped while suspended). Short, no GPU.
import XCTest
import SwiftUI
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreTestSupport

/// A presenter that counts the calls of `cancelPointers()`.
@MainActor
private final class CancelCountingPresenter: ExperiencePresenter {
    typealias Core = SampleExperienceCore<NoFault>
    /// How many times the shell asked to forget the touches.
    var cancels = 0
    func setup(_ context: RenderContext) throws {}
    func draw(_ core: Core, tier: Int, context: RenderContext, frame: FrameInfo) throws {}
    func teardown(_ context: RenderContext) {}
    func describe(_ core: Core) -> String { "cancel counting" }
    func makeControls(_ port: ExperienceActionPort) -> AnyView { AnyView(EmptyView()) }
    func cancelPointers() { cancels += 1 }
}

/// A presenter that keeps every default.
@MainActor
private final class DefaultCancelPresenter: ExperiencePresenter {
    typealias Core = SampleExperienceCore<NoFault>
    func setup(_ context: RenderContext) throws {}
    func draw(_ core: Core, tier: Int, context: RenderContext, frame: FrameInfo) throws {}
    func teardown(_ context: RenderContext) {}
    func describe(_ core: Core) -> String { "defaults" }
    func makeControls(_ port: ExperienceActionPort) -> AnyView { AnyView(EmptyView()) }
}

@MainActor
final class PointerCancelTests: XCTestCase {
    func testSuspendingAsksThePresenterToForgetItsTouches() async throws {
        let presenter = CancelCountingPresenter()
        let shell = ExperienceShell(id: SampleExperience.id, presenter: presenter)
        try await shell.prepare(seed: 1, timeLimit: nil)
        try shell.activate()
        XCTAssertEqual(presenter.cancels, 0, "nothing is cancelled while active")
        try shell.suspend()
        XCTAssertEqual(presenter.cancels, 1, "suspension cancels the touches once")
        try shell.resume()
        XCTAssertEqual(presenter.cancels, 1, "resuming cancels nothing more")
    }

    func testTheDefaultDoesNothingAndSuspensionStillWorks() async throws {
        let presenter = DefaultCancelPresenter()
        presenter.cancelPointers()
        let shell = ExperienceShell(id: SampleExperience.id, presenter: presenter)
        try await shell.prepare(seed: 1, timeLimit: nil)
        try shell.activate()
        try shell.suspend()
        XCTAssertEqual(shell.state, .suspended)
    }
}
