// NoiseTests — feature 152 (A21-P01) T-A21-106 (FR-A21-104; clarification Q2). The Swift port `SkyNoise` matches the
// GPU's `vc/` library: a tiny shader writes the PCG hash byte (exactly), `vc_gradientNoise` and `vc_fbm` at 5 and 3
// octaves (within one 8-bit step) at known points, drawn off screen; plus known properties of the port itself.
import XCTest
import AuroraCore
import VisualCoreRendering

@MainActor
final class NoiseTests: XCTestCase {
    /// Point of pixel (x, y) (GL orientation): `gl_FragCoord × 0.37 + (20, 30)`, the same products in both.
    private static let probe = """
    precision highp float;
    #include "vc/noise.glsl"
    out vec4 color;
    void main() {
        vec2 p = gl_FragCoord.xy * 0.37 + vec2(20.0, 30.0);
        uint word = vc_pcg(uint(gl_FragCoord.x) * 16u + uint(gl_FragCoord.y));
        color = vec4(vc_gradientNoise(p) * 0.5 + 0.5, vc_fbm(p, 5, 2.0, 0.5) * 0.5 + 0.5,
                     vc_fbm(p, 3, 2.0, 0.5) * 0.5 + 0.5, float(word >> 24u) / 255.0);
    }
    """

    private static func unorm(_ v: Float) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }

    func testPortMatchesTheGPUNoise() throws {
        let scene = FullScreenShaderScene(fragment: Self.probe, fragmentName: "aurora-noise-probe.frag",
                                          bundle: ShaderBundle(files: [:]))
        let host = try AuroraOffscreen.makeHost(scene)
        defer { host.destroy() }
        XCTAssertNil(scene.errorMessage)
        let size = 16
        let image = try host.renderOffscreen(width: size, height: size, time: 0)
        var largest = 0, hashMismatches = 0
        for row in 0..<size {
            let y = size - 1 - row
            for x in 0..<size {
                let i = (row * size + x) * 4
                let p = SIMD2(Float(x) + 0.5, Float(y) + 0.5) * 0.37 + SIMD2(20, 30)
                let expected = [Self.unorm(SkyNoise.gradientNoise(p) * 0.5 + 0.5),
                                Self.unorm(SkyNoise.fbm(p, octaves: 5) * 0.5 + 0.5),
                                Self.unorm(SkyNoise.fbm(p, octaves: 3) * 0.5 + 0.5)]
                for c in 0..<3 { largest = max(largest, abs(Int(image.rgba[i + c]) - expected[c])) }
                let word = SkyNoise.pcg(UInt32(x) * 16 + UInt32(y))
                if Int(image.rgba[i + 3]) != Int(word >> 24) { hashMismatches += 1 }
            }
        }
        print("aurora-noise probe: largest difference \(largest)/255, hash mismatches \(hashMismatches)")
        XCTAssertLessThanOrEqual(largest, 1, "noise within one 8-bit step")
        XCTAssertEqual(hashMismatches, 0, "the PCG hash is exact")
    }

    func testHashesAreDeterministicUniformAndUseTheBitPatterns() {
        XCTAssertEqual(SkyNoise.pcg(0), SkyNoise.pcg(0))
        XCTAssertNotEqual(SkyNoise.pcg(0), SkyNoise.pcg(1))
        var sum: Float = 0
        for x in 0..<32 {
            for y in 0..<32 {
                let h = SkyNoise.hash21(SIMD2(Float(x), Float(y)))
                XCTAssertGreaterThanOrEqual(h, 0)
                XCTAssertLessThan(h, 1)
                sum += h
                let pair = SkyNoise.hash22(SIMD2(Float(x), Float(y)))
                XCTAssertEqual(pair.x, h, "hash22's first value is hash21")
            }
        }
        XCTAssertEqual(sum / 1024, 0.5, accuracy: 0.05)
        XCTAssertNotEqual(SkyNoise.hash21(SIMD2(0, 0)), SkyNoise.hash21(SIMD2(-0.0, 0)), "bit patterns, not values")
    }

    func testNoiseIsBoundedAndZeroOnLatticePoints() {
        for x in 0..<20 {
            for y in 0..<20 {
                let p = SIMD2(Float(x) * 0.731 + 3, Float(y) * 0.517 + 5)
                XCTAssertLessThanOrEqual(abs(SkyNoise.gradientNoise(p)), 1.5)
                XCTAssertLessThanOrEqual(abs(SkyNoise.fbm(p, octaves: 5)), 1.5)
            }
            XCTAssertEqual(SkyNoise.gradientNoise(SIMD2(Float(x), 7)), 0, accuracy: 1e-6)
        }
        XCTAssertEqual(SkyNoise.fbm(SIMD2(1.5, 2.5), octaves: 0), 0)
        XCTAssertEqual(SkyNoise.fbm(SIMD2(1.5, 2.5), octaves: 12), SkyNoise.fbm(SIMD2(1.5, 2.5), octaves: 8))
    }
}
