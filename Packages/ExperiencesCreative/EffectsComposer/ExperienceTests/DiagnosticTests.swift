// DiagnosticTests — feature 181 (A25-P02) T-A25-208 (FR-A25-205; SC-A25-204; clarification Q4). A broken program is
// reported, not fatal: with the test seam `programOverride` giving Blur a program that does not build, setup yields
// exactly one diagnostic naming Blur and a line, the controls' diagnostics line reads "Blur, line <n>: …", a chain
// without Blur still draws, and adding Blur leaves the preview on the last good picture until Blur is removed again.
import EffectsComposerCore
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import EffectsComposerExperience

@MainActor
@Suite(.serialized) struct DiagnosticTests {
    @Test func aBrokenProgramGivesOneDiagnosticAndKeepsTheLastGoodPicture() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session) { presenter in
            presenter.programOverride = [.blur: ComposerTest.broken(.blur)]
        }
        let presenter = shell.presenter
        #expect(presenter.diagnostics.count == 1)
        let diagnostic = try #require(presenter.diagnostics.first)
        #expect(diagnostic.effect == .blur)
        #expect(diagnostic.line > 0, "\(diagnostic)")
        #expect(!diagnostic.message.isEmpty)
        #expect(presenter.mirror.diagnostics.hasPrefix("Blur, line \(diagnostic.line): "), "\(presenter.mirror.diagnostics)")
        print("DiagnosticTests: \(presenter.mirror.diagnostics)")

        ComposerTest.accept(shell, "chain.add", [0, 0])
        ComposerTest.accept(shell, "chain.add", [3, 1])
        try ComposerTest.draw(session)
        let good = try #require(presenter.lastResult)
        let goodChain = try ComposerTest.core(shell).chain
        #expect(good.maxChannelDifference(ComposerTest.reference(goodChain)) <= 2)
        let renders = presenter.renderer.renderCount

        ComposerTest.accept(shell, "chain.add", [1, 1])
        try ComposerTest.draw(session)
        try ComposerTest.draw(session)
        #expect(presenter.renderer.blocked)
        #expect(presenter.lastResult == good, "the preview keeps the last good picture")
        #expect(presenter.renderer.renderCount == renders, "nothing was drawn with the broken program")
        #expect(presenter.diagnostics.count == 1)
        #expect(session.renderHost != nil)

        ComposerTest.accept(shell, "chain.remove", [1])
        try ComposerTest.draw(session)
        #expect(!presenter.renderer.blocked)
        #expect(presenter.lastResult == good, "the chain without Blur draws again")
        #expect(presenter.renderer.renderCount == renders + 1)
    }

    @Test func aCompileTextIsParsedIntoEffectLineAndMessage() {
        let parsed = ProgramDiagnostic.parse("a25-blur.frag:7: 'undeclaredName' : undeclared identifier", effect: .blur)
        #expect(parsed == ProgramDiagnostic(effect: .blur, line: 7, message: "'undeclaredName' : undeclared identifier"))
        #expect(parsed.text == "Blur, line 7: 'undeclaredName' : undeclared identifier")
        let other = ProgramDiagnostic.parse("link failed", effect: .grade)
        #expect(other.line == 0 && other.message == "link failed")
        #expect(ComposerPresenter.diagnosticsLine([parsed, other])
                    == "Blur, line 7: 'undeclaredName' : undeclared identifier; Color grade, line 0: link failed")
    }
}
