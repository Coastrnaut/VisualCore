// PreviewDrawTests — feature 181 (A25-P02) T-A25-207 (FR-A25-202, FR-A25-203; SC-A25-202). The preview follows every
// edit kind at the next frame: after an add, a value change, an enable or disable, a move and a removal sent through
// the experience's port, the next frame's result equals `EffectReference.apply(chain:)` on the 256 × 256 test image
// within 2/255 (4/255 with an enabled distort); undo restores the picture before the edit byte for byte and redo the
// picture after it. The opening (empty) chain shows the test image unchanged.
import CoreGraphics
import EffectsComposerCore
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import EffectsComposerExperience

@MainActor
@Suite(.serialized) struct PreviewDrawTests {
    /// Sends `control` with `values`, draws the next frame and expects the result to match the CPU reference of the
    /// edited chain within its tolerance; returns the largest difference.
    @discardableResult
    private func edit(_ session: ExperienceSession, _ shell: ExperienceShell<ComposerPresenter>, _ control: String,
                      _ values: [Double], sourceLocation: SourceLocation = #_sourceLocation) throws -> Int {
        ComposerTest.accept(shell, control, values, sourceLocation: sourceLocation)
        try ComposerTest.draw(session, sourceLocation: sourceLocation)
        let chain = try ComposerTest.core(shell).chain
        let difference = try ComposerTest.difference(shell, chain, sourceLocation: sourceLocation)
        #expect(difference <= ComposerTest.tolerance(chain), "\(control) \(values): \(difference)/255",
                sourceLocation: sourceLocation)
        return difference
    }

    @Test func theOpeningChainShowsTheTestImageUnchanged() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        let result = try #require(shell.presenter.lastResult)
        #expect(result == ComposerTest.image)
        #expect(shell.presenter.renderer.lastPlan?.passes.count == 1)
        #expect(shell.presenter.renderer.lastPlan?.passes.first?.node == nil)
    }

    @Test func addSetAndEnableShowAtTheNextFrame() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        var largest = 0
        largest = max(largest, try edit(session, shell, "chain.add", [0, 0]))
        largest = max(largest, try edit(session, shell, "chain.set", [0, 0, 0.6]))
        largest = max(largest, try edit(session, shell, "chain.add", [1, 1]))
        largest = max(largest, try edit(session, shell, "chain.add", [4, 2]))
        largest = max(largest, try edit(session, shell, "chain.set", [2, 0, 0.1]))
        largest = max(largest, try edit(session, shell, "chain.enable", [1, 0]))
        largest = max(largest, try edit(session, shell, "chain.enable", [1, 1]))
        #expect(try ComposerTest.core(shell).chain.nodes.map(\.effect) == [.grade, .blur, .posterize])
        print("PreviewDrawTests add/set/enable: largest difference \(largest)/255")
    }

    @Test func moveAndRemoveShowAtTheNextFrameWithDistort() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        var largest = 0
        largest = max(largest, try edit(session, shell, "chain.add", [3, 0]))
        largest = max(largest, try edit(session, shell, "chain.add", [2, 1]))
        largest = max(largest, try edit(session, shell, "chain.add", [0, 2]))
        largest = max(largest, try edit(session, shell, "chain.move", [2, 0]))
        largest = max(largest, try edit(session, shell, "chain.move", [1, 2]))
        largest = max(largest, try edit(session, shell, "chain.remove", [1]))
        largest = max(largest, try edit(session, shell, "chain.remove", [0]))
        #expect(try ComposerTest.core(shell).chain.nodes.map(\.effect) == [.vignette])
        print("PreviewDrawTests move/remove: largest difference \(largest)/255")
    }

    @Test func undoRestoresThePictureByteForByteAndRedoReturnsIt() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        try edit(session, shell, "chain.add", [0, 0])
        try edit(session, shell, "chain.add", [3, 1])
        // Each edit changes the picture: posterize added, the grade's saturation lowered, posterize moved before the
        // grade, posterize disabled, the grade removed.
        let edits: [(String, [Double])] = [("chain.add", [4, 1]), ("chain.set", [0, 2, 0.2]), ("chain.move", [1, 0]),
                                           ("chain.enable", [0, 0]), ("chain.remove", [1])]
        for (control, values) in edits {
            let before = try #require(shell.presenter.lastResult)
            ComposerTest.accept(shell, control, values)
            try ComposerTest.draw(session)
            let after = try #require(shell.presenter.lastResult)
            #expect(after != before, "\(control) changes the picture")
            ComposerTest.accept(shell, "edit.undo")
            try ComposerTest.draw(session)
            #expect(shell.presenter.lastResult == before, "undo of \(control) restores it byte for byte")
            ComposerTest.accept(shell, "edit.redo")
            try ComposerTest.draw(session)
            #expect(shell.presenter.lastResult == after, "redo of \(control) returns it")
        }
    }
}
