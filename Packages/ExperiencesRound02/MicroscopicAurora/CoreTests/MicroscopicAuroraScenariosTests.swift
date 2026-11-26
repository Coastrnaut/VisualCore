// MicroscopicAuroraScenariosTests — feature 483 (R02-G19-03) T-R02G1903-006 (FR-R02G1903-005, 008). The scenario
// manifest of Microscopic Aurora: a valid round-two game manifest with the nine standard scenarios,
// `full-playthrough`, `hero`, the 80 acceptance scenarios (rows R2-G19-QA-001 … 080, in order, on 80 distinct levels,
// the first twenty the levels the archived rows name) and three fixtures, every step naming a control the core
// declares; its derived digests, results and outcomes equal to what `ExperienceEngine` gives when played as the runner
// plays them; level 1's certified plan equal to its stored witness and the full playthrough winning level 1 (then 2
// and 3) through the core; the save-restore state survives a restore; every standard scenario and fixture ends in the
// kernel state its actions describe; every acceptance row ends in the state of its family (a refusal with the
// engine's, the kernel's or the adapter's code, a perturbed plan recovered, an exhausted budget refusing further
// moves, a won plan whose digest no quality tier changes, undo and redo restoring digests, a shown tick that leaves
// the digest alone, a failing play undone, the next level's opening digest); and the committed
// `scenario-manifest.json` equal to the Swift manifest (`UPDATE_SCENARIO_MANIFEST=1` rewrites it). Host-run
// (`swift test`); explicit types, plain loops. Modelled on `ApsidesWorkshopScenariosTests` (feature 473).
#if DEBUG || VISUALCORE_AUTOMATION
@testable import MicroscopicAuroraCore
import Foundation
import Testing
import VisualCoreExperience

/// The id of the manifest's experience.
private let scenarioID: ExperienceID = ExperienceID(rawValue: MicroscopicAuroraExperienceCore.experienceID)!

/// The manifest, built once per test process (it certifies 80 levels and more).
private let builtManifest: ScenarioManifest = MicroscopicAuroraExperienceCore.manifest(for: scenarioID)

/// What playing `spec` on a fresh engine gives, as the runner plays it.
private func playScenario(_ spec: ScenarioSpec) async throws
    -> (initial: String, results: [String], final: String, core: MicroscopicAuroraExperienceCore?) {
    var engine: ExperienceEngine<MicroscopicAuroraExperienceCore> =
        ExperienceEngine<MicroscopicAuroraExperienceCore>(id: scenarioID)
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
private func digest(of core: MicroscopicAuroraExperienceCore) throws -> String {
    var builder: DigestBuilder = DigestBuilder(domain: scenarioID.rawValue)
    try core.writeDigest(into: &builder)
    return builder.finish().hex
}

@Suite struct MicroscopicAuroraScenariosTests {
    typealias Core = MicroscopicAuroraExperienceCore

    /// The names of the three fixtures.
    static let fixtureNames: [String] = ["fixture-level-1-solved", "fixture-run-fails", "fixture-undo-redo"]

    /// Level 1's certified placement as its stored witness names it
    /// (`docs/games/microscopic-aurora/levels/001.witness.json`, read 2026-11-26): slot 0, row 11, column 18,
    /// strength 2, clockwise; then the play.
    static let witnessLevel1: [MicroscopicAuroraAction] = [
        .place(slot: 0, well: MicroscopicAuroraWell(cell: MicroscopicAuroraCell(row: 11, column: 18), strength: 2,
                                                    sense: .clockwise)),
    ]

    /// The record kinds of `core`'s play after its opening records (begin and the tutorial's dismissal).
    static func kinds(_ core: Core) -> [MicroscopicAuroraRecordKind] {
        var result: [MicroscopicAuroraRecordKind] = []
        for record in core.play.records where record.kind != .begin && record.kind != .dismissTutorial {
            result.append(record.kind)
        }
        return result
    }

    /// The number of `kind` among `kinds`.
    static func count(_ kind: MicroscopicAuroraRecordKind, in kinds: [MicroscopicAuroraRecordKind]) -> Int {
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
    static func actions(_ core: Core) -> [MicroscopicAuroraAction] {
        var result: [MicroscopicAuroraAction] = []
        for record in core.play.records { if let action = record.action { result.append(action) } }
        return result
    }

    /// The placements of manifest number `number`'s plan followed by the play.
    static func winning(_ number: Int) -> [MicroscopicAuroraAction] {
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
        #expect(rowIDs[0] == "R2-G19-QA-001" && rowIDs[9] == "R2-G19-QA-010" && rowIDs[79] == "R2-G19-QA-080")
        #expect(Set(rowIDs).count == 80)
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
        // The archived rows 1 … 20 name these levels (round2.md: 065, 072, … 100, 007, … 098).
        let named: [Int] = [65, 72, 79, 86, 93, 100, 7, 14, 21, 28, 35, 42, 49, 56, 63, 70, 77, 84, 91, 98]
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

    @Test func level1PlanIsItsWitnessAndTheFullPlaythroughWinsIt() throws {
        #expect(Core.certifiedActions(1) == Self.witnessLevel1)
        let generated: MicroscopicAuroraGenerated = try Core.generated(number: 1)
        let witness: MicroscopicAuroraWitness = try MicroscopicAuroraWitness.make(generated)
        #expect(witness.actions == Self.witnessLevel1 + [.play])
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
        let restoredDigest: String = try digest(of: restored)
        #expect(restoredDigest == played.final)
        #expect(restored == core && restored.play.canRedo)
    }

    @Test func everyGameScenarioAndFixtureEndsInTheStateItsActionsDescribe() async throws {
        let level1: MicroscopicAuroraGenerated = try Core.generated(number: 1)
        let certified1: [MicroscopicAuroraAction] = Core.certifiedActions(1)
        let probe1: MicroscopicAuroraAction = try #require(Core.probeMove(1))
        let second1: MicroscopicAuroraAction = try #require(Core.secondMove(1))
        let heroTick: Int = try #require(Core.heroTick(1))
        let empty: [MicroscopicAuroraWell?] = level1.level.wells
        #expect(heroTick == level1.level.length, "a winning swim swims the whole length")
        for spec in builtManifest.scenarios where !spec.name.hasPrefix("acceptance-") {
            let played = try await playScenario(spec)
            let core: Core = try #require(played.core, "\(spec.name)")
            switch spec.name {
            case "launch-first-frame", "suspend-resume", "teardown-reentry", "cancel-prepare", "rejection":
                #expect(core.levelNumber == 1 && Self.kinds(core).isEmpty && core.play.stage == .playing,
                        "\(spec.name)")
                #expect(core.play.actionsSpent == 0 && core.play.wells == empty, "\(spec.name)")
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
                let snapshot: MicroscopicAuroraSceneSnapshot = core.snapshot(time: 0)
                #expect(snapshot.shownTick == heroTick && snapshot.isWon == false)
                #expect(snapshot.ticksSwum == heroTick && snapshot.failure == nil)
                #expect(snapshot.wells == core.play.wells, "the certified wells are drawn")
            case "fixture-run-fails":
                #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(spec.name)")
                #expect(core.play.failure != nil, "\(spec.name)")
                #expect(Self.kinds(core) == [.play] && core.play.wells == empty, "\(spec.name)")
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
                           probe: MicroscopicAuroraAction, moved: [MicroscopicAuroraWell?]) {
        let core: Core = played.core
        let name: String = Core.acceptanceName(row)
        #expect(core.levelNumber == level && played.results.count == 2, "\(name)")
        #expect(played.results[0] == "accepted" && played.results[1] != "accepted", "\(name)")
        #expect(core.play.stage == .playing && Self.actions(core) == [probe], "\(name)")
        #expect(core.play.wells == moved && core.shownTick == 0, "\(name): the refusal changed nothing")
        switch (row - 1) % 5 {
        case 0:
            #expect(played.results[1] == Core.kernelActionCode, "\(name): an unchanged well")
        case 1:
            #expect(played.results[1] == Core.kernelActionCode, "\(name): a well off the sites")
        case 2:
            #expect(played.results[1] == Core.notWholeCode, "\(name): \(played.results[1])")
        case 3:
            #expect(played.results[1] == Core.kernelActionCode, "\(name): an occupied cell")
        default:
            #expect(played.results[1] == Core.outOfRangeCode, "\(name): \(played.results[1])")
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
            let generated: MicroscopicAuroraGenerated = try Core.generated(number: level)
            let actions: [MicroscopicAuroraAction] = generated.plan.actions
            let opening: String = played.initial
            switch Core.acceptanceFamily(row) {
            case .truth:
                let probe: MicroscopicAuroraAction = try #require(Core.probeMove(level), "\(name)")
                let moved: Core = try #require(Core.played(seed: spec.seed, entries: [Core.actionEntry(probe)]))
                Self.checkTruth(row: row, level: level, played: (played.results, core), probe: probe,
                                moved: moved.play.wells)
            case .witness:
                if row % 2 == 1 {
                    #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                    let kinds: [MicroscopicAuroraRecordKind] = Self.kinds(core)
                    #expect(Self.count(.undo, in: kinds) == 2 && kinds.last == .play, "\(name)")
                    #expect(Self.count(.play, in: kinds) == 2, "\(name): a failed play, then the winning one")
                    #expect(core.play.actionsSpent == actions.count, "\(name)")
                    #expect(core.play.placedWells == generated.plan.wells, "\(name): the plan's wells")
                    let perturbed: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.dropLast(4)))
                    #expect(perturbed?.play.stage == .failed, "\(name): the perturbed plan fails")
                    if let failure = perturbed?.play.failure { runFailures.insert(failure.code) }
                } else {
                    #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode, "\(name)")
                    let path: [MicroscopicAuroraAction] = Core.exhaustedPath(level)
                    #expect(path.count == generated.level.budget && core.play.actionsLeft == 0, "\(name)")
                    #expect(Self.actions(core) == path + [.play], "\(name): the exhausted path")
                    let tail: [String] = Array(played.results.suffix(3))
                    #expect(tail == [Core.budgetCode, "accepted", Core.stageCode], "\(name): \(tail)")
                    let failure: MicroscopicAuroraFailure = try #require(core.play.failure, "\(name)")
                    runFailures.insert(failure.code)
                }
            case .numeric:
                #expect(played.final == opening && core.play.stage == .playing, "\(name)")
                let openingPlay: Core = try Core.opening(number: level)
                let beyond: (tick: Int, code: String) = Core.beyondTick(openingPlay.play)
                let outOfRange: Int = beyond.code == Core.outOfRangeCode ? 3 : 2
                #expect(Self.count(Core.outOfRangeCode, in: played.results) == outOfRange, "\(name)")
                #expect(Self.count(Core.kernelActionCode, in: played.results) == 2, "\(name)")
                #expect(Self.count(Core.notWholeCode, in: played.results) == 1, "\(name)")
                #expect(Self.count(Core.tickCode, in: played.results) == 3 - outOfRange, "\(name)")
                #expect(Self.kinds(core) == [.place, .undo, .place, .undo] && core.play.actionsSpent == 0, "\(name)")
                let last: Core? = Core.played(seed: spec.seed, entries: Array(spec.entries.prefix(1)))
                #expect(last?.shownTick == openingPlay.play.report.ticks, "\(name): the last tick")
                #expect(core.shownTick == 0, "\(name): the first tick")
                let extremes: (smallest: MicroscopicAuroraAction, largest: MicroscopicAuroraAction) =
                    try #require(Core.extremePlacements(generated.level), "\(name)")
                #expect(Self.actions(core) == [extremes.smallest, extremes.largest], "\(name)")
            case .touch:
                let probe: MicroscopicAuroraAction = try #require(Core.probeMove(level), "\(name)")
                let moved: String = try #require(Core.expectedDigest(for: scenarioID, seed: spec.seed,
                                                                     entries: [Core.actionEntry(probe)]))
                #expect(played.final == moved && played.final != opening, "\(name)")
                #expect(Self.kinds(core).count == 3 && Array(Self.kinds(core).suffix(2)) == [.undo, .redo], "\(name)")
                #expect(Self.actions(core) == [probe], "\(name)")
                #expect(core.shownTick == Core.touchTick(level), "\(name): the middle tick shown")
                #expect(played.results.last == Core.kernelActionCode, "\(name)")
            case .rendering:
                #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "\(name)")
                #expect(Self.actions(core) == Self.winning(level), "\(name)")
                #expect(played.results.last == Core.stageCode, "\(name)")
                var tiered: Core = core
                for tier in 0..<Core.qualityTiers {
                    tiered.setQualityTier(tier)
                    let snapshot: MicroscopicAuroraSceneSnapshot = tiered.snapshot(time: Double(tier) * 0.75)
                    #expect(snapshot.isWon && snapshot.failure == nil, "\(name)")
                    #expect(snapshot.coverage >= snapshot.requiredCoverage, "\(name)")
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
                let failure: MicroscopicAuroraFailure = try #require(failedPlay?.play.failure, "\(name)")
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
        // The scripted failing plays name only failures the kernel knows, and at least the coverage shortfall.
        #expect(runFailures.isSubset(of: Set(Core.preferredFailures)) && runFailures.contains("coverage"),
                "\(runFailures)")
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
