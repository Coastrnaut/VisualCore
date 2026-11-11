// PassPixelTests — feature 005, one test group per built-in pass (SC-F402). Added one effect per task.
import CVisualCoreGL
import VisualCoreEffectsGraph
import XCTest
@testable import VisualCoreEffects
@testable import VisualCoreRendering

@MainActor
final class PassPixelTests: XCTestCase {
    // MARK: copy (T-F406)

    func testCopyReproducesTheInputAndOrdersPasses() throws {
        var out: [UInt8] = []
        var order: [String] = []
        _ = try EffectHarness.run { ctx in
            let scene = try EffectHarness.solid(0.2, 0.4, 0.6, in: ctx)
            let renderer = try EffectRenderer(graph: EffectHarness.graph([
                EffectPassDescription(id: "A", type: "copy", inputs: ["input": "scene"], output: "a"),
                EffectPassDescription(id: "B", type: "copy", inputs: ["input": "a"], output: "b"),
            ], output: "b"), registry: ctx.resources)
            let result = try renderer.render(scene: scene, time: 0, delta: 1.0 / 60)
            out = result.readPixels()
            order = renderer.lastOrder
        }
        XCTAssertEqual(order, ["A", "B"])
        let p = EffectHarness.pixel(out, width: 16, x: 8, y: 8)
        XCTAssertEqual(p.x, 51, accuracy: 1); XCTAssertEqual(p.y, 102, accuracy: 1); XCTAssertEqual(p.z, 153, accuracy: 1)
    }

    func testInvalidGraphIsRejectedBeforeGPUWork() throws {
        var caught: Error?
        let host = try EffectHarness.run { ctx in
            do {
                _ = try EffectRenderer(graph: EffectHarness.graph([
                    EffectPassDescription(id: "A", type: "copy", inputs: ["input": "b"], output: "a"),
                    EffectPassDescription(id: "B", type: "copy", inputs: ["input": "a"], output: "b"),
                ], output: "b"), registry: ctx.resources)
            } catch { caught = error }
        }
        XCTAssertEqual(caught as? EffectGraphError, .cycle(["A", "B"]))
        XCTAssertEqual(host.resources.compileCount, 0)
    }

    // MARK: colorMatrix (T-F407)

    func testColorMatrixSwapsRedAndBlueAndAddsOffset() throws {
        var out: [UInt8] = []
        _ = try EffectHarness.run { ctx in
            let scene = try EffectHarness.solid(1, 0, 0, in: ctx)
            // Row-major: R' = B, G' = G, B' = R, A' = A; offset adds 0.2 to green.
            let swap: [Double] = [0, 0, 1, 0,  0, 1, 0, 0,  1, 0, 0, 0,  0, 0, 0, 1]
            let r = try EffectRenderer(graph: EffectHarness.graph([
                EffectPassDescription(id: "M", type: "colorMatrix", inputs: ["input": "scene"], output: "m",
                                      params: ["matrix": swap, "offset": [0, 0.2, 0, 0]]),
            ], output: "m"), registry: ctx.resources)
            out = try r.render(scene: scene, time: 0, delta: 0).readPixels()
        }
        let p = EffectHarness.pixel(out, width: 16, x: 3, y: 3)
        XCTAssertLessThanOrEqual(p.x, 1)
        XCTAssertEqual(p.y, 51, accuracy: 1)
        XCTAssertGreaterThanOrEqual(p.z, 254)
    }

    // MARK: blur (T-F408)

    func testBlurSpreadsABrightBlockLowersItsPeakAndKeepsEnergy() throws {
        var before: [UInt8] = [], after: [UInt8] = []
        _ = try EffectHarness.run { ctx in
            let scene = try EffectHarness.solid(0, 0, 0, size: 32, in: ctx)
            vcglEnable(GLenum(GL_SCISSOR_TEST)); vcglScissor(14, 14, 4, 4)
            vcglClearColor(1, 1, 1, 1); vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT)); vcglDisable(GLenum(GL_SCISSOR_TEST))
            before = scene.readPixels()
            let r = try EffectRenderer(graph: EffectHarness.graph([
                EffectPassDescription(id: "B", type: "blur", inputs: ["input": "scene"], output: "b", params: ["radius": [4]]),
            ], output: "b"), registry: ctx.resources)
            after = try r.render(scene: scene, time: 0, delta: 0).readPixels()
        }
        func red(_ p: [UInt8]) -> Int { stride(from: 0, to: p.count, by: 4).reduce(0) { $0 + Int(p[$1]) } }
        XCTAssertLessThan(EffectHarness.pixel(after, width: 32, x: 15, y: 15).x, 250, "peak drops")
        XCTAssertGreaterThan(EffectHarness.pixel(after, width: 32, x: 12, y: 15).x, 10, "spreads two texels out")
        XCTAssertEqual(EffectHarness.pixel(after, width: 32, x: 2, y: 2).x, 0, "far pixels stay black")
        XCTAssertEqual(Double(red(after)), Double(red(before)), accuracy: Double(red(before)) * 0.05, "energy kept within 5%")
    }

    // MARK: bloom (T-F409)

    func testBloomBrightensNearBrightAreasAndLeavesFarDarkPixels() throws {
        var before: [UInt8] = [], after: [UInt8] = []
        _ = try EffectHarness.run { ctx in
            let scene = try EffectHarness.solid(0.05, 0.05, 0.05, size: 32, in: ctx)
            vcglEnable(GLenum(GL_SCISSOR_TEST)); vcglScissor(14, 14, 4, 4)
            vcglClearColor(1, 1, 1, 1); vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT)); vcglDisable(GLenum(GL_SCISSOR_TEST))
            before = scene.readPixels()
            let r = try EffectRenderer(graph: EffectHarness.graph([
                EffectPassDescription(id: "G", type: "bloom", inputs: ["input": "scene"], output: "g",
                                      params: ["threshold": [0.7], "intensity": [1], "radius": [4]]),
            ], output: "g"), registry: ctx.resources)
            after = try r.render(scene: scene, time: 0, delta: 0).readPixels()
        }
        let nearBefore = EffectHarness.pixel(before, width: 32, x: 12, y: 15).x
        let nearAfter = EffectHarness.pixel(after, width: 32, x: 12, y: 15).x
        XCTAssertGreaterThan(nearAfter, nearBefore + 10, "glow spills next to the bright block")
        XCTAssertEqual(EffectHarness.pixel(after, width: 32, x: 2, y: 2).x, EffectHarness.pixel(before, width: 32, x: 2, y: 2).x, accuracy: 2,
                       "far dark pixels unchanged (below threshold)")
        XCTAssertGreaterThanOrEqual(EffectHarness.pixel(after, width: 32, x: 15, y: 15).x, 254)
    }

    // MARK: distort (T-F410)

    private func stripeDistort(strength: Double) throws -> (before: [UInt8], after: [UInt8]) {
        var before: [UInt8] = [], after: [UInt8] = []
        _ = try EffectHarness.run { ctx in
            let scene = try EffectHarness.solid(0, 0, 0, size: 32, in: ctx)
            vcglEnable(GLenum(GL_SCISSOR_TEST)); vcglScissor(15, 0, 2, 32)
            vcglClearColor(1, 1, 1, 1); vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT)); vcglDisable(GLenum(GL_SCISSOR_TEST))
            before = scene.readPixels()
            let r = try EffectRenderer(graph: EffectHarness.graph([
                EffectPassDescription(id: "D", type: "distort", inputs: ["input": "scene"], output: "d",
                                      params: ["strength": [strength], "frequency": [2], "speed": [0]]),
            ], output: "d"), registry: ctx.resources)
            after = try r.render(scene: scene, time: 0, delta: 0).readPixels()
        }
        return (before, after)
    }

    func testDistortWithZeroStrengthIsTheIdentity() throws {
        let (before, after) = try stripeDistort(strength: 0)
        XCTAssertEqual(zip(before, after).map { abs(Int($0) - Int($1)) }.max(), 0)
    }

    func testDistortMovesAStripe() throws {
        let (before, after) = try stripeDistort(strength: 0.1)
        let movedRows = (0..<32).filter { y in
            EffectHarness.pixel(after, width: 32, x: 15, y: y).x != EffectHarness.pixel(before, width: 32, x: 15, y: y).x
        }
        XCTAssertGreaterThan(movedRows.count, 4, "the stripe is displaced on several rows")
    }

    // MARK: composite (T-F411)

    /// Base = red scene; overlay = the scene turned blue by a colorMatrix; composited with `mode`.
    private func composite(mode: Double, opacity: Double) throws -> SIMD4<Int> {
        var out: [UInt8] = []
        _ = try EffectHarness.run { ctx in
            let red = try EffectHarness.solid(1, 0, 0, in: ctx)
            let toBlue: [Double] = [0, 0, 0, 0,  0, 0, 0, 0,  1, 0, 0, 0,  0, 0, 0, 1]
            let r = try EffectRenderer(graph: EffectHarness.graph([
                EffectPassDescription(id: "O", type: "colorMatrix", inputs: ["input": "scene"], output: "o", params: ["matrix": toBlue]),
                EffectPassDescription(id: "C", type: "composite", inputs: ["base": "scene", "overlay": "o"], output: "c",
                                      params: ["mode": [mode], "opacity": [opacity]]),
            ], output: "c"), registry: ctx.resources)
            out = try r.render(scene: red, time: 0, delta: 0).readPixels()
        }
        return EffectHarness.pixel(out, width: 16, x: 4, y: 4)
    }

    func testCompositeOverAtHalfOpacity() throws {
        let p = try composite(mode: 0, opacity: 0.5)
        XCTAssertEqual(p.x, 128, accuracy: 2); XCTAssertEqual(p.y, 0, accuracy: 1); XCTAssertEqual(p.z, 128, accuracy: 2)
    }

    func testCompositeAdd() throws {
        let p = try composite(mode: 1, opacity: 1)
        XCTAssertGreaterThanOrEqual(p.x, 254); XCTAssertGreaterThanOrEqual(p.z, 254)
    }

    // MARK: feedback (T-F412)

    func testFeedbackDecaysTowardTheInputAndClearsOnResize() throws {
        var values: [Int] = []
        var afterResize = 0
        var liveAfterTeardown = -1
        let host = try EffectHarness.run { ctx in
            let black = try EffectHarness.solid(0, 0, 0, in: ctx)
            let white = try EffectHarness.solid(1, 1, 1, in: ctx)
            let bigWhite = try EffectHarness.solid(1, 1, 1, size: 24, in: ctx)
            let r = try EffectRenderer(graph: EffectHarness.graph([
                EffectPassDescription(id: "F", type: "feedback", inputs: ["input": "scene"], output: "f", params: ["decay": [0.5]]),
            ], output: "f"), registry: ctx.resources)
            for scene in [black, white, white] {
                values.append(EffectHarness.pixel(try r.render(scene: scene, time: 0, delta: 1.0 / 60).readPixels(), width: 16, x: 2, y: 2).x)
            }
            afterResize = EffectHarness.pixel(try r.render(scene: bigWhite, time: 0, delta: 1.0 / 60).readPixels(), width: 24, x: 2, y: 2).x
            r.invalidate()
            [black, white, bigWhite].forEach { ctx.resources.release($0) }
            liveAfterTeardown = ctx.resources.stats.liveCount[.framebuffer] ?? -1
        }
        XCTAssertEqual(values[0], 0)
        XCTAssertEqual(values[1], 128, accuracy: 2)
        XCTAssertEqual(values[2], 191, accuracy: 3)
        XCTAssertEqual(afterResize, 255, "history cleared to the input on a size change")
        XCTAssertEqual(liveAfterTeardown - (host.resources.stats.liveCount[.framebuffer] ?? 0), 0)
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }
}
