// HueCompassSoundRecipeTests — feature 336 (R02-G04-06) T-R02G0406-005 (FR-R02G0406-006; clarification Q4; research
// R6; SC-R02G0406-004). The ambient recipe: equal for equal clue and stage; different for a hue-gap change and for each
// stage change among playing, won and failed; the documented partials (root 110 Hz, the clue partial 110 Hz × (1 + g /
// 12) rounded to whole cycles per 8-second loop and merged into the root at g = 0 or with no clue, a fifth at 165 Hz, an
// octave at 220 Hz when won, the depth factor 1 − 0.4 · min(d, 90) / 90 on the gain, halved when failed); a valid
// `AmbientLoopRecipe` for every certified level's start (no clue, and the clue a probe at the start would give) in
// every stage, for clues at every bearing of a few certified levels in every stage, and for extreme inputs. Explicit
// types, plain loops, short runs.
import Testing
@testable import HueCompassCore
import VisualCoreAudioDSP

@Suite struct HueCompassSoundRecipeTests {
    typealias Recipe = HueCompassSoundRecipe

    static let clue: HueCompassClue = HueCompassClue(bearing: 10, hueGap: 3, depth: 45)

    @Test func equalInputsGiveEqualRecipes() {
        for stage in HueCompassStage.allCases {
            let copy: HueCompassClue = HueCompassClue(bearing: 10, hueGap: 3, depth: 45)
            #expect(Recipe.recipe(clue: Self.clue, stage: stage) == Recipe.recipe(clue: copy, stage: stage))
            #expect(Recipe.recipe(clue: nil, stage: stage) == Recipe.recipe(clue: nil, stage: stage))
            // The bearing alone is not heard.
            let elsewhere: HueCompassClue = HueCompassClue(bearing: 70, hueGap: 3, depth: 45)
            #expect(Recipe.recipe(clue: Self.clue, stage: stage) == Recipe.recipe(clue: elsewhere, stage: stage))
        }
    }

    @Test func aHueGapChangeChangesTheRecipe() {
        for stage in HueCompassStage.allCases {
            var seen: [AmbientLoopRecipe] = []
            for gap in 0...12 {
                let recipe: AmbientLoopRecipe = Recipe.recipe(clue: HueCompassClue(bearing: 0, hueGap: gap, depth: 45),
                                                              stage: stage)
                #expect(!seen.contains(recipe), "gap \(gap) \(stage)")
                seen.append(recipe)
            }
        }
    }

    @Test func eachStageChangeChangesTheRecipe() {
        let clues: [HueCompassClue?] = [nil, Self.clue, HueCompassClue(bearing: 0, hueGap: 12, depth: 0)]
        for clue in clues {
            let playing: AmbientLoopRecipe = Recipe.recipe(clue: clue, stage: .playing)
            let won: AmbientLoopRecipe = Recipe.recipe(clue: clue, stage: .won)
            let failed: AmbientLoopRecipe = Recipe.recipe(clue: clue, stage: .failed)
            #expect(playing != won && playing != failed && won != failed, "\(String(describing: clue))")
        }
    }

    @Test func thePartialsFollowTheClue() {
        let base: Double = Recipe.baseAmplitude
        // No clue: a unison root, the fifth, the full gain.
        let neutral: AmbientLoopRecipe = Recipe.recipe(clue: nil, stage: .playing)
        #expect(neutral.seconds == 8 && neutral.swellCycles == 1 && neutral.gain == Recipe.baseGain)
        #expect(neutral.partials == [AmbientLoopPartial(cyclesPerLoop: 880, amplitude: base),
                                     AmbientLoopPartial(cyclesPerLoop: 1_320, amplitude: base / 2)])
        // Gap 0 at depth 0: the same unison.
        #expect(Recipe.recipe(clue: HueCompassClue(bearing: 5, hueGap: 0, depth: 0), stage: .playing) == neutral)
        // Gap 3 at depth 45: 110 × 1.25 = 137.5 Hz (1,100 cycles), gain × 0.8.
        let playing: AmbientLoopRecipe = Recipe.recipe(clue: Self.clue, stage: .playing)
        #expect(playing.partials.map(\.cyclesPerLoop) == [880, 1_100, 1_320])
        #expect(playing.partials.map(\.amplitude) == [base, base, base / 2])
        #expect(abs(playing.gain - Recipe.baseGain * 0.8) < 1e-12)
        // Won adds the octave, 220 Hz; failed halves the amplitudes and the gain.
        let won: AmbientLoopRecipe = Recipe.recipe(clue: Self.clue, stage: .won)
        #expect(won.partials.count == 4 && won.partials[3] == AmbientLoopPartial(cyclesPerLoop: 1_760, amplitude: base))
        #expect(Array(won.partials.prefix(3)) == playing.partials && won.gain == playing.gain)
        let failed: AmbientLoopRecipe = Recipe.recipe(clue: Self.clue, stage: .failed)
        #expect(failed.gain == playing.gain / 2 && failed.partials.count == 3)
        for index in 0..<3 {
            #expect(failed.partials[index].cyclesPerLoop == playing.partials[index].cyclesPerLoop)
            #expect(failed.partials[index].amplitude == playing.partials[index].amplitude / 2)
        }
        // Gap 12 is the octave of the root (1,760 cycles); gap 1 is 880 × 13 / 12 = 953.3, rounded to 953.
        #expect(Recipe.clueCycles(hueGap: 12) == 1_760 && Recipe.clueCycles(hueGap: 1) == 953)
        #expect(Recipe.clueCycles(hueGap: 2) == 1_027 && Recipe.clueCycles(hueGap: 6) == 1_320)
        // Each cycle count is within half a cycle of the exact 880 × (12 + g) / 12, rising with the gap.
        var previous: Int = 879
        for gap in 0...12 {
            let cycles: Int = Recipe.clueCycles(hueGap: gap)
            #expect(abs(Double(cycles) - 880 * Double(12 + gap) / 12) <= 0.5 && cycles > previous)
            previous = cycles
        }
        // Gaps outside 0 … 12 are clamped.
        #expect(Recipe.clueCycles(hueGap: -4) == 880 && Recipe.clueCycles(hueGap: 99) == 1_760)
        // The depth factor: 1 at 0, linear, 0.6 from 90 on, never below.
        #expect(Recipe.depthFactor(depth: 0) == 1 && Recipe.depthFactor(depth: -5) == 1)
        #expect(abs(Recipe.depthFactor(depth: 45) - 0.8) < 1e-12)
        #expect(abs(Recipe.depthFactor(depth: 90) - 0.6) < 1e-12)
        #expect(Recipe.depthFactor(depth: 423) == Recipe.depthFactor(depth: 90))
        // Won at gap 12 keeps the octave as its own partial.
        let top: AmbientLoopRecipe = Recipe.recipe(clue: HueCompassClue(bearing: 0, hueGap: 12, depth: 0), stage: .won)
        #expect(top.partials.map(\.cyclesPerLoop) == [880, 1_760, 1_320, 1_760])
    }

    @Test func everyCertifiedLevelGivesValidRecipes() throws {
        var count: Int = 0
        for number in HueCompassExperienceCore.levelNumbers {
            let level: HueCompassLevel = try HueCompassExperienceCore.level(number: number)
            let clues: [HueCompassClue?] = [nil, level.clue(at: level.start)]
            for clue in clues {
                for stage in HueCompassStage.allCases {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(clue: clue, stage: stage)
                    #expect(recipe.isValid && recipe.partials.count <= 4, "level \(number) \(stage)")
                    count += 1
                }
            }
            if Self.everyBearing.contains(number) {
                for bearing in 0..<HueCompassWheel.bearings {
                    let clue: HueCompassClue = level.clue(at: bearing)
                    for stage in HueCompassStage.allCases {
                        #expect(Recipe.recipe(clue: clue, stage: stage).isValid, "level \(number) \(bearing) \(stage)")
                    }
                }
                // The target's own clue is a unison at the full gain.
                let home: AmbientLoopRecipe = Recipe.recipe(clue: level.clue(at: level.target), stage: .playing)
                #expect(home == Recipe.recipe(clue: nil, stage: .playing), "level \(number)")
            }
        }
        #expect(count == 100 * 2 * HueCompassStage.allCases.count)
        // Extreme inputs are clamped, never invalid.
        let extremes: [HueCompassClue] = [
            HueCompassClue(bearing: Int.min, hueGap: Int.min, depth: Int.min),
            HueCompassClue(bearing: Int.max, hueGap: Int.max, depth: Int.max),
            HueCompassClue(bearing: 0, hueGap: 12, depth: 423),
        ]
        for clue in extremes {
            for stage in HueCompassStage.allCases {
                #expect(Recipe.recipe(clue: clue, stage: stage).isValid)
            }
        }
    }

    /// The certified levels whose clues are checked at every bearing.
    static let everyBearing: Set<Int> = [1, 50, 100]
}
