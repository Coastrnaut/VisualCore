// StarlitCartoucheScenariosTests — feature 453 (R02-G16-03) T-R02G1603-006 (FR-R02G1603-005, 008). The scenario
// manifest of Starlit Cartouche: a valid round-two game manifest with the nine standard scenarios, `full-playthrough`,
// `hero`, the 80 acceptance scenarios (rows R2-G16-QA-001 … 080, in order, on 80 distinct levels, the first twenty the
// levels the archived rows name) and three fixtures; its derived digests, results and outcomes equal to what
// `ExperienceEngine` gives when played as the runner plays them; the save-restore state survives a restore; every
// standard scenario and fixture ends in the kernel state its actions describe; every acceptance row ends in the state
// of its family (a refusal with the kernel's or the adapter's code, a perturbed plan recovered, an exhausted path
// refused further legs, a won plan whose digest no quality tier changes, undo and redo restoring digests, a chosen
// destination that leaves the digest alone, a failing leg undone — `window`, `hazard`, `deadline` and `stroke` all
// reached — the next level's opening digest); and the committed `scenario-manifest.json` equal to the Swift manifest
// (`UPDATE_SCENARIO_MANIFEST=1` rewrites it). Host-run (`swift test`); explicit types, plain loops.
#if DEBUG || VISUALCORE_AUTOMATION
@testable import StarlitCartoucheCore
import Foundation
import Testing
import VisualCoreExperience

/// The id of the manifest's experience.
private let scenarioID: ExperienceID = ExperienceID(rawValue: StarlitCartoucheExperienceCore.experienceID)!

/// The manifest, built once per test process (it certifies 80 levels and more).
private let builtManifest: ScenarioManifest = StarlitCartoucheExperienceCore.manifest(for: scenarioID)

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playScenario(_ spec: ScenarioSpec) async throws
    -> (initial: String, results: [String], final: String, core: StarlitCartoucheExperienceCore?) {
    var engine: ExperienceEngine<StarlitCartoucheExperienceCore> =
        ExperienceEngine<StarlitCartoucheExperienceCore>(id: scenarioID)
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
private func digest(of core: StarlitCartoucheExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: scenarioID.rawValue)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

@Suite struct StarlitCartoucheScenariosTests {
    typealias Core = StarlitCartoucheExperienceCore

    /// The names of the three fixtures.
    static let fixtureNames: [String] = ["fixture-level-1-solved", "fixture-leg-fails", "fixture-undo-redo"]

    /// The record kinds of `core`'s play.
    static func kinds(_ core: Core) -> [StarlitCartoucheRecordKind] { core.play.records.map(\.kind) }

    /// The legs recorded in `core`'s play, in order (undo and redo records left out).
    static func legs(_ core: Core) -> [StarlitCartoucheAction] {
        var actions: [StarlitCartoucheAction] = []
        for record in core.play.records { if let action = record.action { actions.append(action) } }
        return actions
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
        #expect(rowIDs[0] == "R2-G16-QA-001" && rowIDs[9] == "R2-G16-QA-010" && rowIDs[79] == "R2-G16-QA-080")
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
        // The archived rows 1 … 20 name these levels (round2.md: 056, 063, … 098, 005, … 089).
        let named: [Int] = [56, 63, 70, 77, 84, 91, 98, 5, 12, 19, 26, 33, 40, 47, 54, 61, 68, 75, 82, 89]
        #expect(Array(Core.acceptanceLevels.prefix(20)) == named)
        #expect(Core.acceptanceLevels.count == 80 && Set(Core.acceptanceLevels).count == 80)
        #expect(Core.acceptanceFamily(1) == .truth && Core.acceptanceFamily(10) == .truth)
        #expect(Core.acceptanceFamily(11) == .witness && Core.acceptanceFamily(80) == .integration)
        #expect(Core.inputActions.count == 2 && Core.inputActions[0] == Core.probeMove(1))
        #expect(Core.inputActions[1] == Core.secondMove(1))
        #expect(!Core.completionEntries.isEmpty && !Core.playthroughEntries.isEmpty && !Core.legFailsEntries.isEmpty)
        #expect(!Core.heroEntries.isEmpty && Core.rejectionEntries.count >= 20)
        // Every control appears in the manifest.
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
        let level1: StarlitCartoucheGenerated = try Core.generated(number: 1)
        let certified1: [StarlitCartoucheAction] = Core.certifiedActions(1)
        let probe1: StarlitCartoucheAction = try #require(Core.probeMove(1))
        let second1: StarlitCartoucheAction = try #require(Core.secondMove(1))
        let last1: StarlitCartoucheAction = try #require(certified1.last)
        let start: Int = level1.level.start
        for spec in builtManifest.scenarios where !spec.name.hasPrefix("acceptance-") {
            let played = try await playScenario(spec)
            let core: Core = try #require(played.core, "\(spec.name)")
            switch spec.name {
            case "launch-first-frame", "suspend-resume", "teardown-reentry", "cancel-prepare", "rejection":
                #expect(core.levelNumber == 1 && core.play.records.isEmpty && core.play.stage == .playing,
                        "\(spec.name)")
                #expect(core.play.actionsSpent == 0 && core.play.beat == 0 && core.play.star == start, "\(spec.name)")
                #expect(core.chosenStar == StarlitCartoucheSceneSnapshot.defaultChoice(level1.level, star: start),
                        "\(spec.name)")
                #expect(core.chosenWait == 0, "\(spec.name)")
            case "input-response", "save-restore", "reset":
                #expect(core.levelNumber == 1 && core.play.actionsSpent == 1, "\(spec.name)")
                #expect(core.play.stage == .playing && core.outcome == nil && core.play.canRedo, "\(spec.name)")
                #expect(core.play.records.count == 3 && Self.kinds(core)[2] == .undo, "\(spec.name)")
                #expect(core.play.records[0].action == probe1, "\(spec.name)")
                #expect(core.play.records[1].action == second1, "\(spec.name)")
            case "completion", "fixture-level-1-solved":
                #expect(core.levelNumber == 1 && core.play.stage == .won, "\(spec.name)")
                #expect(core.play.records.map(\.action) == certified1.map { Optional($0) }, "\(spec.name)")
            case "full-playthrough":
                #expect(core.levelNumber == Core.playthroughLevels[Core.playthroughLevels.count - 1])
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
                #expect(core.play.records.map(\.action) == Core.certifiedActions(3).map { Optional($0) })
            case "hero":
                #expect(core.play.records.count == certified1.count - 1 && core.play.stage == .playing)
                #expect(core.outcome == nil && !core.play.report.matched, "the play is still open")
                #expect(core.chosenStar == Core.destination(of: last1) && core.chosenWait == Core.wait(of: last1),
                        "the leg that completes the cartouche is chosen")
            case "fixture-leg-fails":
                #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(spec.name)")
                let failure: StarlitCartoucheFailure = try #require(core.play.failure, "\(spec.name)")
                #expect(failure.code != "budget", "\(spec.name): the chart fails the leg")
                #expect(core.play.records.count == spec.entries.count, "\(spec.name)")
            case "fixture-undo-redo":
                #expect(core.play.records.count == 3 && !core.play.canRedo)
                #expect(Self.kinds(core).suffix(2) == [.undo, .redo])
                #expect(core.play.actionsSpent == 1 && core.play.stage == .playing)
            default:
                Issue.record("unexpected scenario \(spec.name)")
            }
        }
    }

    /// Checks truth row `row` (see the source's header); `level` is its level.
    static func checkTruth(row: Int, level: Int, played: (results: [String], core: Core), probe: StarlitCartoucheAction,
                           stars: Int) {
        let core: Core = played.core
        let name: String = Core.acceptanceName(row)
        #expect(core.levelNumber == level && played.results.count == 2, "\(name)")
        #expect(played.results[0] == "accepted" && played.results[1] != "accepted", "\(name)")
        #expect(core.play.stage == .playing, "\(name)")
        switch (row - 1) % 5 {
        case 1:
            let code: String = stars <= Core.starRange.upperBound ? Core.kernelActionCode : Core.outOfRangeCode
            #expect(played.results[1] == code, "\(name): \(played.results[1])")
            #expect(Self.legs(core) == [probe], "\(name)")
        case 2:
            #expect(core.play.records.isEmpty, "\(name)")
            #expect(core.chosenStar == Core.destination(of: probe) && core.chosenWait == Core.wait(of: probe),
                    "\(name)")
            #expect(played.results[1] == Core.choiceCode, "\(name): \(played.results[1])")
        case 3:
            #expect(Self.legs(core) == [probe], "\(name)")
            #expect(played.results[1] == Core.notWholeCode, "\(name): \(played.results[1])")
        default:
            #expect(Self.legs(core) == [probe], "\(name)")
            #expect(played.results[1] == Core.kernelActionCode, "\(name): \(played.results[1])")
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
            let generated: StarlitCartoucheGenerated = try Core.generated(number: level)
            let actions: [StarlitCartoucheAction] = generated.plan.legs
            let stars: Int = generated.level.stars.count
            let opening: String = played.initial
            switch Core.acceptanceFamily(row) {
            case .truth:
                let probe: StarlitCartoucheAction = try #require(Core.probeMove(level), "\(name)")
                Self.checkTruth(row: row, level: level, played: (played.results, core), probe: probe, stars: stars)
            case .witness:
                if row % 2 == 1 {
                    #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                    let kinds: [StarlitCartoucheRecordKind] = Self.kinds(core)
                    #expect(kinds.filter { $0 == .undo }.count == 1 && kinds.last == .leg, "\(name)")
                    #expect(core.play.actionsSpent == actions.count, "\(name)")
                    var planEntries: [ScenarioStep] = []
                    for action in actions { planEntries.append(Core.actionEntry(action)) }
                    let witnessed: Core? = Core.played(seed: spec.seed, entries: planEntries)
                    #expect(core.play.legs == witnessed?.play.legs, "\(name): the certified legs")
                    let perturbed: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.dropLast(2)))
                    #expect(perturbed?.play.stage != .won, "\(name): the perturbed plan does not win")
                    if let failure = perturbed?.play.failure { runFailures.insert(failure.code) }
                } else {
                    #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(name)")
                    #expect(played.results.last == Core.stageCode, "\(name)")
                    #expect(Self.legs(core) == Core.exhaustedPath(level), "\(name): the exhausted path")
                    let failure: StarlitCartoucheFailure = try #require(core.play.failure, "\(name)")
                    #expect(Core.budgetPath(level).isEmpty == (failure.code != "budget"), "\(name)")
                    runFailures.insert(failure.code)
                }
            case .numeric:
                #expect(played.final == opening && core.play.stage == .playing, "\(name)")
                #expect(played.results.filter { $0 == Core.outOfRangeCode }.count == 2, "\(name)")
                #expect(played.results.filter { $0 == Core.kernelActionCode }.count >= 1, "\(name)")
                #expect(played.results.filter { $0 == Core.notWholeCode }.count == 1, "\(name)")
                #expect(Self.kinds(core) == [.leg, .undo] && core.play.actionsSpent == 0, "\(name)")
                let ends: (highest: Int, lowest: Int) = Core.endpointStars(core.play)
                let highest: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.prefix(1)))
                #expect(highest?.chosenStar == ends.highest && highest?.chosenWait == 8, "\(name): the highest")
                let lowest: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.prefix(2)))
                #expect(lowest?.chosenStar == ends.lowest && lowest?.chosenWait == 0, "\(name): the lowest")
                #expect(ends.highest == stars - 1 || ends.highest == stars - 2, "\(name)")
            case .touch:
                let probe: StarlitCartoucheAction = try #require(Core.probeMove(level), "\(name)")
                let moved: String = try #require(Core.expectedDigest(for: scenarioID, seed: spec.seed,
                                                                     entries: [Core.actionEntry(probe)]))
                #expect(played.final == moved && played.final != opening, "\(name)")
                #expect(Self.kinds(core).suffix(2) == [.undo, .redo] && core.play.records.count == 3, "\(name)")
                #expect(core.chosenStar == generated.level.start && core.chosenWait == 0, "\(name): the start chosen")
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
                #expect(Self.kinds(core).suffix(2) == [.leg, .undo], "\(name)")
                let beforeFailure: [ScenarioStep] = Array(spec.entries.dropLast(2))
                let retry: String = try #require(Core.expectedDigest(for: scenarioID, seed: spec.seed,
                                                                     entries: beforeFailure))
                #expect(played.final == retry, "\(name): the honest retry")
                let failedPlay: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.dropLast()))
                let failure: StarlitCartoucheFailure = try #require(failedPlay?.play.failure, "\(name)")
                #expect(failure.code != "budget", "\(name)")
                runFailures.insert(failure.code)
            case .persistence:
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                #expect(Array(Self.kinds(core).prefix(4)) == [.leg, .undo, .redo, .undo], "\(name)")
                let restored: Core = try Core.restore(payload: core.snapshotPayload(), seed: spec.seed)
                let restoredDigest: String = try digest(of: restored)
                #expect(restored == core && restoredDigest == played.final, "\(name)")
            case .integration:
                let next: Int = Core.nextLevel(after: level)
                #expect(core.levelNumber == next && core.play.stage == .playing, "\(name)")
                let nextOpening: String = try #require(Core.expectedDigest(for: scenarioID, seed: UInt64(next - 1),
                                                                           entries: []))
                #expect(played.final == nextOpening, "\(name)")
                #expect(played.results == ["accepted", "accepted", "accepted", Core.kernelActionCode], "\(name)")
            }
        }
        // Every chart failure is reached; none of the even witness rows' levels can spend its budget cleanly.
        #expect(runFailures == ["window", "hazard", "deadline", "stroke"], "\(runFailures)")
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
