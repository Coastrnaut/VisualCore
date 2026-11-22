// FacetedForgeSoundRecipeTests — feature 376 (R02-G08-06) T-R02G0806-004 (FR-R02G0806-006; SC-R02G0806-004;
// clarification Q4). The ambient recipe: pure (equal inputs give equal recipes); different for every change of the
// added partials (the piece count clamped by the target) and for each stage change among playing, won and failed; the
// documented partials (root 110 Hz, a partial per piece beyond the first at 110 × (5/4, 3/2, 2, 5/2)[k − 1], up to
// four, the root alone while the crystal is whole, a 220 Hz octave and a two-cycle swell when won, halved amplitudes
// and gain when failed, 12 s, whole cycles); the target used only to clamp; a valid `AmbientLoopRecipe` of at most 6
// partials for every input and for every state of level 2's certified win. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import FacetedForgeCore
import VisualCoreAudioDSP
import VisualCoreExperience

@Suite struct FacetedForgeSoundRecipeTests {
    typealias Recipe = FacetedForgeSoundRecipe
    /// The stages whose sound differs.
    static let stages: [FacetedForgeStage] = [.playing, .won, .failed]

    @Test func theDocumentedPartials() {
        #expect(Recipe.seconds == 12 && Recipe.rootCycles == 1_320)
        #expect(Recipe.pieceCycles == [1_650, 1_980, 2_640, 3_300])
        #expect(Recipe.octaveCycles == 2_640)
        // The whole crystal: the root alone.
        let alone: AmbientLoopRecipe = Recipe.recipe(pieces: 1, target: 3, stage: .playing)
        #expect(alone.partials == [AmbientLoopPartial(cyclesPerLoop: 1_320, amplitude: 0.6)])
        #expect(alone.gain == 0.2 && alone.swellCycles == 1 && alone.seconds == 12)
        // Three pieces: root, 5/4 and 3/2.
        let three: AmbientLoopRecipe = Recipe.recipe(pieces: 3, target: 6, stage: .playing)
        #expect(three.partials.map(\.cyclesPerLoop) == [1_320, 1_650, 1_980])
        // Won with five pieces: root, four partials and the octave, swelling twice.
        let won: AmbientLoopRecipe = Recipe.recipe(pieces: 5, target: 5, stage: .won)
        #expect(won.partials.map(\.cyclesPerLoop) == [1_320, 1_650, 1_980, 2_640, 3_300, 2_640])
        #expect(won.swellCycles == 2 && won.gain == 0.2)
        // Failed: amplitudes and gain halved.
        let failed: AmbientLoopRecipe = Recipe.recipe(pieces: 2, target: 3, stage: .failed)
        #expect(failed.partials == [AmbientLoopPartial(cyclesPerLoop: 1_320, amplitude: 0.3),
                                    AmbientLoopPartial(cyclesPerLoop: 1_650, amplitude: 0.3)])
        #expect(failed.gain == 0.1 && failed.swellCycles == 1)
        // At most four partials beyond the root; more pieces than the target hold at the target's chord.
        #expect(Recipe.recipe(pieces: 9, target: 12, stage: .playing)
                == Recipe.recipe(pieces: 5, target: 12, stage: .playing))
        #expect(Recipe.recipe(pieces: 6, target: 3, stage: .playing)
                == Recipe.recipe(pieces: 3, target: 3, stage: .playing))
        #expect(Recipe.recipe(pieces: -2, target: 3, stage: .playing) == alone)
        #expect(Recipe.addedPartials(pieces: 7, target: 9) == 4)
    }

    @Test func pureAndDistinct() {
        var seen: [AmbientLoopRecipe] = []
        for pieces in 1...5 {
            for stage in Self.stages {
                let recipe: AmbientLoopRecipe = Recipe.recipe(pieces: pieces, target: 5, stage: stage)
                // Equal inputs give equal recipes.
                #expect(recipe == Recipe.recipe(pieces: pieces, target: 5, stage: stage))
                // The target matters only through the clamp.
                #expect(recipe == Recipe.recipe(pieces: pieces, target: pieces, stage: stage))
                #expect(recipe == Recipe.recipe(pieces: pieces, target: 21, stage: stage))
                for earlier in seen { #expect(recipe != earlier, "pieces \(pieces) \(stage)") }
                seen.append(recipe)
            }
        }
        #expect(seen.count == 15)
        // The other stages sound as playing.
        let playing: AmbientLoopRecipe = Recipe.recipe(pieces: 2, target: 4, stage: .playing)
        for stage in [FacetedForgeStage.loading, .tutorial, .paused, .result] {
            #expect(Recipe.recipe(pieces: 2, target: 4, stage: stage) == playing)
        }
    }

    @Test func everyRecipeIsWithinTheLimitsWithWholeCycles() {
        for target in -1...22 {
            for pieces in -2...24 {
                for stage in FacetedForgeStage.allCases {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(pieces: pieces, target: target, stage: stage)
                    #expect(recipe.isValid, "\(pieces) of \(target) \(stage)")
                    #expect(AmbientLoopRecipe.partialCountRange.contains(recipe.partials.count))
                    #expect(AmbientLoopRecipe.secondsRange.contains(recipe.seconds))
                    #expect(recipe.gain <= Recipe.baseGain)
                    for partial in recipe.partials {
                        #expect(partial.amplitude <= Recipe.baseAmplitude)
                        // Only the documented whole cycle counts sound.
                        #expect(partial.cyclesPerLoop == Recipe.rootCycles
                                || Recipe.pieceCycles.contains(partial.cyclesPerLoop))
                    }
                }
            }
        }
        // Every frequency of the recipe, in hertz, times 12 s is a whole number.
        let frequencies: [Double] = [110, 137.5, 165, 220, 275, 220]
        let cycles: [Int] = [Recipe.rootCycles] + Recipe.pieceCycles + [Recipe.octaveCycles]
        for index in frequencies.indices {
            let product: Double = frequencies[index] * Double(Recipe.seconds)
            #expect(product == product.rounded() && Int(product) == cycles[index])
        }
    }

    @Test func theCertifiedWinSoundsValidAndOpensUp() throws {
        let number: Int = 2
        var core: FacetedForgeExperienceCore = try FacetedForgeExperienceCore.opening(number: number)
        let target: Int = core.play.level.target.count
        let solution: [FacetedForgeAction] = try FacetedForgeExperienceCore.generated(number: number).solution.actions
        var counts: [Int] = [Recipe.recipe(pieces: core.play.pieces.count, target: target,
                                           stage: core.play.stage).partials.count]
        for kernel in solution {
            let item: ExperienceAction
            switch kernel {
            case .cut(let piece, let direction, let depth):
                item = ExperienceAction(control: "piece.cut", values: [Double(piece), Double(direction), Double(depth)],
                                        step: 0)
            }
            #expect(core.apply(item) == .accepted)
            let snapshot: FacetedForgeSceneSnapshot = core.snapshot(time: 0)
            let recipe: AmbientLoopRecipe = Recipe.recipe(pieces: snapshot.pieces.count, target: target,
                                                          stage: snapshot.stage)
            #expect(recipe.isValid)
            counts.append(recipe.partials.count)
        }
        #expect(core.play.stage == .won)
        // The chord never thins as the crystal is cut, and the win adds the octave.
        for index in 1..<counts.count { #expect(counts[index] >= counts[index - 1]) }
        #expect(counts.first == 1 && counts.last == min(target - 1, 4) + 2)
    }
}
