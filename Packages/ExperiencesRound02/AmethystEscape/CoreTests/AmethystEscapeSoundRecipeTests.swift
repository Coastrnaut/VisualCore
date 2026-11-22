// AmethystEscapeSoundRecipeTests — feature 366 (R02-G07-06) T-R02G0706-004 (FR-R02G0706-006; SC-R02G0706-004;
// clarification Q4). The ambient recipe: pure (equal inputs give equal recipes); different for every change of the
// shells passed and for each stage change among playing, won and failed; the documented partials (root 98 Hz, a
// partial per shell passed at 98 × (5/4, 3/2, 2, 5/2)[shell − 1], the root alone in the innermost shell, a 196 Hz
// octave and a two-cycle swell when won, halved amplitudes and gain when failed, 12 s); the pearl's shell clamped to
// the level's shells; a valid `AmbientLoopRecipe` of at most 6 partials for every input and for every snapshot of the
// seed 2_366 level's certified win. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import AmethystEscapeCore
import VisualCoreAudioDSP
import VisualCoreExperience

@Suite struct AmethystEscapeSoundRecipeTests {
    typealias Recipe = AmethystEscapeSoundRecipe
    /// The stages whose sound differs.
    static let stages: [AmethystEscapeStage] = [.playing, .won, .failed]

    @Test func theDocumentedPartials() {
        #expect(Recipe.seconds == 12 && Recipe.rootCycles == 1_176)
        #expect(Recipe.shellCycles == [1_470, 1_764, 2_352, 2_940])
        #expect(Recipe.octaveCycles == 2_352)
        // The innermost shell: the root alone.
        let alone: AmbientLoopRecipe = Recipe.recipe(pearlShell: 0, shells: 3, stage: .playing)
        #expect(alone.partials == [AmbientLoopPartial(cyclesPerLoop: 1_176, amplitude: 0.6)])
        #expect(alone.gain == 0.2 && alone.swellCycles == 1 && alone.seconds == 12)
        // Two shells passed: root, 5/4 and 3/2.
        let two: AmbientLoopRecipe = Recipe.recipe(pearlShell: 2, shells: 5, stage: .playing)
        #expect(two.partials.map(\.cyclesPerLoop) == [1_176, 1_470, 1_764])
        // Won in the outermost of 5 shells: root, four shells and the octave, swelling twice.
        let won: AmbientLoopRecipe = Recipe.recipe(pearlShell: 4, shells: 5, stage: .won)
        #expect(won.partials.map(\.cyclesPerLoop) == [1_176, 1_470, 1_764, 2_352, 2_940, 2_352])
        #expect(won.swellCycles == 2 && won.gain == 0.2)
        // Failed: amplitudes and gain halved.
        let failed: AmbientLoopRecipe = Recipe.recipe(pearlShell: 1, shells: 3, stage: .failed)
        #expect(failed.partials == [AmbientLoopPartial(cyclesPerLoop: 1_176, amplitude: 0.3),
                                    AmbientLoopPartial(cyclesPerLoop: 1_470, amplitude: 0.3)])
        #expect(failed.gain == 0.1 && failed.swellCycles == 1)
        // The pearl's shell is clamped to the level's shells.
        #expect(Recipe.recipe(pearlShell: 9, shells: 3, stage: .playing)
                == Recipe.recipe(pearlShell: 2, shells: 3, stage: .playing))
        #expect(Recipe.recipe(pearlShell: -2, shells: 3, stage: .playing) == alone)
        #expect(Recipe.passedShells(pearlShell: 7, shells: 9) == 4)
    }

    @Test func pureAndDistinct() {
        var seen: [AmbientLoopRecipe] = []
        for passed in 0...4 {
            for stage in Self.stages {
                let recipe: AmbientLoopRecipe = Recipe.recipe(pearlShell: passed, shells: 5, stage: stage)
                // Equal inputs give equal recipes.
                #expect(recipe == Recipe.recipe(pearlShell: passed, shells: 5, stage: stage))
                // The shell count matters only through the clamp.
                #expect(recipe == Recipe.recipe(pearlShell: passed, shells: passed + 1, stage: stage))
                for earlier in seen { #expect(recipe != earlier, "shell \(passed) \(stage)") }
                seen.append(recipe)
            }
        }
        #expect(seen.count == 15)
        // The other stages sound as playing.
        let playing: AmbientLoopRecipe = Recipe.recipe(pearlShell: 1, shells: 4, stage: .playing)
        for stage in [AmethystEscapeStage.loading, .tutorial, .paused, .result] {
            #expect(Recipe.recipe(pearlShell: 1, shells: 4, stage: stage) == playing)
        }
    }

    @Test func everyRecipeIsWithinTheLimits() {
        for shells in -1...7 {
            for pearlShell in -2...8 {
                for stage in AmethystEscapeStage.allCases {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(pearlShell: pearlShell, shells: shells, stage: stage)
                    #expect(recipe.isValid, "\(pearlShell) of \(shells) \(stage)")
                    #expect(AmbientLoopRecipe.partialCountRange.contains(recipe.partials.count))
                    #expect(recipe.gain <= Recipe.baseGain)
                    for partial in recipe.partials { #expect(partial.amplitude <= Recipe.baseAmplitude) }
                }
            }
        }
    }

    @Test func theSeedsCertifiedWinSoundsValidAndOpensUp() throws {
        let number: Int = AmethystEscapeExperienceCore.levelNumber(forSeed: 2_366)
        var core: AmethystEscapeExperienceCore = try AmethystEscapeExperienceCore.opening(number: number)
        let solution: [AmethystEscapeAction] = try AmethystEscapeExperienceCore.generated(number: number)
            .solution.actions
        var counts: [Int] = [Recipe.recipe(core.snapshot(time: 0)).partials.count]
        for kernel in solution {
            let item: ExperienceAction
            switch kernel {
            case .rotate(let shell, let step):
                item = ExperienceAction(control: "shell.rotate", values: [Double(shell), Double(step)], step: 0)
            case .advance:
                item = ExperienceAction(control: "pearl.advance", values: [], step: 0)
            }
            #expect(core.apply(item) == .accepted)
            let snapshot: AmethystEscapeSceneSnapshot = core.snapshot(time: 0)
            let recipe: AmbientLoopRecipe = Recipe.recipe(snapshot)
            #expect(recipe.isValid)
            #expect(recipe == Recipe.recipe(pearlShell: snapshot.pearl.shell, shells: snapshot.shells.count,
                                            stage: snapshot.stage))
            counts.append(recipe.partials.count)
        }
        #expect(core.play.stage == .won)
        // The chord never thins as the pearl climbs, and the win adds the octave.
        for index in 1..<counts.count { #expect(counts[index] >= counts[index - 1]) }
        #expect(counts.first == 1 && counts.last == core.play.level.shells.count + 1)
    }
}
