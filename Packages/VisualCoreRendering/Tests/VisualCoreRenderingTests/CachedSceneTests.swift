// CachedSceneTests — feature 135 (A18-P05) T-A18-502 (FR-A18-501–503; contracts/qa.md "CachedScene"):
// with a fixed key, 120 renders draw the child once and give byte-identical frames equal to the child's own; a key
// change, a resize, a repeated setup (context recreation) and `invalidate()` draw once more each; pass-through draws
// every frame; teardown leaves no GPU object.
import CVisualCoreGL
import XCTest
@testable import VisualCoreRendering

@MainActor
final class CachedSceneTests: XCTestCase {
    /// A gradient that changes with `u_time`, so any redraw at another frame time changes the pixels.
    static let moving = """
    precision highp float;
    uniform float u_time;
    in vec2 v_uv;
    out vec4 color;
    void main() {
        color = vec4(0.2 + 0.6 * fract(0.37 * u_time + v_uv.x), 0.3 + 0.4 * v_uv.y, 0.5 + 0.4 * sin(u_time), 1.0);
    }
    """

    private var hosts: [RenderHost] = []

    override func tearDown() {
        for h in hosts { h.destroy() }
        hosts.removeAll()
    }

    private static func child(at time: Double) -> FullScreenShaderScene {
        let scene = FullScreenShaderScene(fragment: moving, fragmentName: "moving.frag", bundle: ShaderBundle(files: [:]))
        scene.fixedTime = time
        return scene
    }

    private func host(_ scene: any RenderScene, width: CGFloat = 32, height: CGFloat = 32) throws -> RenderHost {
        let h = try RenderHost(scene: scene)
        h.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        h.view.layoutIfNeeded()
        hosts.append(h)
        return h
    }

    private static func frame(_ host: RenderHost) -> [UInt8] {
        XCTAssertTrue(host.renderOneFrame(present: false))
        return host.readPixels()
    }

    /// The child's own frame at `time`, drawn alone in its own 32×32 host.
    private func alone(at time: Double) throws -> [UInt8] {
        let pixels = Self.frame(try host(Self.child(at: time)))
        XCTAssertFalse(pixels.isEmpty)
        return pixels
    }

    /// A cache in still mode around a child at time 0, in a 32×32 host.
    private func cached(key: Int = 7) throws -> (CachedScene, FullScreenShaderScene, RenderHost) {
        let child = Self.child(at: 0)
        let cache = CachedScene(child: child)
        cache.passThrough = false
        cache.key = key
        return (cache, child, try host(cache))
    }

    func testFixedKeyDrawsOnceIn120RendersWithIdenticalFrames() throws {
        let own0 = try alone(at: 0)
        XCTAssertNotEqual(try alone(at: 1.3), own0, "the child's picture changes with time, so a redraw would show")
        let (cache, child, h) = try cached()
        XCTAssertTrue(cache.isSetUp)
        XCTAssertEqual(cache.childDrawCount, 0)
        let first = Self.frame(h)
        XCTAssertEqual(first, own0, "the cached frame is byte for byte the child's own frame")
        for i in 1..<120 {
            child.fixedTime = Double(i) * 0.1
            XCTAssertEqual(Self.frame(h), first, "render \(i) repeats the cached picture")
        }
        XCTAssertEqual(cache.childDrawCount, 1)
        XCTAssertEqual(vcglGetError(), GLenum(GL_NO_ERROR))
    }

    func testKeyChangeAndInvalidateDrawOnceMore() throws {
        let own3 = try alone(at: 3), own5 = try alone(at: 5)
        let (cache, child, h) = try cached()
        _ = Self.frame(h)
        child.fixedTime = 3
        cache.key = 8
        XCTAssertEqual(Self.frame(h), own3, "a new key draws the child's frame at that time")
        XCTAssertEqual(cache.childDrawCount, 2)
        child.fixedTime = 4
        XCTAssertEqual(Self.frame(h), own3)
        XCTAssertEqual(cache.childDrawCount, 2, "the same key draws nothing more")
        child.fixedTime = 5
        cache.invalidate()
        XCTAssertEqual(Self.frame(h), own5)
        XCTAssertEqual(cache.childDrawCount, 3, "invalidate draws once more")
        XCTAssertEqual(Self.frame(h), own5)
        XCTAssertEqual(cache.childDrawCount, 3)
    }

    func testResizeDrawsOnceMoreAndBackGivesTheSameFrame() throws {
        let (cache, _, h) = try cached()
        let before = Self.frame(h)
        let live = h.resources.stats.liveTotal
        h.view.frame = CGRect(x: 0, y: 0, width: 48, height: 40)
        h.view.layoutIfNeeded()
        let other = Self.frame(h)
        XCTAssertEqual(other.count, h.pixelSize.width * h.pixelSize.height * 4)
        XCTAssertEqual(cache.childDrawCount, 2, "a resize draws once at the new size")
        XCTAssertEqual(Self.frame(h), other)
        XCTAssertEqual(cache.childDrawCount, 2)
        h.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        h.view.layoutIfNeeded()
        XCTAssertEqual(Self.frame(h), before, "the same size gives the same frame")
        XCTAssertEqual(cache.childDrawCount, 3)
        XCTAssertEqual(h.resources.stats.liveTotal, live, "one target at a time")
    }

    func testRepeatedSetupAfterContextRecreationDrawsOnceMoreWithTheSameFrame() throws {
        let (cache, _, h) = try cached()
        let before = Self.frame(h)
        let live = h.resources.stats.liveTotal
        h.recreateContext()
        XCTAssertTrue(cache.isSetUp)
        XCTAssertEqual(Self.frame(h), before)
        XCTAssertEqual(cache.childDrawCount, 2, "the new context generation draws once")
        XCTAssertEqual(Self.frame(h), before)
        XCTAssertEqual(cache.childDrawCount, 2)
        XCTAssertEqual(h.resources.stats.liveTotal, live, "the target and the child's program rebuilt, nothing extra")
        XCTAssertEqual(h.resources.stats.leaked, 0)
    }

    func testPassThroughDrawsEveryFrameAsTheChild() throws {
        let own2 = try alone(at: 2)
        let child = Self.child(at: 2)
        let cache = CachedScene(child: child)
        XCTAssertTrue(cache.passThrough, "pass-through is the default")
        let h = try host(cache)
        for _ in 0..<10 { XCTAssertEqual(Self.frame(h), own2) }
        XCTAssertEqual(cache.childDrawCount, 10)
        cache.passThrough = false
        _ = Self.frame(h)
        _ = Self.frame(h)
        XCTAssertEqual(cache.childDrawCount, 11, "leaving pass-through draws once into the cache")
        cache.passThrough = true
        child.fixedTime = 0
        _ = Self.frame(h)
        cache.passThrough = false
        XCTAssertEqual(Self.frame(h), try alone(at: 0), "returning to the cache draws a fresh picture, not a stale one")
        XCTAssertEqual(cache.childDrawCount, 13)
    }

    func testTeardownLeavesNoGPUObject() throws {
        let h = try host(ClosureScene())
        XCTAssertTrue(h.renderOneFrame(present: false))
        let baseline = h.resources.stats
        let cache = CachedScene(child: Self.child(at: 0))
        cache.passThrough = false
        h.replaceScene(cache)
        _ = Self.frame(h)
        XCTAssertGreaterThan(h.resources.stats.liveTotal, baseline.liveTotal)
        h.replaceScene(ClosureScene())
        XCTAssertFalse(cache.isSetUp)
        XCTAssertEqual(h.resources.stats.liveTotal, baseline.liveTotal, "no target or program left")
        XCTAssertEqual(h.resources.stats.totalBytes, baseline.totalBytes)
        h.destroy()
        XCTAssertEqual(h.resources.stats.leaked, 0)
    }
}
