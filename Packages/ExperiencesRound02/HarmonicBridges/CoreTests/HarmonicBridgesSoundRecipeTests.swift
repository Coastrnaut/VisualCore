// HarmonicBridgesSoundRecipeTests — feature 416 (R02-G12-06) T-R02G1206-004 (FR-R02G1206-006; SC-R02G1206-004;
// clarification Q4). The audition: on the hand level (`HarmonicBridgesFixtures.handLevel`) every string's partials in
// both steps, frequencies 110 Hz × 2^((peg − 1) / 12) × n and gains 0.04 × w exact, the muted pluck (the fundamental
// alone at 0.02) for a string that sings no mode, peg 1 at exactly 110 Hz after the winning tuning, silence for an
// unknown string and the muted pluck for an unknown step; pure and different when the peg or the modes differ; over a
// generated level, every audition within its bounds. The ambient recipe: the root step at its boundaries (0 for more
// than 3/4 of the action budget left, 1 for more than 1/2, 2 for more than 1/4, else 3), checked against an independent
// fraction comparison for every budget 1 … 60; pure (equal inputs give equal recipes); different for every change of
// the root step, of the reached-step partials (the steps reached clamped to 0 … 4) and of the stage among playing, won
// and failed; the documented partials (root 110 Hz × (1, 9/8, 5/4, 4/3)[step], a partial per reached step at the root ×
// (5/4, 3/2, 2, 5/2)[k − 1], up to four, the root alone with none reached, the octave and a two-cycle swell when won,
// halved amplitudes and gain when failed); the loop length the longest in 4 … 16 s at which every partial has a whole
// number of cycles (16 s for steps 0 … 2, 15 s for step 3); a valid `AmbientLoopRecipe` within its limits for every
// input; and `recipe(play:)` over real kernel plays of the hand level with budgets 1 … 8 — tunings, tests, wins,
// failures, results, pauses and undos — equal to the recipe of the play's root step, steps reached and stage, equal for
// equal plays and different whenever those differ. Explicit types, plain loops, short runs, no clocks.
import Foundation
import Testing
@testable import HarmonicBridgesCore
import VisualCoreAudioDSP

@Suite struct HarmonicBridgesSoundRecipeTests {
    typealias Recipe = HarmonicBridgesSoundRecipe
    typealias Audition = HarmonicBridgesAudition
    typealias Partial = HarmonicBridgesPartial
    typealias Play = HarmonicBridgesPlay
    typealias Snapshot = HarmonicBridgesSceneSnapshot
    /// The stages whose sound differs.
    static let stages: [HarmonicBridgesStage] = [.playing, .won, .failed]

    /// The highest frequency any recipe sounds: the fourth reached partial at step 3, 110 × 4/3 × 5/2 Hz (plus
    /// rounding).
    static let highestHertz: Double = 110.0 * 4.0 / 3.0 * 5.0 / 2.0 + 1e-9

    /// Whether `value` is a whole number (within a rounding tolerance far below one cycle).
    static func isWhole(_ value: Double) -> Bool { abs(value - value.rounded()) < 1e-6 }

    /// The fundamental of `peg` by the documented formula.
    static func hertz(_ peg: Int) -> Double { 110 * pow(2, Double(peg - 1) / 12) }

    /// A fresh play of `level` in stage `playing`.
    static func fresh(_ level: HarmonicBridgesLevel) throws -> Play {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The snapshot of `play` at time 0.
    static func snap(_ play: Play) -> Snapshot { Snapshot(play: play, levelNumber: 1, time: 0) }

    // MARK: - Audition

    @Test func theAuditionOfTheHandLevelIsExact() throws {
        #expect(Audition.duration == 0.6)
        let play: Play = try Self.fresh(HarmonicBridgesFixtures.handLevel())
        let snapshot: Snapshot = Self.snap(play)
        #expect(snapshot.pegs == [2, 4, 3, 5])
        // Step 0 (tone 2, strength 2): strings 0 and 1 in mode 1, string 2 in mode 2, string 3 silent.
        #expect(Audition.of(snapshot, string: 0, step: 0).partials
                == [Partial(frequency: Self.hertz(2), gain: 0.08)])
        #expect(Audition.of(snapshot, string: 1, step: 0).partials
                == [Partial(frequency: Self.hertz(4), gain: 0.08)])
        #expect(Audition.of(snapshot, string: 2, step: 0).partials
                == [Partial(frequency: Self.hertz(3) * 2, gain: 0.08)])
        #expect(Audition.of(snapshot, string: 3, step: 0).partials
                == [Partial(frequency: Self.hertz(5), gain: 0.02)])
        // Step 1 (tones 1 and 3, strength 1): string 2 in modes 1 and 3; strings 0, 1 and 3 muted.
        #expect(Audition.of(snapshot, string: 2, step: 1).partials
                == [Partial(frequency: Self.hertz(3), gain: 0.04), Partial(frequency: Self.hertz(3) * 3, gain: 0.04)])
        let muted: [Int] = [0, 1, 3]
        for string in muted {
            let partials: [Partial] = Audition.of(snapshot, string: string, step: 1).partials
            #expect(partials == [Partial(frequency: Self.hertz(snapshot.pegs[string]), gain: 0.02)], "string \(string)")
        }
        // The documented values in hertz: peg 2 ≈ 116.54 Hz, peg 4 ≈ 130.81 Hz, peg 5 ≈ 138.59 Hz.
        #expect(abs(Self.hertz(2) - 116.540_940) < 1e-5)
        #expect(abs(Self.hertz(4) - 130.812_783) < 1e-5)
        #expect(abs(Self.hertz(5) - 138.591_315) < 1e-5)
        #expect(Audition.fundamental(peg: 13) == 220)
        // After the winning tuning string 3 sits on peg 1 (exactly 110 Hz): mode 2 in step 0, modes 1 and 3 in step 1.
        var tuned: Play = play
        try tuned.apply(.tune(3, 1), expecting: tuned.fingerprint)
        let after: Snapshot = Self.snap(tuned)
        #expect(Audition.of(after, string: 3, step: 0).partials == [Partial(frequency: 220, gain: 0.08)])
        #expect(Audition.of(after, string: 3, step: 1).partials
                == [Partial(frequency: 110, gain: 0.04), Partial(frequency: 330, gain: 0.04)])
        // An unknown string is silent; an unknown step sings no mode (the muted pluck).
        #expect(Audition.of(snapshot, string: 4, step: 0).partials.isEmpty)
        #expect(Audition.of(snapshot, string: -1, step: 0).partials.isEmpty)
        #expect(Audition.of(snapshot, string: 1, step: 2).partials == [Partial(frequency: Self.hertz(4), gain: 0.02)])
        #expect(Audition.of(snapshot, string: 1, step: -1).partials == [Partial(frequency: Self.hertz(4), gain: 0.02)])
    }

    @Test func theAuditionIsPureAndFollowsPegAndModes() throws {
        let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel()
        let play: Play = try Self.fresh(level)
        let snapshot: Snapshot = Self.snap(play)
        // Equal inputs give equal auditions, at any presentation time.
        let later: Snapshot = Snapshot(play: play, levelNumber: 3, time: 7.5)
        for string in 0..<4 {
            for step in 0..<2 {
                let first: Audition = Audition.of(snapshot, string: string, step: step)
                #expect(first == Audition.of(snapshot, string: string, step: step))
                #expect(first == Audition.of(later, string: string, step: step))
            }
        }
        // Every peg of string 0 gives a different audition in step 0 (the fundamental moves by a semitone each peg).
        var seen: [Audition] = []
        for peg in HarmonicBridgesLevel.pegs {
            var tuned: Play = play
            if peg != snapshot.pegs[0] { try tuned.apply(.tune(0, peg), expecting: tuned.fingerprint) }
            let audition: Audition = Audition.of(Self.snap(tuned), string: 0, step: 0)
            for earlier in seen { #expect(audition != earlier, "peg \(peg)") }
            seen.append(audition)
        }
        // A resonant string and a muted one differ (step 0 and step 1 of string 0).
        #expect(Audition.of(snapshot, string: 0, step: 0) != Audition.of(snapshot, string: 0, step: 1))
    }

    @Test func everyAuditionOfAGeneratedLevelIsWithinItsBounds() throws {
        let fixtures: [HarmonicBridgesFixture] = HarmonicBridgesFixtures.fixtures(4)
        #expect(!fixtures.isEmpty)
        for fixture in fixtures {
            let snapshot: Snapshot = Self.snap(try Self.fresh(fixture.level))
            for string in snapshot.pegs.indices {
                for step in 0..<snapshot.steps {
                    let partials: [Partial] = Audition.of(snapshot, string: string, step: step).partials
                    let modes: [Int] = snapshot.modes[step][string]
                    let strengths: [Int] = snapshot.strengths[step][string]
                    let root: Double = Self.hertz(snapshot.pegs[string])
                    if modes.isEmpty {
                        #expect(partials == [Partial(frequency: root, gain: 0.02)])
                    } else {
                        #expect(partials.count == modes.count)
                        for index in partials.indices where index < modes.count {
                            #expect(partials[index].frequency == root * Double(modes[index]))
                            #expect(partials[index].gain == 0.04 * Double(strengths[index]))
                        }
                    }
                    for partial in partials {
                        #expect(partial.frequency >= 110 && partial.frequency <= Self.hertz(12) * 5 + 1e-9)
                        #expect(partial.gain > 0 && partial.gain <= 0.12 + 1e-12)
                    }
                }
            }
        }
    }

    // MARK: - Ambient recipe

    /// The root step by an independent rule: the share of the budget left compared with 3/4, 1/2 and 1/4 as
    /// cross-multiplied fractions written out differently (left / budget > p / q ⇔ left · q > p · budget).
    static func expectedStep(left: Int, budget: Int) -> Int {
        let thresholds: [(Int, Int)] = [(3, 4), (1, 2), (1, 4)]
        for index in thresholds.indices {
            let (p, q): (Int, Int) = thresholds[index]
            if left * q > p * budget { return index }
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
        for budget in HarmonicBridgesLevel.budgets {
            var previous: Int = 0
            for left in stride(from: budget, through: 0, by: -1) {
                let step: Int = Recipe.rootStep(actionsLeft: left, budget: budget)
                #expect(step == Self.expectedStep(left: left, budget: budget), "\(left) of \(budget)")
                #expect(step >= previous && Recipe.rootSteps.contains(step))
                previous = step
            }
            #expect(Recipe.rootStep(actionsLeft: budget, budget: budget) == 0)
            #expect(Recipe.rootStep(actionsLeft: 0, budget: budget) == 3)
        }
        #expect(Recipe.clampedStep(-2) == 0 && Recipe.clampedStep(9) == 3)
    }

    @Test func theDocumentedPartials() {
        #expect(Recipe.rootHertz == 110)
        let stepRatios: [Double] = [1.0, 1.125, 1.25, 4.0 / 3.0]
        let reachedRatios: [Double] = [1.25, 1.5, 2.0, 2.5]
        #expect(Recipe.stepRatios == stepRatios)
        #expect(Recipe.reachedRatios == reachedRatios)
        // None reached at step 0: the root alone, 110 Hz over 16 s.
        let alone: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, reached: 0, stage: .playing)
        #expect(alone.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.6)])
        #expect(alone.gain == 0.2 && alone.swellCycles == 1 && alone.seconds == 16)
        // Three reached at step 0: root, 5/4, 3/2 and 2.
        let three: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, reached: 3, stage: .playing)
        #expect(three.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520])
        // Step 1 (9/8): 123.75 Hz, whole over 16 s only.
        let second: AmbientLoopRecipe = Recipe.recipe(rootStep: 1, reached: 2, stage: .playing)
        #expect(second.seconds == 16 && second.partials.map(\.cyclesPerLoop) == [1_980, 2_475, 2_970])
        // Step 3 (4/3): 146.67 Hz, whole only in multiples of 3 s, so 15 s.
        let high: AmbientLoopRecipe = Recipe.recipe(rootStep: 3, reached: 4, stage: .playing)
        #expect(high.seconds == 15 && high.partials.map(\.cyclesPerLoop) == [2_200, 2_750, 3_300, 4_400, 5_500])
        // Won with four reached: root, four partials and the octave, swelling twice.
        let won: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, reached: 4, stage: .won)
        #expect(won.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520, 4_400, 3_520])
        #expect(won.partials.count == 6 && won.swellCycles == 2 && won.gain == 0.2)
        // None reached when won: the root and its octave.
        #expect(Recipe.recipe(rootStep: 2, reached: 0, stage: .won).partials.map(\.cyclesPerLoop) == [2_200, 4_400])
        // Failed: amplitudes and gain halved.
        let failed: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, reached: 1, stage: .failed)
        #expect(failed.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.3),
                                    AmbientLoopPartial(cyclesPerLoop: 2_200, amplitude: 0.3)])
        #expect(failed.gain == 0.1 && failed.swellCycles == 1)
        // At most four reached partials; the step is clamped to 0 … 3; negative counts count as none.
        let four: AmbientLoopRecipe = Recipe.recipe(rootStep: 1, reached: 4, stage: .playing)
        #expect(Recipe.recipe(rootStep: 1, reached: 6, stage: .playing) == four)
        #expect(Recipe.recipe(rootStep: -1, reached: 1, stage: .playing)
                == Recipe.recipe(rootStep: 0, reached: 1, stage: .playing))
        #expect(Recipe.recipe(rootStep: 7, reached: 1, stage: .playing)
                == Recipe.recipe(rootStep: 3, reached: 1, stage: .playing))
        #expect(Recipe.recipe(rootStep: 0, reached: -2, stage: .playing) == alone)
        #expect(Recipe.reachedPartials(reached: 7) == 4 && Recipe.reachedPartials(reached: -1) == 0)
    }

    @Test func pureAndDistinct() {
        var seen: [AmbientLoopRecipe] = []
        for step in 0...3 {
            for reached in 0...4 {
                for stage in Self.stages {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(rootStep: step, reached: reached, stage: stage)
                    // Equal inputs give equal recipes.
                    #expect(recipe == Recipe.recipe(rootStep: step, reached: reached, stage: stage))
                    for earlier in seen { #expect(recipe != earlier, "step \(step) reached \(reached) \(stage)") }
                    seen.append(recipe)
                }
            }
        }
        #expect(seen.count == 60)
        // The other stages sound as playing.
        let playing: AmbientLoopRecipe = Recipe.recipe(rootStep: 2, reached: 2, stage: .playing)
        let others: [HarmonicBridgesStage] = [.loading, .tutorial, .paused, .result]
        for stage in others { #expect(Recipe.recipe(rootStep: 2, reached: 2, stage: stage) == playing) }
    }

    @Test func everyRecipeIsWithinTheLimitsWithWholeCycles() {
        for step in -1...5 {
            for reached in -2...7 {
                for stage in HarmonicBridgesStage.allCases {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(rootStep: step, reached: reached, stage: stage)
                    let label: String = "step \(step) reached \(reached) \(stage)"
                    #expect(recipe.isValid, "\(label)")
                    #expect(AmbientLoopRecipe.partialCountRange.contains(recipe.partials.count), "\(label)")
                    #expect(recipe.partials.count <= 6)
                    #expect(AmbientLoopRecipe.secondsRange.contains(recipe.seconds), "\(label)")
                    #expect(recipe.gain <= Recipe.baseGain && recipe.gain > 0)
                    #expect(recipe.seconds == Recipe.loopSeconds(rootStep: step, reached: reached, stage: stage))
                    // The partials sound the documented frequencies, each a whole number of cycles in the loop.
                    let frequencies: [Double] = Recipe.frequencies(rootStep: step, reached: reached, stage: stage)
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
                #expect(Recipe.loopSeconds(rootStep: step, reached: 4, stage: stage) == (step == 3 ? 15 : 16))
                #expect(Recipe.loopSeconds(rootStep: step, reached: 0, stage: stage) == (step == 3 ? 15 : 16))
            }
        }
    }

    @Test func theRootAloneOctaveWhenWonAndHalvedWhenFailed() {
        for step in 0...3 {
            let root: Double = 110 * Recipe.stepRatios[step]
            let alone: [Double] = Recipe.frequencies(rootStep: step, reached: 0, stage: .playing)
            #expect(alone.count == 1 && abs((alone.first ?? 0) - root) < 1e-9)
            for reached in 0...4 {
                let playing: AmbientLoopRecipe = Recipe.recipe(rootStep: step, reached: reached, stage: .playing)
                #expect(playing.partials.count == 1 + reached)
                let won: AmbientLoopRecipe = Recipe.recipe(rootStep: step, reached: reached, stage: .won)
                #expect(won.partials.count == playing.partials.count + 1)
                #expect(Array(won.partials.prefix(playing.partials.count)) == playing.partials)
                #expect(won.partials.last?.cyclesPerLoop == playing.partials[0].cyclesPerLoop * 2)
                #expect(won.swellCycles == 2 && playing.swellCycles == 1)
                let failed: AmbientLoopRecipe = Recipe.recipe(rootStep: step, reached: reached, stage: .failed)
                #expect(failed.seconds == playing.seconds && failed.gain == playing.gain / 2)
                #expect(failed.partials.map(\.cyclesPerLoop) == playing.partials.map(\.cyclesPerLoop))
                for index in failed.partials.indices {
                    #expect(failed.partials[index].amplitude == playing.partials[index].amplitude / 2)
                }
            }
        }
    }

    /// The steps of `play` in which the start reaches the goal, read through the snapshot.
    static func reachedSteps(_ play: Play) -> Int {
        let snapshot: Snapshot = snap(play)
        var count: Int = 0
        for step in 0..<snapshot.steps where snapshot.isReached(snapshot.goal, step: step) { count += 1 }
        return count
    }

    /// The sound key of `play` by an independent reading: the root step, the steps reached up to 4 and the stage group
    /// (won, failed, or playing for every other stage).
    static func key(_ play: Play) -> String {
        let step: Int = expectedStep(left: play.actionsLeft, budget: play.level.budget)
        let group: String = play.stage == .won ? "won" : (play.stage == .failed ? "failed" : "playing")
        return "\(step) \(min(reachedSteps(play), 4)) \(group)"
    }

    /// Real plays of the hand level with budgets 1 … 8: every prefix of a script of tunings and a test (refused actions
    /// skipped), its undo, its pause, and its result once ended; plus an immediate broken test of each budget.
    static func realPlays() throws -> [Play] {
        let scripts: [[HarmonicBridgesAction]] = [[.tune(0, 1), .tune(3, 1), .tune(0, 2), .tune(2, 1), .tune(2, 3),
                                                   .test],
                                                  [.test]]
        var plays: [Play] = []
        for budget in 1...8 {
            for script in scripts {
                let level: HarmonicBridgesLevel = HarmonicBridgesFixtures.handLevel(budget: budget)
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
        var stagesMet: Set<HarmonicBridgesStage> = []
        var reachedMet: Set<Int> = []
        for play in plays {
            let recipe: AmbientLoopRecipe = Recipe.recipe(play: play)
            let step: Int = Self.expectedStep(left: play.actionsLeft, budget: play.level.budget)
            let reached: Int = Self.reachedSteps(play)
            steps.insert(step)
            stagesMet.insert(play.stage)
            reachedMet.insert(reached)
            #expect(Recipe.stepsReached(play) == reached)
            #expect(recipe == Recipe.recipe(rootStep: step, reached: reached, stage: play.stage))
            #expect(recipe == Recipe.recipe(play: play))
            #expect(recipe.isValid && recipe.partials.count <= 6)
            keys.append(Self.key(play))
            recipes.append(recipe)
        }
        #expect(plays.count > 60)
        #expect(steps.count == 4, "root steps met: \(steps.sorted())")
        let wanted: [HarmonicBridgesStage] = [.playing, .paused, .won, .failed, .result]
        for stage in wanted { #expect(stagesMet.contains(stage), "\(stage) not met") }
        #expect(reachedMet == [0, 1, 2], "steps reached met: \(reachedMet.sorted())")
        // Equal states sound equal; different states sound different.
        for first in recipes.indices {
            for second in recipes.indices where second > first {
                #expect((keys[first] == keys[second]) == (recipes[first] == recipes[second]),
                        "\(keys[first]) vs \(keys[second])")
            }
        }
        // A win on the 6-action hand level: both steps reached, the octave and the two-cycle swell.
        var won: Play = try Self.fresh(HarmonicBridgesFixtures.handLevel())
        let winning: [HarmonicBridgesAction] = [.tune(3, 1), .test]
        for action in winning { try won.apply(action, expecting: won.fingerprint) }
        #expect(won.stage == .won)
        let last: AmbientLoopRecipe = Recipe.recipe(play: won)
        #expect(last.swellCycles == 2 && last.partials.count == 4)
        // 4 of 6 actions left (more than 1/2, not more than 3/4): step 1 (123.75 Hz), 16 s.
        #expect(last.seconds == 16 && last.partials.map(\.cyclesPerLoop) == [1_980, 2_475, 2_970, 3_960])
    }
}
