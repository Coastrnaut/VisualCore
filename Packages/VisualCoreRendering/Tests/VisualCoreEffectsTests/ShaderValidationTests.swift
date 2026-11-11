// EffectShaderValidationTests — feature 010 T-F905 (FR-F906): every built-in effect fragment compiles and links with
// the shared full-screen vertex shader on the real ANGLE compiler.
import XCTest
@testable import VisualCoreEffects
@testable import VisualCoreRendering

@MainActor
final class EffectShaderValidationTests: XCTestCase {
    func testEveryEffectProgramCompilesAndLinks() throws {
        var results: [String: String] = [:]
        let host = try EffectHarness.run { ctx in
            for (name, fragment) in EffectShaders.fragments {
                do {
                    let p = try ctx.resources.program(vertex: EffectShaders.vertex, fragment: fragment,
                                                      vertexName: "effect.vert", fragmentName: "\(name).frag")
                    results[name] = "ok"
                    ctx.resources.release(p)
                } catch {
                    results[name] = "\(error)"
                }
            }
        }
        defer { host.destroy() }
        XCTAssertEqual(results.count, 10, "every EffectShaders fragment is listed in EffectShaders.fragments")
        for (name, result) in results.sorted(by: { $0.key < $1.key }) { XCTAssertEqual(result, "ok", name) }
    }

    func testEveryPassTypeBuildsItsRunner() throws {
        var failures: [String] = []
        let host = try EffectHarness.run { ctx in
            for type in ["copy", "colorMatrix", "blur", "bloom", "distort", "composite", "feedback", "flashLimit"] {
                do { _ = try EffectRenderer.makeRunner(type: type, registry: ctx.resources) } catch { failures.append("\(type): \(error)") }
            }
        }
        defer { host.destroy() }
        XCTAssertEqual(failures, [])
    }
}
