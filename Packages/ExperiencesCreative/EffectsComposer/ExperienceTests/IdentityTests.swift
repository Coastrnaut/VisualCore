// IdentityTests — feature 181 (A25-P02) T-A25-207 (FR-A25-204; SC-A25-203; the manual's regression fixture). A chain
// with one more effect, disabled, draws the same picture as the chain without it: for each of the five effects in turn,
// added at the front, in the middle and at the end of a three-effect chain and disabled, the next frame equals the
// picture of the chain without it within 2/255 (the plan skips a disabled node, so the pictures are identical).
import EffectsComposerCore
import Foundation
import Testing
import VisualCoreExperience
import VisualCoreExperienceHost
@testable import EffectsComposerExperience

@MainActor
@Suite(.serialized) struct IdentityTests {
    @Test func aChainWithOneMoreDisabledEffectDrawsTheSamePicture() async throws {
        let session = ExperienceSession()
        defer { session.close() }
        let shell = try await ComposerTest.open(session)
        ComposerTest.accept(shell, "chain.add", [0, 0])
        ComposerTest.accept(shell, "chain.add", [1, 1])
        ComposerTest.accept(shell, "chain.add", [3, 2])
        try ComposerTest.draw(session)
        let base = try #require(shell.presenter.lastResult)
        let baseChain = try ComposerTest.core(shell).chain
        #expect(base.maxChannelDifference(ComposerTest.reference(baseChain)) <= 2)
        var largest = 0
        for (index, _) in ComposerCore.effects.enumerated() {
            for position in [0, 1, 3] {
                ComposerTest.accept(shell, "chain.add", [Double(index), Double(position)])
                ComposerTest.accept(shell, "chain.enable", [Double(position), 0])
                try ComposerTest.draw(session)
                let picture = try #require(shell.presenter.lastResult)
                let difference = picture.maxChannelDifference(base)
                largest = max(largest, difference)
                #expect(difference <= 2, "effect \(index) disabled at \(position): \(difference)/255")
                #expect(try ComposerTest.core(shell).chain.nodes.count == 4)
                ComposerTest.accept(shell, "chain.remove", [Double(position)])
            }
        }
        #expect(try ComposerTest.core(shell).chain == baseChain)
        print("IdentityTests: largest difference \(largest)/255")
    }
}
