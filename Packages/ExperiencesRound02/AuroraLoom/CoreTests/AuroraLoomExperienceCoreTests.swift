// AuroraLoomExperienceCoreTests — feature 303 (R02-G01-03) T-R02G0103-005 (FR-R02G0103-005; clarification Q5). The
// adapter core: the shared conformance checks pass; the seed picks level `seed % 100 + 1` deterministically in stage
// `playing`; a legal move changes the digest and an illegal one is refused with the state unchanged; undo, redo and
// the certified solution (outcome `won`); `level.next` wraps 100 to 1; the snapshot round trip and refused payloads;
// the quality tier and the presenter's snapshot time never touch the digest. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import AuroraLoomCore
import VisualCoreDiagnostics
import VisualCoreExperience

@Suite struct AuroraLoomExperienceCoreTests {
    typealias Core = AuroraLoomExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The `ribbon.move` action for a kernel move.
    static func action(_ move: AuroraLoomMove) -> ExperienceAction {
        let control: Double = move.control == .wave ? 0 : 1
        return ExperienceAction(control: "ribbon.move", values: [Double(move.ribbon), control, Double(move.step)],
                                step: 0)
    }

    /// A step for ribbon 0's wave that differs from the current one.
    static func otherWave(_ core: Core) -> Int {
        (core.play.steps.wave[0] + 1) % 16
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        let actions: [ScriptedAction] = [ScriptedAction("ribbon.move", [1, 1, 7]),
                                         ScriptedAction("ribbon.move", [2, 0, 3]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("play.undo"), ScriptedAction("level.next"),
                                         ScriptedAction("ribbon.move", [0, 0, 9])]
        let rejected: [ScriptedAction] = [ScriptedAction("ribbon.move", [0, 0, 0.5]),
                                          ScriptedAction("ribbon.move", [0.5, 1, 2]),
                                          ScriptedAction("ribbon.move", [3, 0, 1]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 41, 99, 1_000_003], stepsPerSegment: 2, actions: actions,
                                   rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g01.aurora-loom" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g01.aurora-loom.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        #expect(Core.controls[0].ranges == [0...2, 0...1, 0...15])
        for index in 1..<4 { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.stepDuration == 1.0 / 120)
        #expect(Core.qualityTiers == 3)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        #expect(elements == [1, 0.6, 0.2] && iterations == [1, 0.5, 0.25] && passes == [2, 1, 0])
    }

    @Test func theSeedPicksTheLevelDeterministically() async throws {
        let seeds: [UInt64] = [0, 2, 99, 100, 257]
        let numbers: [Int] = [1, 3, 100, 1, 58]
        for index in seeds.indices {
            let first: Core = try await Core.prepare(seed: seeds[index])
            let second: Core = try await Core.prepare(seed: seeds[index])
            #expect(first.levelNumber == numbers[index] && first.openingNumber == numbers[index])
            #expect(first == second)
            #expect(try Self.digest(first) == Self.digest(second))
            let expected: AuroraLoomLevel = try AuroraLoomGenerator.generate(
                AuroraLoomManifest.entries[numbers[index] - 1]).level
            #expect(first.play.level == expected)
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
        }
    }

    @Test func aLegalMoveChangesTheDigestAndIllegalOnesChangeNothing() async throws {
        var core: Core = try await Core.prepare(seed: 7)
        let opening: StateDigest = try Self.digest(core)
        let current: Int = core.play.steps.wave[0]
        let illegal: [[Double]] = [[0, 0, Double(current)], [0, 0, 1.5], [0, 0.25, 3], [3, 0, 1], [0, 2, 1],
                                   [0, 0, 16], [0, 0, -1], [0, 0, .nan], [0, 0], [0, 0, 1, 1]]
        for values in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(ExperienceAction(control: "ribbon.move", values: values, step: 0))
            #expect(!result.isAccepted, "\(values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening, "\(values)")
        }
        var noChange: Core = core
        #expect(noChange.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, Double(current)], step: 0))
            == .rejected(.rule(code: "r02-g01.move")))
        #expect(noChange.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, 1.5], step: 0))
            == .rejected(.rule(code: AuroraLoomExperienceRule.notWhole)))
        #expect(noChange.apply(ExperienceAction(control: "play.undo", step: 0))
            == .rejected(.rule(code: "r02-g01.move")))
        #expect(noChange.apply(ExperienceAction(control: "nope", step: 0)) == .rejected(.unknownControl("nope")))
        let step: Int = Self.otherWave(core)
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, Double(step)], step: 0))
            == .accepted)
        #expect(core.play.steps.wave[0] == step && core.play.records.count == 1)
        #expect(try Self.digest(core) != opening)
    }

    @Test func undoAndRedo() async throws {
        var core: Core = try await Core.prepare(seed: 12)
        let start: AuroraLoomSteps = core.play.steps
        let step: Int = (core.play.steps.phase[1] + 5) % 16
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [1, 1, Double(step)], step: 0))
            == .accepted)
        let moved: AuroraLoomSteps = core.play.steps
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(core.apply(ExperienceAction(control: "play.undo", step: 0)) == .accepted)
        #expect(core.play.steps == start && core.play.spent == 0)
        #expect(try Self.digest(core) != movedDigest)
        #expect(core.apply(ExperienceAction(control: "play.redo", step: 0)) == .accepted)
        #expect(core.play.steps == moved && core.play.spent == 1 && core.play.records.count == 3)
        #expect(core.apply(ExperienceAction(control: "play.redo", step: 0)) == .rejected(.rule(code: "r02-g01.move")))
    }

    @Test func theCertifiedSolutionWins() async throws {
        let seeds: [UInt64] = [0, 24, 63, 99]
        for seed in seeds {
            var core: Core = try await Core.prepare(seed: seed)
            let generated: AuroraLoomGenerated = try AuroraLoomGenerator.generate(
                AuroraLoomManifest.entries[core.levelNumber - 1])
            for move in generated.solution.moves {
                #expect(core.apply(Self.action(move)) == .accepted, "seed \(seed) \(move)")
            }
            #expect(core.play.stage == .won, "seed \(seed)")
            #expect(core.outcome?.code == "won", "seed \(seed)")
            let won: Core = core
            #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, 0], step: 0))
                == .rejected(.rule(code: "r02-g01.stage")))
            #expect(core == won)
            core.reset()
            #expect(core.play.stage == .playing && core.outcome == nil && core.play.records.isEmpty)
        }
    }

    @Test func nextLevelWrapsAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 98)
        #expect(core.levelNumber == 99)
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, Double(Self.otherWave(core))],
                                            step: 0)) == .accepted)
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
        var core: Core = try await Core.prepare(seed: 31)
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [2, 1, Double((core.play.steps.phase[2]
            + 3) % 16)], step: 0)) == .accepted)
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, Double(Self.otherWave(core))],
                                            step: 0)) == .accepted)
        #expect(core.apply(ExperienceAction(control: "play.undo", step: 0)) == .accepted)
        let payload: Data = try core.snapshotPayload()
        #expect(try core.snapshotPayload() == payload)
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

        #expect(throws: AuroraLoomRestoreRefusal.damaged) { try Core.restore(payload: Data("{}".utf8), seed: 31) }
        #expect(throws: AuroraLoomRestoreRefusal.damaged) { try Core.restore(payload: Data("nope".utf8), seed: 31) }
        #expect(throws: AuroraLoomRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: AuroraLoomRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 31)
        }
        let text: String = try #require(String(data: payload, encoding: .utf8))
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":33").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: AuroraLoomRestoreRefusal.self) { try Core.restore(payload: wrongLevel, seed: 31) }
    }

    @Test func theTierAndTheSnapshotTimeNeverTouchTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: 44)
        #expect(core.apply(ExperienceAction(control: "ribbon.move", values: [0, 0, Double(Self.otherWave(core))],
                                            step: 0)) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let drawn: [Int] = [5, 5, 3, 1, 1]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.layers == drawn[index])
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: AuroraLoomSceneSnapshot = core.snapshot(time: time)
            #expect(snapshot.steps == core.play.steps && snapshot.stage == core.play.stage)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest)
    }
}
