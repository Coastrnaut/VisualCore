// MicroscopicAuroraProgressionCoreTests — feature 485 (R02-G19-05) T-R02G1905-004 (FR-R02G1905-001, 004, 005, 006,
// 007; clarifications Q3–Q5; contracts/api.md). The adapter's teaching and progression: the twelve controls in order
// with their ranges and the progression refusals (`r02-g19.locked`, `r02-g19.date`, the engine's range and count
// checks, `r02-g19.not-whole`) changing nothing; `level.select` of open and locked levels; `level.next` to the next
// open level and refused at the frontier (no wrap); a campaign win (the certified placements, then `swim.play`)
// records 3 stars and opens the next level, while placement and removal detours (undone ones counted) give 2 or 1
// stars and a worse result keeps the best one; practice (budget 24 on a copy of the level, a win records nothing);
// daily (2026-11-26 is level 52, playable while locked and not opened, a daily win records the level's best result;
// 2026-02-30 is refused); campaign returns (the frontier when the current level is not open); the tutorial (place →
// cover → recover → done, advanced by placements and removals and the end of the level, never by `clock.show`, never
// back on undo; `tutorial.dismiss` → done); progress and mode digested but never the tutorial step or the shown tick;
// the schema-2 payload round trip in every mode and damaged payloads refused; the migration of a schema-1 payload
// `{"level", "records"}` through `migrations` (levels 1 … n open, campaign, the tutorial's first step) and a newer
// schema refused; reset returns to the opening state. Level facts used: level 1's certified plan is one clockwise
// well of strength 2 on (11, 18) in slot 0, (9, 7) is another site of level 1, the play from an opening fails (the
// starting wells never win), levels 1 … 3 carry the tutorial; the daily level of 2026-11-26 is 52 (329 days × 19 mod
// 100 + 1) and of 2026-01-01 level 1. Explicit types, plain loops, no wall-clock asserts. Modelled on feature 475's
// ApsidesWorkshopProgressionCoreTests.
@testable import MicroscopicAuroraCore
import Foundation
import Testing
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
import VisualCoreSimulation

@Suite struct MicroscopicAuroraProgressionCoreTests {
    typealias Core = MicroscopicAuroraExperienceCore

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
    static func act(_ action: MicroscopicAuroraAction) -> ExperienceAction {
        switch action {
        case let .place(slot, well):
            let sense: Double = well.sense == .clockwise ? 0 : 1
            return act("well.place", [Double(slot), Double(well.cell.row), Double(well.cell.column),
                                      Double(well.strength), sense])
        case let .remove(slot):
            return act("well.remove", [Double(slot)])
        case .play:
            return act("swim.play")
        }
    }

    /// A detour placement on level 1: a counterclockwise well of strength 1 on the site (9, 7) in slot 1.
    static let detour: ExperienceAction = act("well.place", [1, 9, 7, 1, 1])

    /// The certified plan's placements of level `number` (the play not included).
    static func plan(_ number: Int) throws -> [MicroscopicAuroraAction] {
        try Core.generated(number: number).plan.actions
    }

    /// Applies the certified plan of `core`'s level and the play; whether every action was accepted and the play won.
    static func win(_ core: inout Core) throws -> Bool {
        var accepted: Bool = true
        let steps: [MicroscopicAuroraAction] = try plan(core.levelNumber) + [.play]
        for step in steps {
            accepted = accepted && core.apply(act(step)) == .accepted
        }
        return accepted && core.play.stage == .won
    }

    /// The daily date 2026-11-26 and its level (52: not a tutorial level, not open on a fresh opening of level 1).
    static func plainDaily() throws -> (date: [Double], level: Int) {
        let date: [Double] = [2026, 11, 26]
        let level: Int = try #require(MicroscopicAuroraProgress.dailyLevel(year: 2026, month: 11, day: 26))
        try #require(level > MicroscopicAuroraTutorialStep.tutorialLevels.upperBound)
        return (date, level)
    }

    /// The schema-1 object `{"level", "records"}` of `core`.
    static func schemaOne(_ core: Core) throws -> [String: Any] {
        let records: Data = try Core.payloadEncoder().encode(core.play.records)
        let recordsObject: Any = try JSONSerialization.jsonObject(with: records)
        return ["level": core.levelNumber, "records": recordsObject]
    }

    @Test func theTwelveControlsAreDeclaredInOrder() {
        #expect(Core.schemaVersion == 2 && Core.digestDomain == "r02-g19.microscopic-aurora.v2")
        let ids: [String] = ["well.place", "well.remove", "swim.play", "play.undo", "play.redo", "level.next",
                             "clock.show", "level.select", "mode.daily", "mode.practice", "mode.campaign",
                             "tutorial.dismiss"]
        #expect(Core.actionIDs == ids && Core.controls.map(\.id) == ids && Core.controls.count == 12)
        #expect(Core.controls[0].ranges == [0...2, 0...23, 0...23, 1...4, 0...1])
        #expect(Core.controls[1].ranges == [0...2])
        #expect(Core.controls[6].ranges == [0...480])
        #expect(Core.controls[7].ranges == [1...100])
        #expect(Core.controls[8].ranges == [1...9999, 1...12, 1...31])
        let plainIndices: [Int] = [2, 3, 4, 5, 9, 10, 11]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty, "\(Core.controls[index].id)") }
        #expect(Core.migrations.currentVersion == 2)
        #expect(MicroscopicAuroraExperienceRule.locked == "r02-g19.locked")
        #expect(MicroscopicAuroraExperienceRule.date == "r02-g19.date")
        #expect(Core.practiceBudget == 24 && MicroscopicAuroraMode.practiceBudget == 24)
    }

    @Test func theProgressionControlsRefuseWhatTheyMust() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let locked: ActionResult = .rejected(.rule(code: "r02-g19.locked"))
        let date: ActionResult = .rejected(.rule(code: "r02-g19.date"))
        let notWhole: ActionResult = .rejected(.rule(code: "r02-g19.not-whole"))
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
        let leapLevel: Int = try #require(MicroscopicAuroraProgress.dailyLevel(year: 2028, month: 2, day: 29))
        #expect(leap.mode == .daily(level: leapLevel) && leap.levelNumber == leapLevel)
        #expect(!leap.play.canUndo && leap.play.stage == .playing && leap.progress == core.progress)
        // Selecting the open level 1 reopens it fresh in campaign mode, dropping the records.
        var selected: Core = core
        #expect(selected.apply(Self.detour) == .accepted && selected.play.canUndo)
        #expect(selected.apply(Self.act("clock.show", [3])) == .accepted)
        #expect(selected.apply(Self.act("level.select", [1])) == .accepted)
        #expect(selected == core && selected.shownTick == 0 && !selected.play.canUndo)
    }

    @Test func campaignWinsRecordStarsAndOpenTheNextLevel() async throws {
        let actions: [MicroscopicAuroraAction] = try Self.plan(1)
        let certified: Int = actions.count
        let well = MicroscopicAuroraWell(cell: MicroscopicAuroraCell(row: 11, column: 18), strength: 2,
                                         sense: .clockwise)
        #expect(certified == 1 && actions == [.place(slot: 0, well: well)])
        // The plan alone, then the play: 3 stars, level 2 opened.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.certifiedPlacements == certified && core.mode == .campaign && core.progress.frontier == 1)
        let firstWells: [MicroscopicAuroraWell] = try Core.generated(number: 1).plan.wells
        #expect(core.certifiedWells == firstWells && core.band == 1)
        for step in actions { #expect(core.apply(Self.act(step)) == .accepted) }
        // The placements alone record nothing: only the winning play does.
        #expect(core.progress.solved.isEmpty && core.progress.frontier == 1)
        #expect(core.apply(Self.act("swim.play")) == .accepted)
        #expect(core.play.stage == .won && MicroscopicAuroraProgress.actionsSpent(core.play) == certified)
        let best = MicroscopicAuroraProgress.Result(actionsSpent: certified, stars: 3)
        #expect(core.progress.solved[1] == best && core.progress.stars(of: 1) == 3)
        #expect(core.progress.frontier == 2 && core.progress.isOpen(2) && !core.progress.isOpen(3))
        // level.next goes to the newly opened level 2, fresh, with its tutorial and certified wells.
        var next: Core = core
        #expect(next.apply(Self.act("level.next")) == .accepted)
        #expect(next.levelNumber == 2 && !next.play.canUndo && next.mode == .campaign && next.shownTick == 0)
        let secondWells: [MicroscopicAuroraWell] = try Core.generated(number: 2).plan.wells
        #expect(next.tutorial == .place && next.certifiedWells == secondWells)
        // level.next from the frontier is refused: no next open level, nothing changes.
        let frontier: Core = next
        #expect(next.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g19.locked")))
        #expect(next == frontier && next.levelNumber == 2)
        // The frontier: level 2 can be chosen, level 3 cannot.
        #expect(core.apply(Self.act("level.select", [3])) == .rejected(.rule(code: "r02-g19.locked")))
        #expect(core.apply(Self.act("level.select", [2])) == .accepted)
        #expect(core.levelNumber == 2 && core.play.stage == .playing && core.tutorial == .place)
        // A failed play records nothing.
        var failed: Core = try Core.opening(number: 1)
        #expect(failed.apply(Self.act("swim.play")) == .accepted && failed.play.stage == .failed)
        #expect(failed.progress.solved.isEmpty && failed.progress.frontier == 1)
    }

    @Test func detoursGiveTwoOrOneStarsAndTheBestResultIsKept() async throws {
        let actions: [MicroscopicAuroraAction] = try Self.plan(1)
        let certified: Int = actions.count
        // One undone placement more than the plan: 2 stars.
        var undone: Core = try await Core.prepare(seed: 0)
        #expect(undone.apply(Self.detour) == .accepted)
        #expect(undone.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.win(&undone))
        #expect(MicroscopicAuroraProgress.actionsSpent(undone.play) == certified + 1)
        let twoStars = MicroscopicAuroraProgress.Result(actionsSpent: certified + 1, stars: 2)
        #expect(undone.progress.solved[1] == twoStars && undone.progress.frontier == 2)
        // A placement and its removal: two actions more than the plan, still 2 stars.
        var removed: Core = try await Core.prepare(seed: 0)
        #expect(removed.apply(Self.detour) == .accepted)
        #expect(removed.apply(Self.act("well.remove", [1])) == .accepted)
        #expect(try Self.win(&removed))
        #expect(MicroscopicAuroraProgress.actionsSpent(removed.play) == certified + 2)
        let removedResult = MicroscopicAuroraProgress.Result(actionsSpent: certified + 2, stars: 2)
        #expect(removed.progress.solved[1] == removedResult)
        // Four undone placements more than the plan: 1 star.
        var many: Core = try await Core.prepare(seed: 0)
        for _ in 0..<4 {
            #expect(many.apply(Self.detour) == .accepted)
            #expect(many.apply(Self.act("play.undo")) == .accepted)
        }
        #expect(try Self.win(&many))
        #expect(MicroscopicAuroraProgress.actionsSpent(many.play) == certified + 4)
        let oneStar = MicroscopicAuroraProgress.Result(actionsSpent: certified + 4, stars: 1)
        #expect(many.progress.solved[1] == oneStar)
        // A better result replaces the stored one; a worse one keeps it.
        #expect(many.apply(Self.act("level.select", [1])) == .accepted)
        #expect(try Self.win(&many))
        let best = MicroscopicAuroraProgress.Result(actionsSpent: certified, stars: 3)
        #expect(many.progress.solved[1] == best)
        #expect(many.apply(Self.act("level.select", [1])) == .accepted)
        #expect(many.apply(Self.detour) == .accepted)
        #expect(many.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.win(&many))
        #expect(many.progress.solved[1] == best && many.progress.frontier == 2)
        // A won play is final: it cannot be undone or played again, so it is recorded once.
        let recorded: MicroscopicAuroraProgress = many.progress
        #expect(many.apply(Self.act("play.undo")) == .rejected(.rule(code: "r02-g19.stage")))
        #expect(many.apply(Self.act("swim.play")) == .rejected(.rule(code: "r02-g19.stage")))
        #expect(many.progress == recorded)
        // The winning placement redone without the play is no win.
        var plain: Core = try Core.opening(number: 1)
        for step in actions { #expect(plain.apply(Self.act(step)) == .accepted) }
        #expect(plain.apply(Self.act("play.undo")) == .accepted)
        #expect(plain.apply(Self.act("play.redo")) == .accepted && plain.play.stage == .playing)
        #expect(plain.play.report.wins && plain.progress.solved.isEmpty)
    }

    @Test func practiceAndDailyFollowTheirRules() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let certified: MicroscopicAuroraLevel = try Core.level(number: 1)
        // Practice: a copy of the level with the budget raised to 24; a win records nothing and opens nothing.
        #expect(core.apply(Self.act("clock.show", [5])) == .accepted)
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == 1 && !core.play.canUndo && core.shownTick == 0)
        #expect(core.play.level.budget == 24 && core.play.actionsLeft == 24 && core.tutorial == .place)
        #expect(certified.budget != 24)
        #expect(core.play.level.id == certified.id && core.play.level.seed == certified.seed)
        #expect(core.play.level.stencil == certified.stencil && core.play.level.sites == certified.sites)
        #expect(core.play.level.wells == certified.wells && core.play.level.swimmers == certified.swimmers)
        #expect(core.play.level.tutorial == certified.tutorial && core.play.level.length == certified.length)
        #expect(try Core.practiceLevel(of: certified) == core.play.level)
        let before: MicroscopicAuroraProgress = core.progress
        #expect(try Self.win(&core))
        #expect(core.progress == before && core.progress.solved.isEmpty && core.progress.frontier == 1)
        // Campaign returns to the current level when it is open, fresh, with the certified budget.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && !core.play.canUndo)
        #expect(core.play.level == certified && core.play.actionsLeft == certified.budget)
        // Daily: the date's level, playable while still locked; level.next from it is refused; a win records the
        // level's best result and stars and opens nothing.
        let (dailyDate, daily): ([Double], Int) = try Self.plainDaily()
        #expect(daily == 52 && !core.progress.isOpen(daily))
        #expect(core.apply(Self.act("mode.daily", dailyDate)) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily && core.tutorial == .done)
        let dailyCertified: MicroscopicAuroraLevel = try Core.level(number: daily)
        #expect(core.play.level == dailyCertified && !core.progress.isOpen(daily))
        #expect(core.band == MicroscopicAuroraProgress.band(of: daily) && core.band == 3)
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g19.locked")))
        let dailyActions: [MicroscopicAuroraAction] = try Self.plan(daily)
        #expect(core.certifiedPlacements == dailyActions.count)
        #expect(try Self.win(&core))
        #expect(core.progress.frontier == 1 && !core.progress.isOpen(daily))
        let result: MicroscopicAuroraProgress.Result = try #require(core.progress.solved[daily])
        #expect(result == MicroscopicAuroraProgress.Result(actionsSpent: dailyActions.count, stars: 3))
        // Campaign from a level that is not open goes to the frontier.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.play.level == certified)
        // A daily tutorial level carries the tutorial: 2026-01-01 is level 1.
        #expect(MicroscopicAuroraProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 1])) == .accepted)
        #expect(core.mode == .daily(level: 1) && core.levelNumber == 1 && core.tutorial == .place)
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
        #expect(shown.apply(Self.act("clock.show", [9])) == .accepted)
        #expect(shown == campaign && shown.shownTick == 9)
        #expect(try Self.digest(shown) == campaignDigest)
        var dismissed: Core = campaign
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed != campaign)
        #expect(try Self.digest(dismissed) == campaignDigest)
    }

    @Test func theTutorialAdvancesOnPlacementsAndNeverBack() async throws {
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
        // Showing a tick is no placement: place stays.
        var shown: Core = core
        #expect(shown.apply(Self.act("clock.show", [3])) == .accepted && shown.tutorial == .place)
        // A refused placement moves nothing: a cell that is not a site.
        #expect(shown.apply(Self.act("well.place", [0, 0, 0, 1, 0])) == .rejected(.rule(code: "r02-g19.action")))
        #expect(shown.tutorial == .place)
        // A placement: place → cover; an undo does not move it back, nor a redo forward.
        #expect(core.apply(Self.detour) == .accepted)
        #expect(core.play.stage == .playing && core.tutorial == .cover)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .cover)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .cover)
        // A removal is a second action: cover → recover; recover lasts through undo and redo.
        #expect(core.apply(Self.act("well.remove", [1])) == .accepted)
        #expect(core.play.stage == .playing && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .recover)
        #expect(core.apply(Self.act("well.remove", [1])) == .accepted && core.tutorial == .recover)
        // The end of the level ends it: the certified placement and the winning play.
        #expect(try Self.win(&core))
        #expect(core.tutorial == .done)
        // A play moves any step straight to done: the failing play from a fresh opening goes place → done; the undo
        // that retries does not bring it back; a redo that restores the failed play ends a step restored as place.
        var broken: Core = try Core.opening(number: 1)
        #expect(broken.apply(Self.act("swim.play")) == .accepted)
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
            let expected: MicroscopicAuroraTutorialStep = number <= 3 ? .place : .done
            #expect(opening.tutorial == expected && MicroscopicAuroraTutorialStep.initial(level: number) == expected)
            #expect(opening.play.level.tutorial == (number <= 3))
        }
        var plain: Core = try Core.opening(number: 4)
        let plainFirst: MicroscopicAuroraAction = try #require(try Self.plan(4).first)
        #expect(plain.apply(Self.act(plainFirst)) == .accepted && plain.tutorial == .done)
        // The step is saved and restored.
        var saved: Core = try await Core.prepare(seed: 0)
        #expect(saved.apply(Self.detour) == .accepted)
        let payload: Data = try saved.snapshotPayload()
        #expect(String(decoding: payload, as: UTF8.self).hasSuffix(",\"tutorial\":\"cover\"}"))
        let restored: Core = try Core.restore(payload: payload, seed: 0)
        #expect(restored == saved && restored.tutorial == .cover)
    }

    @Test func theSchemaTwoPayloadRoundTripsInEveryModeAndRefusesDamage() async throws {
        // Campaign with progress: level 1 won, level 2 reached with level.next.
        var campaign: Core = try await Core.prepare(seed: 0)
        #expect(try Self.win(&campaign))
        #expect(campaign.apply(Self.act("level.next")) == .accepted)
        #expect(campaign.levelNumber == 2 && campaign.tutorial == .place)
        // Practice: a placement on the practice copy.
        var practice: Core = try await Core.prepare(seed: 0)
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(practice.apply(Self.detour) == .accepted)
        // Daily: the first certified placement of the date's level.
        let (dailyDate, dailyLevel): ([Double], Int) = try Self.plainDaily()
        var daily: Core = try await Core.prepare(seed: 0)
        #expect(daily.apply(Self.act("mode.daily", dailyDate)) == .accepted)
        let dailyFirst: MicroscopicAuroraAction = try #require(try Self.plan(dailyLevel).first)
        #expect(daily.apply(Self.act(dailyFirst)) == .accepted)
        let cores: [Core] = [campaign, practice, daily]
        for core in cores {
            let payload: Data = try core.snapshotPayload()
            #expect(try core.snapshotPayload() == payload)
            let restored: Core = try Core.restore(payload: payload, seed: 0)
            let restoredDigest: StateDigest = try Self.digest(restored)
            let savedDigest: StateDigest = try Self.digest(core)
            #expect(restored == core && restoredDigest == savedDigest, "\(core.mode)")
            #expect(restored.certifiedWells == core.certifiedWells && restored.openingNumber == 1)
            #expect(restored.shownTick == 0)
            // Reset returns to the opening state: level 1, campaign, nothing won, the tutorial's first step.
            var reset: Core = restored
            reset.reset()
            #expect(reset == (try Core.opening(number: 1)))
            #expect(reset.mode == .campaign && reset.progress == MicroscopicAuroraProgress() && reset.shownTick == 0)
            #expect(try Self.digest(reset) == Self.digest(try Core.opening(number: 1)))
        }
        let restoredPractice: Core = try Core.restore(payload: try practice.snapshotPayload(), seed: 0)
        #expect(restoredPractice.play.level.budget == 24 && restoredPractice.mode == .practice)
        let campaignText: String = String(decoding: try campaign.snapshotPayload(), as: UTF8.self)
        let certified: Int = try Self.plan(1).count
        let progressText: String = "\"progress\":{\"frontier\":2,"
            + "\"solved\":[{\"actionsSpent\":\(certified),\"level\":1,\"stars\":3}]}"
        #expect(campaignText.contains(progressText))
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
            #expect(throws: MicroscopicAuroraRestoreRefusal.damaged) { try Core.restore(payload: payload, seed: 0) }
        }
        // A schema-1 object is no schema-2 payload (the engine migrates it first).
        #expect(throws: MicroscopicAuroraRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":2,\"records\":[]}".utf8), seed: 0)
        }
        // A payload without the tutorial key starts the tutorial at the level's first step.
        let noStep: Data = Data(campaignText.replacingOccurrences(of: ",\"tutorial\":\"place\"", with: "").utf8)
        #expect(noStep != campaignPayload)
        let restoredNoStep: Core = try Core.restore(payload: noStep, seed: 0)
        #expect(restoredNoStep == campaign)
    }

    @Test func aSchemaOnePayloadMigratesAndANewerSchemaIsRefused() async throws {
        // Level 3 after its first certified placement: the tutorial has advanced, which schema 1 did not save.
        var core: Core = try await Core.prepare(seed: 2)
        #expect(core.levelNumber == 3)
        let plan: [MicroscopicAuroraAction] = try Self.plan(3)
        try #require(!plan.isEmpty)
        #expect(core.apply(Self.act(plan[0])) == .accepted)
        #expect(core.tutorial == .cover)
        let schemaOne: [String: Any] = try Self.schemaOne(core)
        let migrated: [String: Any] = try Core.migratedToSchemaTwo(schemaOne)
        let chained: [String: Any] = try Core.migrations.migrate(schemaOne, from: 1)
        let data: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
        let chainedData: Data = try JSONSerialization.data(withJSONObject: chained, options: [.sortedKeys])
        #expect(data == chainedData)
        let restored: Core = try Core.restore(payload: data, seed: 2)
        #expect(restored.levelNumber == 3 && restored.play == core.play && restored.mode == .campaign)
        #expect(restored.progress.frontier == 3 && restored.progress.solved.isEmpty)
        #expect(restored.progress.isOpen(1) && restored.progress.isOpen(3) && !restored.progress.isOpen(4))
        #expect(restored.tutorial == .place && restored.tutorial == MicroscopicAuroraTutorialStep.initial(level: 3))
        // The tutorial step is not digested, so the migrated state digests as the saved one.
        #expect(try Self.digest(restored) == Self.digest(core))
        // A level without the tutorial migrates with it done: the fresh opening of level 7.
        let sevenOpening: Core = try Core.opening(number: 7)
        let seven: [String: Any] = try Core.migratedToSchemaTwo(try Self.schemaOne(sevenOpening))
        let sevenData: Data = try JSONSerialization.data(withJSONObject: seven, options: [.sortedKeys])
        let sevenCore: Core = try Core.restore(payload: sevenData, seed: 6)
        #expect(sevenCore == sevenOpening && sevenCore.tutorial == .done && sevenCore.progress.frontier == 7)
        // A schema-1 object that is not one is refused.
        #expect(throws: MicroscopicAuroraRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": "3"]) }
        #expect(throws: MicroscopicAuroraRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": 3]) }
        // A newer schema is refused by the chain.
        #expect(throws: MigrationError.newerVersion(3)) { try Core.migrations.migrate(schemaOne, from: 3) }
    }

    @Test func theEngineMigratesASchemaOneEnvelopeAndRefusesANewerOne() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 2)
        try engine.activate()
        // Level 3: its first certified placement.
        let first: MicroscopicAuroraAction = try #require(try Self.plan(3).first)
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
        #expect(migrated.tutorial == .place && played.tutorial == .cover)
        #expect(try engine.digest() == saved.digest)
        // An envelope of schema 3 is refused and changes nothing.
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
        #expect(core.levelNumber == 4 && core.tutorial == .done)
        // A saved progress with every level open makes every level selectable; level.next never wraps past 100.
        var progress: MicroscopicAuroraProgress = MicroscopicAuroraProgress()
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
        let refused: ActionResult = .rejected(.rule(code: "r02-g19.locked"))
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
