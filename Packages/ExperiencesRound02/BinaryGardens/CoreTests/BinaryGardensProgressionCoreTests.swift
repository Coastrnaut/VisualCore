// BinaryGardensProgressionCoreTests — feature 505 (R02-G21-05) T-R02G2105-004 (FR-R02G2105-001, 004, 005, 006, 007;
// SC-R02G2105-004, 005; clarifications Q2–Q6; contracts/api.md). The adapter's teaching and progression: the fourteen
// controls in order with their ranges and the progression refusals (`r02-g21.locked`, `r02-g21.date`, the engine's
// range and count checks, `r02-g21.not-whole`) changing nothing; `level.select` of open and locked levels;
// `level.next` to the next open level and refused at the frontier (no wrap); a campaign win (the certified actions,
// then `light.run`) records 3 stars and opens the next level, while undone detours (counted) give 2 or 1 stars and a
// worse result keeps the best one; practice (budget 24 on a copy of the level, a win records nothing); daily
// (2026-11-27 is level 91, playable while locked and not opened, a daily win records the level's best result;
// 2026-02-30 is refused); campaign returns (the frontier when the current level is not open); the tutorial
// (adjust → balance → recover → done, advanced by a first and a second accepted arrangement action and the end of the
// level, never by `clock.show`, never back on undo or redo; `tutorial.dismiss` → done); progress and mode digested but
// never the tutorial step or the shown tick; the schema-2 payload round trip in every mode and damaged payloads
// refused; the migration of a schema-1 payload `{"level", "records"}` of every level 1 … 100 through `migrations`
// (levels 1 … n open, nothing won, campaign, the tutorial's first step, the play replayed exactly; SC-R02G2105-005) and
// a newer schema refused; reset returns to the opening state; the certified plan exposed for hints and stars. Level
// facts used: level 1's certified plan is star 2's luminosity to index 0 (1 action, budget 9); star 2 may move to ring
// 1 and then ring 2 from level 1's opening, star 1's ring is locked; the run from an opening fails (a certified start
// never wins); levels 1 … 3 carry the tutorial; the daily level of 2026-11-27 is 91 (330 days × 13 mod 100 + 1) and of
// 2026-01-01 level 1. Seed 2_505 names no random source here: every input is fixed. Explicit types, plain loops, no
// wall-clock asserts. Modelled on feature 495's MushroomWeatherProgressionCoreTests.
// Feature 507 (R02-G21-07) T-R02G2107-003 (clarification Q6): schema 3 and digest v3, eighteen controls, wins store
// their trace (the effective ring, phase, luminosity and tilt actions, an undone detour left out, then `.run`) as a
// verified result, the schema-3 payload carries the traces and the sound choice, the migration 1 → 2 → 3 (sound off,
// nothing to reconcile), and the refusal of schema 4; the replay, reconciliation and sound rules are in
// `BinaryGardensReplayCoreTests` and `BinaryGardensReconciliationTests`.
@testable import BinaryGardensCore
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

@Suite struct BinaryGardensProgressionCoreTests {
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

    /// A detour on level 1: star 2 to ring 1.
    static let detour: ExperienceAction = act("star.ring", [1, 1])

    /// The certified plan's actions of level `number` (the run not included).
    static func plan(_ number: Int) throws -> [BinaryGardensAction] {
        try Core.generated(number: number).plan.actions
    }

    /// Applies the certified plan of `core`'s level and the run; whether every action was accepted and the play won.
    static func win(_ core: inout Core) throws -> Bool {
        var accepted: Bool = true
        let steps: [BinaryGardensAction] = try plan(core.levelNumber) + [.run]
        for step in steps {
            accepted = accepted && core.apply(act(step)) == .accepted
        }
        return accepted && core.play.stage == .won
    }

    /// The daily date 2026-11-27 and its level (91: not a tutorial level, not open on a fresh opening of level 1).
    static func plainDaily() throws -> (date: [Double], level: Int) {
        let date: [Double] = [2026, 11, 27]
        let level: Int = try #require(BinaryGardensProgress.dailyLevel(year: 2026, month: 11, day: 27))
        try #require(level > BinaryGardensTutorialStep.tutorialLevels.upperBound)
        return (date, level)
    }

    /// The schema-1 object `{"level", "records"}` of `core`.
    static func schemaOne(_ core: Core) throws -> [String: Any] {
        let records: Data = try Core.payloadEncoder().encode(core.play.records)
        let recordsObject: Any = try JSONSerialization.jsonObject(with: records)
        return ["level": core.levelNumber, "records": recordsObject]
    }

    @Test func theEighteenControlsAreDeclaredInOrder() {
        #expect(Core.schemaVersion == 3 && Core.digestDomain == "r02-g21.binary-gardens.v3")
        let ids: [String] = ["star.ring", "star.phase", "star.luminosity", "orbit.tilt", "light.run", "play.undo",
                             "play.redo", "level.next", "clock.show", "level.select", "mode.daily", "mode.practice",
                             "mode.campaign", "tutorial.dismiss", "replay.start", "replay.step", "replay.stop",
                             "settings.sound"]
        #expect(Core.actionIDs == ids && Core.controls.map(\.id) == ids && Core.controls.count == 18)
        #expect(Core.controls[14].ranges == [1...100] && Core.controls[17].ranges == [0...1])
        #expect(Core.controls[9].ranges == [1...100])
        #expect(Core.controls[10].ranges == [1...9999, 1...12, 1...31])
        let plainIndices: [Int] = [4, 5, 6, 7, 11, 12, 13, 15, 16]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty, "\(Core.controls[index].id)") }
        #expect(Core.migrations.currentVersion == 3)
        #expect(BinaryGardensExperienceRule.locked == "r02-g21.locked")
        #expect(BinaryGardensExperienceRule.date == "r02-g21.date")
        #expect(BinaryGardensExperienceRule.notWhole == "r02-g21.not-whole")
        #expect(Core.practiceBudget == 24 && BinaryGardensMode.practiceBudget == 24)
    }

    @Test func theProgressionControlsRefuseWhatTheyMust() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let locked: ActionResult = .rejected(.rule(code: "r02-g21.locked"))
        let date: ActionResult = .rejected(.rule(code: "r02-g21.date"))
        let notWhole: ActionResult = .rejected(.rule(code: "r02-g21.not-whole"))
        let noValues: ActionResult = .rejected(.wrongValueCount(expected: 0, found: 1))
        let actions: [ExperienceAction] = [
            Self.act("level.select", [2]), Self.act("level.select", [100]), Self.act("level.select", [0]),
            Self.act("level.select", [101]), Self.act("level.select", [1.5]), Self.act("level.select", []),
            Self.act("level.select", [1, 1]),
            Self.act("mode.daily", [0, 1, 1]), Self.act("mode.daily", [2026, 13, 1]),
            Self.act("mode.daily", [2026, 1, 32]), Self.act("mode.daily", [2026, 2, 30]),
            Self.act("mode.daily", [2027, 2, 29]), Self.act("mode.daily", [2026, 4, 31]),
            Self.act("mode.daily", [2026, 1.5, 1]), Self.act("mode.daily", [2026, 1]),
            Self.act("mode.daily", [2026, 1, 1, 1]),
            Self.act("mode.practice", [1]), Self.act("mode.campaign", [1]), Self.act("tutorial.dismiss", [1]),
            Self.act("level.next"),
        ]
        let expected: [ActionResult] = [
            locked, locked, .rejected(.outOfRange(index: 0)),
            .rejected(.outOfRange(index: 0)), notWhole, .rejected(.wrongValueCount(expected: 1, found: 0)),
            .rejected(.wrongValueCount(expected: 1, found: 2)),
            .rejected(.outOfRange(index: 0)), .rejected(.outOfRange(index: 1)),
            .rejected(.outOfRange(index: 2)), date,
            date, date,
            notWhole, .rejected(.wrongValueCount(expected: 3, found: 2)),
            .rejected(.wrongValueCount(expected: 3, found: 4)),
            noValues, noValues, noValues,
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
        let leapLevel: Int = try #require(BinaryGardensProgress.dailyLevel(year: 2028, month: 2, day: 29))
        #expect(leap.mode == .daily(level: leapLevel) && leap.levelNumber == leapLevel)
        #expect(!leap.play.canUndo && leap.play.stage == .playing && leap.progress == core.progress)
        // Selecting the open level 1 reopens it fresh in campaign mode, dropping the records.
        var selected: Core = core
        #expect(selected.apply(Self.detour) == .accepted && selected.play.canUndo)
        #expect(selected.apply(Self.act("clock.show", [12])) == .accepted)
        #expect(selected.apply(Self.act("level.select", [1])) == .accepted)
        #expect(selected == core && selected.shownTick == 48 && !selected.play.canUndo)
    }

    @Test func campaignWinsRecordStarsAndOpenTheNextLevel() async throws {
        let actions: [BinaryGardensAction] = try Self.plan(1)
        let certified: Int = actions.count
        #expect(certified == 1 && actions == [.luminosity(star: 1, index: 0)])
        // The plan, then the run: 3 stars, level 2 opened.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.certifiedActionCount == certified && core.mode == .campaign && core.progress.frontier == 1)
        let firstPlan: BinaryGardensPlan = try Core.generated(number: 1).plan
        #expect(core.certifiedPlan == firstPlan && core.band == 1)
        for step in actions { #expect(core.apply(Self.act(step)) == .accepted) }
        // The arrangement actions alone record nothing: only the winning run does.
        #expect(core.progress.solved.isEmpty && core.progress.frontier == 1)
        #expect(core.apply(Self.act("light.run")) == .accepted)
        #expect(core.play.stage == .won && BinaryGardensProgress.actionsSpent(core.play) == certified)
        // Feature 507: the result carries the winning trace (the certified actions, then the run), verified.
        let best = BinaryGardensProgress.Result(actionsSpent: certified, stars: 3, trace: actions + [.run],
                                                verified: true)
        #expect(core.progress.solved[1] == best && core.progress.stars(of: 1) == 3)
        #expect(core.progress.frontier == 2 && core.progress.isOpen(2) && !core.progress.isOpen(3))
        // level.next goes to the newly opened level 2, fresh, with its tutorial and certified plan.
        var next: Core = core
        #expect(next.apply(Self.act("clock.show", [5])) == .accepted)
        #expect(next.apply(Self.act("level.next")) == .accepted)
        #expect(next.levelNumber == 2 && !next.play.canUndo && next.mode == .campaign && next.shownTick == 48)
        let secondPlan: BinaryGardensPlan = try Core.generated(number: 2).plan
        #expect(next.tutorial == .adjust && next.certifiedPlan == secondPlan)
        #expect(next.certifiedActionCount == secondPlan.size)
        // level.next from the frontier is refused: no next open level, nothing changes.
        let frontier: Core = next
        #expect(next.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g21.locked")))
        #expect(next == frontier && next.levelNumber == 2)
        // The frontier: level 2 can be chosen, level 3 cannot.
        #expect(core.apply(Self.act("level.select", [3])) == .rejected(.rule(code: "r02-g21.locked")))
        #expect(core.apply(Self.act("level.select", [2])) == .accepted)
        #expect(core.levelNumber == 2 && core.play.stage == .playing && core.tutorial == .adjust)
        // A failed run records nothing.
        var failed: Core = try Core.opening(number: 1)
        #expect(failed.apply(Self.act("light.run")) == .accepted && failed.play.stage == .failed)
        #expect(failed.progress.solved.isEmpty && failed.progress.frontier == 1)
    }

    @Test func detoursGiveTwoOrOneStarsAndTheBestResultIsKept() async throws {
        let actions: [BinaryGardensAction] = try Self.plan(1)
        let certified: Int = actions.count
        // One undone change more than the plan: 2 stars.
        var undone: Core = try await Core.prepare(seed: 0)
        #expect(undone.apply(Self.detour) == .accepted)
        #expect(undone.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.win(&undone))
        #expect(BinaryGardensProgress.actionsSpent(undone.play) == certified + 1)
        // Feature 507: the undone detour is left out of the trace.
        let twoStars = BinaryGardensProgress.Result(actionsSpent: certified + 1, stars: 2, trace: actions + [.run],
                                                    verified: true)
        #expect(undone.progress.solved[1] == twoStars && undone.progress.frontier == 2)
        // Two undone changes more than the plan: still 2 stars.
        var twice: Core = try await Core.prepare(seed: 0)
        for _ in 0..<2 {
            #expect(twice.apply(Self.detour) == .accepted)
            #expect(twice.apply(Self.act("play.undo")) == .accepted)
        }
        #expect(try Self.win(&twice))
        let twiceResult = BinaryGardensProgress.Result(actionsSpent: certified + 2, stars: 2,
                                                       trace: actions + [.run], verified: true)
        #expect(twice.progress.solved[1] == twiceResult)
        // Three undone changes more than the plan: 1 star.
        var many: Core = try await Core.prepare(seed: 0)
        for _ in 0..<3 {
            #expect(many.apply(Self.detour) == .accepted)
            #expect(many.apply(Self.act("play.undo")) == .accepted)
        }
        #expect(try Self.win(&many))
        #expect(BinaryGardensProgress.actionsSpent(many.play) == certified + 3)
        let oneStar = BinaryGardensProgress.Result(actionsSpent: certified + 3, stars: 1, trace: actions + [.run],
                                                   verified: true)
        #expect(many.progress.solved[1] == oneStar)
        // A better result replaces the stored one; a worse one keeps it.
        #expect(many.apply(Self.act("level.select", [1])) == .accepted)
        #expect(try Self.win(&many))
        let best = BinaryGardensProgress.Result(actionsSpent: certified, stars: 3, trace: actions + [.run],
                                                verified: true)
        #expect(many.progress.solved[1] == best)
        #expect(many.apply(Self.act("level.select", [1])) == .accepted)
        #expect(many.apply(Self.detour) == .accepted)
        #expect(many.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.win(&many))
        #expect(many.progress.solved[1] == best && many.progress.frontier == 2)
        // A won play is final: it cannot be undone or run again, so it is recorded once.
        let recorded: BinaryGardensProgress = many.progress
        #expect(many.apply(Self.act("play.undo")) == .rejected(.rule(code: "r02-g21.stage")))
        #expect(many.apply(Self.act("light.run")) == .rejected(.rule(code: "r02-g21.stage")))
        #expect(many.progress == recorded)
        // The winning arrangement redone without the run is no win.
        var plain: Core = try Core.opening(number: 1)
        for step in try Self.plan(1) { #expect(plain.apply(Self.act(step)) == .accepted) }
        #expect(plain.apply(Self.act("play.undo")) == .accepted)
        #expect(plain.apply(Self.act("play.redo")) == .accepted && plain.play.stage == .playing)
        #expect(plain.play.report.wins && plain.progress.solved.isEmpty)
    }

    @Test func practiceAndDailyFollowTheirRules() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let certified: BinaryGardensLevel = try Core.level(number: 1)
        // Practice: a copy of the level with the budget raised to 24; a win records nothing and opens nothing.
        #expect(core.apply(Self.act("clock.show", [7])) == .accepted)
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == 1 && !core.play.canUndo && core.shownTick == 48)
        #expect(core.play.level.budget == 24 && core.play.actionsLeft == 24 && core.tutorial == .adjust)
        #expect(certified.budget != 24)
        #expect(core.play.level.id == certified.id && core.play.level.seed == certified.seed)
        #expect(core.play.level.worlds == certified.worlds && core.play.level.stars == certified.stars)
        #expect(core.play.level.ringRadii == certified.ringRadii)
        #expect(core.play.level.luminosityLevels == certified.luminosityLevels)
        #expect(core.play.level.maxTilt == certified.maxTilt && core.play.level.startTilt == certified.startTilt)
        #expect(core.play.level.phaseStep == certified.phaseStep && core.play.level.tutorial == certified.tutorial)
        #expect(core.play.level.start == certified.start)
        #expect(try Core.practiceLevel(of: certified) == core.play.level)
        #expect(core.certifiedPlan == (try Core.generated(number: 1).plan))
        let before: BinaryGardensProgress = core.progress
        #expect(try Self.win(&core))
        #expect(core.progress == before && core.progress.solved.isEmpty && core.progress.frontier == 1)
        // Campaign returns to the current level when it is open, fresh, with the certified budget.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && !core.play.canUndo)
        #expect(core.play.level == certified && core.play.actionsLeft == certified.budget)
        // Daily: the date's level, playable while still locked; level.next from it is refused; a win records the
        // level's best result and stars and opens nothing.
        let (dailyDate, daily): ([Double], Int) = try Self.plainDaily()
        #expect(daily == 91 && !core.progress.isOpen(daily))
        #expect(core.apply(Self.act("mode.daily", dailyDate)) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily && core.tutorial == .done)
        let dailyCertified: BinaryGardensLevel = try Core.level(number: daily)
        #expect(core.play.level == dailyCertified && !core.progress.isOpen(daily))
        #expect(core.band == BinaryGardensProgress.band(of: daily) && core.band == 5)
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g21.locked")))
        let dailyActions: [BinaryGardensAction] = try Self.plan(daily)
        #expect(core.certifiedActionCount == dailyActions.count)
        #expect(try Self.win(&core))
        #expect(core.progress.frontier == 1 && !core.progress.isOpen(daily))
        let result: BinaryGardensProgress.Result = try #require(core.progress.solved[daily])
        #expect(result == BinaryGardensProgress.Result(actionsSpent: dailyActions.count, stars: 3,
                                                        trace: dailyActions + [.run], verified: true))
        // Campaign from a level that is not open goes to the frontier.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.play.level == certified)
        // A daily tutorial level carries the tutorial: 2026-01-01 is level 1.
        #expect(BinaryGardensProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 1])) == .accepted)
        #expect(core.mode == .daily(level: 1) && core.levelNumber == 1 && core.tutorial == .adjust)
        // Practice from the daily level practises that level.
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == 1 && core.play.level.budget == 24)
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
        let campaignDigest: StateDigest = try Self.digest(campaign)
        var shown: Core = campaign
        #expect(shown.apply(Self.act("clock.show", [30])) == .accepted)
        #expect(shown == campaign && shown.shownTick == 30)
        #expect(try Self.digest(shown) == campaignDigest)
        var dismissed: Core = campaign
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed != campaign)
        #expect(try Self.digest(dismissed) == campaignDigest)
    }

    @Test func theTutorialAdvancesOnActionsAndNeverBack() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.tutorial == .adjust && core.tutorial.text.hasPrefix("Change a star"))
        // Dismissing ends it; the step is state (==) and saved, but never digested.
        let digest: StateDigest = try Self.digest(core)
        var dismissed: Core = core
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed.tutorial == .done && dismissed != core && dismissed.play == core.play)
        #expect(try Self.digest(dismissed) == digest)
        #expect(try dismissed.snapshotPayload() != (try core.snapshotPayload()))
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted && dismissed.tutorial == .done)
        // Showing a tick is no action: adjust stays.
        var shown: Core = core
        #expect(shown.apply(Self.act("clock.show", [1])) == .accepted && shown.tutorial == .adjust)
        // A refused change moves nothing: star 1's ring is locked.
        #expect(shown.apply(Self.act("star.ring", [0, 1])) == .rejected(.rule(code: "r02-g21.action")))
        #expect(shown.tutorial == .adjust)
        // A change: adjust → balance; an undo does not move it back, nor a redo forward.
        #expect(core.apply(Self.detour) == .accepted)
        #expect(core.play.stage == .playing && core.tutorial == .balance)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .balance)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .balance)
        #expect(core.apply(Self.act("clock.show", [3])) == .accepted && core.tutorial == .balance)
        // A second change: balance → recover; recover lasts through undo and redo.
        #expect(core.apply(Self.act("star.ring", [1, 2])) == .accepted)
        #expect(core.play.stage == .playing && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .recover)
        // The end of the level ends it: the certified plan and the winning run.
        #expect(try Self.win(&core))
        #expect(core.tutorial == .done)
        // An undone first change still counts for the second step: change, undo, another change → recover.
        var counted: Core = try Core.opening(number: 1)
        #expect(counted.apply(Self.detour) == .accepted && counted.tutorial == .balance)
        #expect(counted.apply(Self.act("play.undo")) == .accepted && counted.tutorial == .balance)
        #expect(counted.apply(Self.act("star.luminosity", [1, 0])) == .accepted && counted.tutorial == .recover)
        // A run moves any step straight to done: the failing run from a fresh opening goes adjust → done; the undo
        // that retries does not bring it back; a redo that restores the failed play ends a step restored as adjust.
        var broken: Core = try Core.opening(number: 1)
        #expect(broken.apply(Self.act("light.run")) == .accepted)
        #expect(broken.play.stage == .failed && broken.tutorial == .done)
        #expect(broken.apply(Self.act("play.undo")) == .accepted)
        #expect(broken.play.stage == .playing && broken.tutorial == .done)
        let brokenText: String = String(decoding: try broken.snapshotPayload(), as: UTF8.self)
        #expect(brokenText.hasSuffix(",\"tutorial\":\"done\"}"))
        let adjustText: String = brokenText.replacingOccurrences(of: "\"tutorial\":\"done\"",
                                                                 with: "\"tutorial\":\"adjust\"")
        var redone: Core = try Core.restore(payload: Data(adjustText.utf8), seed: 0)
        #expect(redone.tutorial == .adjust && redone.play == broken.play && redone.play.canRedo)
        #expect(redone.apply(Self.act("play.redo")) == .accepted)
        #expect(redone.play.stage == .failed && redone.tutorial == .done)
        // Choosing a level or a mode restarts the step of that level; a level without the tutorial starts done.
        #expect(broken.apply(Self.act("mode.practice")) == .accepted && broken.tutorial == .adjust)
        for number in 1...5 {
            let opening: Core = try Core.opening(number: number)
            let expected: BinaryGardensTutorialStep = number <= 3 ? .adjust : .done
            #expect(opening.tutorial == expected && BinaryGardensTutorialStep.initial(level: number) == expected)
            #expect(opening.play.level.tutorial == (number <= 3))
        }
        var plain: Core = try Core.opening(number: 4)
        let plainFirst: BinaryGardensAction = try #require(try Self.plan(4).first)
        #expect(plain.apply(Self.act(plainFirst)) == .accepted && plain.tutorial == .done)
        // The step is saved and restored.
        var saved: Core = try await Core.prepare(seed: 0)
        #expect(saved.apply(Self.detour) == .accepted)
        let payload: Data = try saved.snapshotPayload()
        #expect(String(decoding: payload, as: UTF8.self).hasSuffix(",\"tutorial\":\"balance\"}"))
        let restored: Core = try Core.restore(payload: payload, seed: 0)
        #expect(restored == saved && restored.tutorial == .balance)
    }

    @Test func theCertifiedPlanFeedsTheHintsAndTheFailureText() async throws {
        // At the opening the exact hint is the certified plan's first action; the hint never changes the state.
        let core: Core = try await Core.prepare(seed: 0)
        let first: BinaryGardensAction = try #require(core.certifiedPlan.actions.first)
        let hint: BinaryGardensHint = try #require(core.hint(level: 3))
        #expect(hint.action == first && hint.level == 3)
        #expect(core.hint(level: 3) == BinaryGardensHints.hint(level: 3, play: core.play, certified: core.certifiedPlan))
        #expect(core.failureExplanation == nil)
        // Following the hint, then the run, wins in the certified count with 3 stars.
        var followed: Core = core
        #expect(followed.apply(Self.act(first)) == .accepted)
        let run: BinaryGardensHint = try #require(followed.hint(level: 1))
        #expect(run.kind == .run)
        #expect(followed.apply(Self.act("light.run")) == .accepted && followed.play.stage == .won)
        #expect(followed.hint(level: 1) == nil && followed.progress.stars(of: 1) == 3)
        // A failed run is explained and its hint is the retry advice.
        var failed: Core = core
        #expect(failed.apply(Self.act("light.run")) == .accepted && failed.play.stage == .failed)
        let explanation: BinaryGardensFailureExplanation = try #require(failed.failureExplanation)
        #expect(explanation.text.hasSuffix(BinaryGardensFailureExplanation.advice))
        #expect(failed.hint(level: 2)?.kind == .retry)
    }

    @Test func theSchemaThreePayloadRoundTripsInEveryModeAndRefusesDamage() async throws {
        // Campaign with progress: level 1 won, level 2 reached with level.next.
        var campaign: Core = try await Core.prepare(seed: 0)
        #expect(try Self.win(&campaign))
        #expect(campaign.apply(Self.act("level.next")) == .accepted)
        #expect(campaign.levelNumber == 2 && campaign.tutorial == .adjust)
        // Practice: a change on the practice copy.
        var practice: Core = try await Core.prepare(seed: 0)
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(practice.apply(Self.detour) == .accepted)
        // Daily: the first certified action of the date's level.
        let (dailyDate, dailyLevel): ([Double], Int) = try Self.plainDaily()
        var daily: Core = try await Core.prepare(seed: 0)
        #expect(daily.apply(Self.act("mode.daily", dailyDate)) == .accepted)
        let dailyFirst: BinaryGardensAction = try #require(try Self.plan(dailyLevel).first)
        #expect(daily.apply(Self.act(dailyFirst)) == .accepted)
        let cores: [Core] = [campaign, practice, daily]
        let openingOne: Core = try Core.opening(number: 1)
        for core in cores {
            let payload: Data = try core.snapshotPayload()
            #expect(try core.snapshotPayload() == payload)
            let restored: Core = try Core.restore(payload: payload, seed: 0)
            let restoredDigest: StateDigest = try Self.digest(restored)
            let savedDigest: StateDigest = try Self.digest(core)
            #expect(restored == core && restoredDigest == savedDigest, "\(core.mode)")
            #expect(restored.certifiedPlan == core.certifiedPlan && restored.openingNumber == 1)
            #expect(restored.shownTick == 48)
            // Reset returns to the opening state: level 1, campaign, nothing won, the tutorial's first step.
            var reset: Core = restored
            reset.reset()
            #expect(reset == openingOne)
            #expect(reset.mode == .campaign && reset.progress.solved.isEmpty && reset.progress.frontier == 1)
            #expect(reset.shownTick == 48 && reset.certifiedPlan == openingOne.certifiedPlan)
            #expect(try Self.digest(reset) == Self.digest(openingOne))
        }
        let restoredPractice: Core = try Core.restore(payload: try practice.snapshotPayload(), seed: 0)
        #expect(restoredPractice.play.level.budget == 24 && restoredPractice.mode == .practice)
        let campaignText: String = String(decoding: try campaign.snapshotPayload(), as: UTF8.self)
        let certified: Int = try Self.plan(1).count
        // Feature 507: each result carries its trace (the certified actions, then the run) and its verification.
        let traceText: String = String(decoding: try Core.payloadEncoder().encode(try Self.plan(1) + [.run]),
                                       as: UTF8.self)
        let progressText: String = "\"progress\":{\"frontier\":2,"
            + "\"solved\":[{\"actionsSpent\":\(certified),\"level\":1,\"stars\":3,\"trace\":" + traceText
            + ",\"verified\":true}]}"
        #expect(campaignText.contains(progressText))
        #expect(campaignText.contains(",\"sound\":false,\"tutorial\":\"adjust\"}"))
        #expect(campaignText.hasPrefix("{\"level\":2,\"mode\":{\"mode\":\"campaign\"},"))
        #expect(campaignText.hasSuffix(",\"tutorial\":\"adjust\"}"))
        let dailyText: String = String(decoding: try daily.snapshotPayload(), as: UTF8.self)
        let dailyPrefix: String = "{\"level\":\(dailyLevel),\"mode\":{\"level\":\(dailyLevel)"
        #expect(dailyText.hasPrefix(dailyPrefix + ",\"mode\":\"daily\"},"))
        // Damaged: a daily mode naming another level, an unknown mode, an invalid frontier, invalid stars, actions
        // spent below 1, an unknown tutorial step, progress of the wrong type.
        let otherPrefix: String = "{\"level\":\(dailyLevel),\"mode\":{\"level\":\(dailyLevel - 1)"
        let otherDaily: Data = Data(dailyText.replacingOccurrences(of: dailyPrefix, with: otherPrefix).utf8)
        let unknownMode: Data = Data(campaignText.replacingOccurrences(of: "\"mode\":\"campaign\"",
                                                                       with: "\"mode\":\"arcade\"").utf8)
        let badFrontier: Data = Data(campaignText.replacingOccurrences(of: "\"frontier\":2",
                                                                       with: "\"frontier\":0").utf8)
        let farFrontier: Data = Data(campaignText.replacingOccurrences(of: "\"frontier\":2",
                                                                       with: "\"frontier\":101").utf8)
        let badStars: Data = Data(campaignText.replacingOccurrences(of: "\"stars\":3", with: "\"stars\":4").utf8)
        let noStars: Data = Data(campaignText.replacingOccurrences(of: "\"stars\":3", with: "\"stars\":0").utf8)
        let badSpent: Data = Data(campaignText.replacingOccurrences(of: "\"actionsSpent\":\(certified)",
                                                                    with: "\"actionsSpent\":0").utf8)
        let badWonLevel: Data = Data(campaignText.replacingOccurrences(of: "\"level\":1,\"stars\"",
                                                                       with: "\"level\":101,\"stars\"").utf8)
        let badStep: Data = Data(campaignText.replacingOccurrences(of: "\"tutorial\":\"adjust\"",
                                                                   with: "\"tutorial\":\"later\"").utf8)
        let badProgress: Data = Data(campaignText.replacingOccurrences(of: progressText,
                                                                       with: "\"progress\":7").utf8)
        let damaged: [Data] = [otherDaily, unknownMode, badFrontier, farFrontier, badStars, noStars, badSpent,
                               badWonLevel, badStep, badProgress]
        let campaignPayload: Data = try campaign.snapshotPayload()
        let dailyPayload: Data = try daily.snapshotPayload()
        for payload in damaged {
            #expect(payload != campaignPayload && payload != dailyPayload)
            #expect(throws: BinaryGardensRestoreRefusal.damaged) { try Core.restore(payload: payload, seed: 0) }
        }
        // A level outside 1 … 100 in an otherwise valid payload.
        let farLevel: Data = Data(campaignText.replacingOccurrences(of: "{\"level\":2,", with: "{\"level\":101,").utf8)
        #expect(throws: BinaryGardensRestoreRefusal.levelNumber(101)) { try Core.restore(payload: farLevel, seed: 0) }
        // A trace the kernel refuses: level 2's records restored as level 3.
        let otherTrace: Data = Data(campaignText.replacingOccurrences(of: "{\"level\":2,", with: "{\"level\":3,").utf8)
        #expect(throws: BinaryGardensRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: otherTrace, seed: 0)
        }
        // A schema-1 object is no schema-3 payload (the engine migrates it first).
        #expect(throws: BinaryGardensRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":2,\"records\":[]}".utf8), seed: 0)
        }
        // A payload without the tutorial key starts the tutorial at the level's first step.
        let noStep: Data = Data(campaignText.replacingOccurrences(of: ",\"tutorial\":\"adjust\"", with: "").utf8)
        #expect(noStep != campaignPayload)
        let restoredNoStep: Core = try Core.restore(payload: noStep, seed: 0)
        #expect(restoredNoStep == campaign)
    }

    @Test func aSchemaOnePayloadMigratesAndANewerSchemaIsRefused() async throws {
        // Level 3 after its first certified action: the tutorial has advanced, which schema 1 did not save.
        var core: Core = try await Core.prepare(seed: 2)
        #expect(core.levelNumber == 3)
        let first: BinaryGardensAction = try #require(try Self.plan(3).first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.tutorial == .balance)
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
        #expect(restored.tutorial == .adjust && restored.tutorial == BinaryGardensTutorialStep.initial(level: 3))
        // Feature 507: the migration 2 → 3 sets the sound off; nothing to reconcile.
        #expect(migrated["sound"] as? Bool == false && !restored.soundOn && restored.reconciliationDropped == 0)
        // The tutorial step is not digested, so the migrated state digests as the saved one.
        #expect(try Self.digest(restored) == Self.digest(core))
        // A schema-1 object that is not one is refused.
        #expect(throws: BinaryGardensRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": "3"]) }
        #expect(throws: BinaryGardensRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": 3]) }
        // A newer schema is refused by the chain.
        #expect(Core.schemaVersion == 3)
        #expect(throws: MigrationError.newerVersion(4)) { try Core.migrations.migrate(schemaOne, from: 4) }
    }

    /// SC-R02G2105-005: a schema-1 payload of every level 1 … 100 (after its first certified action, so the trace
    /// replays) migrates to levels 1 … n open, nothing won, campaign, the tutorial's first step, the same play and the
    /// same digest. Ten groups of ten levels.
    @Test(arguments: 0..<10) func aSchemaOnePayloadOfEveryLevelMigrates(group: Int) async throws {
        for offset in 1...10 {
            let number: Int = group * 10 + offset
            var core: Core = try Core.opening(number: number)
            let first: BinaryGardensAction = try #require(core.certifiedPlan.actions.first, "level \(number)")
            #expect(core.apply(Self.act(first)) == .accepted, "level \(number)")
            let object: [String: Any] = try Core.migrations.migrate(try Self.schemaOne(core), from: 1)
            let data: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            let restored: Core = try Core.restore(payload: data, seed: UInt64(number - 1))
            #expect(restored.levelNumber == number && restored.play == core.play, "level \(number)")
            #expect(restored.mode == .campaign && restored.progress.solved.isEmpty, "level \(number)")
            #expect(restored.progress.frontier == number && restored.progress.isOpen(number), "level \(number)")
            #expect(!restored.progress.isOpen(number + 1), "level \(number)")
            let step: BinaryGardensTutorialStep = number <= 3 ? .adjust : .done
            #expect(restored.tutorial == step, "level \(number)")
            #expect(restored.certifiedPlan == core.certifiedPlan && restored.openingNumber == number)
            #expect(try Self.digest(restored) == Self.digest(core), "level \(number)")
        }
    }

    @Test func theEngineMigratesASchemaOneEnvelopeAndRefusesANewerOne() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 2)
        try engine.activate()
        // Level 3: its first certified action.
        let first: BinaryGardensAction = try #require(try Self.plan(3).first)
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
        #expect(migrated.tutorial == .adjust && !migrated.soundOn)
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
        // Opening through wins: levels 1 → 2 → 3 by their certified plans, the run and level.next.
        var core: Core = try await Core.prepare(seed: 0)
        for number in 1...3 {
            #expect(core.levelNumber == number)
            #expect(try Self.win(&core))
            #expect(core.progress.frontier == number + 1)
            #expect(core.apply(Self.act("level.next")) == .accepted)
        }
        #expect(core.levelNumber == 4 && core.tutorial == .done)
        // A fresh opening of level N has levels 1 … N open and nothing won.
        let opened: Core = try Core.opening(number: 7)
        #expect(opened.progress.frontier == 7 && opened.progress.solved.isEmpty && opened.mode == .campaign)
        var back: Core = opened
        #expect(back.apply(Self.act("level.select", [6])) == .accepted && back.levelNumber == 6)
        #expect(back.apply(Self.act("level.next")) == .accepted && back.levelNumber == 7)
        #expect(back.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g21.locked")))
        // A saved progress with every level open makes every level selectable; level.next never wraps past 100.
        var progress: BinaryGardensProgress = BinaryGardensProgress()
        progress.open(through: 100)
        let fresh: Core = try await Core.prepare(seed: 0)
        let text: String = String(decoding: try fresh.snapshotPayload(), as: UTF8.self)
        let progressJSON: String = String(decoding: try Core.payloadEncoder().encode(progress), as: UTF8.self)
        let allOpenText: String = text.replacingOccurrences(of: "\"progress\":{\"frontier\":1,\"solved\":[]}",
                                                            with: "\"progress\":" + progressJSON)
        #expect(allOpenText != text)
        let allOpen: Core = try Core.restore(payload: Data(allOpenText.utf8), seed: 0)
        #expect(allOpen.progress == progress)
        let samples: [Int] = [20, 40, 60, 80, 100]
        let refused: ActionResult = .rejected(.rule(code: "r02-g21.locked"))
        for number in samples {
            var copy: Core = allOpen
            #expect(copy.apply(Self.act("level.select", [Double(number)])) == .accepted, "level \(number)")
            #expect(copy.levelNumber == number && copy.mode == .campaign && copy.play.stage == .playing)
            #expect(copy.band == number / 20)
            var locked: Core = fresh
            #expect(locked.apply(Self.act("level.select", [Double(number)])) == refused)
        }
        var last: Core = allOpen
        #expect(last.apply(Self.act("level.select", [100])) == .accepted)
        #expect(last.apply(Self.act("level.next")) == refused && last.levelNumber == 100)
    }
}
