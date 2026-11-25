// CelestialEclipseLabScenariosTests — feature 463 (R02-G17-03) T-R02G1703-006 (FR-R02G1703-005, 008). The scenario
// manifest of Celestial Eclipse Lab: a valid round-two game manifest with the nine standard scenarios,
// `full-playthrough`, `hero`, the 80 acceptance scenarios (rows R2-G17-QA-001 … 080, in order, on 80 distinct levels,
// the first twenty the levels the archived rows name) and three fixtures; its derived digests, results and outcomes
// equal to what `ExperienceEngine` gives when played as the runner plays them; the save-restore state survives a
// restore; every standard scenario and fixture ends in the kernel state its actions describe; every acceptance row ends
// in the state of its family (a refusal with the kernel's or the adapter's code, a perturbed plan recovered, an
// exhausted budget refused further changes, a won plan whose digest no quality tier changes, undo and redo restoring
// digests, a chosen body and shown tick that leave the digest alone, a failing run undone — `unwanted` and `window`
// both reached — the won level recorded and the next level's fresh play); and the committed `scenario-manifest.json`
// equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1` rewrites it). Host-run (`swift test`); explicit types,
// plain loops. Feature 465 (R02-G17-05) T-R02G1705-004: the integration rows win their level before `level.next` (the
// next open level).
#if DEBUG || VISUALCORE_AUTOMATION
@testable import CelestialEclipseLabCore
import Foundation
import Testing
import VisualCoreExperience

/// The id of the manifest's experience.
private let scenarioID: ExperienceID = ExperienceID(rawValue: CelestialEclipseLabExperienceCore.experienceID)!

/// The manifest, built once per test process (it certifies 80 levels and more).
private let builtManifest: ScenarioManifest = CelestialEclipseLabExperienceCore.manifest(for: scenarioID)

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playScenario(_ spec: ScenarioSpec) async throws
    -> (initial: String, results: [String], final: String, core: CelestialEclipseLabExperienceCore?) {
    var engine: ExperienceEngine<CelestialEclipseLabExperienceCore> =
        ExperienceEngine<CelestialEclipseLabExperienceCore>(id: scenarioID)
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
private func digest(of core: CelestialEclipseLabExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: scenarioID.rawValue)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

@Suite struct CelestialEclipseLabScenariosTests {
    typealias Core = CelestialEclipseLabExperienceCore

    /// The names of the three fixtures.
    static let fixtureNames: [String] = ["fixture-level-1-solved", "fixture-run-fails", "fixture-undo-redo"]

    /// The record kinds of `core`'s play after its opening records (begin and the tutorial's dismissal).
    static func kinds(_ core: Core) -> [CelestialEclipseLabRecordKind] {
        var result: [CelestialEclipseLabRecordKind] = []
        for record in core.play.records where record.kind != .begin && record.kind != .dismissTutorial {
            result.append(record.kind)
        }
        return result
    }

    /// The kernel actions recorded in `core`'s play, in order (undo, redo and event records left out).
    static func actions(_ core: Core) -> [CelestialEclipseLabAction] {
        var result: [CelestialEclipseLabAction] = []
        for record in core.play.records { if let action = record.action { result.append(action) } }
        return result
    }

    /// The phase changes of manifest number `number`'s plan followed by the run.
    static func winning(_ number: Int) -> [CelestialEclipseLabAction] {
        Core.certifiedActions(number) + [.run]
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
        #expect(rowIDs[0] == "R2-G17-QA-001" && rowIDs[9] == "R2-G17-QA-010" && rowIDs[79] == "R2-G17-QA-080")
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
        // The archived rows 1 … 20 name these levels (round2.md: 059, 066, … 094, 001, … 092).
        let named: [Int] = [59, 66, 73, 80, 87, 94, 1, 8, 15, 22, 29, 36, 43, 50, 57, 64, 71, 78, 85, 92]
        #expect(Array(Core.acceptanceLevels.prefix(20)) == named)
        #expect(Core.acceptanceLevels.count == 80 && Set(Core.acceptanceLevels).count == 80)
        #expect(Core.acceptanceFamily(1) == .truth && Core.acceptanceFamily(10) == .truth)
        #expect(Core.acceptanceFamily(11) == .witness && Core.acceptanceFamily(80) == .integration)
        #expect(Core.inputActions.count == 2 && Core.inputActions[0] == Core.probeMove(1))
        #expect(Core.inputActions[1] == Core.secondMove(1))
        #expect(Core.probeMove(1) == Core.certifiedActions(1).first)
        #expect(!Core.completionEntries.isEmpty && !Core.playthroughEntries.isEmpty && !Core.runFailsEntries.isEmpty)
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
        let level1: CelestialEclipseLabGenerated = try Core.generated(number: 1)
        let certified1: [CelestialEclipseLabAction] = Core.certifiedActions(1)
        let probe1: CelestialEclipseLabAction = try #require(Core.probeMove(1))
        let second1: CelestialEclipseLabAction = try #require(Core.secondMove(1))
        let last1: CelestialEclipseLabAction = try #require(certified1.last)
        let heroTick: Int = try #require(Core.heroTick(1))
        let start: [Int] = level1.level.phases
        for spec in builtManifest.scenarios where !spec.name.hasPrefix("acceptance-") {
            let played = try await playScenario(spec)
            let core: Core = try #require(played.core, "\(spec.name)")
            switch spec.name {
            case "launch-first-frame", "suspend-resume", "teardown-reentry", "cancel-prepare", "rejection":
                #expect(core.levelNumber == 1 && Self.kinds(core).isEmpty && core.play.stage == .playing,
                        "\(spec.name)")
                #expect(core.play.actionsSpent == 0 && core.play.phases == start, "\(spec.name)")
                #expect(core.chosenBody == CelestialEclipseLabSceneSnapshot.defaultChoice(level1.level),
                        "\(spec.name)")
                #expect(core.shownTick == 0, "\(spec.name)")
            case "input-response", "save-restore", "reset":
                #expect(core.levelNumber == 1 && core.play.actionsSpent == 1, "\(spec.name)")
                #expect(core.play.stage == .playing && core.outcome == nil && core.play.canRedo, "\(spec.name)")
                #expect(Self.kinds(core) == [.phase, .phase, .undo], "\(spec.name)")
                #expect(Self.actions(core) == [probe1, second1], "\(spec.name)")
            case "completion", "fixture-level-1-solved":
                #expect(core.levelNumber == 1 && core.play.stage == .won, "\(spec.name)")
                #expect(Self.actions(core) == Self.winning(1), "\(spec.name)")
            case "full-playthrough":
                #expect(core.levelNumber == Core.playthroughLevels[Core.playthroughLevels.count - 1])
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
                #expect(Self.actions(core) == Self.winning(3))
            case "hero":
                #expect(Self.actions(core) == certified1 && core.play.stage == .playing)
                #expect(core.outcome == nil && core.play.timeline.wins, "the play is open and a run would win")
                #expect(core.chosenBody == Core.phaseBody(of: last1), "the last body the plan moves is chosen")
                #expect(core.shownTick == heroTick, "the hero tick is shown")
                let snapshot: CelestialEclipseLabSceneSnapshot = core.snapshot(time: 0)
                #expect(snapshot.shownTick == heroTick && snapshot.isWon == false)
                #expect(!snapshot.eclipses.isEmpty, "an eclipse is under way at the hero tick")
            case "fixture-run-fails":
                #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(spec.name)")
                let failure: CelestialEclipseLabFailure = try #require(core.play.failure, "\(spec.name)")
                #expect(["unwanted", "window", "horizon"].contains(failure.code), "\(spec.name)")
                #expect(Self.kinds(core) == [.run] && core.play.phases == start, "\(spec.name)")
            case "fixture-undo-redo":
                #expect(Self.kinds(core) == [.phase, .undo, .redo] && !core.play.canRedo)
                #expect(core.play.actionsSpent == 1 && core.play.stage == .playing)
            default:
                Issue.record("unexpected scenario \(spec.name)")
            }
        }
    }

    /// Checks truth row `row` (see the source's header); `level` is its level.
    static func checkTruth(row: Int, level: Int, played: (results: [String], core: Core),
                           probe: CelestialEclipseLabAction, generated: CelestialEclipseLabGenerated) {
        let core: Core = played.core
        let name: String = Core.acceptanceName(row)
        #expect(core.levelNumber == level && played.results.count == 2, "\(name)")
        #expect(played.results[0] == "accepted" && played.results[1] != "accepted", "\(name)")
        #expect(core.play.stage == .playing, "\(name)")
        switch (row - 1) % 5 {
        case 1:
            #expect(played.results[1] == Core.kernelActionCode, "\(name): every period is at most 23")
            #expect(Self.actions(core) == [probe], "\(name)")
        case 2:
            let code: String = generated.level.bodies.count <= Core.bodyRange.upperBound
                ? Core.choiceCode : Core.outOfRangeCode
            #expect(Self.kinds(core).isEmpty, "\(name)")
            #expect(core.chosenBody == Core.phaseBody(of: probe), "\(name)")
            #expect(played.results[1] == code, "\(name): \(played.results[1])")
        case 3:
            #expect(Self.actions(core) == [probe], "\(name)")
            #expect(played.results[1] == Core.notWholeCode, "\(name): \(played.results[1])")
        case 4:
            #expect(Self.actions(core) == [probe] && core.shownTick == 0, "\(name)")
            #expect(played.results[1] == Core.tickCode, "\(name): \(played.results[1])")
        default:
            #expect(Self.actions(core) == [probe], "\(name)")
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
            let generated: CelestialEclipseLabGenerated = try Core.generated(number: level)
            let actions: [CelestialEclipseLabAction] = generated.plan.actions
            let opening: String = played.initial
            switch Core.acceptanceFamily(row) {
            case .truth:
                let probe: CelestialEclipseLabAction = try #require(Core.probeMove(level), "\(name)")
                Self.checkTruth(row: row, level: level, played: (played.results, core), probe: probe,
                                generated: generated)
            case .witness:
                if row % 2 == 1 {
                    #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                    let kinds: [CelestialEclipseLabRecordKind] = Self.kinds(core)
                    #expect(kinds.filter { $0 == .undo }.count == 2 && kinds.last == .run, "\(name)")
                    #expect(kinds.filter { $0 == .run }.count == 2, "\(name): a failed run, then the winning one")
                    #expect(core.play.actionsSpent == actions.count, "\(name)")
                    #expect(core.play.phases == generated.plan.phases(from: generated.level), "\(name): the plan")
                    let perturbed: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.dropLast(4)))
                    #expect(perturbed?.play.stage == .failed, "\(name): the perturbed plan fails")
                    if let failure = perturbed?.play.failure { runFailures.insert(failure.code) }
                } else {
                    #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(name)")
                    let path: [CelestialEclipseLabAction] = Core.exhaustedPath(level)
                    #expect(path.count == generated.level.budget && core.play.actionsLeft == 0, "\(name)")
                    #expect(Self.actions(core) == path + [.run], "\(name): the exhausted path")
                    let tail: [String] = Array(played.results.suffix(3))
                    #expect(tail == [Core.budgetCode, "accepted", Core.stageCode], "\(name): \(tail)")
                    let failure: CelestialEclipseLabFailure = try #require(core.play.failure, "\(name)")
                    runFailures.insert(failure.code)
                }
            case .numeric:
                #expect(played.final == opening && core.play.stage == .playing, "\(name)")
                #expect(played.results.filter { $0 == Core.outOfRangeCode }.count == 2, "\(name)")
                #expect(played.results.filter { $0 == Core.kernelActionCode }.count >= 1, "\(name)")
                #expect(played.results.filter { $0 == Core.notWholeCode }.count == 1, "\(name)")
                #expect(played.results.filter { $0 == Core.tickCode }.count == 1, "\(name)")
                #expect(Self.kinds(core) == [.phase, .undo] && core.play.actionsSpent == 0, "\(name)")
                let ends: (highest: Int, lowest: Int) = Core.endpointBodies(core.play)
                let highest: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.prefix(1)))
                #expect(highest?.chosenBody == ends.highest, "\(name): the highest body")
                let lowest: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.prefix(2)))
                #expect(lowest?.chosenBody == ends.lowest, "\(name): the lowest body")
                let last: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.prefix(3)))
                #expect(last?.shownTick == generated.level.horizon - 1, "\(name): the last tick")
                #expect(core.shownTick == 0 && core.chosenBody == 0, "\(name): the first tick, the lowest body")
                #expect(ends.highest == generated.level.bodies.count - 1, "\(name)")
            case .touch:
                let probe: CelestialEclipseLabAction = try #require(Core.probeMove(level), "\(name)")
                let moved: String = try #require(Core.expectedDigest(for: scenarioID, seed: spec.seed,
                                                                     entries: [Core.actionEntry(probe)]))
                #expect(played.final == moved && played.final != opening, "\(name)")
                #expect(Self.kinds(core) == [.phase, .undo, .redo], "\(name)")
                #expect(core.chosenBody == Core.phaseBody(of: probe), "\(name): the probe body chosen")
                #expect(core.shownTick == generated.level.horizon / 2, "\(name): the middle tick shown")
                #expect(played.results.last == Core.kernelActionCode, "\(name)")
            case .rendering:
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                #expect(Self.actions(core) == Self.winning(level), "\(name)")
                #expect(played.results.last == Core.stageCode, "\(name)")
                var tiered: Core = core
                for tier in 0..<Core.qualityTiers {
                    tiered.setQualityTier(tier)
                    let snapshot: CelestialEclipseLabSceneSnapshot = tiered.snapshot(time: Double(tier) * 0.75)
                    #expect(snapshot.isWon && snapshot.matched == generated.level.target.count, "\(name)")
                    #expect(try digest(of: tiered) == played.final, "\(name): tier \(tier)")
                }
            case .accessibility:
                #expect(core.play.stage == .playing && core.outcome == nil, "\(name)")
                #expect(Self.kinds(core).suffix(2) == [.run, .undo], "\(name)")
                let beforeRun: [ScenarioStep] = Array(spec.entries.dropLast(2))
                let retry: String = try #require(Core.expectedDigest(for: scenarioID, seed: spec.seed,
                                                                     entries: beforeRun))
                #expect(played.final == retry, "\(name): the honest retry")
                let failedPlay: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.dropLast()))
                #expect(failedPlay?.play.stage == .failed, "\(name)")
                let failure: CelestialEclipseLabFailure = try #require(failedPlay?.play.failure, "\(name)")
                runFailures.insert(failure.code)
            case .persistence:
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                #expect(Array(Self.kinds(core).prefix(4)) == [.phase, .undo, .redo, .undo], "\(name)")
                let restored: Core = try Core.restore(payload: core.snapshotPayload(), seed: spec.seed)
                let restoredDigest: String = try digest(of: restored)
                #expect(restored == core && restoredDigest == played.final, "\(name)")
            case .integration:
                // Feature 465: `level.next` needs the next level open, so the row first wins its level's plan; on
                // level 100 `level.next` is refused `r02-g17.locked` (no wrap) and level 1 is chosen instead.
                let next: Int = Core.nextLevel(after: level)
                #expect(core.levelNumber == next && core.play.stage == .playing, "\(name)")
                #expect(Self.kinds(core) == [.phase, .undo] && core.play.actionsSpent == 0, "\(name)")
                #expect(core.mode == .campaign && core.progress.solved[level] != nil, "\(name)")
                var won: [ScenarioStep] = Core.winningEntries(level)
                won += Core.integrationMoveEntries(level)
                let nextFresh: String = try #require(Core.expectedDigest(for: scenarioID, seed: spec.seed,
                                                                         entries: won))
                #expect(played.final == nextFresh, "\(name)")
                var results: [String] = []
                for _ in 0...actions.count { results.append("accepted") }
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
        // The runs fail with an unwanted eclipse and with a target outside its window; no scripted run of these
        // levels runs out of horizon (a prefix of a minimal plan with at most one more change, the even witness
        // rows' toggled settings), so `horizon` is not reached here.
        #expect(runFailures == ["unwanted", "window"], "\(runFailures)")
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
