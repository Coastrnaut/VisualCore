// BinaryGardensExperienceCoreTests — feature 503 (R02-G21-03) T-R02G2103-005 (FR-R02G2103-005, 008, 009;
// SC-R02G2103-004; clarifications Q4, Q5; research R12–R14). The adapter core: the shared conformance checks pass; the
// declared controls, ids, tiers and profile (the quality level names equal `BinaryGardensTier.all`'s, element shares
// 1, 0.5, 0, iteration shares 1, 25/64, 9/64, effect passes 2, 1, 0); the seed picks level `seed % 100 + 1`
// deterministically in stage `playing` with tick 48 shown (seeds 0, 1, 99 and 100 give levels 1, 2, 100 and 1); every
// control is accepted when legal and refused with the state unchanged otherwise (the engine's range checks — the
// declared ranges star 0 … 1, ring 0 … 7, phase 0 … 47, luminosity 0 … 3, tilt 0 … 6 and tick 0 … 60 —,
// `r02-g21.not-whole`, `r02-g21.tick` for ticks 0 and 49 … 60, and every kernel refusal the adapter can meet passing
// through with its code: `r02-g21.action` for a ring, luminosity or tilt the level lacks, a phase off the grid, a
// locked control, an unchanged value and nothing to undo or redo, `r02-g21.budget` and `r02-g21.stage`; `stale` cannot
// arise because every action names the current fingerprint); undo restores the earlier digest exactly and redo the
// later one; `clock.show` changes the snapshot but never the digest, the play or the payload, and an arrangement
// action, the run, undo and redo keep it, while `level.next`, reset and restore return it to 48; the certified plan of
// level 1 wins through the adapter and a run from the opening fails, undo returning the failed play to playing;
// `level.next` wraps 100 to 1 and reset returns; the snapshot round trip and refused payloads (damaged, level out of
// range, a trace of another level, a record of a newer schema, an edited trace, an envelope of a newer schema); the
// certified-candidate table equals the 100 stored witnesses' `skipped` and the directly certified levels equal the
// stored witness levels; `snapshot(time:)` copies the play. Levels are certified once per process, so the run stays
// short. Explicit types, plain loops, single-literal comments. Modelled on MushroomWeatherExperienceCoreTests
// (feature 493).
@testable import BinaryGardensCore
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, BinaryGardens, the package,
/// Packages).
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/binary-gardens/levels", isDirectory: true)

/// Whether the stored witnesses are present (they are in the repository; an isolated copy of the package lacks them).
private let coreWitnessesPresent: Bool = FileManager.default.fileExists(
    atPath: coreWitnessDirectory.appendingPathComponent("001.witness.json").path)

@Suite struct BinaryGardensExperienceCoreTests {
    typealias Core = BinaryGardensExperienceCore

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
    static func act(_ action: BinaryGardensAction) -> ExperienceAction {
        switch action {
        case let .ring(star, index): return act("star.ring", [Double(star), Double(index)])
        case let .phase(star, step): return act("star.phase", [Double(star), Double(step)])
        case let .luminosity(star, index): return act("star.luminosity", [Double(star), Double(index)])
        case let .tilt(step): return act("orbit.tilt", [Double(step)])
        case .run: return act("light.run")
        }
    }

    /// The stored witness of level `number`: its number, `skipped` and level fingerprint, read as plain JSON.
    static func storedWitness(_ number: Int) throws -> (number: Int, skipped: Int, fingerprint: String) {
        let name: String = String(BinaryGardensGenerator.levelID(number).suffix(3)) + ".witness.json"
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
        // Levels 1 and 3 (then 2 and 4). Level 1's certified plan is star 2's luminosity to index 0; level 3's the
        // tilt to 2. The run from the opening fails and is undone.
        let actions: [ScriptedAction] = [ScriptedAction("star.luminosity", [1, 0]), ScriptedAction("play.undo"),
                                         ScriptedAction("play.redo"), ScriptedAction("clock.show", [24]),
                                         ScriptedAction("play.undo"), ScriptedAction("light.run"),
                                         ScriptedAction("play.undo"), ScriptedAction("star.ring", [1, 1]),
                                         ScriptedAction("orbit.tilt", [2]), ScriptedAction("star.phase", [1, 8]),
                                         ScriptedAction("level.next"), ScriptedAction("clock.show", [12]),
                                         ScriptedAction("star.ring", [0, 0]), ScriptedAction("play.undo")]
        // Refused on the openings of levels 1 and 3 (three rings, two luminosity levels, phase step 8, star 1 locked,
        // T_max 0 and 2).
        let rejected: [ScriptedAction] = [ScriptedAction("star.ring", [2, 0]), ScriptedAction("star.ring", [-1, 0]),
                                          ScriptedAction("star.ring", [0, 8]), ScriptedAction("star.ring", [0, 3]),
                                          ScriptedAction("star.ring", [0, 0]), ScriptedAction("star.ring", [0.5, 0]),
                                          ScriptedAction("star.ring", [0]), ScriptedAction("star.phase", [0, 48]),
                                          ScriptedAction("star.phase", [0, 1]), ScriptedAction("star.phase", [1, 1]),
                                          ScriptedAction("star.phase", [0, 0.5]),
                                          ScriptedAction("star.luminosity", [0, 4]),
                                          ScriptedAction("star.luminosity", [0, 2]),
                                          ScriptedAction("star.luminosity", [0, 0]),
                                          ScriptedAction("star.luminosity", [0, 1.5]),
                                          ScriptedAction("orbit.tilt", [7]), ScriptedAction("orbit.tilt", [3]),
                                          ScriptedAction("orbit.tilt", [-1]), ScriptedAction("orbit.tilt", [0.5]),
                                          ScriptedAction("clock.show", [0]), ScriptedAction("clock.show", [49]),
                                          ScriptedAction("clock.show", [60]), ScriptedAction("clock.show", [61]),
                                          ScriptedAction("clock.show", [-1]), ScriptedAction("clock.show", [2.5]),
                                          ScriptedAction("clock.show"), ScriptedAction("play.undo"),
                                          ScriptedAction("play.redo"), ScriptedAction("light.run", [1]),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 2], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries {
            if !entry.passed { print("conformance", entry.check, entry.detail) }
            #expect(entry.passed, "every conformance check passes")
        }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g21.binary-gardens" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g21.binary-gardens.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["star.ring", "star.phase", "star.luminosity", "orbit.tilt", "light.run", "play.undo",
                             "play.redo", "level.next", "clock.show"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[0].ranges == [0...1, 0...7])
        #expect(Core.controls[1].ranges == [0...1, 0...47])
        #expect(Core.controls[2].ranges == [0...1, 0...3])
        #expect(Core.controls[3].ranges == [0...6])
        #expect(Core.controls[8].ranges == [0...60])
        let plainIndices: [Int] = [4, 5, 6, 7]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.starRange == 0...1 && Core.ringRange == 0...7 && Core.phaseRange == 0...47)
        #expect(Core.luminosityRange == 0...3 && Core.tiltRange == 0...6 && Core.tickRange == 0...60)
        #expect(Core.shownTicks == 1...48 && Core.openingTick == 48)
        #expect(Core.qualityTiers == 3 && Core.qualityTiers == BinaryGardensTier.all.count)
        #expect(Core.migrations.currentVersion == 1)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == BinaryGardensTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 0.5, 0] && iterations == [1, 25.0 / 64.0, 9.0 / 64.0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(BinaryGardensExperienceRule.notWhole == "r02-g21.not-whole")
        #expect(BinaryGardensExperienceRule.tick == "r02-g21.tick")
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
            let expected: BinaryGardensLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.arrangement == expected.start)
            // The tutorial is dismissed by the adapter: the play opens in stage playing.
            #expect(first.play.stage == .playing && first.outcome == nil && first.play.failure == nil)
            let opening: Int = expected.tutorial ? 2 : 1
            #expect(first.play.records.count == opening && !first.play.canUndo)
            #expect(first.play.actionsLeft == expected.budget && first.qualityTier == 0 && first.shownTick == 48)
        }
        #expect(try Core.level(number: 1).tutorial && !(try Core.level(number: 100).tutorial))
        #expect(throws: BinaryGardensError.level("number")) { try Core.level(number: 0) }
        #expect(throws: BinaryGardensError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableIsInRange() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for value in Core.certifiedCandidates {
            #expect(value >= 0 && value < BinaryGardensGenerator.maxCandidates)
        }
        // Spot values of the table (levels 1, 4, 42, 54 and 100 skip 1, 3, 12, 24 and 14 candidates).
        #expect(Core.certifiedCandidates[0] == 1 && Core.certifiedCandidates[3] == 3)
        #expect(Core.certifiedCandidates[41] == 12 && Core.certifiedCandidates[53] == 24)
        #expect(Core.certifiedCandidates[99] == 14)
        // Level 4 certifies directly from its table entry and equals the generator's whole search after level 3.
        let entry: BinaryGardensManifestEntry = BinaryGardensManifest.entries[3]
        let searched: BinaryGardensGenerated = try BinaryGardensGenerator.generate(
            entry, previous: try Core.level(number: 3))
        let direct: BinaryGardensGenerated = try #require(Core.certify(entry, index: Core.certifiedCandidates[3]))
        #expect(searched.skipped == 3 && direct == searched)
        #expect(try Core.generated(number: 4) == searched)
        #expect(direct.entry == entry && direct.level.id == BinaryGardensGenerator.levelID(4))
    }

    @Test(.enabled(if: coreWitnessesPresent, "needs the stored witnesses, docs/games/binary-gardens/levels"))
    func theCandidateTableEqualsTheStoredWitnesses() throws {
        for number in 1...100 {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            #expect(witness.number == number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "a table entry differs")
        }
        // Directly certified levels equal the stored witness levels.
        let numbers: [Int] = [1, 4, 42, 54, 100]
        for number in numbers {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            let generated: BinaryGardensGenerated = try Core.generated(number: number)
            #expect(generated.level.fingerprint == witness.fingerprint, "a level fingerprint differs")
            #expect(generated.skipped == witness.skipped)
        }
    }

    @Test func theCertifiedPlanOfLevelOneWinsThroughTheAdapter() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let generated: BinaryGardensGenerated = try Core.generated(number: 1)
        let plan: [BinaryGardensAction] = [.luminosity(star: 1, index: 0)]
        #expect(generated.plan.actions == plan)
        #expect(core.apply(Self.act("clock.show", [7])) == .accepted)
        for step in generated.plan.actions {
            #expect(core.apply(Self.act(step)) == .accepted)
            #expect(core.shownTick == 7, "an arrangement action keeps the shown tick")
        }
        #expect(core.play.arrangement == generated.plan.arrangement && core.play.report.wins)
        #expect(core.apply(Self.act("light.run")) == .accepted)
        #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
        #expect(core.play.failure == nil && core.play.report.wins)
        #expect(core.play.actionsLeft == core.play.level.budget - generated.plan.size)
        #expect(core.snapshot(time: 0).isWon && core.shownTick == 7)
        // A won play is final: an arrangement action, the run, undo and redo are the kernel's stage refusal; showing
        // is still accepted.
        let stage: ActionResult = .rejected(.rule(code: "r02-g21.stage"))
        #expect(core.apply(Self.act("star.ring", [1, 1])) == stage)
        #expect(core.apply(Self.act("star.luminosity", [1, 1])) == stage)
        #expect(core.apply(Self.act("light.run")) == stage)
        #expect(core.apply(Self.act("play.undo")) == stage)
        #expect(core.apply(Self.act("play.redo")) == stage)
        #expect(core.apply(Self.act("clock.show", [48])) == .accepted && core.shownTick == 48)
        #expect(core.apply(Self.act("clock.show", [49])) == .rejected(.rule(code: "r02-g21.tick")))
    }

    @Test func aRunFromTheOpeningFailsAndUndoReturnsToPlaying() async throws {
        // The certified plan is minimal and has one action, so the starting arrangement does not win.
        var core: Core = try await Core.prepare(seed: 0)
        let openingDigest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("clock.show", [30])) == .accepted)
        #expect(core.apply(Self.act("light.run")) == .accepted)
        #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode)
        let failure: BinaryGardensFailure = try #require(core.play.failure)
        #expect(core.play.level.startReport.failure == failure && core.play.actionsLeft == core.play.level.budget)
        let snapshot: BinaryGardensSceneSnapshot = core.snapshot(time: 0)
        #expect(snapshot.failure == failure && snapshot.stage == .failed && snapshot.shownTick == 30)
        let stage: ActionResult = .rejected(.rule(code: "r02-g21.stage"))
        #expect(core.apply(Self.act("star.luminosity", [1, 0])) == stage)
        #expect(core.apply(Self.act("light.run")) == stage)
        #expect(core.apply(Self.act("play.redo")) == stage)
        #expect(core.apply(Self.act("clock.show", [1])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.play.stage == .playing && core.outcome == nil && core.play.failure == nil)
        #expect(core.shownTick == 1, "undo keeps the shown tick")
        #expect(try Self.digest(core) == openingDigest)
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: rings 5, 6 and 8, luminosity levels 19 and 27, phase step 8, T_max 0, budget 9; star 1 locked on
        // ring 0 at phase 32 and luminosity 1; star 2 on ring 0 at phase 16 and luminosity 1, its ring and luminosity
        // adjustable.
        let core: Core = try await Core.prepare(seed: 0)
        let level: BinaryGardensLevel = core.play.level
        #expect(level.ringRadii == [5, 6, 8] && level.luminosityLevels == [19, 27] && level.phaseStep == 8)
        #expect(level.maxTilt == 0 && level.budget == 9)
        #expect(level.start == BinaryGardensArrangement(rings: [0, 0], phases: [32, 16], luminosities: [1, 1], tilt: 0))
        let opening: StateDigest = try Self.digest(core)
        let records: Int = core.play.records.count
        let illegal: [ExperienceAction] = [Self.act("star.ring", [2, 0]), Self.act("star.ring", [-1, 0]),
                                           Self.act("star.ring", [0, 8]), Self.act("star.ring", [0, 0.5]),
                                           Self.act("star.ring", [0, .nan]), Self.act("star.ring", [0]),
                                           Self.act("star.ring"), Self.act("star.ring", [1, 3]),
                                           Self.act("star.ring", [0, 1]), Self.act("star.ring", [1, 0]),
                                           Self.act("star.phase", [0, 48]), Self.act("star.phase", [1, 1]),
                                           Self.act("star.phase", [1, 8]), Self.act("star.phase", [0, 0.5]),
                                           Self.act("star.luminosity", [0, 4]), Self.act("star.luminosity", [1, 2]),
                                           Self.act("star.luminosity", [0, 0]), Self.act("star.luminosity", [1, 1]),
                                           Self.act("star.luminosity", [1, 0.5]), Self.act("orbit.tilt", [7]),
                                           Self.act("orbit.tilt", [1]), Self.act("orbit.tilt", [0]),
                                           Self.act("orbit.tilt", [0.5]), Self.act("clock.show", [0]),
                                           Self.act("clock.show", [49]), Self.act("clock.show", [60]),
                                           Self.act("clock.show", [61]), Self.act("clock.show", [-1]),
                                           Self.act("clock.show", [2.5]), Self.act("clock.show", [1, 1]),
                                           Self.act("play.undo"), Self.act("play.redo"),
                                           Self.act("play.undo", [1]), Self.act("light.run", [1]),
                                           Self.act("level.next", [1]), Self.act("nope")]
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
        #expect(probe.apply(Self.act("star.ring", [2, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("star.ring", [0, 8])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("star.phase", [0, 48])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("star.luminosity", [0, 4])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("orbit.tilt", [7])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("clock.show", [61])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("clock.show", [-1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("star.ring", [0, .nan])) == .rejected(.nonFinite(index: 1)))
        #expect(probe.apply(Self.act("star.ring", [0])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("orbit.tilt")) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(probe.apply(Self.act("clock.show", [1, 1])) == .rejected(.wrongValueCount(expected: 1, found: 2)))
        let noValues: ActionResult = .rejected(.wrongValueCount(expected: 0, found: 1))
        #expect(probe.apply(Self.act("light.run", [1])) == noValues)
        #expect(probe.apply(Self.act("play.undo", [1])) == noValues)
        #expect(probe.apply(Self.act("play.redo", [1])) == noValues)
        #expect(probe.apply(Self.act("level.next", [1])) == noValues)
        let notWhole: ActionResult = .rejected(.rule(code: BinaryGardensExperienceRule.notWhole))
        #expect(probe.apply(Self.act("star.ring", [0, 0.5])) == notWhole)
        #expect(probe.apply(Self.act("star.phase", [0, 0.5])) == notWhole)
        #expect(probe.apply(Self.act("star.luminosity", [1, 0.5])) == notWhole)
        #expect(probe.apply(Self.act("orbit.tilt", [0.5])) == notWhole)
        #expect(probe.apply(Self.act("clock.show", [2.5])) == notWhole)
        // Ticks 0 and 49 … 60: the adapter's refusal, without touching the kernel.
        let tick: ActionResult = .rejected(.rule(code: BinaryGardensExperienceRule.tick))
        for shown in [0, 49, 50, 55, 60] {
            #expect(probe.apply(Self.act("clock.show", [Double(shown)])) == tick)
        }
        // The kernel's refusals pass through with their codes: a ring, luminosity or tilt the level lacks, a phase off
        // the grid, a locked control, an unchanged value, nothing to undo or redo.
        let action: ActionResult = .rejected(.rule(code: "r02-g21.action"))
        #expect(probe.apply(Self.act("star.ring", [1, 3])) == action)
        #expect(probe.apply(Self.act("star.ring", [0, 1])) == action)
        #expect(probe.apply(Self.act("star.ring", [1, 0])) == action)
        #expect(probe.apply(Self.act("star.phase", [1, 1])) == action)
        #expect(probe.apply(Self.act("star.phase", [1, 8])) == action)
        #expect(probe.apply(Self.act("star.luminosity", [1, 2])) == action)
        #expect(probe.apply(Self.act("star.luminosity", [0, 0])) == action)
        #expect(probe.apply(Self.act("star.luminosity", [1, 1])) == action)
        #expect(probe.apply(Self.act("orbit.tilt", [1])) == action)
        #expect(probe.apply(Self.act("orbit.tilt", [0])) == action)
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe == core && probe.play.records.count == records && probe.shownTick == 48)
        // Every legal tick is accepted and changes nothing else.
        for shown in 1...48 {
            #expect(probe.apply(Self.act("clock.show", [Double(shown)])) == .accepted && probe.shownTick == shown)
        }
        #expect(try Self.digest(probe) == opening && probe == core)
        // Every legal action is accepted; an arrangement action, undo and redo keep the shown tick.
        #expect(probe.apply(Self.act("clock.show", [12])) == .accepted)
        #expect(probe.apply(Self.act("star.ring", [1, 1])) == .accepted && probe.play.actionsLeft == 8)
        #expect(probe.play.arrangement.rings == [0, 1])
        #expect(probe.apply(Self.act("star.ring", [1, 2])) == .accepted && probe.play.actionsLeft == 7)
        #expect(probe.apply(Self.act("star.luminosity", [1, 0])) == .accepted && probe.play.actionsLeft == 6)
        #expect(probe.play.arrangement.luminosities == [1, 0] && probe.shownTick == 12)
        #expect(probe.apply(Self.act("play.undo")) == .accepted && probe.play.actionsLeft == 7)
        #expect(probe.apply(Self.act("play.redo")) == .accepted && probe.play.actionsLeft == 6)
        #expect(probe.shownTick == 12)
        #expect(probe.apply(Self.act("level.next")) == .accepted && probe.levelNumber == 2)
        #expect(probe.play.stage == .playing && probe.play.actionsLeft == probe.play.level.budget)
        #expect(probe.shownTick == 48)
    }

    @Test func theBudgetRefusesAnArrangementActionButNotTheRun() async throws {
        // Level 1, budget 9: star 2's luminosity alternates between index 0 and index 1.
        var core: Core = try await Core.prepare(seed: 0)
        for change in 0..<9 {
            let index: Double = change % 2 == 0 ? 0 : 1
            #expect(core.apply(Self.act("star.luminosity", [1, index])) == .accepted)
        }
        #expect(core.play.actionsLeft == 0 && core.play.arrangement.luminosities == [1, 0])
        let before: StateDigest = try Self.digest(core)
        let budget: ActionResult = .rejected(.rule(code: "r02-g21.budget"))
        #expect(core.apply(Self.act("star.luminosity", [1, 1])) == budget)
        #expect(core.apply(Self.act("star.ring", [1, 1])) == budget)
        #expect(try Self.digest(core) == before)
        #expect(core.apply(Self.act("light.run")) == .accepted)
        #expect(core.play.stage == .won)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLaterOne() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let records: Int = core.play.records.count
        #expect(core.apply(Self.act("star.ring", [1, 1])) == .accepted)
        let afterChange: StateDigest = try Self.digest(core)
        #expect(afterChange != opening)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening && core.play.records.count == records + 2)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(try Self.digest(core) == afterChange && core.play.records.count == records + 3)
        // A new change after an undo (the same one again) clears the redo stack.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("star.ring", [1, 1])) == .accepted)
        #expect(try Self.digest(core) == afterChange)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g21.action")))
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
        // A luminosity is undone exactly too.
        #expect(core.apply(Self.act("star.luminosity", [1, 0])) == .accepted)
        #expect(core.apply(Self.act("star.ring", [1, 2])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
        // The run is undone and redone exactly as well.
        #expect(core.apply(Self.act("light.run")) == .accepted)
        let afterRun: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(try Self.digest(core) == afterRun)
    }

    @Test func showingChangesTheSnapshotButNeverTheDigest() async throws {
        // Level 1 after its certified plan.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(Self.act("star.luminosity", [1, 0])) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let play: BinaryGardensPlay = core.play
        let first: BinaryGardensSceneSnapshot = core.snapshot(time: 1)
        #expect(first.shownTick == 48)
        var previous: BinaryGardensSceneSnapshot = first
        for shown in 1...47 {
            #expect(core.apply(Self.act("clock.show", [Double(shown)])) == .accepted)
            let snapshot: BinaryGardensSceneSnapshot = core.snapshot(time: 1)
            #expect(snapshot.shownTick == shown && snapshot.worlds == first.worlds)
            #expect(snapshot.starPositions == first.starPositions)
            #expect(snapshot != previous)
            #expect(try Self.digest(core) == before && core.play == play)
            #expect(try core.snapshotPayload() == payload)
            previous = snapshot
        }
        // A refused tick keeps the current one.
        let shown: Int = core.shownTick
        #expect(core.apply(Self.act("clock.show", [49])) == .rejected(.rule(code: "r02-g21.tick")))
        #expect(core.apply(Self.act("clock.show", [0])) == .rejected(.rule(code: "r02-g21.tick")))
        #expect(core.apply(Self.act("clock.show", [3.25])) == .rejected(.rule(code: "r02-g21.not-whole")))
        #expect(core.apply(Self.act("clock.show", [61])) == .rejected(.outOfRange(index: 0)))
        #expect(core.apply(Self.act("clock.show", [.nan])) == .rejected(.nonFinite(index: 0)))
        #expect(core.snapshot(time: 1).shownTick == shown && core.shownTick == shown)
        #expect(try Self.digest(core) == before)
        // Reset, restore and level.next return to tick 48.
        var reset: Core = core
        reset.reset()
        let opened: Core = try Core.opening(number: 1)
        #expect(reset.shownTick == 48 && reset == opened)
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && restored.shownTick == 48)
        var next: Core = core
        #expect(next.apply(Self.act("level.next")) == .accepted)
        #expect(next.shownTick == 48)
        // Undo and the run keep the shown tick: the report always covers ticks 1 … 48.
        var undone: Core = core
        #expect(undone.apply(Self.act("play.undo")) == .accepted)
        #expect(undone.shownTick == shown && undone.snapshot(time: 0).shownTick == shown)
        var ran: Core = core
        #expect(ran.apply(Self.act("light.run")) == .accepted && ran.shownTick == shown)
    }

    @Test func levelNextWrapsAndResetReturns() async throws {
        var core: Core = try await Core.prepare(seed: 99)
        #expect(core.levelNumber == 100)
        let first: BinaryGardensAction = try #require(try Core.generated(number: 100).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("clock.show", [1])) == .accepted)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 1 && core.play.stage == .playing && !core.play.canUndo)
        #expect(core.play.level == (try Core.level(number: 1)))
        #expect(core.shownTick == 48)
        core.setQualityTier(2)
        core.reset()
        #expect(core.levelNumber == 100 && !core.play.canUndo && core.qualityTier == 2)
        let fresh: Core = try await Core.prepare(seed: 99)
        #expect(core == fresh)
        #expect(try Self.digest(core) == Self.digest(fresh))
        #expect(core.shownTick == fresh.shownTick)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        // Level 21 after a change, an undo, a redo and an undo.
        var core: Core = try await Core.prepare(seed: 20)
        let first: BinaryGardensAction = try #require(try Core.generated(number: 21).plan.actions.first)
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
        #expect(restored.play.canRedo && restored.openingNumber == 21 && restored.shownTick == 48)
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
        #expect(failed.apply(Self.act("light.run")) == .accepted && failed.play.stage == .failed)
        let failedRestored: Core = try Core.restore(payload: try failed.snapshotPayload(), seed: 20)
        #expect(failedRestored == failed && failedRestored.outcome?.code == Core.failedCode)
        // Refusals.
        #expect(throws: BinaryGardensRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 20)
        }
        #expect(throws: BinaryGardensRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 20)
        }
        #expect(throws: BinaryGardensRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"21\",\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: BinaryGardensRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: BinaryGardensRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 20)
        }
        // A trace of level 21 restored as level 22 (another seed).
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "{\"level\":21,", with: "{\"level\":22,").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: BinaryGardensRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: wrongLevel, seed: 20)
        }
        // A record of a newer schema.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: BinaryGardensRestoreRefusal.kernel(.malformed("schema 0"))) {
            try Core.restore(payload: newer, seed: 20)
        }
        // An edited trace: the first record's index changed.
        let edited: Data = Data(text.replacingOccurrences(of: "\"index\":0,", with: "\"index\":3,").utf8)
        #expect(edited != payload)
        #expect(throws: BinaryGardensRestoreRefusal.kernel(.malformed("index 0"))) {
            try Core.restore(payload: edited, seed: 20)
        }
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        // Level 1: its certified plan.
        #expect(engine.handle(control: "star.luminosity", values: [1, 0]) == .accepted)
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
        // Level 41 after the first change of its certified plan, tick 9 shown.
        var core: Core = try await Core.prepare(seed: 40)
        let first: BinaryGardensAction = try #require(try Core.generated(number: 41).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        let play: BinaryGardensPlay = core.play
        let level: BinaryGardensLevel = play.level
        #expect(core.apply(Self.act("clock.show", [9])) == .accepted)
        let snapshot: BinaryGardensSceneSnapshot = core.snapshot(time: 2.5)
        let report: BinaryGardensReport = BinaryGardensSky.report(level, arrangement: play.arrangement)
        #expect(report == play.report)
        #expect(snapshot.starPositions == report.starPositions && snapshot.arrangement == play.arrangement)
        for (index, world) in level.worlds.enumerated() {
            let light: BinaryGardensWorldLight = report.worlds[index]
            #expect(snapshot.worlds[index].flux == light.flux && snapshot.worlds[index].bands == light.bands)
            #expect(snapshot.worlds[index].radius == world.radius && snapshot.band(index) == light.bands[8])
            #expect(snapshot.share(index, star: 1) == light.shares[8][1])
        }
        #expect(snapshot.failure == play.report.failure && snapshot.stage == play.stage)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.shownTick == 9 && snapshot.levelNumber == 41 && snapshot.time == 2.5)
        #expect(core.renderTier == BinaryGardensTier.of(0))
    }
}
