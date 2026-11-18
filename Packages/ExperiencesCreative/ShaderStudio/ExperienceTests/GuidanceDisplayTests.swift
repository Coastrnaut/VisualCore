// GuidanceDisplayTests — feature 162 (A22-P04) T-A22-405 (FR-A22-401, FR-A22-402; SC-A22-401; US1 AC1–AC4;
// clarification Q1; contracts/limits.md "Guidance"). Through the one app's session host: a `#version` source is
// refused with its sentence naming the line; a source that uses `u_speed` without declaring it is told to declare it;
// a project uniform missing from the source is named; a broken compile's guidance is under the status and with each
// diagnostics entry; a refusal compiles nothing and leaves the picture byte-identical; a fix clears the guidance.
// Short runs only.
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering

@MainActor
@Suite(.serialized) struct GuidanceDisplayTests {
    /// Runs `source` and checks it is refused with `code` and `guidance`, with nothing compiled and the same picture.
    static func expectRefused(_ source: String, code: String, guidance: String, session: ExperienceSession,
                              shell: ExperienceShell<StudioPresenter>,
                              sourceLocation: SourceLocation = #_sourceLocation) throws {
        let presenter = shell.presenter
        let host = try #require(session.renderHost)
        let before = try StudioTest.still(session)
        let compiles = presenter.pipeline.compileCount
        let programs = host.resources.compileCount
        try StudioTest.run(session, shell, source: source, sourceLocation: sourceLocation)
        #expect(presenter.mirror.status == "Refused: " + code, sourceLocation: sourceLocation)
        #expect(presenter.mirror.guidance == guidance, sourceLocation: sourceLocation)
        let spoken = StudioControls.labels(presenter.mirror).first { $0.name == "guidance" }
        #expect(spoken?.title == guidance, "the guidance is spoken", sourceLocation: sourceLocation)
        #expect(presenter.pipeline.compileCount == compiles && host.resources.compileCount == programs,
                "a refusal compiles nothing", sourceLocation: sourceLocation)
        #expect(try StudioTest.still(session) == before, "the preview is unchanged", sourceLocation: sourceLocation)
    }

    @Test func aVersionLineIsRefusedWithItsSentenceAndLine() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let sentence = Guidance.forIssue(.versionLine(1))
        #expect(sentence.contains("#version") && sentence.contains("line 1"))
        try Self.expectRefused(StudioTest.refusedSource, code: "version-line", guidance: sentence, session: session,
                               shell: shell)
    }

    @Test func aUniformUsedButNotDeclaredIsToldToBeDeclared() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let undeclared = "void main() {\n    fragColor = vec4(u_speed, 0.0, 0.0, 1.0);\n}\n"
        try Self.expectRefused(undeclared, code: "undeclared-in-source",
                               guidance: "Declare u_speed as `uniform float u_speed;` above main.",
                               session: session, shell: shell)
        #expect(shell.presenter.mirror.guidance.hasPrefix("Declare u_speed"))

        let extra = "uniform float u_speed;\nuniform float u_extra;\n"
            + "void main() { fragColor = vec4(u_speed + u_extra); }\n"
        try Self.expectRefused(extra, code: "undeclared-in-project", guidance: Guidance.forIssue(.undeclaredInProject("u_extra")),
                               session: session, shell: shell)
        #expect(shell.presenter.mirror.guidance.contains("u_extra"))
    }

    @Test func aBrokenCompileCarriesItsGuidanceAndAFixClearsIt() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let mirror = shell.presenter.mirror
        #expect(mirror.guidance.isEmpty, "nothing to change after the opening compile")
        try StudioTest.run(session, shell, source: StudioTest.brokenSource)
        #expect(mirror.status.hasPrefix("Failed"))
        let first = try #require(mirror.diagnostics.first { $0.severity == .error })
        #expect(mirror.guidance == Guidance.forDiagnostic(message: first.message))
        #expect(mirror.guidance.contains("undefinedThing"), "the undeclared name is named: \(first.message)")
        #expect(!mirror.diagnostics.isEmpty)
        for diagnostic in mirror.diagnostics {
            let label = StudioEditorLayout.diagnosticLabel(diagnostic)
            #expect(label.hasPrefix(StudioControls.diagnosticText(diagnostic)))
            #expect(label.hasSuffix(Guidance.forDiagnostic(message: diagnostic.message)), "\(label)")
        }
        #expect(StudioControls.labels(mirror).contains { $0.name == "guidance" })

        try StudioTest.run(session, shell, source: StudioTest.fixedSource)
        #expect(mirror.status == "Compiled" && mirror.guidance.isEmpty)
        #expect(!StudioControls.labels(mirror).contains { $0.name == "guidance" })
    }

    @Test func everyStatusHasItsGuidance() {
        let error = MappedDiagnostic(file: "ss/shader.frag", line: 2, severity: .error, stage: .fragment,
                                     message: "syntax error")
        #expect(StudioPresenter.guidance(for: .failed([error]), limits: .standard) == Guidance.syntax)
        #expect(StudioPresenter.guidance(for: .refused([.noMain, .versionLine(3)]), limits: .standard)
                == Guidance.forIssue(.noMain))
        #expect(StudioPresenter.guidance(for: .compiled([]), limits: .standard).isEmpty)
        #expect(StudioPresenter.guidance(for: .waiting, limits: .standard).isEmpty)
        #expect(StudioPresenter.guidance(for: .failed([]), limits: .standard).isEmpty)
    }
}
