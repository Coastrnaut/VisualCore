// ClueShaderTests — feature 210 (R02-F10) T-R02F10-005 (FR-R02F10-007, FR-R02F10-013; research R6): vc/clue.glsl draws
// every shape × pattern (and the outline band) exactly as the CPU reference ClueReference. Each case renders a 64 × 64
// grid of cells (the surface may be larger by the display scale; every pixel maps to its cell) with the cell centre
// mapped to p in −1…1 (y up) and aa = 1.5/32; the coverage is written to every channel and compared with
// round(ClueReference × 255) within 2 at every pixel. Compiles alone and with vc/sdf.glsl and vc/color.glsl; no GPU
// object is left after destroy.
import XCTest
import VisualCoreParameters
@testable import VisualCoreRendering

@MainActor
final class ClueShaderTests: XCTestCase {
    /// Cells per side.
    static let grid = 64
    /// The soft-edge half width: 1.5 cells (a cell is 2/64 = 1/32 cell units).
    static let antialias = 1.5 / 32.0
    /// The largest allowed difference between the GPU byte and the rounded CPU value.
    static let toleranceBytes = 2

    /// A fragment that writes `expression` (a float of `p`) to every channel; `includes` precede it.
    static func fragment(includes: [String], expression: String) -> String {
        """
        precision highp float;
        \(includes.map { "#include \"\($0)\"" }.joined(separator: "\n"))
        uniform vec2 u_resolution;
        out vec4 color;
        void main() {
            vec2 cell = floor(gl_FragCoord.xy * \(Double(grid)) / u_resolution);
            vec2 p = (cell + 0.5) / \(Double(grid)) * 2.0 - 1.0;
            float c = \(expression);
            color = vec4(c, c, c, 1.0);
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

    /// The largest |GPU byte − round(expected × 255)| over every pixel and channel, `expected` evaluated per cell centre.
    func maxError(_ image: (pixels: [UInt8], width: Int, height: Int), expected: (SIMD2<Double>) -> Double) -> Int {
        let (pixels, w, h) = image
        guard w > 0, h > 0, pixels.count == w * h * 4 else { return Int.max }
        var table = [Int](repeating: 0, count: Self.grid * Self.grid)
        for cy in 0..<Self.grid {
            for cx in 0..<Self.grid {
                let p = SIMD2((Double(cx) + 0.5) / Double(Self.grid) * 2 - 1, (Double(cy) + 0.5) / Double(Self.grid) * 2 - 1)
                table[cy * Self.grid + cx] = Int((min(max(expected(p), 0), 1) * 255).rounded())
            }
        }
        var worst = 0
        for y in 0..<h {
            let cy = Int(((Double(y) + 0.5) * Double(Self.grid) / Double(h)).rounded(.down))
            for x in 0..<w {
                let cx = Int(((Double(x) + 0.5) * Double(Self.grid) / Double(w)).rounded(.down))
                let want = table[cy * Self.grid + cx], i = (y * w + x) * 4
                for c in 0..<3 { worst = max(worst, abs(Int(pixels[i + c]) - want)) }
            }
        }
        return worst
    }

    func testEveryShapeAndPatternMatchesReference() throws {
        var overall = 0, cases = 0
        for shape in ClueShape.allCases {
            for pattern in CluePattern.allCases {
                let expression = "vc_clueCoverage(p, \(shape.rawValue), \(pattern.rawValue), \(Self.antialias))"
                let source = Self.fragment(includes: ["vc/sdf.glsl", "vc/color.glsl", "vc/clue.glsl"], expression: expression)
                let image = try render(source, name: "clue-\(shape.rawValue)-\(pattern.rawValue).frag")
                let error = maxError(image) { p in
                    ClueReference.coverage(shape: shape, pattern: pattern, at: p, antialias: Self.antialias)
                }
                print("ClueShaderTests coverage \(shape) × \(pattern): max error \(error)/255")
                XCTAssertLessThanOrEqual(error, Self.toleranceBytes, "\(shape) × \(pattern)")
                overall = max(overall, error)
                cases += 1
            }
        }
        XCTAssertEqual(cases, 32)
        print("ClueShaderTests coverage: \(cases) cases, max error \(overall)/255")
    }

    func testOutlineBandMatchesReferenceWithClueAlone() throws {
        let width = 0.12
        var overall = 0
        for shape in ClueShape.allCases {
            let expression = "vc_clueOutline(p, \(shape.rawValue), \(width), \(Self.antialias))"
            let image = try render(Self.fragment(includes: ["vc/clue.glsl"], expression: expression),
                                   name: "clue-outline-\(shape.rawValue).frag")
            let error = maxError(image) { p in
                ClueReference.outline(shape: shape, at: p, width: width, antialias: Self.antialias)
            }
            print("ClueShaderTests outline \(shape): max error \(error)/255")
            XCTAssertLessThanOrEqual(error, Self.toleranceBytes, "outline \(shape)")
            overall = max(overall, error)
        }
        print("ClueShaderTests outline: 8 cases, max error \(overall)/255")
    }
}
