// LissajousLabyrinthExperienceCoreTests — feature 313 (R02-G02-03) T-R02G0203-005 (FR-R02G0203-003, 005; clarification
// Q5). The adapter core: the shared conformance checks pass; the seed picks level `seed % 100 + 1` deterministically in
// stage `playing`; a legal dial.set changes the digest and an illegal one is refused with the state unchanged (the
// engine's range checks, the kernel's `r02-g02.move` for a value outside the dial's own range, the current value or
// non-coprime frequencies); undo restores the earlier digest exactly and redo the later one; the certified solution wins;
// `level.next` wraps 100 to 1 and reset returns; the snapshot round trip and refused payloads; the quality tier and the
// presenter's snapshot time never touch the digest. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import LissajousLabyrinthCore
import VisualCoreDiagnostics
import VisualCoreExperience

@Suite struct LissajousLabyrinthExperienceCoreTests {
    typealias Core = LissajousLabyrinthExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The `dial.set` action for a kernel action.
    static func action(_ move: LissajousLabyrinthAction) -> ExperienceAction {
        let index: Int = Core.dialOrder.firstIndex(of: move.dial) ?? 0
        return ExperienceAction(control: "dial.set", values: [Double(index), Double(move.value)], step: 0)
    }

    /// The `dial.set` action with the given values.
    static func set(_ dial: Double, _ value: Double) -> ExperienceAction {
        ExperienceAction(control: "dial.set", values: [dial, value], step: 0)
    }

    /// A phase value for `phaseC` that differs from the current one.
    static func otherPhaseC(_ core: Core) -> Int {
        (core.play.dials.phaseC + 1) % 16
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 (tutorial) and 100 (hardest band), then 2 and 1 after level.next: every scripted action is legal on
        // them and none wins. Two seeds keep the run short (each preparation generates a certified level).
        let actions: [ScriptedAction] = [ScriptedAction("dial.set", [2, 1]),
                                         ScriptedAction("dial.set", [3, 9]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("play.undo"), ScriptedAction("level.next"),
                                         ScriptedAction("dial.set", [2, 13])]
        let rejected: [ScriptedAction] = [ScriptedAction("dial.set", [0, 0.5]),
                                          ScriptedAction("dial.set", [0.5, 1]),
                                          ScriptedAction("dial.set", [4, 1]),
                                          ScriptedAction("dial.set", [0, 0]),
                                          ScriptedAction("dial.set", [1, 12]),
                                          ScriptedAction("dial.set", [2, 16]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 99], stepsPerSegment: 2, actions: actions,
                                   rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g02.lissajous-labyrinth" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g02.lissajous-labyrinth.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        #expect(Core.actionIDs == ["dial.set", "play.undo", "play.redo", "level.next"])
        #expect(Core.controls[0].ranges == [0...3, 0...15])
        for index in 1..<4 { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.dialOrder == [.frequencyA, .frequencyB, .phaseA, .phaseC])
        #expect(Core.qualityTiers == 3)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 0.5, 0.25] && iterations == [1, 0.5, 0.25] && passes == [2, 1, 0])
        #expect(resolutions == [1, 1, 1])
    }

    @Test func theSeedPicksTheLevelDeterministically() async throws {
        let seeds: [UInt64] = [0, 2, 99, 100, 257]
        let numbers: [Int] = [1, 3, 100, 1, 58]
        for index in seeds.indices {
            #expect(Core.levelNumber(forSeed: seeds[index]) == numbers[index])
            let first: Core = try await Core.prepare(seed: seeds[index])
            let second: Core = try await Core.prepare(seed: seeds[index])
            #expect(first.levelNumber == numbers[index] && first.openingNumber == numbers[index])
            #expect(first == second)
            #expect(try Self.digest(first) == Self.digest(second))
            let expected: LissajousLabyrinthLevel = try LissajousLabyrinthGenerator.generate(
                LissajousLabyrinthManifest.entries[numbers[index] - 1]).level
            #expect(first.play.level == expected && first.play.dials == expected.start)
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
        }
    }

    @Test func aLegalDialSetChangesTheDigestAndIllegalOnesChangeNothing() async throws {
        // Level 1 starts at frequencies 7 and 1, phases 5 and 12.
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let current: Int = core.play.dials.phaseA
        let illegal: [[Double]] = [[2, Double(current)], [2, 1.5], [0.25, 3], [4, 1], [-1, 1], [2, 16], [2, -1],
                                   [0, 0], [0, 10], [1, 7], [2, .nan], [2], [2, 1, 1]]
        for values in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(ExperienceAction(control: "dial.set", values: values, step: 0))
            #expect(!result.isAccepted, "\(values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening, "\(values)")
        }
        var probe: Core = core
        // The current value, a frequency outside 1 … 9 and non-coprime frequencies (7 and 7): the kernel's refusal.
        #expect(probe.apply(Self.set(2, Double(current))) == .rejected(.rule(code: "r02-g02.move")))
        #expect(probe.apply(Self.set(0, 0)) == .rejected(.rule(code: "r02-g02.move")))
        #expect(probe.apply(Self.set(1, 12)) == .rejected(.rule(code: "r02-g02.move")))
        #expect(probe.apply(Self.set(1, 7)) == .rejected(.rule(code: "r02-g02.move")))
        // Outside the declared ranges: the engine's refusal.
        #expect(probe.apply(Self.set(4, 1)) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.set(2, 16)) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.set(2, 1.5)) == .rejected(.rule(code: LissajousLabyrinthExperienceRule.notWhole)))
        #expect(probe.apply(ExperienceAction(control: "play.undo", step: 0)) == .rejected(.rule(code: "r02-g02.move")))
        #expect(probe.apply(ExperienceAction(control: "nope", step: 0)) == .rejected(.unknownControl("nope")))
        #expect(probe == core)
        #expect(core.apply(Self.set(2, 1)) == .accepted)
        #expect(core.play.dials.phaseA == 1 && core.play.records.count == 1 && core.play.spent == 1)
        #expect(try Self.digest(core) != opening)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 12)
        let start: LissajousLabyrinthDials = core.play.dials
        let startDigest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.set(3, Double(Self.otherPhaseC(core)))) == .accepted)
        let moved: LissajousLabyrinthDials = core.play.dials
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest)
        #expect(core.apply(ExperienceAction(control: "play.undo", step: 0)) == .accepted)
        #expect(core.play.dials == start && core.play.spent == 0)
        #expect(try Self.digest(core) == startDigest)
        #expect(core.apply(ExperienceAction(control: "play.redo", step: 0)) == .accepted)
        #expect(core.play.dials == moved && core.play.spent == 1 && core.play.records.count == 3)
        #expect(try Self.digest(core) == movedDigest)
        #expect(core.apply(ExperienceAction(control: "play.redo", step: 0)) == .rejected(.rule(code: "r02-g02.move")))
    }

    @Test func theCertifiedSolutionWins() async throws {
        let seeds: [UInt64] = [0, 41, 63, 99]
        for seed in seeds {
            var core: Core = try await Core.prepare(seed: seed)
            let generated: LissajousLabyrinthGenerated = try LissajousLabyrinthGenerator.generate(
                LissajousLabyrinthManifest.entries[core.levelNumber - 1])
            for move in generated.solution.actions {
                #expect(core.apply(Self.action(move)) == .accepted, "seed \(seed) \(move)")
            }
            #expect(core.play.stage == .won && core.play.dials == generated.solution.setting, "seed \(seed)")
            #expect(core.outcome?.code == "won", "seed \(seed)")
            let won: Core = core
            #expect(core.apply(Self.set(3, Double(Self.otherPhaseC(core)))) == .rejected(.rule(code: "r02-g02.stage")))
            #expect(core == won)
            core.reset()
            #expect(core.play.stage == .playing && core.outcome == nil && core.play.records.isEmpty)
        }
    }

    @Test func nextLevelWrapsAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 98)
        #expect(core.levelNumber == 99)
        #expect(core.apply(Self.set(3, Double(Self.otherPhaseC(core)))) == .accepted)
        #expect(core.apply(ExperienceAction(control: "level.next", step: 0)) == .accepted)
        #expect(core.levelNumber == 100 && core.play.records.isEmpty && core.play.stage == .playing)
        #expect(core.apply(ExperienceAction(control: "level.next", step: 0)) == .accepted)
        #expect(core.levelNumber == 1 && core.play.stage == .playing)
        let first: Core = try await Core.prepare(seed: 0)
        #expect(core == first)
        core.reset()
        let fresh: Core = try await Core.prepare(seed: 98)
        let resetDigest: StateDigest = try Self.digest(core)
        let freshDigest: StateDigest = try Self.digest(fresh)
        #expect(core == fresh && resetDigest == freshDigest)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        // Level 32 starts at frequencies 1 and 9, phases 14 and 4.
        var core: Core = try await Core.prepare(seed: 31)
        #expect(core.apply(Self.set(2, 5)) == .accepted)
        #expect(core.apply(Self.set(3, 9)) == .accepted)
        #expect(core.apply(ExperienceAction(control: "play.undo", step: 0)) == .accepted)
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
        #expect(redone.apply(ExperienceAction(control: "play.redo", step: 0)) == .accepted)
        #expect(original.apply(ExperienceAction(control: "play.redo", step: 0)) == .accepted)
        #expect(redone == original)
        let other: Core = try Core.restore(payload: payload, seed: 5)
        #expect(other == core && other.openingNumber == 6)

        #expect(throws: LissajousLabyrinthRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 31)
        }
        #expect(throws: LissajousLabyrinthRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 31)
        }
        #expect(throws: LissajousLabyrinthRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: LissajousLabyrinthRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 31)
        }
        // The same records on another level: the first record's previous fingerprint is stale there.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":33").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: LissajousLabyrinthRestoreRefusal.kernel(.stale)) {
            try Core.restore(payload: wrongLevel, seed: 31)
        }
        // An edited value: the replayed record differs from the stored one.
        let edited: Data = Data(text.replacingOccurrences(of: "\"value\":5", with: "\"value\":6").utf8)
        #expect(edited != payload)
        #expect(throws: LissajousLabyrinthRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: edited, seed: 31)
        }
    }

    @Test func theTierAndTheSnapshotTimeNeverTouchTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: 44)
        #expect(core.apply(Self.set(3, Double(Self.otherPhaseC(core)))) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let drawn: [Int] = [4_096, 4_096, 2_048, 1_024, 1_024]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.samples == drawn[index])
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: LissajousLabyrinthSceneSnapshot = core.snapshot(time: time)
            #expect(snapshot.dials == core.play.dials && snapshot.stage == core.play.stage)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }
}
