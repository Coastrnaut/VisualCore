// ShaderHashParityTests — feature 203 T-R02F03-013 (FR-R02F03-041, SC-R02F03-005): the shader's vc_pcg and the CPU
// twin ShaderHash.pcg agree bit for bit. Each pixel hashes its index and writes the four bytes of the result into
// RGBA8 (byte / 255 is exact for 8-bit normalized output); the read-back words are compared with the CPU exactly.
import XCTest
import VisualCoreMath
@testable import VisualCoreRendering

@MainActor
final class ShaderHashParityTests: XCTestCase {
    /// The row stride is the surface width in pixels, so the indexes are the read-back order of glReadPixels
    /// (bottom row first, as gl_FragCoord counts) whatever the display scale.
    static let fragment = """
    precision highp float;
    precision highp int;
    #include "vc/hash.glsl"
    uniform vec2 u_resolution;
    out vec4 color;
    void main() {
        uint index = uint(gl_FragCoord.y) * uint(u_resolution.x) + uint(gl_FragCoord.x);
        uint h = vc_pcg(index);
        color = vec4(float(h & 255u), float((h >> 8u) & 255u), float((h >> 16u) & 255u), float(h >> 24u)) / 255.0;
    }
    """

    func testShaderPcgMatchesCPUTwinExactly() throws {
        let scene = FullScreenShaderScene(fragment: Self.fragment, fragmentName: "hash-parity.frag", bundle: ShaderBundle(files: [:]))
        let host = try RenderHost(scene: scene)
        defer { host.destroy() }
        host.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        host.view.layoutIfNeeded()
        XCTAssertTrue(host.renderOneFrame(present: false))
        XCTAssertNil(scene.errorMessage)
        let pixels = host.readPixels()
        let count = host.pixelSize.width * host.pixelSize.height
        XCTAssertGreaterThanOrEqual(count, 64, "at least an 8×8 grid of inputs")
        XCTAssertEqual(pixels.count, count * 4)
        var matches = 0, mismatches: [String] = []
        for index in 0..<min(count, pixels.count / 4) {
            let p = index * 4
            let word = UInt32(pixels[p]) | UInt32(pixels[p + 1]) << 8 | UInt32(pixels[p + 2]) << 16 | UInt32(pixels[p + 3]) << 24
            let expected = ShaderHash.pcg(UInt32(index))
            if word == expected { matches += 1 } else if mismatches.count < 8 { mismatches.append("\(index): \(word) != \(expected)") }
        }
        XCTAssertEqual(matches, count, "shader and CPU disagree: \(mismatches)")
        XCTAssertGreaterThanOrEqual(matches, 64)
    }
}
