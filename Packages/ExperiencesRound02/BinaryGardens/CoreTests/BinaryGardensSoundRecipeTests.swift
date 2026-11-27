// BinaryGardensSoundRecipeTests — feature 506 (R02-G21-06) T-R02G2106-004 (FR-R02G2106-006; SC-R02G2106-004;
// clarification Q4; research R6, R7). The audition: the ring step n = 2 × (7 − the ring index) for every index 0 … 7,
// clamped outside; the tone 220 Hz × 2^(n / 12), a whole tone per ring, an outer ring lower, every ring a distinct tone;
// over every ring and both answers of "can change": a star that can change sounds its tone and its fifth (ratio 3/2),
// a consonant interval; one that cannot sounds its tone and a partial 3 Hz above, a 3 Hz beat; each at gain 0.04;
// 0.6 s; pure (equal inputs equal) and different whenever (n, can change) differs — the 16 distinct auditions;
// `canChange(star:play:)` true exactly when the play is playing and the puzzle's legal moves hold a ring, phase or
// luminosity move of the star, over real plays (the opening, every plan step, the failed run, the won run, a spent
// budget). The ambient recipe: the root step at its boundaries, checked against an independent fraction comparison for
// every budget the kernel allows (1 … 24); the light quarters ⌊4w / n⌋ of w worlds keeping their light of n, recomputed
// independently over real plays; the brightness (i₁ + i₂) / (2 (m − 1)); pure; different for every change of the root
// step, the quarters, the brightness and the stage among playing, won and failed; the documented partials (root
// 110 Hz × (1, 9/8, 5/4, 4/3), a partial per quarter at the root × (5/4, 3/2, 2, 5/2), the brightness partial at the
// root × 3 with the base amplitude × b, the octave merged when won, halved amplitudes and gain when failed); the loop the
// longest of 4 … 16 s with whole cycles; every recipe over the whole input domain — a superset of every recipe the 100
// levels can reach (root steps 0 … 3, quarters 0 … 4, every brightness of 1 … 4 luminosity levels, every stage) — a
// valid `AmbientLoopRecipe` within the shared player's limits; and `recipe(play:)` over real plays of the seed level
// (2_506 → level 7) equal to the recipe of its keys. Explicit types, plain loops, short runs, no clocks. Modelled on
// MushroomWeatherSoundRecipeTests (feature 496).
import Foundation
import Testing
import VisualCoreAudioDSP
@testable import BinaryGardensCore

@Suite struct BinaryGardensSoundRecipeTests {
    typealias Recipe = BinaryGardensSoundRecipe
    typealias Audition = BinaryGardensAudition
    typealias Play = BinaryGardensPlay
    typealias Core = BinaryGardensExperienceCore
    /// The feature's fixture seed.
    static let seed: UInt64 = 2_506
    /// The level the seed opens (7).
    static let number: Int = Core.levelNumber(forSeed: seed)
    /// The stages whose sound differs.
    static let stages: [BinaryGardensStage] = [.playing, .won, .failed]

    /// Whether `value` is a whole number (within a rounding tolerance far below one cycle).
    static func isWhole(_ value: Double) -> Bool { abs(value - value.rounded()) < 1e-6 }

    /// The tone of ring step `step` by the documented formula.
    static func hertz(step: Int) -> Double { 220 * pow(2, Double(step) / 12) }

    /// Every brightness a level of 1 … 4 luminosity levels can reach: (i₁ + i₂) / (2 (m − 1)), i₁, i₂ in 0 … m − 1.
    static func reachableBrightness() -> [Double] {
        var values: [Double] = [0]
        for levels in 2...BinaryGardensLevel.luminosityCounts.upperBound {
            for sum in 0...(2 * (levels - 1)) {
                let value: Double = Double(sum) / Double(2 * (levels - 1))
                if !values.contains(value) { values.append(value) }
            }
        }
        return values
    }

    /// Checks that `recipe` is valid and within the shared player's limits, with whole cycles for `frequencies`.
    static func expectValid(_ recipe: AmbientLoopRecipe, frequencies: [Double], _ label: String) {
        #expect(recipe.isValid, "\(label)")
        #expect(AmbientLoopRecipe.secondsRange.contains(recipe.seconds), "\(label)")
        #expect(AmbientLoopRecipe.partialCountRange.contains(recipe.partials.count), "\(label)")
        #expect(AmbientLoopRecipe.gainRange.contains(recipe.gain) && recipe.gain <= 0.2, "\(label)")
        #expect(recipe.partials.count == frequencies.count, "\(label)")
        for (index, partial) in recipe.partials.enumerated() where index < frequencies.count {
            let cycles: Double = frequencies[index] * Double(recipe.seconds)
            #expect(Self.isWhole(cycles) && Int(cycles.rounded()) == partial.cyclesPerLoop, "\(label) partial \(index)")
            #expect(partial.amplitude > 0 && partial.amplitude <= 1, "\(label) partial \(index)")
        }
    }

    @Test func theRingStepsAndTheirTones() {
        #expect(Audition.duration == 0.6 && Audition.toneGain == 0.04 && Audition.maxRingIndex == 7)
        #expect(Audition.step(ring: 0) == 14 && Audition.step(ring: 7) == 0)
        #expect(Audition.tone(ring: 7) == 220)
        #expect(abs(Audition.tone(ring: 0) - 493.883_301_256_124_1) < 1e-9)
        var tones: [Double] = []
        for ring in 0...7 {
            let step: Int = Audition.step(ring: ring)
            #expect(step == 2 * (7 - ring), "ring \(ring)")
            let tone: Double = Audition.tone(ring: ring)
            #expect(abs(tone - Self.hertz(step: step)) < 1e-9, "ring \(ring)")
            // A whole tone below the previous (inner) ring; every tone distinct.
            if let previous = tones.last {
                #expect(abs(previous / tone - pow(2, 2.0 / 12)) < 1e-12, "ring \(ring)")
                #expect(tone < previous)
            }
            for earlier in tones { #expect(tone != earlier, "ring \(ring)") }
            tones.append(tone)
        }
        #expect(Audition.step(ring: -1) == 14 && Audition.step(ring: -9) == 14)
        #expect(Audition.step(ring: 8) == 0 && Audition.step(ring: 40) == 0)
        #expect(Audition.tone(ring: 12) == Audition.tone(ring: 7))
    }

    @Test func aStarThatCanChangeIsAConsonantFifthAndOneThatCannotBeats() {
        var auditions: [Audition] = []
        for ring in 0...7 {
            for canChange in [true, false] {
                let audition: Audition = Audition.of(ring: ring, canChange: canChange)
                #expect(audition == Audition.of(ring: ring, canChange: canChange), "pure")
                #expect(audition.partials.count == 2)
                let tone: Double = Audition.tone(ring: ring)
                #expect(audition.partials[0].frequency == tone)
                for partial in audition.partials { #expect(partial.gain == 0.04) }
                if canChange {
                    #expect(abs(audition.partials[1].frequency / tone - 1.5) < 1e-12, "a clean fifth, ring \(ring)")
                } else {
                    #expect(abs(audition.partials[1].frequency - tone - 3) < 1e-9, "a 3 Hz beat, ring \(ring)")
                }
                for earlier in auditions { #expect(audition != earlier, "ring \(ring), \(canChange)") }
                auditions.append(audition)
            }
        }
        #expect(auditions.count == 16)
        // Clamped rings sound like their clamp.
        #expect(Audition.of(ring: -3, canChange: true) == Audition.of(ring: 0, canChange: true))
    }

    /// Whether star `star` can change in `play`, decided here independently: playing, an action left, and some ring,
    /// phase or luminosity value of the star the kernel accepts.
    static func independentCanChange(_ star: Int, _ play: Play) -> Bool {
        guard play.stage == .playing, play.actionsLeft > 0 else { return false }
        let level: BinaryGardensLevel = play.level
        var candidates: [BinaryGardensAction] = []
        for index in level.ringRadii.indices { candidates.append(.ring(star: star, index: index)) }
        for step in stride(from: 0, to: 48, by: level.phaseStep) { candidates.append(.phase(star: star, step: step)) }
        for index in level.luminosityLevels.indices { candidates.append(.luminosity(star: star, index: index)) }
        for action in candidates {
            var copy: Play = play
            if (try? copy.apply(action, expecting: copy.fingerprint)) != nil { return true }
        }
        return false
    }

    @Test func canChangeFollowsTheLegalMovesOverRealPlays() throws {
        let level: BinaryGardensLevel = try Core.level(number: Self.number)
        let plan: [BinaryGardensAction] = try Core.generated(number: Self.number).plan.actions.filter { $0 != .run }
        var play: Play = try Core.freshPlay(of: level)
        var plays: [Play] = [play]
        for action in plan {
            try play.apply(action, expecting: play.fingerprint)
            plays.append(play)
        }
        var won: Play = play
        try won.apply(.run, expecting: won.fingerprint)
        #expect(won.stage == .won)
        var failed: Play = try Core.freshPlay(of: level)
        try failed.apply(.run, expecting: failed.fingerprint)
        #expect(failed.stage == .failed)
        var anyTrue: Bool = false
        for (index, candidate) in plays.enumerated() {
            for star in 0...1 {
                let expected: Bool = Self.independentCanChange(star, candidate)
                #expect(Audition.canChange(star: star, play: candidate) == expected, "play \(index), star \(star)")
                if expected { anyTrue = true }
            }
        }
        #expect(anyTrue)
        for star in 0...1 {
            #expect(!Audition.canChange(star: star, play: won) && !Audition.canChange(star: star, play: failed))
        }
        #expect(!Audition.canChange(star: 2, play: plays[0]) && !Audition.canChange(star: -1, play: plays[0]))
        // A star whose ring, phase and luminosity are all locked never changes.
        for (star, rules) in level.stars.enumerated()
        where !rules.ringAdjustable && !rules.phaseAdjustable && !rules.luminosityAdjustable {
            #expect(!Audition.canChange(star: star, play: plays[0]))
        }
        // A spent budget leaves nothing to change: drain it with a value moved back and forth.
        var drained: Play = try Core.freshPlay(of: level)
        let puzzle: BinaryGardensPuzzle = BinaryGardensPuzzle(level: level)
        while drained.actionsLeft > 0 {
            let position: BinaryGardensPuzzle.Position = BinaryGardensPuzzle.Position(
                arrangement: drained.arrangement, actionsSpent: drained.actionsSpent)
            guard let move = puzzle.moves(in: position).first else { break }
            try drained.apply(move, expecting: drained.fingerprint)
        }
        #expect(drained.actionsLeft == 0)
        for star in 0...1 { #expect(!Audition.canChange(star: star, play: drained)) }
    }

    @Test func theRootStepFollowsTheActionsLeftInIntegers() {
        for budget in BinaryGardensLevel.budgets {
            for left in 0...budget {
                // Independently: the share left as an exact fraction against 3/4, 1/2 and 1/4.
                let share: (Int, Int) = (left, budget)
                let expected: Int
                if share.0 * 4 > share.1 * 3 {
                    expected = 0
                } else if share.0 * 2 > share.1 {
                    expected = 1
                } else if share.0 * 4 > share.1 {
                    expected = 2
                } else {
                    expected = 3
                }
                #expect(Recipe.rootStep(actionsLeft: left, budget: budget) == expected, "\(left) of \(budget)")
            }
        }
        #expect(Recipe.rootStep(actionsLeft: 4, budget: 4) == 0)
        #expect(Recipe.rootStep(actionsLeft: 3, budget: 4) == 1)
        #expect(Recipe.rootStep(actionsLeft: 2, budget: 4) == 2)
        #expect(Recipe.rootStep(actionsLeft: 1, budget: 4) == 3)
        #expect(Recipe.rootStep(actionsLeft: 0, budget: 0) == 3)
    }

    @Test func theDocumentedPartialsAndWholeCyclesOverTheWholeDomain() {
        let brightness: [Double] = Self.reachableBrightness()
        var recipes: Set<AmbientLoopRecipe> = []
        var count: Int = 0
        for step in Recipe.rootSteps {
            let root: Double = 110 * [1.0, 9.0 / 8, 5.0 / 4, 4.0 / 3][step]
            for quarters in 0...4 {
                for b in brightness {
                    for stage in Self.stages {
                        let recipe: AmbientLoopRecipe = Recipe.recipe(rootStep: step, quarters: quarters,
                                                                      brightness: b, stage: stage)
                        #expect(recipe == Recipe.recipe(rootStep: step, quarters: quarters, brightness: b,
                                                        stage: stage), "pure")
                        // The documented frequencies, in order, the octave merged.
                        var expected: [Double] = [root]
                        let ratios: [Double] = [1.25, 1.5, 2, 2.5]
                        for q in 0..<quarters { expected.append(root * ratios[q]) }
                        if b > 0 { expected.append(root * 3) }
                        if stage == .won && quarters < 3 { expected.append(root * 2) }
                        let frequencies: [Double] = Recipe.frequencies(rootStep: step, quarters: quarters,
                                                                       brightness: b, stage: stage)
                        #expect(frequencies.count == expected.count)
                        for (index, value) in frequencies.enumerated() where index < expected.count {
                            #expect(abs(value - expected[index]) < 1e-9)
                        }
                        let label: String = "step \(step), q \(quarters), b \(b), \(stage)"
                        Self.expectValid(recipe, frequencies: frequencies, label)
                        #expect(recipe.seconds == (step == 3 ? 15 : 16), "\(label)")
                        // Amplitudes: base, the brightness partial × b, halved when failed, the merged octave capped.
                        let scale: Double = stage == .failed ? 0.5 : 1
                        #expect(recipe.partials[0].amplitude == 0.6 * scale)
                        if b > 0 {
                            #expect(abs(recipe.partials[1 + quarters].amplitude - 0.6 * scale * b) < 1e-12)
                        }
                        if stage == .won && quarters >= 3 { #expect(recipe.partials[3].amplitude == 1) }
                        #expect(recipe.gain == 0.2 * scale)
                        #expect(recipe.swellCycles == (stage == .won ? 2 : 1))
                        recipes.insert(recipe)
                        count += 1
                    }
                }
            }
        }
        // Different inputs give different recipes.
        #expect(recipes.count == count)
        // Clamping: outside the domain the recipe equals its clamp.
        #expect(Recipe.recipe(rootStep: 9, quarters: 9, brightness: 7, stage: .playing)
                    == Recipe.recipe(rootStep: 3, quarters: 4, brightness: 1, stage: .playing))
        #expect(Recipe.recipe(rootStep: -2, quarters: -1, brightness: .nan, stage: .playing)
                    == Recipe.recipe(rootStep: 0, quarters: 0, brightness: 0, stage: .playing))
        // Every other stage sounds as playing.
        for stage in [BinaryGardensStage.loading, .tutorial, .paused, .result] {
            #expect(Recipe.recipe(rootStep: 1, quarters: 2, brightness: 0.5, stage: stage)
                        == Recipe.recipe(rootStep: 1, quarters: 2, brightness: 0.5, stage: .playing))
        }
    }

    /// Whether world `world` keeps its light in `play`, decided here independently from the level's bounds and the
    /// kernel's report recomputed with `BinaryGardensSky.report(level, arrangement:)`.
    static func independentKeeps(_ world: Int, _ play: Play) -> Bool {
        let report: BinaryGardensReport = BinaryGardensSky.report(play.level, arrangement: play.arrangement)
        let light: BinaryGardensWorldLight = report.worlds[world]
        let bounds: BinaryGardensWorld = play.level.worlds[world]
        let insideBloom: Bool = light.integral >= bounds.bloomLow && light.integral <= bounds.bloomHigh
        return light.longestLethalRun <= play.level.lethalTolerance && light.window >= bounds.window && insideBloom
    }

    @Test func theRecipeOfRealPlaysFollowsItsKeys() throws {
        let level: BinaryGardensLevel = try Core.level(number: Self.number)
        let plan: [BinaryGardensAction] = try Core.generated(number: Self.number).plan.actions.filter { $0 != .run }
        var plays: [Play] = []
        var play: Play = try Core.freshPlay(of: level)
        plays.append(play)
        for action in plan {
            try play.apply(action, expecting: play.fingerprint)
            plays.append(play)
        }
        var won: Play = play
        try won.apply(.run, expecting: won.fingerprint)
        plays.append(won)
        var wonResult: Play = won
        try wonResult.handle(.showResult)
        plays.append(wonResult)
        var failed: Play = try Core.freshPlay(of: level)
        try failed.apply(.run, expecting: failed.fingerprint)
        plays.append(failed)
        var undone: Play = failed
        try undone.undo()
        plays.append(undone)
        var paused: Play = try Core.freshPlay(of: level)
        try paused.handle(.pause)
        plays.append(paused)
        var keys: [String] = []
        var recipes: [AmbientLoopRecipe] = []
        for (index, candidate) in plays.enumerated() {
            var keeping: Int = 0
            for world in level.worlds.indices where Self.independentKeeps(world, candidate) { keeping += 1 }
            let quarters: Int = min(4, 4 * keeping / level.worlds.count)
            #expect(Recipe.lightQuarters(candidate) == quarters, "play \(index)")
            let m: Int = level.luminosityLevels.count
            let sum: Int = candidate.arrangement.luminosities.reduce(0, +)
            let b: Double = m > 1 ? Double(sum) / Double(2 * (m - 1)) : 0
            #expect(Recipe.brightness(candidate) == b, "play \(index)")
            let step: Int = Recipe.rootStep(actionsLeft: candidate.actionsLeft, budget: level.budget)
            let recipe: AmbientLoopRecipe = Recipe.recipe(play: candidate)
            #expect(recipe == Recipe.recipe(rootStep: step, quarters: quarters, brightness: b,
                                            stage: candidate.stage), "play \(index)")
            #expect(Recipe.loopSeconds(play: candidate) == recipe.seconds)
            Self.expectValid(recipe, frequencies: Recipe.frequencies(rootStep: step, quarters: quarters,
                                                                     brightness: b, stage: candidate.stage),
                             "play \(index)")
            let soundStage: String = candidate.stage == .won || candidate.stage == .failed
                ? candidate.stage.rawValue : "playing"
            let key: String = "\(step) \(quarters) \(b) \(soundStage)"
            for (other, earlier) in keys.enumerated() {
                #expect((key == earlier) == (recipe == recipes[other]), "play \(index) against \(other)")
            }
            keys.append(key)
            recipes.append(recipe)
        }
        // A won play has every world keeping its light.
        #expect(Recipe.lightQuarters(won) == 4)
        #expect(recipes[plays.count - 3] != recipes[plays.count - 2], "a failed run halves the sound")
    }
}
