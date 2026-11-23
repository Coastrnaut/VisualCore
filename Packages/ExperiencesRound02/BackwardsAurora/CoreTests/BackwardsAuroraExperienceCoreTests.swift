// BackwardsAuroraExperienceCoreTests — feature 393 (R02-G10-03) T-R02G1003-005 (FR-R02G1003-003, 005; clarification
// Q5). The adapter core: the shared conformance checks pass; the declared controls, ids, tiers and profile; the seed
// picks level `seed % 100 + 1` deterministically in stage `playing` (seeds 0, 1, 99 and 100 give levels 1, 2, 100 and
// 1); every control is accepted when legal and refused with the state unchanged otherwise (the engine's range checks,
// `r02-g10.not-whole`, and every kernel refusal the adapter can meet passing through with its code: `r02-g10.action`,
// `noop` and `stage`; `stale` cannot arise because every reversal names the current fingerprint); undo restores the
// earlier digest exactly and redo the later one; the certified solution wins, a tear and the budget fail, undo returns a
// failed play to playing; `level.next` wraps 100 to 1 and reset returns; the snapshot round trip and refused payloads
// (damaged, level out of range, a trace of another level, a record of a newer schema, an envelope of a newer schema);
// the certified-candidate table equals the 100 stored witnesses' `skipped` and the directly certified levels equal the
// stored ones; `snapshot(sectionStart:sectionEnd:time:)` mirrors the play. Fixture seed 2_393. Levels are certified
// once per process, so the run stays short. Explicit types, plain loops.
// Feature 395 (R02-G10-05) T-R02G1005-004 (FR-R02G1005-001, 004, 005, 006, 007; clarifications Q2–Q5): `level.next`
// needs an open level (no wrap); a campaign win records stars by reversals made; daily, practice and campaign modes;
// the tutorial advances, is dismissed and is not digested; schema 2's round trip and refusals; a schema-1 payload and
// envelope migrate; an envelope of schema 3 is refused; the digest carries progress and mode. Progression seed 2_395.
import Foundation
import Testing
@testable import BackwardsAuroraCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/backwards-aurora/levels", isDirectory: true)

@Suite struct BackwardsAuroraExperienceCoreTests {
    typealias Core = BackwardsAuroraExperienceCore

    /// The fixture seed of this feature.
    static let fixtureSeed: UInt64 = 2_393
    /// The progression fixture seed (feature 395): it opens level 96.
    static let progressionSeed: UInt64 = 2_395

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
    static func act(_ action: BackwardsAuroraAction) -> ExperienceAction {
        switch action {
        case let .reverse(start, end):
            act("wave.reverse", [Double(start), Double(end)])
        }
    }

    /// A neutral reversal of `core`: the first pair [k, k + 1] that is not a palindrome and holds no checkpoint, so it
    /// can never win; reversing it twice restores the wave.
    static func neutralReverse(_ core: Core) -> ExperienceAction? {
        let samples: [Int] = core.play.wave.samples
        let checkpoints: [Int] = core.play.level.checkpoints
        for k in 0..<(samples.count - 1) {
            if samples[k] != samples[k + 1], !checkpoints.contains(k), !checkpoints.contains(k + 1) {
                return act("wave.reverse", [Double(k), Double(k + 1)])
            }
        }
        return nil
    }

    /// The stored witness of level `number`.
    static func storedWitness(_ number: Int) throws -> BackwardsAuroraWitness {
        let name: String = String(BackwardsAuroraGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: coreWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(BackwardsAuroraWitness.self, from: data)
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 2 (then 2 and 3): a reversal, undo and redo, another reversal, undo, a third reversal, then
        // level.next and a reversal. None of the sections holds a solution, so no play ends.
        let actions: [ScriptedAction] = [ScriptedAction("wave.reverse", [0, 2]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("wave.reverse", [10, 13]), ScriptedAction("play.undo"),
                                         ScriptedAction("wave.reverse", [5, 7]),
                                         ScriptedAction("level.next"), ScriptedAction("wave.reverse", [0, 2])]
        // Refused on the opening of levels 1 and 2 (14 and 15 samples; [5, 6] is a palindrome on both).
        let rejected: [ScriptedAction] = [ScriptedAction("wave.reverse", [32, 1]),
                                          ScriptedAction("wave.reverse", [0, 32]),
                                          ScriptedAction("wave.reverse", [0.5, 2]),
                                          ScriptedAction("wave.reverse", [0]),
                                          ScriptedAction("wave.reverse", [2, 1]),
                                          ScriptedAction("wave.reverse", [3, 3]),
                                          ScriptedAction("wave.reverse", [0, 20]),
                                          ScriptedAction("wave.reverse", [5, 6]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 1], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g10.backwards-aurora" && Core.schemaVersion == 3)
        #expect(Core.digestDomain == "r02-g10.backwards-aurora.v3")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["wave.reverse", "play.undo", "play.redo", "level.next", "level.select", "mode.daily",
                             "mode.practice", "mode.campaign", "tutorial.dismiss", "replay.start", "replay.step",
                             "replay.stop", "settings.sound"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[0].ranges == [0...31, 0...31])
        #expect(Core.controls[4].ranges == [1...100])
        #expect(Core.controls[5].ranges == [1...9999, 1...12, 1...31])
        #expect(Core.controls[9].ranges == [1...100] && Core.controls[12].ranges == [0...1])
        let plainIndices: [Int] = [1, 2, 3, 6, 7, 8, 10, 11]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.practiceBudget == 40)
        #expect(Core.qualityTiers == 3 && Core.migrations.currentVersion == 3)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == BackwardsAuroraTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 2.0 / 3.0, 1.0 / 3.0] && iterations == [1, 0.5, 0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(BackwardsAuroraExperienceRule.notWhole == "r02-g10.not-whole")
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
            let expected: BackwardsAuroraLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.wave == expected.opening)
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.play.spent == 0 && first.qualityTier == 0)
        }
        #expect(Core.levelNumber(forSeed: Self.fixtureSeed) == 94)
        #expect(throws: BackwardsAuroraError.level("number")) { try Core.level(number: 0) }
        #expect(throws: BackwardsAuroraError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableEqualsTheWitnessesAndCertifiesTheStoredLevels() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for number in 1...100 {
            let witness: BackwardsAuroraWitness = try Self.storedWitness(number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "level \(number)")
        }
        // Directly certified levels equal the stored witness levels and solutions.
        let numbers: [Int] = [1, 9, 63, 100]
        for number in numbers {
            let witness: BackwardsAuroraWitness = try Self.storedWitness(number)
            let generated: BackwardsAuroraGenerated = try Core.generated(number: number)
            #expect(generated.level == witness.level && generated.solution.actions == witness.actions)
            #expect(generated.skipped == witness.skipped && generated.bound == witness.bound)
            #expect(generated.entry == BackwardsAuroraManifest.entries[number - 1])
            // The candidate just before the certified one does not certify (the generator skipped it).
            if witness.skipped > 0 {
                let entry: BackwardsAuroraManifestEntry = BackwardsAuroraManifest.entries[number - 1]
                #expect(Core.certify(entry, index: witness.skipped - 1) == nil, "level \(number)")
            }
        }
        // The generator itself gives the same level as the direct certification.
        let entry: BackwardsAuroraManifestEntry = BackwardsAuroraManifest.entries[8]
        #expect(try BackwardsAuroraGenerator.generate(entry) == Core.generated(number: 9))
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: 14 samples, sections 2 … 14, bend limit 1, breaking limit 128, budget 9.
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let illegal: [ExperienceAction] = [Self.act("wave.reverse", [32, 1]), Self.act("wave.reverse", [-1, 1]),
                                           Self.act("wave.reverse", [0, 32]), Self.act("wave.reverse", [0.5, 2]),
                                           Self.act("wave.reverse", [0, .nan]), Self.act("wave.reverse", [0]),
                                           Self.act("wave.reverse", [0, 1, 2]), Self.act("wave.reverse", [2, 1]),
                                           Self.act("wave.reverse", [3, 3]), Self.act("wave.reverse", [0, 14]),
                                           Self.act("wave.reverse", [5, 6]), Self.act("wave.reverse", [1, 2]),
                                           Self.act("play.undo"), Self.act("play.redo"),
                                           Self.act("play.undo", [1]), Self.act("level.next", [1]),
                                           Self.act("nope")]
        for action in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(action)
            #expect(!result.isAccepted, "\(action.control) \(action.values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.isEmpty, "\(action.control)")
        }
        var probe: Core = core
        // Outside the declared ranges or the value count: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.act("wave.reverse", [32, 1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("wave.reverse", [-1, 1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("wave.reverse", [0, 32])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("wave.reverse", [0])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("play.undo", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("level.next", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        let notWhole: ActionResult = .rejected(.rule(code: BackwardsAuroraExperienceRule.notWhole))
        #expect(probe.apply(Self.act("wave.reverse", [0.5, 2])) == notWhole)
        #expect(probe.apply(Self.act("wave.reverse", [0, 2.25])) == notWhole)
        // Every kernel refusal the adapter can meet passes through with its reason code.
        let action: ActionResult = .rejected(.rule(code: BackwardsAuroraError.action("end").reasonCode))
        let noop: ActionResult = .rejected(.rule(code: BackwardsAuroraError.noop.reasonCode))
        #expect(action == .rejected(.rule(code: "r02-g10.action")) && noop == .rejected(.rule(code: "r02-g10.noop")))
        #expect(probe.apply(Self.act("wave.reverse", [0, 14])) == action)     // end outside the wave
        #expect(probe.apply(Self.act("wave.reverse", [2, 1])) == action)      // start not before end
        #expect(probe.apply(Self.act("wave.reverse", [3, 3])) == action)      // start not before end
        #expect(probe.apply(Self.act("wave.reverse", [5, 6])) == noop)        // -20, -20 reads the same both ways
        #expect(probe.apply(Self.act("wave.reverse", [1, 2])) == noop)        // -23, -23
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe.apply(Self.act("nope")) == .rejected(.unknownControl("nope")))
        #expect(probe == core)
        // A section length below the level's shortest cannot be named (start < end gives at least 2 = shortest), so
        // the length refusal is the kernel's only on a longer section than the level allows: the whole wave is
        // allowed (longest = N), so it reverses.
        var whole: Core = core
        #expect(whole.apply(Self.act("wave.reverse", [0, 13])) == .accepted)
        #expect(whole.play.wave.samples == Array(core.play.wave.samples.reversed()))

        // A reversal spends one and reverses the section.
        #expect(core.apply(Self.act("wave.reverse", [0, 2])) == .accepted)
        #expect(core.play.wave.samples.prefix(3) == [-23, -23, -24] && core.play.spent == 1)
        #expect(core.play.records.count == 1 && core.play.stage == .playing)
        #expect(try Self.digest(core) != opening)
        // The stage refusal: a won play refuses everything but level.next.
        var won: Core = try Core.opening(number: 1)
        let generated: BackwardsAuroraGenerated = try Core.generated(number: 1)
        for step in generated.solution.actions { #expect(won.apply(Self.act(step)) == .accepted) }
        #expect(won.play.stage == .won)
        let stage: ActionResult = .rejected(.rule(code: BackwardsAuroraError.stage.reasonCode))
        #expect(stage == .rejected(.rule(code: "r02-g10.stage")))
        let final: Core = won
        #expect(won.apply(Self.act("wave.reverse", [0, 2])) == stage)
        #expect(won.apply(Self.act("play.undo")) == stage)
        #expect(won.apply(Self.act("play.redo")) == stage)
        #expect(won == final)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 20)
        let startDigest: StateDigest = try Self.digest(core)
        let start: BackwardsAuroraWave = core.play.wave
        let sections: [[Double]] = [[0, 2], [5, 7], [10, 13]]
        for section in sections { #expect(core.apply(Self.act("wave.reverse", section)) == .accepted) }
        let moved: Core = core
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest && core.play.stage == .playing)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(core.play.wave == start && core.play.spent == 0 && core.play.stage == .playing)
        #expect(try Self.digest(core) == startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.redo")) == .accepted) }
        #expect(core.play.wave == moved.play.wave && core.play.spent == 3)
        #expect(core.play.records.count == 9)
        #expect(try Self.digest(core) == movedDigest)
        // A new action clears the redo history.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let other: ExperienceAction = try #require(Self.neutralReverse(core))
        #expect(core.apply(other) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g10.action")))
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(try Self.digest(core) == startDigest)
    }

    @Test func theSolutionWinsTheBudgetFailsAndUndoRetries() async throws {
        // Bands 1 and 2 (breaking limit 128): a neutral pair reversed back and forth never tears and never wins.
        let numbers: [Int] = [1, 21, 32]
        let stageCode: ActionResult = .rejected(.rule(code: "r02-g10.stage"))
        for number in numbers {
            let generated: BackwardsAuroraGenerated = try Core.generated(number: number)
            let level: BackwardsAuroraLevel = generated.level
            var core: Core = try Core.opening(number: number)
            var failing: Core = core
            let before: StateDigest = try Self.digest(failing)
            let neutral: ExperienceAction = try #require(Self.neutralReverse(failing))
            for _ in 0..<level.budget { #expect(failing.apply(neutral) == .accepted) }
            #expect(failing.play.stage == .failed && failing.play.failure == .budget, "level \(number)")
            #expect(failing.outcome?.code == Core.failedCode)
            let failedSnapshot: BackwardsAuroraSceneSnapshot = failing.snapshot(sectionStart: 0, sectionEnd: 1, time: 0)
            #expect(failedSnapshot.stage == .failed && failedSnapshot.failure == .budget)
            #expect(failedSnapshot.tear == nil && failedSnapshot.spent == level.budget)
            let failed: Core = failing
            #expect(failing.apply(neutral) == stageCode)
            #expect(failing.apply(Self.act("play.redo")) == stageCode)
            #expect(failing == failed)
            #expect(failing.apply(Self.act("play.undo")) == .accepted)
            #expect(failing.play.stage == .playing && failing.outcome == nil)
            while failing.play.canUndo { #expect(failing.apply(Self.act("play.undo")) == .accepted) }
            #expect(try Self.digest(failing) == before)
            // The certified solution: won on its last action.
            for step in generated.solution.actions { #expect(core.apply(Self.act(step)) == .accepted) }
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "level \(number)")
            #expect(core.play.spent == generated.solution.smallest)
            #expect(core.apply(Self.act("level.next")) == .accepted)
            let next: Int = number % 100 + 1
            #expect(core.play.stage == .playing && core.levelNumber == next && core.outcome == nil)
            core.reset()
            #expect(core.levelNumber == number && core.play.records.isEmpty && core.play.stage == .playing)
        }
    }

    @Test func aTearFailsAndUndoRetries() async throws {
        // The first section of level 100 (breaking limit 18) whose reversal tears the aurora.
        let core: Core = try Core.opening(number: 100)
        let before: StateDigest = try Self.digest(core)
        let count: Int = core.play.wave.count
        var torn: Core? = nil
        for start in 0..<(count - 1) where torn == nil {
            for end in (start + 1)..<count where torn == nil {
                var copy: Core = core
                if copy.apply(Self.act("wave.reverse", [Double(start), Double(end)])).isAccepted,
                   case .tear = copy.play.failure {
                    torn = copy
                }
            }
        }
        var failed: Core = try #require(torn)
        guard case let .tear(move, seam)? = failed.play.failure else {
            Issue.record("no tear")
            return
        }
        #expect(move == 0 && failed.play.stage == .failed && failed.outcome?.code == Core.failedCode)
        let snapshot: BackwardsAuroraSceneSnapshot = failed.snapshot(sectionStart: 3, sectionEnd: 7, time: 1)
        #expect(snapshot.tear == seam && snapshot.failure == failed.play.failure)
        #expect(abs(failed.play.wave.bend(at: seam)) > failed.play.level.breakingLimit)
        #expect(failed.apply(Self.act("wave.reverse", [0, 2])) == .rejected(.rule(code: "r02-g10.stage")))
        #expect(failed.apply(Self.act("play.undo")) == .accepted)
        let retried: StateDigest = try Self.digest(failed)
        #expect(failed.play.stage == .playing && failed.play.failure == nil && retried == before)
    }

    /// Feature 395 (clarification Q3): `level.next` and `level.select` need an open level (100 does not wrap); reset
    /// returns to the seed's opening state.
    @Test func nextLevelNeedsAnOpenLevelAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 40)
        #expect(core.levelNumber == 41 && core.progress.frontier == 41 && core.mode == .campaign)
        let neutral: ExperienceAction = try #require(Self.neutralReverse(core))
        #expect(core.apply(neutral) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let locked: ActionResult = .rejected(.rule(code: BackwardsAuroraExperienceRule.locked))
        let moved: Core = core
        #expect(core.apply(Self.act("level.next")) == locked)
        #expect(core.apply(Self.act("level.select", [42])) == locked)
        let lockedDigest: StateDigest = try Self.digest(core)
        #expect(core == moved && lockedDigest == before)
        #expect(core.apply(Self.act("level.select", [12])) == .accepted)
        #expect(core.levelNumber == 12 && core.play.records.isEmpty && core.mode == .campaign)
        let twelve: BackwardsAuroraLevel = try Core.level(number: 12)
        #expect(core.play.level == twelve && core.tutorial == .done)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 13 && core.play.stage == .playing && core.play.records.isEmpty)
        core.reset()
        let fresh: Core = try await Core.prepare(seed: 40)
        let resetDigest: StateDigest = try Self.digest(core)
        let freshDigest: StateDigest = try Self.digest(fresh)
        #expect(core == fresh && resetDigest == freshDigest)
        // No wrap: level 100 has no next level.
        var last: Core = try Core.opening(number: 100)
        #expect(last.progress.frontier == 100)
        #expect(last.apply(Self.act("level.next")) == locked)
        last.reset()
        #expect(last.levelNumber == 100)
    }

    /// Whether `result` has `reversalsMade` and `stars` and is verified with a non-empty trace (feature 397: a campaign
    /// win records its winning trace).
    static func isVerified(_ result: BackwardsAuroraProgress.Result?, reversalsMade: Int, stars: Int) -> Bool {
        guard let result else { return false }
        return result.reversalsMade == reversalsMade && result.stars == stars && result.verified && !result.trace.isEmpty
    }

    /// Applies `actions` to `core`, each accepted, after `detours` detours of (the first action, undo); returns the
    /// reversals made.
    static func win(_ core: inout Core, actions: [BackwardsAuroraAction], detours: Int) -> Int {
        guard let first = actions.first else { return 0 }
        for _ in 0..<detours {
            #expect(core.apply(Self.act(first)) == .accepted)
            #expect(core.play.stage == .playing)
            #expect(core.apply(Self.act("play.undo")) == .accepted)
        }
        for action in actions { #expect(core.apply(Self.act(action)) == .accepted) }
        #expect(core.play.stage == .won)
        return BackwardsAuroraProgress.reversalsMade(core.play)
    }

    /// Feature 395 (clarification Q3): a campaign win records the reversals made (undone ones included) and its stars,
    /// keeps the better result and opens the next level.
    @Test func aCampaignWinRecordsStarsByReversalsMade() throws {
        let first: BackwardsAuroraGenerated = try Core.generated(number: 1)
        let second: BackwardsAuroraGenerated = try Core.generated(number: 2)
        let smallest: Int = first.solution.smallest
        var core: Core = try Core.opening(number: 1)
        #expect(core.certifiedSmallest == smallest && core.progress.solved.isEmpty && core.progress.frontier == 1)
        // Two detours: smallest + 2 reversals made, 2 stars; level 2 opens.
        let twoDetours: Int = Self.win(&core, actions: first.solution.actions, detours: 2)
        #expect(twoDetours == smallest + 2)
        #expect(Self.isVerified(core.progress.solved[1], reversalsMade: smallest + 2, stars: 2))
        #expect(core.progress.frontier == 2 && core.outcome?.code == Core.wonCode)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 2 && core.mode == .campaign && core.play.records.isEmpty)
        // Level 1 again without a detour: the better result (3 stars) replaces the stored one.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        let noDetour: Int = Self.win(&core, actions: first.solution.actions, detours: 0)
        #expect(noDetour == smallest)
        #expect(Self.isVerified(core.progress.solved[1], reversalsMade: smallest, stars: 3))
        // A worse result (three detours, 1 star) keeps it.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        let threeDetours: Int = Self.win(&core, actions: first.solution.actions, detours: 3)
        #expect(threeDetours == smallest + 3)
        #expect(Self.isVerified(core.progress.solved[1], reversalsMade: smallest, stars: 3))
        #expect(core.progress.frontier == 2)
        // Level 2 with three detours: 1 star; level 3 opens.
        #expect(core.apply(Self.act("level.next")) == .accepted)
        let secondReversals: Int = Self.win(&core, actions: second.solution.actions, detours: 3)
        #expect(Self.isVerified(core.progress.solved[2], reversalsMade: secondReversals, stars: 1))
        #expect(secondReversals == second.solution.smallest + 3 && core.progress.frontier == 3)
        // A redo before the win is no reversal made: level 3 with its first reversal undone and redone gets 3 stars.
        let third: BackwardsAuroraGenerated = try Core.generated(number: 3)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        let firstAction: BackwardsAuroraAction = try #require(third.solution.actions.first)
        #expect(core.apply(Self.act(firstAction)) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        for action in third.solution.actions.dropFirst() { #expect(core.apply(Self.act(action)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.frontier == 4)
        #expect(Self.isVerified(core.progress.solved[3], reversalsMade: third.solution.smallest, stars: 3))
    }

    /// Feature 395 (clarification Q4): daily mode opens nothing and plays a locked level; practice is a fresh play with
    /// the budget 40 that records nothing; `mode.campaign` returns.
    @Test func dailyPracticeAndCampaignModes() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.mode == .campaign && core.progress.frontier == 1 && core.tutorial == .mark)
        let date: ActionResult = .rejected(.rule(code: BackwardsAuroraExperienceRule.date))
        let opening: Core = core
        #expect(core.apply(Self.act("mode.daily", [2027, 2, 29])) == date)
        #expect(core == opening)
        let daily: Int = try #require(BackwardsAuroraProgress.dailyLevel(year: 2026, month: 1, day: 2))
        #expect(daily == 74)
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 2])) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily && core.progress.frontier == 1)
        #expect(!core.progress.isOpen(daily) && core.tutorial == .done && core.play.records.isEmpty)
        let dailyCertified: BackwardsAuroraGenerated = try Core.generated(number: daily)
        #expect(core.play.level == dailyCertified.level && core.certifiedSmallest == dailyCertified.solution.smallest)
        // A daily win on a locked level records its stars but opens nothing.
        var dailyWin: Core = core
        _ = Self.win(&dailyWin, actions: dailyCertified.solution.actions, detours: 0)
        #expect(dailyWin.progress.solved[daily]?.stars == 3 && dailyWin.progress.frontier == 1)
        #expect(dailyWin.apply(Self.act("level.next")) == .rejected(.rule(code: BackwardsAuroraExperienceRule.locked)))
        // Practice of the daily level: the same level fresh with the budget 40.
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == daily && core.play.level.budget == Core.practiceBudget)
        // Campaign returns to the frontier when the current level is not open.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.tutorial == .mark)

        // Practice on level 1 after a reversal: a fresh play of the practice copy; a win records nothing, opens nothing.
        let certified: BackwardsAuroraGenerated = try Core.generated(number: 1)
        let neutral: ExperienceAction = try #require(Self.neutralReverse(core))
        #expect(core.apply(neutral) == .accepted)
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.play.records.isEmpty && core.play.spent == 0 && core.play.stage == .playing)
        let practiced: BackwardsAuroraLevel = core.play.level
        #expect(practiced.budget == 40 && certified.level.budget < 40)
        #expect(practiced.opening == certified.level.opening && practiced.target == certified.level.target)
        #expect(practiced.checkpoints == certified.level.checkpoints && practiced.id == certified.level.id)
        #expect(practiced.bendLimit == certified.level.bendLimit
            && practiced.breakingLimit == certified.level.breakingLimit)
        #expect(practiced.shortest == certified.level.shortest && practiced.longest == certified.level.longest)
        #expect(practiced.tutorial == certified.level.tutorial && practiced.seed == certified.level.seed)
        #expect(core.tutorial == .mark && core.levelNumber == 1)
        #expect(core.snapshot(sectionStart: 0, sectionEnd: 1, time: 0).budget == 40)
        _ = Self.win(&core, actions: certified.solution.actions, detours: 0)
        #expect(core.progress.solved.isEmpty && core.progress.frontier == 1)
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: BackwardsAuroraExperienceRule.locked)))
        // Campaign returns to level 1 with its certified budget, fresh.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.play.level == certified.level && core.play.records.isEmpty)
        #expect(core.levelNumber == 1 && core.progress.solved.isEmpty)
        // The progression seed: level 96 (seed 2_395); practice keeps the level, select returns to campaign.
        var seeded: Core = try await Core.prepare(seed: Self.progressionSeed)
        #expect(seeded.levelNumber == 96 && seeded.progress.frontier == 96)
        #expect(seeded.apply(Self.act("mode.practice")) == .accepted)
        #expect(seeded.levelNumber == 96 && seeded.play.level.budget == 40 && seeded.mode == .practice)
        #expect(seeded.apply(Self.act("level.select", [96])) == .accepted)
        let ninetySix: BackwardsAuroraLevel = try Core.level(number: 96)
        #expect(seeded.mode == .campaign && seeded.play.level == ninetySix)
    }

    /// Feature 395 (clarification Q2): the tutorial starts on levels 1 … 3, advances on accepted reversals, ends with
    /// the level, never moves back on undo or redo, can be dismissed, and is not part of the digest.
    @Test func theTutorialAdvancesIsDismissedAndIsNotDigested() async throws {
        for number in 1...3 {
            let generated: BackwardsAuroraGenerated = try Core.generated(number: number)
            var core: Core = try Core.opening(number: number)
            #expect(core.tutorial == .mark, "level \(number)")
            var seen: [BackwardsAuroraTutorialStep] = [core.tutorial]
            for action in generated.solution.actions {
                #expect(core.apply(Self.act(action)) == .accepted)
                if seen.last != core.tutorial { seen.append(core.tutorial) }
            }
            var expected: [BackwardsAuroraTutorialStep] = [.mark, .reverse, .finish, .done]
            if generated.solution.actions.count == 2 { expected = [.mark, .reverse, .done] }
            if generated.solution.actions.count == 1 { expected = [.mark, .done] }
            #expect(seen == expected, "level \(number): \(seen)")
            #expect(core.play.stage == .won && core.tutorial == .done)
        }
        let four: Core = try Core.opening(number: 4)
        #expect(four.tutorial == .done)
        // Undo and redo never move the step; the digest ignores the step.
        var core: Core = try Core.opening(number: 1)
        let fresh: Core = core
        let freshDigest: StateDigest = try Self.digest(fresh)
        let neutral: ExperienceAction = try #require(Self.neutralReverse(core))
        #expect(core.apply(neutral) == .accepted)
        #expect(core.tutorial == .reverse)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.tutorial == .reverse && core.play.wave == fresh.play.wave)
        #expect(try Self.digest(core) == freshDigest)
        #expect(core != fresh)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(core.tutorial == .reverse)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(neutral) == .accepted)
        #expect(core.tutorial == .finish)
        // A failing end ends it: the budget spent on a neutral reversal.
        var failing: Core = try Core.opening(number: 2)
        let failingNeutral: ExperienceAction = try #require(Self.neutralReverse(failing))
        for _ in 0..<failing.play.level.budget { #expect(failing.apply(failingNeutral) == .accepted) }
        #expect(failing.play.stage == .failed && failing.tutorial == .done)
        // Dismissal ends it; later reversals keep it ended; the digest is unchanged by the dismissal.
        var dismissed: Core = try await Core.prepare(seed: 0)
        let before: StateDigest = try Self.digest(dismissed)
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        let dismissedDigest: StateDigest = try Self.digest(dismissed)
        #expect(dismissed.tutorial == .done && dismissedDigest == before)
        #expect(dismissed.apply(neutral) == .accepted)
        #expect(dismissed.tutorial == .done)
        var undismissed: Core = try await Core.prepare(seed: 0)
        #expect(undismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(undismissed.apply(neutral) == .accepted && undismissed == dismissed)
        // Reopening a tutorial level restarts the tutorial at its initial step.
        #expect(dismissed.apply(Self.act("mode.campaign")) == .accepted)
        #expect(dismissed.tutorial == .mark)
    }

    /// Feature 395: a schema-1 payload migrates to schema 2 (the levels up to the saved level open, campaign mode, the
    /// tutorial at its initial step).
    @Test func aSchemaOnePayloadMigrates() throws {
        var core: Core = try Core.opening(number: 7)
        let neutral: ExperienceAction = try #require(Self.neutralReverse(core))
        #expect(core.apply(neutral) == .accepted)
        let records: Data = try JSONEncoder().encode(core.play.records)
        let recordsText: String = String(decoding: records, as: UTF8.self)
        let schemaOne: String = "{\"level\":7,\"records\":" + recordsText + "}"
        let object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: Data(schemaOne.utf8)) as? [String: Any])
        let migrated: [String: Any] = try Core.migratedToSchemaTwo(object)
        #expect(migrated["tutorial"] == nil)
        let data: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
        let restored: Core = try Core.restore(payload: data, seed: 6)
        #expect(restored.levelNumber == 7 && restored.play == core.play)
        #expect(restored.progress.frontier == 7 && restored.progress.solved.isEmpty)
        #expect(restored.mode == .campaign && restored.tutorial == .done)
        #expect(try Self.digest(restored) == Self.digest(core))
        // A tutorial level starts its tutorial at the initial step.
        let emptyTwo: [String: Any] = try Core.migratedToSchemaTwo(["level": 2, "records": [Any]()])
        let tutorialLevel: Core = try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: emptyTwo, options: [.sortedKeys]), seed: 0)
        #expect(tutorialLevel.levelNumber == 2 && tutorialLevel.tutorial == .mark)
        #expect(tutorialLevel.progress.frontier == 2)
        #expect(throws: BackwardsAuroraRestoreRefusal.damaged) {
            try Core.migratedToSchemaTwo(["level": "7"])
        }
        #expect(throws: BackwardsAuroraRestoreRefusal.damaged) {
            try Core.migratedToSchemaTwo(["level": 7])
        }
        #expect(Core.migrations.currentVersion == 3)
    }

    /// Feature 395: an engine restores a schema-1 envelope through the migration chain.
    @Test func theEngineMigratesASchemaOneEnvelope() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 4)
        try engine.activate()
        var expected: Core = try Core.opening(number: 5)
        let neutral: ExperienceAction = try #require(Self.neutralReverse(expected))
        #expect(engine.handle(control: neutral.control, values: neutral.values) == .accepted)
        let saved: ExperienceSnapshot = try engine.snapshot()
        #expect(expected.apply(neutral) == .accepted)
        let records: String = String(decoding: try JSONEncoder().encode(expected.play.records), as: UTF8.self)
        let schemaOne: String = "{\"level\":5,\"records\":" + records + "}"
        let old = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: saved.seed,
                                         stepIndex: saved.stepIndex, digest: saved.digest,
                                         payload: Data(schemaOne.utf8))
        try engine.restore(old)
        #expect(try engine.digest() == saved.digest)
    }

    /// Feature 395: the digest carries the progress and the mode but never the tutorial step.
    @Test func theDigestCarriesProgressAndModeButNotTheTutorial() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        let base: StateDigest = try Self.digest(core)
        // Progress: a level-1 win and back to level 1 fresh differs from the opening only in progress.
        var won: Core = core
        _ = Self.win(&won, actions: try Core.generated(number: 1).solution.actions, detours: 0)
        #expect(won.apply(Self.act("level.select", [1])) == .accepted)
        #expect(won.play == core.play && won.mode == core.mode && won.progress != core.progress)
        #expect(try Self.digest(won) != base)
        // Mode: practice differs (its level is the practice copy); campaign back restores the digest.
        var practice: Core = core
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(try Self.digest(practice) != base)
        #expect(practice.apply(Self.act("mode.campaign")) == .accepted)
        #expect(try Self.digest(practice) == base && practice == core)
        // Tutorial: dismissing changes `==` but not the digest.
        var dismissed: Core = core
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        let dismissedDigest: StateDigest = try Self.digest(dismissed)
        #expect(dismissed != core && dismissedDigest == base)
        // The progression seed: a reset returns the opening digest after progression actions.
        var seeded: Core = try await Core.prepare(seed: Self.progressionSeed)
        let seededDigest: StateDigest = try Self.digest(seeded)
        #expect(seeded.apply(Self.act("mode.daily", [2026, 11, 23])) == .accepted)
        #expect(try Self.digest(seeded) != seededDigest)
        seeded.reset()
        #expect(try Self.digest(seeded) == seededDigest && seeded.mode == .campaign)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        var core: Core = try await Core.prepare(seed: 31)
        let generated: BackwardsAuroraGenerated = try Core.generated(number: 32)
        // Every action of the solution but the last (none of them ends the play), then an undo.
        try #require(generated.solution.actions.count >= 2)
        for step in generated.solution.actions.dropLast() { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .playing)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let payload: Data = try core.snapshotPayload()
        #expect(try core.snapshotPayload() == payload)
        let text: String = try #require(String(data: payload, encoding: .utf8))
        #expect(text.hasPrefix("{\"level\":32,\"mode\":{\"mode\":\"campaign\"},\"progress\":"
            + "{\"frontier\":32,\"solved\":[]},\"records\":["))
        #expect(text.hasSuffix(",\"tutorial\":\"done\"}"))
        let restored: Core = try Core.restore(payload: payload, seed: 31)
        let restoredDigest: StateDigest = try Self.digest(restored)
        let savedDigest: StateDigest = try Self.digest(core)
        #expect(restored == core && restoredDigest == savedDigest)
        #expect(restored.play.canRedo && restored.openingNumber == 32)
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

        #expect(throws: BackwardsAuroraRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 31)
        }
        #expect(throws: BackwardsAuroraRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 31)
        }
        #expect(throws: BackwardsAuroraRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"32\",\"records\":[]}".utf8), seed: 31)
        }
        // A schema-1 payload is not a schema-2 one (it migrates only through the chain).
        #expect(throws: BackwardsAuroraRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":32,\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: BackwardsAuroraRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":0").utf8),
                             seed: 31)
        }
        #expect(throws: BackwardsAuroraRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":101").utf8),
                             seed: 31)
        }
        // Damaged progress or mode: a frontier outside 1 … 100, an unknown mode, a daily mode naming another level, an
        // unknown tutorial step.
        let damaged: [String] = [
            text.replacingOccurrences(of: "\"frontier\":32", with: "\"frontier\":0"),
            text.replacingOccurrences(of: "\"frontier\":32", with: "\"frontier\":101"),
            text.replacingOccurrences(of: "{\"mode\":\"campaign\"}", with: "{\"mode\":\"arcade\"}"),
            text.replacingOccurrences(of: "{\"mode\":\"campaign\"}", with: "{\"level\":5,\"mode\":\"daily\"}"),
            text.replacingOccurrences(of: "\"tutorial\":\"done\"", with: "\"tutorial\":\"later\""),
        ]
        for variant in damaged {
            #expect(variant != text)
            #expect(throws: BackwardsAuroraRestoreRefusal.damaged) {
                try Core.restore(payload: Data(variant.utf8), seed: 31)
            }
        }
        // A daily mode naming its own level restores; a practice payload replays on the practice copy.
        let dailyText: String = text.replacingOccurrences(of: "{\"mode\":\"campaign\"}",
                                                          with: "{\"level\":32,\"mode\":\"daily\"}")
        let daily: Core = try Core.restore(payload: Data(dailyText.utf8), seed: 31)
        #expect(daily.mode == .daily(level: 32) && daily.play == core.play)
        var practice: Core = try Core.opening(number: 32)
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        let practiceNeutral: ExperienceAction = try #require(Self.neutralReverse(practice))
        #expect(practice.apply(practiceNeutral) == .accepted)
        let practiceRestored: Core = try Core.restore(payload: try practice.snapshotPayload(), seed: 31)
        #expect(practiceRestored == practice && practiceRestored.play.level.budget == 40)
        // The same records on another level: the records carry level 32's seed.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":1").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: BackwardsAuroraRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: wrongLevel, seed: 31)
        }
        // A record of a newer schema.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: BackwardsAuroraRestoreRefusal.kernel(.malformed("schema 0"))) {
            try Core.restore(payload: newer, seed: 31)
        }
        // A trace that no longer replays: an edited next fingerprint.
        let first: BackwardsAuroraRecord = try #require(core.play.records.first)
        let edited: Data = Data(text.replacingOccurrences(of: first.next, with: String(repeating: "0", count: 64)).utf8)
        #expect(edited != payload)
        var editedRefused: Bool = false
        do {
            _ = try Core.restore(payload: edited, seed: 31)
        } catch let refusal as BackwardsAuroraRestoreRefusal {
            if case .kernel(.malformed) = refusal { editedRefused = true }
        }
        #expect(editedRefused)
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 5)
        try engine.activate()
        #expect(engine.handle(control: "wave.reverse", values: [0, 1]) == .accepted)
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

    @Test func theSnapshotMirrorsThePlay() async throws {
        // Level 1 after the first reversal of its solution: the snapshot copies the kernel exactly.
        var core: Core = try await Core.prepare(seed: 0)
        let generated: BackwardsAuroraGenerated = try Core.generated(number: 1)
        let first: BackwardsAuroraAction = try #require(generated.solution.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        let play: BackwardsAuroraPlay = core.play
        let level: BackwardsAuroraLevel = play.level
        let snapshot: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: 2, sectionEnd: 5, time: 2.5)
        #expect(snapshot.samples == play.wave.samples && snapshot.target == level.target.samples)
        #expect(snapshot.checkpoints == level.checkpoints && snapshot.matched == play.matched)
        #expect(snapshot.bendLimit == level.bendLimit && snapshot.tear == nil)
        var kinks: [Int] = []
        for k in 1...(play.wave.count - 2) where abs(play.wave.bend(at: k)) > level.bendLimit { kinks.append(k) }
        #expect(snapshot.kinks == kinks && kinks.count == 4)
        #expect(snapshot.sectionStart == 2 && snapshot.sectionEnd == 5)
        #expect(snapshot.stage == play.stage && snapshot.failure == nil && snapshot.levelNumber == 1)
        #expect(snapshot.spent == 1 && snapshot.budget == level.budget && snapshot.time == 2.5)
        // The section is clamped to the wave: 0 ≤ start < end ≤ N − 1.
        let clamped: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: 40, sectionEnd: -3, time: 0)
        #expect(clamped.sectionStart == 12 && clamped.sectionEnd == 13)
        let low: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: -5, sectionEnd: 0, time: 0)
        #expect(low.sectionStart == 0 && low.sectionEnd == 1)
        let nan: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: 2, sectionEnd: 5, time: .nan)
        #expect(nan.time == 0 && core.snapshot(sectionStart: 2, sectionEnd: 5, time: .infinity) == nan)
    }

    @Test func theTierAndTheSnapshotTimeNeverTouchTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: Self.fixtureSeed)
        let neutral: ExperienceAction = try #require(Self.neutralReverse(core))
        #expect(core.apply(neutral) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let layers: [Int] = [3, 3, 2, 1, 1]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.trailingLayers == layers[index])
            #expect(core.renderTier == BackwardsAuroraTier.of(clamped[index]))
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: BackwardsAuroraSceneSnapshot = core.snapshot(sectionStart: 0, sectionEnd: 1, time: time)
            #expect(snapshot.stage == core.play.stage && snapshot.spent == core.play.spent)
            #expect(snapshot.levelNumber == core.levelNumber && snapshot.time.isFinite)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }

    // MARK: Feature 397 (R02-G10-07) T-R02G1007-003: traces, replay, the sound setting, migrations, reconciliation

    /// Feature 397: a won campaign play records its effective reversals as a verified result (an undone detour left out
    /// but counted in the reversals made); replay plays the trace reversal by reversal, refuses other play actions, ends
    /// with replay-end and never changes progress; stop returns to campaign.
    @Test func replayPlaysTheStoredTraceAndChangesNothing() throws {
        var core: Core = try Core.opening(number: 1)
        let certified: BackwardsAuroraGenerated = try Core.generated(number: 1)
        let actions: [BackwardsAuroraAction] = certified.solution.actions
        #expect(core.apply(Self.act("replay.start", [1])) == .rejected(.rule(code: "r02-g10.no-replay")))
        #expect(core.apply(Self.act("replay.step")) == .rejected(.rule(code: "r02-g10.no-replay")))
        #expect(core.apply(Self.act("replay.stop")) == .rejected(.rule(code: "r02-g10.no-replay")))
        // A detour that is undone stays out of the trace but counts as a reversal made.
        #expect(core.apply(Self.act(actions[0])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        for action in actions { #expect(core.apply(Self.act(action)) == .accepted) }
        #expect(core.play.stage == .won)
        let result: BackwardsAuroraProgress.Result = try #require(core.progress.solved[1])
        #expect(result.verified && result.trace == actions && result.reversalsMade == actions.count + 1)
        let progress: BackwardsAuroraProgress = core.progress
        #expect(core.apply(Self.act("replay.start", [2])) == .rejected(.rule(code: "r02-g10.no-replay")))
        #expect(core.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(core.mode == .replay(level: 1) && core.tutorial == .done && core.play.records.isEmpty)
        let refusedControls: [String] = ["wave.reverse", "play.undo", "play.redo", "level.next", "level.select",
                                         "mode.daily", "mode.practice", "mode.campaign"]
        let refusedValues: [[Double]] = [[0, 1], [], [], [], [1], [2026, 11, 23], [], []]
        for index in refusedControls.indices {
            let before: Core = core
            #expect(core.apply(Self.act(refusedControls[index], refusedValues[index]))
                == .rejected(.rule(code: "r02-g10.replay")), "\(refusedControls[index])")
            #expect(core == before)
        }
        #expect(core.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted)
        var reference: BackwardsAuroraPlay = try Core.freshPlay(of: certified.level)
        for action in actions {
            #expect(core.apply(Self.act("replay.step")) == .accepted)
            try reference.apply(action, expecting: reference.fingerprint)
            #expect(core.play.fingerprint == reference.fingerprint)
        }
        #expect(core.play.stage == .won && core.progress == progress)
        #expect(core.outcome == ExperienceOutcome(code: Core.wonCode))
        #expect(core.apply(Self.act("replay.step")) == .rejected(.rule(code: "r02-g10.replay-end")))
        #expect(core.apply(Self.act("replay.step")) == .rejected(.rule(code: "r02-g10.replay-end")))
        // A saved replay round-trips.
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && restored.reconciliationDropped == 0)
        #expect(core.apply(Self.act("replay.stop")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.soundOn && core.progress == progress)
        #expect(core.play.records.isEmpty)
        #expect(core.apply(Self.act("replay.stop")) == .rejected(.rule(code: "r02-g10.no-replay")))
        // A replay stopped before its end returns to campaign with the progress unchanged.
        #expect(core.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(core.apply(Self.act("replay.step")) == .accepted)
        #expect(core.apply(Self.act("replay.stop")) == .accepted)
        #expect(core.mode == .campaign && core.progress == progress)
    }

    /// Feature 397: the sound choice is snapshotted and in `==`, never in the digest; reset turns it off.
    @Test func theSoundChoiceIsSavedButNotDigested() throws {
        var core: Core = try Core.opening(number: 4)
        let before: StateDigest = try Self.digest(core)
        #expect(!core.soundOn)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted && core.soundOn)
        #expect(try Self.digest(core) == before)
        #expect(core.apply(Self.act("settings.sound", [0.5])) == .rejected(.rule(code: "r02-g10.not-whole")))
        let payload: Data = try core.snapshotPayload()
        #expect(String(decoding: payload, as: UTF8.self).contains("\"sound\":true"))
        let restored: Core = try Core.restore(payload: payload, seed: 3)
        #expect(restored.soundOn && restored == core)
        var off: Core = core
        #expect(off.apply(Self.act("settings.sound", [0])) == .accepted && !off.soundOn)
        #expect(off != core)
        #expect(try Self.digest(off) == before)
        core.reset()
        #expect(!core.soundOn)
    }

    /// A schema-2 object (as feature 395 wrote it: results without `trace` or `verified`) of level 3 with level 1 won
    /// with 4 reversals made (smallest 2: 2 stars) and the frontier at 5.
    static func schemaTwoObject() throws -> [String: Any] {
        var progress: BackwardsAuroraProgress = BackwardsAuroraProgress()
        progress.record(level: 1, reversalsMade: 4, smallest: 2, mode: .campaign)
        progress.open(through: 5)
        var progressObject: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: try Core.payloadEncoder().encode(progress)) as? [String: Any])
        var solved: [[String: Any]] = try #require(progressObject["solved"] as? [[String: Any]])
        for index in solved.indices {
            solved[index].removeValue(forKey: "trace")
            solved[index].removeValue(forKey: "verified")
        }
        progressObject["solved"] = solved
        return ["level": 3, "records": [Any](), "progress": progressObject, "mode": ["mode": "campaign"],
                "tutorial": "done"]
    }

    /// Feature 397: a schema-2 object migrates to schema 3 (empty traces, unverified, sound off) and restores with its
    /// progress; a schema-1 object migrates through 2 to 3; the engine restores schema-1 and schema-2 envelopes.
    @Test func schemaOneAndTwoMigrateToThree() async throws {
        let two: [String: Any] = try Self.schemaTwoObject()
        let three: [String: Any] = try Core.migratedToSchemaThree(two)
        #expect(three["sound"] as? Bool == false)
        let progressThree: [String: Any] = try #require(three["progress"] as? [String: Any])
        let solvedThree: [[String: Any]] = try #require(progressThree["solved"] as? [[String: Any]])
        #expect(solvedThree.count == 1 && solvedThree[0]["verified"] as? Bool == false)
        #expect((solvedThree[0]["trace"] as? [Any])?.isEmpty == true)
        let restored: Core = try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: three, options: [.sortedKeys]), seed: 2)
        #expect(restored.progress.frontier == 5 && restored.reconciliationDropped == 0)
        #expect(restored.progress.solved[1] == BackwardsAuroraProgress.Result(reversalsMade: 4, stars: 2))
        #expect(!restored.soundOn && restored.levelNumber == 3 && restored.mode == .campaign)
        #expect(throws: BackwardsAuroraRestoreRefusal.damaged) { try Core.migratedToSchemaThree(["level": 1]) }
        #expect(throws: BackwardsAuroraRestoreRefusal.damaged) {
            try Core.migratedToSchemaThree(["level": 1, "progress": ["frontier": 1]])
        }
        // 1 → 3: no won levels, the levels up to the saved level open, campaign, sound off.
        let one: [String: Any] = ["level": 6, "records": [Any]()]
        let oneToThree: [String: Any] = try Core.migratedToSchemaThree(try Core.migratedToSchemaTwo(one))
        let fromOne: Core = try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: oneToThree, options: [.sortedKeys]), seed: 0)
        #expect(fromOne.levelNumber == 6 && fromOne.progress.frontier == 6 && fromOne.progress.solved.isEmpty)
        #expect(!fromOne.soundOn && fromOne.mode == .campaign && fromOne.reconciliationDropped == 0)
        // The engine applies the chain to schema-1 and schema-2 envelopes.
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 2)
        try engine.activate()
        let saved: ExperienceSnapshot = try engine.snapshot()
        let twoData: Data = try JSONSerialization.data(withJSONObject: two, options: [.sortedKeys])
        let envelopeTwo = try ExperienceSnapshot(experience: id, schemaVersion: 2, seed: saved.seed,
                                                 stepIndex: saved.stepIndex, digest: try Self.digest(restored),
                                                 payload: twoData)
        try engine.restore(envelopeTwo)
        #expect(try engine.digest() == Self.digest(restored))
        let oneData: Data = try JSONSerialization.data(withJSONObject: one, options: [.sortedKeys])
        let envelopeOne = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: saved.seed,
                                                 stepIndex: saved.stepIndex, digest: try Self.digest(fromOne),
                                                 payload: oneData)
        try engine.restore(envelopeOne)
        #expect(try engine.digest() == Self.digest(fromOne))
    }

    /// Feature 397: an edited verified result is dropped on restore and counted, the frontier kept as saved; an honest
    /// one survives; a saved replay of a dropped result returns to campaign at that level.
    @Test func editedResultsAreDroppedOnRestore() throws {
        let certified: BackwardsAuroraGenerated = try Core.generated(number: 2)
        let trace: [BackwardsAuroraAction] = certified.solution.actions
        let smallest: Int = certified.solution.smallest
        var honest: BackwardsAuroraProgress = BackwardsAuroraProgress()
        honest.open(through: 7)
        honest.record(level: 2, reversalsMade: trace.count, smallest: smallest, trace: trace)
        var edited: BackwardsAuroraProgress = honest
        // The same trace claimed with one reversal fewer than it holds.
        edited.drop(level: 2)
        edited.record(level: 2, reversalsMade: trace.count - 1, smallest: smallest, trace: trace)
        var core: Core = try Core.opening(number: 2)
        #expect(core.apply(Self.act(trace[0])) == .accepted)
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: try core.snapshotPayload()) as? [String: Any])
        object["progress"] = try JSONSerialization.jsonObject(with: try Core.payloadEncoder().encode(honest))
        let kept: Core = try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), seed: 1)
        #expect(kept.reconciliationDropped == 0 && kept.progress == honest)
        object["progress"] = try JSONSerialization.jsonObject(with: try Core.payloadEncoder().encode(edited))
        let checked: Core = try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), seed: 1)
        #expect(checked.reconciliationDropped == 1 && checked.progress.solved[2] == nil)
        #expect(checked.progress.frontier == 7 && checked.play == core.play)
        // The dropped count is not state: not in the digest or `==`.
        #expect(try Self.digest(checked) == Self.digest(try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), seed: 1)))
        // A saved replay of the edited result: the result is dropped, so the restore is campaign at level 2.
        object["mode"] = ["mode": "replay", "level": 2]
        object["records"] = [Any]()
        let replay: Core = try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), seed: 1)
        #expect(replay.mode == .campaign && replay.levelNumber == 2 && replay.reconciliationDropped == 1)
        // A replay mode naming another level is damaged.
        object["mode"] = ["mode": "replay", "level": 3]
        #expect(throws: BackwardsAuroraRestoreRefusal.damaged) {
            try Core.restore(payload: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
                             seed: 1)
        }
    }
}
