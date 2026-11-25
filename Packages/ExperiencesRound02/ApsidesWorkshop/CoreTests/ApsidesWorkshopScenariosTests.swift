// ApsidesWorkshopScenariosTests — feature 473 (R02-G18-03) T-R02G1803-006 (FR-R02G1803-005, 008). The scenario
// manifest of Apsides Workshop: a valid round-two game manifest with the nine standard scenarios, `full-playthrough`,
// `hero`, the 80 acceptance scenarios (rows R2-G18-QA-001 … 080, in order, on 80 distinct levels, the first twenty the
// levels the archived rows name) and three fixtures; its derived digests, results and outcomes equal to what
// `ExperienceEngine` gives when played as the runner plays them; the save-restore state survives a restore; every
// standard scenario and fixture ends in the kernel state its actions describe; every acceptance row ends in the state
// of its family (a refusal with the engine's, the kernel's or the adapter's code, a perturbed plan recovered, an
// exhausted budget refusing further tunings, a won plan whose digest no quality tier changes, undo and redo restoring
// digests, a shown tick that leaves the digest alone, a failing play undone, the next level's opening digest); and the
// committed `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1` rewrites it). Host-run
// (`swift test`); explicit types, plain loops. Modelled on `CelestialEclipseLabScenariosTests` (feature 463).
#if DEBUG || VISUALCORE_AUTOMATION
@testable import ApsidesWorkshopCore
import Foundation
import Testing
import VisualCoreExperience

/// The id of the manifest's experience.
private let scenarioID: ExperienceID = ExperienceID(rawValue: ApsidesWorkshopExperienceCore.experienceID)!

/// The manifest, built once per test process (it certifies 80 levels and more).
private let builtManifest: ScenarioManifest = ApsidesWorkshopExperienceCore.manifest(for: scenarioID)

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playScenario(_ spec: ScenarioSpec) async throws
    -> (initial: String, results: [String], final: String, core: ApsidesWorkshopExperienceCore?) {
    var engine: ExperienceEngine<ApsidesWorkshopExperienceCore> =
        ExperienceEngine<ApsidesWorkshopExperienceCore>(id: scenarioID)
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
private func digest(of core: ApsidesWorkshopExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: scenarioID.rawValue)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

@Suite struct ApsidesWorkshopScenariosTests {
    typealias Core = ApsidesWorkshopExperienceCore

    /// The names of the three fixtures.
    static let fixtureNames: [String] = ["fixture-level-1-solved", "fixture-run-fails", "fixture-undo-redo"]

    /// The record kinds of `core`'s play after its opening records (begin and the tutorial's dismissal).
    static func kinds(_ core: Core) -> [ApsidesWorkshopRecordKind] {
        var result: [ApsidesWorkshopRecordKind] = []
        for record in core.play.records where record.kind != .begin && record.kind != .dismissTutorial {
            result.append(record.kind)
        }
        return result
    }

    /// The number of `kind` among `kinds`.
    static func count(_ kind: ApsidesWorkshopRecordKind, in kinds: [ApsidesWorkshopRecordKind]) -> Int {
        var total: Int = 0
        for each in kinds where each == kind { total += 1 }
        return total
    }

    /// The number of `code` among `results`.
    static func count(_ code: String, in results: [String]) -> Int {
        var total: Int = 0
        for each in results where each == code { total += 1 }
        return total
    }

    /// The kernel actions recorded in `core`'s play, in order (undo, redo and event records left out).
    static func actions(_ core: Core) -> [ApsidesWorkshopAction] {
        var result: [ApsidesWorkshopAction] = []
        for record in core.play.records { if let action = record.action { result.append(action) } }
        return result
    }

    /// The tunings of manifest number `number`'s plan followed by the play.
    static func winning(_ number: Int) -> [ApsidesWorkshopAction] {
        Core.certifiedActions(number) + [.play]
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
        #expect(rowIDs[0] == "R2-G18-QA-001" && rowIDs[9] == "R2-G18-QA-010" && rowIDs[79] == "R2-G18-QA-080")
        #expect(Set(rowIDs).count == 80)
        var names: [String] = []
        for spec in manifest.scenarios { names.append(spec.name) }
        #expect(names == ScenarioManifest.standardNames + ["full-playthrough", "hero"] + acceptanceNames
            + Self.fixtureNames)
        #expect(Set(names).count == names.count)
        #expect(manifest.kind == .game && manifest.round == 2 && manifest.experience == scenarioID)
        var declared: Set<String> = []
        for control in Core.controls { declared.insert(control.id) }
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
        // The archived rows 1 … 20 name these levels (round2.md: 062, 069, … 097, 004, … 095).
        let named: [Int] = [62, 69, 76, 83, 90, 97, 4, 11, 18, 25, 32, 39, 46, 53, 60, 67, 74, 81, 88, 95]
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
        let level1: ApsidesWorkshopGenerated = try Core.generated(number: 1)
        let certified1: [ApsidesWorkshopAction] = Core.certifiedActions(1)
        let probe1: ApsidesWorkshopAction = try #require(Core.probeMove(1))
        let second1: ApsidesWorkshopAction = try #require(Core.secondMove(1))
        let heroTick: Int = try #require(Core.heroTick(1))
        let start: ApsidesWorkshopOrbit = level1.level.orbit
        #expect(heroTick == level1.level.period / 2, "the apoapsis tick T / 2")
        for spec in builtManifest.scenarios where !spec.name.hasPrefix("acceptance-") {
            let played = try await playScenario(spec)
            let core: Core = try #require(played.core, "\(spec.name)")
            switch spec.name {
            case "launch-first-frame", "suspend-resume", "teardown-reentry", "cancel-prepare", "rejection":
                #expect(core.levelNumber == 1 && Self.kinds(core).isEmpty && core.play.stage == .playing,
                        "\(spec.name)")
                #expect(core.play.actionsSpent == 0 && core.play.orbit == start, "\(spec.name)")
                #expect(core.shownTick == 0, "\(spec.name)")
            case "input-response", "save-restore", "reset":
                #expect(core.levelNumber == 1 && core.play.actionsSpent == 1, "\(spec.name)")
                #expect(core.play.stage == .playing && core.outcome == nil && core.play.canRedo, "\(spec.name)")
                #expect(Self.kinds(core).count == 3 && Self.kinds(core).last == .undo, "\(spec.name)")
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
                #expect(core.outcome == nil && core.play.report.wins, "the play is open and a play would win")
                #expect(core.shownTick == heroTick, "the hero tick is shown")
                let snapshot: ApsidesWorkshopSceneSnapshot = core.snapshot(time: 0)
                #expect(snapshot.shownTick == heroTick && snapshot.isWon == false)
                #expect(snapshot.orbiter == snapshot.positions[heroTick], "the orbiter at the apoapsis tick")
                #expect(snapshot.orbit == level1.plan.orbit, "the certified orbit is drawn")
            case "fixture-run-fails":
                #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(spec.name)")
                #expect(core.play.failure != nil, "\(spec.name)")
                #expect(Self.kinds(core) == [.play] && core.play.orbit == start, "\(spec.name)")
            case "fixture-undo-redo":
                #expect(Self.kinds(core).count == 3 && Array(Self.kinds(core).suffix(2)) == [.undo, .redo])
                #expect(Self.actions(core) == [probe1] && !core.play.canRedo)
                #expect(core.play.actionsSpent == 1 && core.play.stage == .playing)
            default:
                Issue.record("unexpected scenario \(spec.name)")
            }
        }
    }

    /// Checks truth row `row` (see the source's header); `level` is its level.
    static func checkTruth(row: Int, level: Int, played: (results: [String], core: Core),
                           probe: ApsidesWorkshopAction, moved: ApsidesWorkshopOrbit) {
        let core: Core = played.core
        let name: String = Core.acceptanceName(row)
        #expect(core.levelNumber == level && played.results.count == 2, "\(name)")
        #expect(played.results[0] == "accepted" && played.results[1] != "accepted", "\(name)")
        #expect(core.play.stage == .playing && Self.actions(core) == [probe], "\(name)")
        #expect(core.play.orbit == moved && core.shownTick == 0, "\(name): the refusal changed nothing")
        switch (row - 1) % 5 {
        case 0:
            #expect(played.results[1] == Core.kernelActionCode, "\(name): an unchanged orbit")
        case 1:
            #expect(played.results[1] == Core.outOfRangeCode, "\(name): the direction never wraps")
        case 2:
            let code: String = Core.invalidTuning(moved) != nil ? Core.kernelActionCode : Core.outOfRangeCode
            #expect(played.results[1] == code, "\(name): \(played.results[1])")
        case 3:
            #expect(played.results[1] == Core.notWholeCode, "\(name): \(played.results[1])")
        default:
            #expect(played.results[1] == Core.tickCode, "\(name): \(played.results[1])")
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
            let generated: ApsidesWorkshopGenerated = try Core.generated(number: level)
            let actions: [ApsidesWorkshopAction] = generated.plan.actions
            let opening: String = played.initial
            let period: Int = generated.level.period
            switch Core.acceptanceFamily(row) {
            case .truth:
                let probe: ApsidesWorkshopAction = try #require(Core.probeMove(level), "\(name)")
                let moved: Core = try #require(Core.played(seed: spec.seed, entries: [Core.actionEntry(probe)]))
                Self.checkTruth(row: row, level: level, played: (played.results, core), probe: probe,
                                moved: moved.play.orbit)
            case .witness:
                if row % 2 == 1 {
                    #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                    let kinds: [ApsidesWorkshopRecordKind] = Self.kinds(core)
                    #expect(Self.count(.undo, in: kinds) == 2 && kinds.last == .play, "\(name)")
                    #expect(Self.count(.play, in: kinds) == 2, "\(name): a failed play, then the winning one")
                    #expect(core.play.actionsSpent == actions.count, "\(name)")
                    #expect(core.play.orbit == generated.plan.orbit, "\(name): the plan's orbit")
                    let perturbed: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.dropLast(4)))
                    #expect(perturbed?.play.stage == .failed, "\(name): the perturbed plan fails")
                    if let failure = perturbed?.play.failure { runFailures.insert(failure.code) }
                } else {
                    #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(name)")
                    let path: [ApsidesWorkshopAction] = Core.exhaustedPath(level)
                    #expect(path.count == generated.level.budget && core.play.actionsLeft == 0, "\(name)")
                    #expect(Self.actions(core) == path + [.play], "\(name): the exhausted path")
                    let tail: [String] = Array(played.results.suffix(3))
                    #expect(tail == [Core.budgetCode, "accepted", Core.stageCode], "\(name): \(tail)")
                    let failure: ApsidesWorkshopFailure = try #require(core.play.failure, "\(name)")
                    runFailures.insert(failure.code)
                }
            case .numeric:
                #expect(played.final == opening && core.play.stage == .playing, "\(name)")
                #expect(Self.count(Core.outOfRangeCode, in: played.results) == 2, "\(name)")
                let invalid: Int = Core.invalidTuning(generated.level.orbit) == nil ? 0 : 1
                #expect(Self.count(Core.kernelActionCode, in: played.results) == 1 + invalid, "\(name)")
                #expect(Self.count(Core.notWholeCode, in: played.results) == 1, "\(name)")
                #expect(Self.count(Core.tickCode, in: played.results) == 1, "\(name)")
                #expect(Self.kinds(core) == [.size, .undo, .size, .undo] && core.play.actionsSpent == 0, "\(name)")
                let last: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.prefix(1)))
                #expect(last?.shownTick == period - 1, "\(name): the last tick")
                #expect(core.shownTick == 0, "\(name): the first tick")
                let extremes: (smallest: Int, largest: Int) =
                    try #require(Core.extremeSizes(generated.level.orbit), "\(name)")
                #expect(Self.actions(core) == [.size(extremes.smallest), .size(extremes.largest)], "\(name)")
            case .touch:
                let probe: ApsidesWorkshopAction = try #require(Core.probeMove(level), "\(name)")
                let moved: String = try #require(Core.expectedDigest(for: scenarioID, seed: spec.seed,
                                                                     entries: [Core.actionEntry(probe)]))
                #expect(played.final == moved && played.final != opening, "\(name)")
                #expect(Self.kinds(core).count == 3 && Array(Self.kinds(core).suffix(2)) == [.undo, .redo], "\(name)")
                #expect(Self.actions(core) == [probe], "\(name)")
                #expect(core.shownTick == period / 2, "\(name): the apoapsis tick shown")
                #expect(played.results.last == Core.kernelActionCode, "\(name)")
            case .rendering:
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                #expect(Self.actions(core) == Self.winning(level), "\(name)")
                #expect(played.results.last == Core.stageCode, "\(name)")
                var tiered: Core = core
                for tier in 0..<Core.qualityTiers {
                    tiered.setQualityTier(tier)
                    let snapshot: ApsidesWorkshopSceneSnapshot = tiered.snapshot(time: Double(tier) * 0.75)
                    var lit: Int = 0
                    for gauge in snapshot.gauges where gauge.met { lit += 1 }
                    #expect(snapshot.isWon && lit == generated.level.targets.count, "\(name)")
                    #expect(try digest(of: tiered) == played.final, "\(name): tier \(tier)")
                }
            case .accessibility:
                #expect(core.play.stage == .playing && core.outcome == nil, "\(name)")
                #expect(Array(Self.kinds(core).suffix(2)) == [.play, .undo], "\(name)")
                let beforeRun: [ScenarioStep] = Array(spec.entries.dropLast(2))
                let retry: String = try #require(Core.expectedDigest(for: scenarioID, seed: spec.seed,
                                                                     entries: beforeRun))
                #expect(played.final == retry, "\(name): the honest retry")
                let failedPlay: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.dropLast()))
                #expect(failedPlay?.play.stage == .failed, "\(name)")
                let failure: ApsidesWorkshopFailure = try #require(failedPlay?.play.failure, "\(name)")
                runFailures.insert(failure.code)
            case .persistence:
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                #expect(Array(Self.kinds(core).dropFirst().prefix(3)) == [.undo, .redo, .undo], "\(name)")
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
        // The scripted failing plays reach every failure the kernel names: a planet struck, sweeps out of order, a
        // share outside its band, an apsis in the wrong sector and an apsis distance outside its band.
        #expect(runFailures == Set(Core.preferredFailures), "\(runFailures)")
    }

    /// The JSON form with the control ids, named by `Catalog/registrations.json`. `UPDATE_SCENARIO_MANIFEST=1`
    /// rewrites it.
    @Test func theCommittedManifestFileMatches() throws {
        let file: URL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("scenario-manifest.json")
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: builtManifest.encoded()) as? [String: Any])
        var controlIDs: [String] = []
        for control in Core.controls { controlIDs.append(control.id) }
        object["controls"] = controlIDs
        let data: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted])
            + Data("\n".utf8)
        if ProcessInfo.processInfo.environment["UPDATE_SCENARIO_MANIFEST"] == "1" { try data.write(to: file) }
        #expect(try Data(contentsOf: file) == data, "run with UPDATE_SCENARIO_MANIFEST=1 and commit the file")
    }
}
#endif
