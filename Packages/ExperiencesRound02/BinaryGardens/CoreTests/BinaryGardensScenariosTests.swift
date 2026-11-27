// BinaryGardensScenariosTests — feature 503 (R02-G21-03) T-R02G2103-006 (FR-R02G2103-005, 008; SC-R02G2103-004). The
// scenario manifest of Binary Gardens: a valid round-two game manifest with the nine standard scenarios,
// `full-playthrough`, `hero`, the 80 acceptance scenarios (rows R2-G21-QA-001 … 080, in order, on 80 distinct levels,
// the first twenty the levels the archived rows name, each row's archived title kept verbatim) and three fixtures,
// every step naming a control the core declares; its derived digests, results and outcomes equal to what
// `ExperienceEngine` gives when played as the runner plays them; level 1's certified plan equal to its stored witness
// and the full playthrough winning level 1 (then 2 and 3) through the core; the save-restore state survives a restore;
// every standard scenario and fixture ends in the kernel state its actions describe; every acceptance row ends in the
// state of its family (a refusal with the engine's, the kernel's or the adapter's code, a perturbed plan recovered, an
// exhausted budget refusing further moves, the tick endpoints and the extreme settings undone, a won plan whose digest
// no quality tier changes, undo and redo restoring digests, a shown tick that leaves the digest alone, a failing run
// undone, the next level's opening digest); and the committed `scenario-manifest.json` equal to the Swift manifest
// (`UPDATE_SCENARIO_MANIFEST=1` rewrites it). Host-run (`swift test`); explicit types, plain loops. Modelled on
// `MushroomWeatherScenariosTests` (feature 493).
#if DEBUG || VISUALCORE_AUTOMATION
@testable import BinaryGardensCore
import Foundation
import Testing
import VisualCoreExperience

/// The id of the manifest's experience.
private let scenarioID: ExperienceID = ExperienceID(rawValue: BinaryGardensExperienceCore.experienceID)!

/// The manifest, built once per test process (it certifies 80 levels and more).
private let builtManifest: ScenarioManifest = BinaryGardensExperienceCore.manifest(for: scenarioID)

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playScenario(_ spec: ScenarioSpec) async throws
    -> (initial: String, results: [String], final: String, core: BinaryGardensExperienceCore?) {
    var engine: ExperienceEngine<BinaryGardensExperienceCore> =
        ExperienceEngine<BinaryGardensExperienceCore>(id: scenarioID)
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
private func scenarioDigest(of core: BinaryGardensExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: scenarioID.rawValue)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

@Suite struct BinaryGardensScenariosTests {
    typealias Core = BinaryGardensExperienceCore
    typealias Kind = BinaryGardensRecord.Kind

    /// The names of the three fixtures.
    static let fixtureNames: [String] = ["fixture-level-1-solved", "fixture-run-fails", "fixture-undo-redo"]

    /// Level 1's certified actions as its stored witness names them
    /// (`docs/games/binary-gardens/levels/001.witness.json`, read 2026-11-27): star 2's luminosity to index 0; then
    /// the run.
    static let witnessLevel1: [BinaryGardensAction] = [.luminosity(star: 1, index: 0)]

    /// The record kinds of `core`'s play after its opening records (begin and the tutorial's dismissal).
    static func kinds(_ core: Core) -> [Kind] {
        var result: [Kind] = []
        for record in core.play.records where record.kind != .begin && record.kind != .dismissTutorial {
            result.append(record.kind)
        }
        return result
    }

    /// The number of `kind` among `kinds`.
    static func count(_ kind: Kind, in kinds: [Kind]) -> Int {
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
    static func actions(_ core: Core) -> [BinaryGardensAction] {
        var result: [BinaryGardensAction] = []
        for record in core.play.records { if let action = record.action { result.append(action) } }
        return result
    }

    /// The certified actions of manifest number `number`'s plan followed by the run.
    static func winning(_ number: Int) -> [BinaryGardensAction] {
        Core.certifiedActions(number) + [.run]
    }

    @Test func theManifestIsAValidRoundTwoGame() {
        let manifest: ScenarioManifest = builtManifest
        let problems: [String] = ScenarioManifestValidator.problems(
            manifest, controls: Core.controls, content: ContentRequirement(fixtures: 3, acceptance: 80, levels: 100))
        #expect(problems.isEmpty, "\(problems)")
        var acceptanceNames: [String] = []
        var rowIDs: [String] = []
        var titles: [String] = []
        for row in 1...80 {
            acceptanceNames.append(Core.acceptanceName(row))
            rowIDs.append(Core.acceptanceRowID(row))
            titles.append(Core.acceptanceTitle(row))
        }
        #expect(acceptanceNames[0] == "acceptance-001" && acceptanceNames[79] == "acceptance-080")
        #expect(rowIDs[0] == "R2-G21-QA-001" && rowIDs[9] == "R2-G21-QA-010" && rowIDs[79] == "R2-G21-QA-080")
        #expect(Set(rowIDs).count == 80 && Set(titles).count == 80)
        // The archived titles of rows 1, 22 and 80 (round2.md section 6.21.19).
        #expect(titles[0] == "Truth and state transitions: fresh install and zero-history start")
        #expect(titles[21] == "Numeric and geometry edge: mid-level save/resume")
        #expect(titles[79] == "Integration, privacy and devices: resume after an app process kill")
        var names: [String] = []
        var acceptanceCount: Int = 0
        for spec in manifest.scenarios {
            names.append(spec.name)
            if spec.name.hasPrefix("acceptance-") { acceptanceCount += 1 }
        }
        #expect(acceptanceCount == 80)
        #expect(names == ScenarioManifest.standardNames + ["full-playthrough", "hero"] + acceptanceNames
            + Self.fixtureNames)
        #expect(Set(names).count == names.count)
        #expect(manifest.kind == .game && manifest.round == 2 && manifest.experience == scenarioID)
        var declared: Set<String> = []
        for control in Core.controls { declared.insert(control.id) }
        #expect(declared == Set(Core.actionIDs))
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
        // The archived rows 1 … 20 name these levels (round2.md: 071, 078, … 034, 041, 048, … 004).
        let named: [Int] = [71, 78, 85, 92, 99, 6, 13, 20, 27, 34, 41, 48, 55, 62, 69, 76, 83, 90, 97, 4]
        #expect(Array(Core.acceptanceLevels.prefix(20)) == named)
        #expect(Core.acceptanceLevels.count == 80 && Set(Core.acceptanceLevels).count == 80)
        #expect(Core.acceptanceFamily(1) == .truth && Core.acceptanceFamily(10) == .truth)
        #expect(Core.acceptanceFamily(11) == .witness && Core.acceptanceFamily(80) == .integration)
        #expect(Core.inputActions.count == 2 && Core.inputActions[0] == Core.probeMove(1))
        #expect(Core.inputActions[1] == Core.secondMove(1))
        #expect(Core.probeMove(1) == Core.certifiedActions(1).first)
        #expect(!Core.completionEntries.isEmpty && !Core.playthroughEntries.isEmpty && !Core.runFailsEntries.isEmpty)
        #expect(!Core.heroEntries.isEmpty && Core.rejectionEntries.count >= 30)
        // Every control appears in the manifest.
        var used: Set<String> = []
        for spec in manifest.scenarios {
            for entry in spec.entries { if let action = entry.action { used.insert(action.control) } }
        }
        #expect(used == declared, "\(declared.subtracting(used))")
    }

    @Test func level1PlanIsItsWitnessAndTheFullPlaythroughWinsIt() throws {
        #expect(Core.certifiedActions(1) == Self.witnessLevel1)
        let generated: BinaryGardensGenerated = try Core.generated(number: 1)
        let witness: BinaryGardensWitness = try BinaryGardensWitness.make(generated)
        #expect(witness.actions == Self.witnessLevel1 + [.run])
        // Through the core: level 1's part of full-playthrough wins level 1, the whole wins level 3.
        let level1Part: [ScenarioStep] = Core.winningEntries(1)
        #expect(Array(Core.playthroughEntries.prefix(level1Part.count)) == level1Part)
        let afterLevel1: Core = try #require(Core.played(seed: Core.manifestSeed, entries: level1Part))
        #expect(afterLevel1.levelNumber == 1 && afterLevel1.play.stage == .won)
        #expect(afterLevel1.outcome?.code == Core.wonCode)
        let afterAll: Core = try #require(Core.played(seed: Core.manifestSeed, entries: Core.playthroughEntries))
        #expect(afterAll.levelNumber == 3 && afterAll.play.stage == .won)
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
        let restoredDigest: String = try scenarioDigest(of: restored)
        #expect(restoredDigest == played.final)
        #expect(restored == core && restored.play.canRedo)
    }

    @Test func everyGameScenarioAndFixtureEndsInTheStateItsActionsDescribe() async throws {
        let level1: BinaryGardensGenerated = try Core.generated(number: 1)
        let certified1: [BinaryGardensAction] = Core.certifiedActions(1)
        let probe1: BinaryGardensAction = try #require(Core.probeMove(1))
        let second1: BinaryGardensAction = try #require(Core.secondMove(1))
        let heroTick: Int = try #require(Core.heroTick(1))
        let start: BinaryGardensArrangement = level1.level.start
        for spec in builtManifest.scenarios where !spec.name.hasPrefix("acceptance-") {
            let played = try await playScenario(spec)
            let core: Core = try #require(played.core, "\(spec.name)")
            switch spec.name {
            case "launch-first-frame", "suspend-resume", "teardown-reentry", "cancel-prepare", "rejection":
                #expect(core.levelNumber == 1 && Self.kinds(core).isEmpty && core.play.stage == .playing,
                        "\(spec.name)")
                #expect(core.play.actionsSpent == 0 && core.play.arrangement == start, "\(spec.name)")
                #expect(core.shownTick == 48, "\(spec.name)")
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
                #expect(core.outcome == nil && core.play.report.wins, "the play is open and a run would win")
                #expect(core.shownTick == heroTick, "the hero tick is shown")
                let snapshot: BinaryGardensSceneSnapshot = core.snapshot(time: 0)
                #expect(snapshot.shownTick == heroTick && snapshot.stage == .playing && snapshot.failure == nil)
                #expect(snapshot.arrangement == core.play.arrangement, "the certified arrangement is drawn")
                for world in snapshot.worlds.indices { #expect(snapshot.band(world) == .comfortable) }
            case "fixture-run-fails":
                #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(spec.name)")
                #expect(core.play.failure != nil, "\(spec.name)")
                #expect(Self.kinds(core) == [.run] && core.play.arrangement == start, "\(spec.name)")
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
                           probe: BinaryGardensAction, moved: BinaryGardensArrangement, phaseStep: Int) {
        let core: Core = played.core
        let name: String = Core.acceptanceName(row)
        #expect(core.levelNumber == level && played.results.count == 2, "\(name)")
        #expect(played.results[0] == "accepted" && played.results[1] != "accepted", "\(name)")
        #expect(core.play.stage == .playing && Self.actions(core) == [probe], "\(name)")
        #expect(core.play.arrangement == moved && core.shownTick == 48, "\(name): the refusal changed nothing")
        switch (row - 1) % 5 {
        case 0:
            #expect(played.results[1] == Core.kernelActionCode, "\(name): an unchanged value")
        case 1:
            let code: String = phaseStep > 1 ? Core.kernelActionCode : Core.notWholeCode
            #expect(played.results[1] == code, "\(name): a phase off the grid")
        case 2:
            #expect(played.results[1] == Core.outOfRangeCode, "\(name): \(played.results[1])")
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
            let generated: BinaryGardensGenerated = try Core.generated(number: level)
            let actions: [BinaryGardensAction] = generated.plan.actions
            let opening: String = played.initial
            switch Core.acceptanceFamily(row) {
            case .truth:
                let probe: BinaryGardensAction = try #require(Core.probeMove(level), "\(name)")
                let moved: Core = try #require(Core.played(seed: spec.seed, entries: [Core.actionEntry(probe)]))
                Self.checkTruth(row: row, level: level, played: (played.results, core), probe: probe,
                                moved: moved.play.arrangement, phaseStep: generated.level.phaseStep)
            case .witness:
                if row % 2 == 1 {
                    #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                    let kinds: [Kind] = Self.kinds(core)
                    #expect(Self.count(.undo, in: kinds) == 2 && kinds.last == .run, "\(name)")
                    #expect(Self.count(.run, in: kinds) == 2, "\(name): a failed run, then the winning one")
                    #expect(core.play.actionsSpent == actions.count, "\(name)")
                    #expect(core.play.arrangement == generated.plan.arrangement, "\(name): the plan's arrangement")
                    let perturbed: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.dropLast(4)))
                    #expect(perturbed?.play.stage == .failed, "\(name): the perturbed plan fails")
                    if let failure = perturbed?.play.failure { runFailures.insert(failure.code) }
                } else {
                    #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(name)")
                    let path: [BinaryGardensAction] = Core.exhaustedPath(level)
                    #expect(path.count == generated.level.budget && core.play.actionsLeft == 0, "\(name)")
                    #expect(Self.actions(core) == path + [.run], "\(name): the exhausted path")
                    let tail: [String] = Array(played.results.suffix(3))
                    #expect(tail == [Core.budgetCode, "accepted", Core.stageCode], "\(name): \(tail)")
                    let failure: BinaryGardensFailure = try #require(core.play.failure, "\(name)")
                    runFailures.insert(failure.code)
                }
            case .numeric:
                #expect(played.final == opening && core.play.stage == .playing, "\(name)")
                #expect(Self.count(Core.outOfRangeCode, in: played.results) == 3, "\(name)")
                #expect(Self.count(Core.kernelActionCode, in: played.results) == 2, "\(name)")
                #expect(Self.count(Core.notWholeCode, in: played.results) == 1, "\(name)")
                #expect(Self.count(Core.tickCode, in: played.results) == 1, "\(name)")
                let extremes: [BinaryGardensAction] = Core.extremeSettings(generated.level)
                #expect(!extremes.isEmpty && extremes.count <= 3, "\(name)")
                var expectedKinds: [Kind] = []
                for setting in extremes {
                    expectedKinds.append(BinaryGardensPlay.kind(of: setting))
                    expectedKinds.append(.undo)
                }
                #expect(Self.kinds(core) == expectedKinds && core.play.actionsSpent == 0, "\(name)")
                #expect(Self.actions(core) == extremes, "\(name)")
                let last: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.prefix(1)))
                #expect(last?.shownTick == 48, "\(name): the last tick")
                #expect(core.shownTick == 1, "\(name): the first tick")
            case .touch:
                let probe: BinaryGardensAction = try #require(Core.probeMove(level), "\(name)")
                let moved: String = try #require(Core.expectedDigest(for: scenarioID, seed: spec.seed,
                                                                     entries: [Core.actionEntry(probe)]))
                #expect(played.final == moved && played.final != opening, "\(name)")
                #expect(Self.kinds(core).count == 3 && Array(Self.kinds(core).suffix(2)) == [.undo, .redo], "\(name)")
                #expect(Self.actions(core) == [probe], "\(name)")
                #expect(core.shownTick == Core.touchTick, "\(name): the middle tick shown")
                #expect(played.results.last == Core.kernelActionCode, "\(name)")
            case .rendering:
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                #expect(Self.actions(core) == Self.winning(level), "\(name)")
                #expect(played.results.last == Core.stageCode, "\(name)")
                var tiered: Core = core
                for tier in 0..<Core.qualityTiers {
                    tiered.setQualityTier(tier)
                    let snapshot: BinaryGardensSceneSnapshot = tiered.snapshot(time: Double(tier) * 0.75)
                    #expect(snapshot.stage == .won && snapshot.failure == nil && snapshot.isWon, "\(name)")
                    #expect(try scenarioDigest(of: tiered) == played.final, "\(name): tier \(tier)")
                }
            case .accessibility:
                #expect(core.play.stage == .playing && core.outcome == nil, "\(name)")
                #expect(Array(Self.kinds(core).suffix(2)) == [.run, .undo], "\(name)")
                let beforeRun: [ScenarioStep] = Array(spec.entries.dropLast(2))
                let retry: String = try #require(Core.expectedDigest(for: scenarioID, seed: spec.seed,
                                                                     entries: beforeRun))
                #expect(played.final == retry, "\(name): the honest retry")
                let failedRun: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.dropLast()))
                #expect(failedRun?.play.stage == .failed, "\(name)")
                let failure: BinaryGardensFailure = try #require(failedRun?.play.failure, "\(name)")
                runFailures.insert(failure.code)
                // The failure is named in words, as the kernel names it.
                #expect(!generated.level.failureDescription(failure).isEmpty)
            case .persistence:
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                #expect(Array(Self.kinds(core).dropFirst().prefix(3)) == [.undo, .redo, .undo], "\(name)")
                let restored: Core = try Core.restore(payload: core.snapshotPayload(), seed: spec.seed)
                let restoredDigest: String = try scenarioDigest(of: restored)
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
        // The scripted failing runs name only failures the kernel knows, at least three of its five.
        #expect(runFailures.isSubset(of: Set(Core.preferredFailures)), "\(runFailures)")
        #expect(runFailures.count >= 3, "\(runFailures)")
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
