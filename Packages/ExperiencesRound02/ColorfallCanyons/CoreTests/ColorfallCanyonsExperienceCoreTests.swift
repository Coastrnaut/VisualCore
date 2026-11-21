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
                                         ScriptedAction("canyon.valve", [0])]
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
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 1], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g05.colorfall-canyons" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g05.colorfall-canyons.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        #expect(Core.actionIDs == ["canyon.carve", "canyon.valve", "time.step", "play.undo", "play.redo", "level.next"])
        #expect(Core.controls[0].ranges == [0...119])
        #expect(Core.controls[1].ranges == [0...2])
        #expect(Core.controls[2].ranges == [1...600])
        let plainIndices: [Int] = [3, 4, 5]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.migrations.currentVersion == 1)
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

    @Test func nextLevelWrapsAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 38)
        #expect(core.levelNumber == 39)
        #expect(core.apply(Self.act("time.step", [3])) == .accepted)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 40 && core.play.records.isEmpty && core.play.stage == .playing)
        core.reset()
        let fresh: Core = try await Core.prepare(seed: 38)
        let resetDigest: StateDigest = try Self.digest(core)
        let freshDigest: StateDigest = try Self.digest(fresh)
        #expect(core == fresh && resetDigest == freshDigest)
        // The wrap: level 100 → 1 (level 100 is in the cache once the preparation check ran; generated here otherwise).
        var last: Core = try Core.opening(number: 100)
        #expect(last.apply(Self.act("level.next")) == .accepted)
        let first: Core = try await Core.prepare(seed: 0)
        #expect(last.levelNumber == 1 && last == first)
        last.reset()
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
        #expect(text.hasPrefix("{\"level\":32,\"records\":["))
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
        #expect(throws: ColorfallCanyonsRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"32\",\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: ColorfallCanyonsRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: ColorfallCanyonsRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 31)
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
        let newer = try ExperienceSnapshot(experience: id, schemaVersion: 2, seed: saved.seed,
                                           stepIndex: saved.stepIndex, digest: saved.digest,
                                           payload: Data(saved.payload.utf8))
        var refused: Bool = false
        do {
            try engine.restore(newer)
        } catch {
            refused = error == .snapshot(.newerSchema(found: 2, current: 1))
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
}
