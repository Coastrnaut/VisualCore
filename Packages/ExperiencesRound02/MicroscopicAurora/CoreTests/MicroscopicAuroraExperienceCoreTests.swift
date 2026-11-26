// MicroscopicAuroraExperienceCoreTests — feature 483 (R02-G19-03) T-R02G1903-005 (FR-R02G1903-005, 008, 009;
// SC-R02G1903-004; clarifications Q4, Q5). The adapter core: the shared conformance checks pass; the declared controls,
// ids, tiers and profile (the quality level names equal `MicroscopicAuroraTier.all`); the seed picks level `seed % 100
// + 1` deterministically in stage `playing` with tick 0 shown (seeds 0, 1, 99 and 100 give levels 1, 2, 100 and 1);
// every control is accepted when legal and refused with the state unchanged otherwise (the engine's range checks,
// `r02-g19.not-whole`, `r02-g19.tick` for a tick past the ticks swum, and every kernel refusal the adapter can meet
// passing through with its code: `r02-g19.action` for a cell off the enclosure or not a site, an occupied cell, an
// unchanged placement, an empty slot and nothing to undo or redo, `r02-g19.budget` and `r02-g19.stage`; `stale` cannot
// arise because every action names the current fingerprint); sense 0 is clockwise and 1 counterclockwise; undo restores
// the earlier digest exactly and redo the later one; `clock.show` changes the snapshot but never the digest, the play
// or the payload, a placement, undo and redo keep it (clamped to the ticks swum), and `level.next`, reset and restore
// return it to 0; the certified plan of level 1 wins through the adapter and a play from the opening fails, undo
// returning the failed play to playing; `level.next` wraps 100 to 1 and reset returns; the snapshot round trip and
// refused payloads (damaged, level out of range, a trace of another level, a record of a newer schema, an edited trace,
// an envelope of a newer schema); the certified-candidate table equals the 100 stored witnesses' `skipped` and the
// directly certified levels equal the stored witness levels; `snapshot(time:)` copies the play, its swimmers standing
// at the kernel's positions. Levels are certified once per process, so the run stays short. Explicit types, plain
// loops, single-literal comments. Modelled on ApsidesWorkshopExperienceCoreTests (feature 473).
@testable import MicroscopicAuroraCore
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, MicroscopicAurora, the
/// package, Packages).
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/microscopic-aurora/levels", isDirectory: true)

/// Whether the stored witnesses are present (they are in the repository; an isolated copy of the package lacks them).
private let coreWitnessesPresent: Bool = FileManager.default.fileExists(
    atPath: coreWitnessDirectory.appendingPathComponent("001.witness.json").path)

@Suite struct MicroscopicAuroraExperienceCoreTests {
    typealias Core = MicroscopicAuroraExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// An action of `control` with `values`.
    static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func act(_ action: MicroscopicAuroraAction) -> ExperienceAction {
        switch action {
        case let .place(slot, well):
            let sense: Double = well.sense == .clockwise ? 0 : 1
            return act("well.place", [Double(slot), Double(well.cell.row), Double(well.cell.column),
                                      Double(well.strength), sense])
        case let .remove(slot):
            return act("well.remove", [Double(slot)])
        case .play:
            return act("swim.play")
        }
    }

    /// The stored witness of level `number`: its number, `skipped` and level fingerprint, read as plain JSON.
    static func storedWitness(_ number: Int) throws -> (number: Int, skipped: Int, fingerprint: String) {
        let name: String = String(MicroscopicAuroraGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: coreWitnessDirectory.appendingPathComponent(name))
        let object: [String: Any] = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let level: [String: Any] = try #require(object["level"] as? [String: Any])
        let stored: Int = try #require(object["number"] as? Int)
        let skipped: Int = try #require(object["skipped"] as? Int)
        let fingerprint: String = try #require(level["fingerprint"] as? String)
        return (stored, skipped, fingerprint)
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 3 (then 2 and 4). Level 1's certified plan is a clockwise well of strength 2 on (11, 18); the
        // play from the opening fails and is undone.
        let actions: [ScriptedAction] = [ScriptedAction("well.place", [0, 11, 18, 2, 0]), ScriptedAction("play.undo"),
                                         ScriptedAction("play.redo"), ScriptedAction("clock.show", [10]),
                                         ScriptedAction("play.undo"), ScriptedAction("swim.play"),
                                         ScriptedAction("play.undo"), ScriptedAction("well.place", [1, 9, 7, 1, 1]),
                                         ScriptedAction("well.remove", [1]), ScriptedAction("level.next"),
                                         ScriptedAction("clock.show", [5]),
                                         ScriptedAction("well.place", [0, 9, 13, 2, 0]), ScriptedAction("play.undo")]
        // Refused on the openings of levels 1 and 3 (no well placed, swims of at most 160 ticks).
        let rejected: [ScriptedAction] = [ScriptedAction("well.place", [3, 11, 18, 2, 0]),
                                          ScriptedAction("well.place", [-1, 11, 18, 2, 0]),
                                          ScriptedAction("well.place", [0, 24, 18, 2, 0]),
                                          ScriptedAction("well.place", [0, 11, 24, 2, 0]),
                                          ScriptedAction("well.place", [0, 11, 18, 0, 0]),
                                          ScriptedAction("well.place", [0, 11, 18, 5, 0]),
                                          ScriptedAction("well.place", [0, 11, 18, 2, 2]),
                                          ScriptedAction("well.place", [0.5, 11, 18, 2, 0]),
                                          ScriptedAction("well.place", [0, 11, 18, 2, 0.5]),
                                          ScriptedAction("well.place", [0, 0, 0, 1, 0]),
                                          ScriptedAction("well.place", [0, 12, 12, 1, 0]),
                                          ScriptedAction("well.place", [0, 11, 18, 2]),
                                          ScriptedAction("well.remove", [0]),
                                          ScriptedAction("well.remove", [3]),
                                          ScriptedAction("well.remove", [0.5]),
                                          ScriptedAction("well.remove"),
                                          ScriptedAction("clock.show", [480]),
                                          ScriptedAction("clock.show", [481]),
                                          ScriptedAction("clock.show", [-1]),
                                          ScriptedAction("clock.show", [2.5]),
                                          ScriptedAction("clock.show"),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("swim.play", [1]), ScriptedAction("level.next", [1]),
                                          ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 2], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries {
            if !entry.passed { print("conformance", entry.check, entry.detail) }
            #expect(entry.passed, "every conformance check passes")
        }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g19.microscopic-aurora" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g19.microscopic-aurora.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["well.place", "well.remove", "swim.play", "play.undo", "play.redo", "level.next",
                             "clock.show"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[0].ranges == [0...2, 0...23, 0...23, 1...4, 0...1])
        #expect(Core.controls[1].ranges == [0...2])
        #expect(Core.controls[6].ranges == [0...480])
        let plainIndices: [Int] = [2, 3, 4, 5]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.qualityTiers == MicroscopicAuroraTier.all.count)
        #expect(Core.migrations.currentVersion == 1)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == MicroscopicAuroraTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 0.5, 0.25] && iterations == [1, 8.0 / 12.0, 0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(MicroscopicAuroraExperienceRule.notWhole == "r02-g19.not-whole")
        #expect(MicroscopicAuroraExperienceRule.tick == "r02-g19.tick")
        #expect(Core.wonCode == "won" && Core.failedCode == "failed")
    }

    @Test func theSeedPicksTheLevelDeterministically() async throws {
        let seeds: [UInt64] = [0, 1, 99, 100]
        let numbers: [Int] = [1, 2, 100, 1]
        for index in seeds.indices {
            #expect(Core.levelNumber(forSeed: seeds[index]) == numbers[index])
            let first: Core = try await Core.prepare(seed: seeds[index])
            let second: Core = try await Core.prepare(seed: seeds[index])
            #expect(first.levelNumber == numbers[index] && first.openingNumber == numbers[index])
            #expect(first == second)
            #expect(try Self.digest(first) == Self.digest(second))
            let expected: MicroscopicAuroraLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.wells == expected.wells)
            // The tutorial (levels 1 … 3) is dismissed by the adapter: the play opens in stage playing.
            #expect(first.play.stage == .playing && first.outcome == nil && first.play.failure == nil)
            let opening: Int = expected.tutorial ? 2 : 1
            #expect(first.play.records.count == opening && !first.play.canUndo)
            #expect(first.play.actionsLeft == expected.budget && first.qualityTier == 0 && first.shownTick == 0)
        }
        #expect(try Core.level(number: 1).tutorial && !(try Core.level(number: 100).tutorial))
        #expect(throws: MicroscopicAuroraError.level("number")) { try Core.level(number: 0) }
        #expect(throws: MicroscopicAuroraError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableIsInRange() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for value in Core.certifiedCandidates {
            #expect(value >= 0 && value < MicroscopicAuroraGenerator.maxCandidates)
        }
        // Spot values of the table (levels 6, 17, 53 and 75 skip 1, 5, 8 and 11 candidates).
        #expect(Core.certifiedCandidates[0] == 0 && Core.certifiedCandidates[5] == 1)
        #expect(Core.certifiedCandidates[16] == 5 && Core.certifiedCandidates[52] == 8)
        #expect(Core.certifiedCandidates[74] == 11)
        // Level 6 certifies directly from its table entry and equals the generator's whole search after level 5.
        let entry: MicroscopicAuroraManifestEntry = MicroscopicAuroraManifest.entries[5]
        let searched: MicroscopicAuroraGenerated = try MicroscopicAuroraGenerator.generate(
            entry, previous: try Core.level(number: 5))
        let direct: MicroscopicAuroraGenerated = try #require(Core.certify(entry, index: Core.certifiedCandidates[5]))
        #expect(searched.skipped == 1 && direct == searched)
        #expect(try Core.generated(number: 6) == searched)
        #expect(direct.entry == entry && direct.level.id == MicroscopicAuroraGenerator.levelID(6))
    }

    @Test(.enabled(if: coreWitnessesPresent, "needs the stored witnesses, docs/games/microscopic-aurora/levels"))
    func theCandidateTableEqualsTheStoredWitnesses() throws {
        for number in 1...100 {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            #expect(witness.number == number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "a table entry differs")
        }
        // Directly certified levels equal the stored witness levels.
        let numbers: [Int] = [1, 17, 21, 75, 100]
        for number in numbers {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            let generated: MicroscopicAuroraGenerated = try Core.generated(number: number)
            #expect(generated.level.fingerprint == witness.fingerprint, "a level fingerprint differs")
            #expect(generated.skipped == witness.skipped)
        }
    }

    @Test func theCertifiedPlanOfLevelOneWinsThroughTheAdapter() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let generated: MicroscopicAuroraGenerated = try Core.generated(number: 1)
        let well = MicroscopicAuroraWell(cell: MicroscopicAuroraCell(row: 11, column: 18), strength: 2,
                                         sense: .clockwise)
        #expect(generated.plan.actions == [.place(slot: 0, well: well)])
        #expect(core.apply(Self.act("clock.show", [1])) == .accepted)
        for step in generated.plan.actions {
            #expect(core.apply(Self.act(step)) == .accepted)
            #expect(core.shownTick == 1, "a placement keeps the shown tick")
        }
        #expect(core.play.wells[0] == well && core.play.report.wins && core.play.report.ticks == 120)
        #expect(core.apply(Self.act("swim.play")) == .accepted)
        #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
        #expect(core.play.failure == nil && core.play.report.wins)
        #expect(core.play.actionsLeft == core.play.level.budget - generated.plan.size)
        #expect(core.snapshot(time: 0).isWon && core.shownTick == 1)
        // A won play is final: a placement, a removal, the play, undo and redo are the kernel's stage refusal; showing
        // is still accepted.
        let stage: ActionResult = .rejected(.rule(code: "r02-g19.stage"))
        #expect(core.apply(Self.act("well.place", [1, 9, 7, 1, 0])) == stage)
        #expect(core.apply(Self.act("well.remove", [0])) == stage)
        #expect(core.apply(Self.act("swim.play")) == stage)
        #expect(core.apply(Self.act("play.undo")) == stage)
        #expect(core.apply(Self.act("play.redo")) == stage)
        #expect(core.apply(Self.act("clock.show", [120])) == .accepted && core.shownTick == 120)
        #expect(core.apply(Self.act("clock.show", [121])) == .rejected(.rule(code: "r02-g19.tick")))
    }

    @Test func aPlayFromTheOpeningFailsAndUndoReturnsToPlaying() async throws {
        // The level rules guarantee the starting wells do not win.
        var core: Core = try await Core.prepare(seed: 0)
        let openingDigest: StateDigest = try Self.digest(core)
        let ticks: Int = core.play.report.ticks
        #expect(core.apply(Self.act("clock.show", [Double(ticks)])) == .accepted)
        #expect(core.apply(Self.act("swim.play")) == .accepted)
        #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode)
        let failure: MicroscopicAuroraFailure = try #require(core.play.failure)
        #expect(core.play.level.startReport.failure == failure && core.play.actionsLeft == core.play.level.budget)
        let snapshot: MicroscopicAuroraSceneSnapshot = core.snapshot(time: 0)
        #expect(snapshot.failure == failure && snapshot.stage == .failed && snapshot.shownTick == ticks)
        let stage: ActionResult = .rejected(.rule(code: "r02-g19.stage"))
        #expect(core.apply(Self.act("well.place", [0, 11, 18, 2, 0])) == stage)
        #expect(core.apply(Self.act("swim.play")) == stage)
        #expect(core.apply(Self.act("play.redo")) == stage)
        #expect(core.apply(Self.act("clock.show", [0])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.play.stage == .playing && core.outcome == nil && core.play.failure == nil)
        #expect(core.shownTick == 0)
        #expect(try Self.digest(core) == openingDigest)
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: sites (9, 7), (11, 18) and (17, 8), budget 9, no starting well.
        let core: Core = try await Core.prepare(seed: 0)
        let level: MicroscopicAuroraLevel = core.play.level
        let sites: [MicroscopicAuroraCell] = [MicroscopicAuroraCell(row: 9, column: 7),
                                              MicroscopicAuroraCell(row: 11, column: 18),
                                              MicroscopicAuroraCell(row: 17, column: 8)]
        #expect(level.sites == sites && level.budget == 9 && level.wells == [nil, nil, nil])
        let ticks: Int = core.play.report.ticks
        #expect(ticks >= 1 && ticks <= level.length)
        let opening: StateDigest = try Self.digest(core)
        let records: Int = core.play.records.count
        let illegal: [ExperienceAction] = [Self.act("well.place", [3, 9, 7, 1, 0]),
                                           Self.act("well.place", [-1, 9, 7, 1, 0]),
                                           Self.act("well.place", [0, 24, 7, 1, 0]),
                                           Self.act("well.place", [0, 9, -1, 1, 0]),
                                           Self.act("well.place", [0, 9, 7, 0, 0]),
                                           Self.act("well.place", [0, 9, 7, 5, 0]),
                                           Self.act("well.place", [0, 9, 7, 1, 2]),
                                           Self.act("well.place", [0, 9.5, 7, 1, 0]),
                                           Self.act("well.place", [0, 9, 7, 1.5, 0]),
                                           Self.act("well.place", [0, 9, 7, 1, .nan]),
                                           Self.act("well.place", [0, 9, 7, 1]),
                                           Self.act("well.place"),
                                           Self.act("well.place", [0, 0, 0, 1, 0]),
                                           Self.act("well.place", [0, 12, 12, 1, 0]),
                                           Self.act("well.remove", [0]), Self.act("well.remove", [3]),
                                           Self.act("well.remove", [1.5]), Self.act("well.remove"),
                                           Self.act("clock.show", [Double(ticks + 1)]),
                                           Self.act("clock.show", [480]), Self.act("clock.show", [481]),
                                           Self.act("clock.show", [-1]), Self.act("clock.show", [2.5]),
                                           Self.act("clock.show", [1, 1]), Self.act("play.undo"),
                                           Self.act("play.redo"), Self.act("play.undo", [1]),
                                           Self.act("swim.play", [1]), Self.act("level.next", [1]),
                                           Self.act("nope")]
        for action in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(action)
            #expect(!result.isAccepted, "an illegal action was accepted")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.count == records, "a refusal changed it")
            #expect(copy.shownTick == core.shownTick)
        }
        var probe: Core = core
        // Outside the declared ranges or the value count: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.act("well.place", [3, 9, 7, 1, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("well.place", [0, 24, 7, 1, 0])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("well.place", [0, 9, -1, 1, 0])) == .rejected(.outOfRange(index: 2)))
        #expect(probe.apply(Self.act("well.place", [0, 9, 7, 5, 0])) == .rejected(.outOfRange(index: 3)))
        #expect(probe.apply(Self.act("well.place", [0, 9, 7, 1, 2])) == .rejected(.outOfRange(index: 4)))
        #expect(probe.apply(Self.act("well.remove", [3])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("clock.show", [481])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("clock.show", [-1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("well.place", [0, 9, 7, 1, .nan])) == .rejected(.nonFinite(index: 4)))
        let fourOfFive: ActionResult = .rejected(.wrongValueCount(expected: 5, found: 4))
        #expect(probe.apply(Self.act("well.place", [0, 9, 7, 1])) == fourOfFive)
        #expect(probe.apply(Self.act("well.remove")) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(probe.apply(Self.act("clock.show", [1, 1])) == .rejected(.wrongValueCount(expected: 1, found: 2)))
        let noValues: ActionResult = .rejected(.wrongValueCount(expected: 0, found: 1))
        #expect(probe.apply(Self.act("swim.play", [1])) == noValues)
        #expect(probe.apply(Self.act("play.undo", [1])) == noValues)
        #expect(probe.apply(Self.act("play.redo", [1])) == noValues)
        #expect(probe.apply(Self.act("level.next", [1])) == noValues)
        let notWhole: ActionResult = .rejected(.rule(code: MicroscopicAuroraExperienceRule.notWhole))
        #expect(probe.apply(Self.act("well.place", [0, 9.5, 7, 1, 0])) == notWhole)
        #expect(probe.apply(Self.act("well.place", [0, 9, 7, 1.5, 0])) == notWhole)
        #expect(probe.apply(Self.act("well.remove", [1.5])) == notWhole)
        #expect(probe.apply(Self.act("clock.show", [2.5])) == notWhole)
        // A tick past the ticks swum: the adapter's refusal.
        let tick: ActionResult = .rejected(.rule(code: MicroscopicAuroraExperienceRule.tick))
        #expect(probe.apply(Self.act("clock.show", [Double(ticks + 1)])) == tick)
        #expect(probe.apply(Self.act("clock.show", [480])) == tick)
        // The kernel's refusals pass through with their codes: off the enclosure, not a site, an empty slot, nothing
        // to undo or redo.
        let action: ActionResult = .rejected(.rule(code: "r02-g19.action"))
        #expect(probe.apply(Self.act("well.place", [0, 0, 0, 1, 0])) == action)
        #expect(probe.apply(Self.act("well.place", [0, 12, 12, 1, 0])) == action)
        #expect(probe.apply(Self.act("well.remove", [0])) == action)
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe == core && probe.play.records.count == records && probe.shownTick == 0)
        // Every legal tick is accepted and changes nothing else.
        for shown in 0...ticks {
            #expect(probe.apply(Self.act("clock.show", [Double(shown)])) == .accepted && probe.shownTick == shown)
        }
        #expect(try Self.digest(probe) == opening && probe == core)
        // Every legal action is accepted; sense 1 is counterclockwise; a placement, undo and redo keep the shown tick
        // within the ticks swum.
        #expect(probe.apply(Self.act("clock.show", [0])) == .accepted)
        #expect(probe.apply(Self.act("well.place", [0, 9, 7, 3, 1])) == .accepted && probe.play.actionsLeft == 8)
        let counter = MicroscopicAuroraWell(cell: sites[0], strength: 3, sense: .counterclockwise)
        #expect(probe.play.wells == [counter, nil, nil])
        #expect(probe.apply(Self.act("well.place", [1, 17, 8, 1, 0])) == .accepted && probe.play.actionsLeft == 7)
        let clockwise = MicroscopicAuroraWell(cell: sites[2], strength: 1, sense: .clockwise)
        #expect(probe.play.wells == [counter, clockwise, nil] && probe.shownTick == 0)
        // An occupied cell and an unchanged placement are the kernel's refusals and keep the shown tick.
        #expect(probe.apply(Self.act("well.place", [2, 9, 7, 2, 0])) == action)
        #expect(probe.apply(Self.act("well.place", [0, 9, 7, 3, 1])) == action)
        #expect(probe.apply(Self.act("well.remove", [1])) == .accepted && probe.play.actionsLeft == 6)
        #expect(probe.apply(Self.act("play.undo")) == .accepted && probe.play.actionsLeft == 7)
        #expect(probe.apply(Self.act("play.redo")) == .accepted && probe.play.actionsLeft == 6)
        #expect(probe.shownTick == 0)
        let shown: Int = probe.play.report.ticks
        #expect(probe.apply(Self.act("clock.show", [Double(shown)])) == .accepted && probe.shownTick == shown)
        #expect(probe.apply(Self.act("well.place", [0, 9, 7, 3, 1])) == action && probe.shownTick == shown)
        #expect(probe.apply(Self.act("level.next")) == .accepted && probe.levelNumber == 2)
        #expect(probe.play.stage == .playing && probe.play.actionsLeft == probe.play.level.budget)
        #expect(probe.shownTick == 0)
    }

    @Test func theBudgetRefusesAPlacementButNotThePlay() async throws {
        // Level 1, budget 9: slot 0 on (9, 7) alternates between strengths 1 and 2.
        var core: Core = try await Core.prepare(seed: 0)
        for change in 0..<9 {
            let strength: Double = change % 2 == 0 ? 1 : 2
            #expect(core.apply(Self.act("well.place", [0, 9, 7, strength, 0])) == .accepted)
        }
        #expect(core.play.actionsLeft == 0)
        let before: StateDigest = try Self.digest(core)
        let budget: ActionResult = .rejected(.rule(code: "r02-g19.budget"))
        #expect(core.apply(Self.act("well.place", [0, 9, 7, 3, 0])) == budget)
        #expect(core.apply(Self.act("well.place", [1, 11, 18, 2, 0])) == budget)
        #expect(core.apply(Self.act("well.remove", [0])) == budget)
        #expect(try Self.digest(core) == before)
        #expect(core.apply(Self.act("swim.play")) == .accepted)
        #expect(core.play.stage == .won || core.play.stage == .failed)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLaterOne() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let records: Int = core.play.records.count
        #expect(core.apply(Self.act("well.place", [0, 9, 7, 2, 0])) == .accepted)
        let afterChange: StateDigest = try Self.digest(core)
        #expect(afterChange != opening)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening && core.play.records.count == records + 2)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(try Self.digest(core) == afterChange && core.play.records.count == records + 3)
        // A new placement after an undo (the same one again) clears the redo stack.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("well.place", [0, 9, 7, 2, 0])) == .accepted)
        #expect(try Self.digest(core) == afterChange)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g19.action")))
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
        // The play is undone and redone exactly as well.
        #expect(core.apply(Self.act("swim.play")) == .accepted)
        let afterPlay: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(try Self.digest(core) == afterPlay)
    }

    @Test func showingChangesTheSnapshotButNeverTheDigest() async throws {
        // Level 1 after its certified placement: a swim of all 120 ticks.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(Self.act("well.place", [0, 11, 18, 2, 0])) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let play: MicroscopicAuroraPlay = core.play
        let ticks: Int = play.report.ticks
        #expect(ticks == 120)
        let first: MicroscopicAuroraSceneSnapshot = core.snapshot(time: 1)
        var previous: MicroscopicAuroraSceneSnapshot = first
        for shown in 1...ticks {
            #expect(core.apply(Self.act("clock.show", [Double(shown)])) == .accepted)
            let snapshot: MicroscopicAuroraSceneSnapshot = core.snapshot(time: 1)
            #expect(snapshot.shownTick == shown && snapshot.positions == first.positions)
            #expect(snapshot.position(0) == first.positions[0][shown])
            #expect(snapshot != previous)
            #expect(try Self.digest(core) == before && core.play == play)
            #expect(try core.snapshotPayload() == payload)
            previous = snapshot
        }
        // A refused tick keeps the current one.
        let shown: Int = core.shownTick
        #expect(core.apply(Self.act("clock.show", [121])) == .rejected(.rule(code: "r02-g19.tick")))
        #expect(core.apply(Self.act("clock.show", [3.25])) == .rejected(.rule(code: "r02-g19.not-whole")))
        #expect(core.apply(Self.act("clock.show", [481])) == .rejected(.outOfRange(index: 0)))
        #expect(core.snapshot(time: 1).shownTick == shown && core.shownTick == shown)
        // Reset, restore and level.next return to tick 0.
        var reset: Core = core
        reset.reset()
        let opened: Core = try Core.opening(number: 1)
        #expect(reset.shownTick == 0 && reset == opened)
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && restored.shownTick == 0)
        var next: Core = core
        #expect(next.apply(Self.act("level.next")) == .accepted)
        #expect(next.shownTick == 0)
        // Undoing the placement swims the opening's ticks; the shown tick is clamped to them.
        var undone: Core = core
        #expect(undone.apply(Self.act("play.undo")) == .accepted)
        #expect(undone.shownTick == min(shown, undone.play.report.ticks))
        #expect(undone.snapshot(time: 0).shownTick == undone.shownTick)
    }

    @Test func levelNextWrapsAndResetReturns() async throws {
        var core: Core = try await Core.prepare(seed: 99)
        #expect(core.levelNumber == 100)
        let first: MicroscopicAuroraAction = try #require(try Core.generated(number: 100).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("clock.show", [1])) == .accepted)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 1 && core.play.stage == .playing && !core.play.canUndo)
        #expect(core.play.level == (try Core.level(number: 1)))
        #expect(core.shownTick == 0)
        core.setQualityTier(2)
        core.reset()
        #expect(core.levelNumber == 100 && !core.play.canUndo && core.qualityTier == 2)
        let fresh: Core = try await Core.prepare(seed: 99)
        #expect(core == fresh)
        #expect(try Self.digest(core) == Self.digest(fresh))
        #expect(core.shownTick == fresh.shownTick)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        // Level 21 after a placement, an undo, a redo and an undo.
        var core: Core = try await Core.prepare(seed: 20)
        let first: MicroscopicAuroraAction = try #require(try Core.generated(number: 21).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("clock.show", [1])) == .accepted)
        let savedDigest: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let text: String = String(decoding: payload, as: UTF8.self)
        #expect(text.hasPrefix("{\"level\":21,\"records\":["))
        let restored: Core = try Core.restore(payload: payload, seed: 20)
        let restoredDigest: StateDigest = try Self.digest(restored)
        #expect(restored == core && restoredDigest == savedDigest)
        #expect(restored.play.canRedo && restored.openingNumber == 21 && restored.shownTick == 0)
        var redone: Core = restored
        #expect(redone.apply(Self.act("play.redo")) == .accepted)
        #expect(redone.play.actionsLeft == redone.play.level.budget - 1)
        let other: Core = try Core.restore(payload: payload, seed: 0)
        #expect(other == core && other.openingNumber == 1)
        var otherReset: Core = other
        otherReset.reset()
        #expect(otherReset.levelNumber == 1 && !otherReset.play.canUndo)
        let opening: Core = try await Core.prepare(seed: 7)
        let openingPayload: Data = try opening.snapshotPayload()
        #expect(try Core.restore(payload: openingPayload, seed: 7) == opening)
        // A finished play round-trips too.
        var failed: Core = try await Core.prepare(seed: 20)
        #expect(failed.apply(Self.act("swim.play")) == .accepted && failed.play.stage == .failed)
        let failedRestored: Core = try Core.restore(payload: try failed.snapshotPayload(), seed: 20)
        #expect(failedRestored == failed && failedRestored.outcome?.code == Core.failedCode)
        // Refusals.
        #expect(throws: MicroscopicAuroraRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 20)
        }
        #expect(throws: MicroscopicAuroraRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 20)
        }
        #expect(throws: MicroscopicAuroraRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"21\",\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: MicroscopicAuroraRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: MicroscopicAuroraRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 20)
        }
        // A trace of level 21 restored as level 22 (another seed).
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "{\"level\":21,", with: "{\"level\":22,").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: MicroscopicAuroraRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: wrongLevel, seed: 20)
        }
        // A record of a newer schema.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: MicroscopicAuroraRestoreRefusal.kernel(.malformed("schema 0"))) {
            try Core.restore(payload: newer, seed: 20)
        }
        // An edited trace: the first record's index changed.
        let edited: Data = Data(text.replacingOccurrences(of: "\"index\":0,", with: "\"index\":3,").utf8)
        #expect(edited != payload)
        #expect(throws: MicroscopicAuroraRestoreRefusal.kernel(.malformed("index 0"))) {
            try Core.restore(payload: edited, seed: 20)
        }
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        // Level 1: its certified placement.
        #expect(engine.handle(control: "well.place", values: [0, 11, 18, 2, 0]) == .accepted)
        let before: StateDigest = try engine.digest()
        let saved: ExperienceSnapshot = try engine.snapshot()
        let newer = try ExperienceSnapshot(experience: id, schemaVersion: 2, seed: saved.seed,
                                           stepIndex: saved.stepIndex, digest: saved.digest,
                                           payload: Data(saved.payload.utf8))
        var refused: Bool = false
        do {
            try engine.restore(newer)
        } catch {
            refused = error == .snapshot(.newerSchema(found: 2, current: 1))
        }
        #expect(refused)
        #expect(try engine.digest() == before)
        try engine.restore(saved)
        #expect(try engine.digest() == before)
    }

    @Test func theSnapshotCopiesThePlay() async throws {
        // Level 41 after the first placement of its certified plan, tick 9 shown.
        var core: Core = try await Core.prepare(seed: 40)
        let first: MicroscopicAuroraAction = try #require(try Core.generated(number: 41).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        let play: MicroscopicAuroraPlay = core.play
        let level: MicroscopicAuroraLevel = play.level
        let shown: Int = min(9, play.report.ticks)
        #expect(core.apply(Self.act("clock.show", [Double(shown)])) == .accepted)
        let snapshot: MicroscopicAuroraSceneSnapshot = core.snapshot(time: 2.5)
        let swim: (report: MicroscopicAuroraReport, positions: [[MicroscopicAuroraPoint]]) =
            MicroscopicAuroraDish.swim(level, wells: play.placedWells, keepPositions: true)
        #expect(swim.report == play.report && snapshot.ticksSwum == play.report.ticks)
        #expect(swim.positions.count == play.report.ticks + 1 && snapshot.positions.count == level.swimmers.count)
        for swimmer in level.swimmers.indices {
            #expect(snapshot.positions[swimmer].count == play.report.ticks + 1)
            for tick in swim.positions.indices {
                #expect(snapshot.positions[swimmer][tick] == swim.positions[tick][swimmer])
            }
            #expect(snapshot.velocities[swimmer].last == play.report.finalSwimmers[swimmer].velocity)
            #expect(snapshot.position(swimmer) == swim.positions[shown][swimmer])
        }
        #expect(snapshot.radius == level.radius && snapshot.density == play.report.density)
        #expect(snapshot.litStencil == play.report.litStencil && snapshot.stencil == level.stencil)
        #expect(snapshot.sites == (level.sites ?? []) && snapshot.wells == play.wells)
        #expect(snapshot.coverage == play.report.coverage && snapshot.requiredCoverage == level.coverage)
        #expect(snapshot.coherence == play.report.smallestCoherence && snapshot.requiredCoherence == level.coherence)
        #expect(snapshot.swarm == level.swimmers.count)
        #expect(snapshot.failure == play.report.failure && snapshot.stage == play.stage)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.shownTick == shown && snapshot.levelNumber == 41 && snapshot.time == 2.5)
        #expect(core.renderTier == MicroscopicAuroraTier.of(0))
    }
}
