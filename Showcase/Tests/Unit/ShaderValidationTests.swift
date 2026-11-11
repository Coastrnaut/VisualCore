// ShaderValidationTests — feature 010 T-F905 (FR-F906): every bundled Showcase shader compiles and links on the real
// ANGLE compiler; broken.frag (the error demonstration) must fail with its own file name and line.
import XCTest
import VisualCoreRendering
import VisualCoreShaderSource
@testable import Showcase

@MainActor
final class ShaderValidationTests: XCTestCase {
    private final class Probe: RenderScene {
        let body: (RenderContext) -> Void
        init(_ body: @escaping (RenderContext) -> Void) { self.body = body }
        func setup(_ context: RenderContext) throws { body(context) }
        func resize(_ context: RenderContext) {}
        func render(_ context: RenderContext, frame: FrameInfo) throws {}
        func teardown(_ context: RenderContext) {}
    }

    private func compileAll() throws -> [String: Result<Void, Error>] {
        var results: [String: Result<Void, Error>] = [:]
        let files = BundleShaders.files()
        let host = try RenderHost(scene: Probe { ctx in
            guard let vs = files["gradient.vert"] else { return }
            for name in files.keys.sorted() where name.hasSuffix(".frag") {
                do {
                    let p = try ctx.resources.program(vertex: vs, fragment: files[name]!, library: BundleShaders.library(),
                                                      vertexName: "gradient.vert", fragmentName: name)
                    ctx.resources.release(p)
                    results[name] = .success(())
                } catch { results[name] = .failure(error) }
            }
        })
        host.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        host.view.layoutIfNeeded()
        _ = host.renderOneFrame(present: false)
        host.destroy()
        return results
    }

    func testEveryBundledShaderCompilesExceptTheBrokenDemo() throws {
        let files = BundleShaders.files()
        XCTAssertNotNil(files["gradient.vert"])
        let results = try compileAll()
        let fragments = Set(files.keys.filter { $0.hasSuffix(".frag") })
        XCTAssertEqual(Set(results.keys), fragments)
        XCTAssertTrue(fragments.isSuperset(of: ["gradient.frag", "stripes.frag", "ripple.frag", "broken.frag"]))
        for (name, result) in results where name != "broken.frag" {
            if case .failure(let e) = result { XCTFail("\(name): \(e)") }
        }
        guard case .failure(let error)? = results["broken.frag"], case .compile(let diags) = error as? ShaderError else {
            return XCTFail("broken.frag must fail to compile")
        }
        XCTAssertEqual(diags.first?.file, "broken.frag")
        XCTAssertEqual(diags.first?.line, 5)
    }
}
