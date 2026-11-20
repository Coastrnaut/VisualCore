// AuroraLoomExperienceCoreTests — feature 303 (R02-G01-03) T-R02G0103-005 (FR-R02G0103-005; clarification Q5). The
// adapter core: the shared conformance checks pass; the seed picks level `seed % 100 + 1` deterministically in stage
// `playing`; a legal move changes the digest and an illegal one is refused with the state unchanged; undo, redo and
// the certified solution (outcome `won`); `level.next` wraps 100 to 1; the snapshot round trip and refused payloads;
// the quality tier and the presenter's snapshot time never touch the digest. Feature 305 (R02-G01-05) T-R02G0105-004:
// schema 2 (progress, mode, tutorial), the migration of a schema-1 payload, `level.next` to the next open level,
// `level.select` of open levels only, daily and practice modes, the tutorial and stars through the port. Explicit types,
// plain loops, short runs.
import Foundation
import Testing
@testable import AuroraLoomCore
import VisualCoreDiagnostics
import VisualCoreExperience

@Suite struct AuroraLoomExperienceCoreTests {
    typealias Core = AuroraLoomExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The `ribbon.move` action for a kernel move.
    static func action(_ move: AuroraLoomMove) -> ExperienceAction {
        let control: Double = move.control == .wave ? 0 : 1
        return ExperienceAction(control: "ribbon.move", values: [Double(move.ribbon), control, Double(move.step)],
                                step: 0)
    }

    /// A step for ribbon 0's wave that differs from the current one.
    static func otherWave(_ core: Core) -> Int {
        (core.play.steps.wave[0] + 1) % 16
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        let actions: [ScriptedAction] = [ScriptedAction("ribbon.move", [1, 1, 7]),
                                         ScriptedAction("ribbon.move", [2, 0, 3]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("play.undo"), ScriptedAction("level.next"),
                                         ScriptedAction("ribbon.move", [0, 0, 9]), ScriptedAction("tutorial.dismiss"),
                                         ScriptedAction("mode.practice"), ScriptedAction("ribbon.move", [1, 1, 4]),
                                         ScriptedAction("mode.daily", [2026, 11, 20]), ScriptedAction("mode.campaign"),
                                         ScriptedAction("level.select", [1])]
        let rejected: [ScriptedAction] = [ScriptedAction("ribbon.move", [0, 0, 0.5]),
                                          ScriptedAction("ribbon.move", [0.5, 1, 2]),
                                          ScriptedAction("ribbon.move", [3, 0, 1]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus"),
                                          ScriptedAction("level.select", [0]), ScriptedAction("level.select", [2.5]),
                                          ScriptedAction("mode.daily", [2026, 2, 30]),
                                          ScriptedAction("mode.daily", [2026, 13, 1])]
        let plan = ConformancePlan(seeds: [0, 41, 99, 1_000_003], stepsPerSegment: 2, actions: actions,
                                   rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g01.aurora-loom" && Core.schemaVersion == 3)
        #expect(Core.digestDomain == "r02-g01.aurora-loom.v3")
        #expect(Core.controls.map(\.id) == Core.actionIDs && Core.actionIDs.count == 12)
        #expect(Core.controls[0].ranges == [0...2, 0...1, 0...15])
        #expect(Core.controls[4].ranges == [1...100])
        #expect(Core.controls[5].ranges == [1...9999, 1...12, 1...31])
        let bare: [Int] = [1, 2, 3, 6, 7, 8]
        for index in bare { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.stepDuration == 1.0 / 120)
        #expect(Core.qualityTiers == 3)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        #expect(elements == [1, 0.6, 0.2] && iterations == [1, 0.5, 0.25] && passes == [2, 1, 0])
    }

    @Test func theSeedPicksTheLevelDeterministically() async throws {
        let seeds: [UInt64] = [0, 2, 99, 100, 257]
        let numbers: [Int] = [1, 3, 100, 1, 58]
        for index in seeds.indices {
            let first: Core = try await Core.prepare(seed: seeds[index])
            let second: Core = try await Core.prepare(seed: seeds[index])
            #expect(first.levelNumber == numbers[index] && first.openingNumber == numbers[index])
            #expect(first == second)
            #expect(try Self.digest(first) == Self.digest(second))
            let expected: AuroraLoomLevel = try AuroraLoomGenerator.generate(
                AuroraLoomManifest.entries[numbers[index] - 1]).level
            #expect(first.play.level == expected)
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
        }
    }

    @Test func aLegalMoveChangesTheDigestAndIllegalOnesChangeNothing() async throws {
        var core: Core = try await Core.prepare(seed: 7)
        let opening: StateDigest = try Self.digest(core)
        let current: Int = core.play.steps.wave[0]
        let illegal: [[Double]] = [[0, 0, Double(current)], [0, 0, 1.5], [0, 0.25, 3], [3, 0, 1], [0, 2, 1],
                                   [0, 0, 16], [0, 0, -1], [0, 0, .nan], [0, 0], [0, 0, 1, 1]]
        for values in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(ExperienceAction(control: "ribbon.move", values: values, step: 0))
            #expect(!result.isAccepted, "\(values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening, "\(values)")
        }
        var noChange: Core = core
        #expect(noChange.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, Double(current)], step: 0))
            == .rejected(.rule(code: "r02-g01.move")))
        #expect(noChange.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, 1.5], step: 0))
            == .rejected(.rule(code: AuroraLoomExperienceRule.notWhole)))
        #expect(noChange.apply(ExperienceAction(control: "play.undo", step: 0))
            == .rejected(.rule(code: "r02-g01.move")))
        #expect(noChange.apply(ExperienceAction(control: "nope", step: 0)) == .rejected(.unknownControl("nope")))
        let step: Int = Self.otherWave(core)
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, Double(step)], step: 0))
            == .accepted)
        #expect(core.play.steps.wave[0] == step && core.play.records.count == 1)
        #expect(try Self.digest(core) != opening)
    }

    @Test func undoAndRedo() async throws {
        var core: Core = try await Core.prepare(seed: 12)
        let start: AuroraLoomSteps = core.play.steps
        let step: Int = (core.play.steps.phase[1] + 5) % 16
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [1, 1, Double(step)], step: 0))
            == .accepted)
        let moved: AuroraLoomSteps = core.play.steps
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(core.apply(ExperienceAction(control: "play.undo", step: 0)) == .accepted)
        #expect(core.play.steps == start && core.play.spent == 0)
        #expect(try Self.digest(core) != movedDigest)
        #expect(core.apply(ExperienceAction(control: "play.redo", step: 0)) == .accepted)
        #expect(core.play.steps == moved && core.play.spent == 1 && core.play.records.count == 3)
        #expect(core.apply(ExperienceAction(control: "play.redo", step: 0)) == .rejected(.rule(code: "r02-g01.move")))
    }

    @Test func theCertifiedSolutionWins() async throws {
        let seeds: [UInt64] = [0, 24, 63, 99]
        for seed in seeds {
            var core: Core = try await Core.prepare(seed: seed)
            let generated: AuroraLoomGenerated = try AuroraLoomGenerator.generate(
                AuroraLoomManifest.entries[core.levelNumber - 1])
            for move in generated.solution.moves {
                #expect(core.apply(Self.action(move)) == .accepted, "seed \(seed) \(move)")
            }
            #expect(core.play.stage == .won, "seed \(seed)")
            #expect(core.outcome?.code == "won", "seed \(seed)")
            let won: Core = core
            #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, 0], step: 0))
                == .rejected(.rule(code: "r02-g01.stage")))
            #expect(core == won)
            core.reset()
            #expect(core.play.stage == .playing && core.outcome == nil && core.play.records.isEmpty)
        }
    }

    @Test func nextLevelGoesToTheNextOpenLevelAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 98)
        #expect(core.levelNumber == 99 && core.progress.frontier == 99 && core.mode == .campaign)
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, Double(Self.otherWave(core))],
                                            step: 0)) == .accepted)
        // Level 100 is not open yet: the next open level after 99, in cyclic order, is 1.
        #expect(core.apply(ExperienceAction(control: "level.next", step: 0)) == .accepted)
        #expect(core.levelNumber == 1 && core.play.records.isEmpty && core.play.stage == .playing)
        #expect(core.apply(ExperienceAction(control: "level.next", step: 0)) == .accepted)
        #expect(core.levelNumber == 2)
        core.reset()
        let fresh: Core = try await Core.prepare(seed: 98)
        let resetDigest: StateDigest = try Self.digest(core)
        let freshDigest: StateDigest = try Self.digest(fresh)
        #expect(core == fresh && resetDigest == freshDigest)
        // Winning 99 in campaign opens 100; level.next then goes there, and from 100 wraps to 1.
        let certified: AuroraLoomGenerated = try Core.generated(number: 99)
        for move in certified.solution.moves { #expect(core.apply(Self.action(move)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.frontier == 100)
        #expect(core.progress.solved[99] == AuroraLoomProgress.Result(bestMoves: certified.solution.shortest, stars: 3,
                                                                      trace: certified.solution.moves, verified: true))
        #expect(core.apply(ExperienceAction(control: "level.next", step: 0)) == .accepted)
        #expect(core.levelNumber == 100)
        #expect(core.apply(ExperienceAction(control: "level.next", step: 0)) == .accepted)
        #expect(core.levelNumber == 1)
    }

    @Test func selectDailyPracticeAndCampaign() async throws {
        var core: Core = try await Core.prepare(seed: 4)
        #expect(core.levelNumber == 5 && core.tutorial == .done)
        let before: Core = core
        #expect(core.apply(ExperienceAction(control: "level.select", values: [6], step: 0))
            == .rejected(.rule(code: AuroraLoomExperienceRule.locked)))
        #expect(core == before)
        #expect(core.apply(ExperienceAction(control: "level.select", values: [2], step: 0)) == .accepted)
        #expect(core.levelNumber == 2 && core.mode == .campaign && core.tutorial != .done)
        // Daily: 2026-01-02 is level 38, closed but playable; a win records stars without opening levels.
        #expect(core.apply(ExperienceAction(control: "mode.daily", values: [2026, 1, 2], step: 0)) == .accepted)
        #expect(core.levelNumber == 38 && core.mode == .daily(level: 38))
        let daily: AuroraLoomGenerated = try Core.generated(number: 38)
        for move in daily.solution.moves { #expect(core.apply(Self.action(move)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.frontier == 5 && core.progress.solved[38]?.stars == 3)
        let dated: Core = core
        #expect(core.apply(ExperienceAction(control: "mode.daily", values: [2026, 2, 29], step: 0))
            == .rejected(.rule(code: AuroraLoomExperienceRule.date)))
        #expect(core == dated)
        // Campaign from a closed daily level returns to the highest open level.
        #expect(core.apply(ExperienceAction(control: "mode.campaign", step: 0)) == .accepted)
        #expect(core.levelNumber == 5 && core.mode == .campaign)
        // Practice: the allowance is 64 and a win changes no progress.
        #expect(core.apply(ExperienceAction(control: "mode.practice", step: 0)) == .accepted)
        #expect(core.mode == .practice && core.play.level.allowance == Core.practiceAllowance)
        let progress: AuroraLoomProgress = core.progress
        let practice: AuroraLoomGenerated = try Core.generated(number: 5)
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, Double(Self.otherWave(core))],
                                            step: 0)) == .accepted)
        #expect(core.apply(ExperienceAction(control: "play.undo", step: 0)) == .accepted)
        for move in practice.solution.moves { #expect(core.apply(Self.action(move)) == .accepted) }
        #expect(core.play.stage == .won && core.progress == progress)
        // The practice state survives a snapshot round trip.
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 4)
        #expect(restored == core && restored.play.level.allowance == Core.practiceAllowance)
    }

    @Test func tutorialFollowsThePlayerAndCanBeDismissed() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let hint: AuroraLoomHint = try #require(core.hint(level: 1))
        #expect(core.tutorial == .wave(ribbon: hint.ribbon))
        let wave: Int = (core.play.steps.wave[hint.ribbon] + 1) % 16
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [Double(hint.ribbon), 0, Double(wave)],
                                            step: 0)) == .accepted)
        guard case .phase = core.tutorial else {
            Issue.record("expected the phase step, got \(core.tutorial)")
            return
        }
        #expect(core.apply(ExperienceAction(control: "play.undo", step: 0)) == .accepted)
        guard case .phase = core.tutorial else {
            Issue.record("undo moved the tutorial back: \(core.tutorial)")
            return
        }
        let digest: StateDigest = try Self.digest(core)
        #expect(core.apply(ExperienceAction(control: "tutorial.dismiss", step: 0)) == .accepted)
        let dismissed: StateDigest = try Self.digest(core)
        // The tutorial step is not in the digest: undo must restore the earlier digest exactly (R2-G01-INV-05).
        #expect(core.tutorial == .done && dismissed == digest)
        #expect(core.apply(ExperienceAction(control: "tutorial.dismiss", step: 0)) == .accepted)
        #expect(core.tutorial == .done)
        // A failure is explained; no hint is given then.
        var failing: Core = try await Core.prepare(seed: 20)
        while failing.play.stage == .playing {
            let ribbon: Int = failing.play.spent % 3
            let current: Int = failing.play.steps.phase[ribbon]
            var next: Int = (current + 1) % 16
            while next != current {
                var trial: Core = failing
                if trial.apply(ExperienceAction(control: "ribbon.move", values: [Double(ribbon), 1, Double(next)],
                                                step: 0)) == .accepted, trial.play.stage != .won {
                    failing = trial
                    break
                }
                next = (next + 1) % 16
            }
            if next == current { break }
        }
        #expect(failing.play.stage == .failed)
        if failing.play.stage == .failed {
            let explanation: AuroraLoomFailureExplanation = try #require(failing.failureExplanation)
            #expect(explanation.mismatch == failing.play.failure && failing.hint(level: 3) == nil)
            #expect(failing.outcome?.code == Core.failedCode)
            var rewound: Core = failing
            #expect(rewound.apply(ExperienceAction(control: "play.undo", step: 0)) == .accepted)
            #expect(rewound.play.stage == .playing && rewound.play.spent == failing.play.spent - 1)
            #expect(rewound.failureExplanation == nil && rewound.outcome == nil)
        }
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        var core: Core = try await Core.prepare(seed: 31)
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [2, 1, Double((core.play.steps.phase[2]
            + 3) % 16)], step: 0)) == .accepted)
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, Double(Self.otherWave(core))],
                                            step: 0)) == .accepted)
        #expect(core.apply(ExperienceAction(control: "play.undo", step: 0)) == .accepted)
        let payload: Data = try core.snapshotPayload()
        #expect(try core.snapshotPayload() == payload)
        let restored: Core = try Core.restore(payload: payload, seed: 31)
        let restoredDigest: StateDigest = try Self.digest(restored)
        let savedDigest: StateDigest = try Self.digest(core)
        #expect(restored == core && restoredDigest == savedDigest)
        #expect(restored.play.canRedo && restored.openingNumber == 32)
        var redone: Core = restored
        var original: Core = core
        #expect(redone.apply(ExperienceAction(control: "play.redo", step: 0)) == .accepted)
        #expect(original.apply(ExperienceAction(control: "play.redo", step: 0)) == .accepted)
        #expect(redone == original)
        let other: Core = try Core.restore(payload: payload, seed: 5)
        #expect(other == core && other.openingNumber == 6)

        #expect(throws: AuroraLoomRestoreRefusal.damaged) { try Core.restore(payload: Data("{}".utf8), seed: 31) }
        #expect(throws: AuroraLoomRestoreRefusal.damaged) { try Core.restore(payload: Data("nope".utf8), seed: 31) }
        #expect(throws: AuroraLoomRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":3,\"records\":[]}".utf8), seed: 31)
        }
        let rest: String = ",\"mode\":{\"campaign\":{}},\"progress\":{\"frontier\":1,\"solved\":[]},\"records\":[]}"
        #expect(throws: AuroraLoomRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data(("{\"level\":0" + rest).utf8), seed: 31)
        }
        #expect(throws: AuroraLoomRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data(("{\"level\":101" + rest).utf8), seed: 31)
        }
        let text: String = try #require(String(data: payload, encoding: .utf8))
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":33").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: AuroraLoomRestoreRefusal.self) { try Core.restore(payload: wrongLevel, seed: 31) }
    }

    @Test func aSchemaOnePayloadMigrates() async throws {
        let objectOne: [String: Any] = ["level": 2, "records": [Any]()]
        let migrated: [String: Any] = try Core.migratedToSchemaTwo(objectOne)
        let data: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
        let restored: Core = try Core.restore(payload: data, seed: 1)
        let expected: Core = try await Core.prepare(seed: 1)
        #expect(restored == expected && restored.mode == .campaign && restored.progress.frontier == 2)
        #expect(restored.tutorial == expected.tutorial && restored.tutorial != .done)
        #expect(throws: AuroraLoomRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": "x"]) }
        #expect(Core.migrations.currentVersion == 3)
    }

    // Feature 307 (R02-G01-07) T-R02G0107-003: migration 2 → 3, reconciliation on restore and replay.

    @Test func aSchemaTwoPayloadMigratesWithResultsUnverified() async throws {
        let objectTwo: [String: Any] = [
            "level": 3, "records": [Any](), "mode": "campaign",
            "progress": ["frontier": 4, "solved": [["level": 1, "bestMoves": 6, "stars": 2]]],
        ]
        let migrated: [String: Any] = try Core.migratedToSchemaThree(objectTwo)
        let progress: [String: Any] = try #require(migrated["progress"] as? [String: Any])
        let solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
        #expect(solved[0]["verified"] as? Bool == false && (solved[0]["trace"] as? [Any])?.isEmpty == true)
        var modeObject: [String: Any] = migrated
        modeObject["mode"] = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(AuroraLoomMode.campaign))
        let data: Data = try JSONSerialization.data(withJSONObject: modeObject, options: [.sortedKeys])
        let restored: Core = try Core.restore(payload: data, seed: 2)
        #expect(restored.progress.solved[1] == AuroraLoomProgress.Result(bestMoves: 6, stars: 2))
        #expect(restored.progress.frontier == 4 && restored.reconciliationDropped == 0)
        #expect(throws: AuroraLoomRestoreRefusal.damaged) { try Core.migratedToSchemaThree(["level": 1]) }
    }

    @Test func anEditedResultIsDroppedOnRestore() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let certified: AuroraLoomGenerated = try Core.generated(number: 1)
        for move in certified.solution.moves { #expect(core.apply(Self.action(move)) == .accepted) }
        #expect(core.progress.solved[1]?.verified == true)
        let honest: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(honest == core && honest.reconciliationDropped == 0)
        let text: String = try #require(String(data: try core.snapshotPayload(), encoding: .utf8))
        let tampered: String = text.replacingOccurrences(of: "\"stars\":3", with: "\"stars\":2")
        #expect(tampered != text)
        let restored: Core = try Core.restore(payload: Data(tampered.utf8), seed: 0)
        #expect(restored.progress.solved[1] == nil && restored.reconciliationDropped == 1)
        #expect(restored.progress.frontier == core.progress.frontier)
    }

    @Test func replayPlaysTheStoredTraceWithoutChangingProgress() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let rule: (String) -> ActionResult = { code in .rejected(.rule(code: code)) }
        #expect(core.apply(ExperienceAction(control: "replay.start", values: [1], step: 0))
            == rule(AuroraLoomExperienceRule.noReplay))
        #expect(core.apply(ExperienceAction(control: "replay.step", step: 0)) == rule(AuroraLoomExperienceRule.noReplay))
        #expect(core.apply(ExperienceAction(control: "replay.stop", step: 0)) == rule(AuroraLoomExperienceRule.noReplay))
        let certified: AuroraLoomGenerated = try Core.generated(number: 1)
        // A detour (a move and its undo) is not part of the winning trace.
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, Double(Self.otherWave(core))],
                                            step: 0)) == .accepted)
        #expect(core.apply(ExperienceAction(control: "play.undo", step: 0)) == .accepted)
        for move in certified.solution.moves { #expect(core.apply(Self.action(move)) == .accepted) }
        let progress: AuroraLoomProgress = core.progress
        #expect(progress.solved[1]?.trace == certified.solution.moves)
        #expect(core.apply(ExperienceAction(control: "replay.start", values: [1], step: 0)) == .accepted)
        #expect(core.mode == .replay(level: 1) && core.play.spent == 0 && core.tutorial == .done)
        #expect(core.apply(ExperienceAction(control: "level.next", step: 0)) == rule(AuroraLoomExperienceRule.replay))
        #expect(core.apply(Self.action(certified.solution.moves[0])) == rule(AuroraLoomExperienceRule.replay))
        #expect(core.apply(ExperienceAction(control: "tutorial.dismiss", step: 0)) == .accepted)
        var digests: [StateDigest] = [try Self.digest(core)]
        for _ in certified.solution.moves {
            #expect(core.apply(ExperienceAction(control: "replay.step", step: 0)) == .accepted)
            digests.append(try Self.digest(core))
        }
        #expect(Set(digests).count == digests.count)
        #expect(core.play.stage == .won && core.progress == progress)
        #expect(core.apply(ExperienceAction(control: "replay.step", step: 0)) == rule(AuroraLoomExperienceRule.replayEnd))
        // A replay survives a snapshot round trip, then stops back to campaign.
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core)
        #expect(core.apply(ExperienceAction(control: "replay.stop", step: 0)) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.play.spent == 0 && core.progress == progress)
    }

    @Test func theTierAndTheSnapshotTimeNeverTouchTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: 44)
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, Double(Self.otherWave(core))],
                                            step: 0)) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let drawn: [Int] = [5, 5, 3, 1, 1]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.layers == drawn[index])
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: AuroraLoomSceneSnapshot = core.snapshot(time: time)
            #expect(snapshot.steps == core.play.steps && snapshot.stage == core.play.stage)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest)
    }
}
