// DepthTargetTests — feature 204 T-R02F04-011 (US3; FR-R02F04-030…033, SC-R02F04-003): offscreen render targets
// with a 24-bit depth renderbuffer. Depth state is set directly with vcgl calls (the opaque 3D state: depth test on,
// depth write on, GL_LESS) so the test does not depend on the pipeline files of story 2.
import CVisualCoreGL
import VisualCoreDiagnostics
import XCTest
@testable import VisualCoreRendering

@MainActor
final class DepthTargetTests: XCTestCase {
    static let vertex = """
    uniform float uZ;
    void main() {
        vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
        gl_Position = vec4(p * 2.0 - 1.0, uZ, 1.0);
    }
    """
    static let fragment = "precision mediump float;\nuniform vec4 uColor;\nout vec4 c;\nvoid main() { c = uColor; }"
    static let far: Float = 0.5, near: Float = -0.5
    static let red = SIMD4<Float>(1, 0, 0, 1), green = SIMD4<Float>(0, 1, 0, 1)

    private func host(_ scene: RenderScene, budget: ResourceBudget = ResourceBudget()) throws -> RenderHost {
        let h = try RenderHost(scene: scene, budget: budget)
        h.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        h.view.layoutIfNeeded()
        return h
    }

    /// Clears `target`, draws two full-screen triangles in order with depth testing on and returns pixel (0, 0).
    private static func drawPair(_ target: RenderTarget, _ program: ShaderProgram,
                                 _ first: (z: Float, color: SIMD4<Float>), _ second: (z: Float, color: SIMD4<Float>)) -> [UInt8] {
        target.bind()
        vcglViewport(0, 0, GLsizei(target.width), GLsizei(target.height))
        vcglDisable(GLenum(GL_BLEND))
        vcglDisable(GLenum(GL_CULL_FACE))
        vcglEnable(GLenum(GL_DEPTH_TEST))
        vcglDepthFunc(GLenum(GL_LESS))
        vcglDepthMask(GLboolean(GL_TRUE))
        vcglClearColor(0, 0, 0, 1)
        vcglClearDepthf(1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
        program.use()
        for pass in [first, second] {
            program.set("uZ", pass.z)
            program.set("uColor", pass.color)
            vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        }
        vcglDisable(GLenum(GL_DEPTH_TEST))
        return Array(target.readPixels().prefix(4))
    }

    func testNearerColourWinsInBothDrawOrders() throws {
        var farThenNear: [UInt8] = [], nearThenFar: [UInt8] = [], withoutDepth: [UInt8] = []
        var depthName: GLuint = 0
        let scene = ProbeScene(setup: { ctx in
            let program = try ctx.resources.program(vertex: Self.vertex, fragment: Self.fragment)
            let target = try ctx.resources.makeRenderTarget(width: 8, height: 8, depth: true, label: "depth")
            depthName = target.depthRenderbuffer
            farThenNear = Self.drawPair(target, program, (Self.far, Self.red), (Self.near, Self.green))
            nearThenFar = Self.drawPair(target, program, (Self.near, Self.green), (Self.far, Self.red))
            let plain = try ctx.resources.makeRenderTarget(width: 8, height: 8, label: "no depth")
            withoutDepth = Self.drawPair(plain, program, (Self.near, Self.green), (Self.far, Self.red))
            ctx.resources.release(target)
            ctx.resources.release(plain)
            ctx.resources.release(program)
        })
        _ = try host(scene)
        XCTAssertNotEqual(depthName, 0, "a depth target carries a renderbuffer")
        for (pixel, order) in [(farThenNear, "far then near"), (nearThenFar, "near then far")] {
            XCTAssertEqual(pixel.count, 4, order)
            guard pixel.count == 4 else { continue }
            XCTAssertGreaterThan(Int(pixel[1]), 250, "nearer green wins (\(order))")
            XCTAssertLessThan(Int(pixel[0]), 5, "farther red is hidden (\(order))")
        }
        XCTAssertGreaterThan(Int(withoutDepth.first ?? 0), 250, "control: without depth storage the last draw wins")
    }

    /// T-R02F04-024 (US2 with US3): the opaque 3D pipeline applied by `GLState.apply` gives correct occlusion in a
    /// depth target, in both draw orders.
    func testOpaque3DPipelineResolvesOcclusionInADepthTarget() throws {
        var pixels: [[UInt8]] = []
        var applied: [Bool] = []
        let scene = ProbeScene(setup: { ctx in
            let program = try ctx.resources.program(vertex: Self.vertex, fragment: Self.fragment)
            let pipeline = Pipeline(program: program, state: .opaque3D)
            let target = try ctx.resources.makeRenderTarget(width: 8, height: 8, depth: true, label: "pipeline depth")
            for order in [[(Self.far, Self.red), (Self.near, Self.green)], [(Self.near, Self.green), (Self.far, Self.red)]] {
                target.bind()
                vcglViewport(0, 0, GLsizei(target.width), GLsizei(target.height))
                vcglDepthMask(GLboolean(GL_TRUE))          // clearing depth needs writes enabled
                vcglClearColor(0, 0, 0, 1)
                vcglClearDepthf(1)
                vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
                applied.append(GLState.apply(pipeline, resources: ctx.resources))
                for pass in order {
                    program.set("uZ", pass.0)
                    program.set("uColor", pass.1)
                    vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
                }
                pixels.append(Array(target.readPixels().prefix(4)))
            }
            ctx.resources.release(target)
            ctx.resources.release(program)
        })
        _ = try host(scene)
        XCTAssertEqual(applied, [true, true], "the opaque 3D pipeline applies")
        XCTAssertEqual(pixels.count, 2)
        for (pixel, order) in zip(pixels, ["far then near", "near then far"]) {
            XCTAssertGreaterThan(Int(pixel.count == 4 ? pixel[1] : 0), 250, "nearer green wins (\(order))")
            XCTAssertLessThan(Int(pixel.first ?? 255), 5, "farther red is hidden (\(order))")
        }
    }

    func testReleaseFreesColourAndDepth() throws {
        var during: ResourceLedger.Snapshot?
        let scene = ProbeScene(setup: { ctx in
            let target = try ctx.resources.makeRenderTarget(width: 16, height: 8, depth: true, label: "depth")
            during = ctx.resources.stats
            ctx.resources.release(target)
            ctx.resources.release(target)      // second release is ignored
        })
        let h = try host(scene)
        let live = try XCTUnwrap(during)
        XCTAssertEqual(live.liveCount[.framebuffer], 1)
        XCTAssertEqual(live.liveCount[.renderbuffer], 1)
        XCTAssertEqual(live.liveBytes[.renderbuffer], 16 * 8 * 4, "24-bit depth accounted as 4 bytes per pixel")
        XCTAssertEqual(live.liveBytes[.framebuffer], 16 * 8 * 4)
        XCTAssertEqual(h.resources.stats.liveCount[.framebuffer], 0)
        XCTAssertEqual(h.resources.stats.liveCount[.renderbuffer], 0)
        XCTAssertEqual(h.resources.stats.totalBytes, 0)
    }

    func testContextRecreationRejectsTheOldDepthTarget() throws {
        var target: RenderTarget?
        let scene = ProbeScene(setup: { ctx in
            if target == nil { target = try ctx.resources.makeRenderTarget(width: 8, height: 8, depth: true, label: "old") }
        })
        let h = try host(scene)
        h.recreateContext()
        let old = try XCTUnwrap(target)
        old.bind()
        XCTAssertEqual(h.resources.stats.staleRejected, 1, "binding the old target is rejected")
        XCTAssertEqual(old.readPixels(), [], "reading the old target is rejected")
        XCTAssertEqual(h.resources.stats.leaked, 2, "the unreleased framebuffer and its depth renderbuffer")
        XCTAssertEqual(h.resources.stats.liveCount[.renderbuffer], 0)
        h.resources.release(old)               // stale release: no GL call, no ledger change
        XCTAssertEqual(h.resources.stats.liveCount[.renderbuffer], 0)
    }

    func testInvalidSizesThrowWithNothingAllocated() throws {
        var errors: [ResourceError] = []
        var after: ResourceLedger.Snapshot?
        let scene = ProbeScene(setup: { ctx in
            let max = ctx.resources.maxTextureSize
            for (w, h) in [(0, 8), (8, 0), (max + 1, 8)] {
                do { _ = try ctx.resources.makeRenderTarget(width: w, height: h, depth: true, label: "bad") }
                catch let e as ResourceError { errors.append(e) }
            }
            after = ctx.resources.stats
        })
        _ = try host(scene)
        XCTAssertEqual(errors.count, 3)
        let s = try XCTUnwrap(after)
        XCTAssertEqual(s.liveCount[.framebuffer], 0)
        XCTAssertEqual(s.liveCount[.texture], 0)
        XCTAssertEqual(s.liveCount[.renderbuffer], 0)
        XCTAssertEqual(s.totalBytes, 0)
    }

    func testBudgetSmallerThanOneDepthTargetThrowsAndAllocatesNothing() throws {
        var caught: Error?
        var after: ResourceLedger.Snapshot?
        let scene = ProbeScene(setup: { ctx in
            // 8×8: colour 256 bytes fits, colour + depth 512 bytes does not.
            do { _ = try ctx.resources.makeRenderTarget(width: 8, height: 8, depth: true, label: "too big") } catch { caught = error }
            after = ctx.resources.stats
        })
        _ = try host(scene, budget: ResourceBudget(total: 384))
        guard case .overBudget(.renderbuffer, requested: 256, available: 128)? = caught as? ResourceBudgetError else {
            return XCTFail("expected the renderbuffer budget error, got \(String(describing: caught))")
        }
        let s = try XCTUnwrap(after)
        XCTAssertEqual(s.liveCount[.framebuffer], 0)
        XCTAssertEqual(s.liveCount[.texture], 0)
        XCTAssertEqual(s.liveCount[.renderbuffer], 0)
        XCTAssertEqual(s.totalBytes, 0)
    }

    func testPooledTargetsWithAndWithoutDepthAreDistinct() throws {
        var withDepth: RenderTarget?, plain: RenderTarget?, againDepth: RenderTarget?, againPlain: RenderTarget?
        let scene = ProbeScene(setup: { ctx in
            let a = try ctx.resources.acquireTarget(width: 8, height: 8, depth: true)
            let b = try ctx.resources.acquireTarget(width: 8, height: 8)
            ctx.resources.recycle(a)
            ctx.resources.recycle(b)
            againPlain = try ctx.resources.acquireTarget(width: 8, height: 8)
            againDepth = try ctx.resources.acquireTarget(width: 8, height: 8, depth: true)
            withDepth = a; plain = b
            ctx.resources.recycle(againPlain!)
            ctx.resources.recycle(againDepth!)
        })
        let h = try host(scene)
        XCTAssertNotEqual(try XCTUnwrap(withDepth).depthRenderbuffer, 0)
        XCTAssertEqual(try XCTUnwrap(plain).depthRenderbuffer, 0)
        XCTAssertTrue(againDepth === withDepth, "a depth request reuses the pooled depth target")
        XCTAssertTrue(againPlain === plain, "a plain request reuses the pooled plain target, not the depth one")
        XCTAssertEqual(h.resources.stats.liveCount[.framebuffer], 2)
        XCTAssertEqual(h.resources.stats.liveCount[.renderbuffer], 1)
        h.resources.trimPools()
        XCTAssertEqual(h.resources.stats.liveCount[.renderbuffer], 0)
        XCTAssertEqual(h.resources.stats.totalBytes, 0)
    }
}
