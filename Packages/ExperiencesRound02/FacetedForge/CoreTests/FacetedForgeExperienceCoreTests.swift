// FacetedForgeExperienceCoreTests — feature 373 (R02-G08-03) T-R02G0803-005 (FR-R02G0803-005, 008, 009; clarification
// Q5). The adapter core: the shared conformance checks pass; the seed picks level `seed % 100 + 1` deterministically in
// stage `playing` (seeds 0, 1, 99 and 100 give levels 1, 2, 100 and 1); every control is accepted when legal and
// refused with the state unchanged otherwise (the engine's range checks, `r02-g08.not-whole`, the kernel's
// `r02-g08.action`, `r02-g08.miss` and `r02-g08.stage`); undo restores the earlier digest exactly and redo the later
// one; the certified solution wins, a sliver and the budget fail, undo returns a failed play to playing; `level.next`
// wrapped 100 to 1 (feature 375: no longer) and reset returns; the snapshot round trip and refused payloads (damaged,
// level out of range, a trace of another level, an edited record, a record of a newer schema, an envelope of a newer
// schema); the quality tier, the preview choice and the presenter's snapshot time never touch the digest. Levels are
// generated once per process, so the run stays short. Explicit types, plain loops.
//
// Feature 375 (R02-G08-05) T-R02G0805-004: schema 2 and the progression controls — `level.select`, `mode.daily`,
// `mode.practice`, `mode.campaign` and `tutorial.dismiss` with their refusals (`r02-g08.locked`, `r02-g08.date`, wrong
// value counts); `level.next` moves to the next open level only (100 no longer wraps); a campaign win records stars by
// cuts made (cut-and-undo detours included) and opens the next level, a daily win opens nothing (a locked daily level
// is playable) and practice (budget 20, a fresh play) records nothing; `mode.campaign` returns; the tutorial is
// dismissed and advances on accepted cuts, never back on undo, and is not digested; the schema-2 round trip, the
// migration of a schema-1 payload (directly and through the engine's migration chain), damaged progress or mode (a
// daily mode naming another level among them) refused and an envelope of a newer schema (3) refused.
import Foundation
import Testing
@testable import FacetedForgeCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct FacetedForgeExperienceCoreTests {
    typealias Core = FacetedForgeExperienceCore

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
    static func act(_ action: FacetedForgeAction) -> ExperienceAction {
        switch action {
        case .cut(let piece, let direction, let depth):
            act("piece.cut", [Double(piece), Double(direction), Double(depth)])
        }
    }

    /// A cut of the largest piece of `core` through its middle crossing depth that keeps the play going; when `last`,
    /// one that ends the play on the budget instead. Nil when no direction gives one.
    static func neutralCut(_ core: Core, last: Bool) -> ExperienceAction? {
        let play: FacetedForgePlay = core.play
        var largest: Int = 0
        for index in play.shares.indices where play.shares[index] > play.shares[largest] { largest = index }
        for direction in 0..<FacetedForgeDirection.all.count {
            let crossing: [Int] = FacetedForgeSolver.crossingDepths(play.pieces[largest], direction: direction)
            if crossing.isEmpty { continue }
            let action: ExperienceAction = act(.cut(largest, direction, crossing[crossing.count / 2]))
            var copy: Core = core
            guard copy.apply(action).isAccepted else { continue }
            if last ? copy.play.failure == .budget : copy.play.stage == .playing { return action }
        }
        return nil
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 2 (and 2 and 3 for the restore engine): a halving cut, undo and redo, a diagonal cut of one
        // half (prisms, never a target of these levels), undo, then level.next and two more cuts.
        let actions: [ScriptedAction] = [ScriptedAction("piece.cut", [0, 0, 0]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("piece.cut", [0, 3, 0]),
                                         ScriptedAction("play.undo"), ScriptedAction("level.next"),
                                         ScriptedAction("piece.cut", [0, 0, 0]),
                                         ScriptedAction("piece.cut", [1, 3, 0])]
        let rejected: [ScriptedAction] = [ScriptedAction("piece.cut", [21, 0, 0]),
                                          ScriptedAction("piece.cut", [-1, 0, 0]),
                                          ScriptedAction("piece.cut", [0, 13, 0]),
                                          ScriptedAction("piece.cut", [0, 0, 25]),
                                          ScriptedAction("piece.cut", [0, 0, 0.5]),
                                          ScriptedAction("piece.cut", [1, 0, 0]),
                                          ScriptedAction("piece.cut", [0, 0, 24]),
                                          ScriptedAction("piece.cut", [0, 0]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("level.select", []),
                                          ScriptedAction("mode.daily", [2026, 1]),
                                          ScriptedAction("mode.practice", [1]), ScriptedAction("mode.campaign", [1]),
                                          ScriptedAction("tutorial.dismiss", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 1], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g08.faceted-forge" && Core.schemaVersion == 2)
        #expect(Core.digestDomain == "r02-g08.faceted-forge.v2")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        #expect(Core.actionIDs == ["piece.cut", "play.undo", "play.redo", "level.next", "level.select", "mode.daily",
                                   "mode.practice", "mode.campaign", "tutorial.dismiss"])
        #expect(Core.controls[0].ranges == [0...20, 0...12, -24...24])
        #expect(Core.controls[4].ranges == [1...100])
        #expect(Core.controls[5].ranges == [1...9_999, 1...12, 1...31])
        let plainIndices: [Int] = [1, 2, 3, 6, 7, 8]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.migrations.currentVersion == 2)
        #expect(Core.practiceBudget == 20)
        #expect(FacetedForgeExperienceRule.locked == "r02-g08.locked")
        #expect(FacetedForgeExperienceRule.date == "r02-g08.date")
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == FacetedForgeTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 2.0 / 3.0, 1.0 / 3.0] && iterations == [1, 2.0 / 3.0, 1.0 / 3.0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(FacetedForgeExperienceRule.notWhole == "r02-g08.not-whole")
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
            let expected: FacetedForgeLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.pieces == [expected.crystal])
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.play.cuts == 0 && first.qualityTier == 0)
        }
        // The cache hands back the generator's own level.
        let entry: FacetedForgeManifestEntry = FacetedForgeManifest.entries[1]
        let fresh: FacetedForgeLevel = try FacetedForgeGenerator.generate(entry).level
        #expect(try Core.level(number: 2) == fresh)
        #expect(throws: FacetedForgeError.level("number")) { try Core.level(number: 0) }
        #expect(throws: FacetedForgeError.level("number")) { try Core.level(number: 101) }
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let illegal: [ExperienceAction] = [Self.act("piece.cut", [21, 0, 0]), Self.act("piece.cut", [-1, 0, 0]),
                                           Self.act("piece.cut", [0, 13, 0]), Self.act("piece.cut", [0, -1, 0]),
                                           Self.act("piece.cut", [0, 0, 25]), Self.act("piece.cut", [0, 0, -25]),
                                           Self.act("piece.cut", [0.5, 0, 0]), Self.act("piece.cut", [0, 0, .nan]),
                                           Self.act("piece.cut", [1, 0, 0]), Self.act("piece.cut", [0, 0, 24]),
                                           Self.act("piece.cut", [0, 0]), Self.act("play.undo"),
                                           Self.act("play.redo"), Self.act("play.undo", [1]),
                                           Self.act("level.next", [1]), Self.act("level.next"),
                                           Self.act("level.select", [2]), Self.act("level.select", [0]),
                                           Self.act("level.select", [1.5]), Self.act("level.select", []),
                                           Self.act("mode.daily", [2027, 2, 29]), Self.act("mode.daily", [2026, 13, 1]),
                                           Self.act("mode.daily", [2026, 4, 31]), Self.act("mode.daily", [2026, 1, 0]),
                                           Self.act("mode.daily", [2026, 11]), Self.act("mode.practice", [1]),
                                           Self.act("mode.campaign", [1]), Self.act("tutorial.dismiss", [1]),
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
        #expect(probe.apply(Self.act("piece.cut", [21, 0, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("piece.cut", [0, 13, 0])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("piece.cut", [0, 0, -25])) == .rejected(.outOfRange(index: 2)))
        #expect(probe.apply(Self.act("piece.cut", [0, 0])) == .rejected(.wrongValueCount(expected: 3, found: 2)))
        #expect(probe.apply(Self.act("play.undo", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("level.next", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("level.select", [])) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(probe.apply(Self.act("level.select", [1, 2])) == .rejected(.wrongValueCount(expected: 1, found: 2)))
        #expect(probe.apply(Self.act("level.select", [101])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("level.select", [0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("mode.daily", [2026, 11])) == .rejected(.wrongValueCount(expected: 3, found: 2)))
        #expect(probe.apply(Self.act("mode.daily", [2026, 13, 1])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("mode.daily", [2026, 1, 32])) == .rejected(.outOfRange(index: 2)))
        #expect(probe.apply(Self.act("mode.practice", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("mode.campaign", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("tutorial.dismiss", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        let locked: ActionResult = .rejected(.rule(code: FacetedForgeExperienceRule.locked))
        #expect(probe.apply(Self.act("level.next")) == locked)
        #expect(probe.apply(Self.act("level.select", [2])) == locked)
        let date: ActionResult = .rejected(.rule(code: FacetedForgeExperienceRule.date))
        #expect(probe.apply(Self.act("mode.daily", [2027, 2, 29])) == date)
        #expect(probe.apply(Self.act("mode.daily", [2026, 4, 31])) == date)
        // Day 0 lies outside the declared day range 1 … 31: the engine refuses it before the calendar check.
        #expect(probe.apply(Self.act("mode.daily", [2026, 1, 0])) == .rejected(.outOfRange(index: 2)))
        #expect(probe.apply(Self.act("mode.daily", [2026, 2, 30])) == date)
        let notWhole: ActionResult = .rejected(.rule(code: FacetedForgeExperienceRule.notWhole))
        #expect(probe.apply(Self.act("level.select", [1.5])) == notWhole)
        #expect(probe.apply(Self.act("mode.daily", [2026, 1, 1.5])) == notWhole)
        #expect(probe.apply(Self.act("piece.cut", [0.5, 0, 0])) == notWhole)
        #expect(probe.apply(Self.act("piece.cut", [0, 0, 0.5])) == notWhole)
        // The kernel's refusals pass through with their reason codes.
        let action: ActionResult = .rejected(.rule(code: "r02-g08.action"))
        #expect(probe.apply(Self.act("piece.cut", [1, 0, 0])) == action)
        #expect(probe.apply(Self.act("piece.cut", [0, 0, 24])) == .rejected(.rule(code: "r02-g08.miss")))
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe.apply(Self.act("nope")) == .rejected(.unknownControl("nope")))
        #expect(probe == core)

        // A cut spends one cut and replaces the piece by its two halves.
        #expect(core.apply(Self.act("piece.cut", [0, 0, 0])) == .accepted)
        #expect(core.play.pieces.count == 2 && core.play.cuts == 1 && core.play.records.count == 1)
        #expect(try Self.digest(core) != opening)
        // The second piece now exists; a third does not.
        var two: Core = core
        #expect(two.apply(Self.act("piece.cut", [2, 0, 0])) == action)
        #expect(two == core)
        #expect(two.apply(Self.act("piece.cut", [1, 3, 0])) == .accepted)
        #expect(two.play.pieces.count == 3 && two.play.cuts == 2)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 20)
        let startDigest: StateDigest = try Self.digest(core)
        let start: [FacetedForgePiece] = core.play.pieces
        for _ in 0..<3 {
            let cut: ExperienceAction = try #require(Self.neutralCut(core, last: false))
            #expect(core.apply(cut) == .accepted)
        }
        let moved: Core = core
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(core.play.pieces == start && core.play.cuts == 0 && core.play.stage == .playing)
        #expect(try Self.digest(core) == startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.redo")) == .accepted) }
        #expect(core.play.pieces == moved.play.pieces && core.play.cuts == 3)
        #expect(core.play.records.count == 9)
        #expect(try Self.digest(core) == movedDigest)
        // A new cut clears the redo history.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let other: ExperienceAction = try #require(Self.neutralCut(core, last: false))
        #expect(core.apply(other) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g08.action")))
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(try Self.digest(core) == startDigest)
    }

    @Test func theSolutionWinsTheBudgetFailsAndUndoRetries() async throws {
        let numbers: [Int] = [1, 21]
        let stageCode: ActionResult = .rejected(.rule(code: "r02-g08.stage"))
        for number in numbers {
            let generated: FacetedForgeGenerated = try Core.generated(number: number)
            let level: FacetedForgeLevel = generated.level
            var core: Core = try Core.opening(number: number)
            // Neutral cuts until the budget is spent: failed (budget); undo returns to playing.
            var failing: Core = core
            let before: StateDigest = try Self.digest(failing)
            for index in 0..<level.budget {
                let cut: ExperienceAction = try #require(Self.neutralCut(failing, last: index == level.budget - 1))
                #expect(failing.apply(cut) == .accepted)
            }
            #expect(failing.play.stage == .failed && failing.play.failure == .budget, "level \(number)")
            #expect(failing.outcome?.code == Core.failedCode)
            let failedSnapshot: FacetedForgeSceneSnapshot = failing.snapshot(time: 0)
            #expect(failedSnapshot.stage == .failed && failedSnapshot.failure == .budget)
            #expect(failedSnapshot.failurePiece == nil && failedSnapshot.cuts == level.budget)
            let failed: Core = failing
            #expect(failing.apply(Self.act("piece.cut", [0, 0, 0])) == stageCode)
            #expect(failing.apply(Self.act("play.redo")) == stageCode)
            #expect(failing == failed)
            #expect(failing.apply(Self.act("play.undo")) == .accepted)
            #expect(failing.play.stage == .playing && failing.outcome == nil)
            while failing.play.canUndo { #expect(failing.apply(Self.act("play.undo")) == .accepted) }
            #expect(try Self.digest(failing) == before)
            // The certified solution: won on its last cut.
            for step in generated.solution.actions { #expect(core.apply(Self.act(step)) == .accepted) }
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "level \(number)")
            #expect(core.play.cuts == generated.solution.smallest && core.snapshot(time: 0).won)
            let won: Core = core
            #expect(core.apply(Self.act("play.undo")) == stageCode)
            #expect(core.apply(Self.act("play.redo")) == stageCode)
            #expect(core.apply(Self.act("piece.cut", [0, 0, 0])) == stageCode)
            #expect(core == won)
            #expect(core.apply(Self.act("level.next")) == .accepted)
            #expect(core.play.stage == .playing && core.levelNumber == number + 1 && core.outcome == nil)
            core.reset()
            #expect(core.levelNumber == number && core.play.records.isEmpty && core.play.stage == .playing)
        }
    }

    @Test func aSliverFailsAndUndoRetries() async throws {
        // The first cut of level 1 at the extreme crossing depth of some direction that leaves a sliver.
        var core: Core = try Core.opening(number: 1)
        let before: StateDigest = try Self.digest(core)
        var sliver: Core? = nil
        for direction in 0..<FacetedForgeDirection.all.count where sliver == nil {
            let crossing: [Int] = FacetedForgeSolver.crossingDepths(core.play.pieces[0], direction: direction)
            let extremes: [Int] = [crossing.first ?? 0, crossing.last ?? 0]
            for depth in extremes where sliver == nil {
                var copy: Core = core
                let cut: ExperienceAction = Self.act(.cut(0, direction, depth))
                if copy.apply(cut).isAccepted, case .sliver = copy.play.failure { sliver = copy }
            }
        }
        core = try #require(sliver)
        guard case .sliver(let piece, let cut) = core.play.failure else {
            Issue.record("no sliver failure")
            return
        }
        #expect(cut == 0 && core.play.stage == .failed && core.outcome?.code == Core.failedCode)
        #expect(core.play.shares[piece] < core.play.level.sliver)
        let snapshot: FacetedForgeSceneSnapshot = core.snapshot(time: 1)
        #expect(snapshot.failurePiece == piece && snapshot.failure == core.play.failure)
        #expect(core.apply(Self.act("piece.cut", [0, 0, 0])) == .rejected(.rule(code: "r02-g08.stage")))
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let retried: StateDigest = try Self.digest(core)
        #expect(core.play.stage == .playing && core.play.failure == nil && retried == before)
    }

    /// Feature 375: `level.next` moves to the next open level only (a locked next level is refused, 100 does not wrap);
    /// a selected open level opens fresh; reset returns to the seed's opening state, progress included.
    @Test func nextLevelNeedsAnOpenLevelAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 40)
        #expect(core.levelNumber == 41 && core.progress.frontier == 41)
        #expect(core.apply(Self.act("piece.cut", [0, 0, 0])) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let locked: ActionResult = .rejected(.rule(code: FacetedForgeExperienceRule.locked))
        let cutState: Core = core
        #expect(core.apply(Self.act("level.next")) == locked)
        #expect(core.apply(Self.act("level.select", [42])) == locked)
        let lockedDigest: StateDigest = try Self.digest(core)
        #expect(core == cutState && lockedDigest == before)
        #expect(core.apply(Self.act("level.select", [12])) == .accepted)
        #expect(core.levelNumber == 12 && core.play.records.isEmpty && core.mode == .campaign)
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
        #expect(last.levelNumber == 100)
    }

    /// Applies `actions` to `core`, each accepted, after `detours` detours of (the first action, undo); returns the
    /// cuts made.
    static func win(_ core: inout Core, actions: [FacetedForgeAction], detours: Int) -> Int {
        guard let first = actions.first else { return 0 }
        for _ in 0..<detours {
            #expect(core.apply(Self.act(first)) == .accepted)
            #expect(core.play.stage == .playing)
            #expect(core.apply(Self.act("play.undo")) == .accepted)
        }
        for action in actions { #expect(core.apply(Self.act(action)) == .accepted) }
        #expect(core.play.stage == .won)
        return FacetedForgeProgress.cutsMade(core.play)
    }

    /// Feature 375 (clarification Q3): a campaign win records the cuts made (undone cuts included) and its stars,
    /// keeps the better result and opens the next level.
    @Test func aCampaignWinRecordsStarsByCutsMade() throws {
        let first: FacetedForgeGenerated = try Core.generated(number: 1)
        let second: FacetedForgeGenerated = try Core.generated(number: 2)
        let smallest: Int = first.solution.smallest
        var core: Core = try Core.opening(number: 1)
        #expect(core.certifiedSmallest == smallest && core.progress.solved.isEmpty)
        // Two detours: smallest + 2 cuts made, 2 stars; level 2 opens.
        let twoDetours: Int = Self.win(&core, actions: first.solution.actions, detours: 2)
        #expect(twoDetours == smallest + 2 && core.play.cuts == smallest)
        #expect(core.progress.solved[1] == FacetedForgeProgress.Result(cutsMade: smallest + 2, stars: 2))
        #expect(core.progress.frontier == 2 && core.outcome?.code == Core.wonCode)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 2 && core.mode == .campaign && core.play.records.isEmpty)
        // Level 1 again without a detour: the better result (3 stars) replaces the stored one.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        let noDetour: Int = Self.win(&core, actions: first.solution.actions, detours: 0)
        #expect(noDetour == smallest)
        #expect(core.progress.solved[1] == FacetedForgeProgress.Result(cutsMade: smallest, stars: 3))
        // A worse result (three detours, 1 star) keeps it.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        let threeDetours: Int = Self.win(&core, actions: first.solution.actions, detours: 3)
        #expect(threeDetours == smallest + 3)
        #expect(core.progress.solved[1] == FacetedForgeProgress.Result(cutsMade: smallest, stars: 3))
        #expect(core.progress.frontier == 2)
        // Level 2 with three detours: 1 star; level 3 opens.
        #expect(core.apply(Self.act("level.next")) == .accepted)
        let secondCuts: Int = Self.win(&core, actions: second.solution.actions, detours: 3)
        #expect(core.progress.solved[2] == FacetedForgeProgress.Result(cutsMade: secondCuts, stars: 1))
        #expect(secondCuts == second.solution.smallest + 3 && core.progress.frontier == 3)
    }

    /// Feature 375 (clarification Q4): daily mode opens nothing and plays a locked level; practice is a fresh play with
    /// the budget 20 that records nothing; `mode.campaign` returns.
    @Test func dailyPracticeAndCampaignModes() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.mode == .campaign && core.progress.frontier == 1)
        let date: ActionResult = .rejected(.rule(code: FacetedForgeExperienceRule.date))
        let opening: Core = core
        #expect(core.apply(Self.act("mode.daily", [2027, 2, 29])) == date)
        #expect(core == opening)
        let daily: Int = try #require(FacetedForgeProgress.dailyLevel(year: 2026, month: 1, day: 2))
        #expect(daily == 68)
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 2])) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily && core.progress.frontier == 1)
        #expect(!core.progress.isOpen(daily) && core.tutorial == .done && core.play.records.isEmpty)
        let dailyCertified: FacetedForgeGenerated = try Core.generated(number: daily)
        #expect(core.play.level == dailyCertified.level && core.certifiedSmallest == dailyCertified.solution.smallest)
        // A daily win on a locked level records its stars but opens nothing.
        var dailyWin: Core = core
        _ = Self.win(&dailyWin, actions: dailyCertified.solution.actions, detours: 0)
        #expect(dailyWin.progress.solved[daily]?.stars == 3 && dailyWin.progress.frontier == 1)
        #expect(dailyWin.apply(Self.act("level.next")) == .rejected(.rule(code: FacetedForgeExperienceRule.locked)))
        // Practice of the daily level: the same level fresh with the budget 20.
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == daily && core.play.level.budget == Core.practiceBudget)
        // Campaign returns to the frontier when the current level is not open.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.tutorial == .aim)

        // Practice on level 1 after a cut: a fresh play of the practice copy; a win records nothing, opens nothing.
        let certified: FacetedForgeGenerated = try Core.generated(number: 1)
        #expect(core.apply(Self.act("piece.cut", [0, 0, 0])) == .accepted)
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.play.records.isEmpty && core.play.cuts == 0 && core.play.stage == .playing)
        #expect(core.play.level.budget == 20 && core.play.level.target == certified.level.target)
        #expect(core.play.level.planes == certified.level.planes && core.play.level.sliver == certified.level.sliver)
        #expect(core.tutorial == .aim && core.levelNumber == 1)
        _ = Self.win(&core, actions: certified.solution.actions, detours: 0)
        #expect(core.progress.solved.isEmpty && core.progress.frontier == 1)
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: FacetedForgeExperienceRule.locked)))
        // Campaign returns to level 1 with its certified budget, fresh.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.play.level == certified.level && core.play.records.isEmpty)
        #expect(core.levelNumber == 1 && core.progress.solved.isEmpty)
    }

    /// Feature 375 (clarification Q2): the tutorial starts on levels 1 … 3, advances on accepted cuts, ends with the
    /// level, never moves back on undo, can be dismissed, and is not part of the digest.
    @Test func theTutorialAdvancesIsDismissedAndIsNotDigested() async throws {
        for number in 1...3 {
            let generated: FacetedForgeGenerated = try Core.generated(number: number)
            var core: Core = try Core.opening(number: number)
            #expect(core.tutorial == .aim, "level \(number)")
            var seen: [FacetedForgeTutorialStep] = [core.tutorial]
            for action in generated.solution.actions {
                #expect(core.apply(Self.act(action)) == .accepted)
                if seen.last != core.tutorial { seen.append(core.tutorial) }
            }
            let expected: [FacetedForgeTutorialStep] = generated.solution.actions.count >= 3
                ? [.aim, .match, .finish, .done] : [.aim, .match, .done]
            #expect(seen == expected, "level \(number): \(seen)")
            #expect(core.play.stage == .won && core.tutorial == .done)
        }
        let four: Core = try Core.opening(number: 4)
        #expect(four.tutorial == .done)
        // Undo never moves the step back; the digest ignores the step.
        var core: Core = try Core.opening(number: 1)
        let fresh: Core = core
        let freshDigest: StateDigest = try Self.digest(fresh)
        #expect(core.apply(Self.act("piece.cut", [0, 0, 0])) == .accepted)
        #expect(core.tutorial == .match)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.tutorial == .match && core.play.pieces == fresh.play.pieces)
        #expect(try Self.digest(core) == freshDigest)
        #expect(core != fresh)
        // Dismissal ends it; later cuts keep it ended; the digest is unchanged by the dismissal.
        var dismissed: Core = try await Core.prepare(seed: 0)
        let before: StateDigest = try Self.digest(dismissed)
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        let dismissedDigest: StateDigest = try Self.digest(dismissed)
        #expect(dismissed.tutorial == .done && dismissedDigest == before)
        #expect(dismissed.apply(Self.act("piece.cut", [0, 0, 0])) == .accepted)
        #expect(dismissed.tutorial == .done)
        var undismissed: Core = try await Core.prepare(seed: 0)
        #expect(undismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(undismissed.apply(Self.act("piece.cut", [0, 0, 0])) == .accepted && undismissed == dismissed)
    }

    /// Feature 375: a schema-1 payload migrates to schema 2 (the levels up to the saved level open, campaign mode, the
    /// tutorial at its initial step).
    @Test func aSchemaOnePayloadMigrates() throws {
        var core: Core = try Core.opening(number: 7)
        #expect(core.apply(Self.act("piece.cut", [0, 0, 0])) == .accepted)
        let records: Data = try JSONEncoder().encode(core.play.records)
        let recordsText: String = String(decoding: records, as: UTF8.self)
        let schemaOne: String = "{\"level\":7,\"records\":" + recordsText + "}"
        let object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: Data(schemaOne.utf8)) as? [String: Any])
        let migrated: [String: Any] = try Core.migratedToSchemaTwo(object)
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
        #expect(tutorialLevel.levelNumber == 2 && tutorialLevel.tutorial == .aim)
        #expect(tutorialLevel.progress.frontier == 2)
        #expect(throws: FacetedForgeRestoreRefusal.damaged) {
            try Core.migratedToSchemaTwo(["level": "7"])
        }
        #expect(throws: FacetedForgeRestoreRefusal.damaged) {
            try Core.migratedToSchemaTwo(["level": 7])
        }
        #expect(Core.migrations.currentVersion == 2)
    }

    /// Feature 375: an engine restores a schema-1 envelope through the migration chain.
    @Test func theEngineMigratesASchemaOneEnvelope() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 4)
        try engine.activate()
        #expect(engine.handle(control: "piece.cut", values: [0, 0, 0]) == .accepted)
        let saved: ExperienceSnapshot = try engine.snapshot()
        var expected: Core = try Core.opening(number: 5)
        #expect(expected.apply(Self.act("piece.cut", [0, 0, 0])) == .accepted)
        let records: String = String(decoding: try JSONEncoder().encode(expected.play.records), as: UTF8.self)
        let schemaOne: String = "{\"level\":5,\"records\":" + records + "}"
        let old = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: saved.seed,
                                         stepIndex: saved.stepIndex, digest: saved.digest,
                                         payload: Data(schemaOne.utf8))
        try engine.restore(old)
        #expect(try engine.digest() == saved.digest)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        var core: Core = try await Core.prepare(seed: 31)
        for _ in 0..<3 {
            let cut: ExperienceAction = try #require(Self.neutralCut(core, last: false))
            #expect(core.apply(cut) == .accepted)
        }
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

        #expect(throws: FacetedForgeRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 31)
        }
        #expect(throws: FacetedForgeRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 31)
        }
        #expect(throws: FacetedForgeRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"32\",\"records\":[]}".utf8), seed: 31)
        }
        // A schema-1 payload is not a schema-2 one (it migrates only through the chain).
        #expect(throws: FacetedForgeRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":32,\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: FacetedForgeRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":0").utf8),
                             seed: 31)
        }
        #expect(throws: FacetedForgeRestoreRefusal.levelNumber(101)) {
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
            #expect(throws: FacetedForgeRestoreRefusal.damaged) {
                try Core.restore(payload: Data(variant.utf8), seed: 31)
            }
        }
        // A daily mode naming its own level restores (the level may be locked in the campaign).
        let dailyLevel: Int = try #require(FacetedForgeProgress.dailyLevel(year: 2026, month: 11, day: 22))
        var daily: Core = core
        #expect(daily.apply(Self.act("mode.daily", [2026, 11, 22])) == .accepted)
        #expect(daily.levelNumber == dailyLevel && daily.mode == .daily(level: dailyLevel))
        let dailyRestored: Core = try Core.restore(payload: try daily.snapshotPayload(), seed: 31)
        #expect(dailyRestored == daily && dailyRestored.certifiedSmallest == daily.certifiedSmallest)
        #expect(try Self.digest(dailyRestored) == Self.digest(daily))
        // A practice state round-trips with its budget.
        var practice: Core = core
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(practice.apply(Self.act("piece.cut", [0, 0, 0])) == .accepted)
        let practiceRestored: Core = try Core.restore(payload: try practice.snapshotPayload(), seed: 31)
        #expect(practiceRestored == practice && practiceRestored.play.level.budget == 20)
        #expect(try Self.digest(practiceRestored) == Self.digest(practice))
        // Progress with a won level round-trips.
        var winner: Core = try Core.opening(number: 2)
        _ = Self.win(&winner, actions: try Core.generated(number: 2).solution.actions, detours: 1)
        let winnerRestored: Core = try Core.restore(payload: try winner.snapshotPayload(), seed: 1)
        #expect(winnerRestored == winner && winnerRestored.progress.solved[2]?.stars == 2)
        #expect(winnerRestored.progress.frontier == 3 && winnerRestored.tutorial == .done)
        // The same records on another level: the first record's previous fingerprint is not that play's.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":1").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: FacetedForgeRestoreRefusal.kernel(.malformed("replay"))) {
            try Core.restore(payload: wrongLevel, seed: 31)
        }
        // A record of a newer schema: the replayed record (schema 1) differs from the stored one.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: FacetedForgeRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: newer, seed: 31)
        }
        // An edited cut index: the replayed record differs from the stored one.
        let edited: Data = Data(text.replacingOccurrences(of: "\"cut\":0,", with: "\"cut\":7,").utf8)
        #expect(edited != payload)
        #expect(throws: FacetedForgeRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: edited, seed: 31)
        }
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 5)
        try engine.activate()
        #expect(engine.handle(control: "piece.cut", values: [0, 0, 0]) == .accepted)
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

    @Test func theTierTheChoiceAndTheSnapshotTimeNeverTouchTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: 4)
        #expect(core.apply(Self.act("piece.cut", [0, 0, 0])) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let bevels: [Int] = [3, 3, 2, 1, 1]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.bevelSegments == bevels[index])
            #expect(core.renderTier == FacetedForgeTier.of(clamped[index]))
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        let choices: [FacetedForgePreviewChoice] = [FacetedForgePreviewChoice(piece: 0, direction: 0, depth: 0),
                                                    FacetedForgePreviewChoice(piece: 1, direction: 5, depth: -2),
                                                    FacetedForgePreviewChoice(piece: 7, direction: 12, depth: 24)]
        for time in times {
            for choice in choices {
                let snapshot: FacetedForgeSceneSnapshot = core.snapshot(choice: choice, time: time)
                #expect(snapshot.choice == choice && snapshot.pieces.count == core.play.pieces.count)
                #expect(snapshot.stage == core.play.stage && snapshot.cuts == core.play.cuts)
                #expect(snapshot.levelNumber == core.levelNumber && snapshot.time.isFinite)
                #expect(snapshot.budget == core.play.level.budget)
                let named: FacetedForgeSceneSnapshot = core.snapshot(chosen: choice.piece, direction: choice.direction,
                                                                     depth: choice.depth, time: time)
                #expect(named == snapshot)
            }
            let initial: FacetedForgeSceneSnapshot = core.snapshot(time: time)
            #expect(initial.choice == FacetedForgePreviewChoice.initial(core.play))
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }
}
