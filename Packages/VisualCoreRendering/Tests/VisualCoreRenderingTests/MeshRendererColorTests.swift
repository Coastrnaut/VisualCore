// MeshRendererColorTests — feature 090 (A12-P02) T-A12-203 (FR-A12-201; SC-A12-204; research D1; gap G-MATERIALS):
// the per-vertex colour stream of `MeshRenderer.init(mesh:colors:registry:)`. A plane split into two colour halves
// shows each colour under a head-on light; `colors: nil` is pixel-identical to the plain initializer; a wrong count,
// NaN and 1.5 are refused; colours survive a context recreation and show through DepthMeshPass.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

/// Fixtures shared by the colour tests.
@MainActor
enum ColorPlane {
    /// Left half colour (x < 0).
    static let left = Vec4(1, 0.5, 0, 1)
    /// Right half colour (x > 0).
    static let right = Vec4(0, 0.25, 1, 1)
    /// Camera at +z: the 1 × 1 plane spans about ±0.58 NDC at distance 1.5.
    static let camera = OrbitCamera(distance: 1.5)

    /// Two separate quads (x −0.5…0 and 0…0.5) facing +z, so the halves do not blend.
    static func mesh() -> Mesh {
        var m = Mesh.plane()
        let base = m
        m.positions = base.positions.map { Vec3(($0.x + 0.5) * 0.5 - 0.5, $0.y, 0) }
            + base.positions.map { Vec3(($0.x + 0.5) * 0.5, $0.y, 0) }
        m.normals = base.normals + base.normals
        m.uvs = base.uvs + base.uvs
        m.indices = base.indices + base.indices.map { $0 + UInt32(base.positions.count) }
        return m
    }

    /// One colour per vertex: the first quad left, the second right.
    static func colors(for mesh: Mesh) -> [Vec4] {
        let half = mesh.positions.count / 2
        return Array(repeating: left, count: half) + Array(repeating: right, count: mesh.positions.count - half)
    }

    /// Asserts every channel of `p` is within ±8 of `expected` × 255.
    static func assertColor(_ p: SIMD4<Int>, _ expected: Vec4, _ label: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        let e = [expected.x, expected.y, expected.z, expected.w]
        for c in 0..<4 {
            XCTAssertLessThanOrEqual(abs(p[c] - Int((e[c] * 255).rounded())), 8, "\(label) channel \(c): \(p)",
                                     file: file, line: line)
        }
    }
}

/// A scene drawing the two-colour plane directly or through a DepthMeshPass.
@MainActor
private final class ColorPlaneScene: RenderScene {
    let throughPass: Bool
    private var renderer: MeshRenderer?
    private var pass: DepthMeshPass?
    init(throughPass: Bool) { self.throughPass = throughPass }

    func setup(_ c: RenderContext) throws {
        let mesh = ColorPlane.mesh()
        let r = try MeshRenderer(mesh: mesh, colors: ColorPlane.colors(for: mesh), registry: c.resources)
        r.lightDirection = Vec3(0, 0, 1)
        renderer = r
        if throughPass { pass = DepthMeshPass(registry: c.resources) }
    }
    func resize(_ c: RenderContext) {}
    func render(_ c: RenderContext, frame: FrameInfo) throws {
        guard let renderer else { return }
        let aspect = Double(c.pixelWidth) / Double(max(1, c.pixelHeight))
        if let pass {
            try pass.draw([.init(renderer: renderer, color: Vec4(1, 1, 1, 1))], camera: ColorPlane.camera, context: c)
        } else {
            vcglClearColor(0, 0, 0, 1); vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            try renderer.draw(camera: ColorPlane.camera, aspect: aspect, color: Vec4(1, 1, 1, 1))
        }
    }
    func teardown(_ c: RenderContext) {
        pass?.release(); renderer?.release()
        pass = nil; renderer = nil
    }
}

@MainActor
final class MeshRendererColorTests: XCTestCase {
    private var host: RenderHost?
    private var hosts: [RenderHost] = []

    override func tearDown() {
        for h in hosts { h.destroy() }
        hosts.removeAll()
        host = nil
    }

    private func makeHost(_ scene: RenderScene) throws -> RenderHost {
        let h = try RenderHost(scene: scene)
        h.view.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        h.view.layoutIfNeeded()
        hosts.append(h)
        return h
    }

    /// Pixel at fractional position (fx, fy) of a bottom-up host read-back.
    private static func hostPixel(_ host: RenderHost, _ fx: Double, _ fy: Double) -> SIMD4<Int> {
        let w = host.pixelSize.width, h = host.pixelSize.height
        let p = host.readPixels()
        let i = (Int(fy * Double(h)) * w + Int(fx * Double(w))) * 4
        return SIMD4(Int(p[i]), Int(p[i + 1]), Int(p[i + 2]), Int(p[i + 3]))
    }

    func testTwoColourPlaneShowsEachColour() throws {
        var error = GLenum(1)
        let p = try DrawHarness.pixels(size: 64, keep: &host) { ctx in
            let mesh = ColorPlane.mesh()
            let r = try MeshRenderer(mesh: mesh, colors: ColorPlane.colors(for: mesh), registry: ctx.resources)
            r.lightDirection = Vec3(0, 0, 1)
            try r.draw(camera: ColorPlane.camera, aspect: 1, color: Vec4(1, 1, 1, 1))
            error = vcglGetError()
            r.release()
        }
        XCTAssertEqual(error, GLenum(GL_NO_ERROR))
        for y in [24, 32, 40] {
            ColorPlane.assertColor(DrawHarness.px(p, 64, 22, y), ColorPlane.left, "left half y \(y)")
            ColorPlane.assertColor(DrawHarness.px(p, 64, 42, y), ColorPlane.right, "right half y \(y)")
        }
        XCTAssertEqual(DrawHarness.px(p, 64, 2, 2), SIMD4(0, 0, 0, 255), "background outside")
    }

    func testDrawColourMultipliesTheStream() throws {
        let p = try DrawHarness.pixels(size: 64, keep: &host) { ctx in
            let mesh = ColorPlane.mesh()
            let r = try MeshRenderer(mesh: mesh, colors: ColorPlane.colors(for: mesh), registry: ctx.resources)
            r.lightDirection = Vec3(0, 0, 1)
            try r.draw(camera: ColorPlane.camera, aspect: 1, color: Vec4(0.5, 1, 1, 1))
            r.release()
        }
        ColorPlane.assertColor(DrawHarness.px(p, 64, 22, 32), Vec4(0.5, 0.5, 0, 1), "left × draw colour")
        ColorPlane.assertColor(DrawHarness.px(p, 64, 42, 32), ColorPlane.right, "right × draw colour")
    }

    func testNilColoursArePixelIdenticalToThePlainInitializer() throws {
        func render(_ make: @escaping (RenderContext) throws -> MeshRenderer) throws -> [UInt8] {
            var keep: RenderHost?
            let p = try DrawHarness.pixels(size: 64, keep: &keep) { ctx in
                let r = try make(ctx)
                r.lightDirection = Vec3(0.3, 0.5, 1).normalized
                r.ambient = 0.2
                try r.draw(camera: OrbitCamera(distance: 3, yaw: 0.4, pitch: 0.3), aspect: 1, color: Vec4(0.8, 0.6, 0.3, 1))
                r.release()
            }
            keep?.destroy()
            return p
        }
        let plain = try render { try MeshRenderer(mesh: .uvSphere(segments: 32, rings: 16), registry: $0.resources) }
        let nilColors = try render {
            try MeshRenderer(mesh: .uvSphere(segments: 32, rings: 16), colors: nil, registry: $0.resources)
        }
        XCTAssertEqual(plain.count, 64 * 64 * 4)
        XCTAssertTrue(plain == nilColors, "colors: nil must draw exactly the plain initializer's pixels")
        XCTAssertGreaterThan(plain.max() ?? 0, 100, "the sphere is drawn")
    }

    func testNilColoursAfterAColouredDrawStayUnchanged() throws {
        // A coloured renderer drawn first must not leak its stream into a following plain draw.
        func render(colouredFirst: Bool) throws -> [UInt8] {
            var keep: RenderHost?
            let p = try DrawHarness.pixels(size: 32, keep: &keep) { ctx in
                if colouredFirst {
                    let mesh = ColorPlane.mesh()
                    let c = try MeshRenderer(mesh: mesh, colors: ColorPlane.colors(for: mesh), registry: ctx.resources)
                    try c.draw(camera: ColorPlane.camera, aspect: 1, color: Vec4(1, 1, 1, 1))
                    c.release()
                    vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
                }
                let r = try MeshRenderer(mesh: .cube(), registry: ctx.resources)
                r.lightDirection = Vec3(0, 0, 1)
                try r.draw(camera: OrbitCamera(distance: 3), aspect: 1, color: Vec4(0.2, 0.9, 0.4, 1))
                r.release()
            }
            keep?.destroy()
            return p
        }
        XCTAssertTrue(try render(colouredFirst: false) == render(colouredFirst: true))
    }

    func testInvalidColoursAreRefused() throws {
        var outcomes: [MeshError?] = []
        var keep: RenderHost?
        _ = try DrawHarness.pixels(size: 8, keep: &keep) { ctx in
            let mesh = ColorPlane.mesh()
            let good = ColorPlane.colors(for: mesh)
            var nan = good; nan[3] = Vec4(1, .nan, 0, 1)
            var over = good; over[5] = Vec4(1.5, 0, 0, 1)
            var negative = good; negative[0] = Vec4(0, 0, 0, -0.1)
            for colors in [Array(good.dropLast()), good + [good[0]], nan, over, negative, [Vec4(1, 1, .infinity, 1)]] {
                do {
                    let r = try MeshRenderer(mesh: mesh, colors: colors, registry: ctx.resources)
                    r.release()
                    outcomes.append(nil)
                } catch let e as MeshError {
                    outcomes.append(e)
                }
            }
        }
        keep?.destroy()
        XCTAssertEqual(outcomes.count, 6)
        for (i, outcome) in outcomes.enumerated() {
            guard case .invalidInput = outcome else { XCTFail("case \(i) not refused: \(String(describing: outcome))"); continue }
        }
    }

    func testColoursSurviveAContextRecreation() throws {
        let host = try makeHost(ColorPlaneScene(throughPass: false))
        XCTAssertTrue(host.renderOneFrame(present: false))
        ColorPlane.assertColor(Self.hostPixel(host, 0.35, 0.5), ColorPlane.left, "left before")
        ColorPlane.assertColor(Self.hostPixel(host, 0.65, 0.5), ColorPlane.right, "right before")
        let live = host.resources.stats.liveCount
        host.recreateContext()
        XCTAssertTrue(host.renderOneFrame(present: false))
        ColorPlane.assertColor(Self.hostPixel(host, 0.35, 0.5), ColorPlane.left, "left after recreation")
        ColorPlane.assertColor(Self.hostPixel(host, 0.65, 0.5), ColorPlane.right, "right after recreation")
        XCTAssertEqual(host.resources.stats.liveCount, live, "same live resources after recreation")
        host.destroy()
        hosts.removeAll()
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }

    func testColouredRendererThroughDepthMeshPass() throws {
        let host = try makeHost(ColorPlaneScene(throughPass: true))
        XCTAssertTrue(host.renderOneFrame(present: false))
        ColorPlane.assertColor(Self.hostPixel(host, 0.35, 0.5), ColorPlane.left, "left through the pass")
        ColorPlane.assertColor(Self.hostPixel(host, 0.65, 0.5), ColorPlane.right, "right through the pass")
        XCTAssertEqual(vcglGetError(), GLenum(GL_NO_ERROR))
    }
}
