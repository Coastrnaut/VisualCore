// CurveBatchRuntimeTests — feature 208 (R02-F08) T-R02F08-006 (FR-R02F08-005, FR-R02F08-006; SC-R02F08-004;
// clarification Q5). On the simulator: 200 ribbons laid out on a 20 × 10 grid in clip space are merged into one mesh
// (`Mesh.merged`) and drawn by one `MeshRenderer` draw through the real OpenGL ES → ANGLE → Metal path; the pixel at
// every ribbon's centre is lit, the gaps between rows stay dark, and every GPU object is released afterwards. The view
// and projection are identity, so mesh coordinates are clip coordinates; the rows are symmetric about y = 0, so the
// check does not depend on the read-back's row order.
import CVisualCoreGL
import Foundation
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

@MainActor
final class CurveBatchRuntimeTests: XCTestCase {
    private var host: RenderHost?

    /// The ribbon centres: 20 columns and 10 rows, rows symmetric about y = 0.
    private static func centres() -> [Vec2] {
        var out: [Vec2] = []
        for row in 0..<10 {
            let y = -0.9 + 0.2 * Double(row)
            for column in 0..<20 { out.append(Vec2(-0.95 + 0.1 * Double(column), y)) }
        }
        return out
    }

    /// One short horizontal ribbon centred on `c`, lying in the clip plane and facing +z.
    private static func ribbon(at c: Vec2) throws -> Mesh {
        let curve = try CubicBezierChain(points: [Vec3(c.x - 0.03, c.y, 0), Vec3(c.x - 0.01, c.y, 0),
                                                  Vec3(c.x + 0.01, c.y, 0), Vec3(c.x + 0.03, c.y, 0)], closed: false)
        let samples = try CurveSampler.sample(curve, tolerance: 1e-4)
        return try Mesh.ribbon(samples, width: .constant(0.06), repeatLength: 0.06, initialNormal: Vec3(0, 0, 1))
    }

    func testTwoHundredMergedRibbonsDrawInOneCall() throws {
        let size = 200
        let parts = try Self.centres().map(Self.ribbon(at:))
        XCTAssertEqual(parts.count, 200)
        let merged = try Mesh.merged(parts)
        XCTAssertEqual(merged.positions.count, parts.reduce(0) { $0 + $1.positions.count })
        XCTAssertEqual(merged.indices.count, parts.reduce(0) { $0 + $1.indices.count })
        var error = GLenum(1)
        let p = try DrawHarness.pixels(size: size, keep: &host) { ctx in
            let r = try MeshRenderer(mesh: merged, registry: ctx.resources)
            r.lightDirection = Vec3(0, 0, 1)
            try r.draw(model: .identity, view: .identity, projection: .identity, color: Vec4(1, 1, 1, 1), fog: nil)
            error = vcglGetError()
            r.release()
        }
        XCTAssertEqual(error, GLenum(GL_NO_ERROR))
        func pixel(_ c: Vec2) -> SIMD4<Int> {
            let x = min(size - 1, max(0, Int(((c.x + 1) / 2 * Double(size)).rounded(.down))))
            let y = min(size - 1, max(0, Int(((c.y + 1) / 2 * Double(size)).rounded(.down))))
            return DrawHarness.px(p, size, x, y)
        }
        var unlit: [Vec2] = []
        for c in Self.centres() where pixel(c).x == 0 && pixel(c).y == 0 && pixel(c).z == 0 { unlit.append(c) }
        XCTAssertTrue(unlit.isEmpty, "every ribbon is drawn; unlit centres: \(unlit.prefix(5))")
        // Between two rows (0.1 clip units from each centre, the ribbons being 0.06 wide) nothing is drawn.
        let gap = pixel(Vec2(-0.95, 0))
        XCTAssertEqual(gap.x + gap.y + gap.z, 0, "the space between rows stays dark")
    }
}
