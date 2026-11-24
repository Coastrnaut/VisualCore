// AcousticConstellatorSoundRecipeTests — feature 426 (R02-G13-06) T-R02G1306-004 (FR-R02G1306-006; SC-R02G1306-004;
// clarification Q4). The audition: on the hand level (`AcousticConstellatorFixtures.handLevel`: three stars of rate 1 at
// phases 0, 0, 1) the tones 220 Hz × 2^(rate / 12) at gain 0.04 each, the second raised by g × 1.5 Hz for the phase gap
// g at the given tick, a gap of 0 giving no detune; silence for a link naming an unknown star; a tick outside the report
// clamped; 0.6 s. Over generated levels (`AcousticConstellatorFixtures.fixtures`) every link and every tick: the
// documented partials against an independent gap, pure (equal at any presentation time), equal exactly when the two
// rates and the gap are equal and different otherwise, within its bounds. The ambient recipe: the root step at its
// boundaries (0 for more than 3/4 of the action budget left, 1 for more than 1/2, 2 for more than 1/4, else 3), checked
// against an independent fraction comparison for every budget 1 … 40; the lit quarters ⌊bars / 3⌋ (0 … 4); pure (equal
// inputs give equal recipes); different for every change of the root step, of the lit quarters and of the stage among
// playing, won and failed; the documented partials (root 110 Hz × (1, 9/8, 5/4, 4/3)[step], a partial per lit quarter
// at the root × (5/4, 3/2, 2, 5/2)[k − 1], up to four, the root alone with none lit, the octave and a two-cycle swell
// when won, halved amplitudes and gain when failed); the loop length the longest in 4 … 16 s at which every partial has
// a whole number of cycles (16 s for steps 0 … 2, 15 s for step 3); a valid `AmbientLoopRecipe` within its limits for
// every input; and `recipe(play:)` over real kernel plays (the hand level with budgets 1 … 8 and generated levels along
// their winning actions — links, nudges, listens, wins, failures, results, pauses and undos) equal to the recipe of the
// play's root step, lit quarters and stage, equal for equal states and different whenever those differ. Explicit types,
// plain loops, short runs, no clocks.
import Foundation
import Testing
@testable import AcousticConstellatorCore
import VisualCoreAudioDSP

@Suite struct AcousticConstellatorSoundRecipeTests {
    typealias Recipe = AcousticConstellatorSoundRecipe
    typealias Audition = AcousticConstellatorAudition
    typealias Partial = AcousticConstellatorPartial
    typealias Play = AcousticConstellatorPlay
    typealias Snapshot = AcousticConstellatorSceneSnapshot
    typealias Level = AcousticConstellatorLevel
    typealias Link = AcousticConstellatorLink
    typealias Action = AcousticConstellatorAction
    /// The stages whose sound differs.
    static let stages: [AcousticConstellatorStage] = [.playing, .won, .failed]

    /// The highest frequency any recipe sounds: the fourth quarter partial at step 3, 110 × 4/3 × 5/2 Hz (plus
    /// rounding).
    static let highestHertz: Double = 110.0 * 4.0 / 3.0 * 5.0 / 2.0 + 1e-9

    /// Whether `value` is a whole number (within a rounding tolerance far below one cycle).
    static func isWhole(_ value: Double) -> Bool { abs(value - value.rounded()) < 1e-6 }

    /// The tone of `rate` by the documented formula.
    static func hertz(_ rate: Int) -> Double { 220 * pow(2, Double(rate) / 12) }

    /// The unsigned phase gap of `p` and `q` on the 12-step clock, by an independent rule: the shorter way round.
    static func gap(_ p: Int, _ q: Int) -> Int {
        let d: Int = ((q - p) % 12 + 12) % 12
        return min(d, 12 - d)
    }

    /// A fresh play of `level` in stage `playing`.
    static func fresh(_ level: Level) throws -> Play {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// The snapshot of `play` at time 0.
    static func snap(_ play: Play) -> Snapshot { Snapshot(play: play, levelNumber: 1, time: 0) }

    /// The hand level with action budget `budget` (otherwise as `AcousticConstellatorFixtures.handLevel()`).
    static func handLevel(budget: Int) -> Level {
        let stars: [AcousticConstellatorStar] = [AcousticConstellatorStar(x: 1, y: 2, z: 3, rate: 1, phase: 0),
                                                 AcousticConstellatorStar(x: 4, y: 5, z: 6, rate: 1, phase: 0),
                                                 AcousticConstellatorStar(x: 7, y: 8, z: 9, rate: 1, phase: 1)]
        do {
            return try Level(id: "hand-three-\(budget)", seed: 9, difficulty: 1, stars: stars,
                             fixedLinks: [Link(a: 0, b: 1)], symbol: [Link(a: 0, b: 1), Link(a: 1, b: 2)],
                             coupling: 2, degreeLimit: 2, linkLimit: 3, snapLimit: 2, threshold: 9, hold: 3,
                             window: 6, budget: budget)
        } catch {
            preconditionFailure("the hand level is valid: \(error)")
        }
    }

    // MARK: - Audition

    @Test func theAuditionOfTheHandLevelIsExact() throws {
        #expect(Audition.duration == 0.6)
        #expect(Audition.tone(rate: 0) == 220 && Audition.tone(rate: 12) == 440)
        #expect(abs(Audition.tone(rate: 1) - 233.081_880) < 1e-5)
        #expect(abs(Audition.tone(rate: 11) - 415.304_698) < 1e-5)
        let play: Play = try Self.fresh(AcousticConstellatorFixtures.handLevel())
        let snapshot: Snapshot = Self.snap(play)
        #expect(snapshot.phases(at: 0) == [0, 0, 1])
        let rate1: Double = Self.hertz(1)
        // Link 0–1 in phase at tick 0: a clean chord, no detune.
        #expect(Audition.of(snapshot, link: Link(a: 0, b: 1), tick: 0).partials
                == [Partial(frequency: rate1, gain: 0.04), Partial(frequency: rate1, gain: 0.04)])
        // Link 1–2 one step apart at tick 0: the second tone 1.5 Hz higher.
        #expect(Audition.of(snapshot, link: Link(a: 1, b: 2), tick: 0).partials
                == [Partial(frequency: rate1, gain: 0.04), Partial(frequency: rate1 + 1.5, gain: 0.04)])
        // A link naming an unknown star is silent.
        #expect(Audition.of(snapshot, link: Link(a: 1, b: 3), tick: 0).partials.isEmpty)
        #expect(Audition.of(snapshot, link: Link(a: -1, b: 2), tick: 0).partials.isEmpty)
        // A tick outside the report is clamped to it.
        let last: Int = snapshot.ticks - 1
        #expect(Audition.of(snapshot, link: Link(a: 1, b: 2), tick: -4) == Audition.of(snapshot, link: Link(a: 1, b: 2),
                                                                                         tick: 0))
        #expect(Audition.of(snapshot, link: Link(a: 1, b: 2), tick: last + 9)
                == Audition.of(snapshot, link: Link(a: 1, b: 2), tick: last))
        // Nudging star 2 two steps further widens the gap at tick 0 to 3: 4.5 Hz.
        var nudged: Play = play
        try nudged.apply(.nudge(2, 1), expecting: nudged.fingerprint)
        try nudged.apply(.nudge(2, 1), expecting: nudged.fingerprint)
        #expect(Audition.of(Self.snap(nudged), link: Link(a: 1, b: 2), tick: 0).partials
                == [Partial(frequency: rate1, gain: 0.04), Partial(frequency: rate1 + 4.5, gain: 0.04)])
    }

    @Test func everyAuditionOfGeneratedLevelsIsExactPureAndDistinct() throws {
        let fixtures: [AcousticConstellatorFixture] = AcousticConstellatorFixtures.fixtures(6)
        #expect(!fixtures.isEmpty)
        var keys: [String] = []
        var auditions: [Audition] = []
        var gapsMet: Set<Int> = []
        var zeroGaps: Int = 0
        for fixture in fixtures {
            let play: Play = try Self.fresh(fixture.level)
            let snapshot: Snapshot = Self.snap(play)
            let later: Snapshot = Snapshot(play: play, levelNumber: 7, time: 12.75)
            let stars: [AcousticConstellatorStar] = snapshot.stars
            for a in stars.indices {
                for b in stars.indices where b > a {
                    let link: Link = Link(a: a, b: b)
                    for tick in 0..<snapshot.ticks {
                        let audition: Audition = Audition.of(snapshot, link: link, tick: tick)
                        let now: [Int] = snapshot.phases(at: tick)
                        let g: Int = Self.gap(now[a], now[b])
                        gapsMet.insert(g)
                        let first: Double = Self.hertz(stars[a].rate)
                        let second: Double = Self.hertz(stars[b].rate) + Double(g) * 1.5
                        #expect(audition.partials == [Partial(frequency: first, gain: 0.04),
                                                      Partial(frequency: second, gain: 0.04)])
                        if g == 0 {
                            zeroGaps += 1
                            #expect(audition.partials[1].frequency == Audition.tone(rate: stars[b].rate))
                        }
                        // Pure: equal inputs give equal auditions, at any presentation time.
                        #expect(audition == Audition.of(snapshot, link: link, tick: tick))
                        #expect(audition == Audition.of(later, link: link, tick: tick))
                        for partial in audition.partials {
                            #expect(partial.frequency >= 220 && partial.frequency <= Self.hertz(11) + 9 + 1e-9)
                            #expect(partial.gain == 0.04)
                        }
                        keys.append("\(stars[a].rate) \(stars[b].rate) \(g)")
                        auditions.append(audition)
                    }
                }
            }
        }
        #expect(zeroGaps > 0 && gapsMet.count > 2, "gaps met: \(gapsMet.sorted())")
        // Equal (rate a, rate b, gap) give equal auditions; different ones give different auditions.
        for first in auditions.indices {
            for second in auditions.indices where second > first {
                #expect((keys[first] == keys[second]) == (auditions[first] == auditions[second]),
                        "\(keys[first]) vs \(keys[second])")
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
        for budget in Level.budgets {
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

    @Test func theLitQuartersOfTheGauge() {
        let expected: [Int] = [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4]
        for bars in 0...12 { #expect(Recipe.quarters(bars: bars) == expected[bars], "\(bars) bars") }
        #expect(Recipe.quarters(bars: -5) == 0 && Recipe.quarters(bars: 40) == 4)
        #expect(Recipe.quarterPartials(quarters: 7) == 4 && Recipe.quarterPartials(quarters: -1) == 0)
    }

    @Test func theDocumentedPartials() {
        #expect(Recipe.rootHertz == 110)
        let stepRatios: [Double] = [1.0, 1.125, 1.25, 4.0 / 3.0]
        let quarterRatios: [Double] = [1.25, 1.5, 2.0, 2.5]
        #expect(Recipe.stepRatios == stepRatios)
        #expect(Recipe.quarterRatios == quarterRatios)
        // None lit at step 0: the root alone, 110 Hz over 16 s.
        let alone: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 0, stage: .playing)
        #expect(alone.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.6)])
        #expect(alone.gain == 0.2 && alone.swellCycles == 1 && alone.seconds == 16)
        // Three lit at step 0: root, 5/4, 3/2 and 2.
        let three: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 3, stage: .playing)
        #expect(three.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520])
        // Step 1 (9/8): 123.75 Hz, whole over 16 s only.
        let second: AmbientLoopRecipe = Recipe.recipe(rootStep: 1, quarters: 2, stage: .playing)
        #expect(second.seconds == 16 && second.partials.map(\.cyclesPerLoop) == [1_980, 2_475, 2_970])
        // Step 3 (4/3): 146.67 Hz, whole only in multiples of 3 s, so 15 s.
        let high: AmbientLoopRecipe = Recipe.recipe(rootStep: 3, quarters: 4, stage: .playing)
        #expect(high.seconds == 15 && high.partials.map(\.cyclesPerLoop) == [2_200, 2_750, 3_300, 4_400, 5_500])
        // Won with four lit: root, four partials and the octave, swelling twice.
        let won: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 4, stage: .won)
        #expect(won.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520, 4_400, 3_520])
        #expect(won.partials.count == 6 && won.swellCycles == 2 && won.gain == 0.2)
        // None lit when won: the root and its octave.
        #expect(Recipe.recipe(rootStep: 2, quarters: 0, stage: .won).partials.map(\.cyclesPerLoop) == [2_200, 4_400])
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
        let others: [AcousticConstellatorStage] = [.loading, .tutorial, .paused, .result]
        for stage in others { #expect(Recipe.recipe(rootStep: 2, quarters: 2, stage: stage) == playing) }
    }

    @Test func everyRecipeIsWithinTheLimitsWithWholeCycles() {
        for step in -1...5 {
            for quarters in -2...7 {
                for stage in AcousticConstellatorStage.allCases {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(rootStep: step, quarters: quarters, stage: stage)
                    let label: String = "step \(step) quarters \(quarters) \(stage)"
                    #expect(recipe.isValid, "\(label)")
                    #expect(AmbientLoopRecipe.partialCountRange.contains(recipe.partials.count), "\(label)")
                    #expect(recipe.partials.count <= 6)
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

    /// The lit quarters of `play` by an independent reading: the snapshot's coherence bars at the report's last tick,
    /// divided by 3.
    static func quarters(_ play: Play) -> Int {
        let snapshot: Snapshot = snap(play)
        return min(snapshot.coherenceBars(at: play.report.lastTick) / 3, 4)
    }

    /// The sound key of `play` by an independent reading: the root step, the lit quarters and the stage group (won,
    /// failed, or playing for every other stage).
    static func key(_ play: Play) -> String {
        let step: Int = expectedStep(left: play.actionsLeft, budget: play.level.budget)
        let group: String = play.stage == .won ? "won" : (play.stage == .failed ? "failed" : "playing")
        return "\(step) \(quarters(play)) \(group)"
    }

    /// Every prefix of `script` on a fresh play of `level` (refused actions skipped), its undo, its pause, and its
    /// result once ended.
    static func plays(_ level: Level, _ script: [Action]) throws -> [Play] {
        var plays: [Play] = []
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
        return plays
    }

    /// The kernel action of a fixture action tuple.
    static func action(_ tuple: (kind: String, a: Int, b: Int)) -> Action {
        switch tuple.kind {
        case "link": return .link(tuple.a, tuple.b)
        case "unlink": return .unlink(tuple.a, tuple.b)
        case "nudge": return .nudge(tuple.a, tuple.b)
        default: return .listen
        }
    }

    /// Real plays: the hand level with budgets 1 … 8 (scripts of nudges, the link and listens; an immediate failed
    /// listen) and generated levels along their winning actions, and along them with a listen first.
    static func realPlays() throws -> [Play] {
        let scripts: [[Action]] = [[.nudge(2, 1), .nudge(2, 1), .link(1, 2), .nudge(2, -1), .nudge(2, -1), .listen],
                                   [.listen]]
        var result: [Play] = []
        for budget in 1...8 {
            for script in scripts { result += try plays(handLevel(budget: budget), script) }
        }
        for fixture in AcousticConstellatorFixtures.fixtures(6) {
            var winning: [Action] = []
            for tuple in fixture.winningActions { winning.append(action(tuple)) }
            result += try plays(fixture.level, winning)
            result += try plays(fixture.level, [.listen] + winning)
        }
        return result
    }

    @Test func realPlaysSoundTheirStateEqualWhenEqualAndDifferentWhenDifferent() throws {
        let plays: [Play] = try Self.realPlays()
        var keys: [String] = []
        var recipes: [AmbientLoopRecipe] = []
        var steps: Set<Int> = []
        var stagesMet: Set<AcousticConstellatorStage> = []
        var quartersMet: Set<Int> = []
        for play in plays {
            let recipe: AmbientLoopRecipe = Recipe.recipe(play: play)
            let step: Int = Self.expectedStep(left: play.actionsLeft, budget: play.level.budget)
            let quarters: Int = Self.quarters(play)
            steps.insert(step)
            stagesMet.insert(play.stage)
            quartersMet.insert(quarters)
            #expect(Recipe.litQuarters(play) == quarters)
            #expect(recipe == Recipe.recipe(rootStep: step, quarters: quarters, stage: play.stage))
            #expect(recipe == Recipe.recipe(play: play))
            #expect(recipe.isValid && recipe.partials.count <= 6)
            keys.append(Self.key(play))
            recipes.append(recipe)
        }
        #expect(plays.count > 60)
        #expect(steps.count == 4, "root steps met: \(steps.sorted())")
        let wanted: [AcousticConstellatorStage] = [.playing, .paused, .won, .failed, .result]
        for stage in wanted { #expect(stagesMet.contains(stage), "\(stage) not met") }
        #expect(quartersMet.count >= 3, "lit quarters met: \(quartersMet.sorted())")
        // Equal states sound equal; different states sound different.
        for first in recipes.indices {
            for second in recipes.indices where second > first {
                #expect((keys[first] == keys[second]) == (recipes[first] == recipes[second]),
                        "\(keys[first]) vs \(keys[second])")
            }
        }
        // A win on the 5-action hand level: 3 of 5 actions left (more than 1/2, not more than 3/4), step 1; the gauge
        // full at the last tick of the winning listen, so four quarters, the octave and the two-cycle swell.
        var won: Play = try Self.fresh(AcousticConstellatorFixtures.handLevel())
        let winning: [Action] = [.link(1, 2), .listen]
        for action in winning { try won.apply(action, expecting: won.fingerprint) }
        #expect(won.stage == .won)
        let last: AmbientLoopRecipe = Recipe.recipe(play: won)
        #expect(Recipe.litQuarters(won) == 4 && Self.quarters(won) == 4)
        #expect(last.swellCycles == 2 && last.partials.count == 6)
        #expect(last.seconds == 16 && last.partials.first?.cyclesPerLoop == 1_980)
    }
}
