// MeshCompilerRuntimeTests — feature 205 (R02-F05) T-R02F05-012 (FR-R02F05-051, FR-R02F05-060; SC-R02F05-003). On the
// simulator: one description per shape gives the digest committed from the host run of 2026-11-13 (byte-for-byte
// determinism across macOS and both iOS simulator runtimes), and a compiled tube is drawn by the existing
// `MeshRenderer` through the real OpenGL ES → ANGLE → Metal path, with every GPU object released afterwards.
import CVisualCoreGL
import Foundation
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

@MainActor
final class MeshCompilerRuntimeTests: XCTestCase {
    private var host: RenderHost?

    private static func semicircle() -> [Vec2] {
        (0...8).map { k in let a = -Double.pi / 2 + Double.pi * Double(k) / 8; return Vec2(cos(a), sin(a)) }
    }

    private static func helix() -> [Vec3] {
        (0..<20).map { i in let t = Double(i) * 0.4; return Vec3(cos(t), sin(t), 0.1 * t) }
    }

    func testShapeDigestsEqualTheHostDigests() throws {
        let cases: [(String, Mesh, String)] = [
            ("surface", try Mesh.surface(columns: 12, rows: 8, closedU: true, closedV: true) { u, v in
                Vec3((2 + cos(2 * .pi * v)) * cos(2 * .pi * u), (2 + cos(2 * .pi * v)) * sin(2 * .pi * u), sin(2 * .pi * v))
            }, "a73056938c61fb88fa459017fa18da79d4646400f566cd2b7d2c8a7c45e5414b"),
            ("revolution", try Mesh.revolution(profile: Self.semicircle(), segments: 16),
             "abc0e0ecb84cd57901241b3d1eae22ee82ff371af9028902938e67454194dcb9"),
            ("extrusion", try Mesh.extrusion(outline: [Vec2(0, 0), Vec2(2, 0), Vec2(2, 1), Vec2(1, 2), Vec2(0, 1)],
                                             depth: 0.5, caps: true),
             "b2526d8f86b8c03809a506e823b7af931537e1694fe0a31ed8f60d2c8ab73a5b"),
            ("tube", try Mesh.tube(path: Self.helix(), radius: 0.2, sides: 10, caps: true, closed: false),
             "ed3c6c9a3dce1025b6863d2408f4428be8b1bc9745c8e9a479af4db238330339"),
            ("bevelledBox", try Mesh.bevelledBox(size: Vec3(2, 1, 1), radius: 0.2, segments: 4),
             "8aee58f90736cae89ac5d0f44784444fca85b2daf421b08c29c90d312f8ef066"),
        ]
        for (name, mesh, digest) in cases {
            XCTAssertEqual(mesh.digest, digest, name)
            XCTAssertTrue(mesh.validate(requireClosed: true).isValid, name)
        }
    }

    func testACompiledTubeIsDrawnByTheMeshRenderer() throws {
        let size = 64
        let tube = try Mesh.tube(path: [Vec3(-0.8, 0, 0), Vec3(0, 0.3, 0), Vec3(0.8, 0, 0)], radius: 0.25, sides: 16,
                                 caps: true, closed: false)
        var error = GLenum(1)
        let p = try DrawHarness.pixels(size: size, keep: &host) { ctx in
            let r = try MeshRenderer(mesh: tube, registry: ctx.resources)
            r.lightDirection = Vec3(0, 0, 1)
            try r.draw(camera: OrbitCamera(distance: 3), aspect: 1, color: Vec4(1, 1, 1, 1))
            error = vcglGetError()
            r.release()
        }
        XCTAssertEqual(error, GLenum(GL_NO_ERROR))
        var lit = 0
        for y in 0..<size { for x in 0..<size where DrawHarness.px(p, size, x, y).x > 0 { lit += 1 } }
        XCTAssertGreaterThanOrEqual(lit, size * size / 100, "at least 1% of the target is covered (\(lit) px)")
        XCTAssertGreaterThan(DrawHarness.px(p, size, size / 2, size / 2 + 3).x, 0, "the tube's middle is drawn")
        let h = try XCTUnwrap(host)
        h.destroy()
        XCTAssertEqual(h.resources.stats.leaked, 0)
    }
}
