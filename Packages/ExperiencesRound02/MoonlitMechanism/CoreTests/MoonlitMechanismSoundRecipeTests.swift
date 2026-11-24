// MoonlitMechanismSoundRecipeTests — feature 436 (R02-G14-06) T-R02G1406-004 (FR-R02G1406-006; SC-R02G1406-004;
// clarification Q4). The audition: the tone 220 Hz × 2^((T − 12) / 12) per tooth count T, clamped to 55 … 880 Hz; over
// seeded fixture levels (`MoonlitMechanismFixture.all(count:seed:)`, seed 2_436) at their start, at their solution
// (every mesh aligned) and after a re-seat of every gear, for every gear: the driver's tone alone, a gear g ≥ 1 with
// its tone and its parent's raised by e × 1.5 Hz for the mesh error e = `report.errors[g]` against an independent
// error, each at gain 0.04; an aligned mesh gives no detune; silence for a gear the level lacks; 0.6 s; pure (equal for
// equal plays) and equal exactly when the (teeth, parent teeth, error) triples are equal, different otherwise; within
// its bounds. The ambient recipe: the root step at its boundaries (0 for more than 3/4 of the action budget left, 1 for
// more than 1/2, 2 for more than 1/4, else 3), checked against an independent fraction comparison for every budget the
// kernel allows; the covered quarters ⌊4c / t⌋ (0 … 4); pure (equal inputs give equal recipes); different for every
// change of the root step, of the covered quarters and of the stage among playing, won and failed; the documented
// partials (root 110 Hz × (1, 9/8, 5/4, 4/3)[step], a partial per covered quarter at the root × (5/4, 3/2, 2, 5/2)[k − 1],
// up to four, the root alone with none covered, the octave and a two-cycle swell when won, halved amplitudes and gain
// when failed); the loop length the longest in 4 … 16 s at which every partial has a whole number of cycles (16 s for
// steps 0 … 2, 15 s for step 3); a valid `AmbientLoopRecipe` within its limits for every input; and `recipe(play:)`
// over real kernel plays (fixture levels with their budgets and copies with budgets 1 … 12 along their known actions,
// and certified level 37 — turns, re-seats, lamp steps, runs, wins, failures, results, pauses and undos) equal to the
// recipe of the play's root step, covered quarters and stage, equal for equal states and different whenever those
// differ. Explicit types, plain loops, short runs, no clocks.
import Foundation
import Testing
@testable import MoonlitMechanismCore
import VisualCoreAudioDSP

@Suite struct MoonlitMechanismSoundRecipeTests {
    typealias Recipe = MoonlitMechanismSoundRecipe
    typealias Audition = MoonlitMechanismAudition
    typealias Partial = MoonlitMechanismPartial
    typealias Play = MoonlitMechanismPlay
    typealias Level = MoonlitMechanismLevel
    typealias Action = MoonlitMechanismAction
    /// The feature's fixture seed.
    static let seed: UInt64 = 2_436
    /// The stages whose sound differs.
    static let stages: [MoonlitMechanismStage] = [.playing, .won, .failed]

    /// The highest frequency any recipe sounds: the fourth quarter partial at step 3, 110 × 4/3 × 5/2 Hz (plus
    /// rounding).
    static let highestHertz: Double = 110.0 * 4.0 / 3.0 * 5.0 / 2.0 + 1e-9

    /// Whether `value` is a whole number (within a rounding tolerance far below one cycle).
    static func isWhole(_ value: Double) -> Bool { abs(value - value.rounded()) < 1e-6 }

    /// The tone of `teeth` teeth by the documented formula, unclamped.
    static func hertz(_ teeth: Int) -> Double { 220 * pow(2, Double(teeth - 12) / 12) }

    /// The mesh error of gear `child` at `phases` by an independent rule: the residue of the two phases against the
    /// alignment value modulo the mesh divisor, the shorter way round.
    static func meshError(_ gears: [MoonlitMechanismGear], _ phases: [Int], child: Int) -> Int {
        guard let parent = gears[child].parent else { return 0 }
        var a: Int = gears[parent].teeth
        var b: Int = gears[child].teeth
        while b > 0 { (a, b) = (b, a % b) }
        let divisor: Int = a
        var residue: Int = (phases[parent] + phases[child] - gears[child].alignment) % divisor
        if residue < 0 { residue += divisor }
        return residue <= divisor - residue ? residue : divisor - residue
    }

    /// A fresh play of `level` in stage `playing`.
    static func fresh(_ level: Level) throws -> Play {
        var play: Play = Play(level: level)
        try play.handle(.begin)
        if level.tutorial { try play.handle(.dismissTutorial) }
        return play
    }

    /// A copy of `level` with action budget `budget` (every other field kept).
    static func withBudget(_ level: Level, _ budget: Int) throws -> Level {
        try Level(id: level.id, seed: level.seed, difficulty: level.difficulty, gears: level.gears, width: level.width,
                  rows: level.rows, lampHeights: level.lampHeights, startingHeight: level.startingHeight,
                  keyFrames: level.keyFrames, forbidden: level.forbidden, allowance: level.allowance, budget: budget,
                  tutorial: level.tutorial)
    }

    /// The seeded fixtures of the feature.
    static func fixtures() -> [MoonlitMechanismFixture] { MoonlitMechanismFixture.all(count: 8, seed: seed) }

    // MARK: - Audition

    @Test func theTonesAndTheirClamp() {
        #expect(Audition.duration == 0.6)
        #expect(Audition.tone(teeth: 12) == 220 && Audition.tone(teeth: 24) == 440 && Audition.tone(teeth: 0) == 110)
        #expect(Audition.tone(teeth: -12) == 55 && Audition.tone(teeth: 36) == 880)
        #expect(Audition.tone(teeth: -40) == 55 && Audition.tone(teeth: 90) == 880)
        #expect(abs(Audition.tone(teeth: 6) - 155.563_492) < 1e-5)
        #expect(abs(Audition.tone(teeth: 20) - 349.228_231) < 1e-5)
        // Fewer teeth, lower; every count the kernel allows sounds unclamped.
        var previous: Double = 0
        for teeth in Level.toothCounts {
            let tone: Double = Audition.tone(teeth: teeth)
            #expect(tone > previous && abs(tone - Self.hertz(teeth)) < 1e-9, "\(teeth) teeth")
            previous = tone
        }
    }

    /// Every play an audition is taken of for `fixture`: its start, its solution set-up (the known actions without the
    /// run) and the start with each gear but the driver re-seated one tooth forward.
    static func auditionPlays(_ fixture: MoonlitMechanismFixture) throws -> [Play] {
        let start: Play = try fresh(try withBudget(fixture.level, 40))
        var result: [Play] = [start]
        var solved: Play = start
        for action in fixture.actions where action != .run {
            try solved.apply(action, expecting: solved.fingerprint)
        }
        result.append(solved)
        for gear in 1..<fixture.level.gears.count {
            var reseated: Play = start
            try reseated.apply(.reseat(gear, 1), expecting: reseated.fingerprint)
            result.append(reseated)
        }
        return result
    }

    @Test func everyAuditionIsExactPureAndDistinct() throws {
        let fixtures: [MoonlitMechanismFixture] = Self.fixtures()
        #expect(fixtures.count == 8)
        var keys: [String] = []
        var auditions: [Audition] = []
        var errorsMet: Set<Int> = []
        var aligned: Int = 0
        for fixture in fixtures {
            let gears: [MoonlitMechanismGear] = fixture.level.gears
            for play in try Self.auditionPlays(fixture) {
                // The report's errors are indexed by the child gear of each mesh; the driver's entry is 0.
                #expect(play.report.errors.count == gears.count && play.report.errors[0] == 0)
                for gear in gears.indices {
                    let audition: Audition = Audition.of(play, gear: gear)
                    let own: Partial = Partial(frequency: Self.hertz(gears[gear].teeth), gain: 0.04)
                    var key: String = "\(gears[gear].teeth)"
                    if let parent = gears[gear].parent {
                        let e: Int = Self.meshError(gears, play.phases, child: gear)
                        #expect(play.report.errors[gear] == e)
                        errorsMet.insert(e)
                        let second: Partial = Partial(frequency: Self.hertz(gears[parent].teeth) + Double(e) * 1.5,
                                                      gain: 0.04)
                        #expect(audition.partials == [own, second], "gear \(gear)")
                        if e == 0 {
                            aligned += 1
                            #expect(audition.partials[1].frequency == Audition.tone(teeth: gears[parent].teeth))
                        }
                        key += " \(gears[parent].teeth) \(e)"
                    } else {
                        // The driver sounds alone.
                        #expect(audition.partials == [own])
                        key += " driver"
                    }
                    // Pure: equal inputs give equal auditions.
                    #expect(audition == Audition.of(play, gear: gear))
                    for partial in audition.partials {
                        #expect(partial.frequency >= 55 && partial.frequency <= Self.hertz(20) + 15 + 1e-9)
                        #expect(partial.gain == 0.04)
                    }
                    keys.append(key)
                    auditions.append(audition)
                }
                // A gear the level lacks is silent.
                #expect(Audition.of(play, gear: gears.count).partials.isEmpty)
                #expect(Audition.of(play, gear: -1).partials.isEmpty)
            }
        }
        #expect(aligned > 0 && errorsMet.count > 2, "errors met: \(errorsMet.sorted())")
        // Equal (teeth, parent teeth, error) give equal auditions; different ones give different auditions.
        for first in auditions.indices {
            for second in auditions.indices where second > first {
                #expect((keys[first] == keys[second]) == (auditions[first] == auditions[second]),
                        "\(keys[first]) vs \(keys[second])")
            }
        }
    }

    @Test func anAlignedSolutionIsACleanChordAtEveryMesh() throws {
        for fixture in Self.fixtures() {
            var solved: Play = try Self.fresh(try Self.withBudget(fixture.level, 40))
            for action in fixture.actions where action != .run {
                try solved.apply(action, expecting: solved.fingerprint)
            }
            #expect(solved.report.aligned)
            let gears: [MoonlitMechanismGear] = fixture.level.gears
            for gear in 1..<gears.count {
                let parent: Int = try #require(gears[gear].parent)
                #expect(Audition.of(solved, gear: gear).partials[1].frequency
                        == Audition.tone(teeth: gears[parent].teeth))
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

    /// The covered quarters by an independent rule: the largest k in 0 … 4 with k / 4 ≤ covered / targets.
    static func expectedQuarters(covered: Int, targets: Int) -> Int {
        guard targets > 0 else { return 0 }
        var best: Int = 0
        for k in 0...4 where k * targets <= 4 * covered { best = k }
        return best
    }

    @Test func theCoveredQuarters() {
        // 12 target cells: 0 … 2 covered none, 3 … 5 one quarter, … 12 all four.
        let twelve: [Int] = [0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4]
        for covered in 0...12 {
            #expect(Recipe.quarters(covered: covered, targets: 12) == twelve[covered], "\(covered) of 12")
        }
        for targets in 1...30 {
            for covered in 0...targets {
                #expect(Recipe.quarters(covered: covered, targets: targets)
                        == Self.expectedQuarters(covered: covered, targets: targets), "\(covered) of \(targets)")
            }
        }
        #expect(Recipe.quarters(covered: 3, targets: 0) == 0 && Recipe.quarters(covered: -2, targets: 5) == 0)
        #expect(Recipe.quarters(covered: 9, targets: 5) == 4)
        #expect(Recipe.quarterPartials(quarters: 7) == 4 && Recipe.quarterPartials(quarters: -1) == 0)
    }

    @Test func theDocumentedPartials() {
        #expect(Recipe.rootHertz == 110)
        let stepRatios: [Double] = [1.0, 1.125, 1.25, 4.0 / 3.0]
        let quarterRatios: [Double] = [1.25, 1.5, 2.0, 2.5]
        #expect(Recipe.stepRatios == stepRatios)
        #expect(Recipe.quarterRatios == quarterRatios)
        // None covered at step 0: the root alone, 110 Hz over 16 s.
        let alone: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 0, stage: .playing)
        #expect(alone.partials == [AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: 0.6)])
        #expect(alone.gain == 0.2 && alone.swellCycles == 1 && alone.seconds == 16)
        // Three covered at step 0: root, 5/4, 3/2 and 2.
        let three: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 3, stage: .playing)
        #expect(three.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520])
        // Step 1 (9/8): 123.75 Hz, whole over 16 s only.
        let second: AmbientLoopRecipe = Recipe.recipe(rootStep: 1, quarters: 2, stage: .playing)
        #expect(second.seconds == 16 && second.partials.map(\.cyclesPerLoop) == [1_980, 2_475, 2_970])
        // Step 3 (4/3): 146.67 Hz, whole only in multiples of 3 s, so 15 s.
        let high: AmbientLoopRecipe = Recipe.recipe(rootStep: 3, quarters: 4, stage: .playing)
        #expect(high.seconds == 15 && high.partials.map(\.cyclesPerLoop) == [2_200, 2_750, 3_300, 4_400, 5_500])
        // Won with four covered: root, four partials and the octave, swelling twice.
        let won: AmbientLoopRecipe = Recipe.recipe(rootStep: 0, quarters: 4, stage: .won)
        #expect(won.partials.map(\.cyclesPerLoop) == [1_760, 2_200, 2_640, 3_520, 4_400, 3_520])
        #expect(won.partials.count == 6 && won.swellCycles == 2 && won.gain == 0.2)
        // None covered when won: the root and its octave.
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
        let others: [MoonlitMechanismStage] = [.loading, .tutorial, .paused, .result]
        for stage in others { #expect(Recipe.recipe(rootStep: 2, quarters: 2, stage: stage) == playing) }
    }

    @Test func everyRecipeIsWithinTheLimitsWithWholeCycles() {
        for step in -1...5 {
            for quarters in -2...7 {
                for stage in MoonlitMechanismStage.allCases {
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

    /// The covered quarters of `play` by an independent reading: the covered target cells of every required key frame
    /// recounted from its cast cells, against all their target cells.
    static func quarters(_ play: Play) -> Int {
        var covered: Int = 0
        var targets: Int = 0
        for (index, frame) in play.level.keyFrames.enumerated() where frame.required {
            let cast: Set<Int> = Set(play.report.frames[index].cast)
            targets += frame.target.count
            for cell in frame.target where cast.contains(cell) { covered += 1 }
        }
        return expectedQuarters(covered: covered, targets: targets)
    }

    /// The sound key of `play` by an independent reading: the root step, the covered quarters and the stage group
    /// (won, failed, or playing for every other stage).
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

    /// Real plays: the fixture levels with their own budgets and with budgets 1 … 12, along their known actions and
    /// along them with a run first; certified level 37 along its winning actions, with a lamp step and a turn there and
    /// back first.
    static func realPlays() throws -> [Play] {
        var result: [Play] = []
        for fixture in fixtures() {
            result += try plays(fixture.level, fixture.actions)
            result += try plays(fixture.level, [.run] + fixture.actions)
            for budget in 1...12 { result += try plays(try withBudget(fixture.level, budget), fixture.actions) }
        }
        let certified: MoonlitMechanismGenerated = try MoonlitMechanismExperienceCore.generated(number: 37)
        let detour: [Action] = [.turn(1), .turn(-1)]
        result += try plays(try withBudget(certified.level, 40), detour + certified.actions)
        result += try plays(certified.level, certified.actions)
        return result
    }

    @Test func realPlaysSoundTheirStateEqualWhenEqualAndDifferentWhenDifferent() throws {
        let plays: [Play] = try Self.realPlays()
        var keys: [String] = []
        var recipes: [AmbientLoopRecipe] = []
        var steps: Set<Int> = []
        var stagesMet: Set<MoonlitMechanismStage> = []
        var quartersMet: Set<Int> = []
        for play in plays {
            let recipe: AmbientLoopRecipe = Recipe.recipe(play: play)
            let step: Int = Self.expectedStep(left: play.actionsLeft, budget: play.level.budget)
            let quarters: Int = Self.quarters(play)
            steps.insert(step)
            stagesMet.insert(play.stage)
            quartersMet.insert(quarters)
            #expect(Recipe.coveredQuarters(play) == quarters)
            #expect(recipe == Recipe.recipe(rootStep: step, quarters: quarters, stage: play.stage))
            #expect(recipe == Recipe.recipe(play: play))
            #expect(recipe.isValid && recipe.partials.count <= 6)
            keys.append(Self.key(play))
            recipes.append(recipe)
        }
        #expect(plays.count > 60)
        #expect(steps.count == 4, "root steps met: \(steps.sorted())")
        let wanted: [MoonlitMechanismStage] = [.playing, .paused, .won, .failed, .result]
        for stage in wanted { #expect(stagesMet.contains(stage), "\(stage) not met") }
        #expect(quartersMet.count >= 3, "covered quarters met: \(quartersMet.sorted())")
        // Equal states sound equal (one recipe per key); different states sound different (the recipes of distinct
        // keys differ pairwise).
        var byKey: [String: AmbientLoopRecipe] = [:]
        for index in recipes.indices {
            if let known = byKey[keys[index]] {
                #expect(known == recipes[index], "\(keys[index])")
            } else {
                byKey[keys[index]] = recipes[index]
            }
        }
        let distinct: [String] = byKey.keys.sorted()
        for first in distinct.indices {
            for second in distinct.indices where second > first {
                #expect(byKey[distinct[first]] != byKey[distinct[second]], "\(distinct[first]) vs \(distinct[second])")
            }
        }
        #expect(distinct.count >= 12, "sound keys met: \(distinct.count)")
        // A won fixture covers every required target cell: four quarters, the octave and the two-cycle swell.
        let fixture: MoonlitMechanismFixture = try #require(Self.fixtures().first)
        var won: Play = try Self.fresh(fixture.level)
        for action in fixture.actions { try won.apply(action, expecting: won.fingerprint) }
        #expect(won.stage == .won)
        let last: AmbientLoopRecipe = Recipe.recipe(play: won)
        #expect(Recipe.coveredQuarters(won) == 4 && Self.quarters(won) == 4)
        #expect(last.swellCycles == 2 && last.partials.count == 6)
    }
}
