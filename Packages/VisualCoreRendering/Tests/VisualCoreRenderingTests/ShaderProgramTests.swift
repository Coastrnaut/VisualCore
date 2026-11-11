// ShaderProgramTests — feature 004 T-F310 (US1; SC-F301, FR-F305) and T-F314 (US3). Real ANGLE
// compiles on the simulator; the raw info log is printed so its format is pinned (analyze U1).
import CVisualCoreGL
import VisualCoreShaderSource
import XCTest
@testable import VisualCoreRendering

/// Runs a closure inside setup/render with the context current.
@MainActor
final class ProbeScene: RenderScene {
    var onSetup: (RenderContext) throws -> Void = { _ in }
    var onRender: (RenderContext) throws -> Void = { _ in }
    init(setup: @escaping (RenderContext) throws -> Void = { _ in }, render: @escaping (RenderContext) throws -> Void = { _ in }) {
        onSetup = setup; onRender = render
    }
    func setup(_ context: RenderContext) throws { try onSetup(context) }
    func resize(_ context: RenderContext) {}
    func render(_ context: RenderContext, frame: FrameInfo) throws { try onRender(context) }
    func teardown(_ context: RenderContext) {}
}

@MainActor
final class ShaderProgramTests: XCTestCase {
    static let vertex = """
    out vec2 uv;
    void main() {
        vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
        uv = p;
        gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
    }
    """

    private func host(_ scene: ProbeScene) throws -> RenderHost {
        let h = try RenderHost(scene: scene)
        h.view.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        h.view.layoutIfNeeded()
        return h
    }

    func testCompileErrorInAnIncludedSnippetNamesThatFileAndLine() throws {
        var library = ShaderLibrary()
        library.add("noise.glsl", "float noise(vec2 p) {\n    return undefinedThing(p);\n}")
        var caught: ShaderError?
        let scene = ProbeScene(setup: { ctx in
            do {
                _ = try ctx.resources.program(vertex: Self.vertex,
                                              fragment: "precision mediump float;\n#include \"noise.glsl\"\nin vec2 uv;\nout vec4 c;\nvoid main() { c = vec4(noise(uv)); }",
                                              library: library)
            } catch let e as ShaderError { caught = e }
        })
        let h = try host(scene)
        print("ANGLE raw fragment log: \(ShaderProgram.lastFailureLog)")
        XCTAssertTrue(ShaderProgram.lastFailureLog.contains("ERROR: 0:"), "pins InfoLogParser's format against real ANGLE output")
        guard case .compile(let diagnostics)? = caught else { return XCTFail("expected compile error, got \(String(describing: caught))") }
        let first = try XCTUnwrap(diagnostics.first)
        XCTAssertEqual(first.file, "noise.glsl")
        XCTAssertEqual(first.line, 2)
        XCTAssertEqual(first.stage, .fragment)
        XCTAssertEqual(h.resources.stats.shaderFailures, 1)
    }

    func testFailedReplacementKeepsTheWorkingProgramDrawing() throws {
        var program: ShaderProgram?
        let scene = ProbeScene(setup: { ctx in
            program = try ctx.resources.program(vertex: Self.vertex,
                                                fragment: "precision mediump float;\nout vec4 c;\nvoid main() { c = vec4(0.0, 1.0, 0.0, 1.0); }")
            if let replacement = try? ctx.resources.program(vertex: Self.vertex, fragment: "this is not glsl") {
                program = replacement
            }
        }, render: { _ in
            program?.use()
            vcglDrawArrays(GLenum(GL_TRIANGLES), 0, 3)
        })
        let h = try host(scene)
        XCTAssertNotNil(program)
        XCTAssertTrue(h.renderOneFrame(present: false))
        let p = h.readPixels()
        XCTAssertGreaterThan(Int(p[1]), 250, "the working green program still draws")
        XCTAssertEqual(h.resources.stats.shaderFailures, 1)
    }

    func testLinkFailureIsALinkDiagnostic() throws {
        var caught: ShaderError?
        let scene = ProbeScene(setup: { ctx in
            do {
                _ = try ctx.resources.program(vertex: "out vec3 onlyInVertex;\nvoid main() { onlyInVertex = vec3(1); gl_Position = vec4(0); }",
                                              fragment: "precision mediump float;\nin vec4 onlyInVertex;\nout vec4 c;\nvoid main() { c = onlyInVertex; }")
            } catch let e as ShaderError { caught = e }
        })
        _ = try host(scene)
        guard case .link(let d)? = caught else { return XCTFail("expected link error, got \(String(describing: caught))") }
        XCTAssertFalse(d.isEmpty)
        XCTAssertEqual(d.first?.stage, .link)
    }

    func testSourceErrorsNeverReachTheGPU() throws {
        var caught: ShaderError?
        let scene = ProbeScene(setup: { ctx in
            do { _ = try ctx.resources.program(vertex: Self.vertex, fragment: "#version 100\nvoid main() {}") }
            catch let e as ShaderError { caught = e }
        })
        let h = try host(scene)
        XCTAssertEqual(caught, .source(.unsupportedVersion(file: "fragment", line: 1)))
        XCTAssertEqual(h.resources.stats.liveCount[.shader], 0)
        XCTAssertEqual(h.resources.stats.liveCount[.program], 0)
    }

    func testActiveUniformsAreTabulated() throws {
        var program: ShaderProgram?
        let scene = ProbeScene(setup: { ctx in
            program = try ctx.resources.program(vertex: Self.vertex,
                fragment: "precision mediump float;\nuniform vec3 uColor;\nuniform float uTime;\nout vec4 c;\nvoid main() { c = vec4(uColor * uTime, 1.0); }")
        })
        _ = try host(scene)
        let u = try XCTUnwrap(program).uniforms
        XCTAssertEqual(u["uColor"]?.type, GLenum(GL_FLOAT_VEC3))
        XCTAssertEqual(u["uTime"]?.type, GLenum(GL_FLOAT))
    }
}
