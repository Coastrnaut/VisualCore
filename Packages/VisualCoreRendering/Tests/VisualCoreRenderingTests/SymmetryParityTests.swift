// SymmetryParityTests — feature 041 T-A05-203 (FR-A05-220, SC-A05-202): the shader's vc_foldDihedral matches the CPU
// twin PointGroup.dihedral(n).fold on a 16 × 16 grid for orders 1, 3, 6, 12, and the 2D distance helpers vc_sdCircle,
// vc_sdBox2 and vc_sdSegment have the right sign and value at known points. Results are encoded as RGBA8 colours.
import XCTest
import VisualCoreMath
@testable import VisualCoreRendering

@MainActor
final class SymmetryParityTests: XCTestCase {
    /// Grid cells per side; the surface may be larger (display scale), so every pixel maps to its logical cell.
    static let grid = 16
    /// Per-channel tolerance: one 8-bit step plus half a step of rounding.
    static let tolerance = 1.0 / 255.0 + 0.5 / 255.0

    /// Each pixel's input is the centre of its grid cell in [-1, 1]²; the fold is written as colour f · 0.35 + 0.5 (radius ≤ √2 stays inside 0…1, so no value is clamped).
    static func foldFragment(order: Int) -> String {
        """
        precision highp float;
        #include "vc/sdf.glsl"
        uniform vec2 u_resolution;
        out vec4 color;
        void main() {
            vec2 cell = floor(gl_FragCoord.xy * \(Double(grid)) / u_resolution);
            vec2 p = (cell + 0.5) / \(Double(grid)) * 2.0 - 1.0;
            vec2 f = vc_foldDihedral(p, \(Double(order)));
            color = vec4(clamp(f * 0.35 + 0.5, 0.0, 1.0), 0.0, 1.0);
        }
        """
    }

    /// Renders `fragment` into a 16 × 16 point view and returns the RGBA8 pixels with the surface size.
    func render(_ fragment: String, name: String) throws -> (pixels: [UInt8], width: Int, height: Int) {
        let scene = FullScreenShaderScene(fragment: fragment, fragmentName: name, bundle: ShaderBundle(files: [:]))
        let host = try RenderHost(scene: scene)
        defer { host.destroy() }
        host.view.frame = CGRect(x: 0, y: 0, width: 16, height: 16)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertNil(scene.errorMessage)
        let pixels = host.readPixels()
        let (w, h) = host.pixelSize
        XCTAssertGreaterThanOrEqual(w * h, Self.grid * Self.grid, "at least a 16×16 grid of inputs")
        XCTAssertEqual(pixels.count, w * h * 4)
        return (pixels, w, h)
    }

    func testShaderDihedralFoldMatchesCPUTwin() throws {
        for order in [1, 3, 6, 12] {
            let (pixels, w, h) = try render(Self.foldFragment(order: order), name: "fold-parity-\(order).frag")
            guard w > 0, h > 0, pixels.count == w * h * 4 else { XCTFail("order \(order): no pixels"); continue }
            let group = PointGroup.dihedral(order)
            let wedge = 2 * Double.pi / Double(order)
            var checked = 0, skipped = 0, mismatches: [String] = []
            var cellsSeen = Set<Int>()
            for y in 0..<h {
                for x in 0..<w {
                    // Same cell as the shader: gl_FragCoord is the pixel centre (bottom row first, as glReadPixels).
                    let cx = Int(((Double(x) + 0.5) * Double(Self.grid) / Double(w)).rounded(.down))
                    let cy = Int(((Double(y) + 0.5) * Double(Self.grid) / Double(h)).rounded(.down))
                    let p = Vec2((Double(cx) + 0.5) / Double(Self.grid) * 2 - 1, (Double(cy) + 0.5) / Double(Self.grid) * 2 - 1)
                    let theta = atan2(p.y, p.x)
                    let t = theta - (theta / wedge).rounded(.down) * wedge
                    if t < 1e-3 || wedge - t < 1e-3 { skipped += 1; continue }
                    let f = group.fold(p)
                    let expected = [min(max(f.x * 0.35 + 0.5, 0), 1), min(max(f.y * 0.35 + 0.5, 0), 1)]
                    let i = (y * w + x) * 4
                    let got = [Double(pixels[i]) / 255, Double(pixels[i + 1]) / 255]
                    checked += 1
                    cellsSeen.insert(cy * Self.grid + cx)
                    for c in 0..<2 where abs(got[c] - expected[c]) > Self.tolerance {
                        if mismatches.count < 8 { mismatches.append("(\(x),\(y)) ch\(c): \(got[c]) != \(expected[c])") }
                    }
                }
            }
            XCTAssertTrue(mismatches.isEmpty, "order \(order): shader and CPU fold disagree: \(mismatches)")
            XCTAssertLessThanOrEqual(skipped * Self.grid * Self.grid, 16 * w * h, "order \(order): too many boundary cells skipped")
            XCTAssertGreaterThanOrEqual(cellsSeen.count, Self.grid * Self.grid - 16, "order \(order): grid coverage")
            XCTAssertGreaterThan(checked, 0)
        }
    }

    /// (expected distance, inside) for each of the 8 cases of `sdfFragment`, from the analytic formulas.
    static let sdfCases: [(d: Double, inside: Bool)] = [
        (Vec2(0.2, 0.1).length - 0.5, true),   // circle r 0.5 at (0.2, 0.1)
        (0.1, false),                          // circle r 0.5 at (0.6, 0)
        (-0.05, true),                         // box (0.5, 0.25) at (0.3, -0.2)
        (0.1, false),                          // box (0.5, 0.25) at (0.6, 0)
        (0.05, true),                          // segment (0,0)-(1,0) at (0.5, 0.05), thickness 0.1
        (0.3, false),                          // segment at (0.5, 0.3)
        (0.2, false),                          // segment at (1.2, 0), past the end point
        (-0.25, true),                         // box (0.5, 0.25) at the origin
    ]

    /// Eight columns of cases: red is 1 inside (distance below zero, or below 0.1 for the segment), green is d + 0.5.
    static let sdfFragment = """
    precision highp float;
    #include "vc/sdf.glsl"
    uniform vec2 u_resolution;
    out vec4 color;
    void main() {
        int k = int(floor(gl_FragCoord.x * 8.0 / u_resolution.x));
        float d = 0.0, inside = 0.0;
        if (k == 0) { d = vc_sdCircle(vec2(0.2, 0.1), 0.5); inside = d < 0.0 ? 1.0 : 0.0; }
        else if (k == 1) { d = vc_sdCircle(vec2(0.6, 0.0), 0.5); inside = d < 0.0 ? 1.0 : 0.0; }
        else if (k == 2) { d = vc_sdBox2(vec2(0.3, -0.2), vec2(0.5, 0.25)); inside = d < 0.0 ? 1.0 : 0.0; }
        else if (k == 3) { d = vc_sdBox2(vec2(0.6, 0.0), vec2(0.5, 0.25)); inside = d < 0.0 ? 1.0 : 0.0; }
        else if (k == 4) { d = vc_sdSegment(vec2(0.5, 0.05), vec2(0.0), vec2(1.0, 0.0)); inside = d - 0.1 < 0.0 ? 1.0 : 0.0; }
        else if (k == 5) { d = vc_sdSegment(vec2(0.5, 0.3), vec2(0.0), vec2(1.0, 0.0)); inside = d - 0.1 < 0.0 ? 1.0 : 0.0; }
        else if (k == 6) { d = vc_sdSegment(vec2(1.2, 0.0), vec2(0.0), vec2(1.0, 0.0)); inside = d - 0.1 < 0.0 ? 1.0 : 0.0; }
        else { d = vc_sdBox2(vec2(0.0), vec2(0.5, 0.25)); inside = d < 0.0 ? 1.0 : 0.0; }
        color = vec4(inside, clamp(d + 0.5, 0.0, 1.0), 0.0, 1.0);
    }
    """

    func testShader2DDistanceSignsAndValues() throws {
        let (pixels, w, h) = try render(Self.sdfFragment, name: "sdf2d-signs.frag")
        guard w >= 8, h > 0, pixels.count == w * h * 4 else { return XCTFail("no pixels") }
        let y = h / 2
        for (k, c) in Self.sdfCases.enumerated() {
            // The centre pixel of column k.
            let x = min(w - 1, Int((Double(k) + 0.5) * Double(w) / 8))
            let i = (y * w + x) * 4
            XCTAssertEqual(pixels[i], c.inside ? 255 : 0, "case \(k): sign")
            let green = Double(pixels[i + 1]) / 255
            XCTAssertEqual(green, min(max(c.d + 0.5, 0), 1), accuracy: Self.tolerance, "case \(k): distance")
        }
    }
}
