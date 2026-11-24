// VoxelOrigamiProgressionCoreTests — feature 445 (R02-G15-05) T-R02G1505-004 (FR-R02G1505-001, 004 … 007;
// clarifications Q2–Q5). The adapter's teaching and progression, modelled on feature 435's Moonlit Mechanism adapter
// tests: the progression controls (`level.select`, `mode.daily`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`
// and `level.next` to the next open level) with their refusals (`r02-g15.locked`, `r02-g15.date`, `r02-g15.not-whole`
// and the engine's range and count checks, the state unchanged); a campaign win records the least actions spent (undone
// turns included) and stars against the certified plan's turn count and opens the next level, a better result replaces
// it and a worse one does not; practice (budget 40 on a copy of the level) records nothing; a daily level
// (`VoxelOrigamiProgress.dailyLevel`, never hard-coded) is playable while locked, records its best result and opens
// nothing; progress and mode are digested (digest v2), the tutorial step is state and saved but never digested; the
// tutorial's steps turn → compare → recover → done (advanced by accepted turns, ended by the end of the level, never
// back on undo, ended by a redo that restores a failed play); the schema-2 payload `{level, mode, progress, records,
// tutorial}` round trip in every mode, its refused payloads, the migration of a schema-1 payload (directly and through
// the engine) and the refusal of a newer schema; no level is gated by anything but being opened. Level facts used:
// level 1's certified plan is hinge 4 turned −1 twice (budget 9); levels 1 … 3 carry the tutorial. Levels are certified
// once per process, so the run stays short. Explicit types, plain loops, no wall-clock asserts.
import Foundation
import Testing
@testable import VoxelOrigamiCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

@Suite struct VoxelOrigamiProgressionCoreTests {
    typealias Core = VoxelOrigamiExperienceCore

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
    static func act(_ action: VoxelOrigamiAction) -> ExperienceAction {
        switch action {
        case let .turn(hinge, step): act("hinge.turn", [Double(hinge), Double(step)])
        }
    }

    /// The certified plan turns of level `number`.
    static func plan(_ number: Int) throws -> [VoxelOrigamiAction] {
        try Core.generated(number: number).plan.turns
    }

    /// A daily date of 2026 whose daily level is not a tutorial level (4 … 100) and not open on a fresh opening of
    /// level 1, with that level; the level is computed with `VoxelOrigamiProgress.dailyLevel`.
    static func plainDaily() throws -> (date: [Double], level: Int) {
        let date: [Double] = [2026, 11, 18]
        let level: Int = try #require(VoxelOrigamiProgress.dailyLevel(year: 2026, month: 11, day: 18))
        try #require(level > VoxelOrigamiTutorialStep.tutorialLevels.upperBound)
        return (date, level)
    }

    @Test func theProgressionControlsRefuseWhatTheyMust() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let locked: ActionResult = .rejected(.rule(code: VoxelOrigamiExperienceRule.locked))
        let date: ActionResult = .rejected(.rule(code: VoxelOrigamiExperienceRule.date))
        let notWhole: ActionResult = .rejected(.rule(code: VoxelOrigamiExperienceRule.notWhole))
        #expect(locked == .rejected(.rule(code: "r02-g15.locked")) && date == .rejected(.rule(code: "r02-g15.date")))
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
        let leapLevel: Int = try #require(VoxelOrigamiProgress.dailyLevel(year: 2028, month: 2, day: 29))
        #expect(leap.mode == .daily(level: leapLevel) && leap.levelNumber == leapLevel)
        #expect(leap.play.records.isEmpty && leap.play.stage == .playing)
    }

    @Test func campaignWinsRecordStarsAndOpenTheNextLevel() async throws {
        let actions: [VoxelOrigamiAction] = try Self.plan(1)
        let certified: Int = actions.count
        // Level 1's certified plan turns hinge 4 by −1 twice.
        #expect(certified == 2 && actions == [.turn(4, -1), .turn(4, -1)])
        // A win that spent one undone turn more than the plan: 2 stars, level 2 opened.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.certifiedTurns == certified && core.mode == .campaign && core.progress.frontier == 1)
        #expect(core.apply(Self.act(actions[0])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        for step in actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && VoxelOrigamiProgress.actionsSpent(core.play) == certified + 1)
        let twoStars: Int = VoxelOrigamiProgress.stars(actionsSpent: certified + 1, certified: certified)
        #expect(twoStars == 2)
        // Since feature 447 a campaign win stores a verified result with its winning trace (the undone turn left out).
        #expect(VoxelOrigamiReconciliation.netTrace(core.play.records) == actions)
        #expect(core.progress.solved[1] == VoxelOrigamiProgress.Result(actionsSpent: certified + 1, stars: twoStars,
                                                                      trace: actions, verified: true))
        #expect(core.progress.frontier == 2 && core.progress.isOpen(2) && !core.progress.isOpen(3))
        // level.next goes to the newly opened level 2, fresh, with its tutorial.
        var next: Core = core
        #expect(next.apply(Self.act("level.next")) == .accepted)
        #expect(next.levelNumber == 2 && next.play.records.isEmpty && next.mode == .campaign)
        let secondTurns: Int = try Self.plan(2).count
        #expect(next.tutorial == .turn && next.certifiedTurns == secondTurns)
        // A better result replaces it: the plan alone, 3 stars.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        #expect(core.levelNumber == 1 && core.play.records.isEmpty && core.mode == .campaign)
        for step in actions { #expect(core.apply(Self.act(step)) == .accepted) }
        // Since feature 447 the result carries the witness trace, verified.
        let best: VoxelOrigamiProgress.Result = VoxelOrigamiProgress.Result(actionsSpent: certified, stars: 3,
                                                                            trace: actions, verified: true)
        #expect(core.progress.solved[1] == best)
        // A worse result keeps the best one: four undone turns more than the plan (1 star) change nothing.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        for _ in 0..<4 {
            #expect(core.apply(Self.act(actions[0])) == .accepted)
            #expect(core.apply(Self.act("play.undo")) == .accepted)
        }
        for step in actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && VoxelOrigamiProgress.actionsSpent(core.play) == certified + 4)
        #expect(VoxelOrigamiProgress.stars(actionsSpent: certified + 4, certified: certified) == 1)
        #expect(core.progress.solved[1] == best && core.progress.frontier == 2)
        // The frontier: level 2 can be chosen, level 3 cannot.
        #expect(core.apply(Self.act("level.select", [3])) == .rejected(.rule(code: "r02-g15.locked")))
        #expect(core.apply(Self.act("level.select", [2])) == .accepted)
        #expect(core.levelNumber == 2 && core.play.stage == .playing && core.tutorial == .turn)
        // level.next from the frontier is refused: no next open level.
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g15.locked")))
        #expect(core.levelNumber == 2)
    }

    @Test func practiceAndDailyFollowTheirRules() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let certified: VoxelOrigamiLevel = try Core.level(number: 1)
        // Practice: a copy of the level with the budget raised to 40; a win records nothing and opens nothing.
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == 1 && core.play.records.isEmpty)
        #expect(core.play.level.budget == 40 && core.play.actionsLeft == 40 && core.tutorial == .turn)
        #expect(Core.practiceBudget == 40 && certified.budget != 40)
        #expect(core.play.level.cubes == certified.cubes && core.play.level.target == certified.target)
        #expect(core.play.level.seed == certified.seed && core.play.level.tutorial == certified.tutorial)
        #expect(core.play.level.id == certified.id && core.play.level.difficulty == certified.difficulty)
        #expect(try Core.practiceLevel(of: certified) == core.play.level)
        let before: VoxelOrigamiProgress = core.progress
        for step in try Self.plan(1) { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress == before && core.progress.solved.isEmpty)
        #expect(core.progress.frontier == 1)
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
        let dailyCertified: VoxelOrigamiLevel = try Core.level(number: daily)
        #expect(core.play.level == dailyCertified && !core.progress.isOpen(daily))
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g15.locked")))
        let dailyActions: [VoxelOrigamiAction] = try Self.plan(daily)
        #expect(core.certifiedTurns == dailyActions.count)
        for step in dailyActions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.frontier == 1 && !core.progress.isOpen(daily))
        let result: VoxelOrigamiProgress.Result = try #require(core.progress.solved[daily])
        // Since feature 447 a daily win stores a verified result with its winning trace.
        #expect(result == VoxelOrigamiProgress.Result(actionsSpent: dailyActions.count, stars: 3,
                                                      trace: dailyActions, verified: true))
        // Campaign from a level that is not open goes to the frontier.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1)
        // A daily tutorial level carries the tutorial: 2026-01-01 is level 1.
        #expect(VoxelOrigamiProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 1])) == .accepted)
        #expect(core.mode == .daily(level: 1) && core.levelNumber == 1 && core.tutorial == .turn)
    }

    @Test func progressAndModeAreDigested() async throws {
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
        for step in try Self.plan(1) { #expect(won.apply(Self.act(step)) == .accepted) }
        #expect(won.apply(Self.act("level.select", [1])) == .accepted)
        #expect(won.play == campaign.play && won.mode == campaign.mode && won.progress != campaign.progress)
        #expect(try Self.digest(won) != (try Self.digest(campaign)))
    }

    @Test func theTutorialAdvancesInOrderAndIsNotDigested() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.tutorial == .turn && core.tutorial.text.hasPrefix("Tap a cube to choose its hinge"))
        // Dismissing ends it; the step is state (==) and saved, but never digested.
        let digest: StateDigest = try Self.digest(core)
        var dismissed: Core = core
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed.tutorial == .done && dismissed != core && dismissed.play == core.play)
        #expect(try Self.digest(dismissed) == digest)
        #expect(try dismissed.snapshotPayload() != (try core.snapshotPayload()))
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted && dismissed.tutorial == .done)
        // Choosing a hinge is no turn: turn stays.
        var chosen: Core = core
        #expect(chosen.apply(Self.act("hinge.choose", [2])) == .accepted && chosen.tutorial == .turn)
        // A turn: turn → compare; an undo does not move it back, nor a redo forward.
        #expect(core.apply(Self.act("hinge.turn", [4, -1])) == .accepted)
        #expect(core.play.stage == .playing && core.tutorial == .compare)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .compare)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .compare)
        // A second turn (back to the start): compare → recover; recover lasts.
        #expect(core.apply(Self.act("hinge.turn", [4, 1])) == .accepted)
        #expect(core.play.stage == .playing && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .recover)
        // The end of the level ends it: the certified plan from the start wins.
        for step in try Self.plan(1) { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.tutorial == .done)
        // A winning turn moves any step straight to done (level 2's plan is one turn).
        var second: Core = try Core.opening(number: 2)
        let secondPlan: [VoxelOrigamiAction] = try Self.plan(2)
        #expect(second.tutorial == .turn && secondPlan.count == 1)
        #expect(second.apply(Self.act(secondPlan[0])) == .accepted)
        #expect(second.play.stage == .won && second.tutorial == .done)
        // A spent budget fails the level and ends it; the undo that retries does not bring it back; a redo that
        // restores the failed play ends a step restored as recover. Level 1 (budget 9): hinge 4 turned −1 and back
        // four times, then −1 once more, never matches and spends the last action.
        var broken: Core = try Core.opening(number: 1)
        #expect(broken.tutorial == .turn && broken.play.level.budget == 9)
        for index in 0..<8 {
            let step: Double = index % 2 == 0 ? -1 : 1
            #expect(broken.apply(Self.act("hinge.turn", [4, step])) == .accepted)
            #expect(broken.play.stage == .playing)
        }
        #expect(broken.tutorial == .recover)
        #expect(broken.apply(Self.act("hinge.turn", [4, -1])) == .accepted)
        #expect(broken.play.stage == .failed && broken.play.failure == .budget(8) && broken.tutorial == .done)
        #expect(broken.progress.solved.isEmpty && broken.progress.frontier == 1)
        #expect(broken.apply(Self.act("play.undo")) == .accepted)
        #expect(broken.play.stage == .playing && broken.tutorial == .done)
        let brokenText: String = String(decoding: try broken.snapshotPayload(), as: UTF8.self)
        let recoverText: String = brokenText.replacingOccurrences(of: "\"tutorial\":\"done\"",
                                                                  with: "\"tutorial\":\"recover\"")
        #expect(recoverText != brokenText)
        var redone: Core = try Core.restore(payload: Data(recoverText.utf8), seed: 0)
        #expect(redone.tutorial == .recover && redone.play == broken.play && redone.play.canRedo)
        #expect(redone.apply(Self.act("play.redo")) == .accepted)
        #expect(redone.play.stage == .failed && redone.tutorial == .done)
        // Choosing a level or a mode restarts the step of that level; a level without the tutorial starts done.
        #expect(broken.apply(Self.act("mode.practice")) == .accepted)
        #expect(broken.tutorial == VoxelOrigamiTutorialStep.initial(level: broken.levelNumber))
        for number in 1...6 {
            let opening: Core = try Core.opening(number: number)
            let expected: VoxelOrigamiTutorialStep = number <= 3 ? .turn : .done
            #expect(opening.tutorial == expected && VoxelOrigamiTutorialStep.initial(level: number) == expected)
        }
        var plain: Core = try Core.opening(number: 4)
        let plainFirst: VoxelOrigamiAction = try #require(try Self.plan(4).first)
        #expect(plain.apply(Self.act(plainFirst)) == .accepted && plain.tutorial == .done)
        // The step is saved and restored; two cores differing only in the step digest alike.
        var saved: Core = try await Core.prepare(seed: 0)
        #expect(saved.apply(Self.act("hinge.turn", [4, -1])) == .accepted)
        let payload: Data = try saved.snapshotPayload()
        #expect(String(decoding: payload, as: UTF8.self).hasSuffix(",\"tutorial\":\"compare\"}"))
        let restored: Core = try Core.restore(payload: payload, seed: 0)
        #expect(restored == saved && restored.tutorial == .compare)
        var savedDismissed: Core = saved
        #expect(savedDismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(savedDismissed != saved && savedDismissed.play == saved.play)
        #expect(try Self.digest(savedDismissed) == Self.digest(saved))
    }

    @Test func theSchemaTwoPayloadRoundTripsInEveryModeAndRefusesDamage() async throws {
        // Campaign with progress: level 1 won, level 2 reached with level.next.
        var campaign: Core = try await Core.prepare(seed: 0)
        for step in try Self.plan(1) { #expect(campaign.apply(Self.act(step)) == .accepted) }
        #expect(campaign.apply(Self.act("level.next")) == .accepted)
        #expect(campaign.levelNumber == 2 && campaign.tutorial == .turn)
        // Practice: a turn on the practice copy.
        var practice: Core = try await Core.prepare(seed: 0)
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(practice.apply(Self.act("hinge.turn", [4, -1])) == .accepted)
        // Daily: the first certified turn of the date's level.
        let (dailyDate, dailyLevel): ([Double], Int) = try Self.plainDaily()
        var daily: Core = try await Core.prepare(seed: 0)
        #expect(daily.apply(Self.act("mode.daily", dailyDate)) == .accepted)
        let dailyFirst: VoxelOrigamiAction = try #require(try Self.plan(dailyLevel).first)
        #expect(daily.apply(Self.act(dailyFirst)) == .accepted)
        let cores: [Core] = [campaign, practice, daily]
        for core in cores {
            let payload: Data = try core.snapshotPayload()
            #expect(try core.snapshotPayload() == payload)
            let restored: Core = try Core.restore(payload: payload, seed: 0)
            let restoredDigest: StateDigest = try Self.digest(restored)
            let savedDigest: StateDigest = try Self.digest(core)
            #expect(restored == core && restoredDigest == savedDigest, "\(core.mode)")
            #expect(restored.certifiedTurns == core.certifiedTurns && restored.openingNumber == 1)
            var reset: Core = restored
            reset.reset()
            #expect(reset == (try Core.opening(number: 1)))
        }
        #expect(practice.play.level.budget == 40)
        let restoredPractice: Core = try Core.restore(payload: try practice.snapshotPayload(), seed: 0)
        #expect(restoredPractice.play.level.budget == 40 && restoredPractice.mode == .practice)
        let campaignText: String = String(decoding: try campaign.snapshotPayload(), as: UTF8.self)
        let certified: Int = try Self.plan(1).count
        // Since feature 447 the stored result carries the winning trace (the witness) and is verified.
        let traceText: String = String(decoding: try Core.payloadEncoder().encode(try Self.plan(1)), as: UTF8.self)
        let progressText: String = "\"progress\":{\"frontier\":2,"
            + "\"solved\":[{\"actionsSpent\":\(certified),\"level\":1,\"stars\":3,"
            + "\"trace\":" + traceText + ",\"verified\":true}]}"
        #expect(campaignText.contains(progressText))
        #expect(campaignText.hasPrefix("{\"level\":2,\"mode\":{\"mode\":\"campaign\"},"))
        #expect(campaignText.hasSuffix(",\"tutorial\":\"turn\"}"))
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
        let badStep: Data = Data(campaignText.replacingOccurrences(of: "\"tutorial\":\"turn\"",
                                                                   with: "\"tutorial\":\"later\"").utf8)
        let damaged: [Data] = [otherDaily, unknownMode, badFrontier, badStars, badStep]
        let campaignPayload: Data = try campaign.snapshotPayload()
        let dailyPayload: Data = try daily.snapshotPayload()
        for payload in damaged {
            #expect(payload != campaignPayload && payload != dailyPayload)
            #expect(throws: VoxelOrigamiRestoreRefusal.damaged) { try Core.restore(payload: payload, seed: 0) }
        }
        // A payload without the tutorial key starts the tutorial at the level's first step.
        let noStep: Data = Data(campaignText.replacingOccurrences(of: ",\"tutorial\":\"turn\"", with: "").utf8)
        #expect(noStep != campaignPayload)
        let restoredNoStep: Core = try Core.restore(payload: noStep, seed: 0)
        #expect(restoredNoStep == campaign)
    }

    @Test func aSchemaOnePayloadMigratesAndANewerSchemaIsRefused() async throws {
        // Level 3 after its first certified turn: the tutorial has advanced, which schema 1 did not save.
        var core: Core = try await Core.prepare(seed: 2)
        #expect(core.levelNumber == 3)
        let first: VoxelOrigamiAction = try #require(try Self.plan(3).first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.tutorial == .compare)
        let records: Data = try Core.payloadEncoder().encode(core.play.records)
        let recordsObject: Any = try JSONSerialization.jsonObject(with: records)
        let schemaOne: [String: Any] = ["level": 3, "records": recordsObject]
        // Since feature 447 the chain runs 1 → 2 → 3, so the expectation is both steps applied in order.
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
        #expect(restored.tutorial == .turn && restored.tutorial == VoxelOrigamiTutorialStep.initial(level: 3))
        // The tutorial step is not digested, so the migrated state digests as the saved one.
        #expect(try Self.digest(restored) == Self.digest(core))
        // A level without the tutorial migrates with it done: the fresh opening of level 7.
        let seven: [String: Any] = try Core.migratedToSchemaTwo(["level": 7, "records": [Any]()])
        let sevenData: Data = try JSONSerialization.data(withJSONObject: seven, options: [.sortedKeys])
        let sevenCore: Core = try Core.restore(payload: sevenData, seed: 6)
        #expect(sevenCore == (try Core.opening(number: 7)) && sevenCore.tutorial == .done)
        // A schema-1 object that is not one is refused.
        #expect(throws: VoxelOrigamiRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": "3"]) }
        #expect(throws: VoxelOrigamiRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": 3]) }
        // A newer schema is refused by the chain.
        // Since feature 447 the current schema is 3, so the newer one is 4.
        #expect(Core.schemaVersion == 3)
        #expect(throws: MigrationError.newerVersion(4)) { try Core.migrations.migrate(schemaOne, from: 4) }
    }

    @Test func theEngineMigratesASchemaOneEnvelopeAndRefusesANewerOne() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 2)
        try engine.activate()
        // Level 3: its first certified turn.
        let first: VoxelOrigamiAction = try #require(try Self.plan(3).first)
        guard case let .turn(hinge, step) = first else { return }
        #expect(engine.handle(control: "hinge.turn", values: [Double(hinge), Double(step)]) == .accepted)
        let played: Core = try #require(engine.core)
        let saved: ExperienceSnapshot = try engine.snapshot()
        let records: Data = try Core.payloadEncoder().encode(played.play.records)
        let recordsObject: Any = try JSONSerialization.jsonObject(with: records)
        let schemaOne: [String: Any] = ["level": 3, "records": recordsObject]
        let schemaOneData: Data = try JSONSerialization.data(withJSONObject: schemaOne, options: [.sortedKeys])
        let old = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: saved.seed,
                                         stepIndex: saved.stepIndex, digest: saved.digest, payload: schemaOneData)
        try engine.restore(old)
        let migrated: Core = try #require(engine.core)
        #expect(migrated.levelNumber == 3 && migrated.play == played.play && migrated.mode == .campaign)
        #expect(migrated.progress.frontier == 3 && migrated.progress.solved.isEmpty)
        #expect(migrated.tutorial == .turn && played.tutorial == .compare)
        #expect(try engine.digest() == saved.digest)
        // An envelope of schema 4 (since feature 447 the current schema is 3) is refused and changes nothing.
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
        // Opening through wins: levels 1 → 2 → 3 by their certified plans and level.next.
        var core: Core = try await Core.prepare(seed: 0)
        for number in 1...3 {
            #expect(core.levelNumber == number)
            for step in try Self.plan(number) { #expect(core.apply(Self.act(step)) == .accepted) }
            #expect(core.play.stage == .won && core.progress.frontier == number + 1)
            #expect(core.apply(Self.act("level.next")) == .accepted)
        }
        #expect(core.levelNumber == 4)
        // Opening through `open(through:)`: a saved progress with every level open makes every level selectable.
        var progress: VoxelOrigamiProgress = VoxelOrigamiProgress()
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
        // Selecting through the adapter: the last level of every band (certifying all 100 would not keep this short;
        // the only refusal of `level.select` in range is `progress.isOpen`).
        let samples: [Int] = [20, 40, 60, 80, 100]
        let refused: ActionResult = .rejected(.rule(code: "r02-g15.locked"))
        for number in samples {
            var copy: Core = allOpen
            #expect(copy.apply(Self.act("level.select", [Double(number)])) == .accepted, "level \(number)")
            #expect(copy.levelNumber == number && copy.mode == .campaign && copy.play.stage == .playing)
            var locked: Core = fresh
            #expect(locked.apply(Self.act("level.select", [Double(number)])) == refused)
        }
    }
}
