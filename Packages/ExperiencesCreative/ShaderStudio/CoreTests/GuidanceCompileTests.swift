// GuidanceCompileTests — feature 162 (A22-P04) T-A22-403 (FR-A22-402; SC-A22-401; research R1). Real broken shaders
// are compiled (compile only) on the simulator's ANGLE through `CompileSupport`; the real error message of each maps
// to its specific guidance sentence and never to the general one, and the undeclared name is taken from the message.
import ShaderStudioCore
import Testing

@MainActor
@Suite struct GuidanceCompileTests {
    /// The error messages of compiling `source`.
    private func errorMessages(_ source: String) throws -> [String] {
        let result = try AssemblyCompiler.mappedDiagnostics(of: source)
        #expect(result.otherFailure == nil)
        #expect(!result.linked)
        let messages = result.mapped.filter { $0.severity == .error }.map(\.message)
        #expect(!messages.isEmpty)
        return messages
    }

    @Test func undeclaredIdentifierNamesTheIdentifier() throws {
        let messages = try errorMessages("void main() {\n    fragColor = vec4(v_uv, ss_missingBlue, 1.0);\n}\n")
        let first = try #require(messages.first)
        #expect(Guidance.forDiagnostic(message: first)
            == "Declare ss_missingBlue before it is used, for example `uniform float ss_missingBlue;`.", "\(first)")
    }

    @Test func missingSemicolonIsASyntaxError() throws {
        let messages = try errorMessages("void main() {\n    float a = v_uv.x float b = v_uv.y;\n"
            + "    fragColor = vec4(a, b, 0.5, 1.0);\n}\n")
        let first = try #require(messages.first)
        #expect(Guidance.forDiagnostic(message: first) == Guidance.syntax, "\(first)")
    }

    @Test(arguments: ["float x = vec2(1.0);", "float y = 1;", "vec3 c = vec3(1.0) * vec2(1.0);",
                      "float n = vc_fbm(v_uv, 4.0, 2.0, 0.5);"])
    func typeMismatchIsNamed(_ statement: String) throws {
        let messages = try errorMessages("void main() {\n    \(statement)\n    fragColor = vec4(v_uv, 0.5, 1.0);\n}\n")
        for message in messages {
            #expect(Guidance.forDiagnostic(message: message) == Guidance.typeMismatch, "\(message)")
        }
    }
}
