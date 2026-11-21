// WaveKnotKeeperSoundRecipeTests — feature 326 (R02-G03-06) T-R02G0306-005 (FR-R02G0306-006; clarification Q4; research
// R5; SC-R02G0306-004). The ambient recipe: equal for equal summary, target and stage; different for a crossings change
// and for each stage change among playing, won and failed; the documented partials (root 110 Hz × (1 + target
// crossings), current 110 Hz × (1 + crossings) merged into the root in unison or when degenerate, a fifth above the
// root, an octave above the root when won, the writhe factor 0.6 + 0.4 / (1 + d) on the current partial and the gain,
// halved when failed); a valid `AmbientLoopRecipe` for every certified level's start and solution summaries in every
// stage, and for extreme inputs. Explicit types, plain loops, short runs.
import Testing
@testable import WaveKnotKeeperCore
import VisualCoreAudioDSP

@Suite struct WaveKnotKeeperSoundRecipeTests {
    typealias Recipe = WaveKnotKeeperSoundRecipe

    static func target(_ crossings: Int, _ writhe: Int) throws -> WaveKnotKeeperTarget {
        try WaveKnotKeeperTarget(crossings: crossings, writhe: writhe)
    }

    static let summary: WaveKnotKeeperSummary = WaveKnotKeeperSummary(crossings: 3, writhe: 1, degenerate: false)

    @Test func equalInputsGiveEqualRecipes() throws {
        for stage in WaveKnotKeeperStage.allCases {
            let copy: WaveKnotKeeperSummary = WaveKnotKeeperSummary(crossings: 3, writhe: 1, degenerate: false)
            #expect(Recipe.recipe(summary: Self.summary, target: try Self.target(4, 2), stage: stage)
                    == Recipe.recipe(summary: copy, target: try Self.target(4, 2), stage: stage))
        }
    }

    @Test func aCrossingsChangeChangesTheRecipe() throws {
        let target: WaveKnotKeeperTarget = try Self.target(4, 2)
        let more: WaveKnotKeeperSummary = WaveKnotKeeperSummary(crossings: 5, writhe: 1, degenerate: false)
        #expect(Recipe.recipe(summary: Self.summary, target: target, stage: .playing)
                != Recipe.recipe(summary: more, target: target, stage: .playing))
        #expect(Recipe.recipe(summary: Self.summary, target: target, stage: .playing)
                != Recipe.recipe(summary: Self.summary, target: try Self.target(2, 0), stage: .playing))
    }

    @Test func eachStageChangeChangesTheRecipe() throws {
        let target: WaveKnotKeeperTarget = try Self.target(4, 2)
        let playing: AmbientLoopRecipe = Recipe.recipe(summary: Self.summary, target: target, stage: .playing)
        let won: AmbientLoopRecipe = Recipe.recipe(summary: Self.summary, target: target, stage: .won)
        let failed: AmbientLoopRecipe = Recipe.recipe(summary: Self.summary, target: target, stage: .failed)
        #expect(playing != won && playing != failed && won != failed)
    }

    @Test func thePartialsFollowTheKnot() throws {
        let target: WaveKnotKeeperTarget = try Self.target(4, 2)
        let playing: AmbientLoopRecipe = Recipe.recipe(summary: Self.summary, target: target, stage: .playing)
        let base: Double = Recipe.baseAmplitude
        let factor: Double = 0.6 + 0.4 / 2   // writhe distance |1 − 2| = 1
        #expect(abs(Recipe.writheFactor(writhe: 1, targetWrithe: 2) - factor) < 1e-12)
        #expect(playing.seconds == 8 && playing.swellCycles == 1)
        #expect(abs(playing.gain - Recipe.baseGain * factor) < 1e-12)
        #expect(playing.partials.map(\.cyclesPerLoop) == [8 * 550, 8 * 440, 8 * 825])
        #expect(playing.partials[0].amplitude == base, "the root at the base")
        #expect(abs(playing.partials[1].amplitude - base * factor) < 1e-12, "the current partial shaped by writhe")
        #expect(playing.partials[2].amplitude == base / 2, "the fifth at half the base")
        let won: AmbientLoopRecipe = Recipe.recipe(summary: Self.summary, target: target, stage: .won)
        #expect(won.partials.count == 4 && won.partials[3].cyclesPerLoop == 8 * 1_100 && won.partials[3].amplitude == base)
        #expect(Array(won.partials.prefix(3)) == playing.partials && won.gain == playing.gain)
        let failed: AmbientLoopRecipe = Recipe.recipe(summary: Self.summary, target: target, stage: .failed)
        #expect(failed.gain == playing.gain / 2 && failed.partials.count == 3)
        for index in 0..<3 {
            #expect(failed.partials[index].cyclesPerLoop == playing.partials[index].cyclesPerLoop)
            #expect(failed.partials[index].amplitude == playing.partials[index].amplitude / 2)
        }
        // The matched knot: a unison (one partial for root and current), the full gain.
        let matched: AmbientLoopRecipe = Recipe.recipe(
            summary: WaveKnotKeeperSummary(crossings: 4, writhe: 2, degenerate: false), target: target, stage: .playing)
        #expect(matched.partials.map(\.cyclesPerLoop) == [8 * 550, 8 * 825] && matched.gain == Recipe.baseGain)
        // A degenerate summary sounds at the root.
        let degenerate: AmbientLoopRecipe = Recipe.recipe(
            summary: WaveKnotKeeperSummary(crossings: 7, writhe: 2, degenerate: true), target: target, stage: .playing)
        #expect(degenerate.partials.map(\.cyclesPerLoop) == [8 * 550, 8 * 825])
        // The writhe factor: 1 at distance 0, strictly falling, never below 0.6.
        var previous: Double = 1.0 + 1e-9
        for distance in 0...40 {
            let value: Double = Recipe.writheFactor(writhe: distance, targetWrithe: 0)
            #expect(value < previous && value > 0.6 && value <= 1)
            previous = value
        }
        #expect(Recipe.writheFactor(writhe: Int.max, targetWrithe: Int.min) >= 0.6)
    }

    @Test func everyCertifiedLevelGivesValidRecipes() throws {
        var count: Int = 0
        for number in Self.sampledLevels {
            let generated: WaveKnotKeeperGenerated = try WaveKnotKeeperExperienceCore.generated(number: number)
            let summaries: [WaveKnotKeeperSummary] = [WaveKnotKeeperGeometry.summary(generated.level.points),
                                                      WaveKnotKeeperGeometry.summary(generated.solution.final)]
            for summary in summaries {
                for stage in WaveKnotKeeperStage.allCases {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(summary: summary, target: generated.level.target,
                                                                  stage: stage)
                    #expect(recipe.isValid, "level \(number) \(summary) \(stage)")
                    #expect(recipe.partials.count <= 4)
                    count += 1
                }
            }
            // The solution's final rope matches the target: a unison at the full gain.
            let final: AmbientLoopRecipe = Recipe.recipe(summary: summaries[1], target: generated.level.target,
                                                         stage: .won)
            #expect(final.gain == Recipe.baseGain && final.partials.count == 3, "level \(number)")
        }
        #expect(count == Self.sampledLevels.count * 2 * WaveKnotKeeperStage.allCases.count)
        // Extreme inputs are clamped, never invalid.
        let extremes: [WaveKnotKeeperSummary] = [
            WaveKnotKeeperSummary(crossings: Int.max, writhe: Int.min, degenerate: false),
            WaveKnotKeeperSummary(crossings: -5, writhe: Int.max, degenerate: false),
            WaveKnotKeeperSummary(crossings: 1_000, writhe: 0, degenerate: true),
        ]
        for summary in extremes {
            for target in [try Self.target(0, 0), try Self.target(32, 32), try Self.target(32, -32)] {
                for stage in WaveKnotKeeperStage.allCases {
                    #expect(Recipe.recipe(summary: summary, target: target, stage: stage).isValid)
                }
            }
        }
    }

    /// The certified levels checked: all 100.
    static let sampledLevels: [Int] = Array(1...100)
}
