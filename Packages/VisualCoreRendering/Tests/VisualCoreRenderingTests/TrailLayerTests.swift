// TrailLayerTests — feature 035 A04-P03 T-A04-304 (G-BLENDTRAIL; FR-A04-302, FR-A04-303; SC-A04-303–SC-A04-305;
// contract C4–C6; manual fixture 3). Simulator tests of the fade against VisualCore's TrailDecay model, texture counts
// across resizes, clears and a context recreation, and the brightness cap.
import CVisualCoreGL
import VisualCoreDiagnostics
import VisualCoreSimulation
import XCTest
@testable import VisualCoreRendering

@MainActor
final class TrailLayerTests: XCTestCase {
    private var host: RenderHost?

    override func tearDown() {
        host?.destroy()
        host = nil
    }

    /// Runs `body` during scene setup with the context current.
    private func withContext(_ body: @escaping (RenderContext) throws -> Void) throws {
        var failure: Error?
        let h = try RenderHost(scene: ProbeScene(setup: { ctx in
            do { try body(ctx) } catch { failure = error }
        }))
        h.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        h.view.layoutIfNeeded()
        host = h
        if let failure { throw failure }
    }

    private func fill(_ v: Float) {
        vcglDisable(GLenum(GL_SCISSOR_TEST))
        vcglClearColor(v, v, v, 1)
        vcglClear(GLbitfield(GL_COLOR_BUFFER_BIT))
    }

    private func red(_ t: RenderTarget) -> UInt8 { t.readPixels()[0] }

    func testFadeFollowsTheModelEveryFrame() throws {
        // SC-A04-303: per frame within 1/255 of TrailDecay.step8 applied to the observed previous value.
        var observed: [UInt8] = []
        var predicted: [UInt8] = []
        try withContext { ctx in
            let layer = try TrailLayer(registry: ctx.resources, width: 8, height: 8)
            defer { layer.release() }
            layer.strength = 0.9
            let out = try ctx.resources.makeRenderTarget(width: 8, height: 8, label: "trail out")
            defer { ctx.resources.release(out) }
            try layer.frame(delta: 1.0 / 60, output: .target(out)) { _ in self.fill(200.0 / 255) }
            var previous = self.red(layer.image!)
            XCTAssertEqual(Int(previous), 200, accuracy: 1)
            XCTAssertEqual(self.red(out), previous, "the composite shows the trail image (no cap)")
            let f = TrailDecay.factor(strength: 0.9, delta: 1.0 / 60), d = TrailDecay.subtraction(delta: 1.0 / 60)
            for _ in 0..<60 {
                try layer.frame(delta: 1.0 / 60, output: .target(out)) { _ in }
                let now = self.red(layer.image!)
                observed.append(now); predicted.append(TrailDecay.step8(previous, factor: f, subtract: d))
                previous = now
            }
        }
        XCTAssertEqual(observed.count, 60)
        for (o, p) in zip(observed, predicted) { XCTAssertLessThanOrEqual(abs(Int(o) - Int(p)), 1, "observed \(o) predicted \(p)") }
        XCTAssertEqual(observed.last, 0, "the trail reaches background")
    }

    func testEqualTimeFadesAlikeAtThirtyAndSixtyHertz() throws {
        // SC-A04-303: 10 frames at 1/60 s versus 5 at 1/30 s, and 60 versus 30, within 6/255.
        var results: [(Int, Int)] = []
        try withContext { ctx in
            for frames in [10, 60] {
                var values: [Int] = []
                for (delta, n) in [(1.0 / 60, frames), (1.0 / 30, frames / 2)] {
                    let layer = try TrailLayer(registry: ctx.resources, width: 4, height: 4)
                    layer.strength = 0.95
                    let out = try ctx.resources.makeRenderTarget(width: 4, height: 4, label: "trail out")
                    try layer.frame(delta: delta, output: .target(out)) { _ in self.fill(220.0 / 255) }
                    for _ in 0..<n { try layer.frame(delta: delta, output: .target(out)) { _ in } }
                    values.append(Int(self.red(layer.image!)))
                    ctx.resources.release(out)
                    layer.release()
                }
                results.append((values[0], values[1]))
            }
        }
        XCTAssertEqual(results.count, 2)
        for (a, b) in results { XCTAssertLessThanOrEqual(abs(a - b), 6, "60 Hz \(a) vs 30 Hz \(b)") }
        XCTAssertGreaterThan(results[0].0, 0, "10 frames of strength 0.95 still show a trail")
    }

    func testBrightnessCap() throws {
        // SC-A04-305: with the cap at 0.6 every composited channel is at most 153.
        var pixels: [UInt8] = []
        try withContext { ctx in
            let layer = try TrailLayer(registry: ctx.resources, width: 8, height: 8)
            defer { layer.release() }
            layer.brightnessCap = 0.6
            let out = try ctx.resources.makeRenderTarget(width: 8, height: 8, label: "trail out")
            defer { ctx.resources.release(out) }
            try layer.frame(delta: 1.0 / 60, output: .target(out)) { _ in self.fill(1) }
            pixels = out.readPixels()
        }
        XCTAssertEqual(pixels.count, 8 * 8 * 4)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            XCTAssertLessThanOrEqual(pixels[i], 153); XCTAssertLessThanOrEqual(pixels[i + 1], 153); XCTAssertLessThanOrEqual(pixels[i + 2], 153)
            XCTAssertGreaterThanOrEqual(pixels[i], 152, "white is capped, not darkened further")
        }
    }

    func testResizesAndClearsLeakNoTextures() throws {
        // SC-A04-304 / fixture 3 (part 1): 20 resizes (release + create at a new size) and 20 clears.
        // Each render target is one ledger `.framebuffer` entry that owns its color texture (ResourceRegistry), so
        // framebuffer entries and total bytes count the trail textures.
        var baseline = -1, afterFirst = -1, afterCycles = -1, afterRelease = -1, leakedBefore = -1, leakedAfter = -1
        var bytesBefore = -1, bytesAfter = -1
        try withContext { ctx in
            let r = ctx.resources
            baseline = r.stats.liveCount[.framebuffer] ?? 0
            leakedBefore = r.stats.leaked
            bytesBefore = r.stats.totalBytes
            var layer = try TrailLayer(registry: r, width: 64, height: 32)
            afterFirst = r.stats.liveCount[.framebuffer] ?? 0
            for i in 0..<20 {
                layer.release()
                layer = try TrailLayer(registry: r, width: 64 + i * 7, height: 32 + i * 3)
                layer.clear()
            }
            afterCycles = r.stats.liveCount[.framebuffer] ?? 0
            layer.release()
            layer.release()   // idempotent
            afterRelease = r.stats.liveCount[.framebuffer] ?? 0
            leakedAfter = r.stats.leaked
            bytesAfter = r.stats.totalBytes
        }
        XCTAssertEqual(afterFirst - baseline, 2, "two trail targets")
        XCTAssertEqual(bytesAfter, bytesBefore, "all trail bytes returned")
        XCTAssertEqual(afterCycles, afterFirst)
        XCTAssertEqual(afterRelease, baseline)
        XCTAssertEqual(leakedAfter, leakedBefore)
    }

    func testContextRecreationLeaksNoTextures() throws {
        // SC-A04-304 / fixture 3 (part 2): a scene owning a layer through a context recreation.
        final class TrailScene: RenderScene {
            var layer: TrailLayer?
            var textures: [Int] = []
            var setups = 0
            func setup(_ c: RenderContext) throws { setups += 1 }
            func resize(_ c: RenderContext) {}
            func render(_ c: RenderContext, frame: FrameInfo) throws {
                // Created lazily at the drawable size (setup runs before layout), as ParticleLayerScene does.
                if layer == nil {
                    layer = try TrailLayer(registry: c.resources, width: c.pixelWidth, height: c.pixelHeight)
                    textures.append(c.resources.stats.liveCount[.framebuffer] ?? 0)
                }
                layer?.strength = 0.9
                try layer?.frame(delta: 1.0 / 60, output: .framebuffer(name: c.framebuffer, width: c.pixelWidth, height: c.pixelHeight)) { _ in }
            }
            func teardown(_ c: RenderContext) { layer?.release(); layer = nil }
        }
        let scene = TrailScene()
        let h = try RenderHost(scene: scene)
        host = h
        h.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        h.view.layoutIfNeeded()
        XCTAssertTrue(h.renderOneFrame(present: false))
        let leaked = h.resources.stats.leaked
        h.recreateContext()
        XCTAssertTrue(h.renderOneFrame(present: false))
        XCTAssertEqual(scene.setups, 2, "set up twice")
        XCTAssertEqual(scene.textures.count, 2, "the layer was rebuilt after the recreation")
        guard scene.textures.count == 2 else { return }
        XCTAssertEqual(scene.textures[1], scene.textures[0], "same live render targets after recreation")
        XCTAssertEqual(h.resources.stats.leaked, leaked, "nothing leaked")
        XCTAssertTrue(scene.layer?.isValid ?? false)
    }

    func testFittedSizeCapsTheLongerEdge() {
        XCTAssertTrue(TrailLayer.fittedSize(width: 4_096, height: 1_024)! == (2_048, 512))
        XCTAssertTrue(TrailLayer.fittedSize(width: 300, height: 200)! == (300, 200))
        XCTAssertNil(TrailLayer.fittedSize(width: 0, height: 10))
    }
}
