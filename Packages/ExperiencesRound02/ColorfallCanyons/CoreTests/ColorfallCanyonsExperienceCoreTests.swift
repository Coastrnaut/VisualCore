// ColorfallCanyonsExperienceCoreTests — feature 343 (R02-G05-03) T-R02G0503-005 (FR-R02G0503-003, 005; SC-R02G0503-002,
// 004; clarifications Q4, Q5). The adapter core: the shared conformance checks pass; the seed picks level
// `seed % 100 + 1` deterministically in stage `playing` (seeds 0, 1, 99 and 100 give levels 1, 2, 100 and 1); every
// control is accepted when legal and refused with the state unchanged otherwise (the engine's range checks,
// `r02-g05.not-whole`, the kernel's `r02-g05.action`, `r02-g05.budget` and `r02-g05.stage`); undo restores the earlier
// digest exactly and redo the later one; the certified solution wins and the unedited level fails, and undo returns a
// failed play to playing; `level.next` wraps 100 to 1 and reset returns; the snapshot round trip and refused payloads
// (damaged, level out of range, a stale trace, an edited record, a record of a newer schema, an envelope of a newer
// schema); the quality tier and the presenter's snapshot time never touch the digest. Levels of bands 1 and 2 (1 … 40)
// keep the run short; only the preparation check generates level 100. Explicit types, plain loops, short runs.
// Feature 345 (R02-G05-05) T-R02G0505-004: the new controls (level.select, mode.daily, mode.practice, mode.campaign,
// tutorial.dismiss) and their refusals (`r02-g05.locked`, `r02-g05.date`); practice plays with budget 30 and never
// records; a daily win records without opening and a locked daily level is playable; `level.next` moves to the next
// open level and is refused when there is none (no wrap); a win records the actions spent and stars; the digest holds
// progress and mode but never the tutorial step; undo restores the digest with the tutorial left advanced; a schema-1
// payload migrates; schema 2 round trips (practice and daily too) and invalid progress or mode is refused; and
// SC-R02G0505-001: on levels 1 … 3 a scripted player following each instruction and the exact hints wins, seeing steer,
// run, fill (or done when one step ends the level), done in order.
// Feature 347 (R02-G05-07) T-R02G0507-003: schema 3 and digest v3 with the replay and sound controls; migrations 1 → 3
// and 2 → 3 keep the progress, unverified and without traces, with the sound off; a campaign or daily win records a
// verified trace equal to the play's net actions (an undone carve left out); restore of an honest save keeps every
// result, an edited one (stars, actions, a trace step) drops it and reports `reconciliationDropped` with the frontier
// kept; replay rules and codes (start, step through to won with the fingerprints of a fresh play, refusals, stop,
// progress unchanged, a replay saved mid-way round trips); `settings.sound` round-trips through the snapshot and never
// changes the digest.
import Foundation
import Testing
@testable import ColorfallCanyonsCore
import VisualCoreDiagnostics
import VisualCoreExperience

@Suite struct ColorfallCanyonsExperienceCoreTests {
    typealias Core = ColorfallCanyonsExperienceCore

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

    /// The first cell of `level` that can be carved at its starting heights.
    static func carvable(_ level: ColorfallCanyonsLevel) throws -> Int {
        try #require((0..<level.cellCount).first { level.isCarvable($0, heights: level.heights) })
    }

    /// Steps `core` 600 ticks at a time until its play is no longer in stage `playing` (at most 7 steps).
    static func runOut(_ core: inout Core) {
        var count: Int = 0
        while core.play.stage == .playing && count < 7 {
            #expect(core.apply(Self.act("time.step", [600])) == .accepted)
            count += 1
        }
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 2 (and 2 and 3 for the restore engine); a valve toggle, steps, undo and redo, then level.next.
        let actions: [ScriptedAction] = [ScriptedAction("canyon.valve", [0]),
                                         ScriptedAction("time.step", [30]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("canyon.valve", [0]),
                                         ScriptedAction("play.undo"), ScriptedAction("level.next"),
                                         ScriptedAction("time.step", [120]),
                                         ScriptedAction("canyon.valve", [0]),
                                         ScriptedAction("tutorial.dismiss"), ScriptedAction("mode.practice"),
                                         ScriptedAction("canyon.valve", [0]), ScriptedAction("mode.campaign"),
                                         ScriptedAction("mode.daily", [2026, 2, 4]),
                                         ScriptedAction("level.select", [1]),
                                         ScriptedAction("settings.sound", [1]),
                                         ScriptedAction("time.step", [60])]
        let rejected: [ScriptedAction] = [ScriptedAction("canyon.carve", [120]),
                                          ScriptedAction("canyon.carve", [-1]),
                                          ScriptedAction("canyon.carve", [0.5]),
                                          ScriptedAction("canyon.carve", [119]),
                                          ScriptedAction("canyon.carve", []),
                                          ScriptedAction("canyon.valve", [3]),
                                          ScriptedAction("canyon.valve", [2]),
                                          ScriptedAction("canyon.valve", [1.5]),
                                          ScriptedAction("time.step", [0]),
                                          ScriptedAction("time.step", [601]),
                                          ScriptedAction("time.step", [2.5]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus"),
                                          ScriptedAction("level.select", [101]),
                                          ScriptedAction("level.select", [0.5]),
                                          ScriptedAction("mode.daily", [2026, 2, 30]),
                                          ScriptedAction("mode.daily", [2026, 1]),
                                          ScriptedAction("mode.practice", [1]),
                                          ScriptedAction("mode.campaign", [1]),
                                          ScriptedAction("tutorial.dismiss", [1]),
                                          ScriptedAction("replay.start", [101]),
                                          ScriptedAction("replay.step"), ScriptedAction("replay.stop"),
                                          ScriptedAction("settings.sound", [2]),
                                          ScriptedAction("settings.sound", [0.5])]
        let plan = ConformancePlan(seeds: [0, 1], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g05.colorfall-canyons" && Core.schemaVersion == 3)
        #expect(Core.digestDomain == "r02-g05.colorfall-canyons.v3")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        #expect(Core.actionIDs == ["canyon.carve", "canyon.valve", "time.step", "play.undo", "play.redo", "level.next",
                                   "level.select", "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss",
                                   "replay.start", "replay.step", "replay.stop", "settings.sound"])
        #expect(Core.controls[0].ranges == [0...119])
        #expect(Core.controls[1].ranges == [0...2])
        #expect(Core.controls[2].ranges == [1...600])
        #expect(Core.controls[6].ranges == [1...100])
        #expect(Core.controls[7].ranges == [1...9999, 1...12, 1...31])
        #expect(Core.controls[11].ranges == [1...100])
        #expect(Core.controls[14].ranges == [0...1])
        let plainIndices: [Int] = [3, 4, 5, 8, 9, 10, 12, 13]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.practiceBudget == 30 && ColorfallCanyonsExperienceRule.locked == "r02-g05.locked")
        #expect(ColorfallCanyonsExperienceRule.date == "r02-g05.date")
        #expect(ColorfallCanyonsExperienceRule.noReplay == "r02-g05.no-replay")
        #expect(ColorfallCanyonsExperienceRule.replayEnd == "r02-g05.replay-end")
        #expect(ColorfallCanyonsExperienceRule.replay == "r02-g05.replay")
        #expect(Core.qualityTiers == 3 && Core.migrations.currentVersion == 3)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == ColorfallCanyonsTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 4.0 / 16.0, 1.0 / 16.0] && iterations == [1, 2.0 / 3.0, 1.0 / 3.0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
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
            let expected: ColorfallCanyonsLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.fluid == ColorfallCanyonsFluid(level: expected))
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.play.spent == 0 && first.qualityTier == 0)
        }
        // Level 1 has a tutorial; the adapter dismisses it.
        #expect(try Core.level(number: 1).tutorial)
        // The cache hands back the generator's own level.
        let entry: ColorfallCanyonsManifestEntry = ColorfallCanyonsManifest.entries[1]
        let fresh: ColorfallCanyonsLevel = try ColorfallCanyonsGenerator.generate(entry).level
        #expect(try Core.level(number: 2) == fresh)
        #expect(throws: ColorfallCanyonsError.level("number")) { try Core.level(number: 0) }
        #expect(throws: ColorfallCanyonsError.level("number")) { try Core.level(number: 101) }
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let level: ColorfallCanyonsLevel = core.play.level
        #expect(level.cellCount < 120 && level.springs.count < 3)
        let opening: StateDigest = try Self.digest(core)
        let spring: Int = level.springs[0].cell
        let illegal: [ExperienceAction] = [Self.act("canyon.carve", [120]), Self.act("canyon.carve", [-1]),
                                           Self.act("canyon.carve", [0.5]), Self.act("canyon.carve", [.nan]),
                                           Self.act("canyon.carve", [Double(level.cellCount)]),
                                           Self.act("canyon.carve", [Double(spring)]),
                                           Self.act("canyon.carve", []), Self.act("canyon.carve", [1, 2]),
                                           Self.act("canyon.valve", [3]), Self.act("canyon.valve", [2]),
                                           Self.act("canyon.valve", [0.25]),
                                           Self.act("time.step", [0]), Self.act("time.step", [601]),
                                           Self.act("time.step", [1.5]), Self.act("time.step", [.infinity]),
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
        #expect(probe.apply(Self.act("canyon.carve", [120])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("canyon.valve", [3])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("time.step", [601])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("time.step", [0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("canyon.carve", [])) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(probe.apply(Self.act("level.next", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        let notWhole: ActionResult = .rejected(.rule(code: ColorfallCanyonsExperienceRule.notWhole))
        #expect(probe.apply(Self.act("canyon.carve", [0.5])) == notWhole)
        #expect(probe.apply(Self.act("canyon.valve", [0.25])) == notWhole)
        #expect(probe.apply(Self.act("time.step", [1.5])) == notWhole)
        #expect(notWhole == .rejected(.rule(code: "r02-g05.not-whole")))
        // The kernel's refusals pass through with their reason codes.
        let action: ActionResult = .rejected(.rule(code: "r02-g05.action"))
        #expect(probe.apply(Self.act("canyon.carve", [Double(level.cellCount)])) == action)
        #expect(probe.apply(Self.act("canyon.carve", [Double(spring)])) == action)
        #expect(probe.apply(Self.act("canyon.valve", [2])) == action)
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe.apply(Self.act("nope")) == .rejected(.unknownControl("nope")))
        #expect(probe == core)

        // A carve lowers the cell and spends one action; a valve toggles and spends one; a step runs ticks only.
        let cell: Int = try Self.carvable(level)
        #expect(core.apply(Self.act("canyon.carve", [Double(cell)])) == .accepted)
        #expect(core.play.fluid.heights[cell] == level.heights[cell] - 1 && core.play.spent == 1)
        #expect(try Self.digest(core) != opening)
        let open: Bool = core.play.fluid.valves[0]
        #expect(core.apply(Self.act("canyon.valve", [0])) == .accepted)
        #expect(core.play.fluid.valves[0] == !open && core.play.spent == 2)
        #expect(core.apply(Self.act("time.step", [5])) == .accepted)
        #expect(core.play.fluid.tick == 5 && core.play.spent == 2 && core.play.records.count == 3)
        // The budget: toggling the valve until nothing is left, then the kernel's `budget`.
        while core.play.remaining > 0 { #expect(core.apply(Self.act("canyon.valve", [0])) == .accepted) }
        let spent: Core = core
        #expect(core.apply(Self.act("canyon.valve", [0])) == .rejected(.rule(code: "r02-g05.budget")))
        #expect(core.apply(Self.act("canyon.carve", [Double(cell)])) == .rejected(.rule(code: "r02-g05.budget")))
        #expect(core == spent)
        #expect(core.apply(Self.act("time.step", [1])) == .accepted)
    }

    @Test func aBandTwoLevelTakesASecondValve() async throws {
        var core: Core = try Core.opening(number: 21)
        #expect(core.play.level.springs.count == 2)
        #expect(core.apply(Self.act("canyon.valve", [1])) == .accepted)
        #expect(core.play.spent == 1)
        #expect(core.apply(Self.act("canyon.valve", [2])) == .rejected(.rule(code: "r02-g05.action")))
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 12)
        let level: ColorfallCanyonsLevel = core.play.level
        let startDigest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("canyon.carve", [Double(try Self.carvable(level))])) == .accepted)
        #expect(core.apply(Self.act("time.step", [40])) == .accepted)
        let moved: Core = core
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.play.fluid == ColorfallCanyonsFluid(level: level) && core.play.spent == 0)
        #expect(try Self.digest(core) == startDigest)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(core.play.fluid == moved.play.fluid && core.play.records.count == 6)
        #expect(try Self.digest(core) == movedDigest)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g05.action")))
        // A new action clears the redo history.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("time.step", [3])) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g05.action")))
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == startDigest)
    }

    @Test func theSolutionWinsTheUneditedLevelFailsAndUndoReturnsToPlaying() async throws {
        let numbers: [Int] = [1, 24]
        for number in numbers {
            let generated: ColorfallCanyonsGenerated = try Core.generated(number: number)
            var core: Core = try Core.opening(number: number)
            // Unedited, the level fails; undo of the failing step returns to playing with the earlier digest.
            var failing: Core = core
            let before: StateDigest = try Self.digest(failing)
            Self.runOut(&failing)
            #expect(failing.play.stage == .failed && failing.outcome?.code == Core.failedCode, "level \(number)")
            #expect(failing.snapshot(time: 0).stage == .failed && failing.snapshot(time: 0).failure != nil)
            let failed: Core = failing
            let stageCode: ActionResult = .rejected(.rule(code: "r02-g05.stage"))
            #expect(failing.apply(Self.act("time.step", [1])) == stageCode)
            #expect(failing.apply(Self.act("canyon.valve", [0])) == stageCode)
            #expect(failing.apply(Self.act("play.redo")) == stageCode)
            #expect(failing == failed)
            while failing.play.canUndo { #expect(failing.apply(Self.act("play.undo")) == .accepted) }
            #expect(failing.play.stage == .playing && failing.outcome == nil)
            #expect(try Self.digest(failing) == before)
            // The certified solution, then time: won.
            for edit in generated.solution.edits {
                let control: String
                let value: Int
                switch edit {
                case .carve(let cell): (control, value) = ("canyon.carve", cell)
                case .valve(let spring): (control, value) = ("canyon.valve", spring)
                }
                #expect(core.apply(Self.act(control, [Double(value)])) == .accepted)
            }
            Self.runOut(&core)
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "level \(number)")
            #expect(core.play.fluid.tick == generated.solution.winTick)
            let won: Core = core
            #expect(core.apply(Self.act("play.undo")) == stageCode)
            #expect(core.apply(Self.act("time.step", [1])) == stageCode)
            #expect(core == won)
            #expect(core.apply(Self.act("level.next")) == .accepted)
            #expect(core.play.stage == .playing && core.levelNumber == number + 1 && core.outcome == nil)
            core.reset()
            #expect(core.levelNumber == number && core.play.records.isEmpty && core.play.stage == .playing)
        }
    }

    @Test func nextLevelMovesToTheNextOpenLevelAndResetReturnsToTheSeedsLevel() async throws {
        // Seed 38 opens levels 1 … 39: level.next from 39 is refused (40 is locked) and changes nothing.
        var core: Core = try await Core.prepare(seed: 38)
        #expect(core.levelNumber == 39 && core.progress.frontier == 39 && core.mode == .campaign)
        #expect(core.apply(Self.act("time.step", [3])) == .accepted)
        let before: Core = core
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: ColorfallCanyonsExperienceRule.locked)))
        #expect(core == before)
        // level.select picks an open level; level.next then moves on to the next open one.
        #expect(core.apply(Self.act("level.select", [38])) == .accepted)
        #expect(core.levelNumber == 38 && core.play.records.isEmpty && core.play.stage == .playing)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 39 && core.play.records.isEmpty && core.mode == .campaign)
        core.reset()
        let fresh: Core = try await Core.prepare(seed: 38)
        let resetDigest: StateDigest = try Self.digest(core)
        let freshDigest: StateDigest = try Self.digest(fresh)
        #expect(core == fresh && resetDigest == freshDigest)
        // No wrap: level 100 (all open) refuses level.next (level 100 is in the cache once the preparation check ran).
        var last: Core = try Core.opening(number: 100)
        #expect(last.progress.frontier == 100)
        #expect(last.apply(Self.act("level.next")) == .rejected(.rule(code: ColorfallCanyonsExperienceRule.locked)))
        #expect(last.levelNumber == 100)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        var core: Core = try await Core.prepare(seed: 31)
        let level: ColorfallCanyonsLevel = core.play.level
        #expect(core.apply(Self.act("canyon.carve", [Double(try Self.carvable(level))])) == .accepted)
        #expect(core.apply(Self.act("time.step", [25])) == .accepted)
        #expect(core.apply(Self.act("canyon.valve", [0])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let payload: Data = try core.snapshotPayload()
        #expect(try core.snapshotPayload() == payload)
        let text: String = try #require(String(data: payload, encoding: .utf8))
        #expect(text.hasPrefix("{\"level\":32,\"mode\":{\"mode\":\"campaign\"},"
                                   + "\"progress\":{\"frontier\":32,\"solved\":[]},\"records\":["))
        #expect(text.hasSuffix("],\"sound\":false,\"tutorial\":\"done\"}"))
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

        #expect(throws: ColorfallCanyonsRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 31)
        }
        #expect(throws: ColorfallCanyonsRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 31)
        }
        let campaign: String = "\"mode\":{\"mode\":\"campaign\"},\"progress\":{\"frontier\":1,\"solved\":[]}"
        #expect(throws: ColorfallCanyonsRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"32\",\(campaign),\"records\":[]}".utf8), seed: 31)
        }
        // A schema-1 payload (no mode, no progress) is not a schema-2 payload: the engine migrates it first.
        #expect(throws: ColorfallCanyonsRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":32,\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: ColorfallCanyonsRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\(campaign),\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: ColorfallCanyonsRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\(campaign),\"records\":[]}".utf8), seed: 31)
        }
        // Invalid progress or mode: a frontier of 0, stars of 4, an unknown mode, a daily mode naming another level.
        let invalid: [String] = [
            "{\"level\":1,\"mode\":{\"mode\":\"campaign\"},\"progress\":{\"frontier\":0,\"solved\":[]},\"records\":[]}",
            "{\"level\":1,\"mode\":{\"mode\":\"campaign\"},\"progress\":{\"frontier\":2,\"solved\":"
                + "[{\"bestActions\":1,\"level\":1,\"stars\":4}]},\"records\":[]}",
            "{\"level\":1,\"mode\":{\"mode\":\"endless\"},\"progress\":{\"frontier\":1,\"solved\":[]},\"records\":[]}",
            "{\"level\":1,\"mode\":{\"level\":3,\"mode\":\"daily\"},\"progress\":{\"frontier\":1,\"solved\":[]},"
                + "\"records\":[]}",
            "{\"level\":1,\"mode\":{\"mode\":\"campaign\"},\"progress\":{\"frontier\":1,\"solved\":[]},\"records\":[],"
                + "\"tutorial\":\"later\"}",
        ]
        for text in invalid {
            #expect(throws: ColorfallCanyonsRestoreRefusal.damaged) {
                try Core.restore(payload: Data(text.utf8), seed: 0)
            }
        }
        // The same records on another level: the first record's previous fingerprint is stale there.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":1").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: ColorfallCanyonsRestoreRefusal.kernel(.stale)) {
            try Core.restore(payload: wrongLevel, seed: 31)
        }
        // A record of a newer schema: the replayed record (schema 1) differs from the stored one.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: ColorfallCanyonsRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: newer, seed: 31)
        }
        // An edited tick: the replayed record differs from the stored one.
        let edited: Data = Data(text.replacingOccurrences(of: "\"tick\":0", with: "\"tick\":7").utf8)
        #expect(edited != payload)
        #expect(throws: ColorfallCanyonsRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: edited, seed: 31)
        }
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 5)
        try engine.activate()
        #expect(engine.handle(control: "time.step", values: [4]) == .accepted)
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

    @Test func theTierAndTheSnapshotTimeNeverTouchTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: 4)
        #expect(core.apply(Self.act("time.step", [11])) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let subdivisions: [Int] = [4, 4, 2, 1, 1]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.subdivision == subdivisions[index])
            #expect(core.renderTier == ColorfallCanyonsTier.of(clamped[index]))
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: ColorfallCanyonsSceneSnapshot = core.snapshot(time: time)
            #expect(snapshot.heights == core.play.fluid.heights && snapshot.stage == core.play.stage)
            #expect(snapshot.levelNumber == core.levelNumber && snapshot.time.isFinite && snapshot.tick == 11)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }

    // MARK: Feature 345

    /// The adapter action of a kernel action.
    static func action(_ kernel: ColorfallCanyonsAction) -> ExperienceAction {
        switch kernel {
        case .carve(let cell): act("canyon.carve", [Double(cell)])
        case .valve(let spring): act("canyon.valve", [Double(spring)])
        case .step(let ticks): act("time.step", [Double(ticks)])
        }
    }

    /// Plays the certified witness actions of manifest number `number` on `core`; every one is accepted and wins.
    static func win(_ core: inout Core, number: Int) throws {
        let generated: ColorfallCanyonsGenerated = try Core.generated(number: number)
        let actions: [ColorfallCanyonsAction] = ColorfallCanyonsWitness.actions(for: generated.solution,
                                                                                level: generated.level)
        for kernel in actions { #expect(core.apply(Self.action(kernel)) == .accepted) }
        #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
    }

    /// The adapter action of a hint's edit (a carve or a valve); nil for `run` and `stuck`.
    static func action(of hint: ColorfallCanyonsHint) -> ExperienceAction? {
        switch hint.kind {
        case .carve: hint.cell.map { act("canyon.carve", [Double($0)]) }
        case .valve: hint.spring.map { act("canyon.valve", [Double($0)]) }
        case .run, .stuck: nil
        }
    }

    @Test func selectAndModesFollowTheProgress() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.mode == .campaign && core.progress.frontier == 1 && core.progress.solved.isEmpty)
        let opening: Core = core
        let openingDigest: StateDigest = try Self.digest(core)
        let locked: ActionResult = .rejected(.rule(code: ColorfallCanyonsExperienceRule.locked))
        let date: ActionResult = .rejected(.rule(code: ColorfallCanyonsExperienceRule.date))
        let notWhole: ActionResult = .rejected(.rule(code: ColorfallCanyonsExperienceRule.notWhole))
        #expect(core.apply(Self.act("level.select", [2])) == locked)
        #expect(core.apply(Self.act("level.next")) == locked)
        #expect(core.apply(Self.act("mode.daily", [2026, 2, 30])) == date)
        #expect(core.apply(Self.act("mode.daily", [2025, 2, 29])) == date)
        #expect(core.apply(Self.act("mode.daily", [2026, 4, 31])) == date)
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 1.5])) == notWhole)
        #expect(core.apply(Self.act("level.select", [1.5])) == notWhole)
        #expect(core.apply(Self.act("level.select", [101])) == .rejected(.outOfRange(index: 0)))
        #expect(core.apply(Self.act("mode.daily", [2026, 13, 1])) == .rejected(.outOfRange(index: 1)))
        #expect(core.apply(Self.act("mode.daily", [2026, 1])) == .rejected(.wrongValueCount(expected: 3, found: 2)))
        #expect(core.apply(Self.act("mode.practice", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(core.apply(Self.act("mode.campaign", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(core.apply(Self.act("tutorial.dismiss", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(try Self.digest(core) == openingDigest && core == opening)
        // The certified actions of level 1 win: the actions spent and the stars are recorded and level 2 opens.
        try Self.win(&core, number: 1)
        let smallest: Int = try Core.generated(number: 1).solution.smallest
        let result: ColorfallCanyonsProgress.Result = try #require(core.progress.solved[1])
        #expect(result.bestActions == core.play.spent && core.certifiedSmallest == smallest)
        #expect(result.stars == ColorfallCanyonsProgress.stars(actions: core.play.spent, smallest: smallest))
        #expect(result.stars == 3 && core.progress.frontier == 2 && core.tutorial == .done)
        #expect(try Self.digest(core) != openingDigest)
        #expect(core.apply(Self.act("level.select", [3])) == locked)
        #expect(core.apply(Self.act("level.select", [2])) == .accepted)
        #expect(core.levelNumber == 2 && core.mode == .campaign && core.play.records.isEmpty)
        let levelTwo: ColorfallCanyonsLevel = try Core.level(number: 2)
        #expect(core.tutorial == .steer && core.play.level == levelTwo && core.play.stage == .playing)
        // Practice: the same level, fresh, with the budget raised to 30; the records of the level left are dropped; a
        // practice win records nothing and opens nothing; the tutorial shows on levels 1 … 3 in every mode.
        #expect(core.apply(Self.act("time.step", [5])) == .accepted)
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == 2 && core.play.records.isEmpty)
        #expect(core.play.level.budget == Core.practiceBudget && core.play.remaining == 30)
        #expect(core.play.level.heights == levelTwo.heights && core.play.level.basins == levelTwo.basins)
        #expect(core.play.level.springs == levelTwo.springs && core.play.level.tickLimit == levelTwo.tickLimit)
        #expect(core.tutorial == .steer)
        let before: ColorfallCanyonsProgress = core.progress
        try Self.win(&core, number: 2)
        #expect(core.progress == before && core.progress.solved[2] == nil && core.progress.frontier == 2)
        // Campaign: a fresh campaign play of the same level, with the certified budget.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 2 && core.play.records.isEmpty)
        #expect(core.play.level == levelTwo)
        // Daily: 2026-02-04 (day 34) gives level 3, locked in the campaign yet playable; a win records it without
        // opening it; the tutorial shows in daily mode too.
        let daily: Int = try #require(ColorfallCanyonsProgress.dailyLevel(year: 2026, month: 2, day: 4))
        #expect(daily == 3 && !core.progress.isOpen(daily))
        #expect(core.apply(Self.act("mode.daily", [2026, 2, 4])) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily && core.tutorial == .steer)
        #expect(core.play.level == (try Core.level(number: daily)))
        try Self.win(&core, number: daily)
        #expect(core.progress.solved[daily] != nil && core.progress.frontier == 2 && !core.progress.isOpen(daily))
        #expect(core.apply(Self.act("level.select", [Double(daily)])) == locked)
        // Back to campaign: the daily level is not open, so the frontier.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 2)
        // level.next from the frontier has no next open level.
        #expect(core.apply(Self.act("level.next")) == locked)
        // Reset returns to the opening state, progress included.
        core.reset()
        #expect(try Self.digest(core) == openingDigest && core == opening)
    }

    @Test func aWorseWinKeepsTheBetterResult() async throws {
        // Level 1 won with the certified edits, then again after a wasted valve toggle pair: the result stays.
        var core: Core = try await Core.prepare(seed: 0)
        try Self.win(&core, number: 1)
        let best: ColorfallCanyonsProgress.Result = try #require(core.progress.solved[1])
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        #expect(core.apply(Self.act("canyon.valve", [0])) == .accepted)
        #expect(core.apply(Self.act("canyon.valve", [0])) == .accepted)
        try Self.win(&core, number: 1)
        #expect(core.progress.solved[1] == best && core.play.spent == best.bestActions + 2)
    }

    @Test func theDigestHoldsProgressAndModeButNotTheTutorial() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        // The tutorial step is not digested, but it is part of equality.
        var dismissed: Core = core
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed.tutorial == .done && dismissed != core)
        #expect(try Self.digest(dismissed) == opening)
        // The mode is digested: practice of the same level differs (its play differs too, so compare campaign twice).
        var again: Core = core
        #expect(again.apply(Self.act("mode.campaign")) == .accepted)
        #expect(try Self.digest(again) == opening && again == core)
        var practice: Core = core
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(try Self.digest(practice) != opening)
        // The progress is digested: the same level and fresh play with level 2 open differs from the opening.
        try Self.win(&core, number: 1)
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        #expect(core.play == (try Core.opening(number: 1)).play && core.mode == .campaign)
        #expect(try Self.digest(core) != opening)
    }

    @Test func theTutorialAdvancesAndUndoRestoresTheDigestWithIt() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.tutorial == .steer && core.tutorial == ColorfallCanyonsTutorialStep.initial(level: 1))
        // Follow the exact hints until the plan is empty: the last edit moves the tutorial to `run`.
        var beforeLast: StateDigest = try Self.digest(core)
        var edits: Int = 0
        while core.tutorial == .steer && edits < 4 {
            let hint: ColorfallCanyonsHint = try #require(core.hint(level: 3))
            let edit: ExperienceAction = try #require(Self.action(of: hint))
            beforeLast = try Self.digest(core)
            #expect(core.apply(edit) == .accepted)
            edits += 1
        }
        let smallest: Int = try Core.generated(number: 1).solution.smallest
        #expect(core.tutorial == .run && edits == smallest)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        // The digest returns; the tutorial does not move back.
        #expect(try Self.digest(core) == beforeLast && core.tutorial == .run)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(core.tutorial == .run)
        #expect(core.apply(Self.act("time.step", [1])) == .accepted)
        #expect(core.tutorial == .fill)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.tutorial == .fill)
        // Dismissing ends it; the tutorial step is never digested.
        let digest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(try Self.digest(core) == digest && core.tutorial == .done)
        // Every opening starts the tutorial again on levels 1 … 3; level 4 has none.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        #expect(core.tutorial == .steer)
        let later: Core = try await Core.prepare(seed: 3)
        #expect(later.tutorial == .done)
        // An edit that leaves the plan non-empty keeps `steer`; a step on `steer` keeps it too.
        var steer: Core = try await Core.prepare(seed: 0)
        #expect(steer.apply(Self.act("time.step", [1])) == .accepted)
        #expect(steer.tutorial == .steer)
        // The end of the level ends the tutorial, a failure too.
        var failed: Core = try await Core.prepare(seed: 2)
        #expect(failed.tutorial == .steer)
        Self.runOut(&failed)
        #expect(failed.play.stage == .failed && failed.tutorial == .done)
    }

    @Test func aSchemaOnePayloadMigrates() async throws {
        let seeds: [UInt64] = [31, 0]
        for seed in seeds {
            var core: Core = try await Core.prepare(seed: seed)
            #expect(core.apply(Self.act("time.step", [9])) == .accepted)
            #expect(core.apply(Self.act("canyon.valve", [0])) == .accepted)
            let object: [String: Any] = try #require(
                try JSONSerialization.jsonObject(with: try core.snapshotPayload()) as? [String: Any])
            let schemaOne: [String: Any] = ["level": try #require(object["level"]),
                                            "records": try #require(object["records"])]
            let migrated: [String: Any] = try Core.migrations.migrate(schemaOne, from: 1)
            #expect(migrated["tutorial"] == nil && migrated["mode"] != nil && migrated["progress"] != nil)
            #expect(migrated["sound"] as? Bool == false)
            let payload: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
            let restored: Core = try Core.restore(payload: payload, seed: seed)
            let number: Int = Core.levelNumber(forSeed: seed)
            #expect(restored.levelNumber == number && restored.mode == .campaign)
            #expect(restored.progress.frontier == number && restored.progress.solved.isEmpty)
            #expect(restored.play == core.play)
            #expect(restored.tutorial == ColorfallCanyonsTutorialStep.initial(level: number))
            #expect(try Self.digest(restored) == Self.digest(core))
        }
        #expect(throws: ColorfallCanyonsRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": "x"]) }
        #expect(throws: ColorfallCanyonsRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": 3]) }
        // Through the engine: a schema-1 envelope restores into schema 3.
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 4)
        try engine.activate()
        #expect(engine.handle(control: "time.step", values: [6]) == .accepted)
        let saved: ExperienceSnapshot = try engine.snapshot()
        let object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: Data(saved.payload.utf8)) as? [String: Any])
        let schemaOne: Data = try JSONSerialization.data(
            withJSONObject: ["level": try #require(object["level"]), "records": try #require(object["records"])],
            options: [.sortedKeys])
        let old = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: saved.seed,
                                         stepIndex: saved.stepIndex, digest: saved.digest, payload: schemaOne)
        let before: StateDigest = try engine.digest()
        try engine.restore(old)
        #expect(try engine.digest() == before)
    }

    @Test func aSchemaTwoPayloadRoundTripsInEveryMode() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        try Self.win(&core, number: 1)
        let won: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(won == core && won.progress.solved[1] != nil && won.tutorial == .done)
        #expect(try Self.digest(won) == Self.digest(core))
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.apply(Self.act("canyon.valve", [0])) == .accepted)
        #expect(core.apply(Self.act("time.step", [7])) == .accepted)
        let practice: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(practice == core && practice.play.level.budget == Core.practiceBudget)
        #expect(try Self.digest(practice) == Self.digest(core))
        #expect(core.apply(Self.act("mode.daily", [2026, 2, 4])) == .accepted)
        #expect(core.apply(Self.act("time.step", [3])) == .accepted)
        #expect(core.apply(Self.act("tutorial.dismiss")) == .accepted)
        let daily: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(daily == core && daily.mode == .daily(level: 3) && daily.tutorial == .done)
        #expect(try Self.digest(daily) == Self.digest(core))
        // A practice trace restored as campaign: the budget differs, so the level fingerprint and every record do too.
        let text: String = try #require(String(data: try practice.snapshotPayload(), encoding: .utf8))
        let asCampaign: Data = Data(text.replacingOccurrences(of: "{\"mode\":\"practice\"}",
                                                              with: "{\"mode\":\"campaign\"}").utf8)
        var refused: Bool = false
        do { _ = try Core.restore(payload: asCampaign, seed: 0) } catch is ColorfallCanyonsRestoreRefusal {
            refused = true
        }
        #expect(refused)
    }

    @Test func theHintAndTheFailureExplanationReadThePlay() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let before: Core = core
        for hintLevel in 1...3 {
            let hint: ColorfallCanyonsHint = try #require(core.hint(level: hintLevel))
            #expect(hint == ColorfallCanyonsHints.hint(level: hintLevel, play: core.play))
        }
        #expect(core.failureExplanation == nil && core == before)
        Self.runOut(&core)
        #expect(core.play.stage == .failed && core.hint(level: 1)?.kind == .stuck)
        let explanation: ColorfallCanyonsFailureExplanation = try #require(core.failureExplanation)
        #expect(explanation == ColorfallCanyonsFailureExplanation(play: core.play))
        #expect(core.progress.solved.isEmpty && core.progress.frontier == 1)
        // Retry: a fresh campaign play of the same level.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.play == before.play && core.failureExplanation == nil)
    }

    /// SC-R02G0505-001: on levels 1 … 3 a scripted player following each instruction — the exact (level-3) hints while
    /// `steer`, one step of the hint's ticks while `run`, steps while `fill` — wins and sees steer, run, fill (or done
    /// when one step ends the level), done in order.
    @Test func aScriptedPlayerFollowingTheTutorialWinsLevelsOneToThree() async throws {
        for number in 1...3 {
            var core: Core = try Core.opening(number: number)
            var seen: [ColorfallCanyonsTutorialStep] = [core.tutorial]
            var moves: Int = 0
            while core.play.stage == .playing && moves < 12 {
                switch core.tutorial {
                case .steer:
                    let hint: ColorfallCanyonsHint = try #require(core.hint(level: 3), "level \(number)")
                    let edit: ExperienceAction = try #require(Self.action(of: hint), "level \(number): \(hint.text)")
                    #expect(hint.text.hasPrefix("Carve row ") || hint.text.hasSuffix(" valve"))
                    #expect(core.apply(edit) == .accepted)
                case .run:
                    let hint: ColorfallCanyonsHint = try #require(core.hint(level: 3), "level \(number)")
                    #expect(hint.kind == .run && hint.text == "Run: \(hint.ticks) ticks")
                    let ticks: Int = min(hint.ticks, ColorfallCanyonsPlay.steps.upperBound)
                    #expect(core.apply(Self.act("time.step", [Double(ticks)])) == .accepted)
                case .fill, .done:
                    #expect(core.apply(Self.act("time.step", [600])) == .accepted)
                }
                if seen.last != core.tutorial { seen.append(core.tutorial) }
                moves += 1
            }
            #expect(core.play.stage == .won, "level \(number)")
            let full: [ColorfallCanyonsTutorialStep] = [.steer, .run, .fill, .done]
            let short: [ColorfallCanyonsTutorialStep] = [.steer, .run, .done]
            #expect(seen == full || seen == short, "level \(number): \(seen)")
            #expect(core.progress.solved[number] != nil && core.progress.isOpen(number + 1))
        }
    }

    // MARK: Feature 347

    /// The snapshot payload of `core` as a JSON object.
    static func object(_ core: Core) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: try core.snapshotPayload()) as? [String: Any])
    }

    /// `object` as JSON data with sorted keys.
    static func data(_ object: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    /// `object` with the first solved result's field `key` set to `value` (nil removes it).
    static func editedFirstResult(_ object: [String: Any], _ key: String, _ value: Any?) throws -> [String: Any] {
        var edited: [String: Any] = object
        var progress: [String: Any] = try #require(object["progress"] as? [String: Any])
        var solved: [[String: Any]] = try #require(progress["solved"] as? [[String: Any]])
        solved[0][key] = value
        progress["solved"] = solved
        edited["progress"] = progress
        return edited
    }

    /// The refusal of rule `code`.
    static func rule(_ code: String) -> ActionResult { .rejected(.rule(code: code)) }

    @Test func aWinRecordsAVerifiedTraceOfTheNetActions() async throws {
        // Level 1's certified actions are carve 10, carve 10, step 120; a carve undone and redone stays, a valve
        // toggle undone and not redone is left out.
        var core: Core = try await Core.prepare(seed: 0)
        let script: [ExperienceAction] = [Self.act("canyon.carve", [10]), Self.act("play.undo"),
                                          Self.act("play.redo"), Self.act("canyon.valve", [0]),
                                          Self.act("play.undo"), Self.act("canyon.carve", [10]),
                                          Self.act("time.step", [120])]
        for action in script { #expect(core.apply(action) == .accepted, "\(action.control)") }
        #expect(core.play.stage == .won && core.play.records.count == 7)
        let result: ColorfallCanyonsProgress.Result = try #require(core.progress.solved[1])
        let expected: [ColorfallCanyonsAction] = [.carve(10), .carve(10), .step(120)]
        #expect(result.verified && result.trace == expected && result.bestActions == 2 && result.stars == 3)
        #expect(result.trace == ColorfallCanyonsReconciliation.netActions(core.play.records))
        #expect(ColorfallCanyonsReconciliation.verifies(level: 1, result: result))
        #expect(core.progress.frontier == 2)
        // Practice records nothing.
        var practice: Core = try await Core.prepare(seed: 0)
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        try Self.win(&practice, number: 1)
        #expect(practice.progress.solved.isEmpty && practice.progress.frontier == 1)
        // A daily win (2026-02-04 is level 3) records a verified trace and opens nothing.
        var daily: Core = try await Core.prepare(seed: 0)
        #expect(daily.apply(Self.act("mode.daily", [2026, 2, 4])) == .accepted)
        try Self.win(&daily, number: 3)
        let dailyResult: ColorfallCanyonsProgress.Result = try #require(daily.progress.solved[3])
        #expect(dailyResult.verified && dailyResult.trace == ColorfallCanyonsReconciliation.netActions(daily.play.records))
        #expect(daily.progress.frontier == 1)
    }

    @Test func restoreKeepsHonestResultsAndDropsEditedOnes() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        try Self.win(&core, number: 1)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        try Self.win(&core, number: 2)
        #expect(core.progress.frontier == 3 && core.progress.solved.count == 2)
        let honest: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(honest == core && honest.reconciliationDropped == 0)
        #expect(try Self.digest(honest) == Self.digest(core))
        let object: [String: Any] = try Self.object(core)
        let savedProgress: [String: Any] = try #require(object["progress"] as? [String: Any])
        let savedSolved: [[String: Any]] = try #require(savedProgress["solved"] as? [[String: Any]])
        let trace: [Any] = try #require(savedSolved[0]["trace"] as? [Any])
        // Edited stars, edited actions, a trace without its last step, a verified result without a trace.
        let edits: [[String: Any]] = [try Self.editedFirstResult(object, "stars", 2),
                                      try Self.editedFirstResult(object, "bestActions", 3),
                                      try Self.editedFirstResult(object, "trace", Array(trace.dropLast())),
                                      try Self.editedFirstResult(object, "trace", [Any]())]
        for edit in edits {
            let restored: Core = try Core.restore(payload: try Self.data(edit), seed: 0)
            #expect(restored.reconciliationDropped == 1 && restored.progress.solved[1] == nil)
            #expect(restored.progress.solved[2] == core.progress.solved[2] && restored.progress.frontier == 3)
            #expect(restored.play == core.play && restored != core)
            #expect(try Self.digest(restored) != Self.digest(core))
        }
        // An unverified result without a trace (an old save) is kept.
        let untraced: [String: Any] = try Self.editedFirstResult(
            try Self.editedFirstResult(object, "trace", [Any]()), "verified", false)
        let kept: Core = try Core.restore(payload: try Self.data(untraced), seed: 0)
        #expect(kept.reconciliationDropped == 0 && kept.progress.solved[1]?.verified == false)
        #expect(kept.progress.solved[1]?.stars == 3)
    }

    @Test func replayPlaysTheStoredTraceAndNeverChangesProgress() async throws {
        let noReplay: ActionResult = Self.rule(ColorfallCanyonsExperienceRule.noReplay)
        let replayEnd: ActionResult = Self.rule(ColorfallCanyonsExperienceRule.replayEnd)
        let inReplay: ActionResult = Self.rule(ColorfallCanyonsExperienceRule.replay)
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(Self.act("replay.start", [1])) == noReplay)
        #expect(core.apply(Self.act("replay.step")) == noReplay)
        #expect(core.apply(Self.act("replay.stop")) == noReplay)
        try Self.win(&core, number: 1)
        #expect(core.apply(Self.act("replay.start", [2])) == noReplay)
        #expect(core.apply(Self.act("replay.start", [1.5])) == Self.rule(ColorfallCanyonsExperienceRule.notWhole))
        #expect(core.apply(Self.act("replay.start", [101])) == .rejected(.outOfRange(index: 0)))
        let progress: ColorfallCanyonsProgress = core.progress
        let trace: [ColorfallCanyonsAction] = try #require(progress.solved[1]).trace
        #expect(core.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(core.mode == .replay(level: 1) && core.levelNumber == 1 && core.tutorial == .done)
        #expect(core.play.records.isEmpty && core.play.stage == .playing)
        let refused: [ExperienceAction] = [Self.act("canyon.carve", [10]), Self.act("canyon.valve", [0]),
                                           Self.act("time.step", [1]), Self.act("play.undo"), Self.act("play.redo"),
                                           Self.act("level.next"), Self.act("level.select", [1]),
                                           Self.act("mode.daily", [2026, 2, 4]), Self.act("mode.practice"),
                                           Self.act("mode.campaign")]
        for action in refused {
            let before: Core = core
            #expect(core.apply(action) == inReplay, "\(action.control)")
            #expect(core == before)
        }
        #expect(core.apply(Self.act("tutorial.dismiss")) == .accepted && core.tutorial == .done)
        var fresh: ColorfallCanyonsPlay = try Core.freshPlay(of: try Core.level(number: 1))
        for index in trace.indices {
            #expect(core.apply(Self.act("replay.step")) == .accepted)
            try fresh.apply(trace[index], expecting: fresh.fingerprint)
            #expect(core.play.fingerprint == fresh.fingerprint && core.progress == progress)
            if index == 0 {
                // A replay saved mid-way round trips.
                let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
                #expect(restored == core && restored.mode == .replay(level: 1))
                #expect(try Self.digest(restored) == Self.digest(core))
            }
        }
        #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode && core.progress == progress)
        #expect(core.apply(Self.act("replay.step")) == replayEnd)
        #expect(core.apply(Self.act("replay.stop")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.play.records.isEmpty)
        #expect(core.progress == progress && core.tutorial == .steer)
        // A daily win beyond the frontier replays; stopping returns to the frontier; an edited save drops the replay.
        #expect(core.apply(Self.act("mode.daily", [2026, 2, 4])) == .accepted)
        try Self.win(&core, number: 3)
        #expect(core.progress.frontier == 2 && core.progress.solved[3]?.verified == true)
        #expect(core.apply(Self.act("replay.start", [3])) == .accepted)
        #expect(core.apply(Self.act("replay.step")) == .accepted)
        var stopped: Core = core
        #expect(stopped.apply(Self.act("replay.stop")) == .accepted)
        #expect(stopped.mode == .campaign && stopped.levelNumber == 2)
        var object: [String: Any] = try Self.object(core)
        var saved: [String: Any] = try #require(object["progress"] as? [String: Any])
        var solved: [[String: Any]] = try #require(saved["solved"] as? [[String: Any]])
        #expect(solved.count == 2 && solved[1]["level"] as? Int == 3)
        solved[1]["bestActions"] = 9
        saved["solved"] = solved
        object["progress"] = saved
        let dropped: Core = try Core.restore(payload: try Self.data(object), seed: 0)
        #expect(dropped.reconciliationDropped == 1 && dropped.mode == .campaign && dropped.levelNumber == 2)
        #expect(dropped.progress.solved[3] == nil && dropped.progress.solved[1] != nil)
        // A replay mode naming another level is damaged.
        object = try Self.object(core)
        object["mode"] = ["mode": "replay", "level": 1]
        #expect(throws: ColorfallCanyonsRestoreRefusal.damaged) {
            try Core.restore(payload: try Self.data(object), seed: 0)
        }
    }

    @Test func aSchemaTwoPayloadMigratesUnverifiedWithTheSoundOff() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        try Self.win(&core, number: 1)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.apply(Self.act("time.step", [5])) == .accepted)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted)
        // The schema-2 form: results without `trace` and `verified`, no `sound`.
        var object: [String: Any] = try Self.editedFirstResult(
            try Self.editedFirstResult(try Self.object(core), "trace", nil), "verified", nil)
        object["sound"] = nil
        let migrated: [String: Any] = try Core.migrations.migrate(object, from: 2)
        #expect(migrated["sound"] as? Bool == false)
        let restored: Core = try Core.restore(payload: try Self.data(migrated), seed: 0)
        let result: ColorfallCanyonsProgress.Result = try #require(restored.progress.solved[1])
        let original: ColorfallCanyonsProgress.Result = try #require(core.progress.solved[1])
        #expect(result.bestActions == original.bestActions && result.stars == original.stars)
        #expect(result.trace.isEmpty && !result.verified)
        #expect(restored.progress.frontier == core.progress.frontier && restored.reconciliationDropped == 0)
        #expect(restored.play == core.play && restored.levelNumber == 2 && !restored.soundOn)
        var replay: Core = restored
        #expect(replay.apply(Self.act("replay.start", [1])) == Self.rule(ColorfallCanyonsExperienceRule.noReplay))
        #expect(throws: ColorfallCanyonsRestoreRefusal.damaged) { try Core.migratedToSchemaThree(["level": 1]) }
        // 1 → 3: a schema-1 object gains progress, mode and the sound off.
        let schemaOne: [String: Any] = ["level": 2, "records": [Any]()]
        let fromOne: [String: Any] = try Core.migrations.migrate(schemaOne, from: 1)
        #expect(fromOne["sound"] as? Bool == false && fromOne["progress"] != nil)
        let restoredOne: Core = try Core.restore(payload: try Self.data(fromOne), seed: 0)
        #expect(restoredOne.levelNumber == 2 && restoredOne.progress.frontier == 2 && !restoredOne.soundOn)
        // Through the engine: a schema-2 envelope restores into schema 3 with the same digest.
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 4)
        try engine.activate()
        #expect(engine.handle(control: "time.step", values: [6]) == .accepted)
        let saved: ExperienceSnapshot = try engine.snapshot()
        var savedObject: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: Data(saved.payload.utf8)) as? [String: Any])
        savedObject["sound"] = nil
        let old = try ExperienceSnapshot(experience: id, schemaVersion: 2, seed: saved.seed,
                                         stepIndex: saved.stepIndex, digest: saved.digest,
                                         payload: try Self.data(savedObject))
        let before: StateDigest = try engine.digest()
        try engine.restore(old)
        #expect(try engine.digest() == before)
    }

    @Test func theSoundChoiceRoundTripsAndIsNeverDigested() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(!core.soundOn)
        let off: Core = core
        let digest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted)
        #expect(core.soundOn && core != off)
        #expect(try Self.digest(core) == digest)
        let text: String = String(decoding: try core.snapshotPayload(), as: UTF8.self)
        #expect(text.contains("\"sound\":true"))
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && restored.soundOn)
        #expect(try Self.digest(restored) == digest)
        #expect(core.apply(Self.act("settings.sound", [2])) == .rejected(.outOfRange(index: 0)))
        #expect(core.apply(Self.act("settings.sound", [0.5])) == Self.rule(ColorfallCanyonsExperienceRule.notWhole))
        #expect(core.apply(Self.act("settings.sound")) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(core.soundOn)
        // A payload without "sound" restores with the sound off.
        var object: [String: Any] = try Self.object(core)
        object["sound"] = nil
        #expect(!(try Core.restore(payload: try Self.data(object), seed: 0)).soundOn)
        var reset: Core = core
        reset.reset()
        #expect(!reset.soundOn && reset == off)
        #expect(core.apply(Self.act("settings.sound", [0])) == .accepted)
        #expect(!core.soundOn && core == off)
        #expect(try Self.digest(core) == digest)
    }
}
