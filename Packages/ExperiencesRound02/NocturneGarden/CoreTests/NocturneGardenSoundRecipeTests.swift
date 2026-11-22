// NocturneGardenSoundRecipeTests — feature 386 (R02-G09-06) T-R02G0906-004 (FR-R02G0906-006; SC-R02G0906-004;
// clarification Q4). The ambient recipe: pure (equal inputs give equal recipes); different for every change of the
// bloom partials (the planted blooms clamped to 0 … 4), of the sun and of the stage among playing, won and failed; the
// documented partials (root 110 Hz × (1, 9/8, 5/4, 4/3)[sun − 1], a partial per planted bloom at the root ×
// (5/4, 3/2, 2, 5/2)[k − 1], up to four, the root alone on an empty bed, the octave and a two-cycle swell when won,
// halved amplitudes and gain when failed); the loop length the longest in 4 … 16 s at which every partial has a whole
// number of cycles (16 s for sun 1 … 3, 15 s for sun 4); a valid `AmbientLoopRecipe` of at most 6 partials for every
// input and for every state of level 1's certified win. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import NocturneGardenCore
import VisualCoreAudioDSP
import VisualCoreExperience

@Suite struct NocturneGardenSoundRecipeTests {
    typealias Recipe = NocturneGardenSoundRecipe
    /// The stages whose sound differs.
    static let stages: [NocturneGardenStage] = [.playing, .won, .failed]

    /// The highest frequency any recipe sounds: the fourth bloom partial at sun 4, 110 × 4/3 × 5/2 Hz (plus rounding).
    static let highestHertz: Double = 110.0 * 4.0 / 3.0 * 5.0 / 2.0 + 1e-9

    /// Whether `value` is a whole number (within a rounding tolerance far below one cycle).
    static func isWhole(_ value: Double) -> Bool { abs(value - value.rounded()) < 1e-6 }

    @Test func theDocumentedPartials() {
        #expect(Recipe.rootHertz == 110)
        let sunRatios: [Double] = [1.0, 1.125, 1.25, 4.0 / 3.0]
        let bloomRatios: [Double] = [1.25, 1.5, 2.0, 2.5]
        #expect(Recipe.sunRatios == sunRatios)
        #expect(Recipe.bloomRatios == bloomRatios)
        // An empty bed at sun 1: the root alone, 110 Hz over 16 s.
        let alone: AmbientLoopRecipe = Recipe.recipe(blooms: 0, sun: 1, stage: .playing)
        #expect(alone.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.6)])
        #expect(alone.gain == 0.2 && alone.swellCycles == 1 && alone.seconds == 16)
        // Three blooms at sun 1: root, 5/4, 3/2 and 2.
        let three: AmbientLoopRecipe = Recipe.recipe(blooms: 3, sun: 1, stage: .playing)
        #expect(three.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520])
        // Sun 2 (9/8): 123.75 Hz, whole over 16 s only (2,475 cycles for the first bloom).
        let second: AmbientLoopRecipe = Recipe.recipe(blooms: 2, sun: 2, stage: .playing)
        #expect(second.seconds == 16 && second.partials.map(\.cyclesPerLoop) == [1_980, 2_475, 2_970])
        // Sun 4 (4/3): 146.67 Hz, whole only in multiples of 3 s, so 15 s.
        let low: AmbientLoopRecipe = Recipe.recipe(blooms: 4, sun: 4, stage: .playing)
        #expect(low.seconds == 15 && low.partials.map(\.cyclesPerLoop) == [2_200, 2_750, 3_300, 4_400, 5_500])
        // Won with four blooms: root, four partials and the octave, swelling twice.
        let won: AmbientLoopRecipe = Recipe.recipe(blooms: 4, sun: 1, stage: .won)
        #expect(won.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520, 4_400, 3_520])
        #expect(won.partials.count == 6 && won.swellCycles == 2 && won.gain == 0.2)
        // An empty bed when won: the root and its octave.
        #expect(Recipe.recipe(blooms: 0, sun: 3, stage: .won).partials.map(\.cyclesPerLoop) == [2_200, 4_400])
        // Failed: amplitudes and gain halved.
        let failed: AmbientLoopRecipe = Recipe.recipe(blooms: 1, sun: 1, stage: .failed)
        #expect(failed.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.3),
                                    AmbientLoopPartial(cyclesPerLoop: 2_200, amplitude: 0.3)])
        #expect(failed.gain == 0.1 && failed.swellCycles == 1)
        // At most four bloom partials; the sun is clamped to 1 … 4; negative blooms count as none.
        #expect(Recipe.recipe(blooms: 9, sun: 2, stage: .playing) == Recipe.recipe(blooms: 4, sun: 2, stage: .playing))
        #expect(Recipe.recipe(blooms: 1, sun: 0, stage: .playing) == Recipe.recipe(blooms: 1, sun: 1, stage: .playing))
        #expect(Recipe.recipe(blooms: 1, sun: 7, stage: .playing) == Recipe.recipe(blooms: 1, sun: 4, stage: .playing))
        #expect(Recipe.recipe(blooms: -2, sun: 1, stage: .playing) == alone)
        #expect(Recipe.bloomPartials(blooms: 7) == 4 && Recipe.clampedSun(-3) == 1)
    }

    @Test func pureAndDistinct() {
        var seen: [AmbientLoopRecipe] = []
        for sun in 1...4 {
            for blooms in 0...4 {
                for stage in Self.stages {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(blooms: blooms, sun: sun, stage: stage)
                    // Equal inputs give equal recipes.
                    #expect(recipe == Recipe.recipe(blooms: blooms, sun: sun, stage: stage))
                    for earlier in seen { #expect(recipe != earlier, "blooms \(blooms) sun \(sun) \(stage)") }
                    seen.append(recipe)
                }
            }
        }
        #expect(seen.count == 60)
        // The other stages sound as playing.
        let playing: AmbientLoopRecipe = Recipe.recipe(blooms: 2, sun: 3, stage: .playing)
        for stage in [NocturneGardenStage.loading, .tutorial, .paused, .result] {
            #expect(Recipe.recipe(blooms: 2, sun: 3, stage: stage) == playing)
        }
    }

    @Test func everyRecipeIsWithinTheLimitsWithWholeCycles() {
        for sun in -1...6 {
            for blooms in -2...8 {
                for stage in NocturneGardenStage.allCases {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(blooms: blooms, sun: sun, stage: stage)
                    let label: String = "blooms \(blooms) sun \(sun) \(stage)"
                    #expect(recipe.isValid, "\(label)")
                    #expect(AmbientLoopRecipe.partialCountRange.contains(recipe.partials.count), "\(label)")
                    #expect(recipe.partials.count <= 6)
                    #expect(AmbientLoopRecipe.secondsRange.contains(recipe.seconds), "\(label)")
                    #expect(recipe.gain <= Recipe.baseGain && recipe.gain > 0)
                    #expect(recipe.seconds == Recipe.loopSeconds(blooms: blooms, sun: sun, stage: stage))
                    // The partials sound the documented frequencies, each a whole number of cycles in the loop.
                    let frequencies: [Double] = Recipe.frequencies(blooms: blooms, sun: sun, stage: stage)
                    #expect(frequencies.count == recipe.partials.count, "\(label)")
                    for index in recipe.partials.indices where index < frequencies.count {
                        let partial: AmbientLoopPartial = recipe.partials[index]
                        let product: Double = frequencies[index] * Double(recipe.seconds)
                        #expect(Self.isWhole(product), "\(label) partial \(index): \(product) cycles")
                        #expect(Int(product.rounded()) == partial.cyclesPerLoop, "\(label) partial \(index)")
                        #expect(partial.amplitude <= Recipe.baseAmplitude && partial.amplitude > 0)
                        #expect(frequencies[index] >= 110 && frequencies[index] <= Self.highestHertz)
                    }
                    // No longer length in the player's range keeps every partial whole: the length is the longest.
                    if recipe.seconds < AmbientLoopRecipe.secondsRange.upperBound {
                        for longer in (recipe.seconds + 1)...AmbientLoopRecipe.secondsRange.upperBound {
                            var allWhole: Bool = true
                            for frequency in frequencies where !Self.isWhole(frequency * Double(longer)) {
                                allWhole = false
                            }
                            #expect(!allWhole, "\(label): \(longer) s would also fit")
                        }
                    }
                }
            }
        }
        // The expected lengths: 16 s for sun 1 … 3, 15 s for sun 4.
        for sun in 1...4 {
            for stage in Self.stages {
                #expect(Recipe.loopSeconds(blooms: 4, sun: sun, stage: stage) == (sun == 4 ? 15 : 16))
                #expect(Recipe.loopSeconds(blooms: 0, sun: sun, stage: stage) == (sun == 4 ? 15 : 16))
            }
        }
    }

    @Test func theRootAloneOctaveWhenWonAndHalvedWhenFailed() {
        for sun in 1...4 {
            let root: Double = 110 * Recipe.sunRatios[sun - 1]
            let empty: AmbientLoopRecipe = Recipe.recipe(blooms: 0, sun: sun, stage: .playing)
            #expect(empty.partials.count == 1)
            let alone: [Double] = Recipe.frequencies(blooms: 0, sun: sun, stage: .playing)
            #expect(alone.count == 1 && abs((alone.first ?? 0) - root) < 1e-9)
            for blooms in 0...4 {
                let playing: AmbientLoopRecipe = Recipe.recipe(blooms: blooms, sun: sun, stage: .playing)
                #expect(playing.partials.count == 1 + blooms)
                let won: AmbientLoopRecipe = Recipe.recipe(blooms: blooms, sun: sun, stage: .won)
                #expect(won.partials.count == playing.partials.count + 1)
                #expect(Array(won.partials.prefix(playing.partials.count)) == playing.partials)
                #expect(won.partials.last?.cyclesPerLoop == playing.partials[0].cyclesPerLoop * 2)
                #expect(won.swellCycles == 2 && playing.swellCycles == 1)
                let failed: AmbientLoopRecipe = Recipe.recipe(blooms: blooms, sun: sun, stage: .failed)
                #expect(failed.seconds == playing.seconds && failed.gain == playing.gain / 2)
                #expect(failed.partials.map(\.cyclesPerLoop) == playing.partials.map(\.cyclesPerLoop))
                for index in failed.partials.indices {
                    #expect(failed.partials[index].amplitude == playing.partials[index].amplitude / 2)
                }
            }
        }
    }

    @Test func theCertifiedWinSoundsValidAndOpensUp() throws {
        let number: Int = 1
        var core: NocturneGardenExperienceCore = try NocturneGardenExperienceCore.opening(number: number)
        let solution: [NocturneGardenAction] = try NocturneGardenExperienceCore.generated(number: number)
            .solution.actions
        let first: NocturneGardenSceneSnapshot = core.snapshot(time: 0)
        var recipes: [AmbientLoopRecipe] = [Recipe.recipe(blooms: first.blooms.count, sun: first.sun,
                                                          stage: first.stage)]
        for kernel in solution {
            let item: ExperienceAction
            switch kernel {
            case let .plant(kind, column, row, size):
                item = ExperienceAction(control: "bloom.plant",
                                        values: [Double(kind.order), Double(column), Double(row), Double(size)],
                                        step: 0)
            case let .move(bloom, column, row):
                item = ExperienceAction(control: "bloom.move", values: [Double(bloom), Double(column), Double(row)],
                                        step: 0)
            case let .resize(bloom, size):
                item = ExperienceAction(control: "bloom.resize", values: [Double(bloom), Double(size)], step: 0)
            case let .remove(bloom):
                item = ExperienceAction(control: "bloom.remove", values: [Double(bloom)], step: 0)
            case let .sun(elevation):
                item = ExperienceAction(control: "sun.set", values: [Double(elevation)], step: 0)
            }
            #expect(core.apply(item) == .accepted)
            let snapshot: NocturneGardenSceneSnapshot = core.snapshot(time: 0)
            let recipe: AmbientLoopRecipe = Recipe.recipe(blooms: snapshot.blooms.count, sun: snapshot.sun,
                                                          stage: snapshot.stage)
            #expect(recipe.isValid)
            #expect(recipe.partials.count <= 6)
            recipes.append(recipe)
        }
        #expect(core.play.stage == .won)
        // The win adds the octave and the two-cycle swell to the chord of the planted blooms.
        let final: NocturneGardenSceneSnapshot = core.snapshot(time: 0)
        let last: AmbientLoopRecipe = try #require(recipes.last)
        #expect(last.partials.count == min(final.blooms.count, 4) + 2 && last.swellCycles == 2)
        #expect(recipes.first?.partials.count == 1 + min(first.blooms.count, 4))
    }
}
