// LissajousLabyrinthSoundRecipeTests — feature 316 (R02-G02-06) T-R02G0206-004 (FR-R02G0206-006; clarification Q4;
// SC-R02G0206-004). The ambient recipe: equal for equal dials and stage; different for a frequency change and for each
// stage change among playing, won and failed; the documented partials (110 Hz × a and × b, a fifth above the lower, an
// octave above the higher when won, phase-shaped amplitudes 0.6 … 1.0 of the base, halved when failed); a valid
// `AmbientLoopRecipe` for every coprime frequency pair with sampled phases in every stage, and for out-of-range dials.
// Explicit types, plain loops, short runs.
import Testing
@testable import LissajousLabyrinthCore
import VisualCoreAudioDSP

@Suite struct LissajousLabyrinthSoundRecipeTests {
    typealias Recipe = LissajousLabyrinthSoundRecipe

    static let dials: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 3, frequencyB: 4, phaseA: 0,
                                                                        phaseC: 15)

    @Test func equalInputsGiveEqualRecipes() {
        for stage in LissajousLabyrinthStage.allCases {
            let copy: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: 3, frequencyB: 4, phaseA: 0,
                                                                        phaseC: 15)
            #expect(Recipe.recipe(dials: Self.dials, stage: stage) == Recipe.recipe(dials: copy, stage: stage))
        }
    }

    @Test func aFrequencyChangeChangesTheRecipe() {
        var changed: LissajousLabyrinthDials = Self.dials
        changed.frequencyB = 5
        #expect(Recipe.recipe(dials: Self.dials, stage: .playing) != Recipe.recipe(dials: changed, stage: .playing))
        changed = Self.dials
        changed.frequencyA = 2
        changed.frequencyB = 3
        #expect(Recipe.recipe(dials: Self.dials, stage: .playing) != Recipe.recipe(dials: changed, stage: .playing))
    }

    @Test func eachStageChangeChangesTheRecipe() {
        let playing: AmbientLoopRecipe = Recipe.recipe(dials: Self.dials, stage: .playing)
        let won: AmbientLoopRecipe = Recipe.recipe(dials: Self.dials, stage: .won)
        let failed: AmbientLoopRecipe = Recipe.recipe(dials: Self.dials, stage: .failed)
        #expect(playing != won && playing != failed && won != failed)
    }

    @Test func thePartialsFollowTheFiguresRatio() {
        let playing: AmbientLoopRecipe = Recipe.recipe(dials: Self.dials, stage: .playing)
        #expect(playing.seconds == 8 && playing.swellCycles == 1 && playing.gain == Recipe.baseGain)
        #expect(playing.partials.map(\.cyclesPerLoop) == [8 * 330, 8 * 440, 8 * 495])
        let base: Double = Recipe.baseAmplitude
        #expect(abs(playing.partials[0].amplitude - 0.6 * base) < 1e-12, "phase φ 0 → 0.6 of the base")
        #expect(abs(playing.partials[1].amplitude - base) < 1e-12, "phase ψ 15 → the whole base")
        #expect(abs(playing.partials[2].amplitude - base / 2) < 1e-12, "the fifth at half the base")
        let won: AmbientLoopRecipe = Recipe.recipe(dials: Self.dials, stage: .won)
        #expect(won.partials.count == 4 && won.partials[3].cyclesPerLoop == 8 * 880)
        #expect(Array(won.partials.prefix(3)) == playing.partials)
        let failed: AmbientLoopRecipe = Recipe.recipe(dials: Self.dials, stage: .failed)
        #expect(failed.gain == playing.gain / 2 && failed.partials.count == 3)
        for index in 0..<3 {
            #expect(failed.partials[index].cyclesPerLoop == playing.partials[index].cyclesPerLoop)
            #expect(failed.partials[index].amplitude == playing.partials[index].amplitude / 2)
        }
        let unison: AmbientLoopRecipe = Recipe.recipe(
            dials: LissajousLabyrinthDials(frequencyA: 1, frequencyB: 1, phaseA: 4, phaseC: 9), stage: .playing)
        #expect(unison.partials.map(\.cyclesPerLoop) == [8 * 110, 8 * 165])
    }

    @Test func everyLegalSettingAndStageGivesAValidRecipe() {
        let phases: [Int] = [0, 1, 7, 8, 14, 15]
        var count: Int = 0
        for a in 1...9 {
            for b in 1...9 {
                for phaseA in phases {
                    for phaseC in phases {
                        let dials: LissajousLabyrinthDials = LissajousLabyrinthDials(frequencyA: a, frequencyB: b,
                                                                                     phaseA: phaseA, phaseC: phaseC)
                        guard dials.isValid else { continue }
                        for stage in LissajousLabyrinthStage.allCases {
                            let recipe: AmbientLoopRecipe = Recipe.recipe(dials: dials, stage: stage)
                            #expect(recipe.isValid, "\(dials) \(stage)")
                            count += 1
                        }
                    }
                }
            }
        }
        #expect(count > 0)
        // Out-of-range dials are clamped, never invalid.
        for dials in [LissajousLabyrinthDials(frequencyA: 0, frequencyB: 40, phaseA: -3, phaseC: 99),
                      LissajousLabyrinthDials(frequencyA: Int.min, frequencyB: Int.max, phaseA: Int.min,
                                              phaseC: Int.max)] {
            for stage in LissajousLabyrinthStage.allCases {
                #expect(Recipe.recipe(dials: dials, stage: stage).isValid, "\(dials) \(stage)")
            }
        }
    }
}
