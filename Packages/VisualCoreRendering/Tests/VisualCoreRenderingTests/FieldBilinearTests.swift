// FieldBilinearTests — feature 020 T-A02-204 (FR-A02-202; research R1): vc_fieldBilinear on the GPU equals
// FieldGrid.sampleBilinear on the CPU, including coordinates outside the field.
import VisualCoreSimulation
import XCTest
@testable import VisualCoreRendering

@MainActor
final class FieldBilinearTests: XCTestCase {
    static let fragment = """
    precision highp float;
    #include "vc/field.glsl"
    uniform sampler2D uField;
    uniform vec2 uScale;
    uniform vec2 uOffset;
    in vec2 v_uv;
    out vec4 color;
    void main() { color = vc_fieldBilinear(uField, gl_FragCoord.xy * uScale + uOffset); }
    """

    func testGPUSamplerMatchesCPU() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let r = context.resources
            try XCTSkipUnless(FloatRenderSupport.detect(in: r).supported, "needs RGBA16F to compare exactly")
            // A 16x8 field whose values (k/64) and interpolated results are exact in half precision.
            var field = FieldGrid(width: 16, height: 8, channels: 4)
            for i in field.values.indices { field.values[i] = Float((i * 37) % 64) / 64 }
            let source = try r.makeRenderTarget(width: 16, height: 8, format: .rgba16f, label: "source")
            let out = try r.makeRenderTarget(width: 8, height: 8, format: .rgba16f, label: "out")
            defer { r.release(source); r.release(out) }
            XCTAssertTrue(source.upload(rgbaFloats: field.values))
            let pass = try FieldPass(registry: r, fragment: Self.fragment, inputs: ["uField"], label: "bilinear")
            defer { pass.release() }
            // Dyadic scales and offsets keep every coordinate and weight exact; the last case reaches outside.
            for (scale, offset) in [(SIMD2<Float>(1, 1), SIMD2<Float>(0, 0)), (SIMD2<Float>(2, 1), SIMD2<Float>(0.25, 0.125)),
                                    (SIMD2<Float>(1.5, 0.75), SIMD2<Float>(0.375, 0.5)), (SIMD2<Float>(2.5, 1.25), SIMD2<Float>(-3, -2))] {
                try pass.run(output: .target(out), inputs: ["uField": source],
                             uniforms: ["uScale": .vec2(scale), "uOffset": .vec2(offset)])
                let gpu = out.readFloatPixels()
                XCTAssertEqual(gpu.count, 8 * 8 * 4)
                var worst: Float = 0
                for y in 0..<8 { for x in 0..<8 {
                    let coord = (SIMD2<Float>(Float(x), Float(y)) + 0.5) * scale + offset
                    let cpu = field.sampleBilinear(cellX: coord.x, cellY: coord.y)
                    for c in 0..<4 { worst = max(worst, abs(gpu[(y * 8 + x) * 4 + c] - cpu[c])) }
                } }
                XCTAssertLessThanOrEqual(worst, 1e-5, "scale \(scale) offset \(offset)")
            }
        }
    }

    func testIncludesAreAvailableByDefault() throws {
        XCTAssertTrue(ShaderBundle.visualCoreIncludes.contains("vc/field.glsl"))
        XCTAssertTrue(ShaderBundle.visualCoreIncludes.contains("vc/color.glsl"))
    }
}
