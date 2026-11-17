// ValidatorTests — feature 159 (A22-P01) T-A22-105 (FR-A22-103; SC-A22-101; clarification Q2). Every validation
// issue with its code; each limit (source bytes, lines, uniforms, texture inputs) at the limit and one past it; issues
// in source order; comments, precision qualifiers and line-break styles; an empty source gives `no-main`. Synthetic
// data only.
import Foundation
import Testing
import VisualCoreParameters
@testable import ShaderStudioCore

@Suite struct ValidatorTests {
    /// A valid uniform named `name`.
    private static func uniform(_ name: String) throws -> ParameterDefinition {
        try ParameterDefinition(name: name, title: name, range: 0...1, defaultValue: 0.5)
    }

    /// A shader body that compiles with the prelude.
    private static let main = "void main() { fragColor = vec4(v_uv, 0.0, 1.0); }"

    /// The issues of a project with the given parts.
    private static func issues(_ source: String, uniforms: [String] = [], textures: [String] = [],
                               limits: ShaderLimits = .standard) throws -> [ValidationIssue] {
        let project = try ShaderProject(name: "test", source: source, uniforms: uniforms.map(uniform),
                                        limits: limits, textureInputs: textures)
        return ShaderValidator.validate(project)
    }

    /// Limits equal to the standard with one value replaced.
    private static func limits(bytes: Int = 16_384, lines: Int = 400, uniforms: Int = 16,
                               textures: Int = 2) -> ShaderLimits {
        ShaderLimits(maxSourceBytes: bytes, maxLines: lines, maxUniforms: uniforms, maxTextureInputs: textures)
    }

    @Test func validProjectHasNoIssues() throws {
        let source = """
            precision highp float;
            uniform float u_speed;
            uniform  highp  float   u_scale ;
            uniform sampler2D u_image;
            uniform mediump sampler2D u_mask;
            \(Self.main)
            """
        #expect(try Self.issues(source, uniforms: ["u_speed", "u_scale"], textures: ["u_image", "u_mask"]) == [])
        #expect(ShaderValidator.reservedNames == ["u_time", "u_resolution"])
    }

    @Test func emptySourceHasNoMain() throws {
        let issues = try Self.issues("")
        #expect(issues == [.noMain])
        #expect(issues.map(\.code) == ["no-main"])
    }

    @Test func sourceBytesAtAndPastLimit() throws {
        let body = Self.main + "\n"
        let pad = String(repeating: " ", count: 100)
        let atLimit = body + pad
        #expect(try Self.issues(atLimit, limits: Self.limits(bytes: atLimit.utf8.count)) == [])
        let past = atLimit + " "
        let issues = try Self.issues(past, limits: Self.limits(bytes: atLimit.utf8.count))
        #expect(issues == [.sourceTooLarge(past.utf8.count)])
        #expect(issues.first?.code == "source-too-large")
    }

    @Test func linesAtAndPastLimit() throws {
        let at = Array(repeating: "", count: 399).joined(separator: "\n") + "\n" + Self.main
        #expect(ShaderValidator.lines(of: at).count == 400)
        #expect(try Self.issues(at) == [])
        let past = "\n" + at
        let issues = try Self.issues(past)
        #expect(issues == [.tooManyLines(401)])
        #expect(issues.first?.code == "too-many-lines")
    }

    @Test func lineBreakStyles() {
        #expect(ShaderValidator.lines(of: "") == [])
        #expect(ShaderValidator.lines(of: "a") == ["a"])
        #expect(ShaderValidator.lines(of: "a\n") == ["a"])
        #expect(ShaderValidator.lines(of: "a\r\nb\rc\nd") == ["a", "b", "c", "d"])
        #expect(ShaderValidator.lines(of: "a\n\nb") == ["a", "", "b"])
    }

    @Test func uniformsAtAndPastLimit() throws {
        let names = (0..<17).map { "u_p\($0)" }
        func source(_ count: Int) -> String {
            names.prefix(count).map { "uniform float \($0);" }.joined(separator: "\n") + "\n" + Self.main
        }
        #expect(try Self.issues(source(16), uniforms: Array(names.prefix(16))) == [])
        let issues = try Self.issues(source(17), uniforms: names)
        #expect(issues == [.tooManyUniforms(17)])
        #expect(issues.first?.code == "too-many-uniforms")
    }

    @Test func textureInputsAtAndPastLimit() throws {
        let source = "uniform sampler2D u_a;\nuniform sampler2D u_b;\n" + Self.main
        #expect(try Self.issues(source, textures: ["u_a", "u_b"]) == [])
        let one = "uniform sampler2D u_a;\n" + Self.main
        #expect(try Self.issues(one, textures: ["u_a"], limits: Self.limits(textures: 1)) == [])
        let issues = try Self.issues(source, textures: ["u_a", "u_b"], limits: Self.limits(textures: 1))
        #expect(issues == [.tooManyTextureInputs(2)])
        #expect(issues.first?.code == "too-many-texture-inputs")
    }

    @Test func versionLine() throws {
        let issues = try Self.issues("#version 300 es\n" + Self.main + "\n  # version 100")
        #expect(issues == [.versionLine(1), .versionLine(3)])
        #expect(issues.first?.code == "version-line")
        #expect(try Self.issues("// #version 300 es\n/*\n#version 300 es\n*/\n" + Self.main) == [])
    }

    @Test func reservedName() throws {
        let issues = try Self.issues("uniform float u_time;\n" + Self.main, uniforms: ["u_time"])
        #expect(issues == [.reservedName("u_time"), .reservedName("u_time")])
        #expect(issues.first?.code == "reserved-name")
        #expect(try Self.issues("uniform vec2 u_resolution;\n" + Self.main, textures: ["u_resolution"])
                == [.reservedName("u_resolution")])
    }

    @Test func duplicateName() throws {
        let source = "uniform float u_a;\nuniform sampler2D u_b;\n" + Self.main
        let issues = try Self.issues(source, uniforms: ["u_a", "u_a"], textures: ["u_b"])
        #expect(issues == [.duplicateName("u_a")])
        #expect(issues.first?.code == "duplicate-name")
        #expect(try Self.issues("uniform float u_a;\n" + Self.main, uniforms: ["u_a"], textures: ["u_a"])
                == [.duplicateName("u_a"), .undeclaredInSource("u_a")])
    }

    @Test func undeclaredInSource() throws {
        let issues = try Self.issues("// uniform float u_gone;\n" + Self.main, uniforms: ["u_gone"],
                                     textures: ["u_img"])
        #expect(issues == [.undeclaredInSource("u_gone"), .undeclaredInSource("u_img")])
        #expect(issues.first?.code == "undeclared-in-source")
        #expect(try Self.issues("uniform sampler2D u_a;\n" + Self.main, uniforms: ["u_a"])
                == [.undeclaredInProject("u_a"), .undeclaredInSource("u_a")])
    }

    @Test func undeclaredInProject() throws {
        let source = "uniform float u_x;\n" + Self.main + "\nuniform lowp sampler2D u_y;"
        let issues = try Self.issues(source)
        #expect(issues == [.undeclaredInProject("u_x"), .undeclaredInProject("u_y")])
        #expect(issues.first?.code == "undeclared-in-project")
    }

    @Test func noMain() throws {
        #expect(try Self.issues("void mainly() {}") == [.noMain])
        #expect(try Self.issues("/* void main() {} */") == [.noMain])
        #expect(try Self.issues("void\n main () {}") == [])
        #expect(try Self.issues("void  main (void) {}") == [])
    }

    @Test func issuesInOrder() throws {
        let source = "uniform float u_extra;\n#version 300 es\nuniform float u_late;"
        let issues = try Self.issues(source, uniforms: ["u_time", "u_k", "u_k"],
                                     limits: Self.limits(lines: 1, uniforms: 2))
        #expect(issues == [.tooManyLines(3), .tooManyUniforms(3), .reservedName("u_time"), .duplicateName("u_k"),
                           .undeclaredInProject("u_extra"), .versionLine(2), .undeclaredInProject("u_late"),
                           .noMain, .undeclaredInSource("u_k")])
    }

    @Test func everyCodeIsDistinct() {
        let all: [ValidationIssue] = [.sourceTooLarge(1), .tooManyLines(1), .tooManyUniforms(1),
                                      .tooManyTextureInputs(1), .noMain, .versionLine(1), .reservedName("a"),
                                      .duplicateName("a"), .undeclaredInSource("a"), .undeclaredInProject("a")]
        #expect(all.map(\.code) == ["source-too-large", "too-many-lines", "too-many-uniforms",
                                    "too-many-texture-inputs", "no-main", "version-line", "reserved-name",
                                    "duplicate-name", "undeclared-in-source", "undeclared-in-project"])
    }
}
