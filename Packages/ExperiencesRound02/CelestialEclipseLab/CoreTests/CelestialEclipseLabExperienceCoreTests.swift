// CelestialEclipseLabExperienceCoreTests — feature 463 (R02-G17-03) T-R02G1703-005 (FR-R02G1703-005; SC-R02G1703-004;
// clarifications Q1, Q5). The adapter core: the shared conformance checks pass; the declared controls, ids, tiers and
// profile (the quality level names equal `CelestialEclipseLabTier.all`); the seed picks level `seed % 100 + 1`
// deterministically in stage `playing` with the default presentation (seeds 0, 1, 99 and 100 give levels 1, 2, 100
// and 1; the lowest-numbered movable body chosen, tick 0 shown); every control is accepted when legal and refused with
// the state unchanged otherwise (the engine's range checks, `r02-g17.not-whole`, `r02-g17.choice` for a body the level
// lacks, `r02-g17.tick` for a tick outside the horizon, and every kernel refusal the adapter can meet passing through
// with its code: `r02-g17.action` for an unknown or fixed body, an offset outside the period or equal to the current
// one and nothing to undo or redo, `r02-g17.budget` and `r02-g17.stage`; `stale` cannot arise because every action
// names the current fingerprint); undo restores the earlier digest exactly and redo the later one; `orbit.choose` and
// `clock.show` change the snapshot but never the digest, the play or the payload, a phase change, the run, undo and
// redo keep them, and `level.next`, reset and restore return them to the default; the certified plan of level 1 wins
// through the adapter and a run from the opening fails, undo returning the failed play to playing; `level.next` wraps
// 100 to 1 and reset returns; the snapshot round trip and refused payloads (damaged, level out of range, a trace of
// another level, a record of a newer schema, an edited trace, an envelope of a newer schema); the certified-candidate
// table equals the generator's search for three levels and the 100 stored witnesses' `skipped`; `snapshot(time:)`
// copies the play. Levels are certified once per process, so the run stays short. Explicit types, plain loops,
// single-literal comments.
import Foundation
import Testing
@testable import CelestialEclipseLabCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, CelestialEclipseLab, the
/// package, Packages).
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/celestial-eclipse-lab/levels", isDirectory: true)

/// Whether the stored witnesses are present (they are in the repository; an isolated copy of the package lacks them).
private let coreWitnessesPresent: Bool = FileManager.default.fileExists(
    atPath: coreWitnessDirectory.appendingPathComponent("001.witness.json").path)

@Suite struct CelestialEclipseLabExperienceCoreTests {
    typealias Core = CelestialEclipseLabExperienceCore

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
    static func act(_ action: CelestialEclipseLabAction) -> ExperienceAction {
        switch action {
        case let .phase(body, offset): act("orbit.phase", [Double(body), Double(offset)])
        case .run: act("clock.run")
        }
    }

    /// Whether `core` holds the default presentation: the lowest-numbered movable body chosen and tick 0 shown.
    static func holdsDefault(_ core: Core) -> Bool {
        core.chosenBody == CelestialEclipseLabSceneSnapshot.defaultChoice(core.play.level) && core.shownTick == 0
    }

    /// The stored witness of level `number`: its number, `skipped` and level fingerprint, read as plain JSON.
    static func storedWitness(_ number: Int) throws -> (number: Int, skipped: Int, fingerprint: String) {
        let name: String = String(CelestialEclipseLabGenerator.levelID(number).suffix(3)) + ".witness.json"
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
        // Levels 1 and 3 (then 2 and 4). Level 1's certified plan starts with body 1 to offset 2; the run from the
        // starting phases fails and is undone.
        let actions: [ScriptedAction] = [ScriptedAction("orbit.phase", [1, 2]), ScriptedAction("play.undo"),
                                         ScriptedAction("play.redo"), ScriptedAction("orbit.choose", [2]),
                                         ScriptedAction("clock.show", [10]), ScriptedAction("play.undo"),
                                         ScriptedAction("clock.run"), ScriptedAction("play.undo"),
                                         ScriptedAction("level.next"), ScriptedAction("orbit.choose", [0]),
                                         ScriptedAction("clock.show", [5]), ScriptedAction("orbit.phase", [1, 0]),
                                         ScriptedAction("play.undo")]
        // Refused on the openings of levels 1 and 3 (3 bodies, body 0 fixed, body 1 at phase 3 with period 8 or 4,
        // body 2 of period 4, horizons 29 and 25).
        let rejected: [ScriptedAction] = [ScriptedAction("orbit.phase", [0, 0]),
                                          ScriptedAction("orbit.phase", [3, 0]),
                                          ScriptedAction("orbit.phase", [5, 0]),
                                          ScriptedAction("orbit.phase", [6, 0]),
                                          ScriptedAction("orbit.phase", [-1, 0]),
                                          ScriptedAction("orbit.phase", [1, 24]),
                                          ScriptedAction("orbit.phase", [1, 8]),
                                          ScriptedAction("orbit.phase", [1, 3]),
                                          ScriptedAction("orbit.phase", [2, 4]),
                                          ScriptedAction("orbit.phase", [1, 0.5]),
                                          ScriptedAction("orbit.phase", [1.5, 0]),
                                          ScriptedAction("orbit.phase", [1]),
                                          ScriptedAction("orbit.choose", [3]),
                                          ScriptedAction("orbit.choose", [5]),
                                          ScriptedAction("orbit.choose", [6]),
                                          ScriptedAction("orbit.choose", [-1]),
                                          ScriptedAction("orbit.choose", [1.5]),
                                          ScriptedAction("orbit.choose", [1, 1]),
                                          ScriptedAction("clock.show", [29]),
                                          ScriptedAction("clock.show", [95]),
                                          ScriptedAction("clock.show", [96]),
                                          ScriptedAction("clock.show", [-1]),
                                          ScriptedAction("clock.show", [2.5]),
                                          ScriptedAction("clock.show"),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("clock.run", [1]), ScriptedAction("level.next", [1]),
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
        #expect(Core.experienceID == "r02-g17.celestial-eclipse-lab" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g17.celestial-eclipse-lab.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["orbit.phase", "clock.run", "play.undo", "play.redo", "level.next", "orbit.choose",
                             "clock.show"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[0].ranges == [0...5, 0...23])
        #expect(Core.controls[5].ranges == [0...5])
        #expect(Core.controls[6].ranges == [0...95])
        let plainIndices: [Int] = [1, 2, 3, 4]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.qualityTiers == CelestialEclipseLabTier.all.count)
        #expect(Core.migrations.currentVersion == 1)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == CelestialEclipseLabTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 0.5, 20.0 / 384.0] && iterations == [1, 0.5, 0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(CelestialEclipseLabExperienceRule.notWhole == "r02-g17.not-whole")
        #expect(CelestialEclipseLabExperienceRule.choice == "r02-g17.choice")
        #expect(CelestialEclipseLabExperienceRule.tick == "r02-g17.tick")
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
            let expected: CelestialEclipseLabLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.phases == expected.phases)
            // The tutorial (levels 1 … 3) is dismissed by the adapter: the play opens in stage playing.
            #expect(first.play.stage == .playing && first.outcome == nil && first.play.failure == nil)
            let opening: Int = expected.tutorial ? 2 : 1
            #expect(first.play.records.count == opening && !first.play.canUndo)
            #expect(first.play.actionsLeft == expected.budget && first.qualityTier == 0)
            #expect(Self.holdsDefault(first) && !expected.bodies[first.chosenBody].fixed)
        }
        // Level 1: body 0 is fixed, so body 1 is chosen.
        let one: Core = try await Core.prepare(seed: 0)
        #expect(one.chosenBody == 1 && one.shownTick == 0 && one.play.level.bodies[0].fixed)
        #expect(try Core.level(number: 1).tutorial && !(try Core.level(number: 100).tutorial))
        #expect(throws: CelestialEclipseLabError.level("number")) { try Core.level(number: 0) }
        #expect(throws: CelestialEclipseLabError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableEqualsTheGeneratorsSearch() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for value in Core.certifiedCandidates {
            #expect(value >= 0 && value < CelestialEclipseLabGenerator.maxCandidates)
        }
        // Three levels re-derived by the generator's whole search after their certified neighbour (levels 7 and 48
        // skip 2 and 3 candidates).
        let numbers: [Int] = [1, 7, 48]
        for number in numbers {
            let entry: CelestialEclipseLabManifestEntry = CelestialEclipseLabManifest.entries[number - 1]
            var previous: CelestialEclipseLabLevel? = nil
            if number > 1 { previous = try Core.level(number: number - 1) }
            let searched: CelestialEclipseLabGenerated = try CelestialEclipseLabGenerator.generate(entry,
                                                                                                   previous: previous)
            #expect(searched.skipped == Core.certifiedCandidates[number - 1], "a table entry differs")
            let direct: CelestialEclipseLabGenerated = try Core.generated(number: number)
            #expect(direct == searched, "the direct certification differs from the generator")
            #expect(direct.entry == entry && direct.level.id == CelestialEclipseLabGenerator.levelID(number))
        }
        #expect(Core.certifiedCandidates[6] == 2 && Core.certifiedCandidates[47] == 3)
        #expect(Core.certifiedCandidates[93] == 4)
    }

    @Test(.enabled(if: coreWitnessesPresent, "needs the stored witnesses, docs/games/celestial-eclipse-lab/levels"))
    func theCandidateTableEqualsTheStoredWitnesses() throws {
        for number in 1...100 {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            #expect(witness.number == number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "a table entry differs")
        }
        // Directly certified levels equal the stored witness levels.
        let numbers: [Int] = [1, 7, 21, 100]
        for number in numbers {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            let generated: CelestialEclipseLabGenerated = try Core.generated(number: number)
            #expect(generated.level.fingerprint == witness.fingerprint, "a level fingerprint differs")
            #expect(generated.skipped == witness.skipped)
        }
    }

    @Test func theCertifiedPlanOfLevelOneWinsThroughTheAdapter() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let generated: CelestialEclipseLabGenerated = try Core.generated(number: 1)
        #expect(generated.plan.actions == [.phase(1, 2), .phase(2, 0)])
        #expect(core.apply(Self.act("orbit.choose", [2])) == .accepted)
        #expect(core.apply(Self.act("clock.show", [11])) == .accepted)
        for step in generated.plan.actions {
            #expect(core.apply(Self.act(step)) == .accepted)
            #expect(core.chosenBody == 2 && core.shownTick == 11, "a phase change keeps the presentation")
        }
        #expect(core.apply(Self.act("clock.run")) == .accepted)
        #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
        #expect(core.play.failure == nil && core.play.timeline.wins)
        #expect(core.play.actionsLeft == core.play.level.budget - generated.plan.size)
        #expect(core.snapshot(time: 0).isWon && core.chosenBody == 2 && core.shownTick == 11)
        // A won play is final: a phase change, the run, undo and redo are the kernel's stage refusal; choosing and
        // showing are still accepted.
        let stage: ActionResult = .rejected(.rule(code: "r02-g17.stage"))
        #expect(core.apply(Self.act("orbit.phase", [1, 0])) == stage)
        #expect(core.apply(Self.act("clock.run")) == stage)
        #expect(core.apply(Self.act("play.undo")) == stage)
        #expect(core.apply(Self.act("play.redo")) == stage)
        #expect(core.apply(Self.act("orbit.choose", [0])) == .accepted)
        #expect(core.apply(Self.act("clock.show", [28])) == .accepted)
        #expect(core.chosenBody == 0 && core.shownTick == 28)
    }

    @Test func aRunFromTheOpeningFailsAndUndoReturnsToPlaying() async throws {
        // Level 1's minimal plan has two changes, so the starting phases (and any single change) do not win.
        var core: Core = try await Core.prepare(seed: 0)
        let openingDigest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("clock.show", [4])) == .accepted)
        #expect(core.apply(Self.act("clock.run")) == .accepted)
        #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode)
        let failure: CelestialEclipseLabFailure = try #require(core.play.failure)
        #expect(core.play.level.startTimeline.failure == failure && core.play.actionsLeft == core.play.level.budget)
        let snapshot: CelestialEclipseLabSceneSnapshot = core.snapshot(time: 0)
        #expect(snapshot.failure == failure && snapshot.stage == .failed && snapshot.shownTick == 4)
        let stage: ActionResult = .rejected(.rule(code: "r02-g17.stage"))
        #expect(core.apply(Self.act("orbit.phase", [1, 2])) == stage)
        #expect(core.apply(Self.act("clock.run")) == stage)
        #expect(core.apply(Self.act("play.redo")) == stage)
        #expect(core.apply(Self.act("orbit.choose", [2])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.play.stage == .playing && core.outcome == nil && core.play.failure == nil)
        #expect(core.chosenBody == 2 && core.shownTick == 4)
        #expect(try Self.digest(core) == openingDigest)
        // A single change then the run fails too.
        #expect(core.apply(Self.act("orbit.phase", [1, 2])) == .accepted)
        #expect(core.apply(Self.act("clock.run")) == .accepted && core.play.stage == .failed)
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: 3 bodies (body 0 fixed with period 7, body 1 at phase 3 of 8, body 2 at phase 2 of 4), horizon 29,
        // budget 9.
        let core: Core = try await Core.prepare(seed: 0)
        let level: CelestialEclipseLabLevel = core.play.level
        #expect(level.bodies.count == 3 && level.horizon == 29 && level.budget == 9)
        #expect(level.bodies.map(\.period) == [7, 8, 4] && core.play.phases == [4, 3, 2])
        let opening: StateDigest = try Self.digest(core)
        let records: Int = core.play.records.count
        let illegal: [ExperienceAction] = [Self.act("orbit.phase", [0, 0]), Self.act("orbit.phase", [3, 0]),
                                           Self.act("orbit.phase", [5, 0]), Self.act("orbit.phase", [6, 0]),
                                           Self.act("orbit.phase", [-1, 0]), Self.act("orbit.phase", [1, 24]),
                                           Self.act("orbit.phase", [1, 8]), Self.act("orbit.phase", [1, 3]),
                                           Self.act("orbit.phase", [2, 4]), Self.act("orbit.phase", [1, 0.5]),
                                           Self.act("orbit.phase", [1.5, 0]), Self.act("orbit.phase", [.nan, 0]),
                                           Self.act("orbit.phase", [1]), Self.act("orbit.phase"),
                                           Self.act("orbit.phase", [1, 2, 0]), Self.act("orbit.choose", [3]),
                                           Self.act("orbit.choose", [5]), Self.act("orbit.choose", [6]),
                                           Self.act("orbit.choose", [-1]), Self.act("orbit.choose", [1.5]),
                                           Self.act("orbit.choose", [.infinity]), Self.act("orbit.choose"),
                                           Self.act("clock.show", [29]), Self.act("clock.show", [95]),
                                           Self.act("clock.show", [96]), Self.act("clock.show", [-1]),
                                           Self.act("clock.show", [2.5]), Self.act("clock.show", [1, 1]),
                                           Self.act("play.undo"), Self.act("play.redo"),
                                           Self.act("play.undo", [1]), Self.act("clock.run", [1]),
                                           Self.act("level.next", [1]), Self.act("nope")]
        for action in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(action)
            #expect(!result.isAccepted, "an illegal action was accepted")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.count == records, "a refusal changed it")
            #expect(copy.chosenBody == core.chosenBody && copy.shownTick == core.shownTick)
        }
        var probe: Core = core
        // Outside the declared ranges or the value count: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.act("orbit.phase", [6, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("orbit.phase", [-1, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("orbit.phase", [1, 24])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("orbit.choose", [6])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("clock.show", [96])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("clock.show", [-1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("orbit.phase", [.nan, 0])) == .rejected(.nonFinite(index: 0)))
        #expect(probe.apply(Self.act("orbit.phase", [1])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("orbit.choose")) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(probe.apply(Self.act("clock.show", [1, 1])) == .rejected(.wrongValueCount(expected: 1, found: 2)))
        let noValues: ActionResult = .rejected(.wrongValueCount(expected: 0, found: 1))
        #expect(probe.apply(Self.act("clock.run", [1])) == noValues)
        #expect(probe.apply(Self.act("play.undo", [1])) == noValues)
        #expect(probe.apply(Self.act("play.redo", [1])) == noValues)
        #expect(probe.apply(Self.act("level.next", [1])) == noValues)
        let notWhole: ActionResult = .rejected(.rule(code: CelestialEclipseLabExperienceRule.notWhole))
        #expect(probe.apply(Self.act("orbit.phase", [1, 0.5])) == notWhole)
        #expect(probe.apply(Self.act("orbit.phase", [1.5, 0])) == notWhole)
        #expect(probe.apply(Self.act("orbit.choose", [1.5])) == notWhole)
        #expect(probe.apply(Self.act("clock.show", [2.5])) == notWhole)
        // A body the level lacks, a tick past the horizon: the adapter's refusals.
        let choice: ActionResult = .rejected(.rule(code: CelestialEclipseLabExperienceRule.choice))
        #expect(probe.apply(Self.act("orbit.choose", [3])) == choice)
        #expect(probe.apply(Self.act("orbit.choose", [5])) == choice)
        let tick: ActionResult = .rejected(.rule(code: CelestialEclipseLabExperienceRule.tick))
        #expect(probe.apply(Self.act("clock.show", [29])) == tick)
        #expect(probe.apply(Self.act("clock.show", [95])) == tick)
        // The kernel's refusals pass through with their codes.
        let action: ActionResult = .rejected(.rule(code: "r02-g17.action"))
        #expect(probe.apply(Self.act("orbit.phase", [0, 0])) == action)
        #expect(probe.apply(Self.act("orbit.phase", [3, 0])) == action)
        #expect(probe.apply(Self.act("orbit.phase", [5, 0])) == action)
        #expect(probe.apply(Self.act("orbit.phase", [1, 8])) == action)
        #expect(probe.apply(Self.act("orbit.phase", [1, 3])) == action)
        #expect(probe.apply(Self.act("orbit.phase", [2, 4])) == action)
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe == core && probe.play.records.count == records && Self.holdsDefault(probe))
        // Every legal choice and tick is accepted (the fixed body included) and changes nothing else.
        for body in 0..<level.bodies.count {
            #expect(probe.apply(Self.act("orbit.choose", [Double(body)])) == .accepted && probe.chosenBody == body)
        }
        for shown in 0..<level.horizon {
            #expect(probe.apply(Self.act("clock.show", [Double(shown)])) == .accepted && probe.shownTick == shown)
        }
        #expect(try Self.digest(probe) == opening && probe == core)
        // Every legal action is accepted; a phase change, undo, redo and the run keep the presentation.
        #expect(probe.apply(Self.act("orbit.choose", [2])) == .accepted)
        #expect(probe.apply(Self.act("clock.show", [7])) == .accepted)
        #expect(probe.apply(Self.act("orbit.phase", [1, 2])) == .accepted && probe.play.actionsLeft == 8)
        #expect(probe.play.phases == [4, 2, 2] && probe.chosenBody == 2 && probe.shownTick == 7)
        #expect(probe.apply(Self.act("play.undo")) == .accepted && probe.play.actionsLeft == 9)
        #expect(probe.chosenBody == 2 && probe.shownTick == 7)
        #expect(probe.apply(Self.act("play.redo")) == .accepted && probe.play.actionsLeft == 8)
        #expect(probe.chosenBody == 2 && probe.shownTick == 7)
        // A refused phase change keeps the presentation.
        #expect(probe.apply(Self.act("orbit.phase", [1, 2])) == action)
        #expect(probe.chosenBody == 2 && probe.shownTick == 7)
        #expect(probe.apply(Self.act("level.next")) == .accepted && probe.levelNumber == 2)
        #expect(probe.play.stage == .playing && probe.play.actionsLeft == probe.play.level.budget)
        #expect(Self.holdsDefault(probe))
    }

    @Test func theBudgetRefusesAPhaseChangeButNotTheRun() async throws {
        // Level 1, budget 9: body 2 (period 4, phase 2) alternates between offsets 0 and 1.
        var core: Core = try await Core.prepare(seed: 0)
        for change in 0..<9 {
            #expect(core.apply(Self.act("orbit.phase", [2, Double(change % 2)])) == .accepted)
        }
        #expect(core.play.actionsLeft == 0)
        let before: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("orbit.phase", [2, 3])) == .rejected(.rule(code: "r02-g17.budget")))
        #expect(try Self.digest(core) == before)
        #expect(core.apply(Self.act("clock.run")) == .accepted)
        #expect(core.play.stage == .won || core.play.stage == .failed)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLaterOne() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let records: Int = core.play.records.count
        #expect(core.apply(Self.act("orbit.phase", [1, 2])) == .accepted)
        let afterChange: StateDigest = try Self.digest(core)
        #expect(afterChange != opening)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening && core.play.records.count == records + 2)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(try Self.digest(core) == afterChange && core.play.records.count == records + 3)
        // A new change after an undo (the same one again) clears the redo stack.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("orbit.phase", [1, 2])) == .accepted)
        #expect(try Self.digest(core) == afterChange)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g17.action")))
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
        // The run is undone and redone exactly as well.
        #expect(core.apply(Self.act("clock.run")) == .accepted)
        let afterRun: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(try Self.digest(core) == afterRun)
    }

    @Test func choosingAndShowingChangeTheSnapshotButNeverTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let before: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let play: CelestialEclipseLabPlay = core.play
        var snapshots: [CelestialEclipseLabSceneSnapshot] = []
        for body in 0..<play.level.bodies.count {
            #expect(core.apply(Self.act("orbit.choose", [Double(body)])) == .accepted)
            let snapshot: CelestialEclipseLabSceneSnapshot = core.snapshot(time: 1)
            #expect(snapshot.chosenBody == body && snapshot.phases == play.phases)
            #expect(try Self.digest(core) == before && core.play == play)
            #expect(try core.snapshotPayload() == payload)
            snapshots.append(snapshot)
        }
        for shown in 1..<play.level.horizon {
            #expect(core.apply(Self.act("clock.show", [Double(shown)])) == .accepted)
            let snapshot: CelestialEclipseLabSceneSnapshot = core.snapshot(time: 1)
            #expect(snapshot.shownTick == shown && snapshot.intervals == play.timeline.intervals)
            #expect(try Self.digest(core) == before && core.play == play)
            #expect(try core.snapshotPayload() == payload)
            snapshots.append(snapshot)
        }
        #expect(snapshots.count == 3 + 28)
        for index in 1..<snapshots.count { #expect(snapshots[index] != snapshots[index - 1]) }
        // A refused choice or tick keeps the current one.
        let chosen: (body: Int, tick: Int) = (core.chosenBody, core.shownTick)
        #expect(core.apply(Self.act("orbit.choose", [4])) == .rejected(.rule(code: "r02-g17.choice")))
        #expect(core.apply(Self.act("clock.show", [40])) == .rejected(.rule(code: "r02-g17.tick")))
        #expect(core.chosenBody == chosen.body && core.snapshot(time: 1).shownTick == chosen.tick)
        // Reset, restore and level.next return to the default.
        var reset: Core = core
        reset.reset()
        let opened: Core = try Core.opening(number: 1)
        #expect(Self.holdsDefault(reset) && reset == opened)
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && Self.holdsDefault(restored))
        var next: Core = core
        #expect(next.apply(Self.act("level.next")) == .accepted)
        #expect(Self.holdsDefault(next))
    }

    @Test func levelNextWrapsAndResetReturns() async throws {
        var core: Core = try await Core.prepare(seed: 99)
        #expect(core.levelNumber == 100)
        let first: CelestialEclipseLabAction = try #require(try Core.generated(number: 100).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 1 && core.play.stage == .playing && !core.play.canUndo)
        #expect(core.play.level == (try Core.level(number: 1)))
        #expect(Self.holdsDefault(core))
        core.setQualityTier(2)
        core.reset()
        #expect(core.levelNumber == 100 && !core.play.canUndo && core.qualityTier == 2)
        let fresh: Core = try await Core.prepare(seed: 99)
        #expect(core == fresh)
        #expect(try Self.digest(core) == Self.digest(fresh))
        #expect(core.chosenBody == fresh.chosenBody && core.shownTick == fresh.shownTick)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        // Level 21 after a change, an undo, a redo and an undo.
        var core: Core = try await Core.prepare(seed: 20)
        let first: CelestialEclipseLabAction = try #require(try Core.generated(number: 21).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("orbit.choose", [2])) == .accepted)
        #expect(core.apply(Self.act("clock.show", [6])) == .accepted)
        let savedDigest: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let text: String = String(decoding: payload, as: UTF8.self)
        #expect(text.hasPrefix("{\"level\":21,\"records\":["))
        let restored: Core = try Core.restore(payload: payload, seed: 20)
        let restoredDigest: StateDigest = try Self.digest(restored)
        #expect(restored == core && restoredDigest == savedDigest)
        #expect(restored.play.canRedo && restored.openingNumber == 21 && Self.holdsDefault(restored))
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
        // A finished run round-trips too.
        var failed: Core = try await Core.prepare(seed: 20)
        #expect(failed.apply(Self.act("clock.run")) == .accepted && failed.play.stage == .failed)
        let failedRestored: Core = try Core.restore(payload: try failed.snapshotPayload(), seed: 20)
        #expect(failedRestored == failed && failedRestored.outcome?.code == Core.failedCode)
        // Refusals.
        #expect(throws: CelestialEclipseLabRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 20)
        }
        #expect(throws: CelestialEclipseLabRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 20)
        }
        #expect(throws: CelestialEclipseLabRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"21\",\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: CelestialEclipseLabRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: CelestialEclipseLabRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 20)
        }
        // A trace of level 21 restored as level 22 (another seed).
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "{\"level\":21,", with: "{\"level\":22,").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: CelestialEclipseLabRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: wrongLevel, seed: 20)
        }
        // A record of a newer schema.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: CelestialEclipseLabRestoreRefusal.kernel(.malformed("schema 0"))) {
            try Core.restore(payload: newer, seed: 20)
        }
        // An edited trace: the first record's index changed.
        let edited: Data = Data(text.replacingOccurrences(of: "\"index\":0,", with: "\"index\":3,").utf8)
        #expect(edited != payload)
        #expect(throws: CelestialEclipseLabRestoreRefusal.kernel(.malformed("index 0"))) {
            try Core.restore(payload: edited, seed: 20)
        }
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        // Level 1: the first change of its certified plan.
        #expect(engine.handle(control: "orbit.phase", values: [1, 2]) == .accepted)
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
        // Level 41 after the first change of its certified plan, body 3 chosen and tick 9 shown.
        var core: Core = try await Core.prepare(seed: 40)
        let first: CelestialEclipseLabAction = try #require(try Core.generated(number: 41).plan.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("orbit.choose", [3])) == .accepted)
        #expect(core.apply(Self.act("clock.show", [9])) == .accepted)
        let play: CelestialEclipseLabPlay = core.play
        let level: CelestialEclipseLabLevel = play.level
        let snapshot: CelestialEclipseLabSceneSnapshot = core.snapshot(time: 2.5)
        #expect(snapshot.bodies == level.bodies && snapshot.phases == play.phases && snapshot.target == level.target)
        var positions: [CelestialEclipseLabVector] = []
        for (index, body) in level.bodies.enumerated() {
            positions.append(body.position(at: 9, phase: play.phases[index]))
        }
        #expect(snapshot.positions == positions)
        let eclipses: [CelestialEclipseLabEclipse] = CelestialEclipseLabSceneSnapshot.eclipses(
            level, phases: play.phases, tick: 9)
        #expect(snapshot.eclipses == eclipses)
        #expect(snapshot.intervals == play.timeline.intervals && snapshot.matched == play.timeline.matched)
        #expect(snapshot.failure == play.timeline.failure && snapshot.stage == play.stage)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.horizon == level.horizon && snapshot.shownTick == 9 && snapshot.chosenBody == 3)
        #expect(snapshot.levelNumber == 41 && snapshot.time == 2.5)
        #expect(core.renderTier == CelestialEclipseLabTier.of(0))
    }
}
