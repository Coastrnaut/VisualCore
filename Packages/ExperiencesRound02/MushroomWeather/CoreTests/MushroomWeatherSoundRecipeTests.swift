// MushroomWeatherSoundRecipeTests — feature 496 (R02-G20-06) T-R02G2006-004 (FR-R02G2006-006; SC-R02G2006-004;
// clarification Q4). The audition: the site step n = 2 × the site index for every index 0 … 7, clamped outside; the
// tone 220 Hz × 2^(n / 12), a whole tone per site, every site a distinct tone; over every site and placeability: a site
// that can take a pod sounds its tone and its fifth (ratio 3/2), a consonant interval; one that cannot sounds its tone
// and a partial 3 Hz above, a 3 Hz beat; each at gain 0.04; 0.6 s; pure (equal inputs give equal auditions) and
// different whenever (n, placeable) differs — the 16 distinct auditions of the 8 sites. The ambient recipe: the root
// step at its boundaries (0 for more than 3/4 of the action budget left, 1 for more than 1/2, 2 for more than 1/4,
// else 3), checked against an independent fraction comparison for every budget the kernel allows; the band quarters
// min(4, ⌊4c / n⌋) of c colonies staying in band of n, independently and over real plays (the final runs recomputed
// with `MushroomWeatherForest.report(level, arrangement:)` against the level's required cycles); pure (equal inputs
// give equal recipes); different for every change of the root step, of the band quarters, of the moonlight and of the
// stage among playing, won and failed; the documented partials (root 110 Hz × (1, 9/8, 5/4, 4/3)[step], a partial per
// quarter at the root × (5/4, 3/2, 2, 5/2)[q − 1], up to four, the root alone below a quarter, the moonlight partial at
// the root × 3 with the base amplitude × l / 3, the octave when won — merged into the root × 2 partial when that
// sounds —, halved amplitudes and gain when failed); the loop length the longest in 4 … 16 s at which every partial has
// a whole number of cycles; a valid `AmbientLoopRecipe` within its limits for every input; and `recipe(play:)` over
// real plays of the certified levels around the feature seed 2_496 (levels 96, 97 and 98: the certified plans, a
// placement and its removal draining the budget, a failed run, its result, its undo, a pause, a won plan and its
// result) equal to the recipe of the play's root step, band quarters, moonlight and stage, equal for equal keys and
// different whenever the keys differ. Explicit types, plain loops, short runs, no clocks. Modelled on
// MicroscopicAuroraSoundRecipeTests (feature 486).
import Foundation
import Testing
import VisualCoreAudioDSP
@testable import MushroomWeatherCore

@Suite struct MushroomWeatherSoundRecipeTests {
    typealias Recipe = MushroomWeatherSoundRecipe
    typealias Audition = MushroomWeatherAudition
    typealias Partial = MushroomWeatherPartial
    typealias Play = MushroomWeatherPlay
    typealias Core = MushroomWeatherExperienceCore
    /// The feature's fixture seed.
    static let seed: UInt64 = 2_496
    /// The primary level the seed opens (97) and its neighbours.
    static let numbers: [Int] = [Core.levelNumber(forSeed: seed) - 1, Core.levelNumber(forSeed: seed),
                                 Core.levelNumber(forSeed: seed) + 1]
    /// The stages whose sound differs.
    static let stages: [MushroomWeatherStage] = [.playing, .won, .failed]
    /// The highest frequency any recipe sounds: the moonlight partial at step 3, 110 × 4/3 × 3 Hz (plus rounding).
    static let highestHertz: Double = 110.0 * 4.0 / 3.0 * 3.0 + 1e-9

    /// Whether `value` is a whole number (within a rounding tolerance far below one cycle).
    static func isWhole(_ value: Double) -> Bool { abs(value - value.rounded()) < 1e-6 }

    /// The tone of site step `step` by the documented formula.
    static func hertz(step: Int) -> Double { 220 * pow(2, Double(step) / 12) }

    @Test func theSiteStepsAndTheirTones() {
        #expect(Audition.duration == 0.6 && Audition.toneGain == 0.04)
        #expect(Audition.step(site: 0) == 0 && Audition.step(site: 7) == 14)
        #expect(Audition.tone(site: 0) == 220)
        #expect(abs(Audition.tone(site: 7) - 493.883_301_256_124_1) < 1e-9)
        var tones: [Double] = []
        for site in 0..<MushroomWeatherLevel.siteCounts.upperBound {
            let step: Int = Audition.step(site: site)
            #expect(step == 2 * site, "site \(site)")
            let tone: Double = Audition.tone(site: site)
            #expect(abs(tone - Self.hertz(step: step)) < 1e-9, "site \(site)")
            // A whole tone (two semitones) above the previous site; every tone distinct, a later site higher.
            if let previous = tones.last {
                #expect(abs(tone / previous - pow(2, 2.0 / 12)) < 1e-12, "site \(site)")
                #expect(tone > previous)
            }
            for earlier in tones { #expect(tone != earlier, "site \(site)") }
            tones.append(tone)
        }
        #expect(tones.count == 8)
        // Outside 0 … 7 the index is clamped.
        #expect(Audition.step(site: -1) == 0 && Audition.step(site: -9) == 0)
        #expect(Audition.step(site: 8) == 14 && Audition.step(site: 40) == 14)
        #expect(Audition.tone(site: 12) == Audition.tone(site: 7))
    }

    @Test func aSiteThatCanTakeAPodIsAConsonantFifthAndOneThatCannotBeats() throws {
        var fifths: Int = 0
        var beats: Int = 0
        var keys: [String] = []
        var auditions: [Audition] = []
        for site in 0..<8 {
            for placeable in [true, false] {
                let label: String = "site \(site) placeable \(placeable)"
                let audition: Audition = Audition.of(site: site, placeable: placeable)
                let tone: Double = Self.hertz(step: 2 * site)
                #expect(audition.partials.count == 2, "\(label)")
                guard audition.partials.count == 2 else { continue }
                let first: Partial = audition.partials[0]
                let second: Partial = audition.partials[1]
                #expect(abs(first.frequency - tone) < 1e-9 && first.gain == 0.04 && second.gain == 0.04, "\(label)")
                if placeable {
                    // A consonant interval: the fifth, ratio exactly 3/2.
                    #expect(abs(second.frequency / first.frequency - 1.5) < 1e-12, "\(label)")
                    fifths += 1
                } else {
                    // A 3 Hz beat: the partials differ by exactly 3 Hz; never silence.
                    #expect(abs(second.frequency - first.frequency - 3) < 1e-9, "\(label)")
                    beats += 1
                }
                // Pure: equal inputs give an equal audition; different (n, placeable) keys different auditions.
                #expect(Audition.of(site: site, placeable: placeable) == audition, "\(label)")
                for earlier in auditions { #expect(earlier != audition, "\(label)") }
                keys.append("\(2 * site)/\(placeable)")
                auditions.append(audition)
            }
        }
        #expect(fifths == 8 && beats == 8 && keys.count == 16)
        // The sites of the certified levels around the seed: each a distinct tone of its index.
        for number in Self.numbers {
            let level: MushroomWeatherLevel = try Core.level(number: number)
            let sites: [MushroomWeatherCell] = level.sites ?? []
            for index in sites.indices {
                #expect(abs(Audition.tone(site: index) - Self.hertz(step: 2 * index)) < 1e-9, "level \(number)")
            }
        }
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
        let eight: [Int] = [3, 3, 3, 2, 2, 1, 1, 0, 0]
        for left in 0...8 { #expect(Recipe.rootStep(actionsLeft: left, budget: 8) == eight[left], "\(left) of 8") }
        // Budget 4: exactly 3/4, 1/2 and 1/4 left fall to the next step.
        let four: [Int] = [3, 3, 2, 1, 0]
        for left in 0...4 { #expect(Recipe.rootStep(actionsLeft: left, budget: 4) == four[left], "\(left) of 4") }
        #expect(Recipe.rootStep(actionsLeft: 1, budget: 1) == 0 && Recipe.rootStep(actionsLeft: 0, budget: 1) == 3)
        #expect(Recipe.rootStep(actionsLeft: 1, budget: 0) == 0 && Recipe.rootStep(actionsLeft: 0, budget: -3) == 3)
        for budget in MushroomWeatherLevel.budgets {
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

    /// The band quarters by an independent rule: the largest q in 0 … 4 with q / 4 ≤ inBand / colonies.
    static func expectedQuarters(inBand: Int, colonies: Int) -> Int {
        guard colonies > 0 else { return 0 }
        var best: Int = 0
        for q in 0...4 where q * colonies <= 4 * inBand { best = q }
        return best
    }

    /// The colonies of `play` staying in band, recomputed independently from its level and arrangement.
    static func recomputedInBand(_ play: Play) -> Int {
        let report: MushroomWeatherReport = MushroomWeatherForest.report(play.level, arrangement: play.arrangement)
        var count: Int = 0
        for runs in report.colonies where runs.finalRun >= play.level.required { count += 1 }
        return count
    }

    /// The band quarters of `play` by the independent rule over its recomputed report.
    static func expectedQuarters(_ play: Play) -> Int {
        expectedQuarters(inBand: recomputedInBand(play), colonies: play.level.colonies.count)
    }

    /// The plays of certified level `number`: the opening, the play after each action of its certified plan and the
    /// play after the winning run.
    static func planPlays(_ number: Int) throws -> [Play] {
        var play: Play = try Core.opening(number: number).play
        var plays: [Play] = [play]
        for action in try Core.generated(number: number).plan.actions {
            try play.apply(action, expecting: play.fingerprint)
            plays.append(play)
        }
        try play.apply(.run, expecting: play.fingerprint)
        plays.append(play)
        #expect(play.stage == .won)
        return plays
    }

    @Test func theQuartersFromTheColoniesStayingInBand() throws {
        for inBand in 0...4 { #expect(Recipe.quarters(inBand: inBand, colonies: 4) == inBand, "\(inBand)/4") }
        // 6 colonies: 0 … 1 none, 2 one, 3 two, 4 … 5 three, 6 four.
        let six: [Int] = [0, 0, 1, 2, 2, 3, 4]
        for inBand in 0...6 { #expect(Recipe.quarters(inBand: inBand, colonies: 6) == six[inBand], "\(inBand)/6") }
        for colonies in MushroomWeatherLevel.colonyCounts {
            for inBand in 0...(colonies + 2) {
                #expect(Recipe.quarters(inBand: inBand, colonies: colonies)
                        == Self.expectedQuarters(inBand: inBand, colonies: colonies), "\(inBand) of \(colonies)")
            }
        }
        #expect(Recipe.quarters(inBand: 3, colonies: 0) == 0 && Recipe.quarters(inBand: -2, colonies: 5) == 0)
        #expect(Recipe.quarters(inBand: 9, colonies: 5) == 4)
        #expect(Recipe.quarterPartials(quarters: 7) == 4 && Recipe.quarterPartials(quarters: -1) == 0)
        // Real plays: the quarters of the colonies staying in band; a won play has every colony in band.
        var seen: Set<Int> = []
        for number in Self.numbers {
            for play in try Self.planPlays(number) {
                let quarters: Int = Recipe.bandQuarters(play)
                #expect(quarters == Self.expectedQuarters(play), "level \(number)")
                #expect(Recipe.coloniesInBand(play) == Self.recomputedInBand(play), "level \(number)")
                if play.stage == .won { #expect(quarters == 4, "level \(number)") }
                seen.insert(quarters)
            }
        }
        #expect(seen.contains(4))
    }

    @Test func theDocumentedPartials() {
        #expect(Recipe.rootHertz == 110)
        #expect(Recipe.stepRatios == [1.0, 1.125, 1.25, 4.0 / 3.0])
        #expect(Recipe.quarterRatios == [1.25, 1.5, 2.0, 2.5])
        #expect(Recipe.moonlightRatio == 3)
        // Nothing in band at step 0, no moonlight: the root alone, 110 Hz over 16 s.
        let alone: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 0, moonlight: 0, stage: .playing)
        #expect(alone.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.6)])
        #expect(alone.gain == 0.2 && alone.swellCycles == 1 && alone.seconds == 16)
        // Three quarters at step 0: root, 5/4, 3/2 and 2.
        let three: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 3, moonlight: 0, stage: .playing)
        #expect(three.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520])
        // Step 1 (9/8): 123.75 Hz, whole over 16 s; moonlight 2 adds the root × 3 at 0.6 × 2/3.
        let second: AmbientLoopRecipe = Recipe.recipe(rootStep: 1, quarters: 2, moonlight: 2, stage: .playing)
        #expect(second.seconds == 16 && second.partials.map(\.cyclesPerLoop) == [1_980, 2_475, 2_970, 5_940])
        #expect(abs(second.partials[3].amplitude - 0.4) < 1e-12)
        // Step 3 (4/3): 146.67 Hz, whole only in multiples of 3 s, so 15 s.
        let high: AmbientLoopRecipe = Recipe.recipe(rootStep: 3, quarters: 4, moonlight: 3, stage: .playing)
        #expect(high.seconds == 15
                && high.partials.map(\.cyclesPerLoop) == [2_200, 2_750, 3_300, 4_400, 5_500, 6_600])
        // Won with four quarters and moonlight 1: the octave merges into the root × 2 partial (amplitude 1), swelling
        // twice; six partials, within the limit.
        let won: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 4, moonlight: 1, stage: .won)
        #expect(won.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520, 4_400, 5_280])
        #expect(won.partials[3].amplitude == 1 && abs(won.partials[5].amplitude - 0.2) < 1e-12)
        #expect(won.partials.count == 6 && won.swellCycles == 2 && won.gain == 0.2)
        // Won below three quarters: the octave is its own partial at the base amplitude.
        let wonLow: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 1, moonlight: 0, stage: .won)
        #expect(wonLow.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.6),
                                    AmbientLoopPartial(cyclesPerLoop: 2_200, amplitude: 0.6),
                                    AmbientLoopPartial(cyclesPerLoop: 3_520, amplitude: 0.6)])
        // Failed: amplitudes and gain halved.
        let failed: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 1, moonlight: 3, stage: .failed)
        #expect(failed.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.3),
                                    AmbientLoopPartial(cyclesPerLoop: 2_200, amplitude: 0.3),
                                    AmbientLoopPartial(cyclesPerLoop: 5_280, amplitude: 0.3)])
        #expect(failed.gain == 0.1 && failed.swellCycles == 1)
        // Clamping: at most four quarter partials; the step to 0 … 3; the moonlight to 0 … 3.
        let four: AmbientLoopRecipe = Recipe.recipe(rootStep: 1, quarters: 4, moonlight: 0, stage: .playing)
        #expect(Recipe.recipe(rootStep: 1, quarters: 6, moonlight: 0, stage: .playing) == four)
        #expect(Recipe.recipe(rootStep: 1, quarters: 4, moonlight: -2, stage: .playing) == four)
        #expect(Recipe.recipe(rootStep: 1, quarters: 4, moonlight: 9, stage: .playing)
                == Recipe.recipe(rootStep: 1, quarters: 4, moonlight: 3, stage: .playing))
        #expect(Recipe.recipe(rootStep: -1, quarters: 1, moonlight: 0, stage: .playing)
                == Recipe.recipe(rootStep: 0, quarters: 1, moonlight: 0, stage: .playing))
        #expect(Recipe.recipe(rootStep: 7, quarters: 1, moonlight: 0, stage: .playing)
                == Recipe.recipe(rootStep: 3, quarters: 1, moonlight: 0, stage: .playing))
        #expect(Recipe.recipe(rootStep: 0, quarters: -2, moonlight: 0, stage: .playing) == alone)
    }

    @Test func pureAndDistinct() {
        var seen: [AmbientLoopRecipe] = []
        for step in 0...3 {
            for quarters in 0...4 {
                for moonlight in 0...3 {
                    for stage in Self.stages {
                        let recipe: AmbientLoopRecipe = Recipe.recipe(rootStep: step, quarters: quarters,
                                                                      moonlight: moonlight, stage: stage)
                        // Equal inputs give equal recipes.
                        #expect(recipe == Recipe.recipe(rootStep: step, quarters: quarters, moonlight: moonlight,
                                                        stage: stage))
                        for earlier in seen {
                            #expect(recipe != earlier, "step \(step) quarters \(quarters) moon \(moonlight) \(stage)")
                        }
                        seen.append(recipe)
                    }
                }
            }
        }
        #expect(seen.count == 240)
        // The other stages sound as playing.
        let playing: AmbientLoopRecipe = Recipe.recipe(rootStep: 2, quarters: 2, moonlight: 1, stage: .playing)
        let others: [MushroomWeatherStage] = [.loading, .tutorial, .paused, .result]
        for stage in others {
            #expect(Recipe.recipe(rootStep: 2, quarters: 2, moonlight: 1, stage: stage) == playing)
        }
    }

    @Test func everyRecipeIsWithinTheLimitsWithWholeCycles() {
        for step in -1...5 {
            for quarters in -2...7 {
                for moonlight in -1...4 {
                    for stage in MushroomWeatherStage.allCases {
                        let recipe: AmbientLoopRecipe = Recipe.recipe(rootStep: step, quarters: quarters,
                                                                      moonlight: moonlight, stage: stage)
                        let label: String = "step \(step) quarters \(quarters) moon \(moonlight) \(stage)"
                        #expect(recipe.isValid, "\(label)")
                        #expect(AmbientLoopRecipe.partialCountRange.contains(recipe.partials.count), "\(label)")
                        #expect(AmbientLoopRecipe.secondsRange.contains(recipe.seconds), "\(label)")
                        #expect(recipe.gain <= Recipe.baseGain && recipe.gain > 0)
                        #expect(recipe.seconds == Recipe.loopSeconds(rootStep: step, quarters: quarters,
                                                                     moonlight: moonlight, stage: stage))
                        // The partials sound the documented frequencies, each a whole number of cycles in the loop.
                        let frequencies: [Double] = Recipe.frequencies(rootStep: step, quarters: quarters,
                                                                       moonlight: moonlight, stage: stage)
                        #expect(frequencies.count == recipe.partials.count, "\(label)")
                        for index in recipe.partials.indices where index < frequencies.count {
                            let partial: AmbientLoopPartial = recipe.partials[index]
                            let product: Double = frequencies[index] * Double(recipe.seconds)
                            #expect(Self.isWhole(product), "\(label) partial \(index): \(product) cycles")
                            #expect(Int(product.rounded()) == partial.cyclesPerLoop, "\(label) partial \(index)")
                            #expect(partial.amplitude <= 1 && partial.amplitude > 0, "\(label) partial \(index)")
                            #expect(frequencies[index] >= 110 && frequencies[index] <= Self.highestHertz)
                        }
                        // Every frequency sounds once (equal partials merged).
                        for index in frequencies.indices {
                            for other in frequencies.indices where other > index {
                                #expect(frequencies[index] != frequencies[other], "\(label)")
                            }
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
        }
        // The expected lengths: 16 s for steps 0 … 2, 15 s for step 3.
        for step in 0...3 {
            for stage in Self.stages {
                for moonlight in 0...3 {
                    let expected: Int = step == 3 ? 15 : 16
                    #expect(Recipe.loopSeconds(rootStep: step, quarters: 4, moonlight: moonlight, stage: stage)
                            == expected)
                    #expect(Recipe.loopSeconds(rootStep: step, quarters: 0, moonlight: moonlight, stage: stage)
                            == expected)
                }
            }
        }
    }

    @Test func theRootAloneMoonlightOctaveWhenWonAndHalvedWhenFailed() {
        for step in 0...3 {
            let root: Double = 110 * Recipe.stepRatios[step]
            let alone: [Double] = Recipe.frequencies(rootStep: step, quarters: 0, moonlight: 0, stage: .playing)
            #expect(alone.count == 1 && abs((alone.first ?? 0) - root) < 1e-9)
            for quarters in 0...4 {
                for moonlight in 0...3 {
                    let playing: AmbientLoopRecipe = Recipe.recipe(rootStep: step, quarters: quarters,
                                                                   moonlight: moonlight, stage: .playing)
                    let lit: Int = moonlight > 0 ? 1 : 0
                    #expect(playing.partials.count == 1 + quarters + lit)
                    if moonlight > 0 {
                        let last: AmbientLoopPartial? = playing.partials.last
                        #expect(last?.cyclesPerLoop == playing.partials[0].cyclesPerLoop * 3)
                        #expect(abs((last?.amplitude ?? 0) - 0.6 * Double(moonlight) / 3) < 1e-12)
                    }
                    let won: AmbientLoopRecipe = Recipe.recipe(rootStep: step, quarters: quarters,
                                                               moonlight: moonlight, stage: .won)
                    #expect(won.swellCycles == 2 && playing.swellCycles == 1)
                    if quarters >= 3 {
                        // The octave coincides with the third quarter's partial: merged, its amplitude summed.
                        #expect(won.partials.count == playing.partials.count)
                        #expect(won.partials.map(\.cyclesPerLoop) == playing.partials.map(\.cyclesPerLoop))
                        #expect(won.partials[3].amplitude == 1)
                    } else {
                        #expect(won.partials.count == playing.partials.count + 1)
                        #expect(Array(won.partials.prefix(playing.partials.count)) == playing.partials)
                        #expect(won.partials.last == AmbientLoopPartial(
                            cyclesPerLoop: playing.partials[0].cyclesPerLoop * 2, amplitude: 0.6))
                    }
                    let failed: AmbientLoopRecipe = Recipe.recipe(rootStep: step, quarters: quarters,
                                                                  moonlight: moonlight, stage: .failed)
                    #expect(failed.seconds == playing.seconds && failed.gain == playing.gain / 2)
                    #expect(failed.partials.map(\.cyclesPerLoop) == playing.partials.map(\.cyclesPerLoop))
                    for index in failed.partials.indices {
                        #expect(failed.partials[index].amplitude == playing.partials[index].amplitude / 2)
                    }
                }
            }
        }
    }

    /// The recipe key of `play`: its root step, band quarters, moonlight and sounding stage (the stages other than won
    /// and failed sound as playing), each decided by the independent rules.
    static func key(_ play: Play) -> String {
        let stage: MushroomWeatherStage = play.stage == .won || play.stage == .failed ? play.stage : .playing
        let step: Int = Self.expectedStep(left: play.actionsLeft, budget: play.level.budget)
        return "\(step)/\(Self.expectedQuarters(play))/\(play.arrangement.moonlight)/\(stage)"
    }

    /// Real plays of the primary level: a pod placement on a free site and its removal back and forth, draining the
    /// budget to fewer than two actions; then the run (a failure: the starting arrangement never wins), the result
    /// after it, its undo, a pause, and the certified plan won and its result.
    static func scriptedPlays() throws -> [Play] {
        let number: Int = Core.levelNumber(forSeed: seed)
        var play: Play = try Core.opening(number: number).play
        var plays: [Play] = [play]
        let held: [MushroomWeatherCell] = play.arrangement.placedPods
        var free: MushroomWeatherCell? = nil
        for site in play.level.sites ?? [] where free == nil && !held.contains(site) { free = site }
        var slot: Int? = nil
        for index in play.arrangement.pods.indices where slot == nil && play.arrangement.pods[index] == nil {
            slot = index
        }
        guard let free, let slot else {
            Issue.record("level \(number) has no free site and empty slot")
            return plays
        }
        while play.stage == .playing, play.actionsLeft >= 2 {
            try play.apply(.place(slot: slot, cell: free), expecting: play.fingerprint)
            plays.append(play)
            try play.apply(.remove(slot: slot), expecting: play.fingerprint)
            plays.append(play)
        }
        try play.apply(.run, expecting: play.fingerprint)
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
        var stagesSeen: Set<MushroomWeatherStage> = []
        var stepsSeen: Set<Int> = []
        for play in plays {
            let recipe: AmbientLoopRecipe = Recipe.recipe(play: play)
            let expected: AmbientLoopRecipe = Recipe.recipe(
                rootStep: Recipe.rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
                quarters: Recipe.bandQuarters(play), moonlight: play.arrangement.moonlight, stage: play.stage)
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
