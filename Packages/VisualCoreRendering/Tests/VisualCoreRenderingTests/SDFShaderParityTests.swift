// SDFShaderParityTests — feature 211 (R02-F11) T-R02F11-006 (FR-R02F11-003, SC-R02F11-003; research R7): the GLSL that
// SDFShape.glslFunction(name:) emits, with vc/sdf.glsl and vc/sdfshape.glsl, evaluates the same distance as the CPU.
// Three descriptions (a rotated rounded box smooth-unioned with a translated sphere; a box minus a capsule; a plane
// intersected with a scaled, rotated torus unioned with a sphere) are drawn into a 64 × 64 grid of cells (the surface
// may be larger by the display scale; every pixel maps to its cell). (a) Slice: the z = 0 plane over −2…2, red =
// 0.5 + d/8, equals round(CPU × 255) within 2 at every pixel. (b) Marched view: a camera at (0, 0, 4) looking −z with a
// 60° field of view sphere-traces conservatively (128 steps, tolerance 1e-4 · max(1, t), max distance 100) and writes 1
// for a hit; the mask equals the CPU march at every cell whose 3 × 3 CPU neighbourhood is uniform. Every program
// compiles through ResourceRegistry.program on the real context and no GPU object is left after destroy.
import XCTest
import VisualCoreMath
import VisualCoreScenes
@testable import VisualCoreRendering

@MainActor
final class SDFShaderParityTests: XCTestCase {
    /// Cells per side.
    static let grid = 64
    /// The largest allowed difference between the GPU byte and the rounded CPU value.
    static let toleranceBytes = 2
    /// The camera of the marched view.
    static let eye = Vec3(0, 0, 4)
    /// tan(field of view / 2) for the 60° field of view.
    static let halfFieldTan = tan(30.0 * Double.pi / 180)

    /// The three parity descriptions.
    static func shapes() throws -> [(name: String, shape: SDFShape)] {
        let box = try SDFShape.roundedBox(halfExtents: Vec3(0.6, 0.4, 0.5), radius: 0.1)
            .rotated(by: Quat(axis: Vec3(1, 1, 0), angle: 0.6))
        let ball = try SDFShape.sphere(radius: 0.5).translated(by: Vec3(0.8, 0.3, 0))
        let first = try SDFShape.smoothUnion(box, ball, radius: 0.3)
        let second = try SDFShape.subtraction(SDFShape.box(halfExtents: Vec3(0.8, 0.6, 0.5)),
                                              SDFShape.capsule(a: Vec3(-1, -0.2, 0), b: Vec3(1, 0.3, 0.2), radius: 0.25))
        let ring = try SDFShape.torus(major: 0.6, minor: 0.2).rotated(by: Quat(axis: Vec3(1, 0, 0), angle: 1.0))
            .scaled(by: 1.5)
        let third = try SDFShape.intersection([SDFShape.plane(normal: Vec3(0, 1, 0.2), offset: 0.2),
                                               SDFShape.union([ring, SDFShape.sphere(radius: 0.3)])])
        return [("smooth-box-sphere", first), ("box-minus-capsule", second), ("plane-and-scaled-torus", third)]
    }

    /// A fragment around the generated function `sdf`; `body` writes `float c` from the cell centre `uv` in −1…1.
    static func fragment(_ shape: SDFShape, body: String) -> String {
        """
        precision highp float;
        #include "vc/sdf.glsl"
        #include "vc/sdfshape.glsl"
        #define VC_SDF_MAX_STEPS 128
        uniform vec2 u_resolution;
        out vec4 color;
        \(shape.glslFunction(name: "sdf"))
        void main() {
            vec2 cell = floor(gl_FragCoord.xy * \(Double(grid)) / u_resolution);
            vec2 uv = (cell + 0.5) / \(Double(grid)) * 2.0 - 1.0;
            float c = 0.0;
        \(body)
            color = vec4(c, c, c, 1.0);
        }
        """
    }

    static let sliceBody = """
        c = clamp(0.5 + sdf(vec3(uv * 2.0, 0.0)) / 8.0, 0.0, 1.0);
    """

    static let marchBody = """
        vec3 ro = vec3(0.0, 0.0, 4.0);
        vec3 rd = normalize(vec3(uv * \(SDFGLSLLiteral.float(halfFieldTan)), -1.0));
        float t = 0.0;
        for (int i = 0; i < VC_SDF_MAX_STEPS; ++i) {
            float d = sdf(ro + rd * t);
            if (d < 1e-4 * max(1.0, t)) { c = 1.0; break; }
            t += d;
            if (t > 100.0) { break; }
        }
    """

    /// The centre of cell (cx, cy) in −1…1.
    static func uv(_ cx: Int, _ cy: Int) -> (Double, Double) {
        ((Double(cx) + 0.5) / Double(grid) * 2 - 1, (Double(cy) + 0.5) / Double(grid) * 2 - 1)
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

    /// Calls `body` with the cell of every pixel and the pixel's red byte.
    func forEachPixel(_ image: (pixels: [UInt8], width: Int, height: Int), _ body: (Int, Int, Int) -> Void) {
        let (pixels, w, h) = image
        guard w > 0, h > 0, pixels.count == w * h * 4 else { return }
        for y in 0..<h {
            let cy = Int(((Double(y) + 0.5) * Double(Self.grid) / Double(h)).rounded(.down))
            for x in 0..<w {
                let cx = Int(((Double(x) + 0.5) * Double(Self.grid) / Double(w)).rounded(.down))
                body(cx, cy, Int(pixels[(y * w + x) * 4]))
            }
        }
    }

    /// The CPU march (SDFMarch.march, SDFMarchOptions.standard) of the cell's ray: true for a hit, false for a miss, nil when the budget ran out.
    static func cpuHit(_ shape: SDFShape, _ cx: Int, _ cy: Int) -> Bool? {
        let (u, v) = uv(cx, cy)
        let direction = Vec3(u * halfFieldTan, v * halfFieldTan, -1)
        guard let ray = Ray3(origin: eye, direction: direction) else { return nil }
        switch SDFMarch.march(shape, ray: ray, options: .standard).outcome {
        case .hit: return true
        case .miss: return false
        case .budgetExhausted: return nil
        }
    }

    func testSliceMatchesCPUDistance() throws {
        var overall = 0
        for (name, shape) in try Self.shapes() {
            var table = [Int](repeating: 0, count: Self.grid * Self.grid)
            for cy in 0..<Self.grid {
                for cx in 0..<Self.grid {
                    let (u, v) = Self.uv(cx, cy)
                    let d = shape.distance(at: Vec3(u * 2, v * 2, 0))
                    table[cy * Self.grid + cx] = Int((min(max(0.5 + d / 8, 0), 1) * 255).rounded())
                }
            }
            let image = try render(Self.fragment(shape, body: Self.sliceBody), name: "sdf-slice-\(name).frag")
            var worst = 0, count = 0
            forEachPixel(image) { cx, cy, red in
                worst = max(worst, abs(red - table[cy * Self.grid + cx]))
                count += 1
            }
            XCTAssertGreaterThanOrEqual(count, Self.grid * Self.grid, name)
            print("SDFShaderParityTests slice \(name): max error \(worst)/255 over \(count) pixels")
            XCTAssertLessThanOrEqual(worst, Self.toleranceBytes, name)
            overall = max(overall, worst)
        }
        print("SDFShaderParityTests slice: 3 descriptions, max error \(overall)/255")
    }

    func testMarchedMaskMatchesCPUAwayFromEdges() throws {
        var totalCompared = 0, totalMismatched = 0
        for (name, shape) in try Self.shapes() {
            var cpu = [Bool?](repeating: nil, count: Self.grid * Self.grid)
            for cy in 0..<Self.grid {
                for cx in 0..<Self.grid { cpu[cy * Self.grid + cx] = Self.cpuHit(shape, cx, cy) }
            }
            // Cells whose 3 × 3 CPU neighbourhood is uniform (and inside the grid, with no exhausted budget).
            var uniform = [Bool](repeating: false, count: Self.grid * Self.grid)
            var hits = 0
            for cy in 1..<(Self.grid - 1) {
                for cx in 1..<(Self.grid - 1) {
                    guard let centre = cpu[cy * Self.grid + cx] else { continue }
                    var same = true
                    for dy in -1...1 { for dx in -1...1 where cpu[(cy + dy) * Self.grid + cx + dx] != centre { same = false } }
                    uniform[cy * Self.grid + cx] = same
                    if centre { hits += 1 }
                }
            }
            XCTAssertGreaterThan(hits, 0, "\(name): the view shows the shape")
            let image = try render(Self.fragment(shape, body: Self.marchBody), name: "sdf-march-\(name).frag")
            var cellCompared = Set<Int>(), cellMismatched = Set<Int>()
            forEachPixel(image) { cx, cy, red in
                let index = cy * Self.grid + cx
                guard uniform[index], let want = cpu[index] else { return }
                cellCompared.insert(index)
                if (red >= 128) != want { cellMismatched.insert(index) }
            }
            print("SDFShaderParityTests mask \(name): \(cellCompared.count) cells compared, \(cellMismatched.count) mismatched")
            XCTAssertGreaterThan(cellCompared.count, Self.grid * Self.grid / 2, name)
            XCTAssertEqual(cellMismatched.count, 0, name)
            totalCompared += cellCompared.count
            totalMismatched += cellMismatched.count
        }
        print("SDFShaderParityTests mask: 3 descriptions, \(totalCompared) cells compared, \(totalMismatched) mismatched")
    }

    func testGeneratedSourceIsStraightLineGLSL() throws {
        for (name, shape) in try Self.shapes() {
            let source = shape.glslFunction()
            XCTAssertTrue(source.hasPrefix("float vc_sdfShape(vec3 p) {"), name)
            XCTAssertFalse(source.contains("vc_sdfShape(p"), "\(name): no recursion")
            XCTAssertFalse(source.contains("for ("), name)
            // Compiles on the real context with the two includes alone (no leak after destroy).
            let fragment = """
            precision highp float;
            #include "vc/sdf.glsl"
            #include "vc/sdfshape.glsl"
            out vec4 color;
            \(source)
            void main() { color = vec4(vc_sdfShape(vec3(0.0)), 0.0, 0.0, 1.0); }
            """
            _ = try render(fragment, name: "sdf-compile-\(name).frag")
        }
        let first = try Self.shapes()[0].shape.glslFunction(name: "probe")
        print("SDFShaderParityTests generated:\n\(first)")
        XCTAssertTrue(first.contains("mat3("))
        XCTAssertTrue(first.contains("vc_opSmoothUnion("))
    }
}

/// Float literals for the hand-written march body (same rule as the generator: always a decimal point or exponent).
enum SDFGLSLLiteral {
    static func float(_ value: Double) -> String {
        var text = String(format: "%.9g", value)
        if !text.contains(".") && !text.contains("e") { text += ".0" }
        return text
    }
}
