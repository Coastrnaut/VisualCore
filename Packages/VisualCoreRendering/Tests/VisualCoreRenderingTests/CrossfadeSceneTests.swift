// CrossfadeSceneTests — feature 133 (A18-P03) T-A18-302 (FR-A18-303, FR-A18-307; SC-A18-303; contracts/crossfade.md):
// progress 0 is `from` byte for byte, 1 is `to`, 0.5 is the average within 2/255; no pixel darker than both inputs;
// resize and context recreation give the same frame; a restart keeps the current mix; teardown leaves no GPU object.
import CVisualCoreGL
import VisualCoreTestSupport
import XCTest
@testable import VisualCoreRendering

@MainActor
final class CrossfadeSceneTests: XCTestCase {
    /// A warm horizontal gradient (never black).
    static let warm = """
    precision highp float;
    in vec2 v_uv;
    out vec4 color;
    void main() { color = vec4(0.25 + 0.6 * v_uv.x, 0.3, 0.15 + 0.3 * v_uv.y, 1.0); }
    """
    /// A cool vertical gradient (never black).
    static let cool = """
    precision highp float;
    in vec2 v_uv;
    out vec4 color;
    void main() { color = vec4(0.1, 0.2 + 0.6 * v_uv.y, 0.85 - 0.4 * v_uv.x, 1.0); }
    """
    /// A flat green, the incoming scene of a restarted fade.
    static let green = """
    precision highp float;
    out vec4 color;
    void main() { color = vec4(0.2, 0.75, 0.3, 1.0); }
    """

    private var hosts: [RenderHost] = []

    override func tearDown() {
        for h in hosts { h.destroy() }
        hosts.removeAll()
    }

    private static func scene(_ fragment: String, _ name: String) -> FullScreenShaderScene {
        FullScreenShaderScene(fragment: fragment, fragmentName: name, bundle: ShaderBundle(files: [:]))
    }

    private func host(_ scene: any RenderScene, size: CGFloat = 32) throws -> RenderHost {
        let h = try RenderHost(scene: scene)
        h.view.frame = CGRect(x: 0, y: 0, width: size, height: size)
        h.view.layoutIfNeeded()
        hosts.append(h)
        return h
    }

    private static func frame(_ host: RenderHost) -> [UInt8] {
        XCTAssertTrue(host.renderOneFrame(present: false))
        return host.readPixels()
    }

    /// The pixels each child draws alone in its own host.
    private func alone(_ fragment: String, _ name: String) throws -> [UInt8] {
        let pixels = Self.frame(try host(Self.scene(fragment, name)))
        XCTAssertFalse(pixels.isEmpty)
        return pixels
    }

    private func crossfade() -> CrossfadeScene {
        CrossfadeScene(from: Self.scene(Self.warm, "warm.frag"), to: Self.scene(Self.cool, "cool.frag"))
    }

    func testProgressEndsEqualTheChildrenByteForByte() throws {
        let warm = try alone(Self.warm, "warm.frag"), cool = try alone(Self.cool, "cool.frag")
        let fade = crossfade()
        let h = try host(fade)
        fade.progress = 0
        XCTAssertEqual(Self.frame(h), warm, "progress 0 is the outgoing scene")
        fade.progress = 1
        XCTAssertEqual(Self.frame(h), cool, "progress 1 is the incoming scene")
        fade.progress = -3
        XCTAssertEqual(fade.progress, 0)
        fade.progress = 7
        XCTAssertEqual(fade.progress, 1)
        fade.progress = .nan
        XCTAssertEqual(fade.progress, 0)
        XCTAssertEqual(vcglGetError(), GLenum(GL_NO_ERROR))
    }

    func testMiddleIsTheAverageAndNeverDarkerThanBoth() throws {
        let warm = try alone(Self.warm, "warm.frag"), cool = try alone(Self.cool, "cool.frag")
        let fade = crossfade()
        let h = try host(fade)
        fade.progress = 0.5
        let mid = Self.frame(h)
        XCTAssertEqual(mid.count, warm.count)
        var worst = 0
        for i in 0..<mid.count {
            let average = (Double(warm[i]) + Double(cool[i])) / 2
            worst = max(worst, Int((abs(Double(mid[i]) - average)).rounded(.up)))
        }
        XCTAssertLessThanOrEqual(worst, 2, "0.5 is within 2/255 of the average per channel")
        for progress in [0.1, 0.25, 0.5, 0.75, 0.9] {
            fade.progress = progress
            let pixels = Self.frame(h)
            for p in stride(from: 0, to: pixels.count, by: 4) {
                let luma = { (x: [UInt8]) in Int(x[p]) + Int(x[p + 1]) + Int(x[p + 2]) }
                XCTAssertGreaterThanOrEqual(luma(pixels) + 3, min(luma(warm), luma(cool)),
                                            "progress \(progress) pixel \(p / 4) is darker than both inputs")
            }
        }
    }

    func testResizeAndBackGivesTheSameFrame() throws {
        let fade = crossfade()
        let h = try host(fade)
        fade.progress = 0.4
        let before = Self.frame(h)
        h.view.frame = CGRect(x: 0, y: 0, width: 48, height: 40)
        h.view.layoutIfNeeded()
        let other = Self.frame(h)
        XCTAssertEqual(other.count, h.pixelSize.width * h.pixelSize.height * 4)
        XCTAssertGreaterThan(ImageStatistics.meanLuminance(other), 0.05, "the mix draws at the new size")
        h.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        h.view.layoutIfNeeded()
        XCTAssertEqual(Self.frame(h), before)
        let export = try h.renderOffscreen(width: 24, height: 20, time: 0)
        XCTAssertEqual(export.width, 24)
        XCTAssertEqual(Self.frame(h), before, "an export at another size leaves the screen frame unchanged")
    }

    func testContextRecreationGivesTheSameFrameAndCounts() throws {
        let fade = crossfade()
        let h = try host(fade)
        fade.progress = 0.6
        let before = Self.frame(h)
        let live = h.resources.stats.liveTotal
        h.recreateContext()
        XCTAssertTrue(fade.isSetUp)
        XCTAssertEqual(Self.frame(h), before)
        XCTAssertEqual(h.resources.stats.liveTotal, live, "both targets and the program rebuilt, nothing extra")
        XCTAssertEqual(h.resources.stats.leaked, 0)
    }

    func testTeardownLeavesNoGPUObject() throws {
        let h = try host(ClosureScene())
        XCTAssertTrue(h.renderOneFrame(present: false))
        let baseline = h.resources.stats
        let fade = crossfade()
        let holder = CrossfadeHolder(fade)
        h.replaceScene(holder)
        fade.progress = 0.5
        _ = Self.frame(h)
        try withContextOf(h, holder) { ctx in try fade.replaceIncoming(Self.scene(Self.green, "green.frag"), context: ctx) }
        fade.progress = 0.5
        _ = Self.frame(h)
        XCTAssertGreaterThan(h.resources.stats.liveTotal, baseline.liveTotal)
        h.replaceScene(ClosureScene())
        XCTAssertFalse(fade.isSetUp)
        XCTAssertEqual(h.resources.stats.liveTotal, baseline.liveTotal, "no target, still picture or program left")
        XCTAssertEqual(h.resources.stats.totalBytes, baseline.totalBytes)
        h.destroy()
        XCTAssertEqual(h.resources.stats.leaked, 0)
    }

    func testReplaceIncomingRestartsFromTheCurrentMix() throws {
        let green = try alone(Self.green, "green.frag")
        let fade = crossfade()
        let holder = CrossfadeHolder(fade)
        let h = try host(holder)
        fade.progress = 0.5
        let mix = Self.frame(h)
        let incoming = Self.scene(Self.green, "green.frag")
        try withContextOf(h, holder) { ctx in try fade.replaceIncoming(incoming, context: ctx) }
        XCTAssertEqual(fade.progress, 0)
        XCTAssertTrue(fade.to === incoming)
        XCTAssertEqual(h.readPixels(), mix, "the restart shows the current mix: no jump")
        XCTAssertEqual(Self.frame(h), mix, "and keeps showing it at progress 0")
        fade.progress = 1
        XCTAssertEqual(Self.frame(h), green, "the restarted fade ends on the new incoming scene")
        fade.progress = 0.5
        let restarted = Self.frame(h)
        for i in 0..<restarted.count {
            XCTAssertLessThanOrEqual(abs(Double(restarted[i]) - (Double(mix[i]) + Double(green[i])) / 2), 2, "channel \(i)")
        }
        h.recreateContext()
        XCTAssertEqual(Self.frame(h), restarted, "the still outgoing picture survives a context recreation")
        XCTAssertEqual(h.resources.stats.leaked, 0)
    }

    /// Runs `body` with the host's context current inside a frame, before the crossfade draws (as a presenter would
    /// from its render callback), then renders that frame.
    private func withContextOf(_ host: RenderHost, _ holder: CrossfadeHolder, _ body: @escaping (RenderContext) throws -> Void) throws {
        var failure: Error?
        holder.beforeRender = { ctx in
            do { try body(ctx) } catch { failure = error }
        }
        XCTAssertTrue(host.renderOneFrame(present: false))
        holder.beforeRender = nil
        if let failure { throw failure }
    }
}

/// The host's scene in the tests that act on the crossfade mid-frame: forwards every callback to `fade` and runs
/// `beforeRender` with the frame's context first.
@MainActor
private final class CrossfadeHolder: RenderScene {
    let fade: CrossfadeScene
    var beforeRender: ((RenderContext) -> Void)?
    init(_ fade: CrossfadeScene) { self.fade = fade }
    func setup(_ context: RenderContext) throws { try fade.setup(context) }
    func resize(_ context: RenderContext) { fade.resize(context) }
    func render(_ context: RenderContext, frame: FrameInfo) throws {
        beforeRender?(context)
        try fade.render(context, frame: frame)
    }
    func teardown(_ context: RenderContext) { fade.teardown(context) }
}
