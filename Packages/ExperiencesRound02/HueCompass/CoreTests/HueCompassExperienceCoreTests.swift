// HueCompassExperienceCoreTests — feature 333 (R02-G04-03) T-R02G0403-005 (FR-R02G0403-003, 005; SC-R02G0403-002, 004;
// clarifications Q4, Q5). The adapter core: the shared conformance checks pass; the seed picks level `seed % 100 + 1`
// deterministically in stage `playing`; every control is accepted when legal and refused with the state unchanged
// otherwise (the engine's range checks, `r02-g04.not-whole`, the kernel's `r02-g04.action` and `r02-g04.stage`); undo
// restores the earlier digest exactly and redo the later one; a probe adds the kernel's clue; a selection of the target
// wins and a miss fails; `level.next` wraps 100 to 1 and reset returns; the snapshot round trip and refused payloads
// (damaged, level out of range, a stale trace, an edited record, a record of a newer schema, an envelope of a newer
// schema); the quality tier and the presenter's snapshot time never touch the digest. Explicit types, plain loops,
// short runs.
import Foundation
import Testing
@testable import HueCompassCore
import VisualCoreDiagnostics
import VisualCoreExperience

@Suite struct HueCompassExperienceCoreTests {
    typealias Core = HueCompassExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The `compass.turn` action with the given steps.
    static func turn(_ steps: Double) -> ExperienceAction {
        ExperienceAction(control: "compass.turn", values: [steps], step: 0)
    }

    /// The `compass.select` action with the given bearing and band.
    static func select(_ bearing: Double, _ band: Double) -> ExperienceAction {
        ExperienceAction(control: "compass.select", values: [bearing, band], step: 0)
    }

    /// A control with no values.
    static func plain(_ control: String) -> ExperienceAction {
        ExperienceAction(control: control, step: 0)
    }

    /// A bearing and band the level refuses: the bearing opposite the target with the target's band.
    static func miss(_ level: HueCompassLevel) -> (Int, Int) {
        ((level.target + 48) % 96, level.targetBand)
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 (tutorial) and 100, then 2 and 1 after level.next. Turns never end a play; one probe spends one of
        // at least two units; the selection ends the play last.
        let actions: [ScriptedAction] = [ScriptedAction("compass.turn", [5]),
                                         ScriptedAction("compass.probe"),
                                         ScriptedAction("compass.turn", [-3]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("play.undo"), ScriptedAction("level.next"),
                                         ScriptedAction("compass.turn", [48]),
                                         ScriptedAction("compass.probe"),
                                         ScriptedAction("compass.select", [0, 0])]
        let rejected: [ScriptedAction] = [ScriptedAction("compass.turn", [0]),
                                          ScriptedAction("compass.turn", [0.5]),
                                          ScriptedAction("compass.turn", [49]),
                                          ScriptedAction("compass.turn", [-49]),
                                          ScriptedAction("compass.turn", []),
                                          ScriptedAction("compass.probe", [1]),
                                          ScriptedAction("compass.select", [96, 0]),
                                          ScriptedAction("compass.select", [0, 24]),
                                          ScriptedAction("compass.select", [1.5, 0]),
                                          ScriptedAction("compass.select", [0]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 99], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g04.hue-compass" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g04.hue-compass.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        #expect(Core.actionIDs == ["compass.turn", "compass.probe", "compass.select", "play.undo", "play.redo",
                                   "level.next"])
        #expect(Core.controls[0].ranges == [-48...48])
        #expect(Core.controls[2].ranges == [0...95, 0...23])
        let plainIndices: [Int] = [1, 3, 4, 5]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 8.0 / 12.0, 4.0 / 12.0] && iterations == [1, 2.0 / 3.0, 1.0 / 3.0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
    }

    @Test func theSeedPicksTheLevelDeterministically() async throws {
        let seeds: [UInt64] = [0, 2, 100, 257]
        let numbers: [Int] = [1, 3, 1, 58]
        for index in seeds.indices {
            #expect(Core.levelNumber(forSeed: seeds[index]) == numbers[index])
            let first: Core = try await Core.prepare(seed: seeds[index])
            let second: Core = try await Core.prepare(seed: seeds[index])
            #expect(first.levelNumber == numbers[index] && first.openingNumber == numbers[index])
            #expect(first == second)
            #expect(try Self.digest(first) == Self.digest(second))
            let expected: HueCompassLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.bearing == expected.start)
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
        }
        #expect(Core.levelNumber(forSeed: 99) == 100)
        // The cache hands back the generator's own level.
        let fresh: HueCompassLevel = try HueCompassGenerator.generate(HueCompassManifest.entries[0]).level
        #expect(try Core.level(number: 1) == fresh)
        #expect(throws: HueCompassError.level("number")) { try Core.level(number: 0) }
        #expect(throws: HueCompassError.level("number")) { try Core.level(number: 101) }
    }

    @Test func aTurnChangesTheDigestAndRefusedActionsChangeNothing() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let illegal: [ExperienceAction] = [Self.turn(0), Self.turn(0.5), Self.turn(49), Self.turn(-49), Self.turn(.nan),
                                           ExperienceAction(control: "compass.turn", values: [1, 1], step: 0),
                                           ExperienceAction(control: "compass.probe", values: [0], step: 0),
                                           Self.select(96, 0), Self.select(-1, 0), Self.select(0, 24),
                                           Self.select(0, -1), Self.select(2.5, 0), Self.select(0, 0.5),
                                           ExperienceAction(control: "compass.select", values: [0], step: 0),
                                           Self.plain("play.undo"), Self.plain("play.redo"),
                                           ExperienceAction(control: "level.next", values: [1], step: 0),
                                           Self.plain("nope")]
        for action in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(action)
            #expect(!result.isAccepted, "\(action.control) \(action.values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.isEmpty, "\(action.control)")
        }
        var probe: Core = core
        // The kernel's refusals pass through with their reason codes.
        #expect(probe.apply(Self.turn(0)) == .rejected(.rule(code: "r02-g04.action")))
        #expect(probe.apply(Self.plain("play.undo")) == .rejected(.rule(code: "r02-g04.action")))
        #expect(probe.apply(Self.plain("play.redo")) == .rejected(.rule(code: "r02-g04.action")))
        // Outside the declared ranges: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.turn(49)) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.select(0, 24)) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.turn(1.5)) == .rejected(.rule(code: HueCompassExperienceRule.notWhole)))
        #expect(probe.apply(Self.select(3, 0.25)) == .rejected(.rule(code: HueCompassExperienceRule.notWhole)))
        #expect(probe.apply(Self.plain("nope")) == .rejected(.unknownControl("nope")))
        #expect(probe == core)
        let start: Int = core.play.bearing
        #expect(core.apply(Self.turn(-48)) == .accepted)
        #expect(core.play.bearing == (start + 48) % 96 && core.play.records.count == 1 && core.play.spent == 0)
        #expect(core.play.stage == .playing)
        #expect(try Self.digest(core) != opening)
        #expect(core.apply(Self.turn(48)) == .accepted)
        #expect(core.play.bearing == start)
    }

    @Test func aProbeAddsTheKernelsClueAndTheLastUnitFails() async throws {
        var core: Core = try await Core.prepare(seed: 7)
        let level: HueCompassLevel = core.play.level
        let opening: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.turn(13)) == .accepted)
        #expect(core.apply(Self.plain("compass.probe")) == .accepted)
        #expect(core.play.spent == 1 && core.play.clues == [level.clue(at: core.play.bearing)])
        #expect(try Self.digest(core) != opening)
        // A probe clears the turn history: the turn before it cannot be undone.
        #expect(core.apply(Self.plain("play.undo")) == .rejected(.rule(code: "r02-g04.action")))
        while core.play.remaining > 1 {
            #expect(core.apply(Self.turn(1)) == .accepted)
            #expect(core.apply(Self.plain("compass.probe")) == .accepted)
            #expect(core.play.stage == .playing && core.outcome == nil)
        }
        #expect(core.apply(Self.plain("compass.probe")) == .accepted)
        #expect(core.play.stage == .failed && core.play.failure == .probes)
        #expect(core.outcome?.code == Core.failedCode)
        #expect(core.snapshot(time: 0).target == level.target)
        let failed: Core = core
        let codes: [ExperienceAction] = [Self.turn(1), Self.plain("compass.probe"), Self.select(0, 0),
                                         Self.plain("play.undo"), Self.plain("play.redo")]
        for action in codes {
            #expect(core.apply(action) == .rejected(.rule(code: "r02-g04.stage")), "\(action.control)")
        }
        #expect(core == failed)
    }

    @Test func aSelectionOfTheTargetWinsAndAMissFails() async throws {
        let seeds: [UInt64] = [0, 41]
        for seed in seeds {
            var core: Core = try await Core.prepare(seed: seed)
            let level: HueCompassLevel = core.play.level
            #expect(core.snapshot(time: 0).target == nil)
            var miss: Core = core
            let (bearing, band): (Int, Int) = Self.miss(level)
            #expect(!level.accepts(bearing: bearing, band: band))
            #expect(miss.apply(Self.select(Double(bearing), Double(band))) == .accepted)
            #expect(miss.play.stage == .failed && miss.play.failure == .selection, "seed \(seed)")
            #expect(miss.outcome?.code == Core.failedCode && miss.snapshot(time: 0).target == level.target)
            #expect(miss.snapshot(time: 0).selection == HueCompassSelection(bearing: bearing, band: band))
            #expect(core.apply(Self.select(Double(level.target), Double(level.targetBand))) == .accepted)
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "seed \(seed)")
            #expect(core.snapshot(time: 0).target == level.target)
            let won: Core = core
            #expect(core.apply(Self.plain("play.undo")) == .rejected(.rule(code: "r02-g04.stage")))
            #expect(core.apply(Self.plain("level.next")) == .accepted)
            #expect(core.play.stage == .playing && core.levelNumber == won.levelNumber + 1)
            core.reset()
            #expect(core.play.stage == .playing && core.outcome == nil && core.play.records.isEmpty)
            #expect(core.levelNumber == won.levelNumber)
        }
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 12)
        let start: Int = core.play.bearing
        let startDigest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.turn(17)) == .accepted)
        let moved: Int = core.play.bearing
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest)
        #expect(core.apply(Self.plain("play.undo")) == .accepted)
        #expect(core.play.bearing == start)
        #expect(try Self.digest(core) == startDigest)
        #expect(core.apply(Self.plain("play.redo")) == .accepted)
        #expect(core.play.bearing == moved && core.play.records.count == 3)
        #expect(try Self.digest(core) == movedDigest)
        #expect(core.apply(Self.plain("play.redo")) == .rejected(.rule(code: "r02-g04.action")))
        // A new turn clears the redo history.
        #expect(core.apply(Self.plain("play.undo")) == .accepted)
        #expect(core.apply(Self.turn(-5)) == .accepted)
        #expect(core.apply(Self.plain("play.redo")) == .rejected(.rule(code: "r02-g04.action")))
        #expect(core.apply(Self.plain("play.undo")) == .accepted)
        #expect(try Self.digest(core) == startDigest)
    }

    @Test func nextLevelWrapsAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 98)
        #expect(core.levelNumber == 99)
        #expect(core.apply(Self.turn(3)) == .accepted)
        #expect(core.apply(Self.plain("level.next")) == .accepted)
        #expect(core.levelNumber == 100 && core.play.records.isEmpty && core.play.stage == .playing)
        #expect(core.apply(Self.plain("level.next")) == .accepted)
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
        #expect(core.apply(Self.turn(9)) == .accepted)
        #expect(core.apply(Self.plain("compass.probe")) == .accepted)
        #expect(core.apply(Self.turn(-20)) == .accepted)
        #expect(core.apply(Self.plain("play.undo")) == .accepted)
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
        #expect(redone.apply(Self.plain("play.redo")) == .accepted)
        #expect(original.apply(Self.plain("play.redo")) == .accepted)
        #expect(redone == original)
        let other: Core = try Core.restore(payload: payload, seed: 0)
        #expect(other == core && other.openingNumber == 1)

        #expect(throws: HueCompassRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 31)
        }
        #expect(throws: HueCompassRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 31)
        }
        #expect(throws: HueCompassRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"32\",\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: HueCompassRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: HueCompassRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 31)
        }
        // The same records on another level: the first record's previous fingerprint is stale there.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":1").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: HueCompassRestoreRefusal.kernel(.stale)) {
            try Core.restore(payload: wrongLevel, seed: 31)
        }
        // A record of a newer schema: the replayed record (schema 1) differs from the stored one.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: HueCompassRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: newer, seed: 31)
        }
        // An edited tick: the replayed record differs from the stored one.
        let edited: Data = Data(text.replacingOccurrences(of: "\"tick\":0", with: "\"tick\":7").utf8)
        #expect(edited != payload)
        #expect(throws: HueCompassRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: edited, seed: 31)
        }
        #expect(Core.migrations.currentVersion == 1)
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 5)
        try engine.activate()
        #expect(engine.handle(control: "compass.turn", values: [4]) == .accepted)
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
        var core: Core = try await Core.prepare(seed: 44)
        #expect(core.apply(Self.turn(-11)) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let facets: [Int] = [12, 12, 8, 4, 4]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.facets == facets[index])
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: HueCompassSceneSnapshot = core.snapshot(time: time)
            #expect(snapshot.bearing == core.play.bearing && snapshot.stage == core.play.stage)
            #expect(snapshot.levelNumber == core.levelNumber && snapshot.time.isFinite && snapshot.target == nil)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }
}
