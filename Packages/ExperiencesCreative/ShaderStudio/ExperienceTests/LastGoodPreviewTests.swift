// LastGoodPreviewTests — feature 160 (A22-P02) T-A22-206 (FR-A22-202, FR-A22-204; SC-A22-201, SC-A22-202;
// clarification Q2; contracts/experience.md). Through the one app's session host, drawn off screen at frame time 0:
// after a good run, a compile error, a link error and a refused source each leave the read-back pixels byte-identical
// and report their diagnostics (on the authored line for the compile error) or issues; a first run that fails keeps
// the first template drawn; a fixed run changes the picture and clears the diagnostics; a compile without errors
// replaces the preview, and the status line counts warnings. Short runs only.
import Foundation
import Testing
import ShaderStudioCore
@testable import ShaderStudioExperience
import VisualCoreExperience
import VisualCoreExperienceHost
import VisualCoreRendering
import VisualCoreShaderSource

@MainActor
@Suite(.serialized) struct LastGoodPreviewTests {
    @Test func aBrokenCompileKeepsTheGoodPictureAndNamesTheAuthoredLine() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        try StudioTest.run(session, shell, source: StudioTest.fixedSource)
        #expect(presenter.pipeline.status == .compiled([]))
        let good = try StudioTest.still(session)
        let compiles = presenter.pipeline.compileCount

        try StudioTest.run(session, shell, source: StudioTest.brokenSource)
        #expect(presenter.pipeline.compileCount == compiles + 1)
        guard case .failed(let diagnostics) = presenter.pipeline.status else {
            Issue.record("not failed: \(presenter.pipeline.status)")
            return
        }
        #expect(!diagnostics.isEmpty)
        let errors = diagnostics.filter { $0.severity == .error }
        #expect(errors.contains { $0.file == ShaderAssembly.personFile && $0.line == StudioTest.brokenLine },
                "\(diagnostics)")
        #expect(presenter.mirror.status == "Failed: \(errors.count) " + (errors.count == 1 ? "error" : "errors"))
        #expect(presenter.mirror.diagnostics.contains { DiagnosticMapper.isInPersonSource($0) })
        #expect(StudioControls.diagnosticLines(presenter.mirror).contains { $0.hasPrefix("Line 4: ") })
        #expect(try StudioTest.still(session) == good, "the picture is byte-identical after the failure")
        #expect(presenter.pipeline.liveProject.source == StudioTest.fixedSource)
    }

    @Test func aLinkErrorKeepsTheGoodPicture() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let good = try StudioTest.still(session)
        try StudioTest.run(session, shell, source: StudioTest.linkFailureSource)
        guard case .failed(let diagnostics) = presenter.pipeline.status else {
            Issue.record("not failed: \(presenter.pipeline.status)")
            return
        }
        #expect(diagnostics.contains { $0.severity == .error }, "\(diagnostics)")
        #expect(try StudioTest.still(session) == good)
        #expect(presenter.pipeline.liveProject == ShaderTemplates.all[0].project)
    }

    @Test func aRefusedSourceCompilesNothing() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let good = try StudioTest.still(session)
        let compiles = presenter.pipeline.compileCount
        let programs = try #require(session.renderHost).resources.compileCount
        try StudioTest.run(session, shell, source: StudioTest.refusedSource)
        #expect(presenter.pipeline.status == .refused([.versionLine(1)]))
        #expect(presenter.mirror.status == "Refused: version-line")
        #expect(presenter.pipeline.compileCount == compiles)
        #expect(try #require(session.renderHost).resources.compileCount == programs, "no program was compiled")
        #expect(try StudioTest.still(session) == good)
    }

    @Test func aFirstRunThatFailsKeepsTheFirstTemplate() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let first = try StudioTest.still(session)
        try StudioTest.run(session, shell, source: StudioTest.brokenSource)
        #expect(presenter.pipeline.status.diagnostics.isEmpty == false)
        #expect(presenter.pipeline.liveProject == ShaderTemplates.all[0].project)
        #expect(try StudioTest.still(session) == first, "the first template is still drawn")
    }

    @Test func aFixAfterAFailureChangesThePictureAndClearsTheDiagnostics() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let first = try StudioTest.still(session)
        try StudioTest.run(session, shell, source: StudioTest.brokenSource)
        #expect(!presenter.mirror.diagnostics.isEmpty)
        try StudioTest.run(session, shell, source: StudioTest.fixedSource)
        #expect(presenter.pipeline.status == .compiled([]) && presenter.mirror.status == "Compiled")
        #expect(presenter.mirror.diagnostics.isEmpty)
        let fixed = try StudioTest.still(session)
        #expect(StudioTest.differs(first, fixed), "the new shader is drawn")
        // The flat colour: red 0.9, blue 0.6 (u_speed 1 at the default, green 0.1).
        #expect(abs(Int(fixed[0]) - 230) <= 1 && abs(Int(fixed[2]) - 153) <= 1, "\(fixed[0...3])")
        let host = try #require(session.renderHost)
        #expect(host.resources.stats.leaked == 0)
    }

    @Test func aCompileWithoutErrorsReplacesThePreviewAndTheStatusCountsWarnings() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await StudioTest.open(session)
        let presenter = shell.presenter
        let first = try StudioTest.still(session)
        // Unused locals and an unused function: warnings at most on any compiler, never an error.
        let lenient = """
        uniform float u_speed;
        float unusedHelper(float x) { return x * 2.0; }
        void main() {
            float unusedLocal = 3.0;
            fragColor = vec4(0.2, 0.8 * u_speed, 0.3, 1.0);
        }

        """
        try StudioTest.run(session, shell, source: lenient)
        #expect(presenter.pipeline.status == .compiled([]), "VisualCore reports no log for a program that links")
        #expect(StudioTest.differs(first, try StudioTest.still(session)), "it replaced the preview")
        let warning = MappedDiagnostic(file: ShaderAssembly.personFile, line: 4, severity: .warning, stage: .fragment,
                                       message: "unused variable")
        #expect(PreviewStatus.compiled([warning]).text == "Compiled, 1 warning")
        #expect(PreviewStatus.compiled([warning, warning]).text == "Compiled, 2 warnings")
        #expect(PreviewStatus.compiled([warning]).diagnostics == [warning])
        let error = MappedDiagnostic(file: "unknown", line: nil, severity: .error, stage: .link, message: "x")
        #expect(PreviewStatus.failed([warning, error]).text == "Failed: 1 error")
        #expect(PreviewStatus.waiting.text == "Waiting")
        #expect(StudioPresenter.ordered([warning, error]) == [error, warning], "outside the source first")
        #expect(StudioControls.diagnosticText(warning) == "Line 4: unused variable")
        #expect(StudioControls.diagnosticText(error) == "Shader: x")
    }
}
