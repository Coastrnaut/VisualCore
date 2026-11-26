// ApsidesWorkshopExperienceCoreTests — feature 473 (R02-G18-03) T-R02G1803-005 (FR-R02G1803-005, 008, 009;
// SC-R02G1803-004; clarifications Q4, Q5). The adapter core: the shared conformance checks pass; the declared controls,
// ids, tiers and profile (the quality level names equal `ApsidesWorkshopTier.all`); the seed picks level
// `seed % 100 + 1` deterministically in stage `playing` with tick 0 shown (seeds 0, 1, 99 and 100 give levels 1, 2, 100
// and 1); every control is accepted when legal and refused with the state unchanged otherwise (the engine's range
// checks, `r02-g18.not-whole`, `r02-g18.tick` for a tick outside the period, and every kernel refusal the adapter can
// meet passing through with its code: `r02-g18.action` for a tuning equal to the current orbit or making it invalid and
// for nothing to undo or redo, `r02-g18.budget` and `r02-g18.stage`; `stale` cannot arise because every action names
// the current fingerprint); undo restores the earlier digest exactly and redo the later one; `clock.show` changes the
// snapshot but never the digest, the play or the payload, a tuning, the play, undo and redo keep it, and a new opening
// (a mode or a level), reset and restore return it to 0; the certified plan of level 1 wins through the adapter and a
// play from the opening fails, undo returning the failed play to playing; `level.next` needs an open level (no wrap)
// and reset returns; the snapshot round trip and refused payloads (damaged, level out of range, a trace of another
// level, a record of a newer schema, an edited trace, an envelope of a newer schema); the certified-candidate table
// equals the generator's search for three levels and the 100 stored witnesses' `skipped`; `snapshot(time:)` copies the
// play. Levels are certified once per process, so the run stays short. Explicit types, plain loops, single-literal
// comments. Modelled on CelestialEclipseLabExperienceCoreTests (feature 463).
// Feature 475 (R02-G18-05) T-R02G1805-004: schema 2 and digest v2, twelve controls, `level.next` to the next open level
// (no wrap; `r02-g18.locked` when none), and `ApsidesWorkshopProgressionCoreTests` below: the progression controls and
// their refusals, campaign stars and unlocks, practice (budget 24, no stars, no unlocks), a locked daily level played
// without opening it, progress and mode digested but never the tutorial step or the shown tick, the tutorial steps
// after tunings, plays, undo, redo and dismissal, the schema-2 round trip, the migration of a schema-1 payload and the
// refusal of a newer schema.
// Feature 477 (R02-G18-07) T-R02G1807-003: schema 3 and digest v3, sixteen controls, wins store their trace (the
// effective `.periapsis(k, d)` and `.size(a)` tunings, an undone tuning left out, then `.play`) as a verified result,
// the migration 1 → 2 → 3, and the refusal of schema 4; the replay, reconciliation and sound rules are in
// `ApsidesWorkshopReplayCoreTests`.
@testable import ApsidesWorkshopCore
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, ApsidesWorkshop, the
/// package, Packages).
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/apsides-workshop/levels", isDirectory: true)

/// Whether the stored witnesses are present (they are in the repository; an isolated copy of the package lacks them).
private let coreWitnessesPresent: Bool = FileManager.default.fileExists(
    atPath: coreWitnessDirectory.appendingPathComponent("001.witness.json").path)

@Suite struct ApsidesWorkshopExperienceCoreTests {
    typealias Core = ApsidesWorkshopExperienceCore

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
    static func act(_ action: ApsidesWorkshopAction) -> ExperienceAction {
        switch action {
        case let .periapsis(eccentricity, direction): act("orbit.periapsis", [Double(eccentricity), Double(direction)])
        case let .size(size): act("orbit.size", [Double(size)])
        case .play: act("orbit.play")
        }
    }

    /// The stored witness of level `number`: its number, `skipped` and level fingerprint, read as plain JSON.
    static func storedWitness(_ number: Int) throws -> (number: Int, skipped: Int, fingerprint: String) {
        let name: String = String(ApsidesWorkshopGenerator.levelID(number).suffix(3)) + ".witness.json"
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
        // Levels 1 and 3. Level 1's certified plan is the knob to (0, 0); the play from the starting orbit fails and is
        // undone; practice reopens the level with the budget raised to 24 (feature 475: `level.next` needs the next
        // level open), where size 20 is accepted again from the starting orbit.
        let actions: [ScriptedAction] = [ScriptedAction("orbit.periapsis", [0, 0]), ScriptedAction("play.undo"),
                                         ScriptedAction("play.redo"), ScriptedAction("clock.show", [10]),
                                         ScriptedAction("play.undo"), ScriptedAction("orbit.play"),
                                         ScriptedAction("play.undo"), ScriptedAction("orbit.size", [20]),
                                         ScriptedAction("mode.practice"), ScriptedAction("clock.show", [5]),
                                         ScriptedAction("orbit.size", [20]), ScriptedAction("play.undo")]
        // Refused on the openings of levels 1 and 3 (period 24 both).
        let rejected: [ScriptedAction] = [ScriptedAction("orbit.periapsis", [16, 0]),
                                          ScriptedAction("orbit.periapsis", [-1, 0]),
                                          ScriptedAction("orbit.periapsis", [0, 24]),
                                          ScriptedAction("orbit.periapsis", [0.5, 0]),
                                          ScriptedAction("orbit.periapsis", [0, 1.5]),
                                          ScriptedAction("orbit.periapsis", [1]),
                                          ScriptedAction("orbit.size", [7]),
                                          ScriptedAction("orbit.size", [49]),
                                          ScriptedAction("orbit.size", [12.5]),
                                          ScriptedAction("orbit.size"),
                                          ScriptedAction("clock.show", [24]),
                                          ScriptedAction("clock.show", [95]),
                                          ScriptedAction("clock.show", [96]),
                                          ScriptedAction("clock.show", [-1]),
                                          ScriptedAction("clock.show", [2.5]),
                                          ScriptedAction("clock.show"),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("orbit.play", [1]), ScriptedAction("level.next", [1]),
                                          ScriptedAction("level.next"), ScriptedAction("level.select", [4]),
                                          ScriptedAction("level.select", [0]), ScriptedAction("level.select"),
                                          ScriptedAction("mode.daily", [2026, 2, 30]),
                                          ScriptedAction("mode.daily", [2026, 13, 1]),
                                          ScriptedAction("mode.daily", [2026, 1]),
                                          ScriptedAction("mode.practice", [1]), ScriptedAction("mode.campaign", [1]),
                                          ScriptedAction("tutorial.dismiss", [1]),
                                          // Feature 477: no replay without a verified result; sound values whole 0 … 1.
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
        #expect(Core.experienceID == "r02-g18.apsides-workshop" && Core.schemaVersion == 3)
        #expect(Core.digestDomain == "r02-g18.apsides-workshop.v3")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["orbit.periapsis", "orbit.size", "orbit.play", "play.undo", "play.redo", "level.next",
                             "clock.show", "level.select", "mode.daily", "mode.practice", "mode.campaign",
                             "tutorial.dismiss", "replay.start", "replay.step", "replay.stop", "settings.sound"]
        #expect(Core.actionIDs == ids && Core.controls.count == 16)
        #expect(Core.controls[12].ranges == [1...100] && Core.controls[15].ranges == [0...1])
        #expect(Core.controls[0].ranges == [0...15, 0...23])
        #expect(Core.controls[1].ranges == [8...48])
        #expect(Core.controls[6].ranges == [0...95])
        #expect(Core.controls[7].ranges == [1...100])
        #expect(Core.controls[8].ranges == [1...9999, 1...12, 1...31])
        let plainIndices: [Int] = [2, 3, 4, 5, 9, 10, 11, 13, 14]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.qualityTiers == ApsidesWorkshopTier.all.count)
        #expect(Core.migrations.currentVersion == 3)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == ApsidesWorkshopTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 0.5, 20.0 / 384.0] && iterations == [1, 0.5, 0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(ApsidesWorkshopExperienceRule.notWhole == "r02-g18.not-whole")
        #expect(ApsidesWorkshopExperienceRule.tick == "r02-g18.tick")
        #expect(ApsidesWorkshopExperienceRule.locked == "r02-g18.locked")
        #expect(ApsidesWorkshopExperienceRule.date == "r02-g18.date")
        #expect(ApsidesWorkshopExperienceRule.noReplay == "r02-g18.no-replay")
        #expect(ApsidesWorkshopExperienceRule.replayEnd == "r02-g18.replay-end")
        #expect(ApsidesWorkshopExperienceRule.replay == "r02-g18.replay")
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
            let expected: ApsidesWorkshopLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.orbit == expected.orbit)
            // The tutorial (levels 1 … 3) is dismissed by the adapter: the play opens in stage playing.
            #expect(first.play.stage == .playing && first.outcome == nil && first.play.failure == nil)
            let opening: Int = expected.tutorial ? 2 : 1
            #expect(first.play.records.count == opening && !first.play.canUndo)
            #expect(first.play.actionsLeft == expected.budget && first.qualityTier == 0 && first.shownTick == 0)
            // Feature 475: campaign mode, level 1 open plus the levels up to the opening one, none won.
            #expect(first.mode == .campaign && first.progress.frontier == numbers[index])
            let certified: Int = try Core.generated(number: numbers[index]).plan.size
            #expect(first.progress.solved.isEmpty && first.certifiedTunings == certified)
            #expect(first.tutorial == ApsidesWorkshopTutorialStep.initial(level: numbers[index]))
            // Feature 477: sound off and nothing dropped at an opening.
            #expect(!first.soundOn && first.reconciliationDropped == 0)
        }
        #expect(try Core.level(number: 1).tutorial && !(try Core.level(number: 100).tutorial))
        #expect(throws: ApsidesWorkshopError.level("number")) { try Core.level(number: 0) }
        #expect(throws: ApsidesWorkshopError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableEqualsTheGeneratorsSearch() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for value in Core.certifiedCandidates {
            #expect(value >= 0 && value < ApsidesWorkshopGenerator.maxCandidates)
        }
        // Three levels re-derived by the generator's whole search after their certified neighbour (levels 3 and 13
        // skip 8 and 4 candidates).
        let numbers: [Int] = [1, 3, 13]
        for number in numbers {
            let entry: ApsidesWorkshopManifestEntry = ApsidesWorkshopManifest.entries[number - 1]
            var previous: ApsidesWorkshopLevel? = nil
            if number > 1 { previous = try Core.level(number: number - 1) }
            let searched: ApsidesWorkshopGenerated = try ApsidesWorkshopGenerator.generate(entry, previous: previous)
            #expect(searched.skipped == Core.certifiedCandidates[number - 1], "a table entry differs")
            let direct: ApsidesWorkshopGenerated = try Core.generated(number: number)
            #expect(direct == searched, "the direct certification differs from the generator")
            #expect(direct.entry == entry && direct.level.id == ApsidesWorkshopGenerator.levelID(number))
        }
        #expect(Core.certifiedCandidates[0] == 1 && Core.certifiedCandidates[2] == 8)
        #expect(Core.certifiedCandidates[12] == 4)
    }

    @Test(.enabled(if: coreWitnessesPresent, "needs the stored witnesses, docs/games/apsides-workshop/levels"))
    func theCandidateTableEqualsTheStoredWitnesses() throws {
        for number in 1...100 {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            #expect(witness.number == number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "a table entry differs")
        }
        // Directly certified levels equal the stored witness levels.
        let numbers: [Int] = [1, 3, 21, 100]
        for number in numbers {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            let generated: ApsidesWorkshopGenerated = try Core.generated(number: number)
            #expect(generated.level.fingerprint == witness.fingerprint, "a level fingerprint differs")
            #expect(generated.skipped == witness.skipped)
        }
    }

    @Test func theCertifiedPlanOfLevelOneWinsThroughTheAdapter() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let generated: ApsidesWorkshopGenerated = try Core.generated(number: 1)
        #expect(generated.plan.actions == [.periapsis(0, 0)])
        #expect(core.apply(Self.act("clock.show", [11])) == .accepted)
        for step in generated.plan.actions {
            #expect(core.apply(Self.act(step)) == .accepted)
            #expect(core.shownTick == 11, "a tuning keeps the shown tick")
        }
        #expect(core.apply(Self.act("orbit.play")) == .accepted)
        #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
        #expect(core.play.failure == nil && core.play.report.wins)
        #expect(core.play.actionsLeft == core.play.level.budget - generated.plan.size)
        #expect(core.snapshot(time: 0).isWon && core.shownTick == 11)
        // A won play is final: a tuning, the play, undo and redo are the kernel's stage refusal; showing is still
        // accepted.
        let stage: ActionResult = .rejected(.rule(code: "r02-g18.stage"))
        #expect(core.apply(Self.act("orbit.periapsis", [5, 5])) == stage)
        #expect(core.apply(Self.act("orbit.size", [20])) == stage)
        #expect(core.apply(Self.act("orbit.play")) == stage)
        #expect(core.apply(Self.act("play.undo")) == stage)
        #expect(core.apply(Self.act("play.redo")) == stage)
        #expect(core.apply(Self.act("clock.show", [23])) == .accepted && core.shownTick == 23)
    }

    @Test func aPlayFromTheOpeningFailsAndUndoReturnsToPlaying() async throws {
        // The level rules guarantee the starting orbit does not win.
        var core: Core = try await Core.prepare(seed: 0)
        let openingDigest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("clock.show", [4])) == .accepted)
        #expect(core.apply(Self.act("orbit.play")) == .accepted)
        #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode)
        let failure: ApsidesWorkshopFailure = try #require(core.play.failure)
        #expect(core.play.level.startReport.failure == failure && core.play.actionsLeft == core.play.level.budget)
        let snapshot: ApsidesWorkshopSceneSnapshot = core.snapshot(time: 0)
        #expect(snapshot.failure == failure && snapshot.stage == .failed && snapshot.shownTick == 4)
        let stage: ActionResult = .rejected(.rule(code: "r02-g18.stage"))
        #expect(core.apply(Self.act("orbit.periapsis", [0, 0])) == stage)
        #expect(core.apply(Self.act("orbit.play")) == stage)
        #expect(core.apply(Self.act("play.redo")) == stage)
        #expect(core.apply(Self.act("clock.show", [7])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.play.stage == .playing && core.outcome == nil && core.play.failure == nil)
        #expect(core.shownTick == 7)
        #expect(try Self.digest(core) == openingDigest)
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: the starting orbit a = 18, k = 10, d = 6, period 24, budget 9.
        let core: Core = try await Core.prepare(seed: 0)
        let level: ApsidesWorkshopLevel = core.play.level
        #expect(level.period == 24 && level.budget == 9)
        #expect(level.orbit == ApsidesWorkshopOrbit(size: 18, eccentricity: 10, direction: 6))
        let opening: StateDigest = try Self.digest(core)
        let records: Int = core.play.records.count
        let illegal: [ExperienceAction] = [Self.act("orbit.periapsis", [10, 6]), Self.act("orbit.periapsis", [16, 0]),
                                           Self.act("orbit.periapsis", [-1, 0]), Self.act("orbit.periapsis", [0, 24]),
                                           Self.act("orbit.periapsis", [0.5, 0]), Self.act("orbit.periapsis", [0, 1.5]),
                                           Self.act("orbit.periapsis", [.nan, 0]), Self.act("orbit.periapsis", [1]),
                                           Self.act("orbit.periapsis"), Self.act("orbit.periapsis", [1, 2, 3]),
                                           Self.act("orbit.size", [18]), Self.act("orbit.size", [48]),
                                           Self.act("orbit.size", [7]), Self.act("orbit.size", [49]),
                                           Self.act("orbit.size", [12.5]), Self.act("orbit.size", [.infinity]),
                                           Self.act("orbit.size"), Self.act("clock.show", [24]),
                                           Self.act("clock.show", [95]), Self.act("clock.show", [96]),
                                           Self.act("clock.show", [-1]), Self.act("clock.show", [2.5]),
                                           Self.act("clock.show", [1, 1]), Self.act("play.undo"),
                                           Self.act("play.redo"), Self.act("play.undo", [1]),
                                           Self.act("orbit.play", [1]), Self.act("level.next", [1]),
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
        #expect(probe.apply(Self.act("orbit.periapsis", [16, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("orbit.periapsis", [-1, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("orbit.periapsis", [0, 24])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("orbit.size", [7])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("orbit.size", [49])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("clock.show", [96])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("clock.show", [-1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("orbit.periapsis", [.nan, 0])) == .rejected(.nonFinite(index: 0)))
        #expect(probe.apply(Self.act("orbit.periapsis", [1])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("orbit.size")) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(probe.apply(Self.act("clock.show", [1, 1])) == .rejected(.wrongValueCount(expected: 1, found: 2)))
        let noValues: ActionResult = .rejected(.wrongValueCount(expected: 0, found: 1))
        #expect(probe.apply(Self.act("orbit.play", [1])) == noValues)
        #expect(probe.apply(Self.act("play.undo", [1])) == noValues)
        #expect(probe.apply(Self.act("play.redo", [1])) == noValues)
        #expect(probe.apply(Self.act("level.next", [1])) == noValues)
        // Feature 477: replay.step and replay.stop take no values; replay.start and settings.sound one.
        #expect(probe.apply(Self.act("replay.step", [1])) == noValues)
        #expect(probe.apply(Self.act("replay.stop", [1])) == noValues)
        #expect(probe.apply(Self.act("replay.start")) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(probe.apply(Self.act("replay.start", [101])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("settings.sound", [2])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("settings.sound")) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        let notWhole: ActionResult = .rejected(.rule(code: ApsidesWorkshopExperienceRule.notWhole))
        #expect(probe.apply(Self.act("orbit.periapsis", [0.5, 0])) == notWhole)
        #expect(probe.apply(Self.act("orbit.periapsis", [0, 1.5])) == notWhole)
        #expect(probe.apply(Self.act("orbit.size", [12.5])) == notWhole)
        #expect(probe.apply(Self.act("clock.show", [2.5])) == notWhole)
        // A tick past the period: the adapter's refusal.
        let tick: ActionResult = .rejected(.rule(code: ApsidesWorkshopExperienceRule.tick))
        #expect(probe.apply(Self.act("clock.show", [24])) == tick)
        #expect(probe.apply(Self.act("clock.show", [95])) == tick)
        // The kernel's refusals pass through with their codes: unchanged, invalid (apoapsis 48 · 30 > 1280), nothing
        // to undo or redo.
        let action: ActionResult = .rejected(.rule(code: "r02-g18.action"))
        #expect(probe.apply(Self.act("orbit.periapsis", [10, 6])) == action)
        #expect(probe.apply(Self.act("orbit.size", [18])) == action)
        #expect(probe.apply(Self.act("orbit.size", [48])) == action)
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe == core && probe.play.records.count == records && probe.shownTick == 0)
        // Every legal tick is accepted and changes nothing else.
        for shown in 0..<level.period {
            #expect(probe.apply(Self.act("clock.show", [Double(shown)])) == .accepted && probe.shownTick == shown)
        }
        #expect(try Self.digest(probe) == opening && probe == core)
        // Every legal action is accepted; a tuning, undo and redo keep the shown tick.
        #expect(probe.apply(Self.act("clock.show", [7])) == .accepted)
        #expect(probe.apply(Self.act("orbit.periapsis", [3, 9])) == .accepted && probe.play.actionsLeft == 8)
        #expect(probe.play.orbit == ApsidesWorkshopOrbit(size: 18, eccentricity: 3, direction: 9))
        #expect(probe.apply(Self.act("orbit.size", [20])) == .accepted && probe.play.actionsLeft == 7)
        #expect(probe.play.orbit == ApsidesWorkshopOrbit(size: 20, eccentricity: 3, direction: 9))
        #expect(probe.shownTick == 7)
        #expect(probe.apply(Self.act("play.undo")) == .accepted && probe.play.actionsLeft == 8)
        #expect(probe.shownTick == 7)
        #expect(probe.apply(Self.act("play.redo")) == .accepted && probe.play.actionsLeft == 7)
        #expect(probe.shownTick == 7)
        // A refused tuning keeps the shown tick.
        #expect(probe.apply(Self.act("orbit.size", [20])) == action && probe.shownTick == 7)
        // Feature 475: `level.next` needs the next level open; level 2 is not open until level 1 is won.
        #expect(probe.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g18.locked")))
        #expect(probe.shownTick == 7 && probe.levelNumber == 1)
        #expect(probe.apply(Self.act("mode.practice")) == .accepted && probe.levelNumber == 1)
        #expect(probe.play.stage == .playing && probe.play.actionsLeft == Core.practiceBudget)
        #expect(probe.shownTick == 0)
    }

    @Test func theBudgetRefusesATuningButNotThePlay() async throws {
        // Level 1, budget 9: the size alternates between 17 and 18.
        var core: Core = try await Core.prepare(seed: 0)
        for change in 0..<9 {
            let size: Double = change % 2 == 0 ? 17 : 18
            #expect(core.apply(Self.act("orbit.size", [size])) == .accepted)
        }
        #expect(core.play.actionsLeft == 0)
        let before: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("orbit.size", [19])) == .rejected(.rule(code: "r02-g18.budget")))
        #expect(core.apply(Self.act("orbit.periapsis", [0, 0])) == .rejected(.rule(code: "r02-g18.budget")))
        #expect(try Self.digest(core) == before)
        #expect(core.apply(Self.act("orbit.play")) == .accepted)
        #expect(core.play.stage == .won || core.play.stage == .failed)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLaterOne() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let records: Int = core.play.records.count
        #expect(core.apply(Self.act("orbit.size", [20])) == .accepted)
        let afterChange: StateDigest = try Self.digest(core)
        #expect(afterChange != opening)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening && core.play.records.count == records + 2)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(try Self.digest(core) == afterChange && core.play.records.count == records + 3)
        // A new tuning after an undo (the same one again) clears the redo stack.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("orbit.size", [20])) == .accepted)
        #expect(try Self.digest(core) == afterChange)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g18.action")))
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
        // The play is undone and redone exactly as well.
        #expect(core.apply(Self.act("orbit.play")) == .accepted)
        let afterPlay: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(try Self.digest(core) == afterPlay)
    }

    @Test func showingChangesTheSnapshotButNeverTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let before: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let play: ApsidesWorkshopPlay = core.play
        var snapshots: [ApsidesWorkshopSceneSnapshot] = [core.snapshot(time: 1)]
        for shown in 1..<play.level.period {
            #expect(core.apply(Self.act("clock.show", [Double(shown)])) == .accepted)
            let snapshot: ApsidesWorkshopSceneSnapshot = core.snapshot(time: 1)
            #expect(snapshot.shownTick == shown && snapshot.orbiter == play.report.positions[shown])
            #expect(snapshot.positions == play.report.positions && snapshot.orbit == play.orbit)
            #expect(try Self.digest(core) == before && core.play == play)
            #expect(try core.snapshotPayload() == payload)
            snapshots.append(snapshot)
        }
        #expect(snapshots.count == 24)
        for index in 1..<snapshots.count { #expect(snapshots[index] != snapshots[index - 1]) }
        // A refused tick keeps the current one.
        let shown: Int = core.shownTick
        #expect(core.apply(Self.act("clock.show", [40])) == .rejected(.rule(code: "r02-g18.tick")))
        #expect(core.apply(Self.act("clock.show", [3.25])) == .rejected(.rule(code: "r02-g18.not-whole")))
        #expect(core.snapshot(time: 1).shownTick == shown && core.shownTick == shown)
        // Reset, restore and a new opening (here practice; since feature 475 `level.next` needs the next level open)
        // return to tick 0.
        var reset: Core = core
        reset.reset()
        let opened: Core = try Core.opening(number: 1)
        #expect(reset.shownTick == 0 && reset == opened)
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && restored.shownTick == 0)
        var next: Core = core
        #expect(next.apply(Self.act("mode.practice")) == .accepted)
        #expect(next.shownTick == 0)
    }

    @Test func levelNextNeedsAnOpenLevelAndResetReturns() async throws {
        var core: Core = try await Core.prepare(seed: 99)
        #expect(core.levelNumber == 100)
        let hundred: ApsidesWorkshopGenerated = try Core.generated(number: 100)
        let first: ApsidesWorkshopAction = try #require(hundred.plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("clock.show", [30])) == .accepted)
        // Feature 475: no wrap; after winning level 100, `level.next` is still refused and level 1 is chosen with
        // `level.select`.
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g18.locked")))
        #expect(core.shownTick == 30)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        for step in hundred.plan.actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.apply(Self.act("orbit.play")) == .accepted)
        #expect(core.play.stage == .won && core.progress.solved[100] != nil && core.progress.frontier == 100)
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g18.locked")))
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
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
        // Level 21 after a tuning, an undo, a redo and an undo.
        var core: Core = try await Core.prepare(seed: 20)
        let first: ApsidesWorkshopAction = try #require(try Core.generated(number: 21).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("clock.show", [6])) == .accepted)
        let savedDigest: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let text: String = String(decoding: payload, as: UTF8.self)
        let prefix: String = "{\"level\":21,\"mode\":{\"mode\":\"campaign\"},\"progress\":{\"frontier\":21,"
        #expect(text.hasPrefix(prefix))
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
        #expect(failed.apply(Self.act("orbit.play")) == .accepted && failed.play.stage == .failed)
        let failedRestored: Core = try Core.restore(payload: try failed.snapshotPayload(), seed: 20)
        #expect(failedRestored == failed && failedRestored.outcome?.code == Core.failedCode)
        // Refusals.
        #expect(throws: ApsidesWorkshopRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 20)
        }
        #expect(throws: ApsidesWorkshopRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 20)
        }
        #expect(throws: ApsidesWorkshopRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"21\",\"records\":[]}".utf8), seed: 20)
        }
        // A schema-1 object is no schema-2 payload (the engine migrates it first).
        #expect(throws: ApsidesWorkshopRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":21,\"records\":[]}".utf8), seed: 20)
        }
        let rest: String = ",\"mode\":{\"mode\":\"campaign\"},"
            + "\"progress\":{\"frontier\":1,\"solved\":[]},\"records\":[]}"
        #expect(throws: ApsidesWorkshopRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data(("{\"level\":0" + rest).utf8), seed: 20)
        }
        #expect(throws: ApsidesWorkshopRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data(("{\"level\":101" + rest).utf8), seed: 20)
        }
        // A trace of level 21 restored as level 22 (another seed).
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "{\"level\":21,", with: "{\"level\":22,").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: ApsidesWorkshopRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: wrongLevel, seed: 20)
        }
        // A record of a newer schema.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: ApsidesWorkshopRestoreRefusal.kernel(.malformed("schema 0"))) {
            try Core.restore(payload: newer, seed: 20)
        }
        // An edited trace: the first record's index changed.
        let edited: Data = Data(text.replacingOccurrences(of: "\"index\":0,", with: "\"index\":3,").utf8)
        #expect(edited != payload)
        #expect(throws: ApsidesWorkshopRestoreRefusal.kernel(.malformed("index 0"))) {
            try Core.restore(payload: edited, seed: 20)
        }
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        // Level 1: its certified tuning.
        #expect(engine.handle(control: "orbit.periapsis", values: [0, 0]) == .accepted)
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
        // Level 41 after its certified tuning, tick 9 shown.
        var core: Core = try await Core.prepare(seed: 40)
        let first: ApsidesWorkshopAction = try #require(try Core.generated(number: 41).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("clock.show", [9])) == .accepted)
        let play: ApsidesWorkshopPlay = core.play
        let level: ApsidesWorkshopLevel = play.level
        let snapshot: ApsidesWorkshopSceneSnapshot = core.snapshot(time: 2.5)
        #expect(snapshot.orbit == play.orbit && snapshot.positions == play.report.positions)
        #expect(snapshot.ghost == ApsidesWorkshopSky.positions(level.orbit, period: level.period).points)
        #expect(snapshot.orbiter == play.report.positions[9] && snapshot.shares == play.report.shares)
        #expect(snapshot.periapsisSector == play.orbit.periapsisSector)
        #expect(snapshot.periapsisDistance == play.orbit.periapsisDistance)
        #expect(snapshot.apoapsisSector == play.orbit.apoapsisSector)
        #expect(snapshot.apoapsisDistance == play.orbit.apoapsisDistance)
        #expect(snapshot.planets == level.planets && snapshot.gauges.count == level.targets.count)
        for index in level.targets.indices {
            #expect(snapshot.gauges[index].target == level.targets[index])
            #expect(snapshot.gauges[index].deviation == play.report.deviations[index])
            #expect(snapshot.gauges[index].met == (index < play.report.met))
        }
        #expect(snapshot.failure == play.report.failure && snapshot.stage == play.stage)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.period == level.period && snapshot.shownTick == 9)
        #expect(snapshot.levelNumber == 41 && snapshot.time == 2.5)
        #expect(core.renderTier == ApsidesWorkshopTier.of(0))
    }
}

/// Feature 475 (R02-G18-05) T-R02G1805-004 (FR-R02G1805-001, 004 … 007; clarifications Q2–Q5): the adapter's teaching
/// and progression, modelled on feature 465's `CelestialEclipseLabProgressionCoreTests`. Level facts used: level 1's
/// certified plan is the knob to (0, 0), followed by the play (budget 9, starting orbit a = 18, k = 10, d = 6, where
/// size 17 is a legal tuning); the play from any opening fails (a valid level's starting orbit never wins); levels
/// 1 … 3 carry the tutorial; the daily level of 2026-11-18 is level 84 (321 days × 23 mod 100 + 1) and of 2026-01-01
/// level 1. Explicit types, plain loops, no wall-clock asserts.
@Suite struct ApsidesWorkshopProgressionCoreTests {
    typealias Core = ApsidesWorkshopExperienceCore

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
    static func act(_ action: ApsidesWorkshopAction) -> ExperienceAction {
        switch action {
        case let .periapsis(eccentricity, direction): act("orbit.periapsis", [Double(eccentricity), Double(direction)])
        case let .size(size): act("orbit.size", [Double(size)])
        case .play: act("orbit.play")
        }
    }

    /// The certified plan's tunings of level `number` (the play not included).
    static func plan(_ number: Int) throws -> [ApsidesWorkshopAction] {
        try Core.generated(number: number).plan.actions
    }

    /// Applies the certified plan of `core`'s level and the play; whether every action was accepted and the play won.
    static func win(_ core: inout Core) throws -> Bool {
        var accepted: Bool = true
        for step in try plan(core.levelNumber) + [.play] {
            accepted = accepted && core.apply(act(step)) == .accepted
        }
        return accepted && core.play.stage == .won
    }

    /// A daily date of 2026 whose daily level is not a tutorial level (4 … 100) and not open on a fresh opening of
    /// level 1, with that level; the level is computed with `ApsidesWorkshopProgress.dailyLevel`.
    static func plainDaily() throws -> (date: [Double], level: Int) {
        let date: [Double] = [2026, 11, 18]
        let level: Int = try #require(ApsidesWorkshopProgress.dailyLevel(year: 2026, month: 11, day: 18))
        try #require(level > ApsidesWorkshopTutorialStep.tutorialLevels.upperBound)
        return (date, level)
    }

    /// The schema-1 object `{"level", "records"}` of `core`.
    static func schemaOne(_ core: Core) throws -> [String: Any] {
        let records: Data = try Core.payloadEncoder().encode(core.play.records)
        let recordsObject: Any = try JSONSerialization.jsonObject(with: records)
        return ["level": core.levelNumber, "records": recordsObject]
    }

    @Test func theProgressionControlsRefuseWhatTheyMust() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let locked: ActionResult = .rejected(.rule(code: ApsidesWorkshopExperienceRule.locked))
        let date: ActionResult = .rejected(.rule(code: ApsidesWorkshopExperienceRule.date))
        let notWhole: ActionResult = .rejected(.rule(code: ApsidesWorkshopExperienceRule.notWhole))
        #expect(locked == .rejected(.rule(code: "r02-g18.locked")) && date == .rejected(.rule(code: "r02-g18.date")))
        let actions: [ExperienceAction] = [
            Self.act("level.select", [2]), Self.act("level.select", [100]), Self.act("level.select", [0]),
            Self.act("level.select", [101]), Self.act("level.select", [1.5]), Self.act("level.select", []),
            Self.act("mode.daily", [0, 1, 1]), Self.act("mode.daily", [2026, 13, 1]),
            Self.act("mode.daily", [2026, 1, 32]), Self.act("mode.daily", [2026, 2, 30]),
            Self.act("mode.daily", [2025, 2, 29]), Self.act("mode.daily", [2026, 4, 31]),
            Self.act("mode.daily", [2026, 1.5, 1]), Self.act("mode.daily", [2026, 1]),
            Self.act("mode.practice", [1]), Self.act("mode.campaign", [1]), Self.act("tutorial.dismiss", [1]),
            Self.act("level.next"),
        ]
        let expected: [ActionResult] = [
            locked, locked, .rejected(.outOfRange(index: 0)),
            .rejected(.outOfRange(index: 0)), notWhole, .rejected(.wrongValueCount(expected: 1, found: 0)),
            .rejected(.outOfRange(index: 0)), .rejected(.outOfRange(index: 1)),
            .rejected(.outOfRange(index: 2)), date,
            date, date,
            notWhole, .rejected(.wrongValueCount(expected: 3, found: 2)),
            .rejected(.wrongValueCount(expected: 0, found: 1)), .rejected(.wrongValueCount(expected: 0, found: 1)),
            .rejected(.wrongValueCount(expected: 0, found: 1)),
            locked,
        ]
        #expect(actions.count == expected.count)
        for index in actions.indices {
            var copy: Core = core
            #expect(copy.apply(actions[index]) == expected[index], "\(actions[index].control) \(actions[index].values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening, "\(actions[index].control) \(actions[index].values)")
            #expect(copy.shownTick == core.shownTick && copy.tutorial == core.tutorial)
        }
        // A leap year's 29 February is a date.
        var leap: Core = core
        #expect(leap.apply(Self.act("mode.daily", [2028, 2, 29])) == .accepted)
        let leapLevel: Int = try #require(ApsidesWorkshopProgress.dailyLevel(year: 2028, month: 2, day: 29))
        #expect(leap.mode == .daily(level: leapLevel) && leap.levelNumber == leapLevel)
        #expect(!leap.play.canUndo && leap.play.stage == .playing && leap.progress == core.progress)
    }

    @Test func campaignWinsRecordStarsAndOpenTheNextLevel() async throws {
        let actions: [ApsidesWorkshopAction] = try Self.plan(1)
        let certified: Int = actions.count
        #expect(certified == 1 && actions == [.periapsis(0, 0)])
        // A win that spent one undone tuning more than the plan: 2 stars, level 2 opened.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.certifiedTunings == certified && core.mode == .campaign && core.progress.frontier == 1)
        #expect(core.band == 1)
        #expect(core.apply(Self.act("orbit.size", [17])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        for step in actions { #expect(core.apply(Self.act(step)) == .accepted) }
        // The tunings alone record nothing: only the winning play does.
        #expect(core.progress.solved.isEmpty && core.progress.frontier == 1)
        #expect(core.apply(Self.act("orbit.play")) == .accepted)
        #expect(core.play.stage == .won && ApsidesWorkshopProgress.actionsSpent(core.play) == certified + 1)
        let twoStars: Int = ApsidesWorkshopProgress.stars(actionsSpent: certified + 1, certified: certified)
        #expect(twoStars == 2)
        // Feature 477: the result carries the winning trace (the undone size tuning left out, the play last), verified.
        let twoStarResult = ApsidesWorkshopProgress.Result(actionsSpent: certified + 1, stars: twoStars,
                                                           trace: actions + [.play], verified: true)
        #expect(core.progress.solved[1] == twoStarResult)
        #expect(core.progress.frontier == 2 && core.progress.isOpen(2) && !core.progress.isOpen(3))
        // level.next goes to the newly opened level 2, fresh, with its tutorial.
        var next: Core = core
        #expect(next.apply(Self.act("level.next")) == .accepted)
        #expect(next.levelNumber == 2 && !next.play.canUndo && next.mode == .campaign)
        let secondTunings: Int = try Self.plan(2).count
        #expect(next.tutorial == .knob && next.certifiedTunings == secondTunings)
        // A better result replaces it: the plan alone, 3 stars.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        #expect(core.levelNumber == 1 && !core.play.canUndo && core.mode == .campaign)
        #expect(try Self.win(&core))
        let best: ApsidesWorkshopProgress.Result = ApsidesWorkshopProgress.Result(actionsSpent: certified, stars: 3,
                                                                                  trace: actions + [.play],
                                                                                  verified: true)
        #expect(core.progress.solved[1] == best)
        // A worse result keeps the best one: four undone tunings more than the plan (1 star) change nothing.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        for _ in 0..<4 {
            #expect(core.apply(Self.act("orbit.size", [17])) == .accepted)
            #expect(core.apply(Self.act("play.undo")) == .accepted)
        }
        #expect(try Self.win(&core))
        #expect(ApsidesWorkshopProgress.actionsSpent(core.play) == certified + 4)
        #expect(ApsidesWorkshopProgress.stars(actionsSpent: certified + 4, certified: certified) == 1)
        #expect(core.progress.solved[1] == best && core.progress.frontier == 2)
        // A failed play records nothing.
        var failed: Core = try Core.opening(number: 1)
        #expect(failed.apply(Self.act("orbit.play")) == .accepted && failed.play.stage == .failed)
        #expect(failed.progress.solved.isEmpty && failed.progress.frontier == 1)
        // The frontier: level 2 can be chosen, level 3 cannot.
        #expect(core.apply(Self.act("level.select", [3])) == .rejected(.rule(code: "r02-g18.locked")))
        #expect(core.apply(Self.act("level.select", [2])) == .accepted)
        #expect(core.levelNumber == 2 && core.play.stage == .playing && core.tutorial == .knob)
        // level.next from the frontier is refused: no next open level.
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g18.locked")))
        #expect(core.levelNumber == 2)
    }

    @Test func onlyAWinningPlayRecordsAWin() async throws {
        // A won play is final: the winning play cannot be undone, so it is recorded once.
        var core: Core = try await Core.prepare(seed: 0)
        let actions: [ApsidesWorkshopAction] = try Self.plan(1)
        #expect(try Self.win(&core))
        let recorded: ApsidesWorkshopProgress = core.progress
        #expect(core.apply(Self.act("play.undo")) == .rejected(.rule(code: "r02-g18.stage")))
        #expect(core.apply(Self.act("orbit.play")) == .rejected(.rule(code: "r02-g18.stage")))
        #expect(core.progress == recorded)
        // A failing play undone and redone: the redo restores the failed moment and records nothing.
        var broken: Core = try Core.opening(number: 1)
        #expect(broken.apply(Self.act("orbit.play")) == .accepted)
        #expect(broken.apply(Self.act("play.undo")) == .accepted && broken.play.stage == .playing)
        #expect(broken.apply(Self.act("play.redo")) == .accepted && broken.play.stage == .failed)
        #expect(broken.progress.solved.isEmpty && broken.progress.frontier == 1)
        // The winning tunings redone without the play are no win: only the play ends a level.
        var plain: Core = try Core.opening(number: 1)
        for step in actions { #expect(plain.apply(Self.act(step)) == .accepted) }
        #expect(plain.apply(Self.act("play.undo")) == .accepted)
        #expect(plain.apply(Self.act("play.redo")) == .accepted && plain.play.stage == .playing)
        #expect(plain.play.report.wins && plain.progress.solved.isEmpty)
    }

    @Test func practiceAndDailyFollowTheirRules() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let certified: ApsidesWorkshopLevel = try Core.level(number: 1)
        // Practice: a copy of the level with the budget raised to 24; a win records nothing and opens nothing.
        #expect(core.apply(Self.act("clock.show", [5])) == .accepted)
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == 1 && !core.play.canUndo)
        #expect(core.play.level.budget == 24 && core.play.actionsLeft == 24 && core.tutorial == .knob)
        #expect(core.shownTick == 0)
        #expect(Core.practiceBudget == 24 && certified.budget != 24)
        #expect(core.play.level.planets == certified.planets && core.play.level.targets == certified.targets)
        #expect(core.play.level.orbit == certified.orbit && core.play.level.period == certified.period)
        #expect(core.play.level.seed == certified.seed && core.play.level.tutorial == certified.tutorial)
        #expect(core.play.level.id == certified.id && core.play.level.difficulty == certified.difficulty)
        #expect(try Core.practiceLevel(of: certified) == core.play.level)
        let before: ApsidesWorkshopProgress = core.progress
        #expect(try Self.win(&core))
        #expect(core.progress == before && core.progress.solved.isEmpty && core.progress.frontier == 1)
        // Campaign returns to the current level when it is open, fresh, with the certified budget.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && !core.play.canUndo)
        #expect(core.play.level == certified && core.play.actionsLeft == certified.budget)
        // Daily: the date's level, playable while still locked; level.next from it is refused; a win records the
        // level's best result and stars and opens nothing.
        let (dailyDate, daily): ([Double], Int) = try Self.plainDaily()
        #expect(daily == 84 && !core.progress.isOpen(daily))
        #expect(core.apply(Self.act("mode.daily", dailyDate)) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily && core.tutorial == .done)
        let dailyCertified: ApsidesWorkshopLevel = try Core.level(number: daily)
        #expect(core.play.level == dailyCertified && !core.progress.isOpen(daily))
        #expect(core.band == ApsidesWorkshopProgress.band(of: daily))
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g18.locked")))
        let dailyActions: [ApsidesWorkshopAction] = try Self.plan(daily)
        #expect(core.certifiedTunings == dailyActions.count)
        #expect(try Self.win(&core))
        #expect(core.progress.frontier == 1 && !core.progress.isOpen(daily))
        let result: ApsidesWorkshopProgress.Result = try #require(core.progress.solved[daily])
        #expect(result == ApsidesWorkshopProgress.Result(actionsSpent: dailyActions.count, stars: 3,
                                                         trace: dailyActions + [.play], verified: true))
        // Campaign from a level that is not open goes to the frontier.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1)
        // A daily tutorial level carries the tutorial: 2026-01-01 is level 1.
        #expect(ApsidesWorkshopProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 1])) == .accepted)
        #expect(core.mode == .daily(level: 1) && core.levelNumber == 1 && core.tutorial == .knob)
    }

    @Test func progressAndModeAreDigestedButNotTheStepOrTheShownTick() async throws {
        // The same fresh play in another mode digests differently.
        var campaign: Core = try await Core.prepare(seed: 0)
        var practice: Core = campaign
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(campaign.apply(Self.act("mode.campaign")) == .accepted)
        #expect(try Self.digest(practice) != (try Self.digest(campaign)))
        var dailyOne: Core = campaign
        #expect(dailyOne.apply(Self.act("mode.daily", [2026, 1, 1])) == .accepted)
        #expect(dailyOne.play == campaign.play && dailyOne.levelNumber == campaign.levelNumber)
        #expect(try Self.digest(dailyOne) != (try Self.digest(campaign)))
        // The same fresh play after a campaign win: only the progress differs, and the digest with it.
        var won: Core = campaign
        #expect(try Self.win(&won))
        #expect(won.apply(Self.act("level.select", [1])) == .accepted)
        #expect(won.play == campaign.play && won.mode == campaign.mode && won.progress != campaign.progress)
        #expect(try Self.digest(won) != (try Self.digest(campaign)))
        // Neither the shown tick nor the tutorial step is digested.
        var shown: Core = campaign
        #expect(shown.apply(Self.act("clock.show", [9])) == .accepted)
        let campaignDigest: StateDigest = try Self.digest(campaign)
        #expect(shown == campaign)
        #expect(try Self.digest(shown) == campaignDigest)
        var dismissed: Core = campaign
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed != campaign)
        #expect(try Self.digest(dismissed) == campaignDigest)
    }

    @Test func theTutorialAdvancesInOrderAndIsNotDigested() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.tutorial == .knob && core.tutorial.text.hasPrefix("Drag the periapsis knob"))
        // Dismissing ends it; the step is state (==) and saved, but never digested.
        let digest: StateDigest = try Self.digest(core)
        var dismissed: Core = core
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed.tutorial == .done && dismissed != core && dismissed.play == core.play)
        #expect(try Self.digest(dismissed) == digest)
        #expect(try dismissed.snapshotPayload() != (try core.snapshotPayload()))
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted && dismissed.tutorial == .done)
        // Showing a tick is no tuning: knob stays.
        var shown: Core = core
        #expect(shown.apply(Self.act("clock.show", [3])) == .accepted && shown.tutorial == .knob)
        // A refused tuning moves nothing: the starting orbit again.
        #expect(shown.apply(Self.act("orbit.periapsis", [10, 6])) == .rejected(.rule(code: "r02-g18.action")))
        #expect(shown.tutorial == .knob)
        // A tuning: knob → order; an undo does not move it back, nor a redo forward.
        let plan: [ApsidesWorkshopAction] = try Self.plan(1)
        #expect(core.apply(Self.act("orbit.size", [17])) == .accepted)
        #expect(core.play.stage == .playing && core.tutorial == .order)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .order)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .order)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .order)
        // A second tuning: order → recover; recover lasts through undo and redo.
        #expect(core.apply(Self.act(plan[0])) == .accepted)
        #expect(core.play.stage == .playing && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .recover)
        // The end of the level ends it: the winning play.
        #expect(core.apply(Self.act("orbit.play")) == .accepted)
        #expect(core.play.stage == .won && core.tutorial == .done)
        // A play moves any step straight to done: the failing play from a fresh opening goes knob → done; the undo
        // that retries does not bring it back; a redo that restores the failed play ends a step restored as knob.
        var broken: Core = try Core.opening(number: 1)
        #expect(broken.apply(Self.act("orbit.play")) == .accepted)
        #expect(broken.play.stage == .failed && broken.tutorial == .done)
        #expect(broken.progress.solved.isEmpty && broken.progress.frontier == 1)
        #expect(broken.apply(Self.act("play.undo")) == .accepted)
        #expect(broken.play.stage == .playing && broken.tutorial == .done)
        let brokenText: String = String(decoding: try broken.snapshotPayload(), as: UTF8.self)
        let knobText: String = brokenText.replacingOccurrences(of: "\"tutorial\":\"done\"",
                                                               with: "\"tutorial\":\"knob\"")
        #expect(knobText != brokenText)
        var redone: Core = try Core.restore(payload: Data(knobText.utf8), seed: 0)
        #expect(redone.tutorial == .knob && redone.play == broken.play && redone.play.canRedo)
        #expect(redone.apply(Self.act("play.redo")) == .accepted)
        #expect(redone.play.stage == .failed && redone.tutorial == .done)
        // Choosing a level or a mode restarts the step of that level; a level without the tutorial starts done.
        #expect(broken.apply(Self.act("mode.practice")) == .accepted)
        #expect(broken.tutorial == ApsidesWorkshopTutorialStep.initial(level: broken.levelNumber))
        #expect(broken.tutorial == .knob)
        for number in 1...6 {
            let opening: Core = try Core.opening(number: number)
            let expected: ApsidesWorkshopTutorialStep = number <= 3 ? .knob : .done
            #expect(opening.tutorial == expected && ApsidesWorkshopTutorialStep.initial(level: number) == expected)
            #expect(opening.play.level.tutorial == (number <= 3))
        }
        var plain: Core = try Core.opening(number: 4)
        let plainFirst: ApsidesWorkshopAction = try #require(try Self.plan(4).first)
        #expect(plain.apply(Self.act(plainFirst)) == .accepted && plain.tutorial == .done)
        // The step is saved and restored.
        var saved: Core = try await Core.prepare(seed: 0)
        #expect(saved.apply(Self.act(plan[0])) == .accepted)
        let payload: Data = try saved.snapshotPayload()
        #expect(String(decoding: payload, as: UTF8.self).hasSuffix(",\"tutorial\":\"order\"}"))
        let restored: Core = try Core.restore(payload: payload, seed: 0)
        #expect(restored == saved && restored.tutorial == .order)
    }

    @Test func theSchemaThreePayloadRoundTripsInEveryModeAndRefusesDamage() async throws {
        // Campaign with progress: level 1 won, level 2 reached with level.next.
        var campaign: Core = try await Core.prepare(seed: 0)
        #expect(try Self.win(&campaign))
        #expect(campaign.apply(Self.act("level.next")) == .accepted)
        #expect(campaign.levelNumber == 2 && campaign.tutorial == .knob)
        // Practice: a tuning on the practice copy.
        var practice: Core = try await Core.prepare(seed: 0)
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(practice.apply(Self.act("orbit.size", [17])) == .accepted)
        // Daily: the first certified tuning of the date's level.
        let (dailyDate, dailyLevel): ([Double], Int) = try Self.plainDaily()
        var daily: Core = try await Core.prepare(seed: 0)
        #expect(daily.apply(Self.act("mode.daily", dailyDate)) == .accepted)
        let dailyFirst: ApsidesWorkshopAction = try #require(try Self.plan(dailyLevel).first)
        #expect(daily.apply(Self.act(dailyFirst)) == .accepted)
        let cores: [Core] = [campaign, practice, daily]
        for core in cores {
            let payload: Data = try core.snapshotPayload()
            #expect(try core.snapshotPayload() == payload)
            let restored: Core = try Core.restore(payload: payload, seed: 0)
            let restoredDigest: StateDigest = try Self.digest(restored)
            let savedDigest: StateDigest = try Self.digest(core)
            #expect(restored == core && restoredDigest == savedDigest, "\(core.mode)")
            #expect(restored.certifiedTunings == core.certifiedTunings && restored.openingNumber == 1)
            var reset: Core = restored
            reset.reset()
            #expect(reset == (try Core.opening(number: 1)))
        }
        #expect(practice.play.level.budget == 24)
        let restoredPractice: Core = try Core.restore(payload: try practice.snapshotPayload(), seed: 0)
        #expect(restoredPractice.play.level.budget == 24 && restoredPractice.mode == .practice)
        let campaignText: String = String(decoding: try campaign.snapshotPayload(), as: UTF8.self)
        let certified: Int = try Self.plan(1).count
        // Feature 477: each result carries its trace (the certified tuning, then the play) and whether it is verified.
        let traceText: String = String(decoding: try Core.payloadEncoder().encode(try Self.plan(1) + [.play]),
                                       as: UTF8.self)
        let progressText: String = "\"progress\":{\"frontier\":2,"
            + "\"solved\":[{\"actionsSpent\":\(certified),\"level\":1,\"stars\":3,\"trace\":" + traceText
            + ",\"verified\":true}]}"
        #expect(campaignText.contains(progressText))
        #expect(campaignText.contains(",\"sound\":false,\"tutorial\":\"knob\"}"))
        #expect(campaignText.hasPrefix("{\"level\":2,\"mode\":{\"mode\":\"campaign\"},"))
        #expect(campaignText.hasSuffix(",\"tutorial\":\"knob\"}"))
        let dailyText: String = String(decoding: try daily.snapshotPayload(), as: UTF8.self)
        let dailyPrefix: String = "{\"level\":\(dailyLevel),\"mode\":{\"level\":\(dailyLevel)"
        #expect(dailyText.hasPrefix(dailyPrefix + ",\"mode\":\"daily\"},"))
        // Damaged: a daily mode naming another level, an unknown mode, an invalid frontier, invalid stars, an unknown
        // tutorial step.
        let otherPrefix: String = "{\"level\":\(dailyLevel),\"mode\":{\"level\":\(dailyLevel - 1)"
        let otherDaily: Data = Data(dailyText.replacingOccurrences(of: dailyPrefix, with: otherPrefix).utf8)
        let unknownMode: Data = Data(campaignText.replacingOccurrences(of: "\"mode\":\"campaign\"",
                                                                       with: "\"mode\":\"arcade\"").utf8)
        let badFrontier: Data = Data(campaignText.replacingOccurrences(of: "\"frontier\":2",
                                                                       with: "\"frontier\":0").utf8)
        let badStars: Data = Data(campaignText.replacingOccurrences(of: "\"stars\":3", with: "\"stars\":4").utf8)
        let badStep: Data = Data(campaignText.replacingOccurrences(of: "\"tutorial\":\"knob\"",
                                                                   with: "\"tutorial\":\"later\"").utf8)
        let damaged: [Data] = [otherDaily, unknownMode, badFrontier, badStars, badStep]
        let campaignPayload: Data = try campaign.snapshotPayload()
        let dailyPayload: Data = try daily.snapshotPayload()
        for payload in damaged {
            #expect(payload != campaignPayload && payload != dailyPayload)
            #expect(throws: ApsidesWorkshopRestoreRefusal.damaged) { try Core.restore(payload: payload, seed: 0) }
        }
        // A payload without the tutorial key starts the tutorial at the level's first step.
        let noStep: Data = Data(campaignText.replacingOccurrences(of: ",\"tutorial\":\"knob\"", with: "").utf8)
        #expect(noStep != campaignPayload)
        let restoredNoStep: Core = try Core.restore(payload: noStep, seed: 0)
        #expect(restoredNoStep == campaign)
    }

    @Test func aSchemaOnePayloadMigratesAndANewerSchemaIsRefused() async throws {
        // Level 3 after its first certified tuning: the tutorial has advanced, which schema 1 did not save.
        var core: Core = try await Core.prepare(seed: 2)
        #expect(core.levelNumber == 3)
        let plan: [ApsidesWorkshopAction] = try Self.plan(3)
        try #require(!plan.isEmpty)
        #expect(core.apply(Self.act(plan[0])) == .accepted)
        #expect(core.tutorial == .order)
        let schemaOne: [String: Any] = try Self.schemaOne(core)
        let migrated: [String: Any] = try Core.migratedToSchemaThree(try Core.migratedToSchemaTwo(schemaOne))
        let chained: [String: Any] = try Core.migrations.migrate(schemaOne, from: 1)
        let data: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
        let chainedData: Data = try JSONSerialization.data(withJSONObject: chained, options: [.sortedKeys])
        #expect(data == chainedData)
        let restored: Core = try Core.restore(payload: data, seed: 2)
        #expect(restored.levelNumber == 3 && restored.play == core.play && restored.mode == .campaign)
        #expect(restored.progress.frontier == 3 && restored.progress.solved.isEmpty)
        #expect(restored.progress.isOpen(1) && restored.progress.isOpen(3) && !restored.progress.isOpen(4))
        #expect(restored.tutorial == .knob && restored.tutorial == ApsidesWorkshopTutorialStep.initial(level: 3))
        // Feature 477: the migration 2 → 3 sets the sound off; nothing to reconcile.
        #expect(migrated["sound"] as? Bool == false && !restored.soundOn && restored.reconciliationDropped == 0)
        // The tutorial step is not digested, so the migrated state digests as the saved one.
        #expect(try Self.digest(restored) == Self.digest(core))
        // A level without the tutorial migrates with it done: the fresh opening of level 7.
        let sevenOpening: Core = try Core.opening(number: 7)
        let seven: [String: Any] = try Core.migratedToSchemaTwo(try Self.schemaOne(sevenOpening))
        let sevenData: Data = try JSONSerialization.data(withJSONObject: seven, options: [.sortedKeys])
        let sevenCore: Core = try Core.restore(payload: sevenData, seed: 6)
        #expect(sevenCore == sevenOpening && sevenCore.tutorial == .done)
        // A schema-1 object that is not one is refused.
        #expect(throws: ApsidesWorkshopRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": "3"]) }
        #expect(throws: ApsidesWorkshopRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": 3]) }
        // A newer schema is refused by the chain.
        #expect(Core.schemaVersion == 3)
        #expect(throws: MigrationError.newerVersion(4)) { try Core.migrations.migrate(schemaOne, from: 4) }
    }

    @Test func theEngineMigratesASchemaOneEnvelopeAndRefusesANewerOne() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 2)
        try engine.activate()
        // Level 3: its first certified tuning.
        let first: ApsidesWorkshopAction = try #require(try Self.plan(3).first)
        let action: ExperienceAction = Self.act(first)
        #expect(engine.handle(control: action.control, values: action.values) == .accepted)
        let played: Core = try #require(engine.core)
        let saved: ExperienceSnapshot = try engine.snapshot()
        let schemaOne: [String: Any] = try Self.schemaOne(played)
        let schemaOneData: Data = try JSONSerialization.data(withJSONObject: schemaOne, options: [.sortedKeys])
        let old = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: saved.seed,
                                         stepIndex: saved.stepIndex, digest: saved.digest, payload: schemaOneData)
        try engine.restore(old)
        let migrated: Core = try #require(engine.core)
        #expect(migrated.levelNumber == 3 && migrated.play == played.play && migrated.mode == .campaign)
        #expect(migrated.progress.frontier == 3 && migrated.progress.solved.isEmpty)
        #expect(migrated.tutorial == .knob && played.tutorial == .order && !migrated.soundOn)
        #expect(try engine.digest() == saved.digest)
        // An envelope of schema 4 is refused and changes nothing.
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
        #expect(engine.core == migrated)
    }

    @Test func noLevelIsGatedByAnythingButBeingOpened() async throws {
        // Opening through wins: levels 1 → 2 → 3 by their certified plans, the play and level.next.
        var core: Core = try await Core.prepare(seed: 0)
        for number in 1...3 {
            #expect(core.levelNumber == number)
            #expect(try Self.win(&core))
            #expect(core.progress.frontier == number + 1)
            #expect(core.apply(Self.act("level.next")) == .accepted)
        }
        #expect(core.levelNumber == 4)
        // Opening through `open(through:)`: a saved progress with every level open makes every level selectable.
        var progress: ApsidesWorkshopProgress = ApsidesWorkshopProgress()
        progress.open(through: 100)
        #expect(progress.frontier == 100)
        let fresh: Core = try await Core.prepare(seed: 0)
        let text: String = String(decoding: try fresh.snapshotPayload(), as: UTF8.self)
        let progressJSON: String = String(decoding: try Core.payloadEncoder().encode(progress), as: UTF8.self)
        let allOpenText: String = text.replacingOccurrences(of: "\"progress\":{\"frontier\":1,\"solved\":[]}",
                                                            with: "\"progress\":" + progressJSON)
        #expect(allOpenText != text)
        let allOpen: Core = try Core.restore(payload: Data(allOpenText.utf8), seed: 0)
        #expect(allOpen.progress == progress)
        for number in 1...100 {
            #expect(allOpen.progress.isOpen(number))
            #expect(allOpen.progress.nextOpen(after: number) == (number < 100 ? number + 1 : nil))
        }
        // Selecting through the adapter: the last level of every band (the only refusal of `level.select` in range is
        // `progress.isOpen`).
        let samples: [Int] = [20, 40, 60, 80, 100]
        let refused: ActionResult = .rejected(.rule(code: "r02-g18.locked"))
        for number in samples {
            var copy: Core = allOpen
            #expect(copy.apply(Self.act("level.select", [Double(number)])) == .accepted, "level \(number)")
            #expect(copy.levelNumber == number && copy.mode == .campaign && copy.play.stage == .playing)
            #expect(copy.band == number / 20)
            var locked: Core = fresh
            #expect(locked.apply(Self.act("level.select", [Double(number)])) == refused)
        }
    }
}
