// StarlitCartoucheSoundRecipeTests — feature 456 (R02-G16-06) T-R02G1606-004 (FR-R02G1606-006; SC-R02G1606-004;
// clarification Q4). The audition: star j's tone 220 Hz × 2^(j / 12), one semitone per star index, clamped to stars
// 0 … 11; over real plays of the certified levels around the feature seed 2_456 (levels 56, 57 and 58, from
// `StarlitCartoucheExperienceCore.opening(number:)`, at their opening and after each leg of their certified plans,
// `generated(number:).plan.legs`), for every star but the ship's: a star a corridor joins to the ship's star sounds its
// tone and its fifth (ratio 3/2), a consonant chord; any other sounds its tone and a partial 3 Hz above, a 3 Hz beat;
// each at gain 0.04; silence for the ship's own star, a negative index and one past the last star; 0.6 s; pure (equal
// plays give equal auditions) and different whenever the (star, reachable) pair differs. The ambient recipe: the root
// step at its boundaries (0 for more than 3/4 of the action budget left, 1 for more than 1/2, 2 for more than 1/4, else
// 3), checked against an independent fraction comparison for every budget the kernel allows; the drawn quarters
// min(4, ⌊4d / n⌋) of d symbol strokes drawn of n, independently and over real plays; pure (equal inputs give equal
// recipes); different for every change of the root step, of the drawn quarters and of the stage among playing, won and
// failed; the documented partials (root 110 Hz × (1, 9/8, 5/4, 4/3)[step], a partial per quarter at the root ×
// (5/4, 3/2, 2, 5/2)[k − 1], up to four, the root alone below a quarter, the octave when won, halved amplitudes and
// gain when failed); the loop length the longest in 4 … 16 s at which every partial has a whole number of cycles; a
// valid `AmbientLoopRecipe` within its limits for every input; and `recipe(play:)` over real plays (legs, undo, a won
// plan, a failure, a result, a pause) equal to the recipe of the play's root step, drawn quarters and stage, equal for
// equal keys and different whenever the keys differ. Explicit types, plain loops, short runs, no clocks.
import Foundation
import Testing
import VisualCoreAudioDSP
@testable import StarlitCartoucheCore

@Suite struct StarlitCartoucheSoundRecipeTests {
    typealias Recipe = StarlitCartoucheSoundRecipe
    typealias Audition = StarlitCartoucheAudition
    typealias Partial = StarlitCartouchePartial
    typealias Play = StarlitCartouchePlay
    typealias Core = StarlitCartoucheExperienceCore
    /// The feature's fixture seed.
    static let seed: UInt64 = 2_456
    /// The primary level the seed opens (57) and its neighbours.
    static let numbers: [Int] = [Core.levelNumber(forSeed: seed) - 1, Core.levelNumber(forSeed: seed),
                                 Core.levelNumber(forSeed: seed) + 1]
    /// The stages whose sound differs.
    static let stages: [StarlitCartoucheStage] = [.playing, .won, .failed]
    /// The highest frequency any recipe sounds: the fourth quarter partial at step 3, 110 × 4/3 × 5/2 Hz (plus
    /// rounding).
    static let highestHertz: Double = 110.0 * 4.0 / 3.0 * 5.0 / 2.0 + 1e-9

    /// Whether `value` is a whole number (within a rounding tolerance far below one cycle).
    static func isWhole(_ value: Double) -> Bool { abs(value - value.rounded()) < 1e-6 }

    /// The tone of star `star` by the documented formula, unclamped.
    static func hertz(_ star: Int) -> Double { 220 * pow(2, Double(star) / 12) }

    /// Whether a corridor of `play`'s level joins `star` and the ship's star, by scanning the corridors directly.
    static func joined(_ play: Play, _ star: Int) -> Bool {
        for corridor in play.level.corridors {
            if (corridor.a == star && corridor.b == play.star) || (corridor.b == star && corridor.a == play.star) {
                return true
            }
        }
        return false
    }

    /// The plays of certified level `number`: the opening and the play after each leg of its certified plan (the last
    /// one won).
    static func planPlays(_ number: Int) throws -> [Play] {
        var play: Play = try Core.opening(number: number).play
        var plays: [Play] = [play]
        for action in try Core.generated(number: number).plan.legs {
            try play.apply(action, expecting: play.fingerprint)
            plays.append(play)
        }
        #expect(play.stage == .won)
        return plays
    }

    @Test func theTonesPerStarAndTheirClamp() {
        #expect(Audition.duration == 0.6 && Audition.toneGain == 0.04)
        #expect(Audition.tone(star: 0) == 220)
        #expect(abs(Audition.tone(star: 11) - 415.304_697_579_945_1) < 1e-9)
        var previous: Double = 0
        for star in 0...11 {
            let tone: Double = Audition.tone(star: star)
            #expect(abs(tone - Self.hertz(star)) < 1e-9, "star \(star)")
            #expect(tone > previous)
            if star > 0 { #expect(abs(tone / previous - pow(2, 1.0 / 12)) < 1e-12, "semitone at \(star)") }
            previous = tone
        }
        // Outside 0 … 11 the index is clamped.
        #expect(Audition.tone(star: -1) == 220 && Audition.tone(star: -4) == 220)
        let top: Double = Audition.tone(star: 11)
        #expect(Audition.tone(star: 12) == top && Audition.tone(star: 40) == top)
    }

    @Test func aReachableStarIsAChordAndAnUnreachableOneBeats() throws {
        var chords: Int = 0
        var beats: Int = 0
        for number in Self.numbers {
            for play in try Self.planPlays(number) {
                let count: Int = play.level.stars.count
                for star in 0..<count where star != play.star {
                    let audition: Audition = Audition.of(play, star: star)
                    let tone: Double = Self.hertz(star)
                    #expect(audition.partials.count == 2, "level \(number) star \(star)")
                    guard audition.partials.count == 2 else { continue }
                    let first: Partial = audition.partials[0]
                    let second: Partial = audition.partials[1]
                    #expect(abs(first.frequency - tone) < 1e-9 && first.gain == 0.04 && second.gain == 0.04)
                    #expect(Audition.isReachable(play, star: star) == Self.joined(play, star))
                    if Self.joined(play, star) {
                        // A consonant chord: the fifth, ratio exactly 3/2.
                        #expect(abs(second.frequency / first.frequency - 1.5) < 1e-12, "level \(number) s \(star)")
                        chords += 1
                    } else {
                        // A 3 Hz beat: the partials differ by exactly 3 Hz.
                        #expect(abs(second.frequency - first.frequency - 3) < 1e-9, "level \(number) s \(star)")
                        beats += 1
                    }
                    // Pure: an equal play gives an equal audition.
                    let copy: Play = play
                    #expect(Audition.of(copy, star: star) == audition)
                }
                // Silence for the ship's own star and a star the level lacks.
                for missing in [play.star, -1, count, count + 3] {
                    #expect(Audition.of(play, star: missing).partials.isEmpty, "level \(number) star \(missing)")
                }
            }
        }
        #expect(chords > 0 && beats > 0, "\(chords) chords, \(beats) beats")
    }

    @Test func auditionsDifferWheneverTheStarOrItsReachDiffers() throws {
        // Every (star, reachable) pair over the plays gives one audition, and different pairs different auditions.
        var keys: [String] = []
        var auditions: [Audition] = []
        for number in Self.numbers {
            for play in try Self.planPlays(number) {
                for star in 0..<play.level.stars.count where star != play.star {
                    let key: String = "\(star)/\(Self.joined(play, star))"
                    let audition: Audition = Audition.of(play, star: star)
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
        for budget in StarlitCartoucheLevel.budgets {
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

    /// The drawn quarters by an independent rule: the largest k in 0 … 4 with k / 4 ≤ drawn / strokes.
    static func expectedQuarters(drawn: Int, strokes: Int) -> Int {
        guard strokes > 0 else { return 0 }
        var best: Int = 0
        for k in 0...4 where k * strokes <= 4 * drawn { best = k }
        return best
    }

    /// The symbol strokes `play` has drawn, counted independently from the kernel's report (its drawn strokes that
    /// are not stray).
    static func strokesDrawn(_ play: Play) -> Int {
        var count: Int = 0
        for stroke in play.report.drawn where !play.report.stray.contains(stroke) { count += 1 }
        return count
    }

    @Test func theQuartersFromTheDrawnStrokes() throws {
        // 8 strokes: 0 … 1 drawn none, 2 … 3 one quarter, 4 … 5 two, 6 … 7 three, 8 all four.
        let eight: [Int] = [0, 0, 1, 1, 2, 2, 3, 3, 4]
        for drawn in 0...8 { #expect(Recipe.quarters(drawn: drawn, strokes: 8) == eight[drawn], "\(drawn)/8") }
        for strokes in StarlitCartoucheLevel.strokeCounts {
            for drawn in 0...strokes {
                #expect(Recipe.quarters(drawn: drawn, strokes: strokes)
                        == Self.expectedQuarters(drawn: drawn, strokes: strokes), "\(drawn) of \(strokes)")
            }
        }
        #expect(Recipe.quarters(drawn: 3, strokes: 0) == 0 && Recipe.quarters(drawn: -2, strokes: 5) == 0)
        #expect(Recipe.quarters(drawn: 9, strokes: 5) == 4)
        #expect(Recipe.quarterPartials(quarters: 7) == 4 && Recipe.quarterPartials(quarters: -1) == 0)
        // Real plays: the quarters of the symbol strokes drawn over the symbol's strokes; a won play has drawn all.
        for number in Self.numbers {
            let plays: [Play] = try Self.planPlays(number)
            for play in plays {
                let drawn: Int = Self.strokesDrawn(play)
                #expect(Recipe.symbolStrokesDrawn(play) == drawn, "level \(number)")
                let expected: Int = Self.expectedQuarters(drawn: drawn, strokes: play.level.symbol.count)
                #expect(Recipe.drawnQuarters(play) == expected, "level \(number)")
            }
            if let first = plays.first { #expect(Recipe.drawnQuarters(first) == 0) }
            if let last = plays.last { #expect(Recipe.drawnQuarters(last) == 4) }
        }
    }

    @Test func theDocumentedPartials() {
        #expect(Recipe.rootHertz == 110)
        let stepRatios: [Double] = [1.0, 1.125, 1.25, 4.0 / 3.0]
        let quarterRatios: [Double] = [1.25, 1.5, 2.0, 2.5]
        #expect(Recipe.stepRatios == stepRatios)
        #expect(Recipe.quarterRatios == quarterRatios)
        // Nothing drawn at step 0: the root alone, 110 Hz over 16 s.
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
        let others: [StarlitCartoucheStage] = [.loading, .tutorial, .paused, .result]
        for stage in others { #expect(Recipe.recipe(rootStep: 2, quarters: 2, stage: stage) == playing) }
    }

    @Test func everyRecipeIsWithinTheLimitsWithWholeCycles() {
        for step in -1...5 {
            for quarters in -2...7 {
                for stage in StarlitCartoucheStage.allCases {
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

    /// The recipe key of `play`: its root step, drawn quarters and sounding stage (the stages other than won and
    /// failed sound as playing).
    static func key(_ play: Play) -> String {
        let stage: StarlitCartoucheStage = play.stage == .won || play.stage == .failed ? play.stage : .playing
        let step: Int = Self.expectedStep(left: play.actionsLeft, budget: play.level.budget)
        let quarters: Int = Self.expectedQuarters(drawn: Self.strokesDrawn(play), strokes: play.level.symbol.count)
        return "\(step)/\(quarters)/\(stage)"
    }

    /// The first leg from `play` (destinations then waits in order) the kernel accepts and that keeps the play in
    /// stage `playing` when `staying`, or that ends it otherwise; nil when there is none.
    static func nextLeg(_ play: Play, staying: Bool) -> Play? {
        for destination in 0..<play.level.stars.count {
            for wait in StarlitCartoucheChart.waits {
                var trial: Play = play
                do {
                    try trial.apply(.leg(destination, wait), expecting: trial.fingerprint)
                } catch {
                    continue
                }
                if (trial.stage == .playing) == staying { return trial }
            }
        }
        return nil
    }

    /// Real plays of the primary level: legs that keep it playing for as long as there are any (draining the
    /// budget), then a leg that ends it (a failure), the result after it, its undo, a pause, and the certified plan
    /// won and its result.
    static func scriptedPlays() throws -> [Play] {
        let number: Int = Core.levelNumber(forSeed: seed)
        var play: Play = try Core.opening(number: number).play
        var plays: [Play] = [play]
        while play.stage == .playing, play.actionsLeft > 1, let next = nextLeg(play, staying: true) {
            play = next
            plays.append(play)
        }
        if play.stage == .playing, let ending = nextLeg(play, staying: false) {
            play = ending
            plays.append(play)
        }
        #expect(play.stage == .failed)
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
        var stagesSeen: Set<StarlitCartoucheStage> = []
        var stepsSeen: Set<Int> = []
        for play in plays {
            let recipe: AmbientLoopRecipe = Recipe.recipe(play: play)
            let expected: AmbientLoopRecipe = Recipe.recipe(
                rootStep: Recipe.rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
                quarters: Recipe.drawnQuarters(play), stage: play.stage)
            #expect(recipe == expected)
            #expect(recipe.isValid)
            // Pure: an equal play gives an equal recipe.
            let copy: Play = play
            #expect(Recipe.recipe(play: copy) == recipe)
            let key: String = Self.key(play)
            for index in keys.indices {
                #expect((keys[index] == key) == (recipes[index] == recipe), "\(key) vs \(keys[index])")
            }
            keys.append(key)
            recipes.append(recipe)
            stagesSeen.insert(play.stage)
            stepsSeen.insert(Recipe.rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget))
        }
        #expect(stagesSeen.isSuperset(of: [.playing, .won, .failed, .result, .paused]))
        #expect(stepsSeen.count >= 2)
    }
}
