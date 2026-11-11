// FieldTestSupport — feature 019 T-A02-103…105: a host whose scene runs test closures with the context current.
import XCTest
@testable import VisualCoreRendering

/// Runs `body` inside `render` (context current, main thread), once per `renderOneFrame`.
@MainActor
final class ClosureScene: RenderScene {
    var body: ((RenderContext) throws -> Void)?
    var setupBody: ((RenderContext) throws -> Void)?
    var teardownBody: ((RenderContext) -> Void)?
    func setup(_ context: RenderContext) throws { try setupBody?(context) }
    func resize(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws { try body?(context) }
    func teardown(_ context: RenderContext) { teardownBody?(context) }
}

@MainActor
func makeFieldHost(_ scene: ClosureScene) throws -> RenderHost {
    let host = try RenderHost(scene: scene)
    host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
    host.view.layoutIfNeeded()
    return host
}

/// Renders one frame running `body` and rethrows anything it threw.
@MainActor
func withContext(_ host: RenderHost, _ scene: ClosureScene, _ body: @escaping (RenderContext) throws -> Void) throws {
    var failure: Error?
    scene.body = { context in
        do { try body(context) } catch { failure = error }
    }
    XCTAssertTrue(host.renderOneFrame(present: false))
    scene.body = nil
    if let failure { throw failure }
}
