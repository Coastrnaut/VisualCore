// PlanarShadowRendererTests — feature 213 (R02-F13) T-R02F13-004 (FR-R02F13-005; SC-R02F13-003; research R5;
// clarification Q5). On the simulator through OpenGL ES → ANGLE → Metal, into a 64 × 64 target cleared to white.
//
// Expected coverage (the method): for every pixel the centre (x + ½, y + ½) gives NDC (2(x + ½)/64 − 1, 2(y + ½)/64 − 1);
// the inverse of projection × view maps NDC depths −1 and 1 to two world points whose ray is intersected with the ground
// y = 0, the hit g is converted to plane coordinates with `ProjectionPlane.coordinates(of:)` and tested (even–odd)
// against every polygon of `ShadowProjector.project(mesh:light:onto:)` for the model-transformed mesh. A pixel is
// covered on the GPU when it is darker than white by at least 100/255. The two agree at every pixel whose 3 × 3 CPU
// neighbourhood is uniform (SC-R02F13-003). Further: a self-overlapping mesh darkens every covered pixel exactly once;
// a parallel light and a target that cannot be created throw and draw nothing; the GL state is restored; zero live GPU
// objects after the host is destroyed; a context recreation gives the same picture. Errors are captured inside the GL
// closure because `RenderHost` reports scene errors itself.
import CVisualCoreGL
import Foundation
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

@MainActor
final class PlanarShadowRendererTests: XCTestCase {
    static let size = 64
    static let projection = Mat4.perspective(fovY: 2 * atan(0.3), aspect: 1, near: 0.1, far: 100)
    /// A camera 8 units above the ground looking straight down (−z of the world is up in the picture).
    static let view = Mat4.lookAt(eye: Vec3(0, 8, 0), target: Vec3(0, 0, 0), up: Vec3(0, 0, -1))
    private var host: RenderHost?

    static func ground() throws -> ProjectionPlane { ProjectionPlane(plane: try ClipPlane(normal: Vec3(0, 1, 0), offset: 0)) }
    static func light() throws -> ShadowLight { try ShadowLight.directional(towards: Vec3(0.3, -1, 0.2)) }

    /// `mesh` with every position mapped by `m`.
    static func transformed(_ mesh: Mesh, _ m: Mat4) -> Mesh {
        var out = mesh
        out.positions = mesh.positions.map { m.applyPoint($0) }
        return out
    }

    /// Even–odd point-in-polygon.
    static func inside(_ q: Vec2, _ polygon: [Vec2]) -> Bool {
        var result = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i], b = polygon[j]
            if (a.y > q.y) != (b.y > q.y), q.x < a.x + (q.y - a.y) * (b.x - a.x) / (b.y - a.y) { result.toggle() }
            j = i
        }
        return result
    }

    /// The CPU coverage of every pixel (row-major, rows bottom-up) for the world-space `mesh` (method in the header).
    static func expectedCoverage(_ mesh: Mesh) throws -> [Bool] {
        let plane = try ground()
        let polygons = try ShadowProjector.project(mesh: mesh, light: try light(), onto: plane)
        let inverse = try XCTUnwrap((projection * view).inverse)
        var out: [Bool] = []
        out.reserveCapacity(size * size)
        for y in 0..<size {
            for x in 0..<size {
                let nx = (Double(x) + 0.5) / Double(size) * 2 - 1, ny = (Double(y) + 0.5) / Double(size) * 2 - 1
                let near = inverse.applyPoint(Vec3(nx, ny, -1)), far = inverse.applyPoint(Vec3(nx, ny, 1))
                let t = near.y / (near.y - far.y)
                let g = near + (far - near) * t
                let q = plane.coordinates(of: g)
                out.append(polygons.contains { inside(q, $0) })
            }
        }
        return out
    }

    /// The pixels of the shadow of `mesh` (placed by `model`) drawn once by a fresh renderer over white, and the
    /// renderer's draw-call count; `light` and `viewport` default to the test light and the full target.
    private func draw(_ mesh: Mesh, model: Mat4 = .identity, darkness: Double = 0.5, light: ShadowLight? = nil,
                      viewport: (width: Int, height: Int)? = nil) throws -> (pixels: [UInt8], calls: Int, error: Error?) {
        var calls = -1, glError = GLenum(1), thrown: Error?
        let plane = try Self.ground(), shadowLight = try light ?? Self.light()
        var stateBefore: [GLint] = [], stateAfter: [GLint] = []
        func state() -> [GLint] {
            var fb: GLint = 0, vp: [GLint] = [0, 0, 0, 0]
            vcglGetIntegerv(GLenum(GL_FRAMEBUFFER_BINDING), &fb)
            vcglGetIntegerv(GLenum(GL_VIEWPORT), &vp)
            var clear: [GLfloat] = [0, 0, 0, 0]
            vcglGetFloatv(GLenum(GL_COLOR_CLEAR_VALUE), &clear)
            let flags = [GL_BLEND, GL_DEPTH_TEST, GL_CULL_FACE].map { GLint(vcglIsEnabled(GLenum($0))) }
            return [fb] + vp + clear.map { GLint($0 * 255) } + flags
        }
        let p = try DrawHarness.pixels(size: Self.size, keep: &host) { ctx in
            vcglClearColor(1, 1, 1, 1)
            vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            let r = try PlanarShadowRenderer(mesh: mesh, registry: ctx.resources)
            r.darkness = darkness
            stateBefore = state()
            do {
                try r.draw(model: model, light: shadowLight, plane: plane, view: Self.view, projection: Self.projection,
                           viewport: viewport ?? (Self.size, Self.size))
            } catch { thrown = error }
            stateAfter = state()
            calls = r.drawCallCount
            glError = vcglGetError()
            r.release()
        }
        XCTAssertEqual(glError, GLenum(GL_NO_ERROR))
        XCTAssertEqual(stateBefore, stateAfter, "framebuffer, viewport, clear colour and enables restored")
        return (p, calls, thrown)
    }

    static func cubeModel() -> Mat4 { Mat4.translation(Vec3(0, 1.2, 0)) * Mat4.scale(Vec3(1, 1.5, 0.8)) }

    // MARK: Coverage equals the CPU mask (SC-R02F13-003)

    func testCubeShadowMatchesTheCPUCoverage() throws {
        let model = Self.cubeModel()
        let (pixels, calls, error) = try draw(Mesh.cube(), model: model)
        XCTAssertNil(error)
        XCTAssertEqual(calls, 2, "one coverage and one composite draw")
        let expected = try Self.expectedCoverage(Self.transformed(Mesh.cube(), model))
        var compared = 0, covered = 0, mismatches = 0
        let n = Self.size
        for y in 1..<(n - 1) {
            for x in 1..<(n - 1) {
                let e = expected[y * n + x]
                var uniform = true
                for dy in -1...1 { for dx in -1...1 where expected[(y + dy) * n + x + dx] != e { uniform = false } }
                guard uniform else { continue }
                compared += 1
                let gpu = DrawHarness.px(pixels, n, x, y).x <= 255 - 100
                if gpu { covered += 1 }
                if gpu != e { mismatches += 1 }
            }
        }
        print("PlanarShadowRendererTests: cube, \(compared) px compared, \(covered) covered, \(mismatches) mismatches")
        XCTAssertGreaterThan(covered, 50, "the shadow is visible")
        XCTAssertEqual(mismatches, 0)
    }

    // MARK: Single darkening (research R5)

    func testOverlappingBoxesDarkenEveryPixelOnce() throws {
        let a = Self.transformed(Mesh.cube(), Mat4.translation(Vec3(0, 1, 0)))
        let b = Self.transformed(Mesh.cube(), Mat4.translation(Vec3(0.4, 1.3, 0.3)) * Mat4.scale(Vec3(1.2, 1, 1)))
        let mesh = try Mesh.merged([a, b])
        let darkness = 0.6
        let (pixels, _, error) = try draw(mesh, darkness: darkness)
        XCTAssertNil(error)
        let single = 255 * (1 - darkness)
        var shadowed = 0, worst = 0.0, other = 0
        for i in 0..<(Self.size * Self.size) {
            let v = Double(pixels[4 * i])
            if v == 255 { continue }
            if abs(v - single) <= 2 {
                shadowed += 1
                worst = max(worst, abs(v - single))
                XCTAssertEqual(Double(pixels[4 * i + 1]), v, accuracy: 0.5)
                XCTAssertEqual(pixels[4 * i + 3], 255, "alpha stays opaque")
            } else {
                other += 1
            }
        }
        print("PlanarShadowRendererTests: overlap, \(shadowed) shadow px within \(worst)/255 of \(single), \(other) other")
        XCTAssertGreaterThan(shadowed, 50)
        XCTAssertEqual(other, 0, "every pixel is white or the single-shadow value, none darker")
    }

    // MARK: Refusals

    func testParallelLightAndFailedTargetThrowAndDrawNothing() throws {
        let parallel = try ShadowLight.directional(towards: Vec3(1, 0, 0))
        let (p1, c1, e1) = try draw(Mesh.cube(), model: Self.cubeModel(), light: parallel)
        XCTAssertEqual(e1 as? ShadowError, .parallelLight)
        XCTAssertEqual(c1, 0)
        XCTAssertTrue(p1.allSatisfy { $0 == 255 }, "nothing drawn")
        let (p2, c2, e2) = try draw(Mesh.cube(), model: Self.cubeModel(), viewport: (0, 0))
        XCTAssertNotNil(e2 as? ResourceError, "an impossible coverage target throws")
        XCTAssertEqual(c2, 0)
        XCTAssertTrue(p2.allSatisfy { $0 == 255 }, "nothing drawn; the previous framebuffer stays bound")
    }

    // MARK: Lifetime

    func testReleaseAndDestroyLeaveNoLiveObjects() throws {
        let scene = ShadowScene(mesh: Mesh.cube(), model: Self.cubeModel())
        let h = try RenderHost(scene: scene)
        host = h
        h.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        h.view.layoutIfNeeded()
        XCTAssertTrue(h.renderOneFrame(present: false))
        let live = h.resources.stats.liveCount.values.reduce(0, +)
        XCTAssertTrue(h.renderOneFrame(present: false))
        XCTAssertEqual(h.resources.stats.liveCount.values.reduce(0, +), live, "the pooled coverage target is reused every frame")
        XCTAssertEqual(scene.renderer?.drawCallCount, 4)
        scene.renderer?.release()
        h.resources.trimPools()
        XCTAssertEqual(h.resources.stats.liveCount.values.reduce(0, +), live - 5,
                       "two buffers and two programs released, the coverage target freed with the pool")
        h.destroy()
        XCTAssertEqual(h.resources.stats.leaked, 0)
    }

    func testContextRecreationGivesTheSamePicture() throws {
        let scene = ShadowScene(mesh: Mesh.cube(), model: Self.cubeModel())
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
        XCTAssertTrue(stride(from: 0, to: before.count, by: 4).contains { before[$0] < 200 }, "the shadow is drawn")
        XCTAssertNil(scene.error)
        h.destroy()
        XCTAssertEqual(h.resources.stats.leaked, 0)
    }
}

/// Clears the window framebuffer to white and draws one shadow each frame with one renderer kept for the host's
/// lifetime; teardown releases its GPU objects (the next setup keeps the object, so its draw rebuilds them).
@MainActor
private final class ShadowScene: RenderScene {
    let mesh: Mesh, model: Mat4
    private(set) var renderer: PlanarShadowRenderer?
    private(set) var error: Error?

    init(mesh: Mesh, model: Mat4) { self.mesh = mesh; self.model = model }

    func setup(_ c: RenderContext) throws {
        if renderer == nil { renderer = try PlanarShadowRenderer(mesh: mesh, registry: c.resources) }
    }
    func resize(_ c: RenderContext) {}
    func render(_ c: RenderContext, frame: FrameInfo) throws {
        vcglClearColor(1, 1, 1, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        do {
            try renderer?.draw(model: model, light: try PlanarShadowRendererTests.light(),
                               plane: try PlanarShadowRendererTests.ground(), view: PlanarShadowRendererTests.view,
                               projection: PlanarShadowRendererTests.projection,
                               viewport: (c.pixelWidth, c.pixelHeight))
        } catch { self.error = error }
    }
    func teardown(_ c: RenderContext) { renderer?.release() }
}
