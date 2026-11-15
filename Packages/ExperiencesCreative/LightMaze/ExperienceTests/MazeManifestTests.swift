// MazeManifestTests — feature 096 (A13-P01) T-A13-106 (FR-A13-113, FR-A13-122; SC-A13-103, SC-A13-106). The scenario
// manifest of Light Maze: valid with the nine standard scenarios, the five fixtures `fixture-lm-01`, `-05`, `-10`,
// `-16` and `fixture-lm-20`, the undo fixture `fixture-undo` (feature 098) and the three refusal scenarios; its derived digests and expected results equal to what the
// engine gives when the runner plays them; every fixture solving its level by the recorded solution with the committed
// final digest; and the committed `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`,
// on the simulator `TEST_RUNNER_UPDATE_SCENARIO_MANIFEST=1`, rewrites it).
import Foundation
import Testing
@testable import LightMazeExperience
import LightMazeCore
import VisualCoreExperience

private let id = ExperienceID(rawValue: MazeCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func play(_ spec: ScenarioSpec) async throws -> (initial: String, results: [String], final: String,
                                                         core: MazeCore?) {
    var engine = ExperienceEngine<MazeCore>(id: id)
    try await engine.prepare(seed: spec.seed)
    try engine.activate()
    let initial = try engine.digest().hex
    var results: [String] = []
    for entry in spec.entries {
        try engine.run(steps: entry.steps)
        if let action = entry.action {
            results.append(engine.handle(control: action.control, values: action.values).code)
        }
    }
    return (initial, results, try engine.digest().hex, engine.core)
}

@Suite struct MazeManifestTests {
    /// The names of the five solved fixtures.
    static let fixtureNames = ["fixture-lm-01", "fixture-lm-05", "fixture-lm-10", "fixture-lm-16", "fixture-lm-20"]
    /// The names of all six fixtures: the five solved ones, then the undo fixture (feature 098).
    static let allFixtureNames = fixtureNames + ["fixture-undo"]
    /// The names of the three refusal scenarios.
    static let refusalNames = ["refusal-level-out-of-range", "refusal-level-before-first",
                               "refusal-turn-without-selection"]

    @Test func theManifestIsValidWithTheStandardScenariosSixFixturesAndThreeRefusals() {
        let manifest = MazeCore.manifest(for: id)
        let problems = ScenarioManifestValidator.problems(manifest, controls: MazeCore.controls,
                                                          content: ContentRequirement(fixtures: 6))
        #expect(problems.isEmpty, "\(problems)")
        #expect(manifest.scenarios.map(\.name)
                == ScenarioManifest.standardNames + Self.allFixtureNames + Self.refusalNames)
        let fixtures = manifest.scenarios.filter { $0.name.hasPrefix("fixture-") }
        #expect(fixtures.count == 6)
        #expect(fixtures.count >= 5, "the content-count audit needs at least five fixtures")
        #expect(MazeCore.solvedFixtures.map { MazeCore.fixtureName(level: $0.level) } == Self.fixtureNames)
        #expect(manifest.kind == .creative)
        #expect(manifest.experience == id)
        #expect(manifest.scenarios.allSatisfy { $0.seed == MazeCore.manifestSeed })
    }

    @Test func derivedDigestsAndResultsAreWhatTheEngineGives() async throws {
        let manifest = MazeCore.manifest(for: id)
        #expect(manifest.scenarios.first { $0.name == "launch-first-frame" }?.expect.initialDigest != nil)
        for spec in manifest.scenarios {
            let played = try await play(spec)
            if let initial = spec.expect.initialDigest {
                #expect(played.initial == initial, "\(spec.name) initial: \(played.initial)")
            }
            if let final = spec.expect.finalDigest {
                #expect(played.final == final, "\(spec.name) final: \(played.final)")
            }
            let expected = spec.entries.compactMap { $0.action == nil ? nil : ($0.result ?? "accepted") }
            #expect(played.results == expected, "\(spec.name)")
            if let outcome = spec.expect.outcome {
                #expect(played.core?.outcome?.code == outcome, "\(spec.name)")
            }
        }
        let completion = try #require(manifest.scenarios.first { $0.name == "completion" })
        #expect(completion.expect.outcome == "level-solved")
        #expect(MazeCore.played(seed: completion.seed, entries: completion.entries).outcome?.code
                == completion.expect.outcome)
        for name in Self.refusalNames {
            let spec = try #require(manifest.scenarios.first { $0.name == name })
            #expect(spec.expect.finalDigest == spec.expect.initialDigest, "\(name) changes nothing")
        }
    }

    @Test func everyFixtureSolvesItsLevelWithTheCommittedDigest() async throws {
        let manifest = MazeCore.manifest(for: id)
        #expect(MazeCore.solvedFixtures.map(\.level) == [0, 4, 9, 15, 19])
        #expect(Set(MazeCore.solvedFixtures.map(\.digest)).count == 5)
        for fixture in MazeCore.solvedFixtures {
            let name = MazeCore.fixtureName(level: fixture.level)
            let spec = try #require(manifest.scenarios.first { $0.name == name })
            #expect(spec.expect.finalDigest == fixture.digest, "\(name)")
            #expect(spec.expect.outcome == "level-solved", "\(name)")
            let played = try await play(spec)
            #expect(played.final == fixture.digest, "\(name): \(played.final)")
            let core = try #require(played.core)
            #expect(core.state.levelIndex == fixture.level, "\(name)")
            #expect(core.state.orientations == core.level.solution, "\(name): the recorded solution")
            #expect(core.isSolved, "\(name)")
            #expect(core.beam == BeamTracer.trace(try #require(core.level.solvedBoard)), "\(name): the solved beam")
            let controls = Set(spec.entries.compactMap { $0.action?.control })
            #expect(controls.isSubset(of: ["level.select", "tile.select", "tile.turn"]), "\(name): solved by actions")
        }
    }

    /// Feature 098: `fixture-undo` solves level 1 and takes the turn back, ending unsolved with no moves at the
    /// committed digest.
    @Test func theUndoFixtureSolvesLevelOneThenTakesTheTurnBack() async throws {
        let manifest = MazeCore.manifest(for: id)
        let spec = try #require(manifest.scenarios.first { $0.name == MazeCore.undoFixtureName })
        #expect(spec.name == "fixture-undo")
        #expect(spec.expect.finalDigest == MazeCore.undoFixtureDigest)
        #expect(spec.expect.outcome == nil, "unsolved after the undo")
        let controls: [String] = spec.entries.compactMap { $0.action?.control }
        #expect(controls == ["level.select", "tile.select", "tile.turn", "move.undo"])
        var beforeUndo: [ScenarioStep] = []
        for entry in spec.entries.dropLast() { beforeUndo.append(entry) }
        let solved = MazeCore.played(seed: spec.seed, entries: beforeUndo)
        #expect(solved.isSolved, "level 1 solved before the undo")
        #expect(solved.state.moves.count == 1)
        let played = try await play(spec)
        #expect(played.final == MazeCore.undoFixtureDigest, "fixture-undo: \(played.final)")
        let core = try #require(played.core)
        #expect(core.state.levelIndex == 0)
        #expect(!core.isSolved)
        #expect(core.state.moves.isEmpty)
        #expect(core.state.orientations == core.level.startOrientations)
        #expect(played.final != played.initial, "the mirror stays selected")
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest = MazeCore.manifest(for: id)
        var object = try #require(try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = MazeCore.controls.map(\.id)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
