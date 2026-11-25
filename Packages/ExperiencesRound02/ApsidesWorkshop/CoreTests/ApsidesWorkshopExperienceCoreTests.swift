// ApsidesWorkshopExperienceCoreTests — feature 473 (R02-G18-03) T-R02G1803-005 (FR-R02G1803-005, 008, 009;
// SC-R02G1803-004; clarifications Q4, Q5). The adapter core: the shared conformance checks pass; the declared controls,
// ids, tiers and profile (the quality level names equal `ApsidesWorkshopTier.all`); the seed picks level
// `seed % 100 + 1` deterministically in stage `playing` with tick 0 shown (seeds 0, 1, 99 and 100 give levels 1, 2, 100
// and 1); every control is accepted when legal and refused with the state unchanged otherwise (the engine's range
// checks, `r02-g18.not-whole`, `r02-g18.tick` for a tick outside the period, and every kernel refusal the adapter can
// meet passing through with its code: `r02-g18.action` for a tuning equal to the current orbit or making it invalid and
// for nothing to undo or redo, `r02-g18.budget` and `r02-g18.stage`; `stale` cannot arise because every action names
// the current fingerprint); undo restores the earlier digest exactly and redo the later one; `clock.show` changes the
// snapshot but never the digest, the play or the payload, a tuning, the play, undo and redo keep it, and `level.next`,
// reset and restore return it to 0; the certified plan of level 1 wins through the adapter and a play from the opening
// fails, undo returning the failed play to playing; `level.next` wraps 100 to 1 and reset returns; the snapshot round
// trip and refused payloads (damaged, level out of range, a trace of another level, a record of a newer schema, an
// edited trace, an envelope of a newer schema); the certified-candidate table equals the generator's search for three
// levels and the 100 stored witnesses' `skipped`; `snapshot(time:)` copies the play. Levels are certified once per
// process, so the run stays short. Explicit types, plain loops, single-literal comments. Modelled on
// CelestialEclipseLabExperienceCoreTests (feature 463).
@testable import ApsidesWorkshopCore
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
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
        // Levels 1 and 3 (then 2 and 4). Level 1's certified plan is the knob to (0, 0); the play from the starting
        // orbit fails and is undone.
        let actions: [ScriptedAction] = [ScriptedAction("orbit.periapsis", [0, 0]), ScriptedAction("play.undo"),
                                         ScriptedAction("play.redo"), ScriptedAction("clock.show", [10]),
                                         ScriptedAction("play.undo"), ScriptedAction("orbit.play"),
                                         ScriptedAction("play.undo"), ScriptedAction("orbit.size", [20]),
                                         ScriptedAction("level.next"), ScriptedAction("clock.show", [5]),
                                         ScriptedAction("orbit.size", [16]), ScriptedAction("play.undo")]
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
        #expect(Core.experienceID == "r02-g18.apsides-workshop" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g18.apsides-workshop.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["orbit.periapsis", "orbit.size", "orbit.play", "play.undo", "play.redo", "level.next",
                             "clock.show"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[0].ranges == [0...15, 0...23])
        #expect(Core.controls[1].ranges == [8...48])
        #expect(Core.controls[6].ranges == [0...95])
        let plainIndices: [Int] = [2, 3, 4, 5]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.qualityTiers == ApsidesWorkshopTier.all.count)
        #expect(Core.migrations.currentVersion == 1)
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
        #expect(probe.apply(Self.act("level.next")) == .accepted && probe.levelNumber == 2)
        #expect(probe.play.stage == .playing && probe.play.actionsLeft == probe.play.level.budget)
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
    }

    @Test func levelNextWrapsAndResetReturns() async throws {
        var core: Core = try await Core.prepare(seed: 99)
        #expect(core.levelNumber == 100)
        let first: ApsidesWorkshopAction = try #require(try Core.generated(number: 100).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("clock.show", [30])) == .accepted)
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
        #expect(throws: ApsidesWorkshopRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: ApsidesWorkshopRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 20)
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
