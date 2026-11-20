// SpectralShaderTests — feature 210 (R02-F10) T-R02F10-006 (FR-R02F10-002, FR-R02F10-004, FR-R02F10-011; research R1,
// R3, R13): vc/spectral.glsl equals the CPU references PerceptualColor and ColorVisionCondition. A 64 × 64 ramp of
// linear colours (derived from the cell x, y; the diagonal is grey) goes through OKLab forward (L, a + 0.5, b + 0.5),
// the inverse round trip, hue rotations by 0, π/2 and 2π and every colour-vision condition; each GPU byte is compared
// with round(CPU × 255) within 2 per channel. No GPU object is left after destroy.
import XCTest
import VisualCoreParameters
@testable import VisualCoreRendering

@MainActor
final class SpectralShaderTests: XCTestCase {
    /// Cells per side.
    static let grid = 64
    /// The largest allowed difference between the GPU byte and the rounded CPU value.
    static let toleranceBytes = 2

    /// The linear colour of cell (x, y): r = (x + ½)/64, g = (y + ½)/64, b = ((5x + 3y) mod 64 + ½)/64; grey r on the
    /// diagonal. Every value is exact in float.
    static func ramp(_ x: Int, _ y: Int) -> SIMD3<Double> {
        let n = Double(grid)
        let r = (Double(x) + 0.5) / n
        if x == y { return SIMD3(r, r, r) }
        return SIMD3(r, (Double(y) + 0.5) / n, (Double((5 * x + 3 * y) % grid) + 0.5) / n)
    }

    /// A fragment that computes `c` (the ramp colour of the pixel's cell) and writes `expression` (a vec3 of `c`).
    static func fragment(_ expression: String) -> String {
        """
        precision highp float;
        #include "vc/color.glsl"
        #include "vc/spectral.glsl"
        uniform vec2 u_resolution;
        out vec4 color;
        void main() {
            vec2 cell = floor(gl_FragCoord.xy * \(Double(grid)) / u_resolution);
            vec3 c = vec3((cell.x + 0.5) / \(Double(grid)), (cell.y + 0.5) / \(Double(grid)),
                          (mod(cell.x * 5.0 + cell.y * 3.0, \(Double(grid))) + 0.5) / \(Double(grid)));
            if (cell.x == cell.y) { c = vec3(c.r); }
            vec3 o = \(expression);
            color = vec4(clamp(o, 0.0, 1.0), 1.0);
        }
        """
    }

    /// Renders `fragment` into a 64 × 64 point view, checks for no compile error and no leak after destroy, and returns
    /// the RGBA8 pixels (bottom row first) with the surface size.
    func render(_ fragment: String, name: String) throws -> (pixels: [UInt8], width: Int, height: Int) {
        let scene = FullScreenShaderScene(fragment: fragment, fragmentName: name, bundle: ShaderBundle(files: [:]))
        let host = try RenderHost(scene: scene)
        host.view.frame = CGRect(x: 0, y: 0, width: Self.grid, height: Self.grid)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false), name)
        XCTAssertNil(scene.errorMessage, name)
        let pixels = host.readPixels()
        let (w, h) = host.pixelSize
        host.destroy()
        XCTAssertEqual(host.resources.stats.leaked, 0, "\(name): leaked GPU objects")
        XCTAssertGreaterThanOrEqual(w * h, Self.grid * Self.grid, name)
        XCTAssertEqual(pixels.count, w * h * 4, name)
        return (pixels, w, h)
    }

    /// Renders `expression` and returns the largest |GPU byte − round(expected × 255)| over every pixel and channel,
    /// `expected` evaluated on each cell's ramp colour.
    func maxError(_ expression: String, name: String, expected: (SIMD3<Double>) throws -> SIMD3<Double>) throws -> Int {
        let (pixels, w, h) = try render(Self.fragment(expression), name: name)
        guard w > 0, h > 0, pixels.count == w * h * 4 else { return Int.max }
        var table = [SIMD3<Int>](repeating: .zero, count: Self.grid * Self.grid)
        for cy in 0..<Self.grid {
            for cx in 0..<Self.grid {
                let v = try expected(Self.ramp(cx, cy))
                var bytes = SIMD3<Int>.zero
                for c in 0..<3 { bytes[c] = Int((min(max(v[c], 0), 1) * 255).rounded()) }
                table[cy * Self.grid + cx] = bytes
            }
        }
        var worst = 0
        for y in 0..<h {
            let cy = Int(((Double(y) + 0.5) * Double(Self.grid) / Double(h)).rounded(.down))
            for x in 0..<w {
                let cx = Int(((Double(x) + 0.5) * Double(Self.grid) / Double(w)).rounded(.down))
                let want = table[cy * Self.grid + cx], i = (y * w + x) * 4
                for c in 0..<3 { worst = max(worst, abs(Int(pixels[i + c]) - want[c])) }
            }
        }
        print("SpectralShaderTests \(name): max error \(worst)/255")
        return worst
    }

    func testOklabForwardAndRoundTripMatchReference() throws {
        let forward = try maxError("vc_linearToOklab(c) + vec3(0.0, 0.5, 0.5)", name: "oklab-forward") { c in
            PerceptualColor.oklab(fromLinear: c) + SIMD3(0, 0.5, 0.5)
        }
        XCTAssertLessThanOrEqual(forward, Self.toleranceBytes, "OKLab forward")
        let roundTrip = try maxError("vc_oklabToLinear(vc_linearToOklab(c))", name: "oklab-round-trip") { c in
            PerceptualColor.linear(fromOklab: PerceptualColor.oklab(fromLinear: c))
        }
        XCTAssertLessThanOrEqual(roundTrip, Self.toleranceBytes, "OKLab round trip")
    }

    func testHueRotationMatchesReference() throws {
        let angles: [(name: String, radians: Double)] = [("0", 0), ("pi-2", Double.pi / 2), ("2pi", 2 * Double.pi)]
        for angle in angles {
            let error = try maxError("vc_hueRotate(c, \(angle.radians))", name: "hue-\(angle.name)") { c in
                let rotated = try PerceptualColor.rotateHue(sRGB: PerceptualColor.sRGB(fromLinear: c), by: angle.radians)
                return PerceptualColor.linear(fromSRGB: rotated)
            }
            XCTAssertLessThanOrEqual(error, Self.toleranceBytes, "hue rotation \(angle.name)")
        }
    }

    func testColorVisionSimulationMatchesReferenceForEveryCondition() throws {
        for (index, condition) in ColorVisionCondition.allCases.enumerated() {
            let error = try maxError("vc_simulateCVD(c, \(index))", name: "cvd-\(condition.rawValue)") { c in
                PerceptualColor.linear(fromSRGB: condition.simulate(sRGB: PerceptualColor.sRGB(fromLinear: c)))
            }
            XCTAssertLessThanOrEqual(error, Self.toleranceBytes, "\(condition)")
        }
        XCTAssertEqual(ColorVisionCondition.allCases.count, 5)
    }
}
