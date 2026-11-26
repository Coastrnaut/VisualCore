// MicroscopicAuroraSoundRecipeTests — feature 486 (R02-G19-06) T-R02G1906-004 (FR-R02G1906-006; SC-R02G1906-004;
// clarifications Q4). The audition: the strength step n = 3 × (s − 1) for every strength 1 … 4, clamped outside; the
// tone 220 Hz × 2^(n / 12), a minor third per strength, every strength a distinct tone; over every strength, sense and
// placeability: a well that can be placed sounds its tone and its fifth (ratio 3/2) clockwise or its fourth (ratio 4/3)
// counterclockwise, a consonant interval; one that cannot be placed sounds its tone and a partial 3 Hz above, a 3 Hz
// beat; each at gain 0.04; 0.6 s; pure (equal inputs give equal auditions, the cell never matters) and different
// whenever (n, sense, placeable) differs among placeable wells — the 12 distinct auditions of the 4 strengths, each
// with a fifth, a fourth and a beat; the certified winning wells of levels 86, 87 and 88 sound consonant intervals.
// The ambient recipe: the root step at its boundaries (0 for more than 3/4 of the action budget left, 1 for more than
// 1/2, 2 for more than 1/4, else 3), checked against an independent fraction comparison for every budget the kernel
// allows; the lit quarters min(4, ⌊4l / N⌋) of l lit stencil cells of N needed, independently and over real plays (the
// lit count and the needed cells recomputed with `MicroscopicAuroraDish.report` and the ceiling of required × size /
// 1000); pure (equal inputs give equal recipes); different for every change of the root step, of the lit quarters and
// of the stage among playing, won and failed; the documented partials (root 110 Hz × (1, 9/8, 5/4, 4/3)[step], a
// partial per quarter at the root × (5/4, 3/2, 2, 5/2)[q − 1], up to four, the root alone below a quarter, the octave
// when won, halved amplitudes and gain when failed); the loop length the longest in 4 … 16 s at which every partial has
// a whole number of cycles; a valid `AmbientLoopRecipe` within its limits for every input; and `recipe(play:)` over
// real plays of the certified levels around the feature seed 2_486 (levels 86, 87 and 88: placements draining the
// budget, a failed play, its result, its undo, a pause, a won plan and its result) equal to the recipe of the play's
// root step, lit quarters and stage, equal for equal keys and different whenever the keys differ. Explicit types, plain
// loops, short runs, no clocks. Modelled on ApsidesWorkshopSoundRecipeTests (feature 476).
import Foundation
import Testing
import VisualCoreAudioDSP
@testable import MicroscopicAuroraCore

@Suite struct MicroscopicAuroraSoundRecipeTests {
    typealias Recipe = MicroscopicAuroraSoundRecipe
    typealias Audition = MicroscopicAuroraAudition
    typealias Partial = MicroscopicAuroraPartial
    typealias Well = MicroscopicAuroraWell
    typealias Play = MicroscopicAuroraPlay
    typealias Core = MicroscopicAuroraExperienceCore
    /// The feature's fixture seed.
    static let seed: UInt64 = 2_486
    /// The primary level the seed opens (87) and its neighbours.
    static let numbers: [Int] = [Core.levelNumber(forSeed: seed) - 1, Core.levelNumber(forSeed: seed),
                                 Core.levelNumber(forSeed: seed) + 1]
    /// The stages whose sound differs.
    static let stages: [MicroscopicAuroraStage] = [.playing, .won, .failed]
    /// The senses.
    static let senses: [MicroscopicAuroraSense] = [.clockwise, .counterclockwise]
    /// The highest frequency any recipe sounds: the fourth quarter partial at step 3, 110 × 4/3 × 5/2 Hz (plus
    /// rounding).
    static let highestHertz: Double = 110.0 * 4.0 / 3.0 * 5.0 / 2.0 + 1e-9

    /// Whether `value` is a whole number (within a rounding tolerance far below one cycle).
    static func isWhole(_ value: Double) -> Bool { abs(value - value.rounded()) < 1e-6 }

    /// The strength step of `strength` by the documented formula for strengths 1 … 4.
    static func expectedStep(_ strength: Int) -> Int { 3 * (strength - 1) }

    /// The tone of strength step `step` by the documented formula.
    static func hertz(step: Int) -> Double { 220 * pow(2, Double(step) / 12) }

    /// A well of `strength` and `sense` on the cell (`row`, `column`).
    static func well(_ strength: Int, _ sense: MicroscopicAuroraSense, row: Int = 12, column: Int = 12) -> Well {
        Well(cell: MicroscopicAuroraCell(row: row, column: column), strength: strength, sense: sense)
    }

    @Test func theStrengthStepsAndTheirTones() {
        #expect(Audition.duration == 0.6 && Audition.toneGain == 0.04)
        #expect(Audition.step(strength: 1) == 0 && Audition.step(strength: 4) == 9)
        #expect(Audition.tone(strength: 1) == 220)
        #expect(abs(Audition.tone(strength: 4) - 369.994_422_711_634_4) < 1e-9)
        var tones: [Double] = []
        for strength in Well.strengths {
            let step: Int = Audition.step(strength: strength)
            #expect(step == Self.expectedStep(strength), "strength \(strength)")
            let tone: Double = Audition.tone(strength: strength)
            #expect(abs(tone - Self.hertz(step: step)) < 1e-9, "strength \(strength)")
            // A minor third (three semitones) above the previous strength; every tone distinct, a stronger well higher.
            if let previous = tones.last {
                #expect(abs(tone / previous - pow(2, 3.0 / 12)) < 1e-12, "strength \(strength)")
                #expect(tone > previous)
            }
            for earlier in tones { #expect(tone != earlier, "strength \(strength)") }
            tones.append(tone)
        }
        #expect(tones.count == 4)
        // Outside 1 … 4 the strength is clamped.
        #expect(Audition.step(strength: 0) == 0 && Audition.step(strength: -3) == 0)
        #expect(Audition.step(strength: 5) == 9 && Audition.step(strength: 40) == 9)
        #expect(Audition.tone(strength: 9) == Audition.tone(strength: 4))
    }

    @Test func aPlaceableWellIsAConsonantIntervalAndOneThatCannotBePlacedBeats() throws {
        var fifths: Int = 0
        var fourths: Int = 0
        var beats: Int = 0
        for strength in Well.strengths {
            for sense in Self.senses {
                for placeable in [true, false] {
                    let label: String = "s \(strength) \(sense) placeable \(placeable)"
                    let audition: Audition = Audition.of(Self.well(strength, sense), placeable: placeable)
                    let tone: Double = Self.hertz(step: Self.expectedStep(strength))
                    #expect(audition.partials.count == 2, "\(label)")
                    guard audition.partials.count == 2 else { continue }
                    let first: Partial = audition.partials[0]
                    let second: Partial = audition.partials[1]
                    #expect(abs(first.frequency - tone) < 1e-9 && first.gain == 0.04 && second.gain == 0.04,
                            "\(label)")
                    if placeable && sense == .clockwise {
                        // A consonant interval: the fifth, ratio exactly 3/2.
                        #expect(abs(second.frequency / first.frequency - 1.5) < 1e-12, "\(label)")
                        fifths += 1
                    } else if placeable {
                        // A consonant interval: the fourth, ratio exactly 4/3.
                        #expect(abs(second.frequency / first.frequency - 4.0 / 3.0) < 1e-12, "\(label)")
                        fourths += 1
                    } else {
                        // A 3 Hz beat: the partials differ by exactly 3 Hz; never silence.
                        #expect(abs(second.frequency - first.frequency - 3) < 1e-9, "\(label)")
                        beats += 1
                    }
                    // Pure: an equal well gives an equal audition, and the cell does not change it.
                    #expect(Audition.of(Self.well(strength, sense), placeable: placeable) == audition, "\(label)")
                    #expect(Audition.of(Self.well(strength, sense, row: 3, column: 17), placeable: placeable)
                            == audition, "\(label)")
                }
            }
        }
        #expect(fifths == 4 && fourths == 4 && beats == 8, "\(fifths) fifths, \(fourths) fourths, \(beats) beats")
        // The certified winning wells, which a player places, sound consonant intervals.
        for number in Self.numbers {
            let wells: [Well] = try Core.generated(number: number).plan.wells
            #expect(!wells.isEmpty, "level \(number)")
            for well in wells {
                let audition: Audition = Audition.of(well, placeable: true)
                let ratio: Double = (audition.partials.last?.frequency ?? 0)
                    / (audition.partials.first?.frequency ?? 1)
                let expected: Double = well.sense == .clockwise ? 1.5 : 4.0 / 3.0
                #expect(abs(ratio - expected) < 1e-12, "level \(number)")
            }
        }
    }

    @Test func auditionsDifferWheneverTheStepTheSenseOrPlaceabilityDiffers() {
        // Every (n, sense, placeable) key gives one audition (a well that cannot be placed beats whatever its sense),
        // and different keys different auditions.
        var keys: [String] = []
        var auditions: [Audition] = []
        for strength in Well.strengths {
            for sense in Self.senses {
                for placeable in [true, false] {
                    let step: Int = Self.expectedStep(strength)
                    let key: String = placeable ? "\(step)/\(sense)" : "\(step)/beat"
                    let audition: Audition = Audition.of(Self.well(strength, sense), placeable: placeable)
                    if let index = keys.firstIndex(of: key) {
                        #expect(auditions[index] == audition, "\(key)")
                    } else {
                        for earlier in auditions { #expect(earlier != audition, "\(key)") }
                        keys.append(key)
                        auditions.append(audition)
                    }
                }
            }
        }
        // 4 strengths, each with a fifth, a fourth and a beat.
        #expect(keys.count == 12)
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
        // Every budget the kernel allows (practice's included), every count left: the independent rule, never falling
        // as actions drain.
        var budgets: [Int] = Array(MicroscopicAuroraLevel.budgets)
        budgets.append(Core.practiceBudget)
        for budget in budgets {
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

    /// The lit quarters by an independent rule: the largest q in 0 … 4 with q / 4 ≤ lit / needed.
    static func expectedQuarters(lit: Int, needed: Int) -> Int {
        guard needed > 0 else { return 0 }
        var best: Int = 0
        for q in 0...4 where q * needed <= 4 * lit { best = q }
        return best
    }

    /// The stencil cells the coverage of `play`'s level needs, recomputed independently: the smallest whole N with
    /// 1000 × N ≥ required × size.
    static func recomputedNeeded(_ play: Play) -> Int {
        let size: Int = play.level.stencil.count
        var needed: Int = 0
        while 1000 * needed < play.level.coverage * size { needed += 1 }
        return needed
    }

    /// The stencil cells `play`'s wells light, recomputed independently from its level and wells.
    static func recomputedLit(_ play: Play) -> Int {
        MicroscopicAuroraDish.report(play.level, wells: play.placedWells).litStencil.count
    }

    /// The lit quarters of `play` by the independent rule over its recomputed report.
    static func expectedQuarters(_ play: Play) -> Int {
        expectedQuarters(lit: recomputedLit(play), needed: recomputedNeeded(play))
    }

    /// The plays of certified level `number`: the opening, the play after each placement of its certified plan and
    /// the play after the winning play.
    static func planPlays(_ number: Int) throws -> [Play] {
        var play: Play = try Core.opening(number: number).play
        var plays: [Play] = [play]
        for action in try Core.generated(number: number).plan.actions {
            try play.apply(action, expecting: play.fingerprint)
            plays.append(play)
        }
        try play.apply(.play, expecting: play.fingerprint)
        plays.append(play)
        #expect(play.stage == .won)
        return plays
    }

    @Test func theQuartersFromTheLitStencilCells() throws {
        // 4 needed: each lit cell is one quarter. 6 needed: 0 … 1 none, 2 one, 3 two, 4 … 5 three, 6 four.
        for lit in 0...4 { #expect(Recipe.quarters(lit: lit, needed: 4) == lit, "\(lit)/4") }
        let six: [Int] = [0, 0, 1, 2, 2, 3, 4]
        for lit in 0...6 { #expect(Recipe.quarters(lit: lit, needed: 6) == six[lit], "\(lit)/6") }
        for needed in 1...MicroscopicAuroraLevel.stencilSizes.upperBound {
            for lit in 0...(needed + 2) {
                #expect(Recipe.quarters(lit: lit, needed: needed)
                        == Self.expectedQuarters(lit: lit, needed: needed), "\(lit) of \(needed)")
            }
        }
        #expect(Recipe.quarters(lit: 3, needed: 0) == 0 && Recipe.quarters(lit: -2, needed: 5) == 0)
        #expect(Recipe.quarters(lit: 9, needed: 5) == 4)
        #expect(Recipe.quarterPartials(quarters: 7) == 4 && Recipe.quarterPartials(quarters: -1) == 0)
        // Real plays: the quarters of the lit stencil cells over the needed cells; a won play has lit them all.
        var seen: Set<Int> = []
        for number in Self.numbers {
            for play in try Self.planPlays(number) {
                let quarters: Int = Recipe.litQuarters(play)
                #expect(quarters == Self.expectedQuarters(play), "level \(number)")
                #expect(Recipe.neededCells(play) == Self.recomputedNeeded(play), "level \(number)")
                #expect(play.report.litStencil.count == Self.recomputedLit(play))
                if play.stage == .won { #expect(quarters == 4, "level \(number)") }
                seen.insert(quarters)
            }
        }
        #expect(seen.count >= 2 && seen.contains(4))
    }

    @Test func theDocumentedPartials() {
        #expect(Recipe.rootHertz == 110)
        let stepRatios: [Double] = [1.0, 1.125, 1.25, 4.0 / 3.0]
        let quarterRatios: [Double] = [1.25, 1.5, 2.0, 2.5]
        #expect(Recipe.stepRatios == stepRatios)
        #expect(Recipe.quarterRatios == quarterRatios)
        // Nothing lit at step 0: the root alone, 110 Hz over 16 s.
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
        let others: [MicroscopicAuroraStage] = [.loading, .tutorial, .paused, .result]
        for stage in others { #expect(Recipe.recipe(rootStep: 2, quarters: 2, stage: stage) == playing) }
    }

    @Test func everyRecipeIsWithinTheLimitsWithWholeCycles() {
        for step in -1...5 {
            for quarters in -2...7 {
                for stage in MicroscopicAuroraStage.allCases {
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

    /// The recipe key of `play`: its root step, lit quarters and sounding stage (the stages other than won and failed
    /// sound as playing), each decided by the independent rules.
    static func key(_ play: Play) -> String {
        let stage: MicroscopicAuroraStage = play.stage == .won || play.stage == .failed ? play.stage : .playing
        let step: Int = Self.expectedStep(left: play.actionsLeft, budget: play.level.budget)
        return "\(step)/\(Self.expectedQuarters(play))/\(stage)"
    }

    /// Real plays of the primary level: the first certified placement and its removal back and forth (so every second
    /// play has the starting wells' slot emptied again), draining the budget to fewer than two actions; then the play
    /// (a failure: the plan needs more than one well, or the slot is empty again), the result after it, its undo, a
    /// pause, and the certified plan won and its result.
    static func scriptedPlays() throws -> [Play] {
        let number: Int = Core.levelNumber(forSeed: seed)
        var play: Play = try Core.opening(number: number).play
        var plays: [Play] = [play]
        let plan: [MicroscopicAuroraAction] = try Core.generated(number: number).plan.actions
        guard case let .place(slot, well) = plan.first else {
            Issue.record("level \(number) has no certified placement")
            return plays
        }
        let start: MicroscopicAuroraWell? = play.wells[slot]
        while play.stage == .playing, play.actionsLeft >= 2 {
            try play.apply(.place(slot: slot, well: well), expecting: play.fingerprint)
            plays.append(play)
            if let start {
                try play.apply(.place(slot: slot, well: start), expecting: play.fingerprint)
            } else {
                try play.apply(.remove(slot: slot), expecting: play.fingerprint)
            }
            plays.append(play)
        }
        try play.apply(.play, expecting: play.fingerprint)
        plays.append(play)
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
        var stagesSeen: Set<MicroscopicAuroraStage> = []
        var stepsSeen: Set<Int> = []
        for play in plays {
            let recipe: AmbientLoopRecipe = Recipe.recipe(play: play)
            let expected: AmbientLoopRecipe = Recipe.recipe(
                rootStep: Recipe.rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
                quarters: Recipe.litQuarters(play), stage: play.stage)
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
