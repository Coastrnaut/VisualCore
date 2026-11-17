// LineMappingCompileTests — feature 159 (A22-P01) T-A22-107 (FR-A22-104; SC-A22-102; US3; clarifications Q1, Q5;
// research D5). Five broken shaders, one per error class, are compiled off screen inside the template (through
// `ResourceRegistry.program` with `FullScreenShaderScene.vertexSource` and a `ShaderLibrary` of
// `ShaderBundle.visualCoreLibrary` plus the assembly, in a test scene on `RenderHost`); every mapped diagnostic names
// `ss/shader.frag` and the line the fixture was written with the error on. An error inside a test-only include names
// that include and its line, outside the person's source; a valid source gives no diagnostic and links.
//
// The missing-semicolon fixture keeps the next statement on the same line, so the line a compiler reports (the line
// of the token after the missing `;`) is the authored line itself.
import ShaderStudioCore
import Testing
import VisualCoreShaderSource

/// One broken shader and the line of its error, 1-based in the person's source.
struct BrokenFixture: Sendable, CustomStringConvertible {
    let name: String
    let line: Int
    let source: String
    var description: String { name }

    static let all: [BrokenFixture] = [unknownIdentifier, typeMismatch, missingSemicolon, fbmLine, afterBlockComment]

    /// An unknown identifier on line 4.
    static let unknownIdentifier = BrokenFixture(name: "unknown-identifier", line: 4, source: """
    // Unknown identifier on line 4.
    void main() {
        vec3 rgb = vec3(v_uv, 0.5);
        rgb *= ss_undefinedGain;
        fragColor = vec4(rgb, 1.0);
    }

    """)

    /// A type mismatch on line 7 (a vec3 assigned to a float), the spec's example line.
    static let typeMismatch = BrokenFixture(name: "type-mismatch", line: 7, source: """
    // Type mismatch on line 7.
    void main() {
        float a = v_uv.x;
        float b = v_uv.y;
        vec3 rgb = vec3(a, b, 0.5);
        rgb = rgb * 0.5;
        float bad = rgb;
        fragColor = vec4(rgb, bad);
    }

    """)

    /// A missing semicolon on line 3, with the next statement on the same line.
    static let missingSemicolon = BrokenFixture(name: "missing-semicolon", line: 3, source: """
    // Missing semicolon on line 3; the next statement starts on the same line.
    void main() {
        float a = v_uv.x float b = v_uv.y;
        fragColor = vec4(a, b, 0.5, 1.0);
    }

    """)

    /// A wrong call of `vc_fbm(vec2, int, float, float)` (a float octave count) on line 5.
    static let fbmLine = BrokenFixture(name: "vc-fbm-line", line: 5, source: """
    // A wrong vc_fbm call on line 5: the octave count must be an int.
    void main() {
        vec2 p = v_uv * 3.0;
        float t = u_time * 0.1;
        float n = vc_fbm(p + t, 4.0, 2.0, 0.5);
        fragColor = vec4(vec3(0.5 + 0.5 * n), 1.0);
    }

    """)

    /// An undeclared identifier on line 7, after a block comment over lines 1 to 4.
    static let afterBlockComment = BrokenFixture(name: "after-block-comment", line: 7, source: """
    /*
       A block comment
       over four lines.
    */
    void main() {
        vec3 rgb = vec3(v_uv, 0.25);
        fragColor = vec4(rgb, ss_missingAlpha);
    }

    """)
}

@MainActor
@Suite struct LineMappingCompileTests {
    @Test(arguments: BrokenFixture.all)
    func brokenShaderNamesTheAuthoredLine(_ fixture: BrokenFixture) throws {
        let result = try AssemblyCompiler.mappedDiagnostics(of: fixture.source)
        #expect(result.otherFailure == nil, "\(fixture.name): \(result.otherFailure ?? "")")
        #expect(!result.linked, "\(fixture.name) must not link")
        let errors = result.mapped.filter { $0.severity == .error }
        #expect(!errors.isEmpty, "\(fixture.name): no error reported")
        for diagnostic in result.mapped {
            #expect(diagnostic.file == ShaderAssembly.personFile, "\(fixture.name): \(diagnostic)")
            #expect(diagnostic.line == fixture.line, "\(fixture.name): \(diagnostic)")
            #expect(diagnostic.stage == .fragment, "\(fixture.name): \(diagnostic)")
            #expect(DiagnosticMapper.isInPersonSource(diagnostic))
        }
    }

    @Test func fixturesHaveTheErrorOnTheirLine() {
        let markers = ["ss_undefinedGain", "float bad = rgb;", "v_uv.x float", "vc_fbm(p + t, 4.0", "ss_missingAlpha"]
        for (fixture, marker) in zip(BrokenFixture.all, markers) {
            let lines = fixture.source.components(separatedBy: "\n")
            #expect(lines[fixture.line - 1].contains(marker), "\(fixture.name)")
            #expect(lines.filter { $0.contains(marker) }.count == 1, "\(fixture.name)")
        }
    }

    @Test func errorInAnIncludeIsOutsideTheSource() throws {
        let include = "// test include\nvec4 ss_broken(vec2 p) {\n    return p;\n}\n"
        let source = "#include \"test/broken.glsl\"\nvoid main() {\n    fragColor = ss_broken(v_uv);\n}\n"
        let result = try AssemblyCompiler.mappedDiagnostics(of: source, extraFiles: ["test/broken.glsl": include])
        #expect(result.otherFailure == nil)
        #expect(!result.linked)
        let first = try #require(result.mapped.first)
        #expect(first.file == "test/broken.glsl")
        #expect(first.line == 3, "the `return p;` line of the include")
        #expect(first.severity == .error)
        #expect(result.mapped.allSatisfy { $0.file != ShaderAssembly.personFile })
        #expect(result.mapped.allSatisfy { !DiagnosticMapper.isInPersonSource($0) })
    }

    @Test func validSourceHasNoDiagnostics() throws {
        let source = """
        void main() {
            float n = vc_fbm(v_uv * 4.0 + u_time, 3, 2.0, 0.5);
            fragColor = vec4(vc_srgbEncode(vec3(v_uv, 0.5 + 0.5 * n)), 1.0);
        }

        """
        let result = try AssemblyCompiler.mappedDiagnostics(of: source)
        #expect(result.otherFailure == nil)
        #expect(result.raw.isEmpty)
        #expect(result.mapped.isEmpty)
        #expect(result.linked)
    }
}
