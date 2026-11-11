// ShaderBundleTests — feature 012 T-A01-104: the VisualCore GLSL library ships with the package and every include
// compiles (alone and together, thanks to include guards) on the real ANGLE compiler.
import XCTest
import VisualCoreShaderSource
@testable import VisualCoreRendering

@MainActor
final class ShaderBundleTests: XCTestCase {
    static let includes = ["vc/hash.glsl", "vc/noise.glsl", "vc/palette.glsl", "vc/sdf.glsl", "vc/color.glsl", "vc/field.glsl"]

    func testLibraryIsBundled() {
        XCTAssertEqual(Set(ShaderBundle.visualCoreLibrary.keys), Set(Self.includes))
        let bundle = ShaderBundle(files: ["a.frag": "void main() {}", "b.glsl": "float b() { return 1.0; }"])
        XCTAssertEqual(bundle.names, ["a.frag", "b.glsl"])
        XCTAssertNil(bundle.source("vc/hash.glsl"), "library includes are not app files")
        for name in Self.includes { XCTAssertTrue(bundle.library.contains(name), name) }
    }

    func testEveryIncludeCompilesAloneAndTogether() throws {
        var bodies: [String: String] = [:]
        for name in Self.includes {
            bodies[name] = "precision highp float;\n#include \"\(name)\"\nout vec4 color;\nvoid main() { color = vec4(1.0); }\n"
        }
        bodies["all"] = "precision highp float;\n" + (Self.includes + Self.includes).map { "#include \"\($0)\"" }.joined(separator: "\n") + """

        in vec2 v_uv;
        out vec4 color;
        void main() {
            float n = vc_fbm(v_uv * 4.0, 5, 2.0, 0.5) + vc_valueNoise(v_uv) + vc_hash21(v_uv);
            float d = vc_smoothUnion(vc_sdSphere(vec3(v_uv, 0.0), 0.5), vc_sdBox(vec3(v_uv, 0.0), vec3(0.2)), 0.1) + vc_sdTorus(vec3(v_uv, 0.0), vec2(0.3, 0.1));
            color = vec4(vc_srgbEncode(vc_palette(n) + vc_srgbDecode(vec3(d))), 1.0);
        }
        """
        let bundle = ShaderBundle(files: [:])
        var failures: [String] = []
        let host = try RenderHost(scene: ProbeScene(setup: { ctx in
            for (name, body) in bodies {
                do { ctx.resources.release(try ctx.resources.program(vertex: FullScreenShaderScene.vertexSource, fragment: body,
                                                                      library: bundle.library, fragmentName: "probe-\(name.replacingOccurrences(of: "/", with: "-")).frag")) }
                catch { failures.append("\(name): \(error)") }
            }
        }))
        host.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        host.view.layoutIfNeeded()
        _ = host.renderOneFrame(present: false)
        host.destroy()
        XCTAssertEqual(failures, [])
    }
}
