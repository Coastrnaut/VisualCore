// ChronoConstellatorExperienceCoreTests — feature 353 (R02-G06-03) T-R02G0603-005 (FR-R02G0603-005, 008, 009;
// SC-R02G0603-002, 004; clarifications Q4, Q5). The adapter core: the shared conformance checks pass; the seed picks
// level `seed % 100 + 1` deterministically in stage `playing` (seeds 0, 1, 99 and 100 give levels 1, 2, 100 and 1);
// every control is accepted when legal and refused with the state unchanged otherwise (the engine's range checks,
// `r02-g06.not-whole`, the kernel's `r02-g06.action`, `r02-g06.budget` and `r02-g06.stage`); undo restores the earlier
// digest exactly and redo the later one; the certified solution wins and the unedited level fails, undo returns a
// failed play to playing and a rewind retries it; `level.next` wraps 100 to 1 and reset returns; the snapshot round
// trip and refused payloads (damaged, level out of range, a stale trace, an edited record, a record of a newer schema,
// an envelope of a newer schema); the quality tier and the presenter's snapshot time never touch the digest. Levels of
// bands 1 and 2 (1 … 40) keep the run short; only the preparation and wrap checks generate level 100. Explicit types,
// plain loops.
import Foundation
import Testing
@testable import ChronoConstellatorCore
import VisualCoreDiagnostics
import VisualCoreExperience

@Suite struct ChronoConstellatorExperienceCoreTests {
    typealias Core = ChronoConstellatorExperienceCore

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

    /// A start phase of star `star` of `level` that differs from its default phase.
    static func otherPhase(_ star: Int, _ level: ChronoConstellatorLevel) -> Double {
        Double((level.stars[star].phase + 1) % level.stars[star].length)
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 2 (and 2 and 3 for the restore engine): a hold, steps, undo and redo, a rewind, a release, then
        // level.next.
        let actions: [ScriptedAction] = [ScriptedAction("star.hold", [0, 1, 2]),
                                         ScriptedAction("time.step", [30]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("time.rewind"),
                                         ScriptedAction("star.release", [0, 1]),
                                         ScriptedAction("play.undo"), ScriptedAction("level.next"),
                                         ScriptedAction("star.hold", [1, 3, 4]),
                                         ScriptedAction("time.step", [12])]
        let rejected: [ScriptedAction] = [ScriptedAction("star.phase", [5, 0]),
                                          ScriptedAction("star.phase", [0, 32]),
                                          ScriptedAction("star.phase", [0, 0.5]),
                                          ScriptedAction("star.phase", [4, 0]),
                                          ScriptedAction("star.phase", [0]),
                                          ScriptedAction("star.hold", [0, 0, 1]),
                                          ScriptedAction("star.hold", [0, 1, 61]),
                                          ScriptedAction("star.hold", [0, 1, 0]),
                                          ScriptedAction("star.hold", [0, 1_200, 60]),
                                          ScriptedAction("star.hold", [3, 1, 1]),
                                          ScriptedAction("star.release", [0, 1]),
                                          ScriptedAction("star.release", [0, 0]),
                                          ScriptedAction("time.step", [0]),
                                          ScriptedAction("time.step", [1_201]),
                                          ScriptedAction("time.step", [2.5]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 1], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g06.chrono-constellator" && Core.schemaVersion == 3)
        #expect(Core.digestDomain == "r02-g06.chrono-constellator.v3")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        #expect(Core.actionIDs == ["star.phase", "star.hold", "star.release", "time.step", "time.rewind", "play.undo",
                                   "play.redo", "level.next", "level.select", "mode.daily", "mode.practice",
                                   "mode.campaign", "tutorial.dismiss", "replay.start", "replay.step", "replay.stop",
                                   "settings.sound"])
        #expect(Core.controls[0].ranges == [0...4, 0...31])
        #expect(Core.controls[1].ranges == [0...4, 1...1_200, 1...60])
        #expect(Core.controls[2].ranges == [0...4, 1...1_200])
        #expect(Core.controls[3].ranges == [1...1_200])
        #expect(Core.controls[8].ranges == [1...100])
        #expect(Core.controls[9].ranges == [1...9_999, 1...12, 1...31])
        #expect(Core.controls[13].ranges == [1...100])
        #expect(Core.controls[16].ranges == [0...1])
        let plainIndices: [Int] = [4, 5, 6, 7, 10, 11, 12, 14, 15]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.migrations.currentVersion == 3)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == ChronoConstellatorTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 24.0 / 96.0, 6.0 / 96.0] && iterations == [1, 0.5, 0.25])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(ChronoConstellatorExperienceRule.notWhole == "r02-g06.not-whole")
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
            let expected: ChronoConstellatorLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.tick == 0)
            #expect(first.play.timeline == ChronoConstellatorTimeline(level: expected))
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.play.spent == 0 && first.qualityTier == 0)
        }
        // Level 1 has a tutorial; the adapter dismisses it.
        #expect(try Core.level(number: 1).tutorial)
        // The cache hands back the generator's own level.
        let entry: ChronoConstellatorManifestEntry = ChronoConstellatorManifest.entries[1]
        let fresh: ChronoConstellatorLevel = try ChronoConstellatorGenerator.generate(entry).level
        #expect(try Core.level(number: 2) == fresh)
        #expect(throws: ChronoConstellatorError.level("number")) { try Core.level(number: 0) }
        #expect(throws: ChronoConstellatorError.level("number")) { try Core.level(number: 101) }
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let level: ChronoConstellatorLevel = core.play.level
        #expect(level.stars.count < 5)
        let opening: StateDigest = try Self.digest(core)
        let own: Double = Double(level.stars[0].phase)
        let length: Double = Double(level.stars[0].length)
        let illegal: [ExperienceAction] = [Self.act("star.phase", [5, 0]), Self.act("star.phase", [-1, 0]),
                                           Self.act("star.phase", [0, 32]), Self.act("star.phase", [0.5, 0]),
                                           Self.act("star.phase", [0, .nan]), Self.act("star.phase", [0]),
                                           Self.act("star.phase", [4, 0]), Self.act("star.phase", [0, length]),
                                           Self.act("star.phase", [0, own]),
                                           Self.act("star.hold", [0, 0, 1]), Self.act("star.hold", [0, 1, 61]),
                                           Self.act("star.hold", [0, 1, 1.5]), Self.act("star.hold", [4, 1, 1]),
                                           Self.act("star.hold", [0, Double(level.tickLimit), 2]),
                                           Self.act("star.release", [0, 1]), Self.act("star.release", [0, 1_201]),
                                           Self.act("star.release", [0, 2.5]),
                                           Self.act("time.step", [0]), Self.act("time.step", [1_201]),
                                           Self.act("time.step", [1.5]), Self.act("time.step", [.infinity]),
                                           Self.act("time.rewind", [1]),
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
        #expect(probe.apply(Self.act("star.phase", [5, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("star.phase", [0, 32])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("star.hold", [0, 1, 61])) == .rejected(.outOfRange(index: 2)))
        #expect(probe.apply(Self.act("star.release", [0, 0])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("time.step", [1_201])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("time.step", [0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("star.phase", [0])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("level.next", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("time.rewind", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        let notWhole: ActionResult = .rejected(.rule(code: ChronoConstellatorExperienceRule.notWhole))
        #expect(probe.apply(Self.act("star.phase", [0.5, 0])) == notWhole)
        #expect(probe.apply(Self.act("star.hold", [0, 1, 1.5])) == notWhole)
        #expect(probe.apply(Self.act("star.release", [0, 2.5])) == notWhole)
        #expect(probe.apply(Self.act("time.step", [1.5])) == notWhole)
        // The kernel's refusals pass through with their reason codes.
        let action: ActionResult = .rejected(.rule(code: "r02-g06.action"))
        #expect(probe.apply(Self.act("star.phase", [4, 0])) == action)
        #expect(probe.apply(Self.act("star.phase", [0, length])) == action)
        #expect(probe.apply(Self.act("star.phase", [0, own])) == action)
        #expect(probe.apply(Self.act("star.hold", [4, 1, 1])) == action)
        #expect(probe.apply(Self.act("star.hold", [0, Double(level.tickLimit), 2])) == action)
        #expect(probe.apply(Self.act("star.release", [0, 1])) == action)
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe.apply(Self.act("nope")) == .rejected(.unknownControl("nope")))
        #expect(probe == core)

        // A phase change and a hold each spend one edit; an overlapping hold is refused; a release frees its edit.
        #expect(core.apply(Self.act("star.phase", [0, Self.otherPhase(0, level)])) == .accepted)
        #expect(core.play.timeline.phases[0] == Int(Self.otherPhase(0, level)) && core.play.spent == 1)
        #expect(try Self.digest(core) != opening)
        #expect(core.apply(Self.act("star.hold", [1, 1, 3])) == .accepted)
        #expect(core.play.timeline.holds == [ChronoConstellatorHold(star: 1, start: 1, length: 3)])
        #expect(core.play.spent == 2)
        #expect(core.apply(Self.act("star.hold", [1, 2, 1])) == action)
        #expect(core.apply(Self.act("star.release", [1, 1])) == .accepted)
        #expect(core.play.timeline.holds.isEmpty && core.play.spent == 1 && core.play.records.count == 3)
        // The budget: one-tick holds on star 1 two ticks apart until nothing is left, then the kernel's `budget`.
        var start: Int = 1
        while core.play.remaining > 0 {
            #expect(core.apply(Self.act("star.hold", [1, Double(start), 1])) == .accepted)
            start += 2
        }
        let spent: Core = core
        #expect(core.apply(Self.act("star.hold", [1, Double(start), 1])) == .rejected(.rule(code: "r02-g06.budget")))
        #expect(core.apply(Self.act("star.phase", [1, Self.otherPhase(1, level)]))
            == .rejected(.rule(code: "r02-g06.budget")))
        #expect(core == spent)
        // Edits only at tick 0: after a step, a phase change is the kernel's `action` (or `stage` once decided).
        #expect(core.apply(Self.act("time.step", [1])) == .accepted)
        #expect(core.play.tick == 1)
        let late: ActionResult = core.apply(Self.act("star.release", [1, 1]))
        let expected: ActionResult = core.play.stage == .playing ? action : .rejected(.rule(code: "r02-g06.stage"))
        #expect(late == expected)
        #expect(core.apply(Self.act("time.rewind")) == .accepted)
        #expect(core.play.tick == 0 && core.play.stage == .playing)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 12)
        let level: ChronoConstellatorLevel = core.play.level
        let startDigest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("star.phase", [0, Self.otherPhase(0, level)])) == .accepted)
        #expect(core.apply(Self.act("star.hold", [1, 2, 2])) == .accepted)
        #expect(core.apply(Self.act("time.step", [3])) == .accepted)
        let moved: Core = core
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(core.play.timeline == ChronoConstellatorTimeline(level: level) && core.play.tick == 0)
        #expect(core.play.spent == 0 && core.play.stage == .playing)
        #expect(try Self.digest(core) == startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.redo")) == .accepted) }
        #expect(core.play.timeline == moved.play.timeline && core.play.tick == moved.play.tick)
        #expect(core.play.records.count == 9)
        #expect(try Self.digest(core) == movedDigest)
        // On level 13 this edited timeline collides within three ticks: the redone step restores the failed moment,
        // where redo is a stage refusal (undo still works in a failed play).
        #expect(core.play.stage == .failed && core.play.failure?.code == "collision" && core.outcome?.code == "failed")
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g06.stage")))
        // A new action clears the redo history.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("time.step", [1])) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g06.action")))
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(try Self.digest(core) == startDigest)
    }

    @Test func theSolutionWinsTheUneditedLevelFailsUndoAndRewindRetry() async throws {
        let numbers: [Int] = [1, 24]
        for number in numbers {
            let generated: ChronoConstellatorGenerated = try Core.generated(number: number)
            let level: ChronoConstellatorLevel = generated.level
            var core: Core = try Core.opening(number: number)
            // Unedited, the level fails; undo of the failing step returns to playing with the earlier digest.
            var failing: Core = core
            let before: StateDigest = try Self.digest(failing)
            #expect(failing.apply(Self.act("time.step", [Double(level.tickLimit)])) == .accepted)
            #expect(failing.play.stage == .failed && failing.outcome?.code == Core.failedCode, "level \(number)")
            #expect(failing.snapshot(time: 0).stage == .failed && failing.snapshot(time: 0).failure != nil)
            let failed: Core = failing
            let stageCode: ActionResult = .rejected(.rule(code: "r02-g06.stage"))
            #expect(failing.apply(Self.act("time.step", [1])) == stageCode)
            #expect(failing.apply(Self.act("star.hold", [0, 1, 1])) == stageCode)
            #expect(failing.apply(Self.act("play.redo")) == stageCode)
            #expect(failing == failed)
            var retried: Core = failing
            #expect(retried.apply(Self.act("time.rewind")) == .accepted)
            #expect(retried.play.stage == .playing && retried.play.tick == 0 && retried.outcome == nil)
            #expect(try Self.digest(retried) == before)
            while failing.play.canUndo { #expect(failing.apply(Self.act("play.undo")) == .accepted) }
            #expect(failing.play.stage == .playing && failing.outcome == nil)
            #expect(try Self.digest(failing) == before)
            // The certified solution's phases, then time: won.
            let changes: [ChronoConstellatorAction] = ChronoConstellatorWitness.phaseChanges(for: generated.solution,
                                                                                            level: level)
            for change in changes {
                guard case .phase(let star, let offset) = change else { continue }
                #expect(core.apply(Self.act("star.phase", [Double(star), Double(offset)])) == .accepted)
            }
            #expect(core.apply(Self.act("time.step", [Double(level.tickLimit)])) == .accepted)
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "level \(number)")
            #expect(core.play.tick == generated.difficulty.winTick)
            let won: Core = core
            #expect(core.apply(Self.act("play.undo")) == stageCode)
            #expect(core.apply(Self.act("time.rewind")) == stageCode)
            #expect(core.apply(Self.act("time.step", [1])) == stageCode)
            #expect(core == won)
            #expect(core.apply(Self.act("level.next")) == .accepted)
            #expect(core.play.stage == .playing && core.levelNumber == number + 1 && core.outcome == nil)
            core.reset()
            #expect(core.levelNumber == number && core.play.records.isEmpty && core.play.stage == .playing)
        }
    }

    /// Feature 355: `level.next` moves to the next open level only (a locked next level is refused, 100 does not wrap);
    /// a selected open level opens fresh; reset returns to the seed's opening state, progress included.
    @Test func nextLevelNeedsAnOpenLevelAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 38)
        #expect(core.levelNumber == 39 && core.progress.frontier == 39)
        #expect(core.apply(Self.act("time.step", [3])) == .accepted)
        let before: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: ChronoConstellatorExperienceRule.locked)))
        #expect(try Self.digest(core) == before)
        #expect(core.apply(Self.act("level.select", [40])) == .rejected(.rule(code: "r02-g06.locked")))
        #expect(core.apply(Self.act("level.select", [12])) == .accepted)
        #expect(core.levelNumber == 12 && core.play.records.isEmpty && core.mode == .campaign)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 13 && core.play.stage == .playing)
        core.reset()
        let fresh: Core = try await Core.prepare(seed: 38)
        let resetDigest: StateDigest = try Self.digest(core)
        let freshDigest: StateDigest = try Self.digest(fresh)
        #expect(core == fresh && resetDigest == freshDigest)
        // No wrap: level 100 has no next level.
        var last: Core = try Core.opening(number: 100)
        #expect(last.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g06.locked")))
        #expect(last.levelNumber == 100)
    }

    /// Feature 355: daily and practice modes, the date refusal, the tutorial dismissal, stars and unlocks on a win.
    @Test func modesProgressAndTheTutorial() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.tutorial == .shift && core.mode == .campaign)
        #expect(core.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(core.tutorial == .done)
        #expect(core.apply(Self.act("mode.daily", [2027, 2, 29])) == .rejected(.rule(code: "r02-g06.date")))
        let daily: Int = try #require(ChronoConstellatorProgress.dailyLevel(year: 2026, month: 11, day: 21))
        #expect(core.apply(Self.act("mode.daily", [2026, 11, 21])) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily && core.progress.frontier == 1)
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.play.level.budget == Core.practiceBudget)
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1)
        // A campaign win records stars and opens level 2.
        let certified: ChronoConstellatorGenerated = try Core.generated(number: 1)
        for action in ChronoConstellatorWitness.actions(for: certified.solution, level: certified.level) {
            switch action {
            case .phase(let star, let phase):
                #expect(core.apply(Self.act("star.phase", [Double(star), Double(phase)])) == .accepted)
            case .step(let ticks):
                #expect(core.apply(Self.act("time.step", [Double(ticks)])) == .accepted)
            default:
                Issue.record("unexpected witness action \(action)")
            }
        }
        #expect(core.play.stage == .won && core.progress.frontier == 2)
        #expect(core.progress.solved[1]?.stars == 3)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 2 && core.tutorial == .shift)
    }

    /// Feature 355 (SC-R02G0605-001): on levels 1 … 3 a scripted player following each instruction and the exact hints
    /// wins, and each instruction matches the state it was shown in.
    @Test func aPlayerFollowingTheTutorialAndHintsWinsLevelsOneToThree() throws {
        for number in 1...3 {
            var core: Core = try Core.opening(number: number)
            var seen: [ChronoConstellatorTutorialStep] = [core.tutorial]
            var guardCount: Int = 0
            while core.play.stage != .won && guardCount < 40 {
                guardCount += 1
                let hint: ChronoConstellatorHint = try #require(core.hint(level: 3), "level \(number)")
                let result: ActionResult
                switch hint.kind {
                case .phase:
                    #expect(core.tutorial == .shift, "level \(number)")
                    let star: Int = try #require(hint.star)
                    let phase: Int = try #require(hint.phase)
                    result = core.apply(Self.act("star.phase", [Double(star), Double(phase)]))
                case .run:
                    // The first run hint shows "replay"; after a step the instruction is "align".
                    #expect(core.tutorial == .replay || core.tutorial == .align, "level \(number)")
                    result = core.apply(Self.act("time.step", [1]))
                case .release:
                    result = core.apply(Self.act("star.release", [Double(hint.star ?? 0), Double(hint.start ?? 1)]))
                case .rewind:
                    result = core.apply(Self.act("time.rewind"))
                case .stuck:
                    Issue.record("level \(number) stuck")
                    return
                }
                #expect(result == .accepted, "level \(number) \(hint.kind)")
                if seen.last != core.tutorial { seen.append(core.tutorial) }
            }
            #expect(core.play.stage == .won && core.tutorial == .done, "level \(number)")
            #expect(seen.first == .shift && seen.contains(.replay) && seen.last == .done, "level \(number): \(seen)")
        }
    }

    /// Feature 355: a schema-1 payload migrates to schema 2 (the levels up to the saved level open, campaign mode, the
    /// tutorial at its initial step).
    @Test func aSchemaOnePayloadMigrates() throws {
        var core: Core = try Core.opening(number: 7)
        #expect(core.apply(Self.act("time.step", [2])) == .accepted)
        let records: Data = try JSONEncoder().encode(core.play.records)
        let recordsText: String = String(decoding: records, as: UTF8.self)
        let schemaOne: String = "{\"level\":7,\"records\":" + recordsText + "}"
        let object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: Data(schemaOne.utf8)) as? [String: Any])
        let migrated: [String: Any] = try Core.migratedToSchemaTwo(object)
        let data: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
        let restored: Core = try Core.restore(payload: data, seed: 6)
        #expect(restored.levelNumber == 7 && restored.play == core.play)
        #expect(restored.progress.frontier == 7 && restored.mode == .campaign && restored.tutorial == .done)
        #expect(throws: ChronoConstellatorRestoreRefusal.damaged) {
            try Core.migratedToSchemaTwo(["level": "7"])
        }
        // The declared chain carries the step 1 → 2.
        #expect(Core.migrations.currentVersion == 3)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        var core: Core = try await Core.prepare(seed: 31)
        let level: ChronoConstellatorLevel = core.play.level
        #expect(core.apply(Self.act("star.phase", [1, Self.otherPhase(1, level)])) == .accepted)
        #expect(core.apply(Self.act("star.hold", [0, 1, 2])) == .accepted)
        #expect(core.apply(Self.act("time.step", [5])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let payload: Data = try core.snapshotPayload()
        #expect(try core.snapshotPayload() == payload)
        let text: String = try #require(String(data: payload, encoding: .utf8))
        #expect(text.hasPrefix("{\"level\":32,\"mode\":"))
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

        #expect(throws: ChronoConstellatorRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 31)
        }
        #expect(throws: ChronoConstellatorRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 31)
        }
        #expect(throws: ChronoConstellatorRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"32\",\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: ChronoConstellatorRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":0").utf8),
                             seed: 31)
        }
        #expect(throws: ChronoConstellatorRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":101").utf8),
                             seed: 31)
        }
        // The same records on another level: the first record's previous fingerprint is stale there.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":1").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: ChronoConstellatorRestoreRefusal.kernel(.stale)) {
            try Core.restore(payload: wrongLevel, seed: 31)
        }
        // A record of a newer schema: the replayed record (schema 1) differs from the stored one.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: ChronoConstellatorRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: newer, seed: 31)
        }
        // An edited tick: the replayed record differs from the stored one.
        let edited: Data = Data(text.replacingOccurrences(of: "\"tick\":0", with: "\"tick\":7").utf8)
        #expect(edited != payload)
        #expect(throws: ChronoConstellatorRestoreRefusal.kernel(.malformed("record 0"))) {
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
        let ribbons: [Int] = [24, 24, 12, 6, 6]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.ribbonTicks == ribbons[index])
            #expect(core.renderTier == ChronoConstellatorTier.of(clamped[index]))
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: ChronoConstellatorSceneSnapshot = core.snapshot(time: time)
            #expect(snapshot.stars.map(\.cell) == core.play.positions && snapshot.stage == core.play.stage)
            #expect(snapshot.levelNumber == core.levelNumber && snapshot.time.isFinite)
            #expect(snapshot.tick == core.play.tick)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }

    /// Feature 357: a won campaign play records its net trace as a verified result; replay plays it action by action,
    /// refuses other play actions, ends with replay-end and never changes progress; stop returns to campaign.
    @Test func replayPlaysTheStoredTraceAndChangesNothing() throws {
        var core: Core = try Core.opening(number: 1)
        let certified: ChronoConstellatorGenerated = try Core.generated(number: 1)
        let actions: [ChronoConstellatorAction] = ChronoConstellatorWitness.actions(for: certified.solution,
                                                                                    level: certified.level)
        #expect(core.apply(Self.act("replay.start", [1])) == .rejected(.rule(code: "r02-g06.no-replay")))
        #expect(core.apply(Self.act("replay.step")) == .rejected(.rule(code: "r02-g06.no-replay")))
        // A detour that is undone stays out of the trace.
        let detour: ExperienceAction = Self.act("star.hold", [0, 50, 2])
        #expect(core.apply(detour) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        for action in actions {
            switch action {
            case .phase(let star, let phase):
                #expect(core.apply(Self.act("star.phase", [Double(star), Double(phase)])) == .accepted)
            case .step(let ticks):
                #expect(core.apply(Self.act("time.step", [Double(ticks)])) == .accepted)
            default:
                Issue.record("unexpected witness action \(action)")
            }
        }
        let result: ChronoConstellatorProgress.Result = try #require(core.progress.solved[1])
        #expect(result.verified && result.trace == actions)
        let progress: ChronoConstellatorProgress = core.progress
        #expect(core.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(core.mode == .replay(level: 1) && core.tutorial == .done && core.play.records.isEmpty)
        #expect(core.apply(Self.act("star.phase", [0, 1])) == .rejected(.rule(code: "r02-g06.replay")))
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g06.replay")))
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted)
        var reference: ChronoConstellatorPlay = try Core.freshPlay(of: certified.level)
        for action in actions {
            #expect(core.apply(Self.act("replay.step")) == .accepted)
            try reference.apply(action, expecting: reference.fingerprint)
            #expect(core.play.fingerprint == reference.fingerprint)
        }
        #expect(core.play.stage == .won && core.progress == progress)
        #expect(core.apply(Self.act("replay.step")) == .rejected(.rule(code: "r02-g06.replay-end")))
        #expect(core.apply(Self.act("replay.stop")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.soundOn)
        #expect(core.apply(Self.act("replay.stop")) == .rejected(.rule(code: "r02-g06.no-replay")))
    }

    /// Feature 357: the sound choice is snapshotted and in `==`, never in the digest; reset turns it off.
    @Test func theSoundChoiceIsSavedButNotDigested() throws {
        var core: Core = try Core.opening(number: 4)
        let before: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted && core.soundOn)
        #expect(try Self.digest(core) == before)
        #expect(core.apply(Self.act("settings.sound", [0.5])) == .rejected(.rule(code: "r02-g06.not-whole")))
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 3)
        #expect(restored.soundOn && restored == core)
        core.reset()
        #expect(!core.soundOn)
    }

    /// Feature 357: a schema-2 object migrates to schema 3 (empty traces, unverified, sound off) and restores with its
    /// progress; an edited verified result is dropped on restore and counted, the frontier kept as saved.
    @Test func schemaTwoMigratesAndEditedResultsAreDropped() throws {
        var progress: ChronoConstellatorProgress = ChronoConstellatorProgress()
        progress.record(level: 1, edits: 1, smallest: 1)
        progress.open(through: 5)
        let progressObject: Any = try JSONSerialization.jsonObject(with: try Core.payloadEncoder().encode(progress))
        var two: [String: Any] = ["level": 3, "records": [Any](), "progress": progressObject,
                                  "mode": ["mode": "campaign"]]
        two["tutorial"] = "done"
        // Remove the schema-3 fields the encoder wrote, as a schema-2 save had none.
        if var p = two["progress"] as? [String: Any], var solved = p["solved"] as? [[String: Any]] {
            for index in solved.indices {
                solved[index].removeValue(forKey: "trace")
                solved[index].removeValue(forKey: "verified")
            }
            p["solved"] = solved
            two["progress"] = p
        }
        let three: [String: Any] = try Core.migratedToSchemaThree(two)
        #expect(three["sound"] as? Bool == false)
        let data: Data = try JSONSerialization.data(withJSONObject: three, options: [.sortedKeys])
        let restored: Core = try Core.restore(payload: data, seed: 2)
        #expect(restored.progress.frontier == 5 && restored.reconciliationDropped == 0)
        #expect(restored.progress.solved[1]?.verified == false && !restored.soundOn)
        #expect(throws: ChronoConstellatorRestoreRefusal.damaged) { try Core.migratedToSchemaThree(["level": 1]) }
        // An edited verified result: a won trace claimed with one edit too many.
        let certified: ChronoConstellatorGenerated = try Core.generated(number: 2)
        let trace: [ChronoConstellatorAction] = ChronoConstellatorWitness.actions(for: certified.solution,
                                                                                  level: certified.level)
        var edited: ChronoConstellatorProgress = ChronoConstellatorProgress()
        edited.open(through: 7)
        edited.record(level: 2, edits: certified.difficulty.smallest + 1, smallest: certified.difficulty.smallest,
                      trace: trace)
        var core: Core = try Core.opening(number: 2)
        #expect(core.apply(Self.act("time.step", [1])) == .accepted)
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: try core.snapshotPayload()) as? [String: Any])
        object["progress"] = try JSONSerialization.jsonObject(with: try Core.payloadEncoder().encode(edited))
        let tampered: Data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let checked: Core = try Core.restore(payload: tampered, seed: 1)
        #expect(checked.reconciliationDropped == 1 && checked.progress.solved[2] == nil)
        #expect(checked.progress.frontier == 7)
    }
}
