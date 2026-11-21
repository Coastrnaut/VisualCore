// ColorfallCanyonsSoundRecipeTests — feature 346 (R02-G05-06) T-R02G0506-005 (FR-R02G0506-006; SC-R02G0506-004;
// clarification Q4; research R6). The ambient recipe: equal for equal basins and stage; different for a fill change and
// for each stage change among playing, won and failed; the documented partials (root 98 Hz, cyan 147 Hz, coral 122.5 Hz,
// yellow 196 Hz at base × (0.3 + 0.7 · share), the root alone without basin fluid, a 196 Hz octave when won, halved
// amplitudes and gain when failed, 10 s); a valid `AmbientLoopRecipe` for every certified level's start and solution
// states (the 100 stored witnesses, replayed) in every stage, and for extreme inputs. Explicit types, plain loops,
// short runs.
import Foundation
import Testing
@testable import ColorfallCanyonsCore
import VisualCoreAudioDSP

/// The repository's witness directory, found from this file.
private let soundWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/colorfall-canyons/levels", isDirectory: true)

@Suite struct ColorfallCanyonsSoundRecipeTests {
    typealias Recipe = ColorfallCanyonsSoundRecipe

    static let basins: [[Int]] = [[6, 2, 0], [0, 0, 0], [2, 0, 0]]

    @Test func equalInputsGiveEqualRecipes() {
        for stage in ColorfallCanyonsStage.allCases {
            let copy: [[Int]] = [[6, 2, 0], [0, 0, 0], [2, 0, 0]]
            #expect(Recipe.recipe(basinMasses: Self.basins, stage: stage) == Recipe.recipe(basinMasses: copy, stage: stage))
            #expect(Recipe.recipe(basinMasses: [], stage: stage) == Recipe.recipe(basinMasses: [], stage: stage))
            // Only the colour totals are heard, not which basin holds them.
            let moved: [[Int]] = [[0, 0, 0], [8, 2, 0]]
            #expect(Recipe.recipe(basinMasses: Self.basins, stage: stage) == Recipe.recipe(basinMasses: moved, stage: stage))
        }
    }

    @Test func aFillChangeChangesTheRecipe() {
        let fills: [[[Int]]] = [[], [[1, 0, 0]], [[1, 1, 0]], [[1, 1, 1]], [[2, 1, 1]], [[0, 3, 0]], [[0, 0, 5]],
                                [[4, 0, 1]]]
        for stage in ColorfallCanyonsStage.allCases {
            var seen: [AmbientLoopRecipe] = []
            for fill in fills {
                let recipe: AmbientLoopRecipe = Recipe.recipe(basinMasses: fill, stage: stage)
                #expect(!seen.contains(recipe), "\(fill) \(stage)")
                seen.append(recipe)
            }
        }
    }

    @Test func eachStageChangeChangesTheRecipe() {
        let fills: [[[Int]]] = [[], Self.basins, [[0, 0, 9]]]
        for fill in fills {
            let playing: AmbientLoopRecipe = Recipe.recipe(basinMasses: fill, stage: .playing)
            let won: AmbientLoopRecipe = Recipe.recipe(basinMasses: fill, stage: .won)
            let failed: AmbientLoopRecipe = Recipe.recipe(basinMasses: fill, stage: .failed)
            #expect(playing != won && playing != failed && won != failed, "\(fill)")
        }
    }

    @Test func thePartialsFollowTheBasins() {
        let base: Double = Recipe.baseAmplitude
        #expect(Recipe.rootCycles == 980 && Recipe.colourCycles == [1_470, 1_225, 1_960] && Recipe.octaveCycles == 1_960)
        // No basin fluid: the root alone.
        let empty: [[[Int]]] = [[], [[0, 0, 0]], [[0, 0, 0], [0, 0, 0]], [[-3, 0, 0]], [[]]]
        for fill in empty {
            let root: AmbientLoopRecipe = Recipe.recipe(basinMasses: fill, stage: .playing)
            #expect(root.seconds == 10 && root.swellCycles == 1 && root.gain == Recipe.baseGain, "\(fill)")
            #expect(root.partials == [AmbientLoopPartial(cyclesPerLoop: 980, amplitude: base)], "\(fill)")
        }
        // Cyan 8 of 10, coral 2 of 10: cyan at 0.3 + 0.7 · 0.8 = 0.86, coral at 0.3 + 0.7 · 0.2 = 0.44 of the base.
        let playing: AmbientLoopRecipe = Recipe.recipe(basinMasses: Self.basins, stage: .playing)
        #expect(playing.partials.map(\.cyclesPerLoop) == [980, 1_470, 1_225])
        #expect(playing.partials[0].amplitude == base)
        #expect(abs(playing.partials[1].amplitude - base * 0.86) < 1e-12)
        #expect(abs(playing.partials[2].amplitude - base * 0.44) < 1e-12)
        // A single colour has the whole share: the base amplitude.
        let yellow: AmbientLoopRecipe = Recipe.recipe(basinMasses: [[0, 0, 4]], stage: .playing)
        #expect(yellow.partials == [AmbientLoopPartial(cyclesPerLoop: 980, amplitude: base),
                                    AmbientLoopPartial(cyclesPerLoop: 1_960, amplitude: base)])
        // Won adds the 196 Hz octave as its own partial, even next to yellow; failed halves the amplitudes and gain.
        let wonYellow: AmbientLoopRecipe = Recipe.recipe(basinMasses: [[0, 0, 4]], stage: .won)
        #expect(wonYellow.partials.map(\.cyclesPerLoop) == [980, 1_960, 1_960])
        let won: AmbientLoopRecipe = Recipe.recipe(basinMasses: Self.basins, stage: .won)
        #expect(Array(won.partials.prefix(3)) == playing.partials && won.gain == playing.gain)
        #expect(won.partials.count == 4 && won.partials[3] == AmbientLoopPartial(cyclesPerLoop: 1_960, amplitude: base))
        let failed: AmbientLoopRecipe = Recipe.recipe(basinMasses: Self.basins, stage: .failed)
        #expect(failed.gain == playing.gain / 2 && failed.partials.count == 3)
        for index in 0..<3 {
            #expect(failed.partials[index].cyclesPerLoop == playing.partials[index].cyclesPerLoop)
            #expect(failed.partials[index].amplitude == playing.partials[index].amplitude / 2)
        }
        // Every other stage sounds as playing.
        let quiet: [ColorfallCanyonsStage] = [.loading, .tutorial, .paused, .result]
        for stage in quiet { #expect(Recipe.recipe(basinMasses: Self.basins, stage: stage) == playing, "\(stage)") }
    }

    @Test func extremeInputsGiveValidRecipes() {
        let fills: [[[Int]]] = [[], [[999, 999, 999]], [[1, 0, 0], [0, 1, 0], [0, 0, 1]], [[-5, -5, -5]],
                                [[1, 2]], [[1, 2, 3, 4]], [[999, 0, 1], [0, 999, 0], [999, 999, 999], [3, 3, 3]]]
        for fill in fills {
            for stage in ColorfallCanyonsStage.allCases {
                let recipe: AmbientLoopRecipe = Recipe.recipe(basinMasses: fill, stage: stage)
                #expect(recipe.isValid && recipe.partials.count <= 5, "\(fill) \(stage)")
            }
        }
    }

    @Test func everyCertifiedLevelGivesValidRecipes() throws {
        var count: Int = 0
        var distinctFills: Int = 0
        for entry in ColorfallCanyonsManifest.entries {
            let name: String = String(ColorfallCanyonsGenerator.levelID(entry.number).suffix(3)) + ".witness.json"
            let data: Data = try Data(contentsOf: soundWitnessDirectory.appendingPathComponent(name))
            let witness: ColorfallCanyonsWitness = try ColorfallCanyonsWitness.decode(data)
            var play: ColorfallCanyonsPlay = try ColorfallCanyonsExperienceCore.freshPlay(of: witness.level)
            let start: [[Int]] = Recipe.basinMasses(ColorfallCanyonsSceneSnapshot(play: play, levelNumber: entry.number,
                                                                                  time: 0))
            for action in witness.actions { try play.apply(action, expecting: play.fingerprint) }
            #expect(play.stage == .won, "level \(entry.number)")
            let solved: [[Int]] = Recipe.basinMasses(ColorfallCanyonsSceneSnapshot(play: play, levelNumber: entry.number,
                                                                                   time: 0))
            #expect(Recipe.colourTotals(solved).reduce(0, +) > 0, "level \(entry.number)")
            if Recipe.recipe(basinMasses: start, stage: .playing) != Recipe.recipe(basinMasses: solved, stage: .playing) {
                distinctFills += 1
            }
            let states: [[[Int]]] = [start, solved]
            for state in states {
                for stage in ColorfallCanyonsStage.allCases {
                    let recipe: AmbientLoopRecipe = Recipe.recipe(basinMasses: state, stage: stage)
                    #expect(recipe.isValid && recipe.partials.count <= 5, "level \(entry.number) \(stage)")
                    count += 1
                }
            }
        }
        #expect(count == 100 * 2 * ColorfallCanyonsStage.allCases.count)
        #expect(distinctFills == 100)
    }
}
