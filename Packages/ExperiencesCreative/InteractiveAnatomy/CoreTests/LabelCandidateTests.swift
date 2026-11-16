// LabelCandidateTests — feature 127 (A17-P04) T-A17-403 (FR-A17-402; SC-A17-403; clarification Q2). The label
// candidates, host-free and short: box 7 points per character plus 8, by 18; one candidate per solid part, sorted by
// index, anchored at the sphere centre; the solid selection has priority 0, the others 1 + index; no candidate for a
// part that is not solid.
import Foundation
import Testing
import VisualCoreMath
@testable import InteractiveAnatomyCore

/// The scene of the bundled knee at the first quality level.
private func labelCandidateScene() throws -> AnatomyScene {
    try AnatomyScene.build(try AnatomyContent.bundledRightKnee(), quality: AnatomyQuality.levels[0]).get()
}

@Suite struct LabelCandidateTests {
    @Test func theBoxIsSevenPointsPerCharacterPlusEightBy18() {
        #expect(AnatomyLabels.boxSize("Femur") == Vec2(43, 18))
        #expect(AnatomyLabels.boxSize("") == Vec2(8, 18))
    }

    @Test func everySolidPartIsACandidateSortedByIndex() throws {
        let scene = try labelCandidateScene()
        let candidates = AnatomyLabels.candidates(scene: scene, solid: [5, 0, 2], selected: nil)
        #expect(candidates.map(\.id) == [0, 2, 5])
        #expect(candidates.map(\.priority) == [1, 3, 6])
        let first = try #require(candidates.first)
        #expect(first.anchor == scene.structureSphere(0).center)
        #expect(first.size == AnatomyLabels.boxSize(scene.parts[0].englishName))
    }

    @Test func theSolidSelectionComesFirst() throws {
        let scene = try labelCandidateScene()
        let solid = Set(scene.parts.indices)
        let candidates = AnatomyLabels.candidates(scene: scene, solid: solid, selected: 3)
        #expect(candidates.count == scene.parts.count)
        #expect(candidates.first { $0.id == 3 }?.priority == 0)
        #expect(candidates.filter { $0.priority == 0 }.count == 1)
    }

    @Test func partsThatAreNotSolidGetNoLabel() throws {
        let scene = try labelCandidateScene()
        let candidates = AnatomyLabels.candidates(scene: scene, solid: [1, 99, -1], selected: 4)
        #expect(candidates.map(\.id) == [1])
        #expect(candidates.allSatisfy { $0.priority != 0 })
    }
}
