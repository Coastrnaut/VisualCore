// MoonlitMechanismScenariosTests — feature 433 (R02-G14-03) T-R02G1403-006 (FR-R02G1403-005). The scenario manifest
// of Moonlit Mechanism: a valid round-two game manifest with the nine standard scenarios, `full-playthrough`, `hero`,
// the 80 acceptance scenarios (rows R2-G14-QA-001 … 080, in order, on 80 distinct levels, the first twenty the levels
// the archived rows name) and three fixtures; its derived digests, results and outcomes equal to what
// `ExperienceEngine` gives when played as the runner plays them; the save-restore state survives a restore; every
// standard scenario and fixture ends in the kernel state its actions describe; every acceptance row ends in the state
// of its family (a refusal with the kernel's code, a failed run — `jammed`, `forbidden` and `missing` all reached —
// a spent budget, a won witness whose digest no quality tier changes, undo and redo restoring digests, a shown key
// frame that leaves the digest alone, the next level's fresh play after a campaign win — since feature 435 (R02-G14-05)
// T-R02G1405-004 `level.next` needs the next level open, and on level 100 it is refused `r02-g14.locked` and level 1 is
// chosen); and the committed `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1`
// rewrites it). Host-run (`swift test`); explicit types, plain loops.
#if DEBUG || VISUALCORE_AUTOMATION
@testable import MoonlitMechanismCore
import Foundation
import Testing
import VisualCoreExperience

/// The id of the manifest's experience.
private let scenarioID: ExperienceID = ExperienceID(rawValue: MoonlitMechanismExperienceCore.experienceID)!

/// The manifest, built once per test process (it certifies 80 levels and more).
private let builtManifest: ScenarioManifest = MoonlitMechanismExperienceCore.manifest(for: scenarioID)

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playScenario(_ spec: ScenarioSpec) async throws
    -> (initial: String, results: [String], final: String, core: MoonlitMechanismExperienceCore?) {
    var engine: ExperienceEngine<MoonlitMechanismExperienceCore> =
        ExperienceEngine<MoonlitMechanismExperienceCore>(id: scenarioID)
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

/// The digest of `core` as the engine writes it.
private func digest(of core: MoonlitMechanismExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: scenarioID.rawValue)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

@Suite struct MoonlitMechanismScenariosTests {
    typealias Core = MoonlitMechanismExperienceCore

    /// The names of the three fixtures.
    static let fixtureNames: [String] = ["fixture-level-1-solved", "fixture-budget-out", "fixture-undo-redo"]

    /// The record kinds of `core`'s play.
    static func kinds(_ core: Core) -> [MoonlitMechanismRecordKind] { core.play.records.map(\.kind) }

    /// The entries of `spec` up to and including its first run.
    static func throughFirstRun(_ spec: ScenarioSpec) -> [ScenarioStep] {
        var prefix: [ScenarioStep] = []
        for entry in spec.entries {
            prefix.append(entry)
            if entry.action?.control == "machine.run" { break }
        }
        return prefix
    }

    @Test func theManifestIsAValidRoundTwoGame() {
        let manifest: ScenarioManifest = builtManifest
        let problems: [String] = ScenarioManifestValidator.problems(
            manifest, controls: Core.controls, content: ContentRequirement(fixtures: 3, acceptance: 80, levels: 100))
        #expect(problems.isEmpty, "\(problems)")
        var acceptanceNames: [String] = []
        var rowIDs: [String] = []
        for row in 1...80 {
            acceptanceNames.append(Core.acceptanceName(row))
            rowIDs.append(Core.acceptanceRowID(row))
        }
        #expect(acceptanceNames[0] == "acceptance-001" && acceptanceNames[79] == "acceptance-080")
        #expect(rowIDs[0] == "R2-G14-QA-001" && rowIDs[9] == "R2-G14-QA-010" && rowIDs[79] == "R2-G14-QA-080")
        #expect(Set(rowIDs).count == 80)
        let names: [String] = manifest.scenarios.map(\.name)
        #expect(names == ScenarioManifest.standardNames + ["full-playthrough", "hero"] + acceptanceNames
            + Self.fixtureNames)
        #expect(Set(names).count == names.count)
        #expect(manifest.kind == .game && manifest.round == 2 && manifest.experience == scenarioID)
        let declared: Set<String> = Set(Core.controls.map(\.id))
        for spec in manifest.scenarios {
            if spec.name.hasPrefix("acceptance-") {
                #expect(spec.entries.count >= 2, "\(spec.name)")
            } else {
                #expect(spec.seed == Core.manifestSeed, "\(spec.name)")
            }
            #expect(spec.entries.count <= 64, "\(spec.name) is short")
            for entry in spec.entries {
                if let action = entry.action { #expect(declared.contains(action.control), "\(spec.name)") }
            }
        }
        // The archived rows 1 … 20 name these levels (round2.md: 050, 057, … 099, 006, … 083).
        let named: [Int] = [50, 57, 64, 71, 78, 85, 92, 99, 6, 13, 20, 27, 34, 41, 48, 55, 62, 69, 76, 83]
        #expect(Array(Core.acceptanceLevels.prefix(20)) == named)
        #expect(Core.acceptanceLevels.count == 80 && Set(Core.acceptanceLevels).count == 80)
        #expect(Core.acceptanceFamily(1) == .truth && Core.acceptanceFamily(10) == .truth)
        #expect(Core.acceptanceFamily(11) == .witness && Core.acceptanceFamily(80) == .integration)
        #expect(Core.inputActions.count == 2 && Core.inputActions[1] == Core.inverse(Core.inputActions[0]))
        #expect(!Core.completionEntries.isEmpty && !Core.playthroughEntries.isEmpty && !Core.budgetOutEntries.isEmpty)
        #expect(!Core.heroEntries.isEmpty && Core.rejectionEntries.count >= 20)
        // Every control appears in the manifest (key frames included).
        var used: Set<String> = []
        for spec in manifest.scenarios {
            for entry in spec.entries { if let action = entry.action { used.insert(action.control) } }
        }
        #expect(used == declared, "\(declared.subtracting(used))")
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
            #expect(played.results == expected, "\(spec.name): \(played.results)")
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
        let restoredDigest: String = try digest(of: restored)
        #expect(restoredDigest == played.final)
        #expect(restored == core && restored.play.canRedo)
    }

    @Test func everyGameScenarioAndFixtureEndsInTheStateItsActionsDescribe() async throws {
        let level1: MoonlitMechanismGenerated = try Core.generated(number: 1)
        let certified1: [MoonlitMechanismAction] = Core.certifiedActions(1)
        let moves1: Int = certified1.count - 1
        for spec in builtManifest.scenarios where !spec.name.hasPrefix("acceptance-") {
            let played = try await playScenario(spec)
            let core: Core = try #require(played.core, "\(spec.name)")
            switch spec.name {
            case "launch-first-frame", "suspend-resume", "teardown-reentry", "cancel-prepare", "rejection":
                #expect(core.levelNumber == 1 && core.play.records.isEmpty && core.play.stage == .playing,
                        "\(spec.name)")
                #expect(core.play.actionsSpent == 0 && core.play.phases == level1.level.startingPhases, "\(spec.name)")
                #expect(core.play.height == level1.level.startingHeight && core.shownFrame == 0, "\(spec.name)")
            case "input-response", "save-restore", "reset":
                #expect(core.levelNumber == 1 && core.play.actionsSpent == 1, "\(spec.name)")
                #expect(core.play.stage == .playing && core.outcome == nil && core.play.canRedo, "\(spec.name)")
                #expect(core.play.records.count == 3 && Self.kinds(core)[2] == .undo, "\(spec.name)")
                #expect(core.play.records[0].action == certified1[0], "\(spec.name)")
                #expect(core.play.records[1].action == Core.inverse(certified1[0]), "\(spec.name)")
            case "completion", "fixture-level-1-solved":
                #expect(core.levelNumber == 1 && core.play.stage == .won, "\(spec.name)")
                #expect(core.play.records.map(\.action) == certified1.map { Optional($0) }, "\(spec.name)")
            case "full-playthrough":
                #expect(core.levelNumber == Core.playthroughLevels[Core.playthroughLevels.count - 1])
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
                #expect(core.play.records.map(\.action) == Core.certifiedActions(3).map { Optional($0) })
            case "hero":
                #expect(core.play.records.count == moves1 && core.play.stage == .playing && core.outcome == nil)
                #expect(core.play.report.outcome == .won, "the solved set-up is shown before the run")
            case "fixture-budget-out":
                #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(spec.name)")
                #expect(core.play.failure == .budget(level1.level.budget - 1), "\(spec.name)")
                #expect(core.play.records.count == level1.level.budget, "\(spec.name)")
            case "fixture-undo-redo":
                #expect(core.play.records.count == 3 && !core.play.canRedo)
                #expect(Self.kinds(core).suffix(2) == [.undo, .redo])
                #expect(core.play.actionsSpent == 1 && core.play.stage == .playing)
            default:
                Issue.record("unexpected scenario \(spec.name)")
            }
        }
    }

    @Test func everyAcceptanceRowEndsInTheStateOfItsFamily() async throws {
        var runFailures: Set<String> = []
        for row in 1...80 {
            let level: Int = Core.acceptanceLevel(row)
            let name: String = Core.acceptanceName(row)
            let spec: ScenarioSpec = try #require(builtManifest.scenarios.first { $0.name == name })
            #expect(spec.seed == UInt64(level - 1), "\(name)")
            let played = try await playScenario(spec)
            let core: Core = try #require(played.core, "\(name)")
            let generated: MoonlitMechanismGenerated = try Core.generated(number: level)
            let actions: [MoonlitMechanismAction] = generated.actions
            let opening: String = played.initial
            switch Core.acceptanceFamily(row) {
            case .truth:
                #expect(core.levelNumber == level && played.results.count == 2, "\(name)")
                #expect(played.results[0] == "accepted" && played.results[1] != "accepted", "\(name)")
                switch (row - 1) % 5 {
                case 0:
                    #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(name)")
                    #expect(played.results[1] == Core.stageCode, "\(name)")
                    if let failure = core.play.failure { runFailures.insert(failure.code) }
                case 1:
                    #expect(core.play.stage == .playing && core.play.records.first?.action == .turn(1), "\(name)")
                    let code: String = generated.level.gears.count <= Core.gearRange.upperBound
                        ? Core.kernelActionCode : Core.outOfRangeCode
                    #expect(played.results[1] == code, "\(name): \(played.results[1])")
                case 4:
                    #expect(core.play.stage == .playing && core.play.records.count == 1, "\(name)")
                    #expect(core.play.records[0].kind == .lamp && core.shownFrame == 0, "\(name)")
                    #expect(played.results[1] == Core.frameCode, "\(name): \(played.results[1])")
                default:
                    #expect(core.play.stage == .playing && core.play.records.count == 1, "\(name)")
                    #expect(core.play.records[0].action == actions[0], "\(name)")
                    let code: String = (row - 1) % 5 == 2 ? Core.kernelActionCode : Core.notWholeCode
                    #expect(played.results[1] == code, "\(name): \(played.results[1])")
                }
            case .witness:
                if row % 2 == 1 {
                    #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                    let kinds: [MoonlitMechanismRecordKind] = Self.kinds(core)
                    #expect(kinds.filter { $0 == .undo }.count == 1 && kinds.filter { $0 == .run }.count == 2)
                    #expect(core.play.actionsSpent == actions.count, "\(name)")
                    let witnessed: Core? = Core.played(seed: spec.seed, entries: actions.map { Core.actionEntry($0) })
                    #expect(core.play.phases == witnessed?.play.phases, "\(name): the certified phases")
                    #expect(core.play.height == witnessed?.play.height, "\(name): the certified lamp")
                    let failedRun: Core? = Core.played(seed: spec.seed, entries: Self.throughFirstRun(spec))
                    let failure: MoonlitMechanismFailure = try #require(failedRun?.play.failure, "\(name)")
                    runFailures.insert(failure.code)
                } else {
                    #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(name)")
                    #expect(core.play.failure == .budget(generated.level.budget - 1), "\(name)")
                    #expect(played.results.last == Core.stageCode, "\(name)")
                    runFailures.insert("budget")
                }
            case .numeric:
                #expect(played.final == opening && core.play.stage == .playing, "\(name)")
                #expect(played.results.filter { $0 == Core.outOfRangeCode }.count == 2, "\(name)")
                #expect(played.results.filter { $0 == Core.kernelActionCode }.count >= 2, "\(name)")
                #expect(Self.kinds(core).suffix(2) == [.undo, .undo] && core.play.actionsSpent == 0, "\(name)")
                let gears: Int = generated.level.gears.count
                #expect(core.play.records[0].action == .reseat(1, -1), "\(name): the lowest gear and step")
                #expect(core.play.records[1].action == .reseat(gears - 1, 1), "\(name): the highest gear and step")
                let reseated: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.prefix(1)))
                let teeth: Int = generated.level.gears[1].teeth
                let start: Int = generated.level.startingPhases[1]
                #expect(reseated?.play.phases[1] == (start + teeth - 1) % teeth, "\(name): the phase wraps")
            case .touch:
                let moved: String = try #require(Core.expectedDigest(for: scenarioID, seed: spec.seed,
                                                                     entries: [Core.actionEntry(actions[0])]))
                #expect(played.final == moved && played.final != opening, "\(name)")
                #expect(Self.kinds(core).suffix(2) == [.undo, .redo] && core.play.records.count == 3, "\(name)")
                #expect(core.shownFrame == generated.level.keyFrames.count - 1, "\(name): the last key frame shown")
                #expect(played.results.last == Core.kernelActionCode, "\(name)")
            case .rendering:
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                #expect(core.play.records.map(\.action) == actions.map { Optional($0) }, "\(name)")
                #expect(played.results.last == Core.stageCode, "\(name)")
                var tiered: Core = core
                for tier in 0..<Core.qualityTiers {
                    tiered.setQualityTier(tier)
                    _ = tiered.snapshot(time: Double(tier) * 0.75)
                    #expect(try digest(of: tiered) == played.final, "\(name): tier \(tier)")
                }
            case .accessibility:
                #expect(core.play.stage == .playing && core.outcome == nil, "\(name)")
                #expect(Self.kinds(core).suffix(2) == [.run, .undo], "\(name)")
                let beforeRun: [ScenarioStep] = Array(Self.throughFirstRun(spec).dropLast())
                let retry: String = try #require(Core.expectedDigest(for: scenarioID, seed: spec.seed,
                                                                     entries: beforeRun))
                #expect(played.final == retry, "\(name): the honest retry")
                if row % 2 == 1 { #expect(played.final == opening, "\(name)") }
                let failedRun: Core? = Core.played(seed: spec.seed, entries: Self.throughFirstRun(spec))
                let failure: MoonlitMechanismFailure = try #require(failedRun?.play.failure, "\(name)")
                runFailures.insert(failure.code)
            case .persistence:
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                #expect(Self.kinds(core)[1] == .undo && Self.kinds(core)[2] == .redo, "\(name)")
                let restored: Core = try Core.restore(payload: core.snapshotPayload(), seed: spec.seed)
                let restoredDigest: String = try digest(of: restored)
                #expect(restored == core && restoredDigest == played.final, "\(name)")
            case .integration:
                // Feature 435: `level.next` needs the next level open, so the row first wins its level's witness; on
                // level 100 `level.next` is refused `r02-g14.locked` (no wrap) and level 1 is chosen instead.
                let next: Int = Core.nextLevel(after: level)
                #expect(core.levelNumber == next && core.play.stage == .playing, "\(name)")
                #expect(Self.kinds(core).count == 2 && Self.kinds(core)[1] == .undo, "\(name)")
                #expect(core.play.actionsSpent == 0, "\(name)")
                #expect(core.mode == .campaign && core.progress.solved[level] != nil, "\(name)")
                let move: [ScenarioStep] = Core.integrationMoveEntries(level)
                var won: [ScenarioStep] = []
                for action in actions { won.append(Core.actionEntry(action)) }
                won += move
                let nextFresh: String = try #require(Core.expectedDigest(for: scenarioID, seed: spec.seed,
                                                                         entries: won))
                #expect(played.final == nextFresh, "\(name)")
                var results: [String] = []
                for _ in actions { results.append("accepted") }
                if level == Core.levelNumbers.upperBound {
                    #expect(core.progress.frontier == Core.levelNumbers.upperBound, "\(name)")
                    results += [Core.lockedCode, "accepted"]
                } else {
                    #expect(core.progress.frontier == next, "\(name)")
                    results.append("accepted")
                }
                results += ["accepted", "accepted", Core.kernelActionCode]
                #expect(played.results == results, "\(name)")
            }
        }
        #expect(runFailures == ["budget", "forbidden", "jammed", "missing"], "\(runFailures)")
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
