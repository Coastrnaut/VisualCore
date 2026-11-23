// HarmonicBridgesExperienceCoreTests — feature 413 (R02-G12-03) T-R02G1203-005 (FR-R02G1203-003, 005; clarifications
// Q4, Q5). The adapter core: the shared conformance checks pass; the declared controls, ids, tiers and profile; the seed
// picks level `seed % 100 + 1` deterministically in stage `playing` (seeds 0, 1, 99 and 100 give levels 1, 2, 100 and
// 1); every control is accepted when legal and refused with the state unchanged otherwise (the engine's range checks,
// `r02-g12.not-whole`, and every kernel refusal the adapter can meet passing through with its code: `r02-g12.action`
// for a string the level lacks, a locked string and nothing to undo or redo, `noop` and `stage`; `stale` cannot arise
// because every tuning and test names the current fingerprint); undo restores the earlier digest exactly and redo the
// later one; the certified witness wins, a broken test and a spent budget fail, undo returns a failed play to playing;
// `level.next` wraps 100 to 1 and reset returns; the snapshot round trip and refused payloads (damaged, level out of
// range, a trace of another level, a record of a newer schema, an edited trace, an envelope of a newer schema); the
// certified-candidate table equals the 100 stored witnesses' `skipped` and the directly certified levels equal the
// stored ones (level fingerprint); `snapshot(time:)` copies the play and the kernel's exact report.
// Feature 415 (R02-G12-05) T-R02G1205-004: schema 2 and digest v2; ten controls; `level.next` to the next open level
// (refused with `r02-g12.locked` when none, no wrap); the progression controls (`level.select`, `mode.daily`,
// `mode.practice`, `mode.campaign`, `tutorial.dismiss`) with their refusals; a campaign win records the least actions
// spent and stars and opens the next level, a daily win records and opens nothing, practice (budget 60 on a copy of the
// level) records nothing; progress and mode in the digest, the tutorial step in the snapshot but not the digest; the
// tutorial's steps; the schema-2 round trip in every mode, its refused payloads and the migration of a schema-1
// payload; a newer schema refused. Fixture seed 2_413.
// Levels are certified once per process, so the run stays short. Explicit types, plain loops.
import Foundation
import Testing
@testable import HarmonicBridgesCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/harmonic-bridges/levels", isDirectory: true)

@Suite struct HarmonicBridgesExperienceCoreTests {
    typealias Core = HarmonicBridgesExperienceCore

    /// The fixture seed of this feature.
    static let fixtureSeed: UInt64 = 2_413

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
    static func act(_ action: HarmonicBridgesAction) -> ExperienceAction {
        switch action {
        case let .tune(string, peg): act("string.tune", [Double(string), Double(peg)])
        case .test: act("crossing.test")
        }
    }

    /// The stored witness of level `number`, read with the plain decoder.
    static func storedWitness(_ number: Int) throws -> HarmonicBridgesWitness {
        let name: String = String(HarmonicBridgesGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: coreWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(HarmonicBridgesWitness.self, from: data)
    }

    /// The first unlocked string of `level`.
    static func unlockedString(_ level: HarmonicBridgesLevel) -> Int? {
        for (index, string) in level.strings.enumerated() where !string.locked { return index }
        return nil
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 3 (then 2 and 4): string 0 is unlocked in both (pegs 11 and 8), string 1 in levels 2 and 4
        // (pegs 12 and 5). No action ends a play (tunings within the budgets of 9 and 11; no test).
        let actions: [ScriptedAction] = [ScriptedAction("string.tune", [0, 3]), ScriptedAction("string.tune", [0, 4]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("string.tune", [0, 5]), ScriptedAction("play.undo"),
                                         ScriptedAction("level.next"), ScriptedAction("string.tune", [1, 3])]
        // Refused on the openings of levels 1 and 3 (1 and 3 strings).
        let rejected: [ScriptedAction] = [ScriptedAction("string.tune", [12, 1]),
                                          ScriptedAction("string.tune", [0, 0]),
                                          ScriptedAction("string.tune", [0, 13]),
                                          ScriptedAction("string.tune", [0.5, 1]),
                                          ScriptedAction("string.tune", [0]),
                                          ScriptedAction("string.tune", [5, 1]),
                                          ScriptedAction("crossing.test", [1]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 2], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g12.harmonic-bridges" && Core.schemaVersion == 2)
        #expect(Core.digestDomain == "r02-g12.harmonic-bridges.v2")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["string.tune", "crossing.test", "play.undo", "play.redo", "level.next",
                             "level.select", "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[0].ranges == [0...11, 1...12])
        let plainIndices: [Int] = [1, 2, 3, 4, 7, 8, 9]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.controls[5].ranges == [1...100])
        #expect(Core.controls[6].ranges == [1...9999, 1...12, 1...31])
        #expect(Core.qualityTiers == 3 && Core.migrations.currentVersion == 2)
        #expect(Core.practiceBudget == 60)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == HarmonicBridgesTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 0.5, 0] && iterations == [1, 0.5, 0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(HarmonicBridgesExperienceRule.notWhole == "r02-g12.not-whole")
        #expect(HarmonicBridgesExperienceRule.locked == "r02-g12.locked")
        #expect(HarmonicBridgesExperienceRule.date == "r02-g12.date")
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
            let expected: HarmonicBridgesLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.pegs == expected.startingPegs)
            // The tutorial (levels 1 … 3) is dismissed by the adapter: the play opens in stage playing.
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.play.actionsLeft == expected.budget && first.qualityTier == 0)
        }
        #expect(try Core.level(number: 1).tutorial && !(try Core.level(number: 100).tutorial))
        #expect(Core.levelNumber(forSeed: Self.fixtureSeed) == 14)
        #expect(throws: HarmonicBridgesError.level("number")) { try Core.level(number: 0) }
        #expect(throws: HarmonicBridgesError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableEqualsTheWitnessesAndCertifiesTheStoredLevels() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for number in 1...100 {
            let witness: HarmonicBridgesWitness = try Self.storedWitness(number)
            #expect(witness.number == number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "level \(number)")
        }
        // Directly certified levels equal the stored witness levels and actions.
        let numbers: [Int] = [1, 2, 49, 100]
        for number in numbers {
            let witness: HarmonicBridgesWitness = try Self.storedWitness(number)
            let generated: HarmonicBridgesGenerated = try Core.generated(number: number)
            #expect(generated.level.fingerprint == witness.level.fingerprint, "level \(number)")
            #expect(generated.level == witness.level && generated.actions == witness.actions)
            #expect(generated.skipped == witness.skipped && generated.difficulty == witness.difficulty)
            #expect(generated.entry == HarmonicBridgesManifest.entries[number - 1])
            // The candidate just before the certified one does not certify (the generator skipped it).
            if witness.skipped > 0 {
                let entry: HarmonicBridgesManifestEntry = HarmonicBridgesManifest.entries[number - 1]
                #expect(Core.certify(entry, index: witness.skipped - 1) == nil, "level \(number)")
            }
        }
        // The generator itself gives the same level as the direct certification.
        let entry: HarmonicBridgesManifestEntry = HarmonicBridgesManifest.entries[1]
        #expect(try HarmonicBridgesGenerator.generate(entry) == Core.generated(number: 2))
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: one unlocked string (0) at peg 11, budget 9; the witness tunes it to 12 and tests.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.play.level.strings.count == 1 && core.play.pegs == [11] && core.play.level.budget == 9)
        let opening: StateDigest = try Self.digest(core)
        let illegal: [ExperienceAction] = [Self.act("string.tune", [12, 1]), Self.act("string.tune", [-1, 1]),
                                           Self.act("string.tune", [0, 0]), Self.act("string.tune", [0, 13]),
                                           Self.act("string.tune", [0.5, 2]), Self.act("string.tune", [0, .nan]),
                                           Self.act("string.tune", [0]), Self.act("string.tune", [0, 1, 2]),
                                           Self.act("string.tune", [1, 3]), Self.act("string.tune", [0, 11]),
                                           Self.act("crossing.test", [1]), Self.act("play.undo"),
                                           Self.act("play.redo"), Self.act("play.undo", [1]),
                                           Self.act("level.next", [1]), Self.act("nope")]
        for action in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(action)
            #expect(!result.isAccepted, "\(action.control) \(action.values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.isEmpty, "\(action.control)")
        }
        var probe: Core = core
        // Outside the declared ranges or the value count: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.act("string.tune", [12, 1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("string.tune", [-1, 1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("string.tune", [0, 0])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("string.tune", [0, 13])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("string.tune", [0, .nan])) == .rejected(.nonFinite(index: 1)))
        #expect(probe.apply(Self.act("string.tune", [0])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("crossing.test", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("play.undo", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("level.next", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        let notWhole: ActionResult = .rejected(.rule(code: HarmonicBridgesExperienceRule.notWhole))
        #expect(probe.apply(Self.act("string.tune", [0.5, 2])) == notWhole)
        #expect(probe.apply(Self.act("string.tune", [0, 2.25])) == notWhole)
        // Every kernel refusal the adapter can meet passes through with its reason code.
        let action: ActionResult = .rejected(.rule(code: HarmonicBridgesError.action("string").reasonCode))
        let noop: ActionResult = .rejected(.rule(code: HarmonicBridgesError.noop.reasonCode))
        let stage: ActionResult = .rejected(.rule(code: HarmonicBridgesError.stage.reasonCode))
        #expect(action == .rejected(.rule(code: "r02-g12.action")) && noop == .rejected(.rule(code: "r02-g12.noop")))
        #expect(stage == .rejected(.rule(code: "r02-g12.stage")))
        #expect(probe.apply(Self.act("string.tune", [1, 3])) == action)     // a string level 1 lacks
        #expect(probe.apply(Self.act("string.tune", [11, 3])) == action)    // a string level 1 lacks
        #expect(probe.apply(Self.act("string.tune", [0, 11])) == noop)      // the current peg
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe.apply(Self.act("nope")) == .rejected(.unknownControl("nope")))
        #expect(probe == core)

        // A tuning spends one action and changes the peg.
        #expect(core.apply(Self.act("string.tune", [0, 3])) == .accepted)
        #expect(core.play.pegs == [3] && core.play.actionsLeft == 8 && core.play.records.count == 1)
        #expect(core.play.stage == .playing && core.outcome == nil)
        #expect(try Self.digest(core) != opening)

        // The locked refusal: level 2's string 0 is locked.
        var locked: Core = try Core.opening(number: 2)
        #expect(locked.play.level.strings[0].locked)
        let lockedOpening: Core = locked
        #expect(locked.apply(Self.act("string.tune", [0, 3])) == action)
        #expect(locked == lockedOpening)

        // The stage refusal: a won play refuses everything but level.next.
        var won: Core = try Core.opening(number: 1)
        let generated: HarmonicBridgesGenerated = try Core.generated(number: 1)
        for step in generated.actions { #expect(won.apply(Self.act(step)) == .accepted) }
        #expect(won.play.stage == .won && won.outcome?.code == Core.wonCode)
        let final: Core = won
        #expect(won.apply(Self.act("string.tune", [0, 3])) == stage)
        #expect(won.apply(Self.act("crossing.test")) == stage)
        #expect(won.apply(Self.act("play.undo")) == stage)
        #expect(won.apply(Self.act("play.redo")) == stage)
        #expect(won == final)
        #expect(won.apply(Self.act("level.next")) == .accepted)
        #expect(won.levelNumber == 2 && won.play.stage == .playing)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 2)
        let startDigest: StateDigest = try Self.digest(core)
        let start: HarmonicBridgesPlay = core.play
        // Level 3: three unlocked strings at pegs 8, 1 and 5, budget 11.
        let steps: [ExperienceAction] = [Self.act("string.tune", [0, 3]), Self.act("string.tune", [1, 7]),
                                         Self.act("string.tune", [2, 9])]
        for step in steps { #expect(core.apply(step) == .accepted) }
        let moved: Core = core
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest && core.play.stage == .playing && core.play.pegs == [3, 7, 9])
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(core.play.pegs == start.pegs && core.play.actionsLeft == start.actionsLeft)
        #expect(core.play.report == start.report && core.play.stage == .playing)
        #expect(try Self.digest(core) == startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.redo")) == .accepted) }
        #expect(core.play.pegs == moved.play.pegs && core.play.actionsLeft == moved.play.actionsLeft)
        #expect(core.play.records.count == 9)
        #expect(try Self.digest(core) == movedDigest)
        // A new action clears the redo history.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("string.tune", [2, 10])) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g12.action")))
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(try Self.digest(core) == startDigest)
    }

    @Test func theWitnessWinsBrokenTestsAndSpentBudgetsFailAndUndoRetries() async throws {
        let numbers: [Int] = [1, 21, 41]
        let stageCode: ActionResult = .rejected(.rule(code: "r02-g12.stage"))
        for number in numbers {
            let generated: HarmonicBridgesGenerated = try Core.generated(number: number)
            let level: HarmonicBridgesLevel = generated.level
            var core: Core = try Core.opening(number: number)
            let before: StateDigest = try Self.digest(core)

            // A test at the starting pegs breaks (the certified plan needs at least one tuning).
            var broken: Core = core
            #expect(broken.apply(Self.act("crossing.test")) == .accepted)
            let expectedBreak: HarmonicBridgesBreak = try #require(level.firstBreak(core.play.report))
            let brokenFailure: HarmonicBridgesFailure = .broken(step: expectedBreak.step, string: expectedBreak.string)
            #expect(broken.play.stage == .failed && broken.play.failure == brokenFailure, "level \(number)")
            #expect(broken.outcome?.code == Core.failedCode && broken.play.actionsLeft == level.budget - 1)
            #expect(broken.apply(Self.act("play.undo")) == .accepted)
            #expect(broken.play.stage == .playing && broken.outcome == nil)
            #expect(try Self.digest(broken) == before)

            // Tunings back and forth on an unlocked string spend the budget: failed on the last one.
            var failing: Core = core
            let string: Int = try #require(Self.unlockedString(level))
            let current: Int = level.strings[string].peg
            let first: Int = current == 1 ? 2 : 1
            let second: Int = current == 3 ? 4 : 3
            var count: Int = 0
            while failing.play.stage == .playing && count < 64 {
                let peg: Int = count % 2 == 0 ? first : second
                #expect(failing.apply(Self.act("string.tune", [Double(string), Double(peg)])) == .accepted)
                count += 1
            }
            #expect(count == level.budget, "level \(number)")
            #expect(failing.play.stage == .failed && failing.play.failure == .budget(count - 1), "level \(number)")
            #expect(failing.play.actionsLeft == 0 && failing.outcome?.code == Core.failedCode)
            let failedSnapshot: HarmonicBridgesSceneSnapshot = failing.snapshot(time: 0)
            #expect(failedSnapshot.stage == .failed && failedSnapshot.failure == .budget(count - 1))
            #expect(failedSnapshot.actionsLeft == 0 && failedSnapshot.budget == level.budget)
            let failed: Core = failing
            #expect(failing.apply(Self.act("string.tune", [Double(string), Double(current)])) == stageCode)
            #expect(failing.apply(Self.act("crossing.test")) == stageCode)
            #expect(failing.apply(Self.act("play.redo")) == stageCode)
            #expect(failing == failed)
            #expect(failing.apply(Self.act("play.undo")) == .accepted)
            #expect(failing.play.stage == .playing && failing.outcome == nil)
            while failing.play.canUndo { #expect(failing.apply(Self.act("play.undo")) == .accepted) }
            #expect(try Self.digest(failing) == before)

            // The certified witness: won on its last action (the test).
            for step in generated.actions { #expect(core.apply(Self.act(step)) == .accepted) }
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "level \(number)")
            #expect(core.play.report.goalReachedInEveryStep && core.play.failure == nil)
            #expect(core.apply(Self.act("level.next")) == .accepted)
            let next: Int = number % 100 + 1
            #expect(core.play.stage == .playing && core.levelNumber == next && core.outcome == nil)
            core.reset()
            #expect(core.levelNumber == number && core.play.records.isEmpty && core.play.stage == .playing)
        }
    }

    @Test func nextLevelOpensOnlyAfterAWinAndResetReturnsToTheSeedsLevel() async throws {
        let locked: ActionResult = .rejected(.rule(code: HarmonicBridgesExperienceRule.locked))
        var core: Core = try await Core.prepare(seed: 40)
        #expect(core.levelNumber == 41 && core.progress.frontier == 41 && core.progress.solved.isEmpty)
        #expect(core.apply(Self.act("string.tune", [0, 12])) == .accepted)
        // Feature 415: level 42 is not open yet, so level.next is refused and changes nothing.
        let before: StateDigest = try Self.digest(core)
        let unchanged: Core = core
        #expect(core.apply(Self.act("level.next")) == locked)
        #expect(try Self.digest(core) == before)
        #expect(core == unchanged)
        core.reset()
        for step in try Core.generated(number: 41).actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.frontier == 42)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 42 && core.play.records.isEmpty && core.play.stage == .playing)
        #expect(core.mode == .campaign && core.progress.solved[41] != nil)
        core.reset()
        let fresh: Core = try await Core.prepare(seed: 40)
        let resetDigest: StateDigest = try Self.digest(core)
        let freshDigest: StateDigest = try Self.digest(fresh)
        #expect(core == fresh && resetDigest == freshDigest)
        #expect(core.progress.solved.isEmpty && core.progress.frontier == 41)
        // No wrap: after winning level 100 there is no next open level.
        var last: Core = try Core.opening(number: 100)
        for step in try Core.generated(number: 100).actions { #expect(last.apply(Self.act(step)) == .accepted) }
        #expect(last.play.stage == .won && last.progress.frontier == 100 && last.progress.solved[100] != nil)
        #expect(last.apply(Self.act("level.next")) == locked)
        last.reset()
        #expect(last.levelNumber == 100 && last.progress.solved.isEmpty)
    }

    @Test func theProgressionControlsRefuseWhatTheyMust() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let locked: ActionResult = .rejected(.rule(code: HarmonicBridgesExperienceRule.locked))
        let date: ActionResult = .rejected(.rule(code: HarmonicBridgesExperienceRule.date))
        let notWhole: ActionResult = .rejected(.rule(code: HarmonicBridgesExperienceRule.notWhole))
        let actions: [ExperienceAction] = [
            Self.act("level.select", [2]), Self.act("level.select", [100]), Self.act("level.select", [0]),
            Self.act("level.select", [101]), Self.act("level.select", [1.5]), Self.act("level.select", []),
            Self.act("mode.daily", [0, 1, 1]), Self.act("mode.daily", [2026, 13, 1]),
            Self.act("mode.daily", [2026, 1, 32]), Self.act("mode.daily", [2026, 2, 30]),
            Self.act("mode.daily", [2025, 2, 29]), Self.act("mode.daily", [2026, 4, 31]),
            Self.act("mode.daily", [2026, 1.5, 1]), Self.act("mode.daily", [2026, 1]),
            Self.act("mode.practice", [1]), Self.act("mode.campaign", [1]), Self.act("tutorial.dismiss", [1]),
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
        ]
        #expect(actions.count == expected.count)
        for index in actions.indices {
            var copy: Core = core
            #expect(copy.apply(actions[index]) == expected[index], "\(actions[index].control) \(actions[index].values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening, "\(actions[index].control) \(actions[index].values)")
        }
        // A leap year's 29 February is a date.
        var leap: Core = core
        #expect(leap.apply(Self.act("mode.daily", [2028, 2, 29])) == .accepted)
        let leapLevel: Int = try #require(HarmonicBridgesProgress.dailyLevel(year: 2028, month: 2, day: 29))
        #expect(leap.mode == .daily(level: leapLevel) && leap.levelNumber == leapLevel)
    }

    @Test func campaignWinsRecordStarsAndOpenTheNextLevel() async throws {
        let generated: HarmonicBridgesGenerated = try Core.generated(number: 1)
        let certified: Int = generated.actions.count
        #expect(certified == generated.plan.tunings.count + 1)
        // A win that spent one undone tuning more than the witness: 2 stars, level 2 opened.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.certifiedActions == certified)
        #expect(core.apply(Self.act("string.tune", [0, 3])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        for step in generated.actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && HarmonicBridgesProgress.actionsSpent(core.play) == certified + 1)
        #expect(core.progress.solved[1] == HarmonicBridgesProgress.Result(actionsSpent: certified + 1, stars: 2))
        #expect(core.progress.frontier == 2 && core.progress.isOpen(2) && !core.progress.isOpen(3))
        // A better result replaces it: the witness alone, 3 stars.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        #expect(core.levelNumber == 1 && core.play.records.isEmpty && core.mode == .campaign)
        for step in generated.actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.progress.solved[1] == HarmonicBridgesProgress.Result(actionsSpent: certified, stars: 3))
        // A worse result keeps the best one: three detours more than the witness (1 star) changes nothing.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        let detours: [ExperienceAction] = [Self.act("string.tune", [0, 3]), Self.act("string.tune", [0, 4]),
                                           Self.act("string.tune", [0, 5])]
        for step in detours { #expect(core.apply(step) == .accepted) }
        for step in generated.actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && HarmonicBridgesProgress.actionsSpent(core.play) == certified + 3)
        #expect(core.progress.solved[1] == HarmonicBridgesProgress.Result(actionsSpent: certified, stars: 3))
        #expect(core.progress.frontier == 2)
        // The frontier: level 2 can be chosen, level 3 cannot.
        #expect(core.apply(Self.act("level.select", [3])) == .rejected(.rule(code: "r02-g12.locked")))
        #expect(core.apply(Self.act("level.select", [2])) == .accepted)
        #expect(core.levelNumber == 2 && core.play.stage == .playing && core.tutorial == .tune)
        #expect(core.certifiedActions == (try Core.generated(number: 2)).actions.count)
        // No level is ever gated by payment: every level up to the frontier is open, whatever the tier.
        for number in 1...core.progress.frontier { #expect(core.progress.isOpen(number)) }
    }

    @Test func practiceAndDailyFollowTheirRules() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let certified: HarmonicBridgesLevel = try Core.level(number: 1)
        // Practice: a copy of the level with the budget raised to 60; a win records nothing and opens nothing.
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == 1 && core.play.records.isEmpty)
        #expect(core.play.level.budget == 60 && core.play.actionsLeft == 60 && core.tutorial == .tune)
        #expect(core.play.level.strings == certified.strings && core.play.level.steps == certified.steps)
        #expect(core.play.level.seed == certified.seed && core.play.level.fingerprint != certified.fingerprint)
        #expect(try Core.practiceLevel(of: certified) == core.play.level)
        let before: HarmonicBridgesProgress = core.progress
        for step in try Core.generated(number: 1).actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress == before && core.progress.solved.isEmpty)
        // Campaign returns to the current level when it is open, fresh, with the certified budget.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.play.records.isEmpty)
        #expect(core.play.level == certified && core.play.actionsLeft == certified.budget)
        // Daily: the date's level, playable while still locked; level.next from it is refused; a win records the
        // level's best result and stars and opens nothing.
        let daily: Int = try #require(HarmonicBridgesProgress.dailyLevel(year: 2026, month: 11, day: 23))
        #expect(daily == 59 && !core.progress.isOpen(daily))
        #expect(core.apply(Self.act("mode.daily", [2026, 11, 23])) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily && core.tutorial == .done)
        #expect(core.play.level == (try Core.level(number: daily)))
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g12.locked")))
        let dailyGenerated: HarmonicBridgesGenerated = try Core.generated(number: daily)
        for step in dailyGenerated.actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.frontier == 1 && !core.progress.isOpen(daily))
        let result: HarmonicBridgesProgress.Result = try #require(core.progress.solved[daily])
        #expect(result == HarmonicBridgesProgress.Result(actionsSpent: dailyGenerated.actions.count, stars: 3))
        // Campaign from a level that is not open goes to the frontier.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1)
        // A daily tutorial level carries the tutorial: 2026-01-01 is level 1.
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 1])) == .accepted)
        #expect(core.mode == .daily(level: 1) && core.levelNumber == 1 && core.tutorial == .tune)
        // Progress and mode are digested: the same fresh play in another mode digests differently.
        var campaign: Core = try await Core.prepare(seed: 0)
        var practice: Core = campaign
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(campaign.apply(Self.act("mode.campaign")) == .accepted)
        #expect(try Self.digest(practice) != (try Self.digest(campaign)))
        var dailyOne: Core = campaign
        #expect(dailyOne.apply(Self.act("mode.daily", [2026, 1, 1])) == .accepted)
        #expect(dailyOne.play == campaign.play && dailyOne.levelNumber == campaign.levelNumber)
        #expect(try Self.digest(dailyOne) != (try Self.digest(campaign)))
        var won: Core = campaign
        for step in try Core.generated(number: 1).actions { #expect(won.apply(Self.act(step)) == .accepted) }
        #expect(won.apply(Self.act("level.select", [1])) == .accepted)
        #expect(won.play == campaign.play && won.progress != campaign.progress)
        #expect(try Self.digest(won) != (try Self.digest(campaign)))
    }

    @Test func theTutorialAdvancesInOrderAndIsNotDigested() async throws {
        let level: HarmonicBridgesLevel = try Core.level(number: 1)
        let generated: HarmonicBridgesGenerated = try Core.generated(number: 1)
        let certifiedTuning: HarmonicBridgesAction = try #require(generated.actions.first)
        guard case let .tune(string, certifiedPeg) = certifiedTuning else {
            Issue.record("level 1's witness starts with a test")
            return
        }
        #expect(generated.actions == [certifiedTuning, .test])
        #expect(level.report(pegs: [certifiedPeg]).goalReachedInEveryStep)
        var offPeg: Int = 0
        for peg in Core.pegRange where peg != level.strings[string].peg && peg != certifiedPeg {
            if !level.report(pegs: [peg]).goalReachedInEveryStep {
                offPeg = peg
                break
            }
        }
        try #require(offPeg > 0)
        #expect(!level.report(pegs: level.startingPegs).goalReachedInEveryStep)
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.tutorial == .tune && core.tutorial.text.hasPrefix("Drag a string's peg"))
        // Dismissing ends it; the step is state (==) but never digested.
        let digest: StateDigest = try Self.digest(core)
        var dismissed: Core = core
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed.tutorial == .done && dismissed != core && dismissed.play == core.play)
        #expect(try Self.digest(dismissed) == digest)
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted && dismissed.tutorial == .done)
        // A tuning that bridges nothing: tune → bridge; an undo does not move it.
        #expect(core.apply(Self.act("string.tune", [Double(string), Double(offPeg)])) == .accepted)
        #expect(core.tutorial == .bridge)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .bridge)
        // The certified tuning bridges every step: bridge → test; undo never moves it back, redo keeps it.
        #expect(core.apply(Self.act(certifiedTuning)) == .accepted && core.tutorial == .test)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .test)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .test)
        // The end of the level ends it.
        #expect(core.apply(Self.act("crossing.test")) == .accepted)
        #expect(core.play.stage == .won && core.tutorial == .done)
        // A tuning that already bridges every step moves tune straight on to test.
        var straight: Core = try await Core.prepare(seed: 0)
        #expect(straight.apply(Self.act(certifiedTuning)) == .accepted && straight.tutorial == .test)
        // A failed test ends it; the undo that retries does not bring it back.
        var broken: Core = try await Core.prepare(seed: 0)
        #expect(broken.apply(Self.act("crossing.test")) == .accepted && broken.play.stage == .failed)
        #expect(broken.tutorial == .done)
        #expect(broken.apply(Self.act("play.undo")) == .accepted && broken.tutorial == .done)
        // Choosing a level or a mode restarts the step of that level; a level without the tutorial starts done.
        #expect(broken.apply(Self.act("mode.practice")) == .accepted && broken.tutorial == .tune)
        var plain: Core = try Core.opening(number: 4)
        #expect(plain.tutorial == .done && HarmonicBridgesTutorialStep.initial(level: 3) == .tune)
        let tuning: Int = try #require(Self.unlockedString(plain.play.level))
        let peg: Int = plain.play.pegs[tuning] == 1 ? 2 : 1
        #expect(plain.apply(Self.act("string.tune", [Double(tuning), Double(peg)])) == .accepted)
        #expect(plain.tutorial == .done)
        // The step is saved and restored.
        var saved: Core = try await Core.prepare(seed: 0)
        #expect(saved.apply(Self.act("string.tune", [Double(string), Double(offPeg)])) == .accepted)
        let payload: Data = try saved.snapshotPayload()
        #expect(String(decoding: payload, as: UTF8.self).hasSuffix(",\"tutorial\":\"bridge\"}"))
        let restored: Core = try Core.restore(payload: payload, seed: 0)
        #expect(restored == saved && restored.tutorial == .bridge)
    }

    @Test func theSchemaTwoPayloadRoundTripsInEveryModeAndRefusesDamage() async throws {
        // Campaign with progress: level 1 won, level 2 reached with level.next.
        var campaign: Core = try await Core.prepare(seed: 0)
        for step in try Core.generated(number: 1).actions { #expect(campaign.apply(Self.act(step)) == .accepted) }
        #expect(campaign.apply(Self.act("level.next")) == .accepted)
        // Practice: a tuning on the practice copy.
        var practice: Core = try await Core.prepare(seed: 0)
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(practice.apply(Self.act("string.tune", [0, 3])) == .accepted)
        // Daily: the first certified action of the date's level.
        var daily: Core = try await Core.prepare(seed: 0)
        #expect(daily.apply(Self.act("mode.daily", [2026, 11, 23])) == .accepted)
        let dailyFirst: HarmonicBridgesAction = try #require(try Core.generated(number: 59).actions.first)
        #expect(daily.apply(Self.act(dailyFirst)) == .accepted)
        let cores: [Core] = [campaign, practice, daily]
        for core in cores {
            let payload: Data = try core.snapshotPayload()
            #expect(try core.snapshotPayload() == payload)
            let restored: Core = try Core.restore(payload: payload, seed: 0)
            let restoredDigest: StateDigest = try Self.digest(restored)
            let savedDigest: StateDigest = try Self.digest(core)
            #expect(restored == core && restoredDigest == savedDigest, "\(core.mode)")
            #expect(restored.certifiedActions == core.certifiedActions && restored.openingNumber == 1)
            var reset: Core = restored
            reset.reset()
            #expect(reset == (try Core.opening(number: 1)))
        }
        #expect(practice.play.level.budget == 60)
        let campaignText: String = String(decoding: try campaign.snapshotPayload(), as: UTF8.self)
        let progressText: String = "\"progress\":{\"frontier\":2,"
            + "\"solved\":[{\"actionsSpent\":2,\"level\":1,\"stars\":3,\"trace\":[],\"verified\":false}]}"
        #expect(campaignText.contains(progressText))
        let dailyText: String = String(decoding: try daily.snapshotPayload(), as: UTF8.self)
        #expect(dailyText.hasPrefix("{\"level\":59,\"mode\":{\"level\":59,\"mode\":\"daily\"},"))
        // Damaged: a daily mode naming another level, an unknown mode, an invalid frontier, an unknown tutorial step.
        let otherDaily: Data = Data(dailyText.replacingOccurrences(of: "{\"level\":59,\"mode\":{\"level\":59",
                                                                   with: "{\"level\":59,\"mode\":{\"level\":58").utf8)
        let unknownMode: Data = Data(campaignText.replacingOccurrences(of: "\"mode\":\"campaign\"",
                                                                       with: "\"mode\":\"arcade\"").utf8)
        let badFrontier: Data = Data(campaignText.replacingOccurrences(of: "\"frontier\":2",
                                                                       with: "\"frontier\":0").utf8)
        let badStars: Data = Data(campaignText.replacingOccurrences(of: "\"stars\":3", with: "\"stars\":4").utf8)
        let badStep: Data = Data(campaignText.replacingOccurrences(of: "\"tutorial\":\"tune\"",
                                                                   with: "\"tutorial\":\"later\"").utf8)
        let damaged: [Data] = [otherDaily, unknownMode, badFrontier, badStars, badStep]
        let campaignPayload: Data = try campaign.snapshotPayload()
        let dailyPayload: Data = try daily.snapshotPayload()
        for payload in damaged {
            #expect(payload != campaignPayload && payload != dailyPayload)
            #expect(throws: HarmonicBridgesRestoreRefusal.damaged) { try Core.restore(payload: payload, seed: 0) }
        }
        // A payload without the tutorial key starts the tutorial at the level's initial step.
        let noStep: Data = Data(campaignText.replacingOccurrences(of: ",\"tutorial\":\"tune\"", with: "").utf8)
        #expect(campaign.tutorial == .tune && noStep != campaignPayload)
        let restoredNoStep: Core = try Core.restore(payload: noStep, seed: 0)
        #expect(restoredNoStep == campaign)
    }

    @Test func aSchemaOnePayloadMigratesAndANewerSchemaIsRefused() async throws {
        // Level 3 after the first certified action: the tutorial has advanced, which schema 1 did not save.
        var core: Core = try await Core.prepare(seed: 2)
        let generated: HarmonicBridgesGenerated = try Core.generated(number: 3)
        let first: HarmonicBridgesAction = try #require(generated.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.tutorial != .tune)
        let records: Data = try Core.payloadEncoder().encode(core.play.records)
        let recordsObject: Any = try JSONSerialization.jsonObject(with: records)
        let schemaOne: [String: Any] = ["level": 3, "records": recordsObject]
        let migrated: [String: Any] = try Core.migratedToSchemaTwo(schemaOne)
        let chained: [String: Any] = try Core.migrations.migrate(schemaOne, from: 1)
        let data: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
        let chainedData: Data = try JSONSerialization.data(withJSONObject: chained, options: [.sortedKeys])
        #expect(data == chainedData)
        let restored: Core = try Core.restore(payload: data, seed: 2)
        #expect(restored.levelNumber == 3 && restored.play == core.play && restored.mode == .campaign)
        #expect(restored.progress.frontier == 3 && restored.progress.solved.isEmpty)
        #expect(restored.progress.isOpen(1) && restored.progress.isOpen(3) && !restored.progress.isOpen(4))
        #expect(restored.tutorial == .tune && restored.tutorial == HarmonicBridgesTutorialStep.initial(level: 3))
        // The tutorial step is not digested, so the migrated state digests as the saved one.
        #expect(try Self.digest(restored) == Self.digest(core))
        // A level without the tutorial migrates with it done: the fresh opening of level 7.
        let seven: [String: Any] = try Core.migratedToSchemaTwo(["level": 7, "records": [Any]()])
        let sevenData: Data = try JSONSerialization.data(withJSONObject: seven, options: [.sortedKeys])
        let sevenCore: Core = try Core.restore(payload: sevenData, seed: 6)
        #expect(sevenCore == (try Core.opening(number: 7)) && sevenCore.tutorial == .done)
        // A schema-1 object that is not one is refused.
        #expect(throws: HarmonicBridgesRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": "3"]) }
        #expect(throws: HarmonicBridgesRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": 3]) }
        // A newer schema is refused by the chain.
        #expect(throws: MigrationError.newerVersion(3)) { try Core.migrations.migrate(schemaOne, from: 3) }
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        var core: Core = try await Core.prepare(seed: 20)
        let generated: HarmonicBridgesGenerated = try Core.generated(number: 21)
        // Every action of the witness but the test (no tuning ends the play), another tuning, then an undo.
        try #require(generated.actions.count >= 2)
        for step in generated.actions.dropLast() { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.apply(Self.act("string.tune", [0, 1])) == .accepted)
        #expect(core.play.stage == .playing)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let payload: Data = try core.snapshotPayload()
        #expect(try core.snapshotPayload() == payload)
        let text: String = try #require(String(data: payload, encoding: .utf8))
        #expect(text.hasPrefix("{\"level\":21,\"mode\":{\"mode\":\"campaign\"},\"progress\":"))
        #expect(text.hasSuffix(",\"tutorial\":\"done\"}"))
        let restored: Core = try Core.restore(payload: payload, seed: 20)
        let restoredDigest: StateDigest = try Self.digest(restored)
        let savedDigest: StateDigest = try Self.digest(core)
        #expect(restored == core && restoredDigest == savedDigest)
        #expect(restored.play.canRedo && restored.openingNumber == 21)
        var redone: Core = restored
        var original: Core = core
        #expect(redone.apply(Self.act("play.redo")) == .accepted)
        #expect(original.apply(Self.act("play.redo")) == .accepted)
        #expect(redone == original)
        let other: Core = try Core.restore(payload: payload, seed: 0)
        #expect(other == core && other.openingNumber == 1)
        var otherReset: Core = other
        otherReset.reset()
        #expect(otherReset.levelNumber == 1 && otherReset.play.records.isEmpty)
        // A fresh play round-trips too.
        let opening: Core = try await Core.prepare(seed: 7)
        let openingPayload: Data = try opening.snapshotPayload()
        let openingText: String = "{\"level\":8,\"mode\":{\"mode\":\"campaign\"},"
            + "\"progress\":{\"frontier\":8,\"solved\":[]},\"records\":[],\"tutorial\":\"done\"}"
        #expect(String(data: openingPayload, encoding: .utf8) == openingText)
        #expect(try Core.restore(payload: openingPayload, seed: 7) == opening)

        #expect(throws: HarmonicBridgesRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 20)
        }
        #expect(throws: HarmonicBridgesRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 20)
        }
        #expect(throws: HarmonicBridgesRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"21\",\"records\":[]}".utf8), seed: 20)
        }
        // A schema-1 payload is no schema-2 payload: the engine migrates it before the core sees it.
        #expect(throws: HarmonicBridgesRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":21,\"records\":[]}".utf8), seed: 20)
        }
        let levelZero: Data = Data(text.replacingOccurrences(of: "\"level\":21", with: "\"level\":0").utf8)
        #expect(throws: HarmonicBridgesRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: levelZero, seed: 20)
        }
        let levelBeyond: Data = Data(text.replacingOccurrences(of: "\"level\":21", with: "\"level\":101").utf8)
        #expect(throws: HarmonicBridgesRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: levelBeyond, seed: 20)
        }
        // The same records on another level: the records carry level 21's seed.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":21", with: "\"level\":1").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: HarmonicBridgesRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: wrongLevel, seed: 20)
        }
        // A record of a newer schema.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: HarmonicBridgesRestoreRefusal.kernel(.malformed("schema 0"))) {
            try Core.restore(payload: newer, seed: 20)
        }
        // A trace that no longer replays: an edited next fingerprint.
        let first: HarmonicBridgesRecord = try #require(core.play.records.first)
        let edited: Data = Data(text.replacingOccurrences(of: first.next, with: String(repeating: "0", count: 64)).utf8)
        #expect(edited != payload)
        var editedRefused: Bool = false
        do {
            _ = try Core.restore(payload: edited, seed: 20)
        } catch let refusal as HarmonicBridgesRestoreRefusal {
            if case .kernel(.malformed) = refusal { editedRefused = true }
        }
        #expect(editedRefused)
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 5)
        try engine.activate()
        // Level 6: string 4 at peg 2 (its witness tunes it to 12).
        #expect(engine.handle(control: "string.tune", values: [4, 7]) == .accepted)
        let before: StateDigest = try engine.digest()
        let saved: ExperienceSnapshot = try engine.snapshot()
        let newer = try ExperienceSnapshot(experience: id, schemaVersion: 3, seed: saved.seed,
                                           stepIndex: saved.stepIndex, digest: saved.digest,
                                           payload: Data(saved.payload.utf8))
        var refused: Bool = false
        do {
            try engine.restore(newer)
        } catch {
            refused = error == .snapshot(.newerSchema(found: 3, current: 2))
        }
        #expect(refused)
        #expect(try engine.digest() == before)
        try engine.restore(saved)
        #expect(try engine.digest() == before)
    }

    @Test func theSnapshotCopiesThePlayAndTheKernelsReport() async throws {
        // Level 3 after the first tuning of its witness: the snapshot copies the play exactly.
        var core: Core = try await Core.prepare(seed: 2)
        let generated: HarmonicBridgesGenerated = try Core.generated(number: 3)
        let first: HarmonicBridgesAction = try #require(generated.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        let play: HarmonicBridgesPlay = core.play
        let level: HarmonicBridgesLevel = play.level
        let snapshot: HarmonicBridgesSceneSnapshot = core.snapshot(time: 2.5)
        #expect(snapshot == HarmonicBridgesSceneSnapshot(play: play, levelNumber: 3, time: 2.5))
        #expect(snapshot.islands == level.islands && snapshot.strings == level.strings && snapshot.pegs == play.pegs)
        #expect(snapshot.report == play.report && snapshot.report == level.report(pegs: play.pegs))
        #expect(snapshot.threshold == level.threshold && snapshot.start == level.start && snapshot.goal == level.goal)
        #expect(snapshot.stage == .playing && snapshot.failure == nil && snapshot.levelNumber == 3)
        #expect(snapshot.actionsLeft == level.budget - 1 && snapshot.budget == level.budget && snapshot.time == 2.5)
        #expect(snapshot.steps == level.steps.count && snapshot.modes.count == level.steps.count)
        // Non-finite and negative times read as 0.
        let zero: HarmonicBridgesSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        #expect(core.snapshot(time: -3) == zero && zero.shownStep == 0)
        // After the win the goal is reached in every step of the snapshot's report.
        for step in generated.actions.dropFirst() { #expect(core.apply(Self.act(step)) == .accepted) }
        let won: HarmonicBridgesSceneSnapshot = core.snapshot(time: 1)
        #expect(won.stage == .won && won.report.goalReachedInEveryStep)
        for step in 0..<won.steps { #expect(won.isReached(won.goal, step: step)) }
    }

    @Test func theTierAndTheSnapshotTimeNeverTouchTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: Self.fixtureSeed)
        let string: Int = try #require(Self.unlockedString(core.play.level))
        let peg: Int = core.play.pegs[string] == 1 ? 2 : 1
        #expect(core.apply(Self.act("string.tune", [Double(string), Double(peg)])) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let shells: [Int] = [2, 2, 1, 0, 0]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.glowShells == shells[index])
            #expect(core.renderTier == HarmonicBridgesTier.of(clamped[index]))
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: HarmonicBridgesSceneSnapshot = core.snapshot(time: time)
            #expect(snapshot.stage == core.play.stage && snapshot.actionsLeft == core.play.actionsLeft)
            #expect(snapshot.levelNumber == core.levelNumber && snapshot.time.isFinite)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }
}
