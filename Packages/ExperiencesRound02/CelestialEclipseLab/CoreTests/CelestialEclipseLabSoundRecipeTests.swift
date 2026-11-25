// CelestialEclipseLabSoundRecipeTests — feature 466 (R02-G17-06) T-R02G1706-004 (FR-R02G1706-006; SC-R02G1706-004;
// clarification Q4). The audition: body j's tone 220 Hz × 2^(2j / 12), one whole tone per body index, clamped to
// bodies 0 … 5; over real plays of the certified levels around the feature seed 2_466 (levels 66, 67 and 68, from
// `CelestialEclipseLabExperienceCore.opening(number:)`, at their opening, after each phase change of their certified
// plans, `generated(number:).plan.actions`, after the winning run, and after each single phase change of every movable
// body from the opening), for every body: a body that takes part (front or back) in an eclipse interval of the
// predicted timeline — recomputed here with `CelestialEclipseLabSky.timeline` — sounds its tone and its fifth (ratio
// 3/2), a consonant chord; any other sounds its tone and a partial 3 Hz above, a 3 Hz beat; each at gain 0.04; silence
// for a negative index and one at or past the body count; 0.6 s; pure (equal plays give equal auditions) and different
// whenever the (body, involved) pair differs. The ambient recipe: the root step at its boundaries (0 for more than 3/4
// of the action budget left, 1 for more than 1/2, 2 for more than 1/4, else 3), checked against an independent
// fraction comparison for every budget the kernel allows; the matched quarters min(4, ⌊4m / n⌋) of m target eclipses
// matched in order of n, independently and over real plays; pure (equal inputs give equal recipes); different for
// every change of the root step, of the matched quarters and of the stage among playing, won and failed; the
// documented partials (root 110 Hz × (1, 9/8, 5/4, 4/3)[step], a partial per quarter at the root × (5/4, 3/2, 2,
// 5/2)[k − 1], up to four, the root alone below a quarter, the octave when won, halved amplitudes and gain when
// failed); the loop length the longest in 4 … 16 s at which every partial has a whole number of cycles; a valid
// `AmbientLoopRecipe` within its limits for every input; and `recipe(play:)` over real plays (phase changes draining
// the budget, a failed run, its result, its undo, a pause, a won plan and its result) equal to the recipe of the play's
// root step, matched quarters and stage, equal for equal keys and different whenever the keys differ. Explicit types,
// plain loops, short runs, no clocks.
import Foundation
import Testing
import VisualCoreAudioDSP
@testable import CelestialEclipseLabCore

@Suite struct CelestialEclipseLabSoundRecipeTests {
    typealias Recipe = CelestialEclipseLabSoundRecipe
    typealias Audition = CelestialEclipseLabAudition
    typealias Partial = CelestialEclipseLabPartial
    typealias Play = CelestialEclipseLabPlay
    typealias Core = CelestialEclipseLabExperienceCore
    /// The feature's fixture seed.
    static let seed: UInt64 = 2_466
    /// The primary level the seed opens (67) and its neighbours.
    static let numbers: [Int] = [Core.levelNumber(forSeed: seed) - 1, Core.levelNumber(forSeed: seed),
                                 Core.levelNumber(forSeed: seed) + 1]
    /// The stages whose sound differs.
    static let stages: [CelestialEclipseLabStage] = [.playing, .won, .failed]
    /// The highest frequency any recipe sounds: the fourth quarter partial at step 3, 110 × 4/3 × 5/2 Hz (plus
    /// rounding).
    static let highestHertz: Double = 110.0 * 4.0 / 3.0 * 5.0 / 2.0 + 1e-9

    /// Whether `value` is a whole number (within a rounding tolerance far below one cycle).
    static func isWhole(_ value: Double) -> Bool { abs(value - value.rounded()) < 1e-6 }

    /// The tone of body `body` by the documented formula, unclamped.
    static func hertz(_ body: Int) -> Double { 220 * pow(2, Double(2 * body) / 12) }

    /// The predicted timeline of `play`, recomputed independently from its level and phases.
    static func predicted(_ play: Play) -> CelestialEclipseLabTimeline {
        CelestialEclipseLabSky.timeline(play.level, phases: play.phases)
    }

    /// Whether `body` is the front or the back body of an interval of the recomputed timeline of `play`.
    static func involved(_ play: Play, _ body: Int) -> Bool {
        var found: Bool = false
        for interval in predicted(play).intervals where interval.front == body || interval.back == body {
            found = true
        }
        return found
    }

    /// The plays of certified level `number`: the opening, the play after each phase change of its certified plan
    /// and the play after the winning run.
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

    /// The plays one phase change away from the opening of level `number`: every movable body set to each of its
    /// first six offsets other than its current one.
    static func neighbourPlays(_ number: Int) throws -> [Play] {
        let opening: Play = try Core.opening(number: number).play
        var plays: [Play] = []
        for (body, orbit) in opening.level.bodies.enumerated() where !orbit.fixed {
            for offset in 0..<min(orbit.period, 6) where offset != opening.phases[body] {
                var play: Play = opening
                try play.apply(.phase(body, offset), expecting: play.fingerprint)
                plays.append(play)
            }
        }
        return plays
    }

    /// Every audition play: the plan plays and the neighbour plays of each level of ``numbers``.
    static func auditionPlays() throws -> [(number: Int, play: Play)] {
        var result: [(number: Int, play: Play)] = []
        for number in numbers {
            for play in try planPlays(number) { result.append((number: number, play: play)) }
            for play in try neighbourPlays(number) { result.append((number: number, play: play)) }
        }
        return result
    }

    @Test func theTonesPerBodyAndTheirClamp() {
        #expect(Audition.duration == 0.6 && Audition.toneGain == 0.04)
        #expect(Audition.tone(body: 0) == 220)
        #expect(abs(Audition.tone(body: 5) - 391.995_435_981_749_27) < 1e-9)
        var previous: Double = 0
        for body in 0...5 {
            let tone: Double = Audition.tone(body: body)
            #expect(abs(tone - Self.hertz(body)) < 1e-9, "body \(body)")
            #expect(tone > previous)
            if body > 0 { #expect(abs(tone / previous - pow(2, 2.0 / 12)) < 1e-12, "whole tone at \(body)") }
            previous = tone
        }
        // Outside 0 … 5 the index is clamped.
        #expect(Audition.tone(body: -1) == 220 && Audition.tone(body: -4) == 220)
        let top: Double = Audition.tone(body: 5)
        #expect(Audition.tone(body: 6) == top && Audition.tone(body: 40) == top)
    }

    @Test func anInvolvedBodyIsAChordAndAnUninvolvedOneBeats() throws {
        var chords: Int = 0
        var beats: Int = 0
        for (number, play) in try Self.auditionPlays() {
            let count: Int = play.level.bodies.count
            for body in 0..<count {
                let audition: Audition = Audition.of(play, body: body)
                let tone: Double = Self.hertz(body)
                #expect(audition.partials.count == 2, "level \(number) body \(body)")
                guard audition.partials.count == 2 else { continue }
                let first: Partial = audition.partials[0]
                let second: Partial = audition.partials[1]
                #expect(abs(first.frequency - tone) < 1e-9 && first.gain == 0.04 && second.gain == 0.04)
                let involved: Bool = Self.involved(play, body)
                #expect(Audition.isInvolved(play, body: body) == involved)
                if involved {
                    // A consonant chord: the fifth, ratio exactly 3/2.
                    #expect(abs(second.frequency / first.frequency - 1.5) < 1e-12, "level \(number) body \(body)")
                    chords += 1
                } else {
                    // A 3 Hz beat: the partials differ by exactly 3 Hz.
                    #expect(abs(second.frequency - first.frequency - 3) < 1e-9, "level \(number) body \(body)")
                    beats += 1
                }
                // Pure: an equal play gives an equal audition.
                let copy: Play = play
                #expect(Audition.of(copy, body: body) == audition)
            }
            // Silence for a body the level lacks.
            for missing in [-1, count, count + 3] {
                #expect(Audition.of(play, body: missing).partials.isEmpty, "level \(number) body \(missing)")
            }
        }
        #expect(chords > 0 && beats > 0, "\(chords) chords, \(beats) beats")
    }

    @Test func auditionsDifferWheneverTheBodyOrItsInvolvementDiffers() throws {
        // Every (body, involved) pair over the plays gives one audition, and different pairs different auditions.
        var keys: [String] = []
        var auditions: [Audition] = []
        for (_, play) in try Self.auditionPlays() {
            for body in 0..<play.level.bodies.count {
                let key: String = "\(body)/\(Self.involved(play, body))"
                let audition: Audition = Audition.of(play, body: body)
                for index in keys.indices {
                    #expect((keys[index] == key) == (auditions[index] == audition), "\(key) vs \(keys[index])")
                }
                keys.append(key)
                auditions.append(audition)
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
        for budget in CelestialEclipseLabLevel.budgets {
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

    /// The matched quarters by an independent rule: the largest k in 0 … 4 with k / 4 ≤ matched / targets.
    static func expectedQuarters(matched: Int, targets: Int) -> Int {
        guard targets > 0 else { return 0 }
        var best: Int = 0
        for k in 0...4 where k * targets <= 4 * matched { best = k }
        return best
    }

    /// The matched quarters of `play` by the independent rule over its recomputed timeline.
    static func expectedQuarters(_ play: Play) -> Int {
        expectedQuarters(matched: predicted(play).matched, targets: play.level.target.count)
    }

    @Test func theQuartersFromTheMatchedEclipses() throws {
        // 4 targets: each matched eclipse is one quarter. 6 targets: 0 … 1 none, 2 one, 3 two, 4 … 5 three, 6 four.
        for matched in 0...4 { #expect(Recipe.quarters(matched: matched, targets: 4) == matched, "\(matched)/4") }
        let six: [Int] = [0, 0, 1, 2, 2, 3, 4]
        for matched in 0...6 { #expect(Recipe.quarters(matched: matched, targets: 6) == six[matched], "\(matched)/6") }
        for targets in CelestialEclipseLabLevel.targetCounts {
            for matched in 0...targets {
                #expect(Recipe.quarters(matched: matched, targets: targets)
                        == Self.expectedQuarters(matched: matched, targets: targets), "\(matched) of \(targets)")
            }
        }
        #expect(Recipe.quarters(matched: 3, targets: 0) == 0 && Recipe.quarters(matched: -2, targets: 5) == 0)
        #expect(Recipe.quarters(matched: 9, targets: 5) == 4)
        #expect(Recipe.quarterPartials(quarters: 7) == 4 && Recipe.quarterPartials(quarters: -1) == 0)
        // Real plays: the quarters of the matched eclipses over the target's length; a won play has matched all.
        var seen: Set<Int> = []
        for (number, play) in try Self.auditionPlays() {
            let quarters: Int = Recipe.matchedQuarters(play)
            #expect(quarters == Self.expectedQuarters(play), "level \(number)")
            #expect(play.timeline.matched == Self.predicted(play).matched)
            if play.stage == .won { #expect(quarters == 4, "level \(number)") }
            seen.insert(quarters)
        }
        #expect(seen.count >= 2 && seen.contains(4))
    }

    @Test func theDocumentedPartials() {
        #expect(Recipe.rootHertz == 110)
        let stepRatios: [Double] = [1.0, 1.125, 1.25, 4.0 / 3.0]
        let quarterRatios: [Double] = [1.25, 1.5, 2.0, 2.5]
        #expect(Recipe.stepRatios == stepRatios)
        #expect(Recipe.quarterRatios == quarterRatios)
        // Nothing matched at step 0: the root alone, 110 Hz over 16 s.
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
        let others: [CelestialEclipseLabStage] = [.loading, .tutorial, .paused, .result]
        for stage in others { #expect(Recipe.recipe(rootStep: 2, quarters: 2, stage: stage) == playing) }
    }

    @Test func everyRecipeIsWithinTheLimitsWithWholeCycles() {
        for step in -1...5 {
            for quarters in -2...7 {
                for stage in CelestialEclipseLabStage.allCases {
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

    /// The recipe key of `play`: its root step, matched quarters and sounding stage (the stages other than won and
    /// failed sound as playing), each decided by the independent rules.
    static func key(_ play: Play) -> String {
        let stage: CelestialEclipseLabStage = play.stage == .won || play.stage == .failed ? play.stage : .playing
        let step: Int = Self.expectedStep(left: play.actionsLeft, budget: play.level.budget)
        return "\(step)/\(Self.expectedQuarters(play))/\(stage)"
    }

    /// Real plays of the primary level: phase changes of its first movable body with two offsets or more, back and
    /// forth between its starting offset and the next one (so every second play has the starting phases again),
    /// draining the budget to fewer than two actions; then the run at the starting phases (a failure: a certified
    /// level never wins at its start), the result after it, its undo, a pause, and the certified plan won and its
    /// result.
    static func scriptedPlays() throws -> [Play] {
        let number: Int = Core.levelNumber(forSeed: seed)
        var play: Play = try Core.opening(number: number).play
        var plays: [Play] = [play]
        var mover: Int = -1
        for (body, orbit) in play.level.bodies.enumerated() where !orbit.fixed && orbit.period >= 2 && mover < 0 {
            mover = body
        }
        guard mover >= 0 else {
            Issue.record("level \(number) has no movable body with two offsets")
            return plays
        }
        let home: Int = play.phases[mover]
        let away: Int = (home + 1) % play.level.bodies[mover].period
        while play.stage == .playing, play.actionsLeft >= 2 {
            try play.apply(.phase(mover, away), expecting: play.fingerprint)
            plays.append(play)
            try play.apply(.phase(mover, home), expecting: play.fingerprint)
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
        var stagesSeen: Set<CelestialEclipseLabStage> = []
        var stepsSeen: Set<Int> = []
        for play in plays {
            let recipe: AmbientLoopRecipe = Recipe.recipe(play: play)
            let expected: AmbientLoopRecipe = Recipe.recipe(
                rootStep: Recipe.rootStep(actionsLeft: play.actionsLeft, budget: play.level.budget),
                quarters: Recipe.matchedQuarters(play), stage: play.stage)
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
