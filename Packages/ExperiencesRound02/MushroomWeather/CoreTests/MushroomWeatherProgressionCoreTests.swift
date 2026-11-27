// MushroomWeatherProgressionCoreTests — feature 495 (R02-G20-05) T-R02G2005-004 (FR-R02G2005-001, 004, 005, 006,
// 007; clarifications Q2–Q5; contracts/api.md). The adapter's teaching and progression: the fourteen controls in order
// with their ranges and the progression refusals (`r02-g20.locked`, `r02-g20.date`, the engine's range and count
// checks, `r02-g20.not-whole`) changing nothing; `level.select` of open and locked levels; `level.next` to the next
// open level and refused at the frontier (no wrap); a campaign win (the certified actions, then `weather.run`) records
// 3 stars and opens the next level, while pod detours (undone ones counted) give 2 or 1 stars and a worse result keeps
// the best one; practice (budget 24 on a copy of the level, a win records nothing); daily (2026-11-26 is level 94,
// playable while locked and not opened, a daily win records the level's best result; 2026-02-30 is refused); campaign
// returns (the frontier when the current level is not open); the tutorial (place → balance → recover → done, advanced
// by a placement, then any second pod, vent or moonlight action, and the end of the level, never by `clock.show`,
// never back on undo; `tutorial.dismiss` → done); progress and mode digested but never the tutorial step or the shown
// cycle; the schema-2 payload round trip in every mode and damaged payloads refused; the migration of a schema-1
// payload `{"level", "records"}` through `migrations` (levels 1 … n open, campaign, the tutorial's first step) and a
// newer schema refused; reset returns to the opening state. Level facts used: level 1's certified plan is a pod in
// slot 0 on (2, 5), then vent 0 shut (2 actions); (0, 4) is another site of level 1 and slot 1 is free; the run from
// an opening fails (a certified start never wins); levels 1 … 3 carry the tutorial; the daily level of 2026-11-26 is
// 94 (329 days × 17 mod 100 + 1) and of 2026-01-01 level 1. Explicit types, plain loops, no wall-clock asserts.
// Modelled on feature 485's MicroscopicAuroraProgressionCoreTests.
// Feature 497 (R02-G20-07) T-R02G2007-003: schema 3 and digest v3, eighteen controls, wins store their trace (the
// effective pod, vent and moonlight actions, an undone placement left out, then `.run`) as a verified result, the
// schema-3 payload carries the traces and the sound choice, the migration 1 → 2 → 3 (sound off, nothing to reconcile),
// and the refusal of schema 4; the replay, reconciliation and sound rules are in `MushroomWeatherReplayCoreTests` and
// `MushroomWeatherReconciliationTests`.
@testable import MushroomWeatherCore
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

@Suite struct MushroomWeatherProgressionCoreTests {
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

    /// A detour placement on level 1: a pod in slot 1 on the site (0, 4).
    static let detour: ExperienceAction = act("pod.place", [1, 0, 4])

    /// The certified plan's actions of level `number` (the run not included).
    static func plan(_ number: Int) throws -> [MushroomWeatherAction] {
        try Core.generated(number: number).plan.actions
    }

    /// Applies the certified plan of `core`'s level and the run; whether every action was accepted and the play won.
    static func win(_ core: inout Core) throws -> Bool {
        var accepted: Bool = true
        let steps: [MushroomWeatherAction] = try plan(core.levelNumber) + [.run]
        for step in steps {
            accepted = accepted && core.apply(act(step)) == .accepted
        }
        return accepted && core.play.stage == .won
    }

    /// The daily date 2026-11-26 and its level (94: not a tutorial level, not open on a fresh opening of level 1).
    static func plainDaily() throws -> (date: [Double], level: Int) {
        let date: [Double] = [2026, 11, 26]
        let level: Int = try #require(MushroomWeatherProgress.dailyLevel(year: 2026, month: 11, day: 26))
        try #require(level > MushroomWeatherTutorialStep.tutorialLevels.upperBound)
        return (date, level)
    }

    /// The schema-1 object `{"level", "records"}` of `core`.
    static func schemaOne(_ core: Core) throws -> [String: Any] {
        let records: Data = try Core.payloadEncoder().encode(core.play.records)
        let recordsObject: Any = try JSONSerialization.jsonObject(with: records)
        return ["level": core.levelNumber, "records": recordsObject]
    }

    @Test func theEighteenControlsAreDeclaredInOrder() {
        #expect(Core.schemaVersion == 3 && Core.digestDomain == "r02-g20.mushroom-weather.v3")
        let ids: [String] = ["pod.place", "pod.remove", "vent.set", "moon.set", "weather.run", "play.undo",
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
        #expect(MushroomWeatherExperienceRule.locked == "r02-g20.locked")
        #expect(MushroomWeatherExperienceRule.date == "r02-g20.date")
        #expect(Core.practiceBudget == 24 && MushroomWeatherMode.practiceBudget == 24)
    }

    @Test func theProgressionControlsRefuseWhatTheyMust() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let locked: ActionResult = .rejected(.rule(code: "r02-g20.locked"))
        let date: ActionResult = .rejected(.rule(code: "r02-g20.date"))
        let notWhole: ActionResult = .rejected(.rule(code: "r02-g20.not-whole"))
        let noValues: ActionResult = .rejected(.wrongValueCount(expected: 0, found: 1))
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
            noValues, noValues, noValues,
            locked,
        ]
        #expect(actions.count == expected.count)
        for index in actions.indices {
            var copy: Core = core
            #expect(copy.apply(actions[index]) == expected[index], "\(actions[index].control) \(actions[index].values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening, "\(actions[index].control) \(actions[index].values)")
            #expect(copy.shownCycle == core.shownCycle && copy.tutorial == core.tutorial)
        }
        // A leap year's 29 February is a date.
        var leap: Core = core
        #expect(leap.apply(Self.act("mode.daily", [2028, 2, 29])) == .accepted)
        let leapLevel: Int = try #require(MushroomWeatherProgress.dailyLevel(year: 2028, month: 2, day: 29))
        #expect(leap.mode == .daily(level: leapLevel) && leap.levelNumber == leapLevel)
        #expect(!leap.play.canUndo && leap.play.stage == .playing && leap.progress == core.progress)
        // Selecting the open level 1 reopens it fresh in campaign mode, dropping the records.
        var selected: Core = core
        #expect(selected.apply(Self.detour) == .accepted && selected.play.canUndo)
        let cycles: Int = selected.play.report.cycles
        try #require(cycles > 0)
        #expect(selected.apply(Self.act("clock.show", [Double(cycles)])) == .accepted)
        #expect(selected.apply(Self.act("level.select", [1])) == .accepted)
        #expect(selected == core && selected.shownCycle == 0 && !selected.play.canUndo)
    }

    @Test func campaignWinsRecordStarsAndOpenTheNextLevel() async throws {
        let actions: [MushroomWeatherAction] = try Self.plan(1)
        let certified: Int = actions.count
        let expectedPlan: [MushroomWeatherAction] = [.place(slot: 0, cell: MushroomWeatherCell(row: 2, column: 5)),
                                                      .vent(index: 0, open: false)]
        #expect(certified == 2 && actions == expectedPlan)
        // The plan, then the run: 3 stars, level 2 opened.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.certifiedActionCount == certified && core.mode == .campaign && core.progress.frontier == 1)
        let firstPlan: MushroomWeatherPlan = try Core.generated(number: 1).plan
        #expect(core.certifiedPlan == firstPlan && core.band == 1)
        for step in actions { #expect(core.apply(Self.act(step)) == .accepted) }
        // The arrangement actions alone record nothing: only the winning run does.
        #expect(core.progress.solved.isEmpty && core.progress.frontier == 1)
        #expect(core.apply(Self.act("weather.run")) == .accepted)
        #expect(core.play.stage == .won && MushroomWeatherProgress.actionsSpent(core.play) == certified)
        // Feature 497: the result carries the winning trace (the certified actions, then the run), verified.
        let best = MushroomWeatherProgress.Result(actionsSpent: certified, stars: 3, trace: actions + [.run],
                                                  verified: true)
        #expect(core.progress.solved[1] == best && core.progress.stars(of: 1) == 3)
        #expect(core.progress.frontier == 2 && core.progress.isOpen(2) && !core.progress.isOpen(3))
        // level.next goes to the newly opened level 2, fresh, with its tutorial and certified plan.
        var next: Core = core
        #expect(next.apply(Self.act("level.next")) == .accepted)
        #expect(next.levelNumber == 2 && !next.play.canUndo && next.mode == .campaign && next.shownCycle == 0)
        let secondPlan: MushroomWeatherPlan = try Core.generated(number: 2).plan
        #expect(next.tutorial == .place && next.certifiedPlan == secondPlan)
        // level.next from the frontier is refused: no next open level, nothing changes.
        let frontier: Core = next
        #expect(next.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g20.locked")))
        #expect(next == frontier && next.levelNumber == 2)
        // The frontier: level 2 can be chosen, level 3 cannot.
        #expect(core.apply(Self.act("level.select", [3])) == .rejected(.rule(code: "r02-g20.locked")))
        #expect(core.apply(Self.act("level.select", [2])) == .accepted)
        #expect(core.levelNumber == 2 && core.play.stage == .playing && core.tutorial == .place)
        // A failed run records nothing.
        var failed: Core = try Core.opening(number: 1)
        #expect(failed.apply(Self.act("weather.run")) == .accepted && failed.play.stage == .failed)
        #expect(failed.progress.solved.isEmpty && failed.progress.frontier == 1)
    }

    @Test func detoursGiveTwoOrOneStarsAndTheBestResultIsKept() async throws {
        let actions: [MushroomWeatherAction] = try Self.plan(1)
        let certified: Int = actions.count
        // One undone placement more than the plan: 2 stars.
        var undone: Core = try await Core.prepare(seed: 0)
        #expect(undone.apply(Self.detour) == .accepted)
        #expect(undone.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.win(&undone))
        #expect(MushroomWeatherProgress.actionsSpent(undone.play) == certified + 1)
        // Feature 497: the undone placement is left out of the trace.
        let twoStars = MushroomWeatherProgress.Result(actionsSpent: certified + 1, stars: 2,
                                                      trace: actions + [.run], verified: true)
        #expect(undone.progress.solved[1] == twoStars && undone.progress.frontier == 2)
        // A placement and its removal: two actions more than the plan, still 2 stars.
        var removed: Core = try await Core.prepare(seed: 0)
        #expect(removed.apply(Self.detour) == .accepted)
        #expect(removed.apply(Self.act("pod.remove", [1])) == .accepted)
        #expect(try Self.win(&removed))
        #expect(MushroomWeatherProgress.actionsSpent(removed.play) == certified + 2)
        // Feature 497: an effective placement and removal stay in the trace.
        let detourTrace: [MushroomWeatherAction] = [.place(slot: 1, cell: MushroomWeatherCell(row: 0, column: 4)),
                                                    .remove(slot: 1)]
        let removedResult = MushroomWeatherProgress.Result(actionsSpent: certified + 2, stars: 2,
                                                           trace: detourTrace + actions + [.run], verified: true)
        #expect(removed.progress.solved[1] == removedResult)
        // Three undone placements more than the plan: 1 star.
        var many: Core = try await Core.prepare(seed: 0)
        for _ in 0..<3 {
            #expect(many.apply(Self.detour) == .accepted)
            #expect(many.apply(Self.act("play.undo")) == .accepted)
        }
        #expect(try Self.win(&many))
        #expect(MushroomWeatherProgress.actionsSpent(many.play) == certified + 3)
        let oneStar = MushroomWeatherProgress.Result(actionsSpent: certified + 3, stars: 1,
                                                     trace: actions + [.run], verified: true)
        #expect(many.progress.solved[1] == oneStar)
        // A better result replaces the stored one; a worse one keeps it.
        #expect(many.apply(Self.act("level.select", [1])) == .accepted)
        #expect(try Self.win(&many))
        let best = MushroomWeatherProgress.Result(actionsSpent: certified, stars: 3, trace: actions + [.run],
                                                  verified: true)
        #expect(many.progress.solved[1] == best)
        #expect(many.apply(Self.act("level.select", [1])) == .accepted)
        #expect(many.apply(Self.detour) == .accepted)
        #expect(many.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.win(&many))
        #expect(many.progress.solved[1] == best && many.progress.frontier == 2)
        // A won play is final: it cannot be undone or run again, so it is recorded once.
        let recorded: MushroomWeatherProgress = many.progress
        #expect(many.apply(Self.act("play.undo")) == .rejected(.rule(code: "r02-g20.stage")))
        #expect(many.apply(Self.act("weather.run")) == .rejected(.rule(code: "r02-g20.stage")))
        #expect(many.progress == recorded)
        // The winning arrangement redone without the run is no win.
        var plain: Core = try Core.opening(number: 1)
        for step in actions { #expect(plain.apply(Self.act(step)) == .accepted) }
        #expect(plain.apply(Self.act("play.undo")) == .accepted)
        #expect(plain.apply(Self.act("play.redo")) == .accepted && plain.play.stage == .playing)
        #expect(plain.play.report.wins && plain.progress.solved.isEmpty)
    }

    @Test func practiceAndDailyFollowTheirRules() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let certified: MushroomWeatherLevel = try Core.level(number: 1)
        // Practice: a copy of the level with the budget raised to 24; a win records nothing and opens nothing.
        let cycles: Int = core.play.report.cycles
        try #require(cycles > 0)
        #expect(core.apply(Self.act("clock.show", [Double(cycles)])) == .accepted)
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == 1 && !core.play.canUndo && core.shownCycle == 0)
        #expect(core.play.level.budget == 24 && core.play.actionsLeft == 24 && core.tutorial == .place)
        #expect(certified.budget != 24)
        #expect(core.play.level.id == certified.id && core.play.level.seed == certified.seed)
        #expect(core.play.level.sites == certified.sites && core.play.level.colonies == certified.colonies)
        #expect(core.play.level.humidity == certified.humidity && core.play.level.vents == certified.vents)
        #expect(core.play.level.start == certified.start && core.play.level.podRules == certified.podRules)
        #expect(core.play.level.tutorial == certified.tutorial && core.play.level.length == certified.length)
        #expect(try Core.practiceLevel(of: certified) == core.play.level)
        let before: MushroomWeatherProgress = core.progress
        #expect(try Self.win(&core))
        #expect(core.progress == before && core.progress.solved.isEmpty && core.progress.frontier == 1)
        // Campaign returns to the current level when it is open, fresh, with the certified budget.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && !core.play.canUndo)
        #expect(core.play.level == certified && core.play.actionsLeft == certified.budget)
        // Daily: the date's level, playable while still locked; level.next from it is refused; a win records the
        // level's best result and stars and opens nothing.
        let (dailyDate, daily): ([Double], Int) = try Self.plainDaily()
        #expect(daily == 94 && !core.progress.isOpen(daily))
        #expect(core.apply(Self.act("mode.daily", dailyDate)) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily && core.tutorial == .done)
        let dailyCertified: MushroomWeatherLevel = try Core.level(number: daily)
        #expect(core.play.level == dailyCertified && !core.progress.isOpen(daily))
        #expect(core.band == MushroomWeatherProgress.band(of: daily) && core.band == 5)
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g20.locked")))
        let dailyActions: [MushroomWeatherAction] = try Self.plan(daily)
        #expect(core.certifiedActionCount == dailyActions.count)
        #expect(try Self.win(&core))
        #expect(core.progress.frontier == 1 && !core.progress.isOpen(daily))
        let result: MushroomWeatherProgress.Result = try #require(core.progress.solved[daily])
        #expect(result == MushroomWeatherProgress.Result(actionsSpent: dailyActions.count, stars: 3,
                                                          trace: dailyActions + [.run], verified: true))
        // Campaign from a level that is not open goes to the frontier.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.play.level == certified)
        // A daily tutorial level carries the tutorial: 2026-01-01 is level 1.
        #expect(MushroomWeatherProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 1])) == .accepted)
        #expect(core.mode == .daily(level: 1) && core.levelNumber == 1 && core.tutorial == .place)
    }

    @Test func progressAndModeAreDigestedButNotTheStepOrTheShownCycle() async throws {
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
        // Neither the shown cycle nor the tutorial step is digested.
        let campaignDigest: StateDigest = try Self.digest(campaign)
        let cycles: Int = campaign.play.report.cycles
        try #require(cycles > 0)
        var shown: Core = campaign
        #expect(shown.apply(Self.act("clock.show", [Double(cycles)])) == .accepted)
        #expect(shown == campaign && shown.shownCycle == cycles)
        #expect(try Self.digest(shown) == campaignDigest)
        var dismissed: Core = campaign
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed != campaign)
        #expect(try Self.digest(dismissed) == campaignDigest)
    }

    @Test func theTutorialAdvancesOnActionsAndNeverBack() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.tutorial == .place && core.tutorial.text.hasPrefix("Tap a marked site"))
        // Dismissing ends it; the step is state (==) and saved, but never digested.
        let digest: StateDigest = try Self.digest(core)
        var dismissed: Core = core
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed.tutorial == .done && dismissed != core && dismissed.play == core.play)
        #expect(try Self.digest(dismissed) == digest)
        #expect(try dismissed.snapshotPayload() != (try core.snapshotPayload()))
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted && dismissed.tutorial == .done)
        // Showing a cycle is no action: place stays.
        var shown: Core = core
        #expect(shown.apply(Self.act("clock.show", [1])) == .accepted && shown.tutorial == .place)
        // A refused placement moves nothing: a cell that is not a site.
        #expect(shown.apply(Self.act("pod.place", [0, 0, 0])) == .rejected(.rule(code: "r02-g20.action")))
        #expect(shown.tutorial == .place)
        // A vent before any placement is no placement: place stays.
        var vented: Core = core
        #expect(vented.apply(Self.act("vent.set", [0, 0])) == .accepted && vented.tutorial == .place)
        // A placement: place → balance; an undo does not move it back, nor a redo forward.
        #expect(core.apply(Self.detour) == .accepted)
        #expect(core.play.stage == .playing && core.tutorial == .balance)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .balance)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .balance)
        // A removal is a second action: balance → recover; recover lasts through undo and redo.
        #expect(core.apply(Self.act("pod.remove", [1])) == .accepted)
        #expect(core.play.stage == .playing && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .recover)
        #expect(core.apply(Self.act("pod.remove", [1])) == .accepted && core.tutorial == .recover)
        // The end of the level ends it: the certified plan and the winning run.
        #expect(try Self.win(&core))
        #expect(core.tutorial == .done)
        // The moonlight is a second action too: place → balance → recover.
        var moon: Core = try Core.opening(number: 1)
        #expect(moon.apply(Self.detour) == .accepted && moon.tutorial == .balance)
        #expect(moon.apply(Self.act("moon.set", [3])) == .accepted && moon.tutorial == .recover)
        // A run moves any step straight to done: the failing run from a fresh opening goes place → done; the undo
        // that retries does not bring it back; a redo that restores the failed play ends a step restored as place.
        var broken: Core = try Core.opening(number: 1)
        #expect(broken.apply(Self.act("weather.run")) == .accepted)
        #expect(broken.play.stage == .failed && broken.tutorial == .done)
        #expect(broken.apply(Self.act("play.undo")) == .accepted)
        #expect(broken.play.stage == .playing && broken.tutorial == .done)
        let brokenText: String = String(decoding: try broken.snapshotPayload(), as: UTF8.self)
        #expect(brokenText.hasSuffix(",\"tutorial\":\"done\"}"))
        let placeText: String = brokenText.replacingOccurrences(of: "\"tutorial\":\"done\"",
                                                                with: "\"tutorial\":\"place\"")
        var redone: Core = try Core.restore(payload: Data(placeText.utf8), seed: 0)
        #expect(redone.tutorial == .place && redone.play == broken.play && redone.play.canRedo)
        #expect(redone.apply(Self.act("play.redo")) == .accepted)
        #expect(redone.play.stage == .failed && redone.tutorial == .done)
        // Choosing a level or a mode restarts the step of that level; a level without the tutorial starts done.
        #expect(broken.apply(Self.act("mode.practice")) == .accepted && broken.tutorial == .place)
        for number in 1...5 {
            let opening: Core = try Core.opening(number: number)
            let expected: MushroomWeatherTutorialStep = number <= 3 ? .place : .done
            #expect(opening.tutorial == expected && MushroomWeatherTutorialStep.initial(level: number) == expected)
            #expect(opening.play.level.tutorial == (number <= 3))
        }
        var plain: Core = try Core.opening(number: 4)
        let plainFirst: MushroomWeatherAction = try #require(try Self.plan(4).first)
        #expect(plain.apply(Self.act(plainFirst)) == .accepted && plain.tutorial == .done)
        // The step is saved and restored.
        var saved: Core = try await Core.prepare(seed: 0)
        #expect(saved.apply(Self.detour) == .accepted)
        let payload: Data = try saved.snapshotPayload()
        #expect(String(decoding: payload, as: UTF8.self).hasSuffix(",\"tutorial\":\"balance\"}"))
        let restored: Core = try Core.restore(payload: payload, seed: 0)
        #expect(restored == saved && restored.tutorial == .balance)
    }

    @Test func theSchemaThreePayloadRoundTripsInEveryModeAndRefusesDamage() async throws {
        // Campaign with progress: level 1 won, level 2 reached with level.next.
        var campaign: Core = try await Core.prepare(seed: 0)
        #expect(try Self.win(&campaign))
        #expect(campaign.apply(Self.act("level.next")) == .accepted)
        #expect(campaign.levelNumber == 2 && campaign.tutorial == .place)
        // Practice: a placement on the practice copy.
        var practice: Core = try await Core.prepare(seed: 0)
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(practice.apply(Self.detour) == .accepted)
        // Daily: the first certified action of the date's level.
        let (dailyDate, dailyLevel): ([Double], Int) = try Self.plainDaily()
        var daily: Core = try await Core.prepare(seed: 0)
        #expect(daily.apply(Self.act("mode.daily", dailyDate)) == .accepted)
        let dailyFirst: MushroomWeatherAction = try #require(try Self.plan(dailyLevel).first)
        #expect(daily.apply(Self.act(dailyFirst)) == .accepted)
        let cores: [Core] = [campaign, practice, daily]
        for core in cores {
            let payload: Data = try core.snapshotPayload()
            #expect(try core.snapshotPayload() == payload)
            let restored: Core = try Core.restore(payload: payload, seed: 0)
            let restoredDigest: StateDigest = try Self.digest(restored)
            let savedDigest: StateDigest = try Self.digest(core)
            #expect(restored == core && restoredDigest == savedDigest, "\(core.mode)")
            #expect(restored.certifiedPlan == core.certifiedPlan && restored.openingNumber == 1)
            #expect(restored.shownCycle == 0)
            // Reset returns to the opening state: level 1, campaign, nothing won, the tutorial's first step.
            var reset: Core = restored
            reset.reset()
            #expect(reset == (try Core.opening(number: 1)))
            #expect(reset.mode == .campaign && reset.progress == MushroomWeatherProgress() && reset.shownCycle == 0)
            #expect(try Self.digest(reset) == Self.digest(try Core.opening(number: 1)))
        }
        let restoredPractice: Core = try Core.restore(payload: try practice.snapshotPayload(), seed: 0)
        #expect(restoredPractice.play.level.budget == 24 && restoredPractice.mode == .practice)
        let campaignText: String = String(decoding: try campaign.snapshotPayload(), as: UTF8.self)
        let certified: Int = try Self.plan(1).count
        // Feature 497: each result carries its trace (the certified actions, then the run) and its verification.
        let traceText: String = String(decoding: try Core.payloadEncoder().encode(try Self.plan(1) + [.run]),
                                       as: UTF8.self)
        let progressText: String = "\"progress\":{\"frontier\":2,"
            + "\"solved\":[{\"actionsSpent\":\(certified),\"level\":1,\"stars\":3,\"trace\":" + traceText
            + ",\"verified\":true}]}"
        #expect(campaignText.contains(progressText))
        #expect(campaignText.contains(",\"sound\":false,\"tutorial\":\"place\"}"))
        #expect(campaignText.hasPrefix("{\"level\":2,\"mode\":{\"mode\":\"campaign\"},"))
        #expect(campaignText.hasSuffix(",\"tutorial\":\"place\"}"))
        let dailyText: String = String(decoding: try daily.snapshotPayload(), as: UTF8.self)
        let dailyPrefix: String = "{\"level\":\(dailyLevel),\"mode\":{\"level\":\(dailyLevel)"
        #expect(dailyText.hasPrefix(dailyPrefix + ",\"mode\":\"daily\"},"))
        // Damaged: a daily mode naming another level, an unknown mode, an invalid frontier, invalid stars, negative
        // actions spent, an unknown tutorial step, progress of the wrong type.
        let otherPrefix: String = "{\"level\":\(dailyLevel),\"mode\":{\"level\":\(dailyLevel - 1)"
        let otherDaily: Data = Data(dailyText.replacingOccurrences(of: dailyPrefix, with: otherPrefix).utf8)
        let unknownMode: Data = Data(campaignText.replacingOccurrences(of: "\"mode\":\"campaign\"",
                                                                       with: "\"mode\":\"arcade\"").utf8)
        let badFrontier: Data = Data(campaignText.replacingOccurrences(of: "\"frontier\":2",
                                                                       with: "\"frontier\":0").utf8)
        let farFrontier: Data = Data(campaignText.replacingOccurrences(of: "\"frontier\":2",
                                                                       with: "\"frontier\":101").utf8)
        let badStars: Data = Data(campaignText.replacingOccurrences(of: "\"stars\":3", with: "\"stars\":4").utf8)
        let badSpent: Data = Data(campaignText.replacingOccurrences(of: "\"actionsSpent\":\(certified)",
                                                                    with: "\"actionsSpent\":-1").utf8)
        let badStep: Data = Data(campaignText.replacingOccurrences(of: "\"tutorial\":\"place\"",
                                                                   with: "\"tutorial\":\"later\"").utf8)
        let badProgress: Data = Data(campaignText.replacingOccurrences(of: progressText,
                                                                       with: "\"progress\":7").utf8)
        let damaged: [Data] = [otherDaily, unknownMode, badFrontier, farFrontier, badStars, badSpent, badStep,
                               badProgress]
        let campaignPayload: Data = try campaign.snapshotPayload()
        let dailyPayload: Data = try daily.snapshotPayload()
        for payload in damaged {
            #expect(payload != campaignPayload && payload != dailyPayload)
            #expect(throws: MushroomWeatherRestoreRefusal.damaged) { try Core.restore(payload: payload, seed: 0) }
        }
        // A schema-1 object is no schema-3 payload (the engine migrates it first).
        #expect(throws: MushroomWeatherRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":2,\"records\":[]}".utf8), seed: 0)
        }
        // A payload without the tutorial key starts the tutorial at the level's first step.
        let noStep: Data = Data(campaignText.replacingOccurrences(of: ",\"tutorial\":\"place\"", with: "").utf8)
        #expect(noStep != campaignPayload)
        let restoredNoStep: Core = try Core.restore(payload: noStep, seed: 0)
        #expect(restoredNoStep == campaign)
    }

    @Test func aSchemaOnePayloadMigratesAndANewerSchemaIsRefused() async throws {
        // Level 3 after its first certified action: the tutorial has advanced, which schema 1 did not save.
        var core: Core = try await Core.prepare(seed: 2)
        #expect(core.levelNumber == 3)
        let plan: [MushroomWeatherAction] = try Self.plan(3)
        let first: MushroomWeatherAction = try #require(plan.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        var isPlacement: Bool = false
        if case .place = first { isPlacement = true }
        #expect(core.tutorial == (isPlacement ? .balance : .place))
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
        #expect(restored.tutorial == .place && restored.tutorial == MushroomWeatherTutorialStep.initial(level: 3))
        // Feature 497: the migration 2 → 3 sets the sound off; nothing to reconcile.
        #expect(migrated["sound"] as? Bool == false && !restored.soundOn && restored.reconciliationDropped == 0)
        // The tutorial step is not digested, so the migrated state digests as the saved one.
        #expect(try Self.digest(restored) == Self.digest(core))
        // A level without the tutorial migrates with it done: the fresh opening of level 7.
        let sevenOpening: Core = try Core.opening(number: 7)
        let seven: [String: Any] = try Core.migrations.migrate(try Self.schemaOne(sevenOpening), from: 1)
        let sevenData: Data = try JSONSerialization.data(withJSONObject: seven, options: [.sortedKeys])
        let sevenCore: Core = try Core.restore(payload: sevenData, seed: 6)
        #expect(sevenCore == sevenOpening && sevenCore.tutorial == .done && sevenCore.progress.frontier == 7)
        // A schema-1 object that is not one is refused.
        #expect(throws: MushroomWeatherRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": "3"]) }
        #expect(throws: MushroomWeatherRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": 3]) }
        // A newer schema is refused by the chain.
        #expect(Core.schemaVersion == 3)
        #expect(throws: MigrationError.newerVersion(4)) { try Core.migrations.migrate(schemaOne, from: 4) }
    }

    @Test func theEngineMigratesASchemaOneEnvelopeAndRefusesANewerOne() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 2)
        try engine.activate()
        // Level 3: its first certified action.
        let first: MushroomWeatherAction = try #require(try Self.plan(3).first)
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
        #expect(migrated.tutorial == .place && !migrated.soundOn)
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
        // A saved progress with every level open makes every level selectable; level.next never wraps past 100.
        var progress: MushroomWeatherProgress = MushroomWeatherProgress()
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
        let refused: ActionResult = .rejected(.rule(code: "r02-g20.locked"))
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
