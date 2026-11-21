// WaveKnotKeeperScenariosTests — feature 323 (R02-G03-03) T-R02G0303-006 (FR-R02G0303-005, FR-R02G0303-008). The
// scenario manifest of Wave Knot Keeper: a valid round-two game manifest with the nine standard scenarios,
// `full-playthrough`, `hero`, the 80 acceptance scenarios and three fixtures; its derived digests, results and outcomes
// equal to what `ExperienceEngine` gives when played as the runner plays them; the save-restore state survives a
// restore; every fixture ends in the state its actions describe; every acceptance scenario opens its planned level and
// refuses its illegal action; and the committed `scenario-manifest.json` equal to the Swift manifest
// (`UPDATE_SCENARIO_MANIFEST=1` rewrites it). Host-run (`swift test`); explicit types, plain loops, short runs.
#if DEBUG || VISUALCORE_AUTOMATION
import Foundation
import Testing
@testable import WaveKnotKeeperCore
import VisualCoreExperience

/// The id of the manifest's experience.
private let scenarioID: ExperienceID = ExperienceID(rawValue: WaveKnotKeeperExperienceCore.experienceID)!

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playScenario(_ spec: ScenarioSpec) async throws
    -> (initial: String, results: [String], final: String, core: WaveKnotKeeperExperienceCore?) {
    var engine: ExperienceEngine<WaveKnotKeeperExperienceCore> =
        ExperienceEngine<WaveKnotKeeperExperienceCore>(id: scenarioID)
    try await engine.prepare(seed: spec.seed)
    try engine.activate()
    let initial: String = try engine.digest().hex
    var results: [String] = []
    for entry in spec.entries {
        try engine.run(steps: entry.steps)
        if let action = entry.action {
            results.append(engine.handle(control: action.control, values: action.values).code)
        }
    }
    return (initial, results, try engine.digest().hex, engine.core)
}

@Suite struct WaveKnotKeeperScenariosTests {
    typealias Core = WaveKnotKeeperExperienceCore

    /// The names of the three fixtures.
    static let fixtureNames: [String] = ["fixture-level-1-solved", "fixture-allowance-spent", "fixture-undo-redo"]

    @Test func theManifestIsAValidRoundTwoGame() {
        let manifest: ScenarioManifest = Core.manifest(for: scenarioID)
        let problems: [String] = ScenarioManifestValidator.problems(
            manifest, controls: Core.controls, content: ContentRequirement(fixtures: 3, acceptance: 80, levels: 100))
        #expect(problems.isEmpty, "\(problems)")
        var acceptanceNames: [String] = []
        for row in 1...80 { acceptanceNames.append(Core.acceptanceName(row)) }
        #expect(acceptanceNames[0] == "acceptance-001" && acceptanceNames[79] == "acceptance-080")
        let names: [String] = manifest.scenarios.map(\.name)
        #expect(names == ScenarioManifest.standardNames + ["full-playthrough", "hero"] + acceptanceNames
            + Self.fixtureNames)
        #expect(Set(names).count == names.count)
        #expect(manifest.kind == .game && manifest.round == 2 && manifest.experience == scenarioID)
        let declared: Set<String> = Set(Core.controls.map(\.id))
        for spec in manifest.scenarios {
            if spec.name.hasPrefix("acceptance-") {
                #expect(spec.entries.count == 2, "\(spec.name)")
            } else {
                #expect(spec.seed == Core.manifestSeed, "\(spec.name)")
            }
            #expect(spec.entries.count <= 64, "\(spec.name) is short")
            for entry in spec.entries {
                if let action = entry.action { #expect(declared.contains(action.control), "\(spec.name)") }
            }
        }
        #expect(Core.acceptanceLevels.count == 80 && Set(Core.acceptanceLevels).count == 80)
        let archived: [Int] = [17, 24, 31, 38, 45, 52, 59, 66, 73, 80, 87, 94, 1, 8, 15, 22, 29, 36, 43, 50]
        #expect(Array(Core.acceptanceLevels.prefix(20)) == archived)
        #expect(!Core.inputEntries.isEmpty && !Core.completionEntries.isEmpty && !Core.allowanceEntries.isEmpty)
        #expect(Core.rejectionEntries.count == 10)
    }

    @Test func derivedDigestsResultsAndOutcomesAreWhatTheEngineGives() async throws {
        let manifest: ScenarioManifest = Core.manifest(for: scenarioID)
        for spec in manifest.scenarios {
            let played = try await playScenario(spec)
            if let initial = spec.expect.initialDigest {
                #expect(played.initial == initial, "\(spec.name) initial: \(played.initial)")
            }
            if let final = spec.expect.finalDigest {
                #expect(played.final == final, "\(spec.name) final: \(played.final)")
            }
            var expected: [String] = []
            for entry in spec.entries where entry.action != nil { expected.append(entry.result ?? "accepted") }
            #expect(played.results == expected, "\(spec.name)")
            if let outcome = spec.expect.outcome {
                #expect(played.core?.outcome?.code == outcome, "\(spec.name)")
            }
        }
    }

    @Test func theSaveRestoreStateSurvivesARestore() async throws {
        let manifest: ScenarioManifest = Core.manifest(for: scenarioID)
        let spec: ScenarioSpec = try #require(manifest.scenarios.first { $0.name == "save-restore" })
        let played = try await playScenario(spec)
        let core: Core = try #require(played.core)
        let restored: Core = try Core.restore(payload: core.snapshotPayload(), seed: spec.seed)
        var builder: DigestBuilder = DigestBuilder(domain: scenarioID.rawValue)
        try restored.writeDigest(into: &builder)
        #expect(builder.finish().hex == played.final)
        #expect(restored == core && restored.play.canRedo)
    }

    @Test func everyGameScenarioAndFixtureEndsInTheStateItsActionsDescribe() async throws {
        let manifest: ScenarioManifest = Core.manifest(for: scenarioID)
        let level1: WaveKnotKeeperGenerated = try Core.generated(number: 1)
        for spec in manifest.scenarios where !spec.name.hasPrefix("acceptance-") {
            let played = try await playScenario(spec)
            let core: Core = try #require(played.core, "\(spec.name)")
            switch spec.name {
            case "launch-first-frame", "suspend-resume", "teardown-reentry", "cancel-prepare", "rejection":
                #expect(core.levelNumber == 1 && core.play.records.isEmpty && core.play.stage == .playing,
                        "\(spec.name)")
            case "input-response", "save-restore", "reset":
                #expect(core.levelNumber == 1 && core.play.spent == 1 && core.play.records.count == 3, "\(spec.name)")
                #expect(core.play.stage == .playing && core.outcome == nil && core.play.canRedo, "\(spec.name)")
            case "completion", "fixture-level-1-solved":
                #expect(core.levelNumber == 1 && core.play.stage == .won, "\(spec.name)")
                #expect(core.play.spent == level1.solution.moves.count, "\(spec.name)")
            case "full-playthrough":
                #expect(core.levelNumber == Core.playthroughLevels[Core.playthroughLevels.count - 1])
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
            case "hero":
                #expect(core.play.spent == 1 && core.play.stage == .playing && core.outcome == nil)
            case "fixture-allowance-spent":
                #expect(core.play.stage == .failed && core.play.failure != nil)
                #expect(core.play.spent == level1.level.allowance && core.outcome?.code == Core.failedCode)
            case "fixture-undo-redo":
                #expect(core.play.spent == 1 && core.play.records.count == 3 && !core.play.canRedo)
                #expect(core.play.records.map(\.kind) == [.move, .undo, .redo])
            default:
                Issue.record("unexpected scenario \(spec.name)")
            }
        }
    }

    @Test func everyAcceptanceScenarioOpensItsPlannedLevelAndRefusesItsIllegalAction() async throws {
        let manifest: ScenarioManifest = Core.manifest(for: scenarioID)
        for (index, level) in Core.acceptanceLevels.enumerated() {
            let name: String = Core.acceptanceName(index + 1)
            let spec: ScenarioSpec = try #require(manifest.scenarios.first { $0.name == name })
            #expect(spec.seed == UInt64(level - 1), "\(name)")
            let played = try await playScenario(spec)
            let core: Core = try #require(played.core, "\(name)")
            #expect(core.levelNumber == level && core.play.spent == 1 && core.play.records.count == 1, "\(name)")
            #expect(played.results.count == 2 && played.results[0] == "accepted", "\(name)")
            let illegal: String = played.results[1]
            if index % 2 == 0 {
                #expect(illegal == "action.out-of-range", "\(name)")
            } else {
                let kernel: Set<String> = ["action.rule.r02-g03.move", "action.rule.r02-g03.stage"]
                #expect(kernel.contains(illegal), "\(name): \(illegal)")
            }
            let first: WaveKnotKeeperMove = try #require(Core.generated(number: level).solution.moves.first)
            #expect(core.play.records[0].point == first.point && core.play.records[0].direction == first.direction,
                    "\(name)")
        }
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        let manifest: ScenarioManifest = Core.manifest(for: scenarioID)
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: manifest.encoded()) as? [String: Any])
        object["controls"] = Core.controls.map(\.id)
        let data: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
#endif
