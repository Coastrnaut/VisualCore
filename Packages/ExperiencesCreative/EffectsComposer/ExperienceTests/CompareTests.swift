// CompareTests — feature 182 (A25-P03) T-A25-305 (FR-A25-301; clarification Q1; User Story 1). Compare through the
// one app's session host, read back from the framebuffer the present pass drew: with compare on the shown picture is
// the source's (the test image) and the status says "Original"; off it is the result's; the result is still rendered
// while compare is on, so turning it off shows the edited picture at once; an empty chain shows the source either
// way; after `recreateContext` with compare on the source is shown again; compare is neither digested nor stored, so a
// restored core shows the result. Short runs; no clock, no sleep.
//
// Feature 184 (A25-P05) T-A25-503 (research R4): `onShowsTheSourceAndOffTheResult` runs on standard-precision
// intermediates (`forceStandardPrecision`): its chain is a colour grade (contrast 1.85) followed by posterize, and on the
// half-float path a few test-image pixels sit on a posterize level boundary where the GPU's and the CPU's `pow` differ
// by less than a half-float step yet land on different levels; the precision paths are covered by ColorPathTests.
import CoreGraphics
import EffectsComposerCore
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import EffectsComposerExperience

@MainActor
@Suite(.serialized) struct CompareTests {
    /// A view large enough for the picture at its own side or a whole multiple of it.
    static let size = CGSize(width: 300, height: 300)

    /// The picture last presented in `session`'s framebuffer.
    private func shown(_ session: ExperienceSession, _ shell: ExperienceShell<ComposerPresenter>,
                       sourceLocation: SourceLocation = #_sourceLocation) throws -> RGBAImage {
        try #require(ComposerTest.presented(session, renderer: shell.presenter.renderer), sourceLocation: sourceLocation)
    }

    @Test func onShowsTheSourceAndOffTheResult() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session, size: Self.size) { presenter in
            presenter.renderer.forceStandardPrecision = true
        }
        let source = ComposerTest.opaque(ComposerTest.image)
        ComposerTest.accept(shell, "chain.add", [0, 0])
        ComposerTest.accept(shell, "chain.set", [0, 1, 0.9])
        try ComposerTest.draw(session)
        let result = ComposerTest.opaque(try #require(shell.presenter.lastResult))
        #expect(result != source)
        #expect(try shown(session, shell) == result)
        #expect(shell.presenter.renderer.presentedTargetIsSource == false)
        #expect(shell.presenter.mirror.shownStatus == ComposerPresenter.readyWord)

        ComposerTest.accept(shell, "view.compare", [1])
        try ComposerTest.draw(session)
        #expect(try shown(session, shell) == source)
        #expect(shell.presenter.renderer.presentedTargetIsSource)
        #expect(shell.presenter.mirror.shownStatus == "Original")
        #expect(shell.presenter.describe(try ComposerTest.core(shell)).hasSuffix(". Original"))

        // An edit while comparing still renders the result; the source stays shown.
        let renders = shell.presenter.renderer.renderCount
        ComposerTest.accept(shell, "chain.add", [4, 1])
        try ComposerTest.draw(session)
        #expect(shell.presenter.renderer.renderCount == renders + 1)
        let chain = try ComposerTest.core(shell).chain
        #expect(try ComposerTest.difference(shell, chain) <= ComposerTest.tolerance(chain))
        #expect(try shown(session, shell) == source)

        ComposerTest.accept(shell, "view.compare", [0])
        try ComposerTest.draw(session)
        #expect(shell.presenter.renderer.renderCount == renders + 1, "turning compare off draws no new render")
        let edited = ComposerTest.opaque(try #require(shell.presenter.lastResult))
        #expect(try shown(session, shell) == edited)
        #expect(edited != result && edited != source)
        #expect(shell.presenter.mirror.shownStatus == ComposerPresenter.readyWord)
    }

    @Test func anEmptyChainShowsTheSourceEitherWay() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session, size: Self.size)
        let source = ComposerTest.opaque(ComposerTest.image)
        #expect(try shown(session, shell) == source)
        ComposerTest.accept(shell, "view.compare", [1])
        try ComposerTest.draw(session)
        #expect(try shown(session, shell) == source)
        #expect(shell.presenter.renderer.presentedTargetIsSource)
    }

    @Test func afterAContextLossWithCompareOnTheSourceIsShownAgain() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session, size: Self.size)
        let source = ComposerTest.opaque(ComposerTest.image)
        ComposerTest.accept(shell, "chain.add", [4, 0])
        ComposerTest.accept(shell, "view.compare", [1])
        try ComposerTest.draw(session)
        #expect(try shown(session, shell) == source)
        let host = try #require(session.renderHost)
        host.recreateContext()
        try ComposerTest.draw(session)
        #expect(try shown(session, shell) == source)
        #expect(shell.presenter.renderer.presentedTargetIsSource)
        ComposerTest.accept(shell, "view.compare", [0])
        try ComposerTest.draw(session)
        let chain = try ComposerTest.core(shell).chain
        #expect(try ComposerTest.difference(shell, chain) <= ComposerTest.tolerance(chain))
        #expect(try shown(session, shell) == ComposerTest.opaque(try #require(shell.presenter.lastResult)))
    }

    @Test func compareIsNeitherDigestedNorStored() throws {
        let (added, _) = ComposerTest.applied(ComposerCore(), "chain.add", [1, 0])
        let (comparing, result) = ComposerTest.applied(added, "view.compare", [1])
        #expect(result == .accepted && comparing.compare)
        #expect(comparing.history.undoCount == added.history.undoCount, "compare is not an edit")
        #expect(try ComposerTest.digest(comparing) == ComposerTest.digest(added))
        let restored = try ComposerCore.restore(payload: comparing.snapshotPayload(), seed: 1)
        #expect(restored.compare == false && restored.chain == comparing.chain)
        let (_, fraction) = ComposerTest.applied(added, "view.compare", [0.5])
        #expect(fraction.code == "action.rule." + ComposerRule.notWhole)
    }
}
