// VoxelOrigamiSoundRecipeTests — feature 446 (R02-G15-06) T-R02G1506-004 (FR-R02G1506-006; SC-R02G1506-004;
// clarification Q4). The audition: hinge h's tone 220 Hz × 2^((h − 1) / 12), one semitone per hinge index, clamped to
// hinges 1 … 11; over real plays of the certified levels around the feature seed 2_446 (levels 46, 47 and 48, from
// `VoxelOrigamiExperienceCore.opening(number:)`, at their opening and after each turn of their certified plans,
// `generated(number:).plan.turns`), for every hinge: a hinge that can turn sounds its tone and its fifth (ratio 3/2), a
// consonant chord; a hinge that swings nothing sounds its tone and a partial 3 Hz above, a 3 Hz beat; each at gain
// 0.04; silence for the root (0), a negative index and one past the last hinge; 0.6 s; pure (equal plays give equal
// auditions) and different whenever the (hinge, can turn) pair differs. The ambient recipe: the root step at its
// boundaries (0 for more than 3/4 of the action budget left, 1 for more than 1/2, 2 for more than 1/4, else 3), checked
// against an independent fraction comparison for every budget the kernel allows; the covered quarters min(4, ⌊4c / n⌋)
// of c covered cells of n cubes, independently and over real plays; pure (equal inputs give equal recipes); different
// for every change of the root step, of the covered quarters and of the stage among playing, won and failed; the
// documented partials (root 110 Hz × (1, 9/8, 5/4, 4/3)[step], a partial per quarter at the root ×
// (5/4, 3/2, 2, 5/2)[k − 1], up to four, the root alone below a quarter, the octave when won, halved amplitudes and gain when failed); the
// loop length the longest in 4 … 16 s at which every partial has a whole number of cycles; a valid `AmbientLoopRecipe`
// within its limits for every input; and `recipe(play:)` over real plays (turns, undo, a won plan, a budget failure, a
// result, a pause) equal to the recipe of the play's root step, covered quarters and stage, equal for equal keys and
// different whenever the keys differ. Explicit types, plain loops, short runs, no clocks.
import Foundation
import Testing
import VisualCoreAudioDSP
@testable import VoxelOrigamiCore

@Suite struct VoxelOrigamiSoundRecipeTests {
    typealias Recipe = VoxelOrigamiSoundRecipe
    typealias Audition = VoxelOrigamiAudition
    typealias Partial = VoxelOrigamiPartial
    typealias Play = VoxelOrigamiPlay
    typealias Core = VoxelOrigamiExperienceCore
    /// The feature's fixture seed.
    static let seed: UInt64 = 2_446
    /// The primary level the seed opens (47) and its neighbours.
    static let numbers: [Int] = [Core.levelNumber(forSeed: seed) - 1, Core.levelNumber(forSeed: seed),
                                 Core.levelNumber(forSeed: seed) + 1]
    /// The stages whose sound differs.
    static let stages: [VoxelOrigamiStage] = [.playing, .won, .failed]
    /// The highest frequency any recipe sounds: the fourth quarter partial at step 3, 110 × 4/3 × 5/2 Hz (plus
    /// rounding).
    static let highestHertz: Double = 110.0 * 4.0 / 3.0 * 5.0 / 2.0 + 1e-9

    /// Whether `value` is a whole number (within a rounding tolerance far below one cycle).
    static func isWhole(_ value: Double) -> Bool { abs(value - value.rounded()) < 1e-6 }

    /// The tone of hinge `hinge` by the documented formula, unclamped.
    static func hertz(_ hinge: Int) -> Double { 220 * pow(2, Double(hinge - 1) / 12) }

    /// The plays of certified level `number`: the opening and the play after each turn of its certified plan (the
    /// last one won).
    static func planPlays(_ number: Int) throws -> [Play] {
        var play: Play = try Core.opening(number: number).play
        var plays: [Play] = [play]
        for action in try Core.generated(number: number).plan.turns {
            try play.apply(action, expecting: play.fingerprint)
            plays.append(play)
        }
        #expect(play.stage == .won)
        return plays
    }

    @Test func theTonesPerHingeAndTheirClamp() {
        #expect(Audition.duration == 0.6 && Audition.toneGain == 0.04)
        #expect(Audition.tone(hinge: 1) == 220)
        #expect(abs(Audition.tone(hinge: 11) - 391.995_435_981_749_3) < 1e-9)
        var previous: Double = 0
        for hinge in 1...11 {
            let tone: Double = Audition.tone(hinge: hinge)
            #expect(abs(tone - Self.hertz(hinge)) < 1e-9, "hinge \(hinge)")
            #expect(tone > previous)
            if hinge > 1 { #expect(abs(tone / previous - pow(2, 1.0 / 12)) < 1e-12, "semitone at \(hinge)") }
            previous = tone
        }
        // Outside 1 … 11 the index is clamped.
        #expect(Audition.tone(hinge: 0) == 220 && Audition.tone(hinge: -4) == 220)
        let top: Double = Audition.tone(hinge: 11)
        #expect(Audition.tone(hinge: 12) == top && Audition.tone(hinge: 40) == top)
    }

    @Test func aTurnableHingeIsAChordAndAnIdleOneBeats() throws {
        var chords: Int = 0
        var beats: Int = 0
        for number in Self.numbers {
            for play in try Self.planPlays(number) {
                let count: Int = play.level.cubes.count
                for hinge in 1..<count {
                    let audition: Audition = Audition.of(play, hinge: hinge)
                    let tone: Double = Self.hertz(hinge)
                    #expect(audition.partials.count == 2, "level \(number) hinge \(hinge)")
                    guard audition.partials.count == 2 else { continue }
                    let first: Partial = audition.partials[0]
                    let second: Partial = audition.partials[1]
                    #expect(abs(first.frequency - tone) < 1e-9 && first.gain == 0.04 && second.gain == 0.04)
                    if play.level.canTurn(hinge, turns: play.turns) {
                        // A consonant chord: the fifth, ratio exactly 3/2.
                        #expect(abs(second.frequency / first.frequency - 1.5) < 1e-12, "level \(number) h \(hinge)")
                        chords += 1
                    } else {
                        // A 3 Hz beat: the partials differ by exactly 3 Hz.
                        #expect(abs(second.frequency - first.frequency - 3) < 1e-9, "level \(number) h \(hinge)")
                        beats += 1
                    }
                    // Pure: an equal play gives an equal audition.
                    let copy: Play = play
                    #expect(Audition.of(copy, hinge: hinge) == audition)
                }
                // Silence for a hinge the level lacks.
                for missing in [0, -1, count, count + 3] {
                    #expect(Audition.of(play, hinge: missing).partials.isEmpty, "level \(number) hinge \(missing)")
                }
            }
        }
        #expect(chords > 0 && beats > 0, "\(chords) chords, \(beats) beats")
    }

    @Test func auditionsDifferWheneverTheHingeOrItsTurnDiffers() throws {
        // Every (hinge, can turn) pair over the plays gives one audition, and different pairs different auditions.
        var keys: [String] = []
        var auditions: [Audition] = []
        for number in Self.numbers {
            for play in try Self.planPlays(number) {
                for hinge in 1..<play.level.cubes.count {
                    let key: String = "\(hinge)/\(play.level.canTurn(hinge, turns: play.turns))"
                    let audition: Audition = Audition.of(play, hinge: hinge)
                    for index in keys.indices {
                        #expect((keys[index] == key) == (auditions[index] == audition), "\(key) vs \(keys[index])")
                    }
                    keys.append(key)
                    auditions.append(audition)
                }
            }
        }
        #expect(keys.count > 20)
    }

    /// The root step by an independent rule: the first threshold p / q (3/4, 1/2, 1/4) the share left exceeds.
    static func expectedStep(left: Int, budget: Int) -> Int {
        let whole: Int = max(budget, 1)
        let thresholds: [(Int, Int)] = [(3, 4), (1, 2), (1, 4)]
        for index in thresholds.indices {
            let (p, q): (Int, Int) = thresholds[index]
            if left * q > p * whole { return index }
        }
        return 3
    }

    @Test func theRootStepAtItsBoundaries() {
        // Budget 8: 8 and 7 left (more than 6) step 0; 6 and 5 (more than 4) step 1; 4 and 3 (more than 2) step 2;
        // 2, 1 and 0 step 3.
        let eight: [Int] = [3, 3, 3, 2, 2, 1, 1, 0, 0]
        for left in 0...8 { #expect(Recipe.rootStep(actionsLeft: left, budget: 8) == eight[left], "\(left) of 8") }
        // Budget 4: exactly 3/4, 1/2 and 1/4 left fall to the next step.
        let four: [Int] = [3, 3, 2, 1, 0]
        for left in 0...4 { #expect(Recipe.rootStep(actionsLeft: left, budget: 4) == four[left], "\(left) of 4") }
        // Budget 1: full is step 0, empty step 3; a budget below 1 counts as 1.
        #expect(Recipe.rootStep(actionsLeft: 1, budget: 1) == 0 && Recipe.rootStep(actionsLeft: 0, budget: 1) == 3)
        #expect(Recipe.rootStep(actionsLeft: 1, budget: 0) == 0 && Recipe.rootStep(actionsLeft: 0, budget: -3) == 3)
        // Every budget the kernel allows, every count left: the independent rule, never falling as actions drain.
        for budget in VoxelOrigamiLevel.budgets {
            var previous: Int = 0
            for left in stride(from: budget, through: 0, by: -1) {
                let step: Int = Recipe.rootStep(actionsLeft: left, budget: budget)
                #expect(step == Self.expectedStep(left: left, budget: budget), "\(left) of \(budget)")
                #expect(step >= previous && Recipe.rootSteps.contains(step))
                previous = step
            }
        }
        #expect(Recipe.clampedStep(-2) == 0 && Recipe.clampedStep(9) == 3)
    }

    /// The covered quarters by an independent rule: the largest k in 0 … 4 with k / 4 ≤ covered / cubes.
    static func expectedQuarters(covered: Int, cubes: Int) -> Int {
        guard cubes > 0 else { return 0 }
        var best: Int = 0
        for k in 0...4 where k * cubes <= 4 * covered { best = k }
        return best
    }

    @Test func theQuartersFromTheCoveredCounts() throws {
        // 8 cubes: 0 … 1 covered none, 2 … 3 one quarter, 4 … 5 two, 6 … 7 three, 8 all four.
        let eight: [Int] = [0, 0, 1, 1, 2, 2, 3, 3, 4]
        for covered in 0...8 { #expect(Recipe.quarters(covered: covered, cubes: 8) == eight[covered], "\(covered)/8") }
        for cubes in VoxelOrigamiLevel.cubeCounts {
            for covered in 0...cubes {
                #expect(Recipe.quarters(covered: covered, cubes: cubes)
                        == Self.expectedQuarters(covered: covered, cubes: cubes), "\(covered) of \(cubes)")
            }
        }
        #expect(Recipe.quarters(covered: 3, cubes: 0) == 0 && Recipe.quarters(covered: -2, cubes: 5) == 0)
        #expect(Recipe.quarters(covered: 9, cubes: 5) == 4)
        #expect(Recipe.quarterPartials(quarters: 7) == 4 && Recipe.quarterPartials(quarters: -1) == 0)
        // Real plays: the quarters of the kernel's covered count over the cube count; a won play has every cube in
        // place.
        for number in Self.numbers {
            let plays: [Play] = try Self.planPlays(number)
            for play in plays {
                let expected: Int = Self.expectedQuarters(covered: play.report.covered, cubes: play.level.cubes.count)
                #expect(Recipe.coveredQuarters(play) == expected, "level \(number)")
            }
            if let last = plays.last { #expect(Recipe.coveredQuarters(last) == 4) }
        }
    }

    @Test func theDocumentedPartials() {
        #expect(Recipe.rootHertz == 110)
        let stepRatios: [Double] = [1.0, 1.125, 1.25, 4.0 / 3.0]
        let quarterRatios: [Double] = [1.25, 1.5, 2.0, 2.5]
        #expect(Recipe.stepRatios == stepRatios)
        #expect(Recipe.quarterRatios == quarterRatios)
        // None in place at step 0: the root alone, 110 Hz over 16 s.
        let alone: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 0, stage: .playing)
        #expect(alone.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.6)])
        #expect(alone.gain == 0.2 && alone.swellCycles == 1 && alone.seconds == 16)
        // Three quarters at step 0: root, 5/4, 3/2 and 2.
        let three: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 3, stage: .playing)
        #expect(three.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520])
        // Step 1 (9/8): 123.75 Hz, whole over 16 s.
        let second: AmbientLoopRecipe = Recipe.recipe(rootStep: 1, quarters: 2, stage: .playing)
        #expect(second.seconds == 16 && second.partials.map(\.cyclesPerLoop) == [1_980, 2_475, 2_970])
        // Step 3 (4/3): 146.67 Hz, whole only in multiples of 3 s, so 15 s.
        let high: AmbientLoopRecipe = Recipe.recipe(rootStep: 3, quarters: 4, stage: .playing)
        #expect(high.seconds == 15 && high.partials.map(\.cyclesPerLoop) == [2_200, 2_750, 3_300, 4_400, 5_500])
        // Won with four quarters: root, four partials and the octave, swelling twice.
        let won: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 4, stage: .won)
        #expect(won.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520, 4_400, 3_520])
        #expect(won.partials.count == 6 && won.swellCycles == 2 && won.gain == 0.2)
        // Failed: amplitudes and gain halved.
        let failed: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 1, stage: .failed)
        #expect(failed.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.3),
                                    AmbientLoopPartial(cyclesPerLoop: 2_200, amplitude: 0.3)])
        #expect(failed.gain == 0.1 && failed.swellCycles == 1)
        // At most four quarter partials; the step is clamped to 0 … 3; negative counts count as none.
        let four: AmbientLoopRecipe = Recipe.recipe(rootStep: 1, quarters: 4, stage: .playing)
        #expect(Recipe.recipe(rootStep: 1, quarters: 6, stage: .playing) == four)
        #expect(Recipe.recipe(rootStep: -1, quarters: 1, stage: .playing)
                == Recipe.recipe(rootStep: 0, quarters: 1, stage: .playing))
        #expect(Recipe.recipe(rootStep: 7, quarters: 1, stage: .playing)
                == Recipe.recipe(rootStep: 3, quarters: 1, stage: .playing))
        #expect(Recipe.recipe(rootStep: 0, quarters: -2, stage: .playing) == alone)
    }

    @Test func pureAndDistinct() {
        var seen: [AmbientLoopRecipe] = []
        for step in 0...3 {
            for quarters in 0...4 {
                for stage in Self.stages {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(rootStep: step, quarters: quarters, stage: stage)
                    // Equal inputs give equal recipes.
                    #expect(recipe == Recipe.recipe(rootStep: step, quarters: quarters, stage: stage))
                    for earlier in seen { #expect(recipe != earlier, "step \(step) quarters \(quarters) \(stage)") }
                    seen.append(recipe)
                }
            }
        }
        #expect(seen.count == 60)
        // The other stages sound as playing.
        let playing: AmbientLoopRecipe = Recipe.recipe(rootStep: 2, quarters: 2, stage: .playing)
        let others: [VoxelOrigamiStage] = [.loading, .tutorial, .paused, .result]
        for stage in others { #expect(Recipe.recipe(rootStep: 2, quarters: 2, stage: stage) == playing) }
    }

    @Test func everyRecipeIsWithinTheLimitsWithWholeCycles() {
        for step in -1...5 {
            for quarters in -2...7 {
                for stage in VoxelOrigamiStage.allCases {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(rootStep: step, quarters: quarters, stage: stage)
                    let label: String = "step \(step) quarters \(quarters) \(stage)"
                    #expect(recipe.isValid, "\(label)")
                    #expect(AmbientLoopRecipe.partialCountRange.contains(recipe.partials.count), "\(label)")
                    #expect(AmbientLoopRecipe.secondsRange.contains(recipe.seconds), "\(label)")
                    #expect(AmbientLoopRecipe.gainRange.contains(recipe.gain))
                    #expect(recipe.gain <= Recipe.baseGain && recipe.gain > 0)
                    #expect(recipe.seconds == Recipe.loopSeconds(rootStep: step, quarters: quarters, stage: stage))
                    // The partials sound the documented frequencies, each a whole number of cycles in the loop.
                    let frequencies: [Double] = Recipe.frequencies(rootStep: step, quarters: quarters, stage: stage)
                    #expect(frequencies.count == recipe.partials.count, "\(label)")
                    for index in recipe.partials.indices where index < frequencies.count {
                        let partial: AmbientLoopPartial = recipe.partials[index]
                        let product: Double = frequencies[index] * Double(recipe.seconds)
                        #expect(Self.isWhole(product), "\(label) partial \(index): \(product) cycles")
                        #expect(Int(product.rounded()) == partial.cyclesPerLoop, "\(label) partial \(index)")
                        #expect(AmbientLoopPartial.amplitudeRange.contains(partial.amplitude))
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
                #expect(Recipe.loopSeconds(rootStep: step, quarters: 4, stage: stage) == (step == 3 ? 15 : 16))
                #expect(Recipe.loopSeconds(rootStep: step, quarters: 0, stage: stage) == (step == 3 ? 15 : 16))
            }
        }
    }

    @Test func theRootAloneOctaveWhenWonAndHalvedWhenFailed() {
        for step in 0...3 {
            let root: Double = 110 * Recipe.stepRatios[step]
            let alone: [Double] = Recipe.frequencies(rootStep: step, quarters: 0, stage: .playing)
            #expect(alone.count == 1 && abs((alone.first ?? 0) - root) < 1e-9)
            for quarters in 0...4 {
                let playing: AmbientLoopRecipe = Recipe.recipe(rootStep: step, quarters: quarters, stage: .playing)
                #expect(playing.partials.count == 1 + quarters)
                let won: AmbientLoopRecipe = Recipe.recipe(rootStep: step, quarters: quarters, stage: .won)
                #expect(won.partials.count == playing.partials.count + 1)
                #expect(Array(won.partials.prefix(playing.partials.count)) == playing.partials)
                #expect(won.partials.last?.cyclesPerLoop == playing.partials[0].cyclesPerLoop * 2)
                #expect(won.swellCycles == 2 && playing.swellCycles == 1)
                let failed: AmbientLoopRecipe = Recipe.recipe(rootStep: step, quarters: quarters, stage: .failed)
                #expect(failed.seconds == playing.seconds && failed.gain == playing.gain / 2)
                #expect(failed.partials.map(\.cyclesPerLoop) == playing.partials.map(\.cyclesPerLoop))
                for index in failed.partials.indices {
                    #expect(failed.partials[index].amplitude == playing.partials[index].amplitude / 2)
                }
            }
        }
    }

    /// The recipe key of `play`: its root step, covered quarters and sounding stage (the stages other than won and
    /// failed sound as playing).
    static func key(_ play: Play) -> String {
        let stage: VoxelOrigamiStage = play.stage == .won || play.stage == .failed ? play.stage : .playing
        let step: Int = Self.expectedStep(left: play.actionsLeft, budget: play.level.budget)
        let quarters: Int = Self.expectedQuarters(covered: play.report.covered, cubes: play.level.cubes.count)
        return "\(step)/\(quarters)/\(stage)"
    }

    /// Real plays of the primary level: turns forward and back on hinge 1 until the budget is spent (a budget
    /// failure), its undo, the result after it, a pause, and the certified plan won and its result.
    static func scriptedPlays() throws -> [Play] {
        let number: Int = Core.levelNumber(forSeed: seed)
        var play: Play = try Core.opening(number: number).play
        var plays: [Play] = [play]
        var forward: Bool = true
        while play.stage == .playing {
            try play.apply(.turn(1, forward ? 1 : -1), expecting: play.fingerprint)
            forward.toggle()
            plays.append(play)
        }
        #expect(play.stage == .failed && play.actionsLeft == 0)
        var shown: Play = play
        try shown.handle(.showResult)
        plays.append(shown)
        try play.undo()
        plays.append(play)
        try play.handle(.pause)
        plays.append(play)
        var won: Play = try planPlays(number).last ?? play
        plays.append(won)
        try won.handle(.showResult)
        plays.append(won)
        return plays
    }

    @Test func theRecipeOfARealPlayFollowsItsKey() throws {
        var plays: [Play] = try Self.scriptedPlays()
        for number in Self.numbers { plays += try Self.planPlays(number) }
        var keys: [String] = []
        var recipes: [AmbientLoopRecipe] = []
        var stagesSeen: Set<VoxelOrigamiStage> = []
        for play in plays {
            let recipe: AmbientLoopRecipe = Recipe.recipe(play: play)
            let expected: AmbientLoopRecipe = Recipe.recipe(
                rootStep: Recipe.rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
                quarters: Recipe.coveredQuarters(play), stage: play.stage)
            #expect(recipe == expected)
            #expect(recipe.isValid)
            let key: String = Self.key(play)
            for index in keys.indices {
                #expect((keys[index] == key) == (recipes[index] == recipe), "\(key) vs \(keys[index])")
            }
            keys.append(key)
            recipes.append(recipe)
            stagesSeen.insert(play.stage)
        }
        #expect(stagesSeen.isSuperset(of: [.playing, .won, .failed, .result, .paused]))
        // The keys cover several root steps as the budget drains.
        var steps: Set<Int> = []
        for play in plays { steps.insert(Recipe.rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget)) }
        #expect(steps == [0, 1, 2, 3])
    }
}
