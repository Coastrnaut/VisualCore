// SkyShaderTests — feature 218 (R02-F18) T-R02F18-005 (FR-R02F18-005, 006; SC-R02F18-004, 005; clarification Q4; research R5, R6).
// vc/sky.glsl equals the CPU reference SkyModel. Each pixel of a 64 point view belongs to a cell of a 64 × 64 grid
// (cell = floor(gl_FragCoord · 64 / resolution), the SpectralShaderTests sampling rule); the cell centre gives an
// equirectangular direction: azimuth = (x + ½)/64 · 2π, elevation = ((y + ½)/64 − ½) · π, d = (cos el · cos az,
// sin el, cos el · sin az). vc_sky runs with the default SkyParameters as literals for nine sun positions from below
// the horizon to the zenith (eight at elevations −0.6, −0.2, −0.05, 0, 0.05, 0.3, 0.8 and π/2 rad, azimuth 0.3, plus
// one aimed exactly at a cell centre so the sun disc itself is compared); every GPU byte is compared with
// round(SkyModel × 255) within 2 per channel, with no pixel excluded. No cell centre lies in the disc's 0.004 rad
// smoothstep band (for the eight placed suns the nearest centre is 0.0245 rad away, beyond the band's outer edge
// r + 0.004 = 0.0133; the aimed sun sits on its cell's centre, deep inside the disc), so the float/double difference of
// that very steep ramp (d·s spans only 4.5e-5 across it) cannot show. No GPU object is left after destroy.
import Foundation
import VisualCoreMath
import VisualCoreScenes
import XCTest
@testable import VisualCoreRendering

@MainActor
final class SkyShaderTests: XCTestCase {
    /// Cells per side.
    static let grid = 64
    /// The largest allowed difference between the GPU byte and the rounded CPU value.
    static let toleranceBytes = 2

    /// A GLSL float literal.
    static func literal(_ v: Double) -> String {
        var text = String(v)
        if !text.contains(".") && !text.contains("e") { text += ".0" }
        return text
    }

    /// A GLSL vec3 literal.
    static func literal(_ v: Vec3) -> String { "vec3(\(literal(v.x)), \(literal(v.y)), \(literal(v.z)))" }

    /// The direction of cell (x, y) (formula in the file header), in Double.
    static func direction(_ x: Int, _ y: Int) -> Vec3 {
        let n = Double(grid)
        let azimuth = (Double(x) + 0.5) / n * 2 * Double.pi
        let elevation = ((Double(y) + 0.5) / n - 0.5) * Double.pi
        return Vec3(cos(elevation) * cos(azimuth), sin(elevation), cos(elevation) * sin(azimuth))
    }

    /// The unit sun direction at `elevation` and `azimuth`.
    static func sun(elevation: Double, azimuth: Double) -> Vec3 {
        Vec3(cos(elevation) * cos(azimuth), sin(elevation), cos(elevation) * sin(azimuth))
    }

    /// A fragment that computes the direction of the pixel's cell and writes vc_sky with `parameters` and `sun`.
    static func fragment(sun: Vec3, parameters p: SkyParameters) -> String {
        let n = literal(Double(grid))
        return """
        precision highp float;
        #include "vc/sky.glsl"
        uniform vec2 u_resolution;
        out vec4 color;
        void main() {
            vec2 cell = floor(gl_FragCoord.xy * \(n) / u_resolution);
            float azimuth = (cell.x + 0.5) / \(n) * 6.283185307179586;
            float elevation = ((cell.y + 0.5) / \(n) - 0.5) * 3.141592653589793;
            vec3 d = vec3(cos(elevation) * cos(azimuth), sin(elevation), cos(elevation) * sin(azimuth));
            vec3 o = vc_sky(d, \(literal(sun)), \(literal(p.zenith)), \(literal(p.horizon)), \(literal(p.ground)),
                            \(literal(p.dusk)), \(literal(p.night)), \(literal(p.sunColour)),
                            vec3(\(literal(p.sunRadius)), \(literal(p.glowStrength)), \(literal(p.glowExponent))));
            color = vec4(o, 1.0);
        }
        """
    }

    /// Renders `fragment` into a 64 point view, checks for no compile error and no leak after destroy, and returns the
    /// RGBA8 pixels (bottom row first) with the surface size.
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

    /// The largest |GPU byte − round(SkyModel × 255)| over every pixel and channel for `sun`, with the cell where it
    /// occurs.
    func maxError(sun: Vec3, name: String) throws -> (error: Int, cell: (Int, Int)) {
        let parameters = SkyParameters()
        let (pixels, w, h) = try render(Self.fragment(sun: sun, parameters: parameters), name: name)
        guard w > 0, h > 0, pixels.count == w * h * 4 else { return (Int.max, (-1, -1)) }
        var table = [SIMD3<Int>](repeating: .zero, count: Self.grid * Self.grid)
        for cy in 0..<Self.grid {
            for cx in 0..<Self.grid {
                let v = try SkyModel.colour(direction: Self.direction(cx, cy), sun: sun, parameters: parameters)
                table[cy * Self.grid + cx] = SIMD3(Int((v.x * 255).rounded()), Int((v.y * 255).rounded()),
                                                   Int((v.z * 255).rounded()))
            }
        }
        var worst = 0, worstCell = (0, 0)
        for y in 0..<h {
            let cy = Int(((Double(y) + 0.5) * Double(Self.grid) / Double(h)).rounded(.down))
            for x in 0..<w {
                let cx = Int(((Double(x) + 0.5) * Double(Self.grid) / Double(w)).rounded(.down))
                let want = table[cy * Self.grid + cx], i = (y * w + x) * 4
                for c in 0..<3 {
                    let error = abs(Int(pixels[i + c]) - want[c])
                    if error > worst { worst = error; worstCell = (cx, cy) }
                }
            }
        }
        print("SkyShaderTests \(name): max error \(worst)/255 at cell \(worstCell)")
        return (worst, worstCell)
    }

    func testSkyMatchesReferenceForEverySunPosition() throws {
        let elevations: [Double] = [-0.6, -0.2, -0.05, 0, 0.05, 0.3, 0.8]
        var suns: [(String, Vec3)] = []
        for elevation in elevations { suns.append(("el\(elevation)", Self.sun(elevation: elevation, azimuth: 0.3))) }
        suns.append(("zenith", Vec3(0, 1, 0)))
        suns.append(("at-cell-10-40", Self.direction(10, 40)))
        XCTAssertGreaterThanOrEqual(suns.count, 8)
        for (name, sun) in suns {
            let (error, cell) = try maxError(sun: sun, name: name)
            XCTAssertLessThanOrEqual(error, Self.toleranceBytes, "\(name): worst cell \(cell)")
        }
    }

    func testSunDiscIsDrawnAtItsCell() throws {
        // The sun aimed at a cell centre: that cell is saturated by the disc (1 + glow, clamped), so every channel is
        // 255 on the GPU as in the reference.
        let sun = Self.direction(10, 40)
        let reference = try SkyModel.colour(direction: sun, sun: sun, parameters: SkyParameters())
        XCTAssertEqual(reference, Vec3(1, 1, 1))
        let (pixels, w, h) = try render(Self.fragment(sun: sun, parameters: SkyParameters()), name: "disc")
        let x = Int((10.5 * Double(w) / Double(Self.grid)).rounded(.down))
        let y = Int((40.5 * Double(h) / Double(Self.grid)).rounded(.down))
        let i = (y * w + x) * 4
        XCTAssertEqual([pixels[i], pixels[i + 1], pixels[i + 2]], [255, 255, 255])
    }
}
