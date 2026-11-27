// MushroomWeatherExperienceCoreTests — feature 493 (R02-G20-03) T-R02G2003-005 (FR-R02G2003-005, 008, 009;
// SC-R02G2003-004; clarifications Q4, Q5). The adapter core: the shared conformance checks pass; the declared controls,
// ids, tiers and profile (the quality level names equal `MushroomWeatherTier.all`'s); the seed picks level `seed % 100
// + 1` deterministically in stage `playing` with cycle 0 shown (seeds 0, 1, 99 and 100 give levels 1, 2, 100 and 1);
// every control is accepted when legal and refused with the state unchanged otherwise (the engine's range checks,
// `r02-g20.not-whole`, `r02-g20.cycle` for a cycle past the cycles run, and every kernel refusal the adapter can meet
// passing through with its code: `r02-g20.action` for a slot or vent the level lacks, a cell off the floor, a colony
// cell, a cell that is not a site, an occupied cell, an unchanged pod, vent or moonlight, an empty slot and nothing to
// undo or redo, `r02-g20.budget` and `r02-g20.stage`; `stale` cannot arise because every action names the current
// fingerprint); vent state 1 is open and 0 shut; undo restores the earlier digest exactly and redo the later one;
// `clock.show` changes the snapshot but never the digest, the play or the payload, refuses bad values, and an
// arrangement action, undo and redo keep it (clamped to the cycles run), while a new opening (a mode or a level), reset
// and restore return it to 0; the certified plan of level 1 wins through the adapter and a run from the opening fails, undo returning the
// failed play to playing; `level.next` needs an open level (no wrap) and reset returns; the snapshot round trip and refused payloads
// (damaged, level out of range, a trace of another level, a record of a newer schema, an edited trace, an envelope of a
// newer schema); the certified-candidate table equals the 100 stored witnesses' `skipped` and the directly certified
// levels equal the stored witness levels; `snapshot(time:)` copies the play, its humidity the kernel's. Levels are
// certified once per process, so the run stays short. Explicit types, plain loops, single-literal comments. Modelled
// on MicroscopicAuroraExperienceCoreTests (feature 483).
// Feature 495 (R02-G20-05) T-R02G2005-004: schema 2 and digest v2, fourteen controls, `level.next` to the next open
// level (no wrap; `r02-g20.locked` when none); the progression itself is tested in
// `MushroomWeatherProgressionCoreTests`.
// Feature 497 (R02-G20-07) T-R02G2007-003: schema 3 and digest v3, eighteen controls (`replay.start` 1 … 100,
// `replay.step`, `replay.stop`, `settings.sound` 0 … 1), the replay and sound controls refused without a verified
// result or with wrong values, an opening with the sound off and nothing dropped, and the refusal of schema 4; the
// migrations 1 → 3 and 2 → 3 through the engine, reconciliation on restore (an edited result dropped and counted, the
// count never digested), the replay rules and codes (`r02-g20.no-replay`, `r02-g20.replay`, `r02-g20.replay-end`,
// presentation and sound accepted during a replay, `replay.stop` at a locked daily level going to the frontier), a
// replay saved mid-way restoring while a changed, reordered or undo-carrying saved replay is refused `damaged`, the
// sound setting (snapshotted, never digested, off after a reset), and the feedback of a replay (the refusal words, a
// step announced like the action it applies, a replayed win claiming no stars) are in `MushroomWeatherReplayCoreTests`
// at the end of this file.
@testable import MushroomWeatherCore
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, MushroomWeather, the package,
/// Packages).
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/mushroom-weather/levels", isDirectory: true)

/// Whether the stored witnesses are present (they are in the repository; an isolated copy of the package lacks them).
private let coreWitnessesPresent: Bool = FileManager.default.fileExists(
    atPath: coreWitnessDirectory.appendingPathComponent("001.witness.json").path)

@Suite struct MushroomWeatherExperienceCoreTests {
    typealias Core = MushroomWeatherExperienceCore

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
    static func act(_ action: MushroomWeatherAction) -> ExperienceAction {
        switch action {
        case let .place(slot, cell):
            return act("pod.place", [Double(slot), Double(cell.row), Double(cell.column)])
        case let .remove(slot):
            return act("pod.remove", [Double(slot)])
        case let .vent(index, open):
            return act("vent.set", [Double(index), open ? 1 : 0])
        case let .moonlight(level):
            return act("moon.set", [Double(level)])
        case .run:
            return act("weather.run")
        }
    }

    /// The stored witness of level `number`: its number, `skipped` and level fingerprint, read as plain JSON.
    static func storedWitness(_ number: Int) throws -> (number: Int, skipped: Int, fingerprint: String) {
        let name: String = String(MushroomWeatherGenerator.levelID(number).suffix(3)) + ".witness.json"
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
        // Levels 1 and 3. Level 1's certified plan is a pod on (2, 5) and its vent shut; the run from the opening fails
        // and is undone; practice reopens the level with the budget raised to 24 (feature 495: `level.next` needs the
        // next level open), where a pod on the site (0, 4) is placed and undone.
        let actions: [ScriptedAction] = [ScriptedAction("pod.place", [0, 2, 5]), ScriptedAction("play.undo"),
                                         ScriptedAction("play.redo"), ScriptedAction("clock.show", [3]),
                                         ScriptedAction("play.undo"), ScriptedAction("weather.run"),
                                         ScriptedAction("play.undo"), ScriptedAction("moon.set", [3]),
                                         ScriptedAction("pod.place", [1, 0, 4]), ScriptedAction("pod.remove", [1]),
                                         ScriptedAction("vent.set", [0, 0]), ScriptedAction("mode.practice"),
                                         ScriptedAction("clock.show", [2]),
                                         ScriptedAction("pod.place", [0, 0, 4]), ScriptedAction("play.undo")]
        // Refused on the openings of levels 1 and 3 (two slots, one vent, no pod placed, runs of at most 35 cycles).
        let rejected: [ScriptedAction] = [ScriptedAction("pod.place", [6, 0, 4]),
                                          ScriptedAction("pod.place", [-1, 0, 4]),
                                          ScriptedAction("pod.place", [2, 0, 4]),
                                          ScriptedAction("pod.place", [0, 12, 4]),
                                          ScriptedAction("pod.place", [0, 0, 14]),
                                          ScriptedAction("pod.place", [0, 7, 0]),
                                          ScriptedAction("pod.place", [0, 0, 0]),
                                          ScriptedAction("pod.place", [0.5, 0, 4]),
                                          ScriptedAction("pod.place", [0, 0]),
                                          ScriptedAction("pod.remove", [0]),
                                          ScriptedAction("pod.remove", [6]),
                                          ScriptedAction("pod.remove", [0.5]),
                                          ScriptedAction("pod.remove"),
                                          ScriptedAction("vent.set", [1, 1]),
                                          ScriptedAction("vent.set", [6, 1]),
                                          ScriptedAction("vent.set", [0, 2]),
                                          ScriptedAction("vent.set", [0, 0.5]),
                                          ScriptedAction("moon.set", [4]),
                                          ScriptedAction("moon.set", [-1]),
                                          ScriptedAction("moon.set", [1.5]),
                                          ScriptedAction("clock.show", [200]),
                                          ScriptedAction("clock.show", [201]),
                                          ScriptedAction("clock.show", [-1]),
                                          ScriptedAction("clock.show", [2.5]),
                                          ScriptedAction("clock.show"),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("weather.run", [1]), ScriptedAction("level.next", [1]),
                                          ScriptedAction("level.next"), ScriptedAction("level.select", [4]),
                                          ScriptedAction("level.select", [0]), ScriptedAction("level.select"),
                                          ScriptedAction("mode.daily", [2026, 2, 30]),
                                          ScriptedAction("mode.daily", [2026, 13, 1]),
                                          ScriptedAction("mode.daily", [2026, 1]),
                                          ScriptedAction("mode.practice", [1]), ScriptedAction("mode.campaign", [1]),
                                          ScriptedAction("tutorial.dismiss", [1]),
                                          // Feature 497: no replay without a verified result; sound whole 0 … 1.
                                          ScriptedAction("replay.start", [1]), ScriptedAction("replay.start", [0]),
                                          ScriptedAction("replay.step"), ScriptedAction("replay.step", [1]),
                                          ScriptedAction("replay.stop"), ScriptedAction("replay.stop", [1]),
                                          ScriptedAction("settings.sound", [2]),
                                          ScriptedAction("settings.sound", [0.5]), ScriptedAction("settings.sound"),
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
        #expect(Core.experienceID == "r02-g20.mushroom-weather" && Core.schemaVersion == 3)
        #expect(Core.digestDomain == "r02-g20.mushroom-weather.v3")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["pod.place", "pod.remove", "vent.set", "moon.set", "weather.run", "play.undo",
                             "play.redo", "level.next", "clock.show", "level.select", "mode.daily", "mode.practice",
                             "mode.campaign", "tutorial.dismiss", "replay.start", "replay.step", "replay.stop",
                             "settings.sound"]
        #expect(Core.actionIDs == ids && Core.controls.count == 18)
        #expect(Core.controls[14].ranges == [1...100] && Core.controls[17].ranges == [0...1])
        #expect(Core.controls[0].ranges == [0...5, 0...11, 0...13])
        #expect(Core.controls[1].ranges == [0...5])
        #expect(Core.controls[2].ranges == [0...5, 0...1])
        #expect(Core.controls[3].ranges == [0...3])
        #expect(Core.controls[8].ranges == [0...200])
        #expect(Core.controls[9].ranges == [1...100])
        #expect(Core.controls[10].ranges == [1...9999, 1...12, 1...31])
        let plainIndices: [Int] = [4, 5, 6, 7, 11, 12, 13, 15, 16]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.qualityTiers == MushroomWeatherTier.all.count)
        #expect(Core.migrations.currentVersion == 3)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == MushroomWeatherTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 0.5, 0] && iterations == [1, 10.0 / 16.0, 0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(MushroomWeatherExperienceRule.notWhole == "r02-g20.not-whole")
        #expect(MushroomWeatherExperienceRule.cycle == "r02-g20.cycle")
        #expect(MushroomWeatherExperienceRule.locked == "r02-g20.locked")
        #expect(MushroomWeatherExperienceRule.date == "r02-g20.date")
        #expect(MushroomWeatherExperienceRule.noReplay == "r02-g20.no-replay")
        #expect(MushroomWeatherExperienceRule.replayEnd == "r02-g20.replay-end")
        #expect(MushroomWeatherExperienceRule.replay == "r02-g20.replay")
        #expect(Core.practiceBudget == 24)
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
            let expected: MushroomWeatherLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.arrangement == expected.start)
            // The tutorial is dismissed by the adapter: the play opens in stage playing.
            #expect(first.play.stage == .playing && first.outcome == nil && first.play.failure == nil)
            let opening: Int = expected.tutorial ? 2 : 1
            #expect(first.play.records.count == opening && !first.play.canUndo)
            #expect(first.play.actionsLeft == expected.budget && first.qualityTier == 0 && first.shownCycle == 0)
            // Feature 497: sound off and nothing dropped at an opening.
            #expect(!first.soundOn && first.reconciliationDropped == 0)
        }
        #expect(try Core.level(number: 1).tutorial && !(try Core.level(number: 100).tutorial))
        #expect(throws: MushroomWeatherError.level("number")) { try Core.level(number: 0) }
        #expect(throws: MushroomWeatherError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableIsInRange() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for value in Core.certifiedCandidates {
            #expect(value >= 0 && value < MushroomWeatherGenerator.maxCandidates)
        }
        // Spot values of the table (levels 4, 27, 40 and 72 skip 1, 2, 2 and 2 candidates).
        #expect(Core.certifiedCandidates[0] == 0 && Core.certifiedCandidates[3] == 1)
        #expect(Core.certifiedCandidates[26] == 2 && Core.certifiedCandidates[39] == 2)
        #expect(Core.certifiedCandidates[71] == 2)
        // Level 4 certifies directly from its table entry and equals the generator's whole search after level 3.
        let entry: MushroomWeatherManifestEntry = MushroomWeatherManifest.entries[3]
        let searched: MushroomWeatherGenerated = try MushroomWeatherGenerator.generate(
            entry, previous: try Core.level(number: 3))
        let direct: MushroomWeatherGenerated = try #require(Core.certify(entry, index: Core.certifiedCandidates[3]))
        #expect(searched.skipped == 1 && direct == searched)
        #expect(try Core.generated(number: 4) == searched)
        #expect(direct.entry == entry && direct.level.id == MushroomWeatherGenerator.levelID(4))
    }

    @Test(.enabled(if: coreWitnessesPresent, "needs the stored witnesses, docs/games/mushroom-weather/levels"))
    func theCandidateTableEqualsTheStoredWitnesses() throws {
        for number in 1...100 {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            #expect(witness.number == number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "a table entry differs")
        }
        // Directly certified levels equal the stored witness levels.
        let numbers: [Int] = [1, 4, 27, 72, 100]
        for number in numbers {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            let generated: MushroomWeatherGenerated = try Core.generated(number: number)
            #expect(generated.level.fingerprint == witness.fingerprint, "a level fingerprint differs")
            #expect(generated.skipped == witness.skipped)
        }
    }

    @Test func theCertifiedPlanOfLevelOneWinsThroughTheAdapter() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let generated: MushroomWeatherGenerated = try Core.generated(number: 1)
        let pod: MushroomWeatherCell = MushroomWeatherCell(row: 2, column: 5)
        let plan: [MushroomWeatherAction] = [.place(slot: 0, cell: pod), .vent(index: 0, open: false)]
        #expect(generated.plan.actions == plan)
        #expect(core.apply(Self.act("clock.show", [1])) == .accepted)
        for step in generated.plan.actions {
            #expect(core.apply(Self.act(step)) == .accepted)
            #expect(core.shownCycle == 1, "an arrangement action keeps the shown cycle")
        }
        #expect(core.play.arrangement.pods == [pod, nil] && core.play.arrangement.ventsOpen == [false])
        #expect(core.play.report.wins && core.play.report.cycles == 31)
        #expect(core.apply(Self.act("weather.run")) == .accepted)
        #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
        #expect(core.play.failure == nil && core.play.report.wins)
        #expect(core.play.actionsLeft == core.play.level.budget - generated.plan.size)
        #expect(core.snapshot(time: 0).isWon && core.shownCycle == 1)
        // A won play is final: an arrangement action, the run, undo and redo are the kernel's stage refusal; showing
        // is still accepted.
        let stage: ActionResult = .rejected(.rule(code: "r02-g20.stage"))
        #expect(core.apply(Self.act("pod.place", [1, 0, 4])) == stage)
        #expect(core.apply(Self.act("pod.remove", [0])) == stage)
        #expect(core.apply(Self.act("vent.set", [0, 1])) == stage)
        #expect(core.apply(Self.act("moon.set", [3])) == stage)
        #expect(core.apply(Self.act("weather.run")) == stage)
        #expect(core.apply(Self.act("play.undo")) == stage)
        #expect(core.apply(Self.act("play.redo")) == stage)
        #expect(core.apply(Self.act("clock.show", [31])) == .accepted && core.shownCycle == 31)
        #expect(core.apply(Self.act("clock.show", [32])) == .rejected(.rule(code: "r02-g20.cycle")))
    }

    @Test func aRunFromTheOpeningFailsAndUndoReturnsToPlaying() async throws {
        // The certified plan is minimal and has two actions, so the starting arrangement does not win.
        var core: Core = try await Core.prepare(seed: 0)
        let openingDigest: StateDigest = try Self.digest(core)
        let cycles: Int = core.play.report.cycles
        #expect(core.apply(Self.act("clock.show", [Double(cycles)])) == .accepted)
        #expect(core.apply(Self.act("weather.run")) == .accepted)
        #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode)
        let failure: MushroomWeatherFailure = try #require(core.play.failure)
        #expect(core.play.level.startReport.failure == failure && core.play.actionsLeft == core.play.level.budget)
        let snapshot: MushroomWeatherSceneSnapshot = core.snapshot(time: 0)
        #expect(snapshot.failure == failure && snapshot.stage == .failed && snapshot.shownCycle == cycles)
        let stage: ActionResult = .rejected(.rule(code: "r02-g20.stage"))
        #expect(core.apply(Self.act("pod.place", [0, 2, 5])) == stage)
        #expect(core.apply(Self.act("weather.run")) == stage)
        #expect(core.apply(Self.act("play.redo")) == stage)
        #expect(core.apply(Self.act("clock.show", [0])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.play.stage == .playing && core.outcome == nil && core.play.failure == nil)
        #expect(core.shownCycle == 0)
        #expect(try Self.digest(core) == openingDigest)
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: a 6 × 6 floor, blocked (2, 1), (4, 3) and (5, 0), colonies on (1, 5) and (5, 1), sites (0, 4),
        // (2, 4), (2, 5) and (5, 2), two slots, one vent on (0, 5) open, moonlight 2, budget 9.
        let core: Core = try await Core.prepare(seed: 0)
        let level: MushroomWeatherLevel = core.play.level
        let sites: [MushroomWeatherCell] = [MushroomWeatherCell(row: 0, column: 4),
                                            MushroomWeatherCell(row: 2, column: 4),
                                            MushroomWeatherCell(row: 2, column: 5),
                                            MushroomWeatherCell(row: 5, column: 2)]
        #expect(level.rows == 6 && level.columns == 6 && level.sites == sites && level.budget == 9)
        #expect(level.start.pods == [nil, nil] && level.start.ventsOpen == [true] && level.start.moonlight == 2)
        let cycles: Int = core.play.report.cycles
        #expect(cycles >= 1 && cycles <= level.length)
        let opening: StateDigest = try Self.digest(core)
        let records: Int = core.play.records.count
        let illegal: [ExperienceAction] = [Self.act("pod.place", [6, 0, 4]), Self.act("pod.place", [-1, 0, 4]),
                                           Self.act("pod.place", [0, 12, 4]), Self.act("pod.place", [0, 0, 14]),
                                           Self.act("pod.place", [0, 0.5, 4]), Self.act("pod.place", [0, 0, .nan]),
                                           Self.act("pod.place", [0, 0]), Self.act("pod.place"),
                                           Self.act("pod.place", [2, 0, 4]), Self.act("pod.place", [0, 6, 0]),
                                           Self.act("pod.place", [0, 2, 1]), Self.act("pod.place", [0, 1, 5]),
                                           Self.act("pod.place", [0, 0, 0]),
                                           Self.act("pod.remove", [0]), Self.act("pod.remove", [2]),
                                           Self.act("pod.remove", [6]), Self.act("pod.remove", [1.5]),
                                           Self.act("pod.remove"),
                                           Self.act("vent.set", [0, 1]), Self.act("vent.set", [1, 0]),
                                           Self.act("vent.set", [6, 0]), Self.act("vent.set", [0, 2]),
                                           Self.act("vent.set", [0, 0.5]), Self.act("vent.set", [0]),
                                           Self.act("moon.set", [2]), Self.act("moon.set", [4]),
                                           Self.act("moon.set", [-1]), Self.act("moon.set", [2.5]),
                                           Self.act("clock.show", [Double(cycles + 1)]),
                                           Self.act("clock.show", [200]), Self.act("clock.show", [201]),
                                           Self.act("clock.show", [-1]), Self.act("clock.show", [2.5]),
                                           Self.act("clock.show", [1, 1]), Self.act("play.undo"),
                                           Self.act("play.redo"), Self.act("play.undo", [1]),
                                           Self.act("weather.run", [1]), Self.act("level.next", [1]),
                                           Self.act("nope")]
        for action in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(action)
            #expect(!result.isAccepted, "an illegal action was accepted")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.count == records, "a refusal changed it")
            #expect(copy.shownCycle == core.shownCycle)
        }
        var probe: Core = core
        // Outside the declared ranges or the value count: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.act("pod.place", [6, 0, 4])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("pod.place", [0, 12, 4])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("pod.place", [0, 0, 14])) == .rejected(.outOfRange(index: 2)))
        #expect(probe.apply(Self.act("pod.remove", [6])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("vent.set", [6, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("vent.set", [0, 2])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("moon.set", [4])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("clock.show", [201])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("clock.show", [-1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("pod.place", [0, 0, .nan])) == .rejected(.nonFinite(index: 2)))
        #expect(probe.apply(Self.act("pod.place", [0, 0])) == .rejected(.wrongValueCount(expected: 3, found: 2)))
        #expect(probe.apply(Self.act("pod.remove")) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(probe.apply(Self.act("vent.set", [0])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("clock.show", [1, 1])) == .rejected(.wrongValueCount(expected: 1, found: 2)))
        let noValues: ActionResult = .rejected(.wrongValueCount(expected: 0, found: 1))
        #expect(probe.apply(Self.act("weather.run", [1])) == noValues)
        #expect(probe.apply(Self.act("play.undo", [1])) == noValues)
        #expect(probe.apply(Self.act("play.redo", [1])) == noValues)
        #expect(probe.apply(Self.act("level.next", [1])) == noValues)
        // Feature 497: replay.step and replay.stop take no values; replay.start and settings.sound one.
        #expect(probe.apply(Self.act("replay.step", [1])) == noValues)
        #expect(probe.apply(Self.act("replay.stop", [1])) == noValues)
        #expect(probe.apply(Self.act("replay.start")) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(probe.apply(Self.act("replay.start", [101])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("settings.sound", [2])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("settings.sound")) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        let notWhole: ActionResult = .rejected(.rule(code: MushroomWeatherExperienceRule.notWhole))
        #expect(probe.apply(Self.act("pod.place", [0, 0.5, 4])) == notWhole)
        #expect(probe.apply(Self.act("pod.remove", [1.5])) == notWhole)
        #expect(probe.apply(Self.act("vent.set", [0, 0.5])) == notWhole)
        #expect(probe.apply(Self.act("moon.set", [2.5])) == notWhole)
        #expect(probe.apply(Self.act("clock.show", [2.5])) == notWhole)
        // A cycle past the cycles run: the adapter's refusal.
        let cycle: ActionResult = .rejected(.rule(code: MushroomWeatherExperienceRule.cycle))
        #expect(probe.apply(Self.act("clock.show", [Double(cycles + 1)])) == cycle)
        #expect(probe.apply(Self.act("clock.show", [200])) == cycle)
        // The kernel's refusals pass through with their codes: a slot or vent the level lacks, off the floor, a
        // blocked cell, a colony cell, not a site, an empty slot, an unchanged vent or moonlight, nothing to undo or
        // redo.
        let action: ActionResult = .rejected(.rule(code: "r02-g20.action"))
        #expect(probe.apply(Self.act("pod.place", [2, 0, 4])) == action)
        #expect(probe.apply(Self.act("pod.place", [0, 6, 0])) == action)
        #expect(probe.apply(Self.act("pod.place", [0, 2, 1])) == action)
        #expect(probe.apply(Self.act("pod.place", [0, 1, 5])) == action)
        #expect(probe.apply(Self.act("pod.place", [0, 0, 0])) == action)
        #expect(probe.apply(Self.act("pod.remove", [0])) == action)
        #expect(probe.apply(Self.act("pod.remove", [2])) == action)
        #expect(probe.apply(Self.act("vent.set", [0, 1])) == action)
        #expect(probe.apply(Self.act("vent.set", [1, 0])) == action)
        #expect(probe.apply(Self.act("moon.set", [2])) == action)
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe == core && probe.play.records.count == records && probe.shownCycle == 0)
        // Every legal cycle is accepted and changes nothing else.
        for shown in 0...cycles {
            #expect(probe.apply(Self.act("clock.show", [Double(shown)])) == .accepted && probe.shownCycle == shown)
        }
        #expect(try Self.digest(probe) == opening && probe == core)
        // Every legal action is accepted; vent state 0 shuts and 1 opens; an arrangement action, undo and redo keep the
        // shown cycle within the cycles run.
        #expect(probe.apply(Self.act("clock.show", [0])) == .accepted)
        #expect(probe.apply(Self.act("pod.place", [0, 0, 4])) == .accepted && probe.play.actionsLeft == 8)
        #expect(probe.play.arrangement.pods == [sites[0], nil])
        #expect(probe.apply(Self.act("pod.place", [1, 5, 2])) == .accepted && probe.play.actionsLeft == 7)
        #expect(probe.play.arrangement.pods == [sites[0], sites[3]] && probe.shownCycle == 0)
        // A move of slot 0 to another site.
        #expect(probe.apply(Self.act("pod.place", [0, 2, 4])) == .accepted && probe.play.actionsLeft == 6)
        #expect(probe.play.arrangement.pods == [sites[1], sites[3]])
        // An occupied cell and an unchanged placement are the kernel's refusals.
        #expect(probe.apply(Self.act("pod.place", [1, 2, 4])) == action)
        #expect(probe.apply(Self.act("pod.place", [0, 2, 4])) == action)
        #expect(probe.apply(Self.act("vent.set", [0, 0])) == .accepted && probe.play.arrangement.ventsOpen == [false])
        #expect(probe.apply(Self.act("vent.set", [0, 1])) == .accepted && probe.play.arrangement.ventsOpen == [true])
        #expect(probe.apply(Self.act("moon.set", [0])) == .accepted && probe.play.arrangement.moonlight == 0)
        #expect(probe.play.actionsLeft == 3)
        #expect(probe.apply(Self.act("pod.remove", [1])) == .accepted && probe.play.actionsLeft == 2)
        #expect(probe.apply(Self.act("play.undo")) == .accepted && probe.play.actionsLeft == 3)
        #expect(probe.apply(Self.act("play.redo")) == .accepted && probe.play.actionsLeft == 2)
        #expect(probe.shownCycle == 0)
        let shown: Int = probe.play.report.cycles
        #expect(probe.apply(Self.act("clock.show", [Double(shown)])) == .accepted && probe.shownCycle == shown)
        #expect(probe.apply(Self.act("pod.place", [0, 2, 4])) == action && probe.shownCycle == shown)
        // Feature 495: `level.next` needs the next level open; level 2 is not open until level 1 is won.
        #expect(probe.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g20.locked")))
        #expect(probe.shownCycle == shown && probe.levelNumber == 1)
        #expect(probe.apply(Self.act("mode.practice")) == .accepted && probe.levelNumber == 1)
        #expect(probe.play.stage == .playing && probe.play.actionsLeft == Core.practiceBudget)
        #expect(probe.shownCycle == 0)
    }

    @Test func theBudgetRefusesAnArrangementActionButNotTheRun() async throws {
        // Level 1, budget 9, moonlight 2: the moonlight alternates between 3 and 2.
        var core: Core = try await Core.prepare(seed: 0)
        for change in 0..<9 {
            let level: Double = change % 2 == 0 ? 3 : 2
            #expect(core.apply(Self.act("moon.set", [level])) == .accepted)
        }
        #expect(core.play.actionsLeft == 0 && core.play.arrangement.moonlight == 3)
        let before: StateDigest = try Self.digest(core)
        let budget: ActionResult = .rejected(.rule(code: "r02-g20.budget"))
        #expect(core.apply(Self.act("moon.set", [1])) == budget)
        #expect(core.apply(Self.act("pod.place", [0, 2, 5])) == budget)
        #expect(core.apply(Self.act("vent.set", [0, 0])) == budget)
        #expect(try Self.digest(core) == before)
        #expect(core.apply(Self.act("weather.run")) == .accepted)
        #expect(core.play.stage == .won || core.play.stage == .failed)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLaterOne() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let records: Int = core.play.records.count
        #expect(core.apply(Self.act("pod.place", [0, 2, 5])) == .accepted)
        let afterChange: StateDigest = try Self.digest(core)
        #expect(afterChange != opening)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening && core.play.records.count == records + 2)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(try Self.digest(core) == afterChange && core.play.records.count == records + 3)
        // A new placement after an undo (the same one again) clears the redo stack.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("pod.place", [0, 2, 5])) == .accepted)
        #expect(try Self.digest(core) == afterChange)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g20.action")))
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
        // A vent and the moonlight are undone exactly too.
        #expect(core.apply(Self.act("vent.set", [0, 0])) == .accepted)
        #expect(core.apply(Self.act("moon.set", [0])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
        // The run is undone and redone exactly as well.
        #expect(core.apply(Self.act("weather.run")) == .accepted)
        let afterRun: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(try Self.digest(core) == afterRun)
    }

    @Test func showingChangesTheSnapshotButNeverTheDigest() async throws {
        // Level 1 after its certified plan: a run of all 31 cycles.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(Self.act("pod.place", [0, 2, 5])) == .accepted)
        #expect(core.apply(Self.act("vent.set", [0, 0])) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let play: MushroomWeatherPlay = core.play
        let cycles: Int = play.report.cycles
        #expect(cycles == 31)
        let first: MushroomWeatherSceneSnapshot = core.snapshot(time: 1)
        var previous: MushroomWeatherSceneSnapshot = first
        for shown in 1...cycles {
            #expect(core.apply(Self.act("clock.show", [Double(shown)])) == .accepted)
            let snapshot: MushroomWeatherSceneSnapshot = core.snapshot(time: 1)
            #expect(snapshot.shownCycle == shown && snapshot.fields == first.fields)
            #expect(snapshot.shownField == first.fields[shown])
            #expect(snapshot != previous)
            #expect(try Self.digest(core) == before && core.play == play)
            #expect(try core.snapshotPayload() == payload)
            previous = snapshot
        }
        // A refused cycle keeps the current one.
        let shown: Int = core.shownCycle
        #expect(core.apply(Self.act("clock.show", [32])) == .rejected(.rule(code: "r02-g20.cycle")))
        #expect(core.apply(Self.act("clock.show", [3.25])) == .rejected(.rule(code: "r02-g20.not-whole")))
        #expect(core.apply(Self.act("clock.show", [201])) == .rejected(.outOfRange(index: 0)))
        #expect(core.apply(Self.act("clock.show", [.nan])) == .rejected(.nonFinite(index: 0)))
        #expect(core.snapshot(time: 1).shownCycle == shown && core.shownCycle == shown)
        #expect(try Self.digest(core) == before)
        // Reset, restore and a new opening (here practice; since feature 495 `level.next` needs the next level open)
        // return to cycle 0.
        var reset: Core = core
        reset.reset()
        let opened: Core = try Core.opening(number: 1)
        #expect(reset.shownCycle == 0 && reset == opened)
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && restored.shownCycle == 0)
        var next: Core = core
        #expect(next.apply(Self.act("mode.practice")) == .accepted)
        #expect(next.shownCycle == 0)
        // Undoing the vent runs the earlier arrangement's cycles; the shown cycle is clamped to them.
        var undone: Core = core
        #expect(undone.apply(Self.act("play.undo")) == .accepted)
        #expect(undone.shownCycle == min(shown, undone.play.report.cycles))
        #expect(undone.snapshot(time: 0).shownCycle == undone.shownCycle)
    }

    /// The fields of a schema-2 payload after its level number: campaign mode, level 1 open, no records (feature 495).
    static let restOfPayload: String = ",\"mode\":{\"mode\":\"campaign\"},"
        + "\"progress\":{\"frontier\":1,\"solved\":[]},\"records\":[]}"

    @Test func levelNextNeedsAnOpenLevelAndResetReturns() async throws {
        var core: Core = try await Core.prepare(seed: 99)
        #expect(core.levelNumber == 100)
        let hundred: MushroomWeatherGenerated = try Core.generated(number: 100)
        let first: MushroomWeatherAction = try #require(hundred.plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("clock.show", [1])) == .accepted)
        // Feature 495: no wrap; after winning level 100, `level.next` is still refused and level 1 is chosen with
        // `level.select`.
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g20.locked")))
        #expect(core.shownCycle == 1)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        for step in hundred.plan.actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.apply(Self.act("weather.run")) == .accepted)
        #expect(core.play.stage == .won && core.progress.solved[100] != nil && core.progress.frontier == 100)
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g20.locked")))
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        #expect(core.levelNumber == 1 && core.play.stage == .playing && !core.play.canUndo)
        #expect(core.play.level == (try Core.level(number: 1)))
        #expect(core.shownCycle == 0)
        core.setQualityTier(2)
        core.reset()
        #expect(core.levelNumber == 100 && !core.play.canUndo && core.qualityTier == 2)
        #expect(core.progress.solved.isEmpty && core.mode == .campaign)
        let fresh: Core = try await Core.prepare(seed: 99)
        #expect(core == fresh)
        #expect(try Self.digest(core) == Self.digest(fresh))
        #expect(core.shownCycle == fresh.shownCycle)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        // Level 21 after a placement, an undo, a redo and an undo.
        var core: Core = try await Core.prepare(seed: 20)
        let first: MushroomWeatherAction = try #require(try Core.generated(number: 21).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("clock.show", [1])) == .accepted)
        let savedDigest: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let text: String = String(decoding: payload, as: UTF8.self)
        let prefix: String = "{\"level\":21,\"mode\":{\"mode\":\"campaign\"},\"progress\":{\"frontier\":21,"
        #expect(text.hasPrefix(prefix))
        let restored: Core = try Core.restore(payload: payload, seed: 20)
        let restoredDigest: StateDigest = try Self.digest(restored)
        #expect(restored == core && restoredDigest == savedDigest)
        #expect(restored.play.canRedo && restored.openingNumber == 21 && restored.shownCycle == 0)
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
        #expect(failed.apply(Self.act("weather.run")) == .accepted && failed.play.stage == .failed)
        let failedRestored: Core = try Core.restore(payload: try failed.snapshotPayload(), seed: 20)
        #expect(failedRestored == failed && failedRestored.outcome?.code == Core.failedCode)
        // Refusals.
        #expect(throws: MushroomWeatherRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 20)
        }
        #expect(throws: MushroomWeatherRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 20)
        }
        #expect(throws: MushroomWeatherRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"21\",\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: MushroomWeatherRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data(("{\"level\":0" + Self.restOfPayload).utf8), seed: 20)
        }
        #expect(throws: MushroomWeatherRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data(("{\"level\":101" + Self.restOfPayload).utf8), seed: 20)
        }
        // A trace of level 21 restored as level 22 (another seed).
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "{\"level\":21,", with: "{\"level\":22,").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: MushroomWeatherRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: wrongLevel, seed: 20)
        }
        // A record of a newer schema.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: MushroomWeatherRestoreRefusal.kernel(.malformed("schema 0"))) {
            try Core.restore(payload: newer, seed: 20)
        }
        // An edited trace: the first record's index changed.
        let edited: Data = Data(text.replacingOccurrences(of: "\"index\":0,", with: "\"index\":3,").utf8)
        #expect(edited != payload)
        #expect(throws: MushroomWeatherRestoreRefusal.kernel(.malformed("index 0"))) {
            try Core.restore(payload: edited, seed: 20)
        }
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        // Level 1: the first action of its certified plan.
        #expect(engine.handle(control: "pod.place", values: [0, 2, 5]) == .accepted)
        let before: StateDigest = try engine.digest()
        let saved: ExperienceSnapshot = try engine.snapshot()
        let newer = try ExperienceSnapshot(experience: id, schemaVersion: 4, seed: saved.seed,
                                           stepIndex: saved.stepIndex, digest: saved.digest,
                                           payload: Data(saved.payload.utf8))
        var refused: Bool = false
        do {
            try engine.restore(newer)
        } catch {
            refused = error == .snapshot(.newerSchema(found: 4, current: 3))
        }
        #expect(refused)
        #expect(try engine.digest() == before)
        try engine.restore(saved)
        #expect(try engine.digest() == before)
    }

    @Test func theSnapshotCopiesThePlay() async throws {
        // Level 41 after the first placement of its certified plan, cycle 9 shown.
        var core: Core = try await Core.prepare(seed: 40)
        let first: MushroomWeatherAction = try #require(try Core.generated(number: 41).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        let play: MushroomWeatherPlay = core.play
        let level: MushroomWeatherLevel = play.level
        let shown: Int = min(9, play.report.cycles)
        #expect(core.apply(Self.act("clock.show", [Double(shown)])) == .accepted)
        let snapshot: MushroomWeatherSceneSnapshot = core.snapshot(time: 2.5)
        let run: (report: MushroomWeatherReport, fields: [[Int]]) =
            MushroomWeatherForest.run(level, arrangement: play.arrangement, keepFields: true)
        #expect(run.report == play.report && snapshot.cyclesRun == play.report.cycles)
        #expect(run.fields.count == play.report.cycles + 1 && snapshot.fields == run.fields)
        #expect(snapshot.shownField == run.fields[shown])
        for (index, colony) in level.colonies.enumerated() {
            let humidity: Int = run.fields[shown][level.index(of: colony.cell)]
            #expect(snapshot.humidity(colony.cell) == humidity)
            #expect(snapshot.colonies[index].inBand == colony.isInBand(humidity))
            #expect(snapshot.colonies[index].finalRun == play.report.colonies[index].finalRun)
            #expect(snapshot.colonies[index].longestRun == play.report.colonies[index].longestRun)
            #expect(snapshot.colonies[index].low == colony.low && snapshot.colonies[index].high == colony.high)
        }
        #expect(snapshot.rows == level.rows && snapshot.columns == level.columns && snapshot.blocked == level.blocked)
        #expect(snapshot.moldBound == level.moldBound && snapshot.requiredCycles == level.required)
        #expect(snapshot.pods == play.arrangement.pods && snapshot.grownAt == play.report.grownAt)
        #expect(snapshot.sites == (level.sites ?? []) && snapshot.vents == level.vents.map(\.cell))
        #expect(snapshot.ventsOpen == play.arrangement.ventsOpen && snapshot.moonlight == play.arrangement.moonlight)
        #expect(snapshot.failure == play.report.failure && snapshot.stage == play.stage)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.shownCycle == shown && snapshot.levelNumber == 41 && snapshot.time == 2.5)
        #expect(core.renderTier == MushroomWeatherTier.of(0))
    }
}

/// Feature 497 (R02-G20-07) T-R02G2007-003: the adapter's migrations to schema 3, reconciliation on restore, replay,
/// saved replays, the sound setting and the replay feedback (see the file header).
@Suite struct MushroomWeatherReplayCoreTests {
    typealias Core = MushroomWeatherExperienceCore
    typealias Action = MushroomWeatherAction
    typealias Record = MushroomWeatherRecord
    typealias Rule = MushroomWeatherExperienceRule
    typealias Plan = MushroomWeatherFeedbackPlan

    /// The `r02-g20.replay-end` refusal.
    static let replayEnd: ActionResult = .rejected(.rule(code: Rule.replayEnd))
    /// The `r02-g20.no-replay` refusal.
    static let noReplay: ActionResult = .rejected(.rule(code: Rule.noReplay))
    /// The `r02-g20.replay` refusal.
    static let inReplay: ActionResult = .rejected(.rule(code: Rule.replay))

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        try MushroomWeatherExperienceCoreTests.digest(core)
    }

    /// An action of `control` with `values`.
    static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        MushroomWeatherExperienceCoreTests.act(control, values)
    }

    /// The adapter action of a kernel action.
    static func act(_ action: Action) -> ExperienceAction {
        MushroomWeatherExperienceCoreTests.act(action)
    }

    /// The certified pod, vent and moonlight actions of level `number`, then the run.
    static func certifiedTrace(_ number: Int) throws -> [Action] {
        var actions: [Action] = try Core.generated(number: number).plan.actions
        actions.append(.run)
        return actions
    }

    /// The core prepared on level `number` (open, campaign) with the level won from its certified trace.
    static func won(_ number: Int) async throws -> Core {
        var core: Core = try await Core.prepare(seed: UInt64(number - 1))
        for action in try certifiedTrace(number) {
            #expect(core.apply(act(action)) == .accepted, "level \(number) \(action)")
        }
        #expect(core.play.stage == .won && core.progress.solved[number]?.verified == true, "level \(number)")
        return core
    }

    /// The payload's JSON object.
    static func object(_ payload: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
    }

    /// The JSON data of `object` with sorted keys.
    static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// The payload of `core` with its records replaced by `records`.
    static func payload(_ core: Core, records: [Record]) throws -> Data {
        var object: [String: Any] = try Self.object(try core.snapshotPayload())
        object["records"] = try JSONSerialization.jsonObject(with: try JSONEncoder().encode(records))
        return try Self.data(object)
    }

    /// The positions of the place, remove, vent, moonlight and run records of `records`.
    static func actionPositions(_ records: [Record]) -> [Int] {
        var positions: [Int] = []
        var index: Int = 0
        while index < records.count {
            switch records[index].kind {
            case .place, .remove, .vent, .moonlight, .run: positions.append(index)
            case .undo, .redo, .begin, .dismissTutorial, .pause, .resume: break
            }
            index += 1
        }
        return positions
    }

    /// Another action of the same kind as `action` on `level`: a placement on another site, the other vent state,
    /// another moonlight level; nil for a removal or the run.
    static func changed(_ action: Action, level: MushroomWeatherLevel) -> Action? {
        switch action {
        case let .place(slot, cell):
            for site in level.sites ?? [] where site != cell { return .place(slot: slot, cell: site) }
            return nil
        case let .vent(index, open):
            return .vent(index: index, open: !open)
        case let .moonlight(moon):
            return .moonlight(level: moon == 0 ? 1 : 0)
        case .remove, .run:
            return nil
        }
    }

    // MARK: Migrations to schema 3

    @Test func theEngineMigratesSchemaOneAndTwoEnvelopesToSchemaThree() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        // A schema-2 state: level 1 won, then level 2 after level.next with its first certified action, the sound on.
        var core: Core = try await Self.won(1)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        let first: Action = try #require(try Core.generated(number: 2).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted && core.soundOn)
        var object: [String: Any] = try Self.object(try core.snapshotPayload())
        object["sound"] = nil
        var progress: [String: Any] = try #require(object["progress"] as? [String: Any])
        var solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
        for index in solved.indices {
            solved[index]["trace"] = nil
            solved[index]["verified"] = nil
        }
        progress["solved"] = solved
        object["progress"] = progress
        let stepwise: Data = try Self.data(try Core.migratedToSchemaThree(object))
        let chained: Data = try Self.data(try Core.migrations.migrate(object, from: 2))
        #expect(stepwise == chained)
        let restored: Core = try Core.restore(payload: chained, seed: 0)
        #expect(restored.levelNumber == 2 && restored.play == core.play && restored.mode == .campaign)
        #expect(restored.progress.frontier == 2 && restored.progress.best(1) == core.progress.best(1))
        #expect(restored.progress.stars(of: 1) == 3 && restored.progress.solved[1]?.verified == false)
        #expect(restored.progress.solved[1]?.trace == [] && !restored.soundOn && restored.reconciliationDropped == 0)
        let saved: ExperienceSnapshot = try engine.snapshot()
        let two = try ExperienceSnapshot(experience: id, schemaVersion: 2, seed: 0, stepIndex: saved.stepIndex,
                                         digest: try Self.digest(restored), payload: try Self.data(object))
        try engine.restore(two)
        #expect(engine.core == restored)
        // A schema-1 envelope `{level, records}` reaches schema 3 through both steps: no won level, the sound off.
        var schemaOne: [String: Any] = [:]
        schemaOne["level"] = object["level"]
        schemaOne["records"] = object["records"]
        let one = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: 0, stepIndex: saved.stepIndex,
                                         digest: saved.digest, payload: try Self.data(schemaOne))
        do {
            try engine.restore(one)
        } catch {
            Issue.record("schema 1 refused: \(error)")
        }
        let migrated: Core = try #require(engine.core)
        #expect(migrated.levelNumber == 2 && migrated.play == core.play && migrated.progress.solved.isEmpty)
        #expect(migrated.progress.frontier == 2 && !migrated.soundOn && migrated.reconciliationDropped == 0)
        let threeObject: [String: Any] = try Core.migrations.migrate(schemaOne, from: 1)
        #expect(threeObject["sound"] as? Bool == false)
        #expect(throws: MushroomWeatherRestoreRefusal.damaged) { try Core.migratedToSchemaThree(["level": 2]) }
    }

    // MARK: Reconciliation on restore

    @Test func restoreReconcilesAndCountsDroppedResultsWithoutDigestingTheCount() async throws {
        var core: Core = try await Self.won(1)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        for action in try Self.certifiedTrace(2) { #expect(core.apply(Self.act(action)) == .accepted) }
        #expect(core.progress.solved.count == 2 && core.progress.frontier == 3)
        let honest: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(honest == core && honest.reconciliationDropped == 0)
        // Level 2's stars edited from 3 to 2: dropped and counted; level 1 kept; the frontier as saved.
        var object: [String: Any] = try Self.object(try core.snapshotPayload())
        var progress: [String: Any] = try #require(object["progress"] as? [String: Any])
        var solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
        try #require(solved.count == 2)
        solved[1]["stars"] = 2
        progress["solved"] = solved
        object["progress"] = progress
        let edited: Core = try Core.restore(payload: try Self.data(object), seed: 0)
        #expect(edited.reconciliationDropped == 1 && edited.progress.solved[2] == nil)
        #expect(edited.progress.solved[1] == core.progress.solved[1] && edited.progress.frontier == 3)
        // The same state without level 2's result: equal state and digest, only the dropped count differs.
        solved.removeLast()
        progress["solved"] = solved
        object["progress"] = progress
        let without: Core = try Core.restore(payload: try Self.data(object), seed: 0)
        #expect(without.reconciliationDropped == 0 && without == edited)
        #expect(try Self.digest(without) == Self.digest(edited))
        // A saved replay whose result is dropped returns to campaign at that level.
        var replaying: Core = try await Self.won(1)
        #expect(replaying.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(replaying.apply(Self.act("replay.step")) == .accepted)
        var replayObject: [String: Any] = try Self.object(try replaying.snapshotPayload())
        var replayProgress: [String: Any] = try #require(replayObject["progress"] as? [String: Any])
        var replaySolved: [[String: Any]] = try #require(replayProgress["solved"] as? [[String: Any]])
        replaySolved[0]["stars"] = 1
        replayProgress["solved"] = replaySolved
        replayObject["progress"] = replayProgress
        let back: Core = try Core.restore(payload: try Self.data(replayObject), seed: 0)
        #expect(back.mode == .campaign && back.levelNumber == 1 && back.reconciliationDropped == 1)
        let freshOne: MushroomWeatherPlay = try Core.freshPlay(of: try Core.level(number: 1))
        #expect(back.play == freshOne && back.progress.solved.isEmpty)
    }

    // MARK: Replay rules and codes

    @Test func noReplayWithoutAVerifiedTracedResultOrOutsideAReplay() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let before: Core = core
        #expect(core.apply(Self.act("replay.start", [1])) == Self.noReplay && core == before)
        #expect(core.apply(Self.act("replay.step")) == Self.noReplay && core == before)
        #expect(core.apply(Self.act("replay.stop")) == Self.noReplay && core == before)
        // An untraced result (as a schema-2 save carries it) cannot be replayed.
        var won: Core = try await Self.won(1)
        var object: [String: Any] = try Self.object(try won.snapshotPayload())
        var progress: [String: Any] = try #require(object["progress"] as? [String: Any])
        var solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
        try #require(solved.count == 1)
        solved[0]["trace"] = [Any]()
        solved[0]["verified"] = false
        progress["solved"] = solved
        object["progress"] = progress
        let untraced: Core = try Core.restore(payload: try Self.data(object), seed: 0)
        #expect(untraced.progress.solved[1]?.verified == false && untraced.reconciliationDropped == 0)
        var tried: Core = untraced
        #expect(tried.apply(Self.act("replay.start", [1])) == Self.noReplay && tried == untraced)
        // The verified level replays with the tutorial done; an unsolved level does not.
        #expect(won.apply(Self.act("replay.start", [2])) == Self.noReplay)
        #expect(won.apply(Self.act("replay.start", [1])) == .accepted && won.mode == .replay(level: 1))
        let budget: Int = try Core.level(number: 1).budget
        #expect(won.tutorial == .done && won.play.level.budget == budget)
    }

    @Test func duringAReplayOtherPlayActionsAreRefusedAndPresentationAndSoundStayAccepted() async throws {
        var core: Core = try await Self.won(41)
        #expect(core.apply(Self.act("replay.start", [41])) == .accepted)
        #expect(core.apply(Self.act("replay.step")) == .accepted)
        let before: Core = core
        let beforeDigest: StateDigest = try Self.digest(core)
        let trace: [Action] = try Self.certifiedTrace(41)
        let refused: [ExperienceAction] = [Self.act(trace[0]), Self.act("pod.remove", [0]), Self.act("vent.set", [0, 1]),
                                           Self.act("moon.set", [1]), Self.act("weather.run"), Self.act("play.undo"),
                                           Self.act("play.redo"), Self.act("level.next"),
                                           Self.act("level.select", [1]), Self.act("mode.daily", [2026, 1, 1]),
                                           Self.act("mode.practice"), Self.act("mode.campaign")]
        for action in refused {
            var copy: Core = core
            #expect(copy.apply(action) == Self.inReplay && copy == before, "\(action.control)")
        }
        #expect(core.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(core.apply(Self.act("clock.show", [0])) == .accepted)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted && core.soundOn)
        let afterDigest: StateDigest = try Self.digest(core)
        #expect(afterDigest == beforeDigest && core.play == before.play && core.progress == before.progress)
        // A restart from the middle begins the replay again; the replay never records.
        #expect(core.apply(Self.act("replay.start", [41])) == .accepted)
        let fresh: MushroomWeatherPlay = try Core.freshPlay(of: try Core.level(number: 41))
        #expect(core.play == fresh && core.mode == .replay(level: 41))
        let progress: MushroomWeatherProgress = core.progress
        for _ in 0..<trace.count { #expect(core.apply(Self.act("replay.step")) == .accepted) }
        #expect(core.play.stage == .won && core.progress == progress)
        #expect(core.apply(Self.act("replay.step")) == Self.replayEnd && core.progress == progress)
    }

    @Test func aReplayOfALockedDailyLevelStopsAtTheFrontier() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        // 2026-01-01 + d days has daily level (17 d) mod 100 + 1; d = 49 × 53 mod 100 = 97 (2026-04-08) gives 50.
        let date: [Double] = [2026, 4, 8]
        #expect(MushroomWeatherProgress.dailyLevel(year: 2026, month: 4, day: 8) == 50)
        #expect(core.apply(Self.act("mode.daily", date)) == .accepted && core.levelNumber == 50)
        for action in try Self.certifiedTrace(50) { #expect(core.apply(Self.act(action)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.solved[50]?.verified == true)
        #expect(!core.progress.isOpen(50) && core.progress.frontier == 1)
        #expect(core.apply(Self.act("replay.start", [50])) == .accepted)
        #expect(core.apply(Self.act("replay.stop")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1)
    }

    // MARK: Saved replays

    @Test func aReplaySavedMidwayRestoresWhileAChangedReorderedOrUndoReplayIsDamaged() async throws {
        var core: Core = try await Self.won(41)
        let trace: [Action] = try Self.certifiedTrace(41)
        try #require(trace.count >= 3)
        #expect(core.apply(Self.act("replay.start", [41])) == .accepted)
        var steps: Int = 0
        while true {
            let payload: Data = try core.snapshotPayload()
            let restored: Core = try Core.restore(payload: payload, seed: 40)
            let restoredDigest: StateDigest = try Self.digest(restored)
            let digest: StateDigest = try Self.digest(core)
            #expect(restored == core && restoredDigest == digest, "after \(steps) steps")
            #expect(restored.mode == .replay(level: 41) && restored.reconciliationDropped == 0, "after \(steps)")
            // The restored replay continues to the win.
            var continued: Core = restored
            var left: Int = trace.count - steps
            while left > 0 {
                #expect(continued.apply(Self.act("replay.step")) == .accepted, "after \(steps) steps")
                left -= 1
            }
            #expect(continued.play.stage == .won && continued.apply(Self.act("replay.step")) == Self.replayEnd)
            if steps == trace.count { break }
            #expect(core.apply(Self.act("replay.step")) == .accepted)
            steps += 1
        }
        let records: [Record] = core.play.records
        let positions: [Int] = Self.actionPositions(records)
        try #require(positions.count == trace.count)
        // Changed: the first action replaced by another of its kind.
        let level: MushroomWeatherLevel = try Core.level(number: 41)
        let other: Action = try #require(Self.changed(trace[0], level: level))
        var changed: [Record] = records
        let first: Record = records[positions[0]]
        changed[positions[0]] = Record(schema: first.schema, seed: first.seed, index: first.index, kind: first.kind,
                                       action: other, previous: first.previous, next: first.next)
        // Reordered: the first two actions swapped.
        var reordered: [Record] = records
        reordered[positions[0]] = records[positions[1]]
        reordered[positions[1]] = records[positions[0]]
        // Undo-carrying: an undo and a redo after the first action.
        var undone: [Record] = Array(records.prefix(positions[0] + 1))
        undone.append(Record(schema: first.schema, seed: first.seed, index: first.index + 1, kind: .undo, action: nil,
                             previous: first.next, next: first.previous))
        undone.append(Record(schema: first.schema, seed: first.seed, index: first.index + 2, kind: .redo, action: nil,
                             previous: first.previous, next: first.next))
        // Longer than the trace: an extra run after the win.
        var longer: [Record] = records
        longer.append(records[positions[positions.count - 1]])
        let variants: [(name: String, records: [Record])] = [("changed", changed), ("reordered", reordered),
                                                             ("undo", undone), ("longer", longer)]
        for variant in variants {
            let data: Data = try Self.payload(core, records: variant.records)
            #expect(throws: MushroomWeatherRestoreRefusal.damaged, "\(variant.name)") {
                _ = try Core.restore(payload: data, seed: 40)
            }
        }
        // A replay mode naming another level than the saved level is damaged too.
        var object: [String: Any] = try Self.object(try core.snapshotPayload())
        object["mode"] = ["mode": "replay", "level": 40]
        #expect(throws: MushroomWeatherRestoreRefusal.damaged) {
            _ = try Core.restore(payload: try Self.data(object), seed: 40)
        }
    }

    // MARK: Sound

    @Test func theSoundSettingIsSnapshottedNeverDigestedAndOffAfterAReset() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        #expect(!core.soundOn)
        let notWhole: ActionResult = .rejected(.rule(code: Rule.notWhole))
        #expect(core.apply(Self.act("settings.sound", [0.5])) == notWhole && !core.soundOn)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted && core.soundOn)
        #expect(try Self.digest(core) == opening)
        let text: String = String(decoding: try core.snapshotPayload(), as: UTF8.self)
        #expect(text.contains(",\"sound\":true,\"tutorial\":\"place\"}"))
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        let restoredDigest: StateDigest = try Self.digest(restored)
        #expect(restored.soundOn && restored == core && restoredDigest == opening)
        var off: Core = core
        #expect(off.apply(Self.act("settings.sound", [0])) == .accepted && !off.soundOn && off != core)
        #expect(try Self.digest(off) == opening)
        // A payload without the sound key (before schema 3) restores with the sound off.
        let noSound: Data = Data(text.replacingOccurrences(of: ",\"sound\":true", with: "").utf8)
        let silent: Core = try Core.restore(payload: noSound, seed: 0)
        #expect(!silent.soundOn)
        var reset: Core = core
        reset.reset()
        let openingCore: Core = try Core.opening(number: 1)
        #expect(!reset.soundOn && reset == openingCore)
    }

    // MARK: Feedback

    @Test func theReplayFeedbackNamesRefusalsStepsAndAStarlessWin() async throws {
        #expect(Plan.refusalText(code: Rule.noReplay) == "There is no saved solution to replay for this level.")
        #expect(Plan.refusalText(code: Rule.replayEnd) == "The replay is over.")
        #expect(Plan.refusalText(code: Rule.replay) == "Stop the replay first.")
        #expect(Plan.refusalText(code: "action.rule." + Rule.replay) == "Stop the replay first.")
        #expect(Plan.refused(code: Rule.replayEnd).kind == .rejection && Plan.modeName(.replay(level: 3)) == "replay")
        // Level 1 replayed beside a campaign play of the same actions: each step is announced like the action, and
        // the replayed win claims no stars while the campaign win does.
        var replay: Core = try await Self.won(1)
        var campaign: Core = try await Core.prepare(seed: 0)
        let started: Core = replay
        #expect(replay.apply(Self.act("replay.start", [1])) == .accepted)
        let opened: Plan = Plan.after(old: started, new: replay)
        #expect(opened.kind == .level && opened.text == "Level 1, band 1, replay.")
        let trace: [Action] = try Self.certifiedTrace(1)
        for action in trace {
            let oldReplay: Core = replay
            let oldCampaign: Core = campaign
            #expect(replay.apply(Self.act("replay.step")) == .accepted)
            #expect(campaign.apply(Self.act(action)) == .accepted)
            let replayed: Plan = Plan.after(old: oldReplay, new: replay)
            let played: Plan = Plan.after(old: oldCampaign, new: campaign)
            if action == .run {
                let spent: Int = trace.count - 1
                #expect(replayed.text == Plan.wonText + " Level won spending \(spent) actions.")
                #expect(replayed.kind == .outcome && replayed.haptic == .success)
                #expect(played.text == Plan.wonText + " Level won spending \(spent) actions, 3 of 3 stars.")
            } else {
                #expect(replayed == played, "\(action)")
            }
        }
    }
}
