// InstancedMeshRendererTests — feature 209 (R02-F09) T-R02F09-003 (SC-R02F09-001, SC-R02F09-003; clarifications Q1,
// Q3–Q5). On the simulator through OpenGL ES → ANGLE → Metal: 500 instances drawn with one instanced call equal 500
// `MeshRenderer` draws within 1/255 per channel into a target with depth (depth test on, lighting and fog on); the
// limit (16,384) is accepted and one more is refused with nothing drawn; a non-finite matrix or colour is refused;
// scrambled translucent orders give the sorted picture, which equals sequential back-to-front `MeshRenderer` draws;
// equal depths keep submission order; 100 frames keep the registry's live counts constant; a context recreation gives
// the same picture. Errors are captured inside the GL closure because `RenderHost` reports scene errors itself.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

/// Runs a closure with a fresh size×size colour + depth target bound, cleared to opaque black and depth 1, depth test
/// on (LESS); returns its pixels (rows bottom-up).
@MainActor
enum DepthDrawHarness {
    static func pixels(size: Int = 64, keep: inout RenderHost?, _ body: @escaping (RenderContext) throws -> Void) throws -> [UInt8] {
        var out: [UInt8] = []
        let host = try RenderHost(scene: ProbeScene(setup: { ctx in
            let t = try ctx.resources.makeRenderTarget(width: size, height: size, depth: true, label: "instancing test")
            t.bind()
            vcglViewport(0, 0, GLsizei(size), GLsizei(size))
            vcglDisable(GLenum(GL_BLEND))
            vcglDepthMask(GLboolean(GL_TRUE))
            vcglClearColor(0, 0, 0, 1)
            vcglClearDepthf(1)
            vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT))
            vcglEnable(GLenum(GL_DEPTH_TEST))
            vcglDepthFunc(GLenum(GL_LESS))
            try body(ctx)
            vcglDisable(GLenum(GL_DEPTH_TEST))
            out = t.readPixels()
            ctx.resources.release(t)
        }))
        host.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        host.view.layoutIfNeeded()
        keep = host
        return out
    }

    /// The largest per-channel difference between two equal-sized pixel arrays (Int.max when the sizes differ or empty).
    static func maxDifference(_ a: [UInt8], _ b: [UInt8]) -> Int {
        guard a.count == b.count, !a.isEmpty else { return .max }
        return zip(a, b).reduce(0) { max($0, abs(Int($1.0) - Int($1.1))) }
    }
}

@MainActor
final class InstancedMeshRendererTests: XCTestCase {
    static let camera = OrbitCamera(target: .zero, distance: 6, yaw: 0.3, pitch: 0.25)
    private var host: RenderHost?

    /// 500 deterministic cubes: positions in a 3.2 × 3.2 × 3 box (so they overlap in depth), uniform scales 0.12…0.3,
    /// rotations about varied axes, opaque colours.
    static func fiveHundred() -> [MeshInstance] {
        var seed: UInt64 = 0x2090_0003
        func next() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0..<500).map { _ in
            let position = Vec3(next() * 3.2 - 1.6, next() * 3.2 - 1.6, next() * 3 - 1.5)
            let axis = Vec3(next() - 0.5, next() - 0.5, next() - 0.5 + 0.01).normalized
            let s = 0.12 + next() * 0.18
            let model = Mat4.translation(position) * Mat4.rotation(Quat(axis: axis, angle: next() * 6.28)) * Mat4.scale(Vec3(s, s, s))
            return MeshInstance(model: model, color: Vec4(0.2 + 0.8 * next(), 0.2 + 0.8 * next(), 0.2 + 0.8 * next(), 1))
        }
    }

    func testFiveHundredInstancesEqualFiveHundredMeshRendererDraws() throws {
        let instances = Self.fiveHundred()
        let view = Self.camera.view(), projection = Self.camera.projection(aspect: 1)
        let fog = try XCTUnwrap(MeshFog(start: 4, end: 9, color: Vec4(0.1, 0.1, 0.2, 1)))
        var calls = -1, error = GLenum(1)
        let instanced = try DepthDrawHarness.pixels(keep: &host) { ctx in
            let r = try InstancedMeshRenderer(mesh: .cube(), registry: ctx.resources)
            try r.draw(instances, view: view, projection: projection, fog: fog)
            calls = r.drawCallCount
            error = vcglGetError()
            r.release()
        }
        XCTAssertEqual(calls, 1, "500 instances in one draw call")
        XCTAssertEqual(error, GLenum(GL_NO_ERROR))
        let sequential = try DepthDrawHarness.pixels(keep: &host) { ctx in
            let r = try MeshRenderer(mesh: .cube(), registry: ctx.resources)
            for i in instances { try r.draw(model: i.model, view: view, projection: projection, color: i.color, fog: fog) }
            r.release()
        }
        let lit = stride(from: 0, to: instanced.count, by: 4).filter { instanced[$0] > 0 || instanced[$0 + 1] > 0 }.count
        XCTAssertGreaterThan(lit, 64 * 64 / 4, "the cubes cover a quarter of the target (\(lit) px)")
        let difference = DepthDrawHarness.maxDifference(instanced, sequential)
        print("InstancedMeshRendererTests: 500 instances vs 500 MeshRenderer draws, max difference \(difference)/255, \(lit) px lit")
        XCTAssertLessThanOrEqual(difference, 1, "instanced picture equals 500 MeshRenderer draws within 1/255")
    }

    func testTheLimitIsAcceptedAndOneMoreIsRefusedWithNothingDrawn() throws {
        let one = MeshInstance(model: .translation(Vec3(0, 0, 0)), color: Vec4(1, 1, 1, 1))
        var refused: Error?, callsAfterRefusal = -1, callsAtLimit = -1
        let p = try DepthDrawHarness.pixels(keep: &host) { ctx in
            let r = try InstancedMeshRenderer(mesh: .cube(), registry: ctx.resources)
            do {
                try r.draw(Array(repeating: one, count: InstancedMeshRenderer.maxInstances + 1),
                           view: Self.camera.view(), projection: Self.camera.projection(aspect: 1), fog: nil)
            } catch { refused = error }
            callsAfterRefusal = r.drawCallCount
            try r.draw([], view: Self.camera.view(), projection: Self.camera.projection(aspect: 1), fog: nil)
            XCTAssertEqual(r.drawCallCount, 0, "an empty list draws nothing")
            r.release()
        }
        XCTAssertEqual(InstancedMeshRenderer.maxInstances, 16_384)
        XCTAssertEqual(refused as? InstancingError, .tooMany(count: 16_385, limit: 16_384))
        XCTAssertEqual(callsAfterRefusal, 0)
        XCTAssertTrue(stride(from: 0, to: p.count, by: 4).allSatisfy { p[$0] == 0 && p[$0 + 1] == 0 && p[$0 + 2] == 0 },
                      "nothing drawn")
        let atLimit = try DepthDrawHarness.pixels(keep: &host) { ctx in
            let r = try InstancedMeshRenderer(mesh: .cube(), registry: ctx.resources)
            try r.draw(Array(repeating: one, count: InstancedMeshRenderer.maxInstances),
                       view: Self.camera.view(), projection: Self.camera.projection(aspect: 1), fog: nil)
            callsAtLimit = r.drawCallCount
            r.release()
        }
        XCTAssertEqual(callsAtLimit, 1)
        XCTAssertGreaterThan(DrawHarness.px(atLimit, 64, 32, 32).x, 0, "16,384 instances drawn")
    }

    func testNonFiniteMatrixOrColourIsRefused() throws {
        let good = MeshInstance(model: .identity, color: Vec4(1, 0, 0, 1))
        var badMatrix = Mat4.translation(Vec3(0.1, 0, 0))
        badMatrix.c1.z = .nan
        let lists: [([MeshInstance], InstancingError)] = [
            ([good, good, MeshInstance(model: badMatrix, color: Vec4(1, 0, 0, 1))], .notFinite(index: 2)),
            ([good, MeshInstance(model: .identity, color: Vec4(1, .infinity, 0, 1))], .notFinite(index: 1)),
            ([MeshInstance(model: .translation(Vec3(-.infinity, 0, 0)), color: Vec4(1, 0, 0, 1))], .notFinite(index: 0)),
        ]
        for (list, expected) in lists {
            XCTAssertThrowsError(try InstancedMeshRenderer.instanceFloats(list)) { XCTAssertEqual($0 as? InstancingError, expected) }
        }
        var errors: [InstancingError?] = [], calls = -1
        let p = try DepthDrawHarness.pixels(keep: &host) { ctx in
            let r = try InstancedMeshRenderer(mesh: .cube(), registry: ctx.resources)
            for (list, _) in lists {
                do {
                    try r.draw(list, view: Self.camera.view(), projection: Self.camera.projection(aspect: 1), fog: nil)
                    errors.append(nil)
                } catch { errors.append(error as? InstancingError) }
            }
            calls = r.drawCallCount
            r.release()
        }
        XCTAssertEqual(errors, lists.map(\.1))
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(DrawHarness.px(p, 64, 32, 32), SIMD4(0, 0, 0, 255), "nothing drawn")
    }

    /// Six flat-lit (ambient 1) translucent cubes at increasing z (nearer the eye at +z), overlapping on screen: the
    /// list is already back to front.
    static func translucentSorted() -> [MeshInstance] {
        let colors = [Vec4(1, 0, 0, 0.5), Vec4(0, 1, 0, 0.4), Vec4(0, 0, 1, 0.6),
                      Vec4(1, 1, 0, 0.3), Vec4(0, 1, 1, 0.5), Vec4(1, 0, 1, 0.45)]
        return colors.enumerated().map { i, c in
            let t = Double(i)
            return MeshInstance(model: .translation(Vec3(0.12 * t - 0.3, 0.08 * t - 0.2, -1.5 + 0.6 * t)), color: c)
        }
    }

    func testScrambledTranslucentOrdersEqualTheSortedPicture() throws {
        let sorted = Self.translucentSorted()
        let camera = OrbitCamera(distance: 4)
        let view = camera.view(), projection = camera.projection(aspect: 1)
        let orders = [[0, 1, 2, 3, 4, 5], [5, 4, 3, 2, 1, 0], [2, 5, 0, 3, 1, 4], [4, 0, 5, 1, 3, 2]]
        var pictures: [[UInt8]] = []
        for order in orders {
            pictures.append(try DepthDrawHarness.pixels(keep: &host) { ctx in
                let r = try InstancedMeshRenderer(mesh: .cube(), registry: ctx.resources)
                r.ambient = 1
                try r.draw(order.map { sorted[$0] }, view: view, projection: projection, fog: nil, translucent: true)
                XCTAssertEqual(vcglIsEnabled(GLenum(GL_BLEND)), GLboolean(GL_FALSE), "blending disabled again")
                var mask = GLboolean(GL_FALSE)
                vcglGetBooleanv(GLenum(GL_DEPTH_WRITEMASK), &mask)
                XCTAssertEqual(mask, GLboolean(GL_TRUE), "depth writes enabled again")
                r.release()
            })
        }
        for (order, picture) in zip(orders, pictures).dropFirst() {
            XCTAssertEqual(picture, pictures[0], "order \(order) gives the sorted picture")
        }
        let reference = try DepthDrawHarness.pixels(keep: &host) { ctx in
            let r = try MeshRenderer(mesh: .cube(), registry: ctx.resources)
            r.ambient = 1
            vcglEnable(GLenum(GL_BLEND))
            vcglBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
            vcglDepthMask(GLboolean(GL_FALSE))
            for i in sorted { try r.draw(model: i.model, view: view, projection: projection, color: i.color, fog: nil) }
            vcglDepthMask(GLboolean(GL_TRUE))
            vcglDisable(GLenum(GL_BLEND))
            r.release()
        }
        XCTAssertLessThanOrEqual(DepthDrawHarness.maxDifference(pictures[0], reference), 1,
                                 "sorted instanced picture equals sequential back-to-front MeshRenderer draws")
        XCTAssertNotEqual(DrawHarness.px(pictures[0], 64, 32, 32), SIMD4(0, 0, 0, 255))
    }

    func testEqualDepthsKeepSubmissionOrder() throws {
        // Same translation z (a tie), overlapping in the middle of the view.
        let first = MeshInstance(model: .translation(Vec3(-0.25, 0, 0)), color: Vec4(1, 0, 0, 0.6))
        let second = MeshInstance(model: .translation(Vec3(0.25, 0, 0)), color: Vec4(0, 0, 1, 0.6))
        let camera = OrbitCamera(distance: 4)
        let view = camera.view(), projection = camera.projection(aspect: 1)
        XCTAssertEqual(try InstancedMeshRenderer.backToFront([first, second], view: view), [0, 1])
        XCTAssertEqual(try InstancedMeshRenderer.backToFront([second, first], view: view), [0, 1])
        func instanced(_ list: [MeshInstance]) throws -> [UInt8] {
            try DepthDrawHarness.pixels(keep: &host) { ctx in
                let r = try InstancedMeshRenderer(mesh: .cube(), registry: ctx.resources)
                r.ambient = 1
                try r.draw(list, view: view, projection: projection, fog: nil, translucent: true)
                r.release()
            }
        }
        func sequential(_ list: [MeshInstance]) throws -> [UInt8] {
            try DepthDrawHarness.pixels(keep: &host) { ctx in
                let r = try MeshRenderer(mesh: .cube(), registry: ctx.resources)
                r.ambient = 1
                vcglEnable(GLenum(GL_BLEND))
                vcglBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
                vcglDepthMask(GLboolean(GL_FALSE))
                for i in list { try r.draw(model: i.model, view: view, projection: projection, color: i.color, fog: nil) }
                vcglDepthMask(GLboolean(GL_TRUE))
                vcglDisable(GLenum(GL_BLEND))
                r.release()
            }
        }
        let ab = try instanced([first, second]), ba = try instanced([second, first])
        XCTAssertLessThanOrEqual(DepthDrawHarness.maxDifference(ab, try sequential([first, second])), 1)
        XCTAssertLessThanOrEqual(DepthDrawHarness.maxDifference(ba, try sequential([second, first])), 1)
        XCTAssertNotEqual(DrawHarness.px(ab, 64, 32, 32), DrawHarness.px(ba, 64, 32, 32),
                          "the overlap shows which was drawn last: ties keep submission order")
    }

    func testOneHundredFramesKeepLiveCountsConstant() throws {
        let scene = InstancedScene()
        let all = Self.fiveHundred()
        scene.instances = { frame in Array(all.prefix(frame % 2 == 0 ? 500 : 300)) }
        let h = try RenderHost(scene: scene)
        host = h
        h.view.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        h.view.layoutIfNeeded()
        XCTAssertTrue(h.renderOneFrame(present: false))
        let live = h.resources.stats.liveCount, bytes = h.resources.stats.liveBytes, compiles = h.resources.compileCount
        for _ in 1..<100 { XCTAssertTrue(h.renderOneFrame(present: false)) }
        XCTAssertEqual(h.resources.stats.liveCount, live, "no GPU object added over 100 frames")
        XCTAssertEqual(h.resources.stats.liveBytes, bytes, "the instance buffer is reused")
        XCTAssertEqual(h.resources.compileCount, compiles)
        XCTAssertEqual(scene.renderer?.drawCallCount, 100, "one draw call per frame")
        XCTAssertEqual(vcglGetError(), GLenum(GL_NO_ERROR))
        h.destroy()
        XCTAssertEqual(h.resources.stats.leaked, 0)
    }

    func testContextRecreationGivesTheSamePicture() throws {
        let scene = InstancedScene()
        let all = Self.fiveHundred()
        scene.instances = { _ in all }
        let h = try RenderHost(scene: scene)
        host = h
        h.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        h.view.layoutIfNeeded()
        XCTAssertTrue(h.renderOneFrame(present: false))
        let before = h.readPixels()
        let renderer = scene.renderer
        h.recreateContext()
        XCTAssertTrue(h.renderOneFrame(present: false))
        let after = h.readPixels()
        XCTAssertTrue(scene.renderer === renderer, "the same renderer rebuilt its GPU objects")
        XCTAssertFalse(before.isEmpty)
        XCTAssertEqual(before, after, "same picture after the context recreation")
        let lit = stride(from: 0, to: before.count, by: 4).filter { before[$0] > 0 || before[$0 + 1] > 0 }.count
        XCTAssertGreaterThan(lit, 0, "the cubes are drawn")
        h.destroy()
        XCTAssertEqual(h.resources.stats.leaked, 0)
    }
}

/// Draws a list of cube instances into the window framebuffer each frame with one renderer kept for the host's
/// lifetime; teardown releases its GPU objects (the next setup keeps the object, so its draw rebuilds them).
@MainActor
private final class InstancedScene: RenderScene {
    var instances: (Int) -> [MeshInstance] = { _ in [] }
    private(set) var renderer: InstancedMeshRenderer?
    private var frameIndex = 0

    func setup(_ c: RenderContext) throws {
        if renderer == nil { renderer = try InstancedMeshRenderer(mesh: .cube(), registry: c.resources) }
    }
    func resize(_ c: RenderContext) {}
    func render(_ c: RenderContext, frame: FrameInfo) throws {
        vcglClearColor(0, 0, 0, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        let camera = InstancedMeshRendererTests.camera
        try renderer?.draw(instances(frameIndex), view: camera.view(), projection: camera.projection(aspect: 1), fog: nil)
        frameIndex += 1
    }
    func teardown(_ c: RenderContext) { renderer?.release() }
}
