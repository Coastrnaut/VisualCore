// ReadmeExampleTests — feature 003 T-F219 (SC-F204): the README integration example compiles and renders.
import CVisualCoreGL
import SwiftUI
import XCTest
@testable import VisualCoreRendering

@MainActor final class PulseScene: RenderScene {
    func setup(_ context: RenderContext) throws {}
    func resize(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        let level = Float(0.5 + 0.5 * sin(frame.time))
        vcglClearColor(level, 0.2, 1 - level, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }
    func teardown(_ context: RenderContext) {}
}

struct PulseView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let host = try! RenderHost(scene: PulseScene())
        context.coordinator.host = host
        return host.view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
    func makeCoordinator() -> Holder { Holder() }
    final class Holder { var host: RenderHost? }
}

@MainActor
final class ReadmeExampleTests: XCTestCase {
    func testReadmeSceneRendersThroughTheHost() throws {
        let host = try RenderHost(scene: PulseScene())
        host.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        let p = host.readPixels()
        XCTAssertEqual(Int(p[1]), 51, accuracy: 2, "green channel is the scene's constant 0.2")
        _ = PulseView()   // the SwiftUI wrapper compiles against the public API
    }
}
