// EchoCartographerScenariosTests — feature 403 (R02-G11-03) T-R02G1103-006 (FR-R02G1103-005, FR-R02G1103-008). The
// scenario manifest of Echo Cartographer: a valid round-two game manifest with the nine standard scenarios,
// `full-playthrough`, `hero`, the 80 acceptance scenarios and three fixtures; its derived digests, results and outcomes
// equal to what `ExperienceEngine` gives when played as the runner plays them; the save-restore state survives a
// restore; every fixture ends in the state its actions describe; every acceptance scenario opens its level, plays its
// certified first action and refuses its illegal action; and the committed `scenario-manifest.json` equal to the Swift
// manifest (`UPDATE_SCENARIO_MANIFEST=1` rewrites it). Host-run (`swift test`); explicit types, plain loops.
#if DEBUG || VISUALCORE_AUTOMATION
@testable import EchoCartographerCore
import Foundation
import Testing
import VisualCoreExperience

/// The id of the manifest's experience.
private let scenarioID: ExperienceID = ExperienceID(rawValue: EchoCartographerExperienceCore.experienceID)!

/// The manifest, built once per test process (it generates 80 certified levels).
private let builtManifest: ScenarioManifest = EchoCartographerExperienceCore.manifest(for: scenarioID)

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playScenario(_ spec: ScenarioSpec) async throws
    -> (initial: String, results: [String], final: String, core: EchoCartographerExperienceCore?) {
    var engine: ExperienceEngine<EchoCartographerExperienceCore> =
        ExperienceEngine<EchoCartographerExperienceCore>(id: scenarioID)
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

@Suite struct EchoCartographerScenariosTests {
    typealias Core = EchoCartographerExperienceCore

    /// The names of the three fixtures.
    static let fixtureNames: [String] = ["fixture-level-1-solved", "fixture-budget-out", "fixture-undo-redo"]

    @Test func theManifestIsAValidRoundTwoGame() {
        let manifest: ScenarioManifest = builtManifest
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
        #expect(Array(Core.acceptanceLevels.prefix(4)) == [1, 8, 15, 22])
        #expect(Core.inputActions.count == 2)
        #expect(!Core.completionEntries.isEmpty && !Core.playthroughEntries.isEmpty && !Core.budgetOutEntries.isEmpty)
        #expect(Core.rejectionEntries.count >= 12)
    }

    @Test func derivedDigestsResultsAndOutcomesAreWhatTheEngineGives() async throws {
        for spec in builtManifest.scenarios {
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
        let spec: ScenarioSpec = try #require(builtManifest.scenarios.first { $0.name == "save-restore" })
        let played = try await playScenario(spec)
        let core: Core = try #require(played.core)
        let restored: Core = try Core.restore(payload: core.snapshotPayload(), seed: spec.seed)
        var builder: DigestBuilder = DigestBuilder(domain: scenarioID.rawValue)
        try restored.writeDigest(into: &builder)
        #expect(builder.finish().hex == played.final)
        #expect(restored == core && restored.play.canRedo)
    }

    @Test func everyGameScenarioAndFixtureEndsInTheStateItsActionsDescribe() async throws {
        let level1: EchoCartographerGenerated = try Core.generated(number: 1)
        let certified1: [EchoCartographerAction] = Core.certifiedActions(1)
        for spec in builtManifest.scenarios where !spec.name.hasPrefix("acceptance-") {
            let played = try await playScenario(spec)
            let core: Core = try #require(played.core, "\(spec.name)")
            switch spec.name {
            case "launch-first-frame", "suspend-resume", "teardown-reentry", "cancel-prepare", "rejection":
                #expect(core.levelNumber == 1 && core.play.records.isEmpty && core.play.stage == .playing,
                        "\(spec.name)")
                #expect(core.play.energy == level1.level.energy, "\(spec.name)")
            case "input-response", "save-restore", "reset":
                #expect(core.levelNumber == 1 && core.play.energy == level1.level.energy - 1, "\(spec.name)")
                #expect(core.play.records.map(\.kind) == [.pulse, .mark, .undo], "\(spec.name)")
                #expect(core.play.stage == .playing && core.outcome == nil && core.play.canRedo, "\(spec.name)")
                #expect(core.play.markers.isEmpty, "\(spec.name)")
            case "completion", "fixture-level-1-solved":
                #expect(core.levelNumber == 1 && core.play.stage == .won, "\(spec.name)")
                #expect(core.play.records.map(\.action) == certified1.map { Optional($0) }, "\(spec.name)")
                #expect(core.play.located.count == level1.level.beacons.count, "\(spec.name)")
            case "full-playthrough":
                #expect(core.levelNumber == Core.playthroughLevels[Core.playthroughLevels.count - 1])
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
            case "hero":
                #expect(core.play.records.count == 1 && core.play.lastEcho != nil && core.play.stage == .playing)
                #expect(core.outcome == nil)
            case "fixture-budget-out":
                #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(spec.name)")
                #expect(core.play.energy == 0 && core.play.records.count == level1.level.energy, "\(spec.name)")
            case "fixture-undo-redo":
                #expect(core.play.records.map(\.kind) == [.pulse, .undo, .redo] && !core.play.canRedo)
                #expect(core.play.energy == level1.level.energy - 1)
            default:
                Issue.record("unexpected scenario \(spec.name)")
            }
        }
    }

    @Test func everyAcceptanceScenarioOpensItsLevelAndRefusesItsIllegalAction() async throws {
        for (index, level) in Core.acceptanceLevels.enumerated() {
            let name: String = Core.acceptanceName(index + 1)
            let spec: ScenarioSpec = try #require(builtManifest.scenarios.first { $0.name == name })
            #expect(spec.seed == UInt64(level - 1), "\(name)")
            let played = try await playScenario(spec)
            let core: Core = try #require(played.core, "\(name)")
            #expect(core.levelNumber == level && core.play.records.count == 1, "\(name)")
            #expect(core.play.stage == .playing, "\(name)")
            #expect(played.results.count == 2 && played.results[0] == "accepted", "\(name)")
            #expect(played.results[1] == "action.out-of-range", "\(name): \(played.results[1])")
            let first: EchoCartographerAction = try #require(Core.certifiedActions(level).first)
            #expect(core.play.records[0].action == first, "\(name)")
        }
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: builtManifest.encoded()) as? [String: Any])
        object["controls"] = Core.controls.map(\.id)
        let data: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
#endif
