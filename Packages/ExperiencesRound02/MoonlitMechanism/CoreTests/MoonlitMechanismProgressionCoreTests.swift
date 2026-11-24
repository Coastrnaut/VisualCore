// MoonlitMechanismProgressionCoreTests — feature 435 (R02-G14-05) T-R02G1405-004 (FR-R02G1405-001, 004 … 007;
// clarifications Q2–Q5). The adapter's teaching and progression, ported from feature 425's Acoustic Constellator adapter
// tests: the progression controls (`level.select`, `mode.daily`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`
// and `level.next` to the next open level) with their refusals (`r02-g14.locked`, `r02-g14.date`, `r02-g14.not-whole`
// and the engine's range and count checks, the state unchanged); a campaign win records the least actions spent (undone
// ones included) and stars against the certified witness's action count and opens the next level, a better result
// replaces it and a worse one does not; practice (budget 40 on a copy of the level) records nothing; a daily level
// (`MoonlitMechanismProgress.dailyLevel`, never hard-coded) is playable while locked, records its best result and opens
// nothing; progress and mode are digested (digest v2), the tutorial step is state and saved but never digested; the
// tutorial's steps change → align → run → done (advanced after a turn, re-seat or lamp step, aligned when
// `MoonlitMechanismTutorialStep.isAligned(play)`, ended by the end of the level, never back on undo or redo); the
// schema-2 payload `{level, mode, progress, records, tutorial}` round trip in every mode, its refused payloads, the
// migration of a schema-1 payload and the refusal of a newer schema. Level facts used: level 1's witness is turn(1),
// lamp(−1), run (budget 9); levels 2 and 3 re-seat a gear, step the lamp and run; levels 4 and later have no tutorial.
// Levels are certified once per process, so the run stays short. Explicit types, plain loops, no wall-clock asserts.
import Foundation
import Testing
@testable import MoonlitMechanismCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

@Suite struct MoonlitMechanismProgressionCoreTests {
    typealias Core = MoonlitMechanismExperienceCore

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
    static func act(_ action: MoonlitMechanismAction) -> ExperienceAction {
        switch action {
        case let .turn(step): act("handle.turn", [Double(step)])
        case let .reseat(gear, step): act("gear.reseat", [Double(gear), Double(step)])
        case let .lamp(step): act("lamp.step", [Double(step)])
        case .run: act("machine.run")
        }
    }

    /// The certified witness actions of level `number` (its turns, re-seats and lamp steps, then the run).
    static func witness(_ number: Int) throws -> [MoonlitMechanismAction] {
        try Core.generated(number: number).actions
    }

    /// A daily date of 2026 whose daily level is not a tutorial level (4 … 100) and not open on a fresh opening of
    /// level 1, with that level; the level is computed with `MoonlitMechanismProgress.dailyLevel`.
    static func plainDaily() throws -> (date: [Double], level: Int) {
        let date: [Double] = [2026, 11, 23]
        let level: Int = try #require(MoonlitMechanismProgress.dailyLevel(year: 2026, month: 11, day: 23))
        try #require(level > MoonlitMechanismTutorialStep.tutorialLevels.upperBound)
        return (date, level)
    }

    @Test func theProgressionControlsRefuseWhatTheyMust() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let locked: ActionResult = .rejected(.rule(code: MoonlitMechanismExperienceRule.locked))
        let date: ActionResult = .rejected(.rule(code: MoonlitMechanismExperienceRule.date))
        let notWhole: ActionResult = .rejected(.rule(code: MoonlitMechanismExperienceRule.notWhole))
        #expect(locked == .rejected(.rule(code: "r02-g14.locked")) && date == .rejected(.rule(code: "r02-g14.date")))
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
        }
        // A leap year's 29 February is a date.
        var leap: Core = core
        #expect(leap.apply(Self.act("mode.daily", [2028, 2, 29])) == .accepted)
        let leapLevel: Int = try #require(MoonlitMechanismProgress.dailyLevel(year: 2028, month: 2, day: 29))
        #expect(leap.mode == .daily(level: leapLevel) && leap.levelNumber == leapLevel)
        #expect(leap.play.records.isEmpty && leap.shownFrame == Core.openingFrame)
    }

    @Test func campaignWinsRecordStarsAndOpenTheNextLevel() async throws {
        let actions: [MoonlitMechanismAction] = try Self.witness(1)
        let certified: Int = actions.count
        // Level 1's witness turns the handle, steps the lamp down and runs: its changes plus the run.
        #expect(certified == 3 && actions == [.turn(1), .lamp(-1), .run])
        // A win that spent one undone turn more than the witness: 2 stars, level 2 opened.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.certifiedActions == certified)
        #expect(core.apply(Self.act("handle.turn", [1])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        for step in actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && MoonlitMechanismProgress.actionsSpent(core.play) == certified + 1)
        // Since feature 437 a campaign win stores a verified result with its winning trace (the undone turn left out).
        #expect(MoonlitMechanismReconciliation.netTrace(core.play.records) == actions)
        #expect(core.progress.solved[1] == MoonlitMechanismProgress.Result(actionsSpent: certified + 1, stars: 2,
                                                                          trace: actions, verified: true))
        #expect(core.progress.frontier == 2 && core.progress.isOpen(2) && !core.progress.isOpen(3))
        // A better result replaces it: the witness alone, 3 stars.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        #expect(core.levelNumber == 1 && core.play.records.isEmpty && core.mode == .campaign)
        for step in actions { #expect(core.apply(Self.act(step)) == .accepted) }
        // Since feature 437 the result carries the witness trace, verified.
        let best: MoonlitMechanismProgress.Result = MoonlitMechanismProgress.Result(actionsSpent: certified, stars: 3,
                                                                                    trace: actions, verified: true)
        #expect(core.progress.solved[1] == best)
        // A worse result keeps the best one: four turns back and forth more than the witness (1 star; 7 of the
        // budget's 9 actions) change nothing.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        #expect(core.play.level.budget >= certified + 5)
        let detours: [ExperienceAction] = [Self.act("handle.turn", [1]), Self.act("handle.turn", [-1]),
                                           Self.act("handle.turn", [1]), Self.act("handle.turn", [-1])]
        for step in detours { #expect(core.apply(step) == .accepted) }
        for step in actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && MoonlitMechanismProgress.actionsSpent(core.play) == certified + 4)
        #expect(core.progress.solved[1] == best)   // since feature 437 compared with its trace
        #expect(core.progress.frontier == 2)
        // The frontier: level 2 can be chosen, level 3 cannot.
        #expect(core.apply(Self.act("level.select", [3])) == .rejected(.rule(code: "r02-g14.locked")))
        #expect(core.apply(Self.act("level.select", [2])) == .accepted)
        #expect(core.levelNumber == 2 && core.play.stage == .playing && core.tutorial == .change)
        #expect(core.certifiedActions == (try Self.witness(2)).count)
        // level.next from the frontier is refused: no next open level.
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g14.locked")))
        // No level is ever gated by payment: every level up to the frontier is open, whatever the tier.
        for number in 1...core.progress.frontier { #expect(core.progress.isOpen(number)) }
    }

    @Test func practiceAndDailyFollowTheirRules() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let certified: MoonlitMechanismLevel = try Core.level(number: 1)
        // Practice: a copy of the level with the budget raised to 40; a win records nothing and opens nothing.
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == 1 && core.play.records.isEmpty)
        #expect(core.play.level.budget == 40 && core.play.actionsLeft == 40 && core.tutorial == .change)
        #expect(Core.practiceBudget == 40)
        #expect(core.play.level.gears == certified.gears && core.play.level.keyFrames == certified.keyFrames)
        #expect(core.play.level.lampHeights == certified.lampHeights)
        #expect(core.play.level.startingHeight == certified.startingHeight)
        #expect(core.play.level.forbidden == certified.forbidden && core.play.level.tutorial == certified.tutorial)
        #expect(core.play.level.seed == certified.seed && core.play.level.fingerprint != certified.fingerprint)
        #expect(try Core.practiceLevel(of: certified) == core.play.level)
        let before: MoonlitMechanismProgress = core.progress
        for step in try Self.witness(1) { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress == before && core.progress.solved.isEmpty)
        // Campaign returns to the current level when it is open, fresh, with the certified budget.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.play.records.isEmpty)
        #expect(core.play.level == certified && core.play.actionsLeft == certified.budget)
        // Daily: the date's level, playable while still locked; level.next from it is refused; a win records the
        // level's best result and stars and opens nothing.
        let (dailyDate, daily): ([Double], Int) = try Self.plainDaily()
        #expect(!core.progress.isOpen(daily))
        #expect(core.apply(Self.act("mode.daily", dailyDate)) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily && core.tutorial == .done)
        #expect(core.play.level == (try Core.level(number: daily)))
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g14.locked")))
        let dailyActions: [MoonlitMechanismAction] = try Self.witness(daily)
        for step in dailyActions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.frontier == 1 && !core.progress.isOpen(daily))
        let result: MoonlitMechanismProgress.Result = try #require(core.progress.solved[daily])
        // Since feature 437 a daily win stores a verified result with its winning trace.
        #expect(result == MoonlitMechanismProgress.Result(actionsSpent: dailyActions.count, stars: 3,
                                                          trace: dailyActions, verified: true))
        // Campaign from a level that is not open goes to the frontier.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1)
        // A daily tutorial level carries the tutorial: 2026-01-01 is level 1.
        #expect(MoonlitMechanismProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 1])) == .accepted)
        #expect(core.mode == .daily(level: 1) && core.levelNumber == 1 && core.tutorial == .change)
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
        for step in try Self.witness(1) { #expect(won.apply(Self.act(step)) == .accepted) }
        #expect(won.apply(Self.act("level.select", [1])) == .accepted)
        #expect(won.play == campaign.play && won.progress != campaign.progress)
        #expect(try Self.digest(won) != (try Self.digest(campaign)))
    }

    @Test func theTutorialAdvancesInOrderAndIsNotDigested() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.tutorial == .change && core.tutorial.text.hasPrefix("Drag a gear around"))
        #expect(!MoonlitMechanismTutorialStep.isAligned(core.play))
        // Dismissing ends it; the step is state (==) but never digested.
        let digest: StateDigest = try Self.digest(core)
        var dismissed: Core = core
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed.tutorial == .done && dismissed != core && dismissed.play == core.play)
        #expect(try Self.digest(dismissed) == digest)
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted && dismissed.tutorial == .done)
        // Showing a key frame is no change: change stays.
        var shown: Core = core
        #expect(shown.apply(Self.act("frame.show", [1])) == .accepted && shown.tutorial == .change)
        // A turn that leaves the set-up unaligned: change → align; an undo does not move it, nor a redo.
        #expect(core.apply(Self.act("handle.turn", [1])) == .accepted)
        #expect(!MoonlitMechanismTutorialStep.isAligned(core.play) && core.tutorial == .align)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .align)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .align)
        // The lamp step that aligns the set-up: align → run; undo never moves it back, redo keeps it, a lamp step that
        // unaligns keeps it.
        #expect(core.apply(Self.act("lamp.step", [-1])) == .accepted)
        #expect(MoonlitMechanismTutorialStep.isAligned(core.play) && core.tutorial == .run)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .run)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .run)
        var unaligned: Core = core
        #expect(unaligned.apply(Self.act("lamp.step", [1])) == .accepted)
        #expect(!MoonlitMechanismTutorialStep.isAligned(unaligned.play) && unaligned.tutorial == .run)
        // The end of the level ends it.
        #expect(core.apply(Self.act("machine.run")) == .accepted)
        #expect(core.play.stage == .won && core.tutorial == .done)
        // A change that aligns the set-up moves change straight on to run: the saved state after the turn with its
        // step set back to change, then the lamp step.
        var turned: Core = try await Core.prepare(seed: 0)
        #expect(turned.apply(Self.act("handle.turn", [1])) == .accepted)
        let turnedText: String = String(decoding: try turned.snapshotPayload(), as: UTF8.self)
        let changeText: String = turnedText.replacingOccurrences(of: "\"tutorial\":\"align\"",
                                                                 with: "\"tutorial\":\"change\"")
        #expect(changeText != turnedText)
        var straight: Core = try Core.restore(payload: Data(changeText.utf8), seed: 0)
        #expect(straight.tutorial == .change && straight.play == turned.play)
        #expect(straight.apply(Self.act("lamp.step", [-1])) == .accepted && straight.tutorial == .run)
        // A failed run ends it; the undo that retries does not bring it back.
        var broken: Core = try await Core.prepare(seed: 0)
        #expect(broken.apply(Self.act("machine.run")) == .accepted && broken.play.stage == .failed)
        #expect(broken.tutorial == .done)
        #expect(broken.apply(Self.act("play.undo")) == .accepted && broken.tutorial == .done)
        // Choosing a level or a mode restarts the step of that level; a level without the tutorial starts done.
        #expect(broken.apply(Self.act("mode.practice")) == .accepted && broken.tutorial == .change)
        var plain: Core = try Core.opening(number: 4)
        #expect(plain.tutorial == .done && MoonlitMechanismTutorialStep.initial(level: 3) == .change)
        let plainFirst: MoonlitMechanismAction = try #require(try Self.witness(4).first)
        #expect(plain.apply(Self.act(plainFirst)) == .accepted)
        #expect(plain.tutorial == .done)
        // A re-seat on a tutorial level advances it as a turn does (level 2's witness re-seats first).
        var second: Core = try Core.opening(number: 2)
        let secondFirst: MoonlitMechanismAction = try #require(try Self.witness(2).first)
        #expect(second.tutorial == .change && MoonlitMechanismTutorialStep.isChange(secondFirst))
        #expect(second.apply(Self.act(secondFirst)) == .accepted && second.tutorial != .change)
        // The step is saved and restored.
        var saved: Core = try await Core.prepare(seed: 0)
        #expect(saved.apply(Self.act("handle.turn", [1])) == .accepted)
        let payload: Data = try saved.snapshotPayload()
        #expect(String(decoding: payload, as: UTF8.self).hasSuffix(",\"tutorial\":\"align\"}"))
        let restored: Core = try Core.restore(payload: payload, seed: 0)
        #expect(restored == saved && restored.tutorial == .align)
    }

    @Test func theSchemaTwoPayloadRoundTripsInEveryModeAndRefusesDamage() async throws {
        // Campaign with progress: level 1 won, level 2 reached with level.next.
        var campaign: Core = try await Core.prepare(seed: 0)
        for step in try Self.witness(1) { #expect(campaign.apply(Self.act(step)) == .accepted) }
        #expect(campaign.apply(Self.act("level.next")) == .accepted)
        #expect(campaign.levelNumber == 2 && campaign.tutorial == .change)
        // Practice: a turn on the practice copy.
        var practice: Core = try await Core.prepare(seed: 0)
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(practice.apply(Self.act("handle.turn", [1])) == .accepted)
        // Daily: the first certified action of the date's level.
        let (dailyDate, dailyLevel): ([Double], Int) = try Self.plainDaily()
        var daily: Core = try await Core.prepare(seed: 0)
        #expect(daily.apply(Self.act("mode.daily", dailyDate)) == .accepted)
        let dailyFirst: MoonlitMechanismAction = try #require(try Self.witness(dailyLevel).first)
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
        #expect(practice.play.level.budget == 40)
        let campaignText: String = String(decoding: try campaign.snapshotPayload(), as: UTF8.self)
        let certified: Int = try Self.witness(1).count
        // Since feature 437 the stored result carries the winning trace (the witness) and is verified.
        let traceText: String = String(decoding: try Core.payloadEncoder().encode(try Self.witness(1)), as: UTF8.self)
        let progressText: String = "\"progress\":{\"frontier\":2,"
            + "\"solved\":[{\"actionsSpent\":\(certified),\"level\":1,\"stars\":3,"
            + "\"trace\":" + traceText + ",\"verified\":true}]}"
        #expect(campaignText.contains(progressText))
        #expect(campaignText.hasPrefix("{\"level\":2,\"mode\":{\"mode\":\"campaign\"},"))
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
        let badStep: Data = Data(campaignText.replacingOccurrences(of: "\"tutorial\":\"change\"",
                                                                   with: "\"tutorial\":\"later\"").utf8)
        let damaged: [Data] = [otherDaily, unknownMode, badFrontier, badStars, badStep]
        let campaignPayload: Data = try campaign.snapshotPayload()
        let dailyPayload: Data = try daily.snapshotPayload()
        for payload in damaged {
            #expect(payload != campaignPayload && payload != dailyPayload)
            #expect(throws: MoonlitMechanismRestoreRefusal.damaged) { try Core.restore(payload: payload, seed: 0) }
        }
        // A payload without the tutorial key starts the tutorial at the level's first step.
        let noStep: Data = Data(campaignText.replacingOccurrences(of: ",\"tutorial\":\"change\"", with: "").utf8)
        #expect(campaign.tutorial == .change && noStep != campaignPayload)
        let restoredNoStep: Core = try Core.restore(payload: noStep, seed: 0)
        #expect(restoredNoStep == campaign)
    }

    @Test func aSchemaOnePayloadMigratesAndANewerSchemaIsRefused() async throws {
        // Level 3 after the first certified action (a re-seat): the tutorial has advanced, which schema 1 did not save.
        var core: Core = try await Core.prepare(seed: 2)
        #expect(core.levelNumber == 3)
        let first: MoonlitMechanismAction = try #require(try Self.witness(3).first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.tutorial != .change)
        let records: Data = try Core.payloadEncoder().encode(core.play.records)
        let recordsObject: Any = try JSONSerialization.jsonObject(with: records)
        let schemaOne: [String: Any] = ["level": 3, "records": recordsObject]
        // Since feature 437 the chain runs 1 → 2 → 3, so the expectation is both steps applied in order.
        let migrated: [String: Any] = try Core.migratedToSchemaThree(try Core.migratedToSchemaTwo(schemaOne))
        #expect(migrated["sound"] as? Bool == false)
        let chained: [String: Any] = try Core.migrations.migrate(schemaOne, from: 1)
        let data: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
        let chainedData: Data = try JSONSerialization.data(withJSONObject: chained, options: [.sortedKeys])
        #expect(data == chainedData)
        let restored: Core = try Core.restore(payload: data, seed: 2)
        #expect(restored.levelNumber == 3 && restored.play == core.play && restored.mode == .campaign)
        #expect(restored.progress.frontier == 3 && restored.progress.solved.isEmpty)
        #expect(restored.progress.isOpen(1) && restored.progress.isOpen(3) && !restored.progress.isOpen(4))
        #expect(restored.tutorial == .change && restored.tutorial == MoonlitMechanismTutorialStep.initial(level: 3))
        // The tutorial step is not digested, so the migrated state digests as the saved one.
        #expect(try Self.digest(restored) == Self.digest(core))
        // A level without the tutorial migrates with it done: the fresh opening of level 7.
        let seven: [String: Any] = try Core.migratedToSchemaTwo(["level": 7, "records": [Any]()])
        let sevenData: Data = try JSONSerialization.data(withJSONObject: seven, options: [.sortedKeys])
        let sevenCore: Core = try Core.restore(payload: sevenData, seed: 6)
        #expect(sevenCore == (try Core.opening(number: 7)) && sevenCore.tutorial == .done)
        // A schema-1 object that is not one is refused.
        #expect(throws: MoonlitMechanismRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": "3"]) }
        #expect(throws: MoonlitMechanismRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": 3]) }
        // A newer schema is refused by the chain.
        // Since feature 437 the current schema is 3, so the newer one is 4.
        #expect(Core.schemaVersion == 3)
        #expect(throws: MigrationError.newerVersion(4)) { try Core.migrations.migrate(schemaOne, from: 4) }
    }
}
