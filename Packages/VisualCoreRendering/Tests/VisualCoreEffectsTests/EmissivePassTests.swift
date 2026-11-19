// EmissivePassTests — feature 207 R02-F07 T-R02F07-005 (FR-R02F07-001…006; SC-R02F07-001, 002, 004): the emissive
// pass against a CPU reference, its blur-target sizes and pool use, composite mode 2 and the premultiplied preset,
// the limiter in linear light, and a context rebuild.
//
// Reference method: `EmissiveRun.reference` emulates the GPU taps exactly rather than an idealised downsample. The
// prefilter takes the same four bilinear taps (±0.25 blur texel; clamp-to-edge bilinear on the encoded input), decodes
// each with `EmissiveReference.srgbDecode`, averages and applies `EmissiveReference.prefilter`; the result is stored
// at the blur target's precision (half float, or 8 bits clamped to 0…1). The blur is the same separable 9-tap
// Gaussian (σ = radius / 2, spacing 1, edge-clamped) with storage rounding after each direction; the composite
// samples base and glow bilinearly at the output texel centre and applies `EmissiveReference.composite` and
// `srgbEncode`.
import CVisualCoreGL
import VisualCoreEffectsGraph
import VisualCoreShaderSource
import XCTest
@testable import VisualCoreEffects
@testable import VisualCoreRendering

/// A CPU picture, rows bottom-up like GL readbacks.
struct EmissivePicture {
    var width: Int, height: Int
    var pixels: [SIMD4<Double>]

    init(width: Int, height: Int, fill: SIMD4<Double> = SIMD4(0, 0, 0, 1)) {
        self.width = width; self.height = height
        pixels = Array(repeating: fill, count: width * height)
    }

    subscript(x: Int, y: Int) -> SIMD4<Double> {
        get { pixels[min(max(y, 0), height - 1) * width + min(max(x, 0), width - 1)] }
        set { pixels[y * width + x] = newValue }
    }

    /// Clamp-to-edge bilinear sample at uv, as GL_LINEAR with GL_CLAMP_TO_EDGE.
    func sample(_ u: Double, _ v: Double) -> SIMD4<Double> {
        let x = u * Double(width) - 0.5, y = v * Double(height) - 0.5
        let x0 = Int(x.rounded(.down)), y0 = Int(y.rounded(.down))
        let fx = x - Double(x0), fy = y - Double(y0)
        let top = self[x0, y0] * (1 - fx) + self[x0 + 1, y0] * fx
        let bottom = self[x0, y0 + 1] * (1 - fx) + self[x0 + 1, y0 + 1] * fx
        return top * (1 - fy) + bottom * fy
    }

    var bytes: [UInt8] { pixels.flatMap { p in (0..<4).map { UInt8((min(max(p[$0], 0), 1) * 255).rounded()) } } }
}

/// Parameters of one emissive run and its CPU reference.
struct EmissiveRun {
    var threshold = 1.0, knee = 0.5, intensity = 1.0, radius = 4.0, quality = 0.0, exposure = 0.0, tonemap = 0.0

    var params: [String: [Double]] {
        ["threshold": [threshold], "knee": [knee], "intensity": [intensity], "radius": [radius], "quality": [quality],
         "exposure": [exposure], "tonemap": [tonemap]]
    }

    static func store(_ v: Double, half: Bool) -> Double {
        #if arch(arm64)
        if half { return Double(Float16(Float(v))) }
        #else
        if half { return Double(Float(v)) }
        #endif
        return (min(max(v, 0), 1) * 255).rounded() / 255
    }

    static func store(_ c: SIMD3<Double>, half: Bool) -> SIMD4<Double> {
        SIMD4(store(c.x, half: half), store(c.y, half: half), store(c.z, half: half), 1)
    }

    /// The blurred glow at blur size, emulating the GPU taps and storage precision.
    func glow(_ input: EmissivePicture, outWidth: Int, outHeight: Int, half: Bool) -> EmissivePicture {
        let size = EmissivePass.blurSize(width: outWidth, height: outHeight, quality: quality)
        let bw = size.x, bh = size.y
        var a = EmissivePicture(width: bw, height: bh)
        let ox = 0.25 / Double(bw), oy = 0.25 / Double(bh)
        for y in 0..<bh {
            for x in 0..<bw {
                let u = (Double(x) + 0.5) / Double(bw), v = (Double(y) + 0.5) / Double(bh)
                var s = SIMD3<Double>(0, 0, 0)
                for (dx, dy) in [(-ox, -oy), (ox, -oy), (-ox, oy), (ox, oy)] {
                    let t = input.sample(u + dx, v + dy)
                    s += SIMD3(EmissiveReference.srgbDecode(t.x), EmissiveReference.srgbDecode(t.y), EmissiveReference.srgbDecode(t.z))
                }
                a[x, y] = Self.store(EmissiveReference.prefilter(s * 0.25, threshold: threshold, knee: knee), half: half)
            }
        }
        let sigma = max(radius * 0.5, 0.5)
        let weights = (-4...4).map { exp(-Double($0 * $0) / (2 * sigma * sigma)) }
        let total = weights.reduce(0, +)
        func pass(_ src: EmissivePicture, horizontal: Bool) -> EmissivePicture {
            var out = EmissivePicture(width: bw, height: bh)
            for y in 0..<bh {
                for x in 0..<bw {
                    var s = SIMD3<Double>(0, 0, 0)
                    for (i, w) in weights.enumerated() {
                        let p = horizontal ? src[x + i - 4, y] : src[x, y + i - 4]
                        s += SIMD3(p.x, p.y, p.z) * w
                    }
                    out[x, y] = Self.store(s / total, half: half)
                }
            }
            return out
        }
        return pass(pass(a, horizontal: true), horizontal: false)
    }

    /// The linear composite before the tone map (to show values above 1).
    func untoned(_ input: EmissivePicture, half: Bool) -> [SIMD3<Double>] {
        let g = glow(input, outWidth: input.width, outHeight: input.height, half: half)
        return (0..<input.height).flatMap { y in (0..<input.width).map { x in
            let u = (Double(x) + 0.5) / Double(input.width), v = (Double(y) + 0.5) / Double(input.height)
            let b = input[x, y], gl = g.sample(u, v)
            let base = SIMD3(EmissiveReference.srgbDecode(b.x), EmissiveReference.srgbDecode(b.y), EmissiveReference.srgbDecode(b.z))
            return (base + SIMD3(gl.x, gl.y, gl.z) * intensity) * pow(2, exposure)
        } }
    }

    /// The encoded output in bytes, rows bottom-up.
    func reference(_ input: EmissivePicture, half: Bool) -> [Double] {
        let g = glow(input, outWidth: input.width, outHeight: input.height, half: half)
        let op = ToneMapOperator(rawValue: Int(tonemap.rounded())) ?? .none
        var out: [Double] = []
        for y in 0..<input.height {
            for x in 0..<input.width {
                let u = (Double(x) + 0.5) / Double(input.width), v = (Double(y) + 0.5) / Double(input.height)
                let b = input[x, y], gl = g.sample(u, v)
                let base = SIMD3(EmissiveReference.srgbDecode(b.x), EmissiveReference.srgbDecode(b.y), EmissiveReference.srgbDecode(b.z))
                let c = EmissiveReference.composite(base: base, glow: SIMD3(gl.x, gl.y, gl.z), intensity: intensity,
                                                    exposure: exposure, op: op)
                out += [EmissiveReference.srgbEncode(c.x), EmissiveReference.srgbEncode(c.y), EmissiveReference.srgbEncode(c.z), b.w]
                    .map { $0 * 255 }
            }
        }
        return out
    }
}

@MainActor
final class EmissivePassTests: XCTestCase {
    /// Uploads `picture` and runs one emissive pass over it; returns the output bytes and the pass.
    private func render(_ picture: EmissivePicture, _ run: EmissiveRun, forceStandard: Bool = false,
                        frames: Int = 1) throws -> (bytes: [UInt8], pass: EmissivePass?, warnings: [String]) {
        var bytes: [UInt8] = []
        var pass: EmissivePass?
        var warnings: [String] = []
        let host = try EffectHarness.run { ctx in
            let scene = try ctx.resources.makeRenderTarget(width: picture.width, height: picture.height, label: "emissive input")
            XCTAssertTrue(scene.upload(rgba: picture.bytes))
            let r = try EffectRenderer(graph: EffectHarness.graph([
                EffectPassDescription(id: "E", type: "emissive", inputs: ["input": "scene"], output: "e", params: run.params),
            ], output: "e"), registry: ctx.resources)
            r.forceStandardPrecision = forceStandard
            for _ in 0..<frames { bytes = try r.render(scene: scene, time: 0, delta: 1.0 / 60).readPixels() }
            pass = r.runners["E"] as? EmissivePass
            XCTAssertEqual(r.failedPasses, [])
            warnings = ctx.resources.stats.warnings
        }
        defer { host.destroy() }
        return (bytes, pass, warnings)
    }

    private func maxError(_ bytes: [UInt8], _ reference: [Double], rgbOnly: Bool = true) -> Double {
        var worst = 0.0
        for i in 0..<min(bytes.count, reference.count) where !rgbOnly || i % 4 != 3 {
            worst = max(worst, abs(Double(bytes[i]) - reference[i]))
        }
        return worst
    }

    /// Black with a white 2×2 block, a dimmer coloured point and a soft ramp along the bottom row.
    private func brightPoint(size: Int = 32) -> EmissivePicture {
        var p = EmissivePicture(width: size, height: size)
        for y in 14...15 { for x in 14...15 { p[x, y] = SIMD4(1, 1, 1, 1) } }
        p[6, 24] = SIMD4(1, 0.6, 0.2, 1)
        for x in 0..<size { p[x, 0] = SIMD4(Double(x) / Double(size), 0.2, 0.1, 1) }
        return p
    }

    private func skipUnlessHalfFloat(_ pass: EmissivePass?) throws {
        guard pass?.lastBlurFormat == .rgba16f else { throw XCTSkip("half-float render targets not supported here") }
    }

    func testEmissiveProgramsCompileAndLink() throws {
        var results: [String: String] = [:]
        let host = try EffectHarness.run { ctx in
            for (name, fragment) in EffectShaders.emissiveFragments {
                do {
                    let p = try ctx.resources.program(vertex: EffectShaders.vertex, fragment: fragment,
                                                      vertexName: "effect.vert", fragmentName: "\(name).frag")
                    results[name] = "ok"
                    ctx.resources.release(p)
                } catch { results[name] = "\(error)" }
            }
            do { _ = try EffectRenderer.makeRunner(type: "emissive", registry: ctx.resources) } catch { results["runner"] = "\(error)" }
        }
        defer { host.destroy() }
        XCTAssertEqual(results.count, 3)
        for (name, result) in results.sorted(by: { $0.key < $1.key }) { XCTAssertEqual(result, "ok", name) }
    }

    // Analyze U1: below the threshold the pass is the identity with tonemap 0 and exposure 0.
    func testBelowThresholdIsTheIdentity() throws {
        var p = EmissivePicture(width: 32, height: 32)
        for y in 0..<32 { for x in 0..<32 { p[x, y] = SIMD4(Double(x) / 31 * 0.6, Double(y) / 31 * 0.55, 0.3, 1) } }
        let input = p.bytes
        let out = try render(p, EmissiveRun()).bytes   // threshold 1, knee 0.5: nothing below L = 0.5 glows
        XCTAssertEqual(out.count, input.count)
        let worst = zip(out, input).enumerated().filter { $0.offset % 4 != 3 }.map { abs(Int($0.element.0) - Int($0.element.1)) }.max()
        XCTAssertLessThanOrEqual(worst ?? 99, 1)
    }

    func testBrightPointGlowMatchesTheReferenceOnHighPrecision() throws {
        let picture = brightPoint()
        for quality in [0.0, 1.0] {
            let run = EmissiveRun(threshold: 0.1, knee: 0.5, intensity: 2, radius: 4, quality: quality)
            let (out, pass, warnings) = try render(picture, run)
            try skipUnlessHalfFloat(pass)
            XCTAssertFalse(warnings.contains(EmissivePass.standardPrecisionWarning))
            XCTAssertLessThanOrEqual(maxError(out, run.reference(picture, half: true)), 2, "quality \(quality)")
            let spill = EffectHarness.pixel(out, width: 32, x: 12, y: 15).x
            XCTAssertGreaterThan(spill, 10, "the glow spreads beside the block (quality \(quality))")
        }
    }

    func testForcedStandardPrecisionMatchesWithinFourAndWarnsOnce() throws {
        let picture = brightPoint()
        let run = EmissiveRun(threshold: 0.1, knee: 0.5, intensity: 2, radius: 4)
        let (out, pass, warnings) = try render(picture, run, forceStandard: true, frames: 3)
        XCTAssertEqual(pass?.lastBlurFormat, .rgba8)
        XCTAssertLessThanOrEqual(maxError(out, run.reference(picture, half: false)), 4)
        XCTAssertEqual(warnings.filter { $0 == EmissivePass.standardPrecisionWarning }.count, 1)
    }

    func testToneMapsRollOffValuesAboveOne() throws {
        var picture = EmissivePicture(width: 32, height: 32, fill: SIMD4(0.3, 0.3, 0.35, 1))
        for y in 12..<20 { for x in 12..<20 { picture[x, y] = SIMD4(1, 0.9, 0.8, 1) } }
        for op in [1.0, 2.0] {
            let run = EmissiveRun(threshold: 0.5, knee: 0.5, intensity: 3, radius: 4, tonemap: op)
            XCTAssertGreaterThan(run.untoned(picture, half: true).map { $0.max() }.max() ?? 0, 1.2, "values above 1 reach the tone map")
            let (out, pass, _) = try render(picture, run)
            try skipUnlessHalfFloat(pass)
            let rgb = out.enumerated().filter { $0.offset % 4 != 3 }.map(\.element)
            XCTAssertLessThan(Int(rgb.max() ?? 255), 255, "operator \(op) keeps the output below 1")
            XCTAssertLessThanOrEqual(maxError(out, run.reference(picture, half: true)), 2, "operator \(op)")
        }
        let clipped = try render(picture, EmissiveRun(threshold: 0.5, knee: 0.5, intensity: 3, radius: 4, tonemap: 0)).bytes
        XCTAssertEqual(EffectHarness.pixel(clipped, width: 32, x: 16, y: 16).x, 255, "tonemap 0 clamps")
    }

    func testBlurTargetSizes() throws {
        XCTAssertEqual(EmissivePass.blurSize(width: 512, height: 512, quality: 0), SIMD2(256, 256))
        XCTAssertEqual(EmissivePass.blurSize(width: 512, height: 512, quality: 1), SIMD2(128, 128))
        XCTAssertEqual(EmissivePass.blurSize(width: 3, height: 1, quality: 0), SIMD2(1, 1))
        XCTAssertEqual(EmissivePass.blurSize(width: 3, height: 1, quality: 1), SIMD2(1, 1))
        for (w, h, q, expected) in [(512, 512, 0.0, SIMD2(256, 256)), (512, 512, 1.0, SIMD2(128, 128)),
                                    (3, 1, 0.0, SIMD2(1, 1)), (3, 1, 1.0, SIMD2(1, 1))] {
            let (_, pass, _) = try render(EmissivePicture(width: w, height: h), EmissiveRun(quality: q))
            XCTAssertEqual(pass?.lastBlurSize, expected, "\(w)×\(h) quality \(q)")
        }
    }

    func testHundredFramesKeepTheRegistryCountsConstant() throws {
        var first: (Int, Int) = (0, 0), last: (Int, Int) = (-1, -1)
        let host = try EffectHarness.run { ctx in
            let scene = try ctx.resources.makeRenderTarget(width: 32, height: 32, label: "emissive input")
            scene.upload(rgba: self.brightPoint().bytes)
            let r = try EffectRenderer(graph: EffectHarness.graph([
                EffectPassDescription(id: "E", type: "emissive", inputs: ["input": "scene"], output: "e",
                                      params: EmissiveRun(threshold: 0.1).params),
            ], output: "e"), registry: ctx.resources)
            _ = try r.render(scene: scene, time: 0, delta: 1.0 / 60)
            first = (ctx.resources.stats.liveTotal, ctx.resources.stats.totalBytes)
            for _ in 1..<100 { _ = try r.render(scene: scene, time: 0, delta: 1.0 / 60) }
            last = (ctx.resources.stats.liveTotal, ctx.resources.stats.totalBytes)
        }
        defer { host.destroy() }
        XCTAssertEqual(first.0, last.0, "live objects constant")
        XCTAssertEqual(first.1, last.1, "live bytes constant")
    }

    // MARK: Premultiplied alpha (FR-R02F07-004)

    private let base = SIMD4<Double>(60, 40, 20, 153) / 255         // premultiplied (alpha 0.6)
    private let overlay = SIMD4<Double>(102, 26, 51, 128) / 255     // premultiplied (alpha ≈ 0.5)
    private let opacity = 0.8

    func testCompositeModeTwoIsPremultipliedOver() throws {
        var out: [UInt8] = []
        let (b, o) = (base, overlay)
        let host = try EffectHarness.run { ctx in
            let scene = try EffectHarness.solid(Float(b.x), Float(b.y), Float(b.z), Float(b.w), in: ctx)
            let zero = [Double](repeating: 0, count: 16)
            let r = try EffectRenderer(graph: EffectHarness.graph([
                EffectPassDescription(id: "O", type: "colorMatrix", inputs: ["input": "scene"], output: "o",
                                      params: ["matrix": zero, "offset": [o.x, o.y, o.z, o.w]]),
                EffectPassDescription(id: "C", type: "composite", inputs: ["base": "scene", "overlay": "o"], output: "c",
                                      params: ["mode": [2], "opacity": [self.opacity]]),
            ], output: "c"), registry: ctx.resources)
            out = try r.render(scene: scene, time: 0, delta: 0).readPixels()
        }
        defer { host.destroy() }
        let expected = EmissiveReference.premultipliedOver(overlay: overlay, base: base, opacity: opacity) * 255
        let p = EffectHarness.pixel(out, width: 16, x: 5, y: 5)
        for c in 0..<4 { XCTAssertEqual(Double(p[c]), expected[c], accuracy: 1, "channel \(c)") }
    }

    func testPremultipliedBlendedPresetDrawsTheSame() throws {
        var out: [UInt8] = []
        let (b, o, k) = (base, overlay, opacity)
        let host = try EffectHarness.run { ctx in
            let target = try EffectHarness.solid(Float(b.x), Float(b.y), Float(b.z), Float(b.w), in: ctx)
            let program = try ctx.resources.program(vertex: EffectShaders.vertex, fragment: """
            precision highp float;
            uniform vec4 u_color;
            in vec2 uv;
            out vec4 color;
            void main() { color = u_color; }
            """)
            target.bind()
            vcglViewport(0, 0, 16, 16)
            XCTAssertTrue(GLState.apply(Pipeline(program: program, state: .premultipliedBlended), resources: ctx.resources))
            program.set("u_color", SIMD4<Float>(Float(o.x * k), Float(o.y * k), Float(o.z * k), Float(o.w * k)))
            vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
            vcglDisable(GLenum(GL_BLEND))
            out = target.readPixels()
        }
        defer { host.destroy() }
        XCTAssertEqual(RenderState.premultipliedBlended.blend, .premultiplied)
        let expected = EmissiveReference.premultipliedOver(overlay: overlay, base: base, opacity: opacity) * 255
        let p = EffectHarness.pixel(out, width: 16, x: 5, y: 5)
        for c in 0..<4 { XCTAssertEqual(Double(p[c]), expected[c], accuracy: 1, "channel \(c)") }
    }

    // MARK: Limiter in linear light (FR-R02F07-005)

    private static let emissiveGraph = EffectHarness.graph([
        EffectPassDescription(id: "glow", type: "emissive", inputs: ["input": "scene"], output: "g", params: ["threshold": [0.8]]),
    ], output: "g")

    func testLimiterGetsLinearOnlyWithAnEmissivePass() {
        let with = EffectScene(content: ClearColorScene(red: 1, green: 1, blue: 1), graph: Self.emissiveGraph)
        with.reduceFlashing = true
        let limiter = with.effectiveGraph.passes.last
        XCTAssertEqual(limiter?.id, EffectScene.flashLimitPassID)
        XCTAssertEqual(limiter?.params, ["limit": [0.3], "linear": [1]])
        let plain = EffectScene(content: ClearColorScene(red: 1, green: 1, blue: 1), graph: EffectHarness.graph([
            EffectPassDescription(id: "c", type: "copy", inputs: ["input": "scene"], output: "c"),
        ], output: "c"))
        plain.reduceFlashing = true
        XCTAssertEqual(plain.effectiveGraph.passes.last?.params, ["limit": [0.3]], "existing graphs unchanged")
        with.reduceFlashing = false
        XCTAssertEqual(with.effectiveGraph, Self.emissiveGraph)
    }

    private func strobe(reduceFlashing: Bool) throws -> [Int] {
        let scene = EffectScene(content: ClearColorScene(red: 0, green: 0, blue: 0), graph: Self.emissiveGraph)
        scene.reduceFlashing = reduceFlashing
        let graph = scene.effectiveGraph
        var displayed: [Int] = []
        let host = try EffectHarness.run { ctx in
            let black = try EffectHarness.solid(0, 0, 0, in: ctx)
            let white = try EffectHarness.solid(1, 1, 1, in: ctx)
            let r = try EffectRenderer(graph: graph, registry: ctx.resources)
            _ = try r.render(scene: black, time: 0, delta: 1.0 / 30)      // adapt to black first
            for frame in 1...30 {
                let s = frame % 2 == 0 ? black : white
                displayed.append(EffectHarness.pixel(try r.render(scene: s, time: 0, delta: 1.0 / 30).readPixels(), width: 16, x: 8, y: 8).x)
            }
            XCTAssertEqual(r.failedPasses, [])
        }
        defer { host.destroy() }
        return displayed
    }

    func testThirtyHertzStrobeThroughAnEmissiveGraphIsBoundedWhenReduced() throws {
        let displayed = try strobe(reduceFlashing: true)
        let perFrame = 0.3 / 30 * 255
        for i in 1..<displayed.count { XCTAssertLessThanOrEqual(Double(abs(displayed[i] - displayed[i - 1])), perFrame + 2) }
        XCTAssertLessThanOrEqual(Double(displayed.max()! - displayed.min()!), 0.3 * 255 + 2, "≤ 0.3 per second")
        let free = try strobe(reduceFlashing: false)
        XCTAssertGreaterThan(free.max()! - free.min()!, 200, "without the limiter the strobe follows the input")
    }

    // MARK: Context rebuild

    func testContextRebuildGivesTheSameOutput() throws {
        let scene = EffectScene(content: GradientQuadScene(), graph: EffectHarness.graph([
            EffectPassDescription(id: "glow", type: "emissive", inputs: ["input": "scene"], output: "g",
                                  params: ["threshold": [0.15], "intensity": [2], "radius": [3]]),
        ], output: "g"))
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: 32, height: 16)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        let before = host.readPixels()
        host.recreateContext()
        XCTAssertTrue(host.renderOneFrame(present: false))
        let after = host.readPixels()
        XCTAssertNil(scene.lastError)
        XCTAssertEqual(scene.renderer?.failedPasses, [])
        XCTAssertFalse(before.isEmpty)
        XCTAssertEqual(before.count, after.count)
        XCTAssertLessThanOrEqual(zip(before, after).map { abs(Int($0) - Int($1)) }.max() ?? 99, 1)
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }
}
