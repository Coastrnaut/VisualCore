// BackwardsAuroraSoundRecipeTests — feature 396 (R02-G10-06) T-R02G1006-004 (FR-R02G1006-006; SC-R02G1006-004;
// clarification Q4). The ambient recipe: the root step at its boundaries (0 for a worst bend at most the limit L, 1 at
// most 2L, 2 at most 4L, else 3); pure (equal inputs give equal recipes); different for every change of the root step,
// of the checkpoint partials (the matched checkpoints clamped to 0 … 4) and of the stage among playing, won and failed;
// the documented partials (root 110 Hz × (1, 9/8, 5/4, 4/3)[step], a partial per matched checkpoint at the root ×
// (5/4, 3/2, 2, 5/2)[k − 1], up to four, the root alone with none matched, the octave and a two-cycle swell when won,
// halved amplitudes and gain when failed); the loop length the longest in 4 … 16 s at which every partial has a whole
// number of cycles (16 s for steps 0 … 2, 15 s for step 3); a valid `AmbientLoopRecipe` of at most 6 partials for every
// input; and `recipe(play:)` over real plays of the fixture level (seed 2_396: level 97) — its certified win, a tear and
// a wandering of reversals — equal to the recipe of the play's root step, matched count and stage, equal for equal
// plays and different whenever those differ. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import BackwardsAuroraCore
import VisualCoreAudioDSP
import VisualCoreExperience

@Suite struct BackwardsAuroraSoundRecipeTests {
    typealias Recipe = BackwardsAuroraSoundRecipe
    typealias Core = BackwardsAuroraExperienceCore
    /// The fixture seed of this feature.
    static let fixtureSeed: UInt64 = 2_396
    /// The stages whose sound differs.
    static let stages: [BackwardsAuroraStage] = [.playing, .won, .failed]

    /// The highest frequency any recipe sounds: the fourth checkpoint partial at step 3, 110 × 4/3 × 5/2 Hz (plus
    /// rounding).
    static let highestHertz: Double = 110.0 * 4.0 / 3.0 * 5.0 / 2.0 + 1e-9

    /// Whether `value` is a whole number (within a rounding tolerance far below one cycle).
    static func isWhole(_ value: Double) -> Bool { abs(value - value.rounded()) < 1e-6 }

    @Test func theRootStepAtItsBoundaries() {
        for limit in [1, 2, 5, 12, 64] {
            #expect(Recipe.rootStep(worstBend: 0, limit: limit) == 0)
            #expect(Recipe.rootStep(worstBend: limit, limit: limit) == 0)
            #expect(Recipe.rootStep(worstBend: limit + 1, limit: limit) == 1)
            #expect(Recipe.rootStep(worstBend: 2 * limit, limit: limit) == 1)
            #expect(Recipe.rootStep(worstBend: 2 * limit + 1, limit: limit) == 2)
            #expect(Recipe.rootStep(worstBend: 4 * limit, limit: limit) == 2)
            #expect(Recipe.rootStep(worstBend: 4 * limit + 1, limit: limit) == 3)
            #expect(Recipe.rootStep(worstBend: 1_000, limit: limit) == 3)
        }
        // A limit below 1 counts as 1.
        #expect(Recipe.rootStep(worstBend: 1, limit: 0) == 0 && Recipe.rootStep(worstBend: 5, limit: -3) == 3)
        #expect(Recipe.clampedStep(-2) == 0 && Recipe.clampedStep(9) == 3)
    }

    @Test func theDocumentedPartials() {
        #expect(Recipe.rootHertz == 110)
        let stepRatios: [Double] = [1.0, 1.125, 1.25, 4.0 / 3.0]
        let checkpointRatios: [Double] = [1.25, 1.5, 2.0, 2.5]
        #expect(Recipe.stepRatios == stepRatios)
        #expect(Recipe.checkpointRatios == checkpointRatios)
        // None matched at step 0: the root alone, 110 Hz over 16 s.
        let alone: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, matched: 0, stage: .playing)
        #expect(alone.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.6)])
        #expect(alone.gain == 0.2 && alone.swellCycles == 1 && alone.seconds == 16)
        // Three matched at step 0: root, 5/4, 3/2 and 2.
        let three: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, matched: 3, stage: .playing)
        #expect(three.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520])
        // Step 1 (9/8): 123.75 Hz, whole over 16 s only (2,475 cycles for the first checkpoint).
        let second: AmbientLoopRecipe = Recipe.recipe(rootStep: 1, matched: 2, stage: .playing)
        #expect(second.seconds == 16 && second.partials.map(\.cyclesPerLoop) == [1_980, 2_475, 2_970])
        // Step 3 (4/3): 146.67 Hz, whole only in multiples of 3 s, so 15 s.
        let high: AmbientLoopRecipe = Recipe.recipe(rootStep: 3, matched: 4, stage: .playing)
        #expect(high.seconds == 15 && high.partials.map(\.cyclesPerLoop) == [2_200, 2_750, 3_300, 4_400, 5_500])
        // Won with four matched: root, four partials and the octave, swelling twice.
        let won: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, matched: 4, stage: .won)
        #expect(won.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520, 4_400, 3_520])
        #expect(won.partials.count == 6 && won.swellCycles == 2 && won.gain == 0.2)
        // None matched when won: the root and its octave.
        #expect(Recipe.recipe(rootStep: 2, matched: 0, stage: .won).partials.map(\.cyclesPerLoop) == [2_200, 4_400])
        // Failed: amplitudes and gain halved.
        let failed: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, matched: 1, stage: .failed)
        #expect(failed.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.3),
                                    AmbientLoopPartial(cyclesPerLoop: 2_200, amplitude: 0.3)])
        #expect(failed.gain == 0.1 && failed.swellCycles == 1)
        // At most four checkpoint partials (levels have up to six checkpoints); the step is clamped to 0 … 3; negative
        // matched counts count as none.
        let four: AmbientLoopRecipe = Recipe.recipe(rootStep: 1, matched: 4, stage: .playing)
        #expect(Recipe.recipe(rootStep: 1, matched: 6, stage: .playing) == four)
        #expect(Recipe.recipe(rootStep: -1, matched: 1, stage: .playing)
                == Recipe.recipe(rootStep: 0, matched: 1, stage: .playing))
        #expect(Recipe.recipe(rootStep: 7, matched: 1, stage: .playing)
                == Recipe.recipe(rootStep: 3, matched: 1, stage: .playing))
        #expect(Recipe.recipe(rootStep: 0, matched: -2, stage: .playing) == alone)
        #expect(Recipe.checkpointPartials(matched: 7) == 4 && Recipe.checkpointPartials(matched: -1) == 0)
    }

    @Test func pureAndDistinct() {
        var seen: [AmbientLoopRecipe] = []
        for step in 0...3 {
            for matched in 0...4 {
                for stage in Self.stages {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(rootStep: step, matched: matched, stage: stage)
                    // Equal inputs give equal recipes.
                    #expect(recipe == Recipe.recipe(rootStep: step, matched: matched, stage: stage))
                    for earlier in seen { #expect(recipe != earlier, "step \(step) matched \(matched) \(stage)") }
                    seen.append(recipe)
                }
            }
        }
        #expect(seen.count == 60)
        // The other stages sound as playing.
        let playing: AmbientLoopRecipe = Recipe.recipe(rootStep: 2, matched: 2, stage: .playing)
        for stage in [BackwardsAuroraStage.loading, .tutorial, .paused, .result] {
            #expect(Recipe.recipe(rootStep: 2, matched: 2, stage: stage) == playing)
        }
    }

    @Test func everyRecipeIsWithinTheLimitsWithWholeCycles() {
        for step in -1...5 {
            for matched in -2...7 {
                for stage in BackwardsAuroraStage.allCases {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(rootStep: step, matched: matched, stage: stage)
                    let label: String = "step \(step) matched \(matched) \(stage)"
                    #expect(recipe.isValid, "\(label)")
                    #expect(AmbientLoopRecipe.partialCountRange.contains(recipe.partials.count), "\(label)")
                    #expect(recipe.partials.count <= 6)
                    #expect(AmbientLoopRecipe.secondsRange.contains(recipe.seconds), "\(label)")
                    #expect(recipe.gain <= Recipe.baseGain && recipe.gain > 0)
                    #expect(recipe.seconds == Recipe.loopSeconds(rootStep: step, matched: matched, stage: stage))
                    // The partials sound the documented frequencies, each a whole number of cycles in the loop.
                    let frequencies: [Double] = Recipe.frequencies(rootStep: step, matched: matched, stage: stage)
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
        // The expected lengths: 16 s for steps 0 … 2, 15 s for step 3.
        for step in 0...3 {
            for stage in Self.stages {
                #expect(Recipe.loopSeconds(rootStep: step, matched: 4, stage: stage) == (step == 3 ? 15 : 16))
                #expect(Recipe.loopSeconds(rootStep: step, matched: 0, stage: stage) == (step == 3 ? 15 : 16))
            }
        }
    }

    @Test func theRootAloneOctaveWhenWonAndHalvedWhenFailed() {
        for step in 0...3 {
            let root: Double = 110 * Recipe.stepRatios[step]
            let alone: [Double] = Recipe.frequencies(rootStep: step, matched: 0, stage: .playing)
            #expect(alone.count == 1 && abs((alone.first ?? 0) - root) < 1e-9)
            for matched in 0...4 {
                let playing: AmbientLoopRecipe = Recipe.recipe(rootStep: step, matched: matched, stage: .playing)
                #expect(playing.partials.count == 1 + matched)
                let won: AmbientLoopRecipe = Recipe.recipe(rootStep: step, matched: matched, stage: .won)
                #expect(won.partials.count == playing.partials.count + 1)
                #expect(Array(won.partials.prefix(playing.partials.count)) == playing.partials)
                #expect(won.partials.last?.cyclesPerLoop == playing.partials[0].cyclesPerLoop * 2)
                #expect(won.swellCycles == 2 && playing.swellCycles == 1)
                let failed: AmbientLoopRecipe = Recipe.recipe(rootStep: step, matched: matched, stage: .failed)
                #expect(failed.seconds == playing.seconds && failed.gain == playing.gain / 2)
                #expect(failed.partials.map(\.cyclesPerLoop) == playing.partials.map(\.cyclesPerLoop))
                for index in failed.partials.indices {
                    #expect(failed.partials[index].amplitude == playing.partials[index].amplitude / 2)
                }
            }
        }
    }

    /// The inputs `recipe(play:)` reads from `play`: the root step, the matched count and the stage.
    static func inputs(_ play: BackwardsAuroraPlay) -> (step: Int, matched: Int, stage: BackwardsAuroraStage) {
        var matched: Int = 0
        for flag in play.matched where flag { matched += 1 }
        return (Recipe.rootStep(worstBend: play.worstBend, limit: play.level.bendLimit), matched, play.stage)
    }

    @Test func realPlaysSoundTheirStateEqualWhenEqualAndDifferentWhenDifferent() throws {
        let number: Int = Core.levelNumber(forSeed: Self.fixtureSeed)
        let opening: Core = try Core.opening(number: number)
        var plays: [BackwardsAuroraPlay] = [opening.play]
        // The certified win, one play per reversal.
        var core: Core = opening
        for kernel in try Core.generated(number: number).solution.actions {
            let item: ExperienceAction
            switch kernel {
            case let .reverse(start, end):
                item = ExperienceAction(control: "wave.reverse", values: [Double(start), Double(end)], step: 0)
            }
            #expect(core.apply(item) == .accepted)
            plays.append(core.play)
        }
        #expect(core.play.stage == .won)
        // Every accepted single reversal from the opening: wandering plays, tears among them.
        let count: Int = opening.play.wave.count
        var tears: Int = 0
        for start in 0..<(count - 1) {
            for end in (start + 1)..<count {
                var copy: Core = opening
                let item: ExperienceAction = ExperienceAction(control: "wave.reverse",
                                                              values: [Double(start), Double(end)], step: 0)
                if copy.apply(item) == .accepted {
                    if case .tear? = copy.play.failure { tears += 1 }
                    plays.append(copy.play)
                }
            }
        }
        #expect(tears > 0 && plays.count > 20)
        var keys: [String] = []
        var recipes: [AmbientLoopRecipe] = []
        var steps: Set<Int> = []
        for play in plays {
            let recipe: AmbientLoopRecipe = Recipe.recipe(play: play)
            let input: (step: Int, matched: Int, stage: BackwardsAuroraStage) = Self.inputs(play)
            steps.insert(input.step)
            #expect(recipe == Recipe.recipe(rootStep: input.step, matched: input.matched, stage: input.stage))
            #expect(recipe == Recipe.recipe(play: play))
            #expect(recipe.isValid && recipe.partials.count <= 6)
            keys.append("\(input.step) \(min(input.matched, 4)) \(input.stage)")
            recipes.append(recipe)
        }
        #expect(steps.count >= 2, "root steps met: \(steps.sorted())")
        // Equal states sound equal; different states sound different.
        for first in recipes.indices {
            for second in recipes.indices where second > first {
                #expect((keys[first] == keys[second]) == (recipes[first] == recipes[second]),
                        "\(keys[first]) vs \(keys[second])")
            }
        }
        // The win adds the octave and the two-cycle swell.
        let last: AmbientLoopRecipe = Recipe.recipe(play: core.play)
        #expect(last.swellCycles == 2 && last.seconds == 16)
        #expect(last.partials.count == min(core.play.level.checkpoints.count, 4) + 2)
    }
}
