// OversizedProjectTests — feature 161 (A22-P03) T-A22-306 (FR-A22-302; SC-A22-301; US2 AC1, AC2; clarification Q2;
// contracts/editor.md "Oversized projects"; the phase's regression fixture). Through the one app's session host: a
// source of 16,385 bytes (one past `ShaderLimits.standard.maxSourceBytes`), a project of 17 uniforms (one past
// `maxUniforms`, set through the presenter's `replaceDocument(_:)` test seam) and an empty source are each run and
// refused with their limit's code; the pipeline's `compileCount` and the registry's `ResourceRegistry.compileCount`
// stay unchanged (no GPU program), and the read-back preview stays byte-identical. Short runs only.
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreParameters
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct OversizedProjectTests {
    /// ``StudioTest/fixedSource`` behind a comment line that brings it to exactly `bytes` UTF-8 bytes.
    static func source(bytes: Int) -> String {
        let body = StudioTest.fixedSource
        let padding = bytes - body.utf8.count - "//\n".utf8.count
        return "//" + String(repeating: "x", count: max(padding, 0)) + "\n" + body
    }

    /// Runs `change` then `shader.run` and one frame, and checks the refusal `code` with nothing compiled and the
    /// picture unchanged.
    static func expectRefused(_ code: String, session: ExperienceSession, shell: ExperienceShell<StudioPresenter>,
                              sourceLocation: SourceLocation = #_sourceLocation,
                              _ change: (StudioPresenter) -> Void) throws {
        let presenter = shell.presenter
        let host = try #require(session.renderHost)
        let before = try StudioTest.still(session)
        let compiles = presenter.pipeline.compileCount
        let programs = host.resources.compileCount
        change(presenter)
        StudioTest.accept(shell, "shader.run", [1], sourceLocation: sourceLocation)
        try StudioTest.draw(session)
        #expect(presenter.mirror.status == "Refused: " + code, sourceLocation: sourceLocation)
        guard case .refused(let issues) = presenter.pipeline.status else {
            Issue.record("not refused: \(presenter.pipeline.status)", sourceLocation: sourceLocation)
            return
        }
        #expect(issues.first?.code == code, sourceLocation: sourceLocation)
        #expect(presenter.pipeline.compileCount == compiles, "no compile", sourceLocation: sourceLocation)
        #expect(host.resources.compileCount == programs, "no GPU program", sourceLocation: sourceLocation)
        #expect(try StudioTest.still(session) == before, "the preview is byte-identical",
                sourceLocation: sourceLocation)
    }

    @Test func aSourceOneBytePastTheLimitIsRefused() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let big = Self.source(bytes: ShaderLimits.standard.maxSourceBytes + 1)
        #expect(big.utf8.count == 16_385)
        try Self.expectRefused("source-too-large", session: session, shell: shell) { presenter in
            #expect(presenter.setSource(big))
        }
        #expect(shell.presenter.pipeline.status == .refused([.sourceTooLarge(16_385)]))
    }

    @Test func seventeenUniformsAreRefused() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let uniforms = try (0...ShaderLimits.standard.maxUniforms).map { k in
            try ParameterDefinition(name: "u_p\(k)", title: "P\(k)", range: 0...1, defaultValue: 0.5)
        }
        #expect(uniforms.count == 17)
        let declarations = uniforms.map { "uniform float \($0.name);\n" }.joined()
        let sum = uniforms.map(\.name).joined(separator: " + ")
        let source = declarations + "void main() { fragColor = vec4(vec3(" + sum + "), 1.0); }\n"
        let project = try ShaderProject(name: "Too many", source: source, uniforms: uniforms)
        try Self.expectRefused("too-many-uniforms", session: session, shell: shell) { presenter in
            presenter.replaceDocument(project)
        }
        #expect(shell.presenter.pipeline.status == .refused([.tooManyUniforms(17)]))
    }

    @Test func anEmptySourceIsRefusedAsNoMain() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        try Self.expectRefused("no-main", session: session, shell: shell) { presenter in
            #expect(presenter.setSource(""))
        }
        #expect(shell.presenter.mirror.editor.lines.count == 1, "the empty source is one empty line")
    }
}
