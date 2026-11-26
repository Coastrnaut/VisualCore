// ApsidesWorkshopSoundRecipeTests — feature 476 (R02-G18-06) T-R02G1806-004 (FR-R02G1806-004, 006; clarifications Q3,
// Q4). The audition: the size step n = ⌊(48 − a) / 4⌋ for every size 8 … 48, clamped to 0 … 10 outside; the tone
// 220 Hz × 2^(n / 12), one semitone per step, every step a distinct tone; over every size and eccentricity step with
// three directions (and, for every size, an orbit whose direction is out of range, so every step has an orbit that
// cannot be set): an orbit that can be set (`isValid`, decided here independently from its steps) sounds its tone and
// its fifth (ratio 3/2) for k ≤ 7 or its fourth (ratio 4/3) for k ≥ 8, a consonant interval; one that cannot be set
// sounds its tone and a partial 3 Hz above, a 3 Hz beat; each at gain 0.04; 0.6 s; pure (equal orbits give equal
// auditions) and different whenever (n, k ≤ 7, can be set) differs — the 33 distinct auditions of the 11 steps, each
// with a fifth, a fourth and a beat; the certified winning orbits of levels 76, 77 and 78 sound consonant intervals.
// The ambient recipe: the root step at its boundaries (0 for more than 3/4 of the action budget left, 1 for more than
// 1/2, 2 for more than 1/4, else 3), checked against an independent fraction comparison for every budget the kernel
// allows; the met quarters min(4, ⌊4m / n⌋) of m targets met in order of n, independently and over real plays (the
// met count recomputed with `ApsidesWorkshopSky.report`); pure (equal inputs give equal recipes); different for every
// change of the root step, of the met quarters and of the stage among playing, won and failed; the documented partials
// (root 110 Hz × (1, 9/8, 5/4, 4/3)[step], a partial per quarter at the root × (5/4, 3/2, 2, 5/2)[k − 1], up to four,
// the root alone below a quarter, the octave when won, halved amplitudes and gain when failed); the loop length the
// longest in 4 … 16 s at which every partial has a whole number of cycles; a valid `AmbientLoopRecipe` within its
// limits for every input; and `recipe(play:)` over real plays of the certified levels around the feature seed 2_476
// (levels 76, 77 and 78: size tunings draining the budget, a failed play, its result, its undo, a pause, a won plan and
// its result) equal to the recipe of the play's root step, met quarters and stage, equal for equal keys and different
// whenever the keys differ. Explicit types, plain loops, short runs, no clocks.
import Foundation
import Testing
import VisualCoreAudioDSP
@testable import ApsidesWorkshopCore

@Suite struct ApsidesWorkshopSoundRecipeTests {
    typealias Recipe = ApsidesWorkshopSoundRecipe
    typealias Audition = ApsidesWorkshopAudition
    typealias Partial = ApsidesWorkshopPartial
    typealias Orbit = ApsidesWorkshopOrbit
    typealias Play = ApsidesWorkshopPlay
    typealias Core = ApsidesWorkshopExperienceCore
    /// The feature's fixture seed.
    static let seed: UInt64 = 2_476
    /// The primary level the seed opens (77) and its neighbours.
    static let numbers: [Int] = [Core.levelNumber(forSeed: seed) - 1, Core.levelNumber(forSeed: seed),
                                 Core.levelNumber(forSeed: seed) + 1]
    /// The stages whose sound differs.
    static let stages: [ApsidesWorkshopStage] = [.playing, .won, .failed]
    /// The highest frequency any recipe sounds: the fourth quarter partial at step 3, 110 × 4/3 × 5/2 Hz (plus
    /// rounding).
    static let highestHertz: Double = 110.0 * 4.0 / 3.0 * 5.0 / 2.0 + 1e-9

    /// Whether `value` is a whole number (within a rounding tolerance far below one cycle).
    static func isWhole(_ value: Double) -> Bool { abs(value - value.rounded()) < 1e-6 }

    /// The size step of `size` by the documented formula for sizes 8 … 48: the largest n with 4n ≤ 48 − size.
    static func expectedStep(_ size: Int) -> Int {
        var best: Int = 0
        for n in 0...10 where 4 * n <= 48 - size { best = n }
        return best
    }

    /// The tone of size step `step` by the documented formula.
    static func hertz(step: Int) -> Double { 220 * pow(2, Double(step) / 12) }

    /// Whether `orbit` can be set, decided independently: every step in range, periapsis a(20 − k) ≥ 60 and apoapsis
    /// a(20 + k) ≤ 1280.
    static func settable(_ orbit: Orbit) -> Bool {
        guard (8...48).contains(orbit.size), (0...15).contains(orbit.eccentricity),
              (0...23).contains(orbit.direction) else { return false }
        return orbit.size * (20 - orbit.eccentricity) >= 60 && orbit.size * (20 + orbit.eccentricity) <= 1280
    }

    /// The audition orbits: every size and eccentricity step with directions 0, 13 and 23, and for every size an
    /// orbit whose direction (24) is out of range.
    static func auditionOrbits() -> [Orbit] {
        var orbits: [Orbit] = []
        for size in Orbit.sizes {
            for eccentricity in Orbit.eccentricities {
                for direction in [0, 13, 23] {
                    orbits.append(Orbit(size: size, eccentricity: eccentricity, direction: direction))
                }
            }
            orbits.append(Orbit(size: size, eccentricity: 0, direction: 24))
        }
        return orbits
    }

    @Test func theSizeStepsAndTheirTones() {
        #expect(Audition.duration == 0.6 && Audition.toneGain == 0.04)
        #expect(Audition.step(size: 48) == 0 && Audition.step(size: 8) == 10)
        #expect(Audition.tone(size: 48) == 220)
        #expect(abs(Audition.tone(size: 8) - 391.995_435_981_749_27) < 1e-9)
        var tones: [Double] = []
        for size in Orbit.sizes {
            let step: Int = Audition.step(size: size)
            #expect(step == Self.expectedStep(size), "size \(size)")
            #expect(abs(Audition.tone(size: size) - Self.hertz(step: step)) < 1e-9, "size \(size)")
        }
        // Every step 0 … 10 is reached, a semitone apart, each a distinct tone; a larger orbit never sounds higher.
        for step in 0...10 {
            let size: Int = 48 - 4 * step
            #expect(Audition.step(size: size) == step)
            let tone: Double = Audition.tone(size: size)
            if let previous = tones.last { #expect(abs(tone / previous - pow(2, 1.0 / 12)) < 1e-12, "step \(step)") }
            for earlier in tones { #expect(tone != earlier, "step \(step)") }
            tones.append(tone)
        }
        #expect(tones.count == 11)
        var previous: Double = 0
        for size in stride(from: 48, through: 8, by: -1) {
            let tone: Double = Audition.tone(size: size)
            #expect(tone >= previous, "size \(size)")
            previous = tone
        }
        // Outside 8 … 48 the step is clamped.
        #expect(Audition.step(size: 49) == 0 && Audition.step(size: 200) == 0)
        #expect(Audition.step(size: 7) == 10 && Audition.step(size: -5) == 10)
        #expect(Audition.tone(size: 60) == 220 && Audition.tone(size: 0) == Audition.tone(size: 8))
    }

    @Test func aSettableOrbitIsAConsonantIntervalAndOneThatCannotBeSetBeats() throws {
        var fifths: Int = 0
        var fourths: Int = 0
        var beats: Int = 0
        for orbit in Self.auditionOrbits() {
            let label: String = "a \(orbit.size) k \(orbit.eccentricity) d \(orbit.direction)"
            let audition: Audition = Audition.of(orbit)
            let tone: Double = Self.hertz(step: Self.expectedStep(orbit.size))
            #expect(audition.partials.count == 2, "\(label)")
            guard audition.partials.count == 2 else { continue }
            let first: Partial = audition.partials[0]
            let second: Partial = audition.partials[1]
            #expect(abs(first.frequency - tone) < 1e-9 && first.gain == 0.04 && second.gain == 0.04, "\(label)")
            let settable: Bool = Self.settable(orbit)
            #expect(orbit.isValid == settable, "\(label)")
            if settable && orbit.eccentricity <= 7 {
                // A consonant interval: the fifth, ratio exactly 3/2.
                #expect(abs(second.frequency / first.frequency - 1.5) < 1e-12, "\(label)")
                fifths += 1
            } else if settable {
                // A consonant interval: the fourth, ratio exactly 4/3.
                #expect(abs(second.frequency / first.frequency - 4.0 / 3.0) < 1e-12, "\(label)")
                fourths += 1
            } else {
                // A 3 Hz beat: the partials differ by exactly 3 Hz; never silence.
                #expect(abs(second.frequency - first.frequency - 3) < 1e-9, "\(label)")
                beats += 1
            }
            // Pure: an equal orbit gives an equal audition.
            let copy: Orbit = Orbit(size: orbit.size, eccentricity: orbit.eccentricity, direction: orbit.direction)
            #expect(Audition.of(copy) == audition, "\(label)")
        }
        #expect(fifths > 0 && fourths > 0 && beats > 0, "\(fifths) fifths, \(fourths) fourths, \(beats) beats")
        // The certified winning orbits, which a player sets, sound consonant intervals.
        for number in Self.numbers {
            let orbit: Orbit = try Core.generated(number: number).plan.orbit
            let audition: Audition = Audition.of(orbit)
            let ratio: Double = (audition.partials.last?.frequency ?? 0) / (audition.partials.first?.frequency ?? 1)
            let expected: Double = orbit.eccentricity <= 7 ? 1.5 : 4.0 / 3.0
            #expect(orbit.isValid && abs(ratio - expected) < 1e-12, "level \(number)")
        }
    }

    @Test func auditionsDifferWheneverTheStepTheIntervalOrSettabilityDiffers() {
        // Every (n, k ≤ 7, can be set) key gives one audition (an orbit that cannot be set beats whatever its k), and
        // different keys different auditions.
        var keys: [String] = []
        var auditions: [Audition] = []
        for orbit in Self.auditionOrbits() {
            let step: Int = Self.expectedStep(orbit.size)
            let settable: Bool = Self.settable(orbit)
            let key: String = settable ? "\(step)/\(orbit.eccentricity <= 7)/set" : "\(step)/beat"
            let audition: Audition = Audition.of(orbit)
            if let index = keys.firstIndex(of: key) {
                #expect(auditions[index] == audition, "\(key)")
            } else {
                for earlier in auditions { #expect(earlier != audition, "\(key)") }
                keys.append(key)
                auditions.append(audition)
            }
        }
        // 11 steps, each with a fifth, a fourth and a beat.
        #expect(keys.count == 33)
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
        for budget in ApsidesWorkshopLevel.budgets {
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

    /// The met quarters by an independent rule: the largest k in 0 … 4 with k / 4 ≤ met / targets.
    static func expectedQuarters(met: Int, targets: Int) -> Int {
        guard targets > 0 else { return 0 }
        var best: Int = 0
        for k in 0...4 where k * targets <= 4 * met { best = k }
        return best
    }

    /// The targets `play`'s orbit meets in order, recomputed independently from its level and orbit.
    static func recomputedMet(_ play: Play) -> Int {
        ApsidesWorkshopSky.report(play.level, orbit: play.orbit).met
    }

    /// The met quarters of `play` by the independent rule over its recomputed report.
    static func expectedQuarters(_ play: Play) -> Int {
        expectedQuarters(met: recomputedMet(play), targets: play.level.targets.count)
    }

    /// The plays of certified level `number`: the opening, the play after each tuning of its certified plan and the
    /// play after the winning play.
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

    @Test func theQuartersFromTheMetTargets() throws {
        // 4 targets: each met target is one quarter. 6 targets: 0 … 1 none, 2 one, 3 two, 4 … 5 three, 6 four.
        for met in 0...4 { #expect(Recipe.quarters(met: met, targets: 4) == met, "\(met)/4") }
        let six: [Int] = [0, 0, 1, 2, 2, 3, 4]
        for met in 0...6 { #expect(Recipe.quarters(met: met, targets: 6) == six[met], "\(met)/6") }
        for targets in ApsidesWorkshopLevel.targetCounts {
            for met in 0...targets {
                #expect(Recipe.quarters(met: met, targets: targets)
                        == Self.expectedQuarters(met: met, targets: targets), "\(met) of \(targets)")
            }
        }
        #expect(Recipe.quarters(met: 3, targets: 0) == 0 && Recipe.quarters(met: -2, targets: 5) == 0)
        #expect(Recipe.quarters(met: 9, targets: 5) == 4)
        #expect(Recipe.quarterPartials(quarters: 7) == 4 && Recipe.quarterPartials(quarters: -1) == 0)
        // Real plays: the quarters of the met targets over the target count; a won play has met them all.
        var seen: Set<Int> = []
        for number in Self.numbers {
            for play in try Self.planPlays(number) {
                let quarters: Int = Recipe.metQuarters(play)
                #expect(quarters == Self.expectedQuarters(play), "level \(number)")
                #expect(play.report.met == Self.recomputedMet(play))
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
        // Nothing met at step 0: the root alone, 110 Hz over 16 s.
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
        let others: [ApsidesWorkshopStage] = [.loading, .tutorial, .paused, .result]
        for stage in others { #expect(Recipe.recipe(rootStep: 2, quarters: 2, stage: stage) == playing) }
    }

    @Test func everyRecipeIsWithinTheLimitsWithWholeCycles() {
        for step in -1...5 {
            for quarters in -2...7 {
                for stage in ApsidesWorkshopStage.allCases {
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

    /// The recipe key of `play`: its root step, met quarters and sounding stage (the stages other than won and failed
    /// sound as playing), each decided by the independent rules.
    static func key(_ play: Play) -> String {
        let stage: ApsidesWorkshopStage = play.stage == .won || play.stage == .failed ? play.stage : .playing
        let step: Int = Self.expectedStep(left: play.actionsLeft, budget: play.level.budget)
        return "\(step)/\(Self.expectedQuarters(play))/\(stage)"
    }

    /// A size one unit away from `orbit`'s that keeps it valid (one larger, else one smaller), or nil.
    static func nearbySize(_ orbit: Orbit) -> Int? {
        for size in [orbit.size + 1, orbit.size - 1] {
            if Orbit(size: size, eccentricity: orbit.eccentricity, direction: orbit.direction).isValid { return size }
        }
        return nil
    }

    /// Real plays of the primary level: size tunings back and forth between the starting size and a neighbouring one
    /// (so every second play has the starting orbit again), draining the budget to fewer than two actions; then the
    /// play at the starting orbit (a failure: a certified level's starting orbit never wins), the result after it, its
    /// undo, a pause, and the certified plan won and its result.
    static func scriptedPlays() throws -> [Play] {
        let number: Int = Core.levelNumber(forSeed: seed)
        var play: Play = try Core.opening(number: number).play
        var plays: [Play] = [play]
        let home: Int = play.orbit.size
        guard let away = nearbySize(play.orbit) else {
            Issue.record("level \(number) has no valid neighbouring size")
            return plays
        }
        while play.stage == .playing, play.actionsLeft >= 2 {
            try play.apply(.size(away), expecting: play.fingerprint)
            plays.append(play)
            try play.apply(.size(home), expecting: play.fingerprint)
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
        var stagesSeen: Set<ApsidesWorkshopStage> = []
        var stepsSeen: Set<Int> = []
        for play in plays {
            let recipe: AmbientLoopRecipe = Recipe.recipe(play: play)
            let expected: AmbientLoopRecipe = Recipe.recipe(
                rootStep: Recipe.rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
                quarters: Recipe.metQuarters(play), stage: play.stage)
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
