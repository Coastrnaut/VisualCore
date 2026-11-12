// ParticleBlendTests — feature 035 A04-P03 T-A04-303 (G-BLENDTRAIL; FR-A04-301; contract C3). Simulator pixel tests:
// additive blending sums overlapping particles; the default keeps the premultiplied "over" result.
import VisualCoreMath
import VisualCoreScenes
import VisualCoreSimulation
import XCTest
@testable import VisualCoreRendering

@MainActor
final class ParticleBlendTests: XCTestCase {
    private let metrics = ViewMetrics(size: Vec2(32, 32), scale: 1)
    private var host: RenderHost?
    /// Two half-transparent red particles on top of each other at the center.
    private let pair = [ParticleInstance(position: .zero, size: 12, color: Vec4(1, 0, 0, 0.5)),
                        ParticleInstance(position: .zero, size: 12, color: Vec4(1, 0, 0, 0.5))]

    private func center(_ blend: ParticleBlend?) throws -> SIMD4<Int> {
        let particles = pair
        let p = try DrawHarness.pixels(keep: &host) { ctx in
            let r = try ParticleRenderer(registry: ctx.resources)
            if let blend {
                try r.draw(particles, camera: Camera2D(), metrics: self.metrics, blend: blend)
            } else {
                try r.draw(particles, camera: Camera2D(), metrics: self.metrics)
            }
            r.release()
        }
        return DrawHarness.px(p, 32, 16, 16)
    }

    func testAdditiveSumsOverlappingLight() throws {
        let c = try center(.additive)
        XCTAssertGreaterThanOrEqual(c.x, 254, "0.5 + 0.5 red")
        XCTAssertEqual(c.y, 0); XCTAssertEqual(c.z, 0)
    }

    func testNormalIsTheDefaultOverComposite() throws {
        let normal = try center(.normal), implicit = try center(nil)
        XCTAssertEqual(normal, implicit, "the default is .normal")
        XCTAssertEqual(Double(normal.x), 191, accuracy: 2, "0.5 then 0.5 over: 0.75 red")
    }

    func testAdditiveSaturatesAtWhite() throws {
        let many = Array(repeating: ParticleInstance(position: .zero, size: 12, color: Vec4(0.6, 0.6, 0.6, 1)), count: 5)
        let p = try DrawHarness.pixels(keep: &host) { ctx in
            let r = try ParticleRenderer(registry: ctx.resources)
            try r.draw(many, camera: Camera2D(), metrics: self.metrics, blend: .additive)
            r.release()
        }
        XCTAssertEqual(DrawHarness.px(p, 32, 16, 16), SIMD4(255, 255, 255, 255))
        XCTAssertEqual(ParticleBlend.allCases, [.normal, .additive])
    }
}
