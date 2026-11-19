// BeamRendererTests — feature 209 (R02-F09) T-R02F09-004 (SC-R02F09-002, SC-R02F09-003; clarifications Q2–Q5). On the
// simulator through OpenGL ES → ANGLE → Metal.
//
// Expected pixels (the method): every pixel of a 64 × 64 target is compared with the CPU reference. The pixel centre
// (x + ½, y + ½) gives NDC (2(x + ½)/64 − 1, 2(y + ½)/64 − 1) and, through the symmetric perspective with
// f = 1 / tan(fovY / 2), the view-space ray direction (ndc.x / f, ndc.y / f, −1) from the eye at the origin. The beam's end
// points are taken to view space, M is their midpoint, e = −M/|M| the unit vector toward the eye, Π the plane through M
// with normal e, and A', B' the end points projected orthogonally onto Π (the strip of clarification Q2). The ray is
// intersected with Π (t = (M·e) / (dir·e), P = dir·t) and the expected premultiplied colour over opaque black is
// colour × `BeamProfile.coverage(point: P, a: A', b: B', width: w)`; each RGB channel must be within 2/255 of it.
// Cases: a beam lying in Π (its cross-section), a zero-length point, a diagonal beam seen through a rotated camera,
// an oblique beam (keeps its full width), an end-on beam (a round point). Further: zero width, non-finite values and the
// limit are refused with nothing drawn; scrambled premultiplied beams give the sorted picture, equal to one-at-a-time
// back-to-front draws; additive beams are order-free; one draw call; the previous GL state is restored; 100 frames
// keep the live counts constant (T-R02F09-012); a context recreation gives the same picture. Errors are captured
// inside the GL closure because `RenderHost` reports scene errors itself.
import CVisualCoreGL
import Foundation
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

@MainActor
final class BeamRendererTests: XCTestCase {
    static let size = 64
    /// Focal factor 1 / tan(fovY / 2): at view depth 5, one world unit is 16 pixels of the 64-pixel target.
    static let f = 2.5
    static let projection = Mat4.perspective(fovY: 2 * atan(1 / f), aspect: 1, near: 0.1, far: 100)
    private var host: RenderHost?

    // MARK: CPU reference

    /// The expected premultiplied colour of pixel (x, y) (bottom-up) for `beam` alone over opaque black (method in the
    /// file header).
    static func expected(_ beam: BeamInstance, view: Mat4, x: Int, y: Int) -> Vec3 {
        let a = view.applyPoint(beam.a), b = view.applyPoint(beam.b)
        let m = (a + b) * 0.5
        let e = m.length > 0 ? -m.normalized : Vec3(0, 0, 1)
        let ap = a - e * (a - m).dot(e), bp = b - e * (b - m).dot(e)
        let nx = (Double(x) + 0.5) / Double(size) * 2 - 1, ny = (Double(y) + 0.5) / Double(size) * 2 - 1
        let dir = Vec3(nx / f, ny / f, -1)
        let p = dir * (m.dot(e) / dir.dot(e))
        let coverage = BeamProfile.coverage(point: p, a: ap, b: bp, width: beam.width)
        return beam.color.xyz * coverage
    }

    /// The largest RGB difference (in 1/255 steps) between `pixels` and the reference, and how many pixels the
    /// reference lights to at least half the centre colour.
    static func compare(_ pixels: [UInt8], _ beam: BeamInstance, view: Mat4) -> (maxError: Double, bright: Int) {
        var worst = 0.0, bright = 0
        guard pixels.count == size * size * 4 else { return (.infinity, 0) }
        for y in 0..<size {
            for x in 0..<size {
                let e = expected(beam, view: view, x: x, y: y) * 255
                let p = DrawHarness.px(pixels, size, x, y)
                worst = max(worst, abs(Double(p.x) - e.x), abs(Double(p.y) - e.y), abs(Double(p.z) - e.z))
                if e.x >= beam.color.x * 255 / 2, beam.color.x > 0 { bright += 1 }
            }
        }
        return (worst, bright)
    }

    /// The pixels of `beams` drawn once by a fresh renderer, and the renderer's draw-call count afterwards.
    private func draw(_ beams: [BeamInstance], view: Mat4 = .identity, blend: BeamBlend = .premultiplied) throws -> ([UInt8], Int) {
        var calls = -1, error = GLenum(1)
        let p = try DrawHarness.pixels(size: Self.size, keep: &host) { ctx in
            let r = try BeamRenderer(registry: ctx.resources)
            try r.draw(beams, view: view, projection: Self.projection, blend: blend)
            calls = r.drawCallCount
            error = vcglGetError()
            r.release()
        }
        XCTAssertEqual(error, GLenum(GL_NO_ERROR))
        return (p, calls)
    }

    // MARK: Shape

    func testCrossSectionAndPointMatchBeamProfile() throws {
        let rotated = Mat4.lookAt(eye: Vec3(0.4, 0.3, 0), target: Vec3(0, 0, -5), up: Vec3(0, 1, 0))
        let cases: [(String, BeamInstance, Mat4)] = [
            ("beam in the eye-facing plane", BeamInstance(a: Vec3(-1, 0, -5), b: Vec3(1, 0, -5), width: 1,
                                                  color: Vec4(0.9, 0.6, 0.3, 0.9)), .identity),
            ("zero-length point", BeamInstance(a: Vec3(0.3, -0.2, -5), b: Vec3(0.3, -0.2, -5), width: 1.2,
                                       color: Vec4(0.8, 0.8, 0.4, 0.8)), .identity),
            ("diagonal beam, rotated camera", BeamInstance(a: Vec3(-0.8, -0.6, -4.5), b: Vec3(0.9, 0.7, -5.8), width: 0.7,
                                                   color: Vec4(0.5, 0.9, 0.7, 1)), rotated),
        ]
        for (name, beam, view) in cases {
            let (pixels, calls) = try draw([beam], view: view)
            XCTAssertEqual(calls, 1, name)
            let (worst, bright) = Self.compare(pixels, beam, view: view)
            print("BeamRendererTests: \(name), max error \(worst)/255 over \(Self.size * Self.size) px")
            XCTAssertLessThanOrEqual(worst, 2, "\(name): every pixel within 2/255 of BeamProfile")
            XCTAssertGreaterThan(bright, 20, "\(name): the beam is visible (\(bright) bright px)")
        }
    }

    func testAnObliqueBeamKeepsItsFullWidth() throws {
        let color = Vec4(0.9, 0.6, 0.3, 0.9)
        let flat = BeamInstance(a: Vec3(-1, 0, -5), b: Vec3(1, 0, -5), width: 1, color: color)
        let oblique = BeamInstance(a: Vec3(-1, 0, -3.5), b: Vec3(1, 0, -6.5), width: 1, color: color)
        let (flatPixels, _) = try draw([flat])
        let (obliquePixels, _) = try draw([oblique])
        XCTAssertLessThanOrEqual(Self.compare(obliquePixels, oblique, view: .identity).maxError, 2)
        // Across the beam at the centre column: lit over the full width w = 1 (16 px at depth 5), as the flat beam.
        func litRows(_ p: [UInt8]) -> Int { (0..<Self.size).filter { DrawHarness.px(p, Self.size, 32, $0).x > 0 }.count }
        XCTAssertEqual(litRows(obliquePixels), 16, "full width: 16 px across")
        XCTAssertEqual(litRows(obliquePixels), litRows(flatPixels))
        XCTAssertLessThanOrEqual(DepthDrawHarness.maxDifference(obliquePixels, flatPixels), 2,
                                 "the oblique beam's cross-section equals the flat beam's")
    }

    func testAnEndOnBeamIsARoundPoint() throws {
        let color = Vec4(0.7, 0.9, 0.5, 0.9)
        let endOn = BeamInstance(a: Vec3(0, 0, -4), b: Vec3(0, 0, -6), width: 1, color: color)
        let point = BeamInstance(a: Vec3(0, 0, -5), b: Vec3(0, 0, -5), width: 1, color: color)
        let (p, calls) = try draw([endOn])
        XCTAssertEqual(calls, 1)
        let (worst, bright) = Self.compare(p, endOn, view: .identity)
        print("BeamRendererTests: end-on beam, max error \(worst)/255")
        XCTAssertLessThanOrEqual(worst, 2)
        XCTAssertGreaterThan(bright, 20)
        let (pointPixels, _) = try draw([point])
        XCTAssertLessThanOrEqual(DepthDrawHarness.maxDifference(p, pointPixels), 1, "end-on equals a point at the midpoint")
        for k in 0..<10 {   // the view centre is the corner between pixels 31 and 32: compare mirrored pixels
            let right = DrawHarness.px(p, 64, 32 + k, 32), up = DrawHarness.px(p, 64, 32, 32 + k)
            let left = DrawHarness.px(p, 64, 31 - k, 31), down = DrawHarness.px(p, 64, 31, 31 - k)
            for other in [up, left, down] {
                XCTAssertLessThanOrEqual(abs(right.x - other.x), 1, "round at radius \(k)")
            }
        }
        XCTAssertEqual(DrawHarness.px(p, 64, 32 + 9, 32).x, 0, "nothing beyond the radius (8 px)")
    }

    // MARK: Refusals

    func testZeroWidthNonFiniteAndTooManyAreRefused() throws {
        let good = BeamInstance(a: Vec3(-1, 0, -5), b: Vec3(1, 0, -5), width: 1, color: Vec4(1, 1, 1, 1))
        var nanA = good; nanA.a.y = .nan
        var infB = good; infB.b.z = -.infinity
        var nanWidth = good; nanWidth.width = .nan
        var infColor = good; infColor.color.w = .infinity
        var zero = good; zero.width = 0
        var negative = good; negative.width = -0.5
        let lists: [([BeamInstance], InstancingError)] = [
            ([good, zero], .badWidth(index: 1)), ([negative], .badWidth(index: 0)),
            ([good, good, nanA], .notFinite(index: 2)), ([infB], .notFinite(index: 0)),
            ([good, nanWidth], .notFinite(index: 1)), ([infColor], .notFinite(index: 0)),
            (Array(repeating: good, count: BeamRenderer.maxBeams + 1), .tooMany(count: 65_537, limit: 65_536)),
        ]
        XCTAssertEqual(BeamRenderer.maxBeams, 65_536)
        for (list, expected) in lists {
            XCTAssertThrowsError(try BeamRenderer.beamFloats(list)) { XCTAssertEqual($0 as? InstancingError, expected) }
        }
        var errors: [InstancingError?] = [], calls = -1
        let p = try DrawHarness.pixels(size: Self.size, keep: &host) { ctx in
            let r = try BeamRenderer(registry: ctx.resources)
            for (list, _) in lists {
                do {
                    try r.draw(list, view: .identity, projection: Self.projection)
                    errors.append(nil)
                } catch { errors.append(error as? InstancingError) }
            }
            try r.draw([], view: .identity, projection: Self.projection)
            calls = r.drawCallCount
            r.release()
        }
        XCTAssertEqual(errors, lists.map(\.1))
        XCTAssertEqual(calls, 0, "no draw call for a refused or empty list")
        XCTAssertTrue(stride(from: 0, to: p.count, by: 4).allSatisfy { p[$0] == 0 && p[$0 + 1] == 0 && p[$0 + 2] == 0 },
                      "nothing drawn")
    }

    // MARK: Blending and order

    /// Five crossing translucent beams at view depths −8 … −4, listed back to front.
    static func translucentSorted() -> [BeamInstance] {
        let colors = [Vec4(0.5, 0, 0, 0.5), Vec4(0, 0.42, 0, 0.6), Vec4(0, 0, 0.7, 0.7),
                      Vec4(0.3, 0.3, 0, 0.55), Vec4(0, 0.25, 0.25, 0.5)]
        return colors.enumerated().map { i, c in
            let angle = Double(i) * 0.6, z = -8 + Double(i)
            let d = Vec3(cos(angle), sin(angle), 0) * (0.25 * -z)
            return BeamInstance(a: Vec3(0, 0, z) - d, b: Vec3(0, 0, z) + d, width: 0.08 * -z, color: c)
        }
    }

    func testScrambledTranslucentBeamsEqualTheSortedPicture() throws {
        let sorted = Self.translucentSorted()
        XCTAssertEqual(try BeamRenderer.backToFront(sorted, view: .identity), [0, 1, 2, 3, 4])
        let tie = [BeamInstance(a: Vec3(-1, 0, -5), b: Vec3(1, 0, -5), width: 1, color: Vec4(0.5, 0, 0, 0.5)),
                   BeamInstance(a: Vec3(0, -1, -5), b: Vec3(0, 1, -5), width: 1, color: Vec4(0, 0, 0.5, 0.5))]
        XCTAssertEqual(try BeamRenderer.backToFront(tie, view: .identity), [0, 1], "equal depths keep submission order")
        let orders = [[0, 1, 2, 3, 4], [4, 3, 2, 1, 0], [2, 4, 0, 3, 1], [1, 3, 0, 4, 2]]
        var pictures: [[UInt8]] = []
        for order in orders {
            let (p, calls) = try draw(order.map { sorted[$0] })
            XCTAssertEqual(calls, 1)
            pictures.append(p)
        }
        for (order, picture) in zip(orders, pictures).dropFirst() {
            XCTAssertEqual(picture, pictures[0], "order \(order) gives the sorted picture")
        }
        let oneAtATime = try DrawHarness.pixels(size: Self.size, keep: &host) { ctx in
            let r = try BeamRenderer(registry: ctx.resources)
            for beam in sorted { try r.draw([beam], view: .identity, projection: Self.projection) }
            r.release()
        }
        XCTAssertLessThanOrEqual(DepthDrawHarness.maxDifference(pictures[0], oneAtATime), 1,
                                 "the sorted picture equals one-at-a-time back-to-front draws")
        let (tieAB, _) = try draw(tie), (tieBA, _) = try draw(Array(tie.reversed()))
        XCTAssertNotEqual(DrawHarness.px(tieAB, 64, 32, 32), DrawHarness.px(tieBA, 64, 32, 32),
                          "the crossing shows which tied beam was drawn last")
    }

    func testAdditiveBeamsAreOrderFree() throws {
        let sorted = Self.translucentSorted()
        let orders = [[0, 1, 2, 3, 4], [4, 3, 2, 1, 0], [2, 4, 0, 3, 1]]
        var pictures: [[UInt8]] = []
        for order in orders {
            let (p, calls) = try draw(order.map { sorted[$0] }, blend: .additive)
            XCTAssertEqual(calls, 1)
            pictures.append(p)
        }
        for picture in pictures.dropFirst() {
            XCTAssertLessThanOrEqual(DepthDrawHarness.maxDifference(picture, pictures[0]), 1, "additive: any order")
        }
        let (premultiplied, _) = try draw(sorted)
        XCTAssertNotEqual(pictures[0], premultiplied, "additive and premultiplied differ where beams cross")
    }

    // MARK: State and lifecycle

    func testPreviousGLStateIsRestored() throws {
        var flags: [GLboolean] = [], mask = GLboolean(GL_FALSE), factors: [GLint] = []
        _ = try DrawHarness.pixels(size: Self.size, keep: &host) { ctx in
            let r = try BeamRenderer(registry: ctx.resources)
            vcglDisable(GLenum(GL_BLEND))
            vcglDisable(GLenum(GL_DEPTH_TEST))
            vcglEnable(GLenum(GL_CULL_FACE))
            vcglDepthMask(GLboolean(GL_TRUE))
            vcglBlendFuncSeparate(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA), GLenum(GL_ONE), GLenum(GL_ZERO))
            try r.draw(Self.translucentSorted(), view: .identity, projection: Self.projection, blend: .additive)
            flags = [GL_BLEND, GL_DEPTH_TEST, GL_CULL_FACE].map { vcglIsEnabled(GLenum($0)) }
            vcglGetBooleanv(GLenum(GL_DEPTH_WRITEMASK), &mask)
            factors = [GL_BLEND_SRC_RGB, GL_BLEND_DST_RGB, GL_BLEND_SRC_ALPHA, GL_BLEND_DST_ALPHA].map { name in
                var v: GLint = 0
                vcglGetIntegerv(GLenum(name), &v)
                return v
            }
            vcglDisable(GLenum(GL_CULL_FACE))
            vcglBlendFunc(GLenum(GL_ONE), GLenum(GL_ZERO))
            r.release()
        }
        XCTAssertEqual(flags, [GLboolean(GL_FALSE), GLboolean(GL_FALSE), GLboolean(GL_TRUE)])
        XCTAssertEqual(mask, GLboolean(GL_TRUE))
        XCTAssertEqual(factors, [GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ZERO].map { GLint($0) })
    }

    /// T-R02F09-012 (SC-R02F09-004): 100 frames alternating 500 and 300 beams reuse one instance buffer and program.
    func testOneHundredFramesKeepLiveCountsConstant() throws {
        let scene = BeamScene()
        let all = (0..<500).map { i -> BeamInstance in
            let x = -1.5 + 3 * Double(i % 25) / 24, y = -1.5 + 3 * Double(i / 25) / 19
            return BeamInstance(a: Vec3(x - 0.05, y, -5), b: Vec3(x + 0.05, y, -5), width: 0.06,
                                color: Vec4(0.4, 0.3, 0.2, 0.5))
        }
        scene.perFrame = { frame in Array(all.prefix(frame % 2 == 0 ? 500 : 300)) }
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
        let scene = BeamScene()
        scene.beams = Self.translucentSorted()
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
        XCTAssertEqual(scene.renderer?.drawCallCount, 2)
        XCTAssertTrue(stride(from: 0, to: before.count, by: 4).contains { before[$0] > 0 || before[$0 + 2] > 0 },
                      "the beams are drawn")
        h.destroy()
        XCTAssertEqual(h.resources.stats.leaked, 0)
    }
}

/// Draws a fixed beam list into the window framebuffer each frame with one renderer kept for the host's lifetime;
/// teardown releases its GPU objects (the next setup keeps the object, so its draw rebuilds them).
@MainActor
private final class BeamScene: RenderScene {
    var beams: [BeamInstance] = []
    /// When set, the beams of frame `n` (counted from 0) instead of ``beams``.
    var perFrame: ((Int) -> [BeamInstance])?
    private(set) var renderer: BeamRenderer?
    private var frameIndex = 0

    func setup(_ c: RenderContext) throws {
        if renderer == nil { renderer = try BeamRenderer(registry: c.resources) }
    }
    func resize(_ c: RenderContext) {}
    func render(_ c: RenderContext, frame: FrameInfo) throws {
        vcglClearColor(0, 0, 0, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        try renderer?.draw(perFrame?(frameIndex) ?? beams, view: .identity, projection: BeamRendererTests.projection)
        frameIndex += 1
    }
    func teardown(_ c: RenderContext) { renderer?.release() }
}
