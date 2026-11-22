// ChronoConstellatorSoundRecipeTests — feature 356 (R02-G06-06) T-R02G0606-005 (FR-R02G0606-006; SC-R02G0606-004;
// clarification Q4). The ambient recipe: equal for equal stars on target and stage; different for every change of the
// stars on target and for each stage change among playing, won and failed; the documented partials (root 110 Hz, a
// partial per star on target at 110 × (3/2, 5/4, 2, 5/3, 9/8)[star], the root alone with no star on target, a 220 Hz
// octave when won — the root raised to it when 6 partials already sound — halved amplitudes and gain when failed, 12
// s); a valid `AmbientLoopRecipe` of at most 6 partials for every certified level's start (tick 0) and solution (the
// win tick, the certified actions replayed through the adapter) in every stage, the 100 levels generated concurrently
// into the adapter's per-process cache. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import ChronoConstellatorCore
import VisualCoreAudioDSP
import VisualCoreExperience

/// Generates the levels `numbers` concurrently into the adapter's per-process cache.
private func soundPrewarm(_ numbers: [Int]) async {
    await withTaskGroup(of: Void.self) { (group: inout TaskGroup<Void>) in
        for number in numbers {
            group.addTask { _ = try? ChronoConstellatorExperienceCore.generated(number: number) }
        }
    }
}

@Suite struct ChronoConstellatorSoundRecipeTests {
    typealias Recipe = ChronoConstellatorSoundRecipe

    /// Every on-target pattern of 5 stars (32), bit k set: star k on its target.
    static func patterns() -> [[Bool]] {
        var result: [[Bool]] = []
        for mask in 0..<32 {
            var pattern: [Bool] = []
            for star in 0..<5 { pattern.append(mask & (1 << star) != 0) }
            result.append(pattern)
        }
        return result
    }

    @Test func equalInputsGiveEqualRecipes() {
        for stage in ChronoConstellatorStage.allCases {
            for pattern in Self.patterns() {
                var copy: [Bool] = []
                for value in pattern { copy.append(value) }
                #expect(Recipe.recipe(onTarget: pattern, stage: stage) == Recipe.recipe(onTarget: copy, stage: stage))
            }
            #expect(Recipe.recipe(onTarget: [], stage: stage) == Recipe.recipe(onTarget: [], stage: stage))
            // Stars beyond the fifth are not heard.
            let six: [Bool] = [true, false, true, false, true, true]
            #expect(Recipe.recipe(onTarget: six, stage: stage)
                    == Recipe.recipe(onTarget: [true, false, true, false, true], stage: stage))
        }
    }

    @Test func aChangeOfTheStarsOnTargetChangesTheRecipe() {
        for stage in ChronoConstellatorStage.allCases {
            var seen: [AmbientLoopRecipe] = []
            for pattern in Self.patterns() {
                let recipe: AmbientLoopRecipe = Recipe.recipe(onTarget: pattern, stage: stage)
                #expect(!seen.contains(recipe), "\(pattern) \(stage)")
                seen.append(recipe)
            }
        }
    }

    @Test func eachStageChangeChangesTheRecipe() {
        for pattern in Self.patterns() {
            let playing: AmbientLoopRecipe = Recipe.recipe(onTarget: pattern, stage: .playing)
            let won: AmbientLoopRecipe = Recipe.recipe(onTarget: pattern, stage: .won)
            let failed: AmbientLoopRecipe = Recipe.recipe(onTarget: pattern, stage: .failed)
            #expect(playing != won && playing != failed && won != failed, "\(pattern)")
        }
    }

    @Test func thePartialsFollowTheStars() {
        let base: Double = Recipe.baseAmplitude
        #expect(Recipe.rootCycles == 1_320 && Recipe.octaveCycles == 2_640)
        #expect(Recipe.starCycles == [1_980, 1_650, 2_640, 2_200, 1_485])
        // Every partial has a whole number of cycles at its documented frequency.
        let hertz: [Double] = [165, 137.5, 220, 110.0 * 5 / 3, 123.75]
        for star in 0..<5 {
            #expect(abs(Double(Recipe.starCycles[star]) / Double(Recipe.seconds) - hertz[star]) < 1e-9, "\(star)")
        }
        // No star on target: the root alone.
        let empty: [[Bool]] = [[], [false, false], [false, false, false, false, false]]
        for pattern in empty {
            let root: AmbientLoopRecipe = Recipe.recipe(onTarget: pattern, stage: .playing)
            #expect(root.seconds == 12 && root.swellCycles == 1 && root.gain == Recipe.baseGain, "\(pattern)")
            #expect(root.partials == [AmbientLoopPartial(cyclesPerLoop: 1_320, amplitude: base)], "\(pattern)")
        }
        // Stars 0 and 3 on target: the root, the fifth and the major sixth, each at the base amplitude.
        let pattern: [Bool] = [true, false, false, true]
        let playing: AmbientLoopRecipe = Recipe.recipe(onTarget: pattern, stage: .playing)
        #expect(playing.partials == [AmbientLoopPartial(cyclesPerLoop: 1_320, amplitude: base),
                                     AmbientLoopPartial(cyclesPerLoop: 1_980, amplitude: base),
                                     AmbientLoopPartial(cyclesPerLoop: 2_200, amplitude: base)])
        // Won adds the 220 Hz octave as its own partial.
        let won: AmbientLoopRecipe = Recipe.recipe(onTarget: pattern, stage: .won)
        #expect(won.partials == playing.partials + [AmbientLoopPartial(cyclesPerLoop: 2_640, amplitude: base)])
        #expect(won.gain == playing.gain && won.seconds == 12)
        // With all 5 stars on target (6 partials) the root is raised to the octave instead.
        let all: [Bool] = [true, true, true, true, true]
        let full: AmbientLoopRecipe = Recipe.recipe(onTarget: all, stage: .playing)
        let fullWon: AmbientLoopRecipe = Recipe.recipe(onTarget: all, stage: .won)
        #expect(full.partials.count == 6 && fullWon.partials.count == 6)
        #expect(fullWon.partials[0] == AmbientLoopPartial(cyclesPerLoop: 2_640, amplitude: base))
        #expect(Array(fullWon.partials.dropFirst()) == Array(full.partials.dropFirst()))
        // Failed halves every amplitude and the gain.
        let failed: AmbientLoopRecipe = Recipe.recipe(onTarget: pattern, stage: .failed)
        #expect(failed.gain == playing.gain / 2 && failed.partials.count == playing.partials.count)
        for index in playing.partials.indices {
            #expect(failed.partials[index].cyclesPerLoop == playing.partials[index].cyclesPerLoop)
            #expect(failed.partials[index].amplitude == playing.partials[index].amplitude / 2)
        }
        // Every other stage sounds as playing.
        let quiet: [ChronoConstellatorStage] = [.loading, .tutorial, .paused, .result]
        for stage in quiet { #expect(Recipe.recipe(onTarget: pattern, stage: stage) == playing, "\(stage)") }
    }

    @Test func everyPatternGivesAValidRecipe() {
        for stage in ChronoConstellatorStage.allCases {
            for pattern in Self.patterns() {
                let recipe: AmbientLoopRecipe = Recipe.recipe(onTarget: pattern, stage: stage)
                #expect(recipe.isValid && recipe.partials.count <= 6, "\(pattern) \(stage)")
            }
            let long: [Bool] = [Bool](repeating: true, count: 9)
            #expect(Recipe.recipe(onTarget: long, stage: stage).isValid, "\(stage)")
        }
    }

    @Test func everyCertifiedLevelGivesValidRecipes() async throws {
        var numbers: [Int] = []
        for number in 1...100 { numbers.append(number) }
        await soundPrewarm(numbers)
        var count: Int = 0
        var distinct: Int = 0
        for number in numbers {
            let generated: ChronoConstellatorGenerated = try ChronoConstellatorExperienceCore.generated(number: number)
            var core: ChronoConstellatorExperienceCore = try ChronoConstellatorExperienceCore.opening(number: number)
            let start: [Bool] = Recipe.onTarget(core.snapshot(time: 0))
            for kernel in ChronoConstellatorWitness.actions(for: generated.solution, level: generated.level) {
                let item: ExperienceAction
                switch kernel {
                case .phase(let star, let offset):
                    item = ExperienceAction(control: "star.phase", values: [Double(star), Double(offset)], step: 0)
                case .step(let ticks):
                    item = ExperienceAction(control: "time.step", values: [Double(ticks)], step: 0)
                default:
                    Issue.record("level \(number): unexpected certified action \(kernel)")
                    continue
                }
                #expect(core.apply(item) == .accepted, "level \(number)")
            }
            #expect(core.play.stage == .won, "level \(number)")
            let solved: [Bool] = Recipe.onTarget(core.snapshot(time: 0))
            for value in solved { #expect(value, "level \(number): a star is off target at the win") }
            if Recipe.recipe(onTarget: start, stage: .playing) != Recipe.recipe(onTarget: solved, stage: .playing) {
                distinct += 1
            }
            let states: [[Bool]] = [start, solved]
            for state in states {
                for stage in ChronoConstellatorStage.allCases {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(onTarget: state, stage: stage)
                    #expect(recipe.isValid && recipe.partials.count <= 6, "level \(number) \(stage)")
                    count += 1
                }
            }
        }
        #expect(count == 100 * 2 * ChronoConstellatorStage.allCases.count)
        print("levels whose start and solution sound different while playing: \(distinct) of 100")
    }
}
