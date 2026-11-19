// ShaderBindingTests — feature 206 T-R02F06-007 (US4; SC-R02F06-004, FR-R02F06-006, FR-R02F06-007): declared uniform
// layouts checked against real ANGLE reflection, and parameter values bound to `u_<name>` uniforms read back with
// glGetUniformfv before and after a context rebuild; non-finite values refused with nothing set.
import CVisualCoreGL
import VisualCoreShaderSource
import XCTest
@testable import VisualCoreParameters
@testable import VisualCoreRendering

@MainActor
final class ShaderBindingTests: XCTestCase {
    static let layoutFragment = """
    precision mediump float;
    uniform float u_a;
    uniform vec3 u_b;
    uniform sampler2D u_c;
    uniform float u_arr[4];
    in vec2 uv;
    out vec4 c;
    void main() { c = vec4(u_b * u_a * u_arr[2], 1.0) + texture(u_c, uv); }
    """

    static let paramFragment = """
    precision highp float;
    uniform float u_gain;
    uniform float u_speed;
    out vec4 c;
    void main() { c = vec4(u_gain, u_speed, 0.0, 1.0); }
    """

    private func schema() throws -> ParameterSchema {
        try ParameterSchema([
            ParameterDefinition(name: "gain", title: "Gain", range: 0...2, defaultValue: 1),
            ParameterDefinition(name: "speed", title: "Speed", range: 0.1...10, defaultValue: 1, transform: .logarithmic),
            ParameterDefinition(name: "ghost", title: "Ghost", range: 0...1, defaultValue: 0.5),
        ])
    }

    private func readBack(_ program: ShaderProgram, _ uniform: String) -> Float {
        var value: Float = .nan
        let location = program.uniforms[uniform]?.location ?? -1
        vcglGetUniformfv(program.name, location, &value)
        return value
    }

    // MARK: Layouts (FR-R02F06-006)

    func testLayoutErrorsAndUnusedDeclarations() throws {
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var program: ShaderProgram?
        try withContext(host, scene) { context in
            program = try context.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.layoutFragment)
        }
        let p = try XCTUnwrap(program)
        XCTAssertEqual(p.activeUniformTypes, ["u_a": .float, "u_b": .vec3, "u_c": .sampler2D, "u_arr": .float])

        let faulty = try UniformLayout([UniformDeclaration(name: "u_a", type: .float),
                                        UniformDeclaration(name: "u_b", type: .vec2),
                                        UniformDeclaration(name: "u_arr", type: .float),
                                        UniformDeclaration(name: "u_gone", type: .float)])
        let report = p.check(faulty)
        XCTAssertEqual(report.undeclared, ["u_c"])
        XCTAssertEqual(report.mistyped, [UniformMismatch(name: "u_b", declared: .vec2, actual: .vec3)])
        XCTAssertEqual(report.unused, ["u_gone"])
        XCTAssertFalse(report.isValid)
        XCTAssertEqual(report.reasonCode, .uniformUndeclared)

        let exact = try UniformLayout([UniformDeclaration(name: "u_a", type: .float),
                                       UniformDeclaration(name: "u_b", type: .vec3),
                                       UniformDeclaration(name: "u_c", type: .sampler2D),
                                       UniformDeclaration(name: "u_arr", type: .float)])
        XCTAssertTrue(p.check(exact).isValid)
        XCTAssertNil(p.check(exact).reasonCode)

        let mistypedOnly = try UniformLayout(exact.declarations.map {
            $0.name == "u_c" ? UniformDeclaration(name: "u_c", type: .samplerCube) : $0
        })
        XCTAssertEqual(p.check(mistypedOnly).reasonCode, .uniformType)
    }

    func testGLTypeMapping() {
        XCTAssertEqual(ShaderProgram.uniformType(glType: GLenum(GL_FLOAT_MAT4)), .mat4)
        XCTAssertEqual(ShaderProgram.uniformType(glType: GLenum(GL_INT_VEC3)), .ivec3)
        XCTAssertEqual(ShaderProgram.uniformType(glType: GLenum(GL_BOOL)), .bool)
        XCTAssertEqual(ShaderProgram.uniformType(glType: GLenum(GL_SAMPLER_3D)), .sampler3D)
        XCTAssertEqual(ShaderProgram.uniformType(glType: 0x8B5A), .other(0x8B5A), "GL_FLOAT_MAT2 is not mapped")
    }

    // MARK: Parameter binding (FR-R02F06-007, SC-R02F06-004)

    func testValuesReadBackClampedBeforeAndAfterContextRebuild() throws {
        let schema = try schema()
        let resolved = try schema.resolve(["gain": 5, "speed": 0.5])   // gain is clamped to 2
        let unclamped = ResolvedParameters(values: ["gain": -3, "speed": 50, "ghost": 0.25], warnings: [])
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        var before: [Float] = [], after: [Float] = []
        try withContext(host, scene) { context in
            let program = try context.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.paramFragment)
            let binding = ParameterUniformBinding(schema: schema, program: program)
            XCTAssertEqual(binding.unused, ["ghost"])
            XCTAssertEqual(Set(binding.bound.keys), ["gain", "speed"])
            program.use()
            try binding.apply(resolved)
            before = [self.readBack(program, "u_gain"), self.readBack(program, "u_speed")]
            try binding.apply(unclamped)   // the binding clamps through the schema itself
            XCTAssertEqual([self.readBack(program, "u_gain"), self.readBack(program, "u_speed")], [0, 10])
        }
        XCTAssertEqual(before, [2, 0.5])
        host.recreateContext()
        try withContext(host, scene) { context in
            let program = try context.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.paramFragment)
            XCTAssertEqual(program.generation, context.resources.generation)
            let binding = ParameterUniformBinding(schema: schema, program: program)
            program.use()
            try binding.apply(resolved)
            after = [self.readBack(program, "u_gain"), self.readBack(program, "u_speed")]
        }
        XCTAssertEqual(after, before, "the same values give the same uniforms after the rebuild")
    }

    func testNonFiniteValueIsRefusedWithNothingSet() throws {
        let schema = try schema()
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let program = try context.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.paramFragment)
            let binding = ParameterUniformBinding(schema: schema, program: program)
            program.use()
            try binding.apply(ResolvedParameters(values: ["gain": 1, "speed": 0.5], warnings: []))
            for bad in [Double.nan, .infinity, -.infinity] {
                // gain comes first in the schema: a binding that set before checking would change it.
                let values = ResolvedParameters(values: ["gain": 1.5, "speed": bad], warnings: [])
                XCTAssertThrowsError(try binding.apply(values)) { error in
                    XCTAssertEqual(error as? ParameterBindingError, .notFinite("speed"))
                    XCTAssertEqual((error as? ParameterBindingError)?.reasonCode, .parameterNotFinite)
                }
                XCTAssertEqual(self.readBack(program, "u_gain"), 1, "nothing set for \(bad)")
                XCTAssertEqual(self.readBack(program, "u_speed"), 0.5, "nothing set for \(bad)")
            }
        }
    }

    func testUnusedParameterIsReportedOnce() throws {
        let schema = try schema()
        let scene = ClosureScene()
        let host = try makeFieldHost(scene)
        defer { host.destroy() }
        try withContext(host, scene) { context in
            let program = try context.resources.program(vertex: ShaderProgramTests.vertex, fragment: Self.paramFragment)
            program.use()
            for _ in 0..<3 {
                let binding = ParameterUniformBinding(schema: schema, program: program)
                XCTAssertEqual(binding.unused, ["ghost"])
                try binding.apply(schema.resolve([:]))
            }
            let ghostWarnings = context.resources.stats.warnings.filter { $0.contains("ghost") }
            XCTAssertEqual(ghostWarnings.count, 1, "\(context.resources.stats.warnings)")
        }
    }
}
