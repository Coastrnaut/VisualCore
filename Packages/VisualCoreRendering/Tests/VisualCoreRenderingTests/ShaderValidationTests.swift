// ShaderValidationTests — feature 010 T-F905 (FR-F906): every built-in VisualCoreRendering program compiles and links
// with the real ANGLE compiler, and an invalid source fails with stage, file and line diagnostics.
import CVisualCoreGL
import XCTest
@testable import VisualCoreRendering

@MainActor
final class ShaderValidationTests: XCTestCase {
    /// Built-in programs (vertex, fragment) by owner. A new built-in program must be added here.
    static let builtIns: [(String, String, String)] = [
        ("GradientQuadScene", GradientQuadScene.vertexSource, GradientQuadScene.fragmentSource),
        ("PrimitiveRenderer", PrimitiveRenderer.vertexSource, PrimitiveRenderer.fragmentSource),
        ("ParticleRenderer", ParticleRenderer.vertexSource, ParticleRenderer.fragmentSource),
        ("MeshRenderer", MeshRenderer.vertexSource, MeshRenderer.fragmentSource),
    ]

    private func withContext(_ body: @escaping (RenderContext) throws -> Void) throws -> RenderHost {
        let h = try RenderHost(scene: ProbeScene(setup: body))
        h.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        h.view.layoutIfNeeded()
        _ = h.renderOneFrame(present: false)
        return h
    }

    func testEveryBuiltInProgramCompilesAndLinks() throws {
        var results: [String: String] = [:]
        let host = try withContext { ctx in
            for (name, v, f) in Self.builtIns {
                do {
                    let p = try ctx.resources.program(vertex: v, fragment: f, vertexName: "\(name).vert", fragmentName: "\(name).frag")
                    results[name] = p.name != 0 ? "ok" : "no program"
                    ctx.resources.release(p)
                } catch {
                    results[name] = "\(error)"
                }
            }
        }
        defer { host.destroy() }
        XCTAssertEqual(results.count, Self.builtIns.count)
        for (name, result) in results.sorted(by: { $0.key < $1.key }) { XCTAssertEqual(result, "ok", name) }
        XCTAssertEqual(host.resources.stats.leaked, 0)
    }

    func testInvalidFragmentFailsWithFileAndLine() throws {
        var caught: Error?
        let host = try withContext { ctx in
            do {
                _ = try ctx.resources.program(vertex: GradientQuadScene.vertexSource,
                                              fragment: "precision mediump float;\nout vec4 c;\nvoid main() {\n    c = vec4(nope, 1.0);\n}\n",
                                              vertexName: "ok.vert", fragmentName: "bad.frag")
            } catch { caught = error }
        }
        defer { host.destroy() }
        guard case .compile(let diags)? = caught as? ShaderError else { return XCTFail("expected compile error, got \(String(describing: caught))") }
        let first = try XCTUnwrap(diags.first)
        XCTAssertEqual(first.file, "bad.frag")
        XCTAssertEqual(first.line, 4)
        XCTAssertEqual(first.stage, .fragment)
    }
}
