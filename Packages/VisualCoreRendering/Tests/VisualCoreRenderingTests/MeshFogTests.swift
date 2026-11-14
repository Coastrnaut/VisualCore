// MeshFogTests — feature 055 (A07-P02) T-A07-203 (FR-A07-202; SC-A07-202; gap G-RAILDRAW): MeshFog refuses invalid
// ranges; a mesh beyond the fog end takes the fog colour (within 2%), a mesh before the fog start equals the unfogged
// render, the mix is linear in eye depth, and the orbit-camera methods of MeshRenderer and DepthMeshPass give pixels
// identical to the free-camera overloads with the orbit camera's matrices and nil fog.
import CVisualCoreGL
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

@MainActor
final class MeshFogTests: XCTestCase {
    private var host: RenderHost?
    /// Eye on +z at distance 4: the cube's front face (z = 0.5) lies at eye depth 3.5.
    private static let camera = OrbitCamera(distance: 4)
    private static let fogColor = Vec4(0.2, 0.4, 0.8, 1)
    private static let size = 64

    override func tearDown() {
        host?.destroy()
        host = nil
    }

    /// Pixels of a lit red cube at the origin drawn through the overload with `fog` (or the orbit method when `orbit`).
    private func cube(fog: MeshFog?, orbit: Bool = false, camera: OrbitCamera? = nil, mesh: Mesh? = nil) throws -> [UInt8] {
        let camera = camera ?? Self.camera, mesh = mesh ?? .cube()
        var error = GLenum(1)
        let pixels = try DrawHarness.pixels(size: Self.size, keep: &host) { ctx in
            let r = try MeshRenderer(mesh: mesh, registry: ctx.resources)
            r.lightDirection = Vec3(0, 0, 1)
            if orbit {
                try r.draw(camera: camera, aspect: 1, color: Vec4(1, 0, 0, 1))
            } else {
                try r.draw(model: .identity, view: camera.view(), projection: camera.projection(aspect: 1),
                           color: Vec4(1, 0, 0, 1), fog: fog)
            }
            error = vcglGetError()
            r.release()
        }
        XCTAssertEqual(error, GLenum(GL_NO_ERROR))
        return pixels
    }

    private static func assertNear(_ p: SIMD4<Int>, _ expected: Vec4, tolerance: Int, _ label: String,
                                   file: StaticString = #filePath, line: UInt = #line) {
        let e = SIMD4<Int>(Int((expected.x * 255).rounded()), Int((expected.y * 255).rounded()),
                           Int((expected.z * 255).rounded()), Int((expected.w * 255).rounded()))
        for c in 0..<4 {
            XCTAssertLessThanOrEqual(abs(p[c] - e[c]), tolerance, "\(label) channel \(c): \(p) vs \(e)", file: file, line: line)
        }
    }

    func testInitRefusesInvalidRanges() {
        let c = Vec4(0, 0, 0, 1)
        XCTAssertNil(MeshFog(start: 10, end: 10, color: c), "end == start")
        XCTAssertNil(MeshFog(start: 10, end: 5, color: c), "end < start")
        XCTAssertNil(MeshFog(start: -1, end: 5, color: c), "negative start")
        XCTAssertNil(MeshFog(start: .nan, end: 5, color: c))
        XCTAssertNil(MeshFog(start: 0, end: .infinity, color: c))
        XCTAssertNil(MeshFog(start: 0, end: 5, color: Vec4(.nan, 0, 0, 1)))
        let fog = MeshFog(start: 40, end: 110, color: c)
        XCTAssertEqual(fog?.start, 40)
        XCTAssertEqual(fog?.end, 110)
        XCTAssertEqual(fog?.color, c)
        XCTAssertEqual(fog, MeshFog(start: 40, end: 110, color: c))
    }

    func testFarMeshTakesTheFogColour() throws {
        let fog = try XCTUnwrap(MeshFog(start: 0.5, end: 1, color: Self.fogColor))
        let p = try cube(fog: fog)
        let half = Self.size / 2
        for (x, y) in [(half, half), (half - 4, half + 3), (half + 4, half - 3)] {
            Self.assertNear(DrawHarness.px(p, Self.size, x, y), Self.fogColor, tolerance: 5, "fogged (\(x), \(y))")
        }
        XCTAssertEqual(DrawHarness.px(p, Self.size, 2, 2), SIMD4(0, 0, 0, 255), "background is not drawn")
    }

    func testNearMeshIsUnfogged() throws {
        let unfogged = try cube(fog: nil)
        let fog = try XCTUnwrap(MeshFog(start: 10, end: 20, color: Self.fogColor))
        let fogged = try cube(fog: fog)
        XCTAssertEqual(fogged, unfogged, "fog starting beyond the mesh leaves every pixel unchanged")
        let half = Self.size / 2
        XCTAssertEqual(DrawHarness.px(unfogged, Self.size, half, half).x, 255, accuracy: 1, "lit red front face")
    }

    func testFogIsLinearInEyeDepth() throws {
        // Front face at depth 3.5, fog from 3 to 4: half way between red (1, 0, 0, 1) and the fog colour.
        let fog = try XCTUnwrap(MeshFog(start: 3, end: 4, color: Vec4(0, 0, 1, 1)))
        let p = try cube(fog: fog)
        let half = Self.size / 2
        Self.assertNear(DrawHarness.px(p, Self.size, half, half), Vec4(0.5, 0, 0.5, 1), tolerance: 4, "mid fog")
    }

    func testOrbitMethodEqualsOverloadWithOrbitMatrices() throws {
        let camera = OrbitCamera(distance: 3.2, yaw: 0.7, pitch: 0.4)
        let sphere = Mesh.uvSphere(segments: 32, rings: 16)
        let orbit = try cube(fog: nil, orbit: true, camera: camera, mesh: sphere)
        let overload = try cube(fog: nil, camera: camera, mesh: sphere)
        XCTAssertEqual(orbit.count, Self.size * Self.size * 4)
        XCTAssertEqual(Self.fnv1a(orbit), Self.fnv1a(overload), "identical pixel hash")
        XCTAssertEqual(orbit, overload)
        XCTAssertGreaterThan(orbit.filter { $0 > 0 && $0 < 255 }.count, 100, "the sphere is drawn")
    }

    func testDepthMeshPassOverloadMatchesOrbitAndFogs() throws {
        let size = 48
        func pass(_ body: @escaping (DepthMeshPass, [DepthMeshPass.Item], RenderContext) throws -> Void) throws -> [UInt8] {
            var out: [UInt8] = []
            _ = try DrawHarness.pixels(size: 8, keep: &host) { ctx in
                let colour = try ctx.resources.makeRenderTarget(width: size, height: size, label: "fog pass test")
                let r = try MeshRenderer(mesh: .cube(), registry: ctx.resources)
                r.lightDirection = Vec3(0, 0, 1)
                let p = DepthMeshPass(registry: ctx.resources)
                p.clearColor = Vec4(0, 0, 0, 1)
                let items = [DepthMeshPass.Item(renderer: r, color: Vec4(1, 0, 0, 1))]
                try body(p, items, ctx.redirected(to: colour.handle.name, width: size, height: size))
                out = colour.readPixels()
                p.release(); r.release(); ctx.resources.release(colour)
            }
            return out
        }
        let camera = OrbitCamera(distance: 4, yaw: 0.3, pitch: 0.2)
        let orbit = try pass { p, items, ctx in try p.draw(items, camera: camera, context: ctx) }
        let overload = try pass { p, items, ctx in
            try p.draw(items, view: camera.view(), projection: camera.projection(aspect: 1), fog: nil, context: ctx)
        }
        XCTAssertEqual(Self.fnv1a(orbit), Self.fnv1a(overload), "identical pixel hash through the pass")
        let fog = try XCTUnwrap(MeshFog(start: 0.5, end: 1, color: Self.fogColor))
        let fogged = try pass { p, items, ctx in
            try p.draw(items, view: camera.view(), projection: camera.projection(aspect: 1), fog: fog, context: ctx)
        }
        Self.assertNear(DrawHarness.px(fogged, size, size / 2, size / 2), Self.fogColor, tolerance: 5, "pass fogged")
        XCTAssertEqual(DrawHarness.px(fogged, size, 1, 1), SIMD4(0, 0, 0, 255), "clear colour unchanged")
    }

    /// FNV-1a 64-bit hash of the bytes (stable across runs, unlike Hasher).
    private static func fnv1a(_ bytes: [UInt8]) -> UInt64 {
        var h: UInt64 = 0xcbf2_9ce4_8422_2325
        for b in bytes { h = (h ^ UInt64(b)) &* 0x0000_0100_0000_01b3 }
        return h
    }
}
