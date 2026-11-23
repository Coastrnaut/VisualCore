// EchoCartographerSoundRecipeTests — feature 406 (R02-G11-06) T-R02G1106-004 (FR-R02G1106-006; SC-R02G1106-004;
// clarification Q4). The ambient recipe: the root step at its boundaries (0 for more than 3/4 of the energy budget
// left, 1 for more than 1/2, 2 for more than 1/4, else 3), checked against an independent fraction comparison for every
// budget 1 … 60; pure (equal inputs give equal recipes); different for every change of the root step, of the beacon
// partials (the located beacons clamped to 0 … 4) and of the stage among playing, won and failed; the documented
// partials (root 110 Hz × (1, 9/8, 5/4, 4/3)[step], a partial per located beacon at the root × (5/4, 3/2, 2, 5/2)[k −
// 1], up to four, the root alone with none located, the octave and a two-cycle swell when won, halved amplitudes and
// gain when failed); the loop length the longest in 4 … 16 s at which every partial has a whole number of cycles (16 s
// for steps 0 … 2, 15 s for step 3); a valid `AmbientLoopRecipe` within its limits for every input; and `recipe(play:)`
// over real kernel plays of the hand level (`EchoCartographerFixtures.handLevel`) with energies 1 … 8 — pulses, hits,
// misses, wins, failures, results, pauses and undos — equal to the recipe of the play's root step, located count and
// stage, equal for equal plays and different whenever those differ. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import EchoCartographerCore
import VisualCoreAudioDSP

@Suite struct EchoCartographerSoundRecipeTests {
    typealias Recipe = EchoCartographerSoundRecipe
    typealias Play = EchoCartographerPlay
    /// The stages whose sound differs.
    static let stages: [EchoCartographerStage] = [.playing, .won, .failed]

    /// The highest frequency any recipe sounds: the fourth beacon partial at step 3, 110 × 4/3 × 5/2 Hz (plus
    /// rounding).
    static let highestHertz: Double = 110.0 * 4.0 / 3.0 * 5.0 / 2.0 + 1e-9

    /// Whether `value` is a whole number (within a rounding tolerance far below one cycle).
    static func isWhole(_ value: Double) -> Bool { abs(value - value.rounded()) < 1e-6 }

    /// The root step by an independent rule: the share of the budget left compared with 3/4, 1/2 and 1/4 as
    /// cross-multiplied fractions written out differently (energy / budget > p / q ⇔ energy · q > p · budget).
    static func expectedStep(energy: Int, budget: Int) -> Int {
        let thresholds: [(Int, Int)] = [(3, 4), (1, 2), (1, 4)]
        for index in thresholds.indices {
            let (p, q): (Int, Int) = thresholds[index]
            if energy * q > p * budget { return index }
        }
        return 3
    }

    @Test func theRootStepAtItsBoundaries() {
        // Budget 8: 8 and 7 left (more than 6) step 0; 6 and 5 (more than 4) step 1; 4 and 3 (more than 2) step 2;
        // 2, 1 and 0 step 3.
        let eight: [Int] = [3, 3, 3, 2, 2, 1, 1, 0, 0]
        for energy in 0...8 { #expect(Recipe.rootStep(energy: energy, budget: 8) == eight[energy], "\(energy) of 8") }
        // Budget 4: exactly 3/4, 1/2 and 1/4 left fall to the next step.
        let four: [Int] = [3, 3, 2, 1, 0]
        for energy in 0...4 { #expect(Recipe.rootStep(energy: energy, budget: 4) == four[energy], "\(energy) of 4") }
        // Budget 1: full is step 0, empty step 3; a budget below 1 counts as 1.
        #expect(Recipe.rootStep(energy: 1, budget: 1) == 0 && Recipe.rootStep(energy: 0, budget: 1) == 3)
        #expect(Recipe.rootStep(energy: 1, budget: 0) == 0 && Recipe.rootStep(energy: 0, budget: -3) == 3)
        // Every budget the kernel allows, every energy: the independent rule, never rising as energy drains.
        for budget in EchoCartographerLevel.energies {
            var previous: Int = 0
            for energy in stride(from: budget, through: 0, by: -1) {
                let step: Int = Recipe.rootStep(energy: energy, budget: budget)
                #expect(step == Self.expectedStep(energy: energy, budget: budget), "\(energy) of \(budget)")
                #expect(step >= previous && Recipe.rootSteps.contains(step))
                previous = step
            }
            #expect(Recipe.rootStep(energy: budget, budget: budget) == 0)
            #expect(Recipe.rootStep(energy: 0, budget: budget) == 3)
        }
        #expect(Recipe.clampedStep(-2) == 0 && Recipe.clampedStep(9) == 3)
    }

    @Test func theDocumentedPartials() {
        #expect(Recipe.rootHertz == 110)
        let stepRatios: [Double] = [1.0, 1.125, 1.25, 4.0 / 3.0]
        let beaconRatios: [Double] = [1.25, 1.5, 2.0, 2.5]
        #expect(Recipe.stepRatios == stepRatios)
        #expect(Recipe.beaconRatios == beaconRatios)
        // None located at step 0: the root alone, 110 Hz over 16 s.
        let alone: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, located: 0, stage: .playing)
        #expect(alone.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.6)])
        #expect(alone.gain == 0.2 && alone.swellCycles == 1 && alone.seconds == 16)
        // Three located at step 0: root, 5/4, 3/2 and 2.
        let three: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, located: 3, stage: .playing)
        #expect(three.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520])
        // Step 1 (9/8): 123.75 Hz, whole over 16 s only.
        let second: AmbientLoopRecipe = Recipe.recipe(rootStep: 1, located: 2, stage: .playing)
        #expect(second.seconds == 16 && second.partials.map(\.cyclesPerLoop) == [1_980, 2_475, 2_970])
        // Step 3 (4/3): 146.67 Hz, whole only in multiples of 3 s, so 15 s.
        let high: AmbientLoopRecipe = Recipe.recipe(rootStep: 3, located: 4, stage: .playing)
        #expect(high.seconds == 15 && high.partials.map(\.cyclesPerLoop) == [2_200, 2_750, 3_300, 4_400, 5_500])
        // Won with four located: root, four partials and the octave, swelling twice.
        let won: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, located: 4, stage: .won)
        #expect(won.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520, 4_400, 3_520])
        #expect(won.partials.count == 6 && won.swellCycles == 2 && won.gain == 0.2)
        // None located when won: the root and its octave.
        #expect(Recipe.recipe(rootStep: 2, located: 0, stage: .won).partials.map(\.cyclesPerLoop) == [2_200, 4_400])
        // Failed: amplitudes and gain halved.
        let failed: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, located: 1, stage: .failed)
        #expect(failed.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.3),
                                    AmbientLoopPartial(cyclesPerLoop: 2_200, amplitude: 0.3)])
        #expect(failed.gain == 0.1 && failed.swellCycles == 1)
        // At most four beacon partials; the step is clamped to 0 … 3; negative located counts count as none.
        let four: AmbientLoopRecipe = Recipe.recipe(rootStep: 1, located: 4, stage: .playing)
        #expect(Recipe.recipe(rootStep: 1, located: 6, stage: .playing) == four)
        #expect(Recipe.recipe(rootStep: -1, located: 1, stage: .playing)
                == Recipe.recipe(rootStep: 0, located: 1, stage: .playing))
        #expect(Recipe.recipe(rootStep: 7, located: 1, stage: .playing)
                == Recipe.recipe(rootStep: 3, located: 1, stage: .playing))
        #expect(Recipe.recipe(rootStep: 0, located: -2, stage: .playing) == alone)
        #expect(Recipe.beaconPartials(located: 7) == 4 && Recipe.beaconPartials(located: -1) == 0)
    }

    @Test func pureAndDistinct() {
        var seen: [AmbientLoopRecipe] = []
        for step in 0...3 {
            for located in 0...4 {
                for stage in Self.stages {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(rootStep: step, located: located, stage: stage)
                    // Equal inputs give equal recipes.
                    #expect(recipe == Recipe.recipe(rootStep: step, located: located, stage: stage))
                    for earlier in seen { #expect(recipe != earlier, "step \(step) located \(located) \(stage)") }
                    seen.append(recipe)
                }
            }
        }
        #expect(seen.count == 60)
        // The other stages sound as playing.
        let playing: AmbientLoopRecipe = Recipe.recipe(rootStep: 2, located: 2, stage: .playing)
        let others: [EchoCartographerStage] = [.loading, .tutorial, .paused, .result]
        for stage in others { #expect(Recipe.recipe(rootStep: 2, located: 2, stage: stage) == playing) }
    }

    @Test func everyRecipeIsWithinTheLimitsWithWholeCycles() {
        for step in -1...5 {
            for located in -2...7 {
                for stage in EchoCartographerStage.allCases {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(rootStep: step, located: located, stage: stage)
                    let label: String = "step \(step) located \(located) \(stage)"
                    #expect(recipe.isValid, "\(label)")
                    #expect(AmbientLoopRecipe.partialCountRange.contains(recipe.partials.count), "\(label)")
                    #expect(recipe.partials.count <= 6)
                    #expect(AmbientLoopRecipe.secondsRange.contains(recipe.seconds), "\(label)")
                    #expect(recipe.gain <= Recipe.baseGain && recipe.gain > 0)
                    #expect(recipe.seconds == Recipe.loopSeconds(rootStep: step, located: located, stage: stage))
                    // The partials sound the documented frequencies, each a whole number of cycles in the loop.
                    let frequencies: [Double] = Recipe.frequencies(rootStep: step, located: located, stage: stage)
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
                #expect(Recipe.loopSeconds(rootStep: step, located: 4, stage: stage) == (step == 3 ? 15 : 16))
                #expect(Recipe.loopSeconds(rootStep: step, located: 0, stage: stage) == (step == 3 ? 15 : 16))
            }
        }
    }

    @Test func theRootAloneOctaveWhenWonAndHalvedWhenFailed() {
        for step in 0...3 {
            let root: Double = 110 * Recipe.stepRatios[step]
            let alone: [Double] = Recipe.frequencies(rootStep: step, located: 0, stage: .playing)
            #expect(alone.count == 1 && abs((alone.first ?? 0) - root) < 1e-9)
            for located in 0...4 {
                let playing: AmbientLoopRecipe = Recipe.recipe(rootStep: step, located: located, stage: .playing)
                #expect(playing.partials.count == 1 + located)
                let won: AmbientLoopRecipe = Recipe.recipe(rootStep: step, located: located, stage: .won)
                #expect(won.partials.count == playing.partials.count + 1)
                #expect(Array(won.partials.prefix(playing.partials.count)) == playing.partials)
                #expect(won.partials.last?.cyclesPerLoop == playing.partials[0].cyclesPerLoop * 2)
                #expect(won.swellCycles == 2 && playing.swellCycles == 1)
                let failed: AmbientLoopRecipe = Recipe.recipe(rootStep: step, located: located, stage: .failed)
                #expect(failed.seconds == playing.seconds && failed.gain == playing.gain / 2)
                #expect(failed.partials.map(\.cyclesPerLoop) == playing.partials.map(\.cyclesPerLoop))
                for index in failed.partials.indices {
                    #expect(failed.partials[index].amplitude == playing.partials[index].amplitude / 2)
                }
            }
        }
    }

    /// A fresh play of `level` in stage `playing`.
    static func fresh(_ level: EchoCartographerLevel) throws -> Play {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The sound key of `play` by an independent reading: the root step, the located count up to 4 and the stage
    /// group (won, failed, or playing for every other stage).
    static func key(_ play: Play) -> String {
        let step: Int = expectedStep(energy: play.energy, budget: play.level.energy)
        let group: String = play.stage == .won ? "won" : (play.stage == .failed ? "failed" : "playing")
        return "\(step) \(min(play.located.count, 4)) \(group)"
    }

    /// Real plays of the hand level with energies 1 … 8 and miss costs 1 … 3: every prefix of a script of pulses, hits
    /// and misses (refused actions skipped), its undo, its pause, and its result once ended.
    static func realPlays() throws -> [Play] {
        let pulse: EchoCartographerAction = .pulse(0, 0)
        let pulseAgain: EchoCartographerAction = .pulse(0, 4)
        let miss: EchoCartographerAction = .claim(0, 4)
        let firstHit: EchoCartographerAction = .claim(2, 2)
        let secondHit: EchoCartographerAction = .claim(6, 0)
        let script: [EchoCartographerAction] = [pulse, miss, pulseAgain, firstHit, pulse, miss, secondHit]
        var plays: [Play] = []
        for energy in 1...8 {
            for missCost in 1...3 {
                let level: EchoCartographerLevel = EchoCartographerFixtures.handLevel(energy: energy,
                                                                                      missCost: missCost)
                var play: Play = try fresh(level)
                plays.append(play)
                for action in script where play.stage == .playing {
                    do {
                        try play.apply(action, expecting: play.fingerprint)
                    } catch {
                        continue
                    }
                    plays.append(play)
                    if play.canUndo {
                        var undone: Play = play
                        try undone.undo()
                        plays.append(undone)
                    }
                    if play.stage == .playing {
                        var paused: Play = play
                        try paused.handle(.pause)
                        plays.append(paused)
                    }
                }
                if play.stage == .won || play.stage == .failed {
                    var result: Play = play
                    try result.handle(.showResult)
                    plays.append(result)
                }
            }
        }
        return plays
    }

    @Test func realPlaysSoundTheirStateEqualWhenEqualAndDifferentWhenDifferent() throws {
        let plays: [Play] = try Self.realPlays()
        var keys: [String] = []
        var recipes: [AmbientLoopRecipe] = []
        var steps: Set<Int> = []
        var stagesMet: Set<EchoCartographerStage> = []
        var locatedMet: Set<Int> = []
        for play in plays {
            let recipe: AmbientLoopRecipe = Recipe.recipe(play: play)
            let step: Int = Self.expectedStep(energy: play.energy, budget: play.level.energy)
            steps.insert(step)
            stagesMet.insert(play.stage)
            locatedMet.insert(play.located.count)
            #expect(recipe == Recipe.recipe(rootStep: step, located: play.located.count, stage: play.stage))
            #expect(recipe == Recipe.recipe(play: play))
            #expect(recipe.isValid && recipe.partials.count <= 6)
            keys.append(Self.key(play))
            recipes.append(recipe)
        }
        #expect(plays.count > 100)
        #expect(steps.count == 4, "root steps met: \(steps.sorted())")
        let wanted: [EchoCartographerStage] = [.playing, .paused, .won, .failed, .result]
        for stage in wanted { #expect(stagesMet.contains(stage), "\(stage) not met") }
        #expect(locatedMet == [0, 1, 2])
        // Equal states sound equal; different states sound different.
        for first in recipes.indices {
            for second in recipes.indices where second > first {
                #expect((keys[first] == keys[second]) == (recipes[first] == recipes[second]),
                        "\(keys[first]) vs \(keys[second])")
            }
        }
        // A win on the 6-energy hand level adds the octave and the two-cycle swell to two beacon partials.
        var won: Play = try Self.fresh(EchoCartographerFixtures.handLevel())
        let winning: [EchoCartographerAction] = [.pulse(0, 0), .claim(2, 2), .claim(6, 0)]
        for action in winning { try won.apply(action, expecting: won.fingerprint) }
        #expect(won.stage == .won)
        let last: AmbientLoopRecipe = Recipe.recipe(play: won)
        #expect(last.swellCycles == 2 && last.partials.count == 4)
        // 5 of 6 energy left (more than 3/4): step 0, 16 s.
        #expect(last.seconds == 16 && last.partials[0].cyclesPerLoop == 1_760)
    }
}
