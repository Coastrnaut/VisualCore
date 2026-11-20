// AuroraLoomSoundRecipeTests — feature 306 (R02-G01-06) T-R02G0106-005 (FR-R02G0106-006; clarification Q4;
// SC-R02G0106-004). The ambient recipe: equal steps and stage give an equal recipe; it differs for every single wave-step
// change and among playing, won and failed; it is valid for all 16³ wave combinations in every stage; phase steps alone
// never change it (phase is not sonified). Explicit types, plain loops, short runs.
import Testing
@testable import AuroraLoomCore
import VisualCoreAudioDSP

@Suite struct AuroraLoomSoundRecipeTests {
    static let stages: [AuroraLoomStage] = [.playing, .won, .failed]

    @Test func pureForEqualInputs() {
        let steps: AuroraLoomSteps = AuroraLoomSteps(wave: [3, 9, 14], phase: [1, 2, 3])
        for stage in AuroraLoomStage.allCases {
            let first: AmbientLoopRecipe = AuroraLoomSoundRecipe.recipe(steps: steps, stage: stage)
            let second: AmbientLoopRecipe = AuroraLoomSoundRecipe.recipe(
                steps: AuroraLoomSteps(wave: [3, 9, 14], phase: [1, 2, 3]), stage: stage)
            #expect(first == second, "\(stage)")
        }
    }

    @Test func differsForEverySingleWaveStepChange() {
        let base: [Int] = [5, 7, 2]
        for stage in Self.stages {
            let original: AmbientLoopRecipe = AuroraLoomSoundRecipe.recipe(
                steps: AuroraLoomSteps(wave: base, phase: [0, 0, 0]), stage: stage)
            for ribbon in 0..<3 {
                for step in 0..<16 where step != base[ribbon] {
                    var wave: [Int] = base
                    wave[ribbon] = step
                    let changed: AmbientLoopRecipe = AuroraLoomSoundRecipe.recipe(
                        steps: AuroraLoomSteps(wave: wave, phase: [0, 0, 0]), stage: stage)
                    #expect(changed != original, "\(stage) ribbon \(ribbon) step \(step)")
                }
            }
        }
    }

    @Test func differsAmongPlayingWonAndFailed() {
        let steps: AuroraLoomSteps = AuroraLoomSteps(wave: [0, 4, 11], phase: [6, 6, 6])
        let playing: AmbientLoopRecipe = AuroraLoomSoundRecipe.recipe(steps: steps, stage: .playing)
        let won: AmbientLoopRecipe = AuroraLoomSoundRecipe.recipe(steps: steps, stage: .won)
        let failed: AmbientLoopRecipe = AuroraLoomSoundRecipe.recipe(steps: steps, stage: .failed)
        #expect(playing != won && playing != failed && won != failed)
        #expect(playing.partials.count == 3 && failed.partials.count == 3 && won.partials.count == 4)
        #expect(won.gain > playing.gain && playing.gain > failed.gain)
        // The fifth sits above the lowest partial: 110 Hz × 3 / 2 = 165 Hz, 1,320 cycles in 8 s.
        #expect(won.partials[3].cyclesPerLoop == 1_320)
    }

    @Test func validForEveryWaveCombinationAndStage() {
        var count: Int = 0
        for stage in Self.stages {
            for a in 0..<16 {
                for b in 0..<16 {
                    for c in 0..<16 {
                        let recipe: AmbientLoopRecipe = AuroraLoomSoundRecipe.recipe(
                            steps: AuroraLoomSteps(wave: [a, b, c], phase: [0, 0, 0]), stage: stage)
                        if !recipe.isValid { Issue.record("invalid \(stage) \(a) \(b) \(c)") }
                        count += 1
                    }
                }
            }
        }
        #expect(count == 3 * 4_096)
        for stage in AuroraLoomStage.allCases {
            #expect(AuroraLoomSoundRecipe.recipe(steps: AuroraLoomSteps(wave: [], phase: []), stage: stage).isValid)
        }
    }

    @Test func phaseAloneDoesNotChangeTheRecipe() {
        for stage in Self.stages {
            let reference: AmbientLoopRecipe = AuroraLoomSoundRecipe.recipe(
                steps: AuroraLoomSteps(wave: [8, 1, 12], phase: [0, 0, 0]), stage: stage)
            for ribbon in 0..<3 {
                for step in 0..<16 {
                    var phase: [Int] = [0, 0, 0]
                    phase[ribbon] = step
                    let recipe: AmbientLoopRecipe = AuroraLoomSoundRecipe.recipe(
                        steps: AuroraLoomSteps(wave: [8, 1, 12], phase: phase), stage: stage)
                    #expect(recipe == reference, "\(stage) ribbon \(ribbon) phase \(step)")
                }
            }
        }
    }

    @Test func pentatonicTableIsWholeHertzAndRising() {
        let table: [Int] = AuroraLoomSoundRecipe.pentatonicHertz
        #expect(table.count == 16 && table.first == 110 && table.last == 880)
        for index in 1..<table.count { #expect(table[index] > table[index - 1]) }
    }
}
