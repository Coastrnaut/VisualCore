// HueCompassExperienceCoreTests — feature 333 (R02-G04-03) T-R02G0403-005 (FR-R02G0403-003, 005; SC-R02G0403-002, 004;
// clarifications Q4, Q5). The adapter core: the shared conformance checks pass; the seed picks level `seed % 100 + 1`
// deterministically in stage `playing`; every control is accepted when legal and refused with the state unchanged
// otherwise (the engine's range checks, `r02-g04.not-whole`, the kernel's `r02-g04.action` and `r02-g04.stage`); undo
// restores the earlier digest exactly and redo the later one; a probe adds the kernel's clue; a selection of the target
// wins and a miss fails; `level.next` wraps 100 to 1 and reset returns; the snapshot round trip and refused payloads
// (damaged, level out of range, a stale trace, an edited record, a record of a newer schema, an envelope of a newer
// schema); the quality tier and the presenter's snapshot time never touch the digest. Feature 335 (R02-G04-05)
// T-R02G0405-004: the progression actions (`level.select`, `mode.daily`, `mode.practice`, `mode.campaign`,
// `tutorial.dismiss`) and their refusals (`r02-g04.locked`, `r02-g04.date`), a win's record (campaign opens the next
// level, daily records without opening, practice records nothing), `level.next` to the next open level only, the
// tutorial on levels 1 … 3 in every mode, the hint and failure-explanation accessors, the schema-1 → 2 migration and
// undo restoring the digest with the tutorial advanced. Explicit types, plain loops, short runs.
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
        // Levels 1 (tutorial) and 100; level.next is refused on both (only the seed's levels are open), the mode and
        // tutorial actions start fresh plays. Turns never end a play; one probe spends one of at least two units; the
        // selection ends the play last.
        let actions: [ScriptedAction] = [ScriptedAction("compass.turn", [5]),
                                         ScriptedAction("compass.probe"),
                                         ScriptedAction("compass.turn", [-3]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("play.undo"), ScriptedAction("level.next"),
                                         ScriptedAction("tutorial.dismiss"), ScriptedAction("mode.practice"),
                                         ScriptedAction("compass.turn", [7]), ScriptedAction("mode.campaign"),
                                         ScriptedAction("mode.daily", [2026, 1, 2]), ScriptedAction("level.select", [1]),
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
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus"),
                                          ScriptedAction("level.select", [101]),
                                          ScriptedAction("level.select", [0.5]),
                                          ScriptedAction("mode.daily", [2026, 2, 30]),
                                          ScriptedAction("mode.daily", [2026, 1]),
                                          ScriptedAction("mode.practice", [1]),
                                          ScriptedAction("mode.campaign", [1]),
                                          ScriptedAction("tutorial.dismiss", [1])]
        let plan = ConformancePlan(seeds: [0, 99], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g04.hue-compass" && Core.schemaVersion == 3)
        #expect(Core.digestDomain == "r02-g04.hue-compass.v3")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        #expect(Core.actionIDs == ["compass.turn", "compass.probe", "compass.select", "play.undo", "play.redo",
                                   "level.next", "level.select", "mode.daily", "mode.practice", "mode.campaign",
                                   "tutorial.dismiss", "replay.start", "replay.step", "replay.stop"])
        #expect(Core.controls[0].ranges == [-48...48])
        #expect(Core.controls[2].ranges == [0...95, 0...23])
        #expect(Core.controls[6].ranges == [1...100])
        #expect(Core.controls[7].ranges == [1...9999, 1...12, 1...31])
        #expect(Core.practiceAllowance == 24 && Core.practiceAllowance == HueCompassLevel.allowances.upperBound)
        #expect(Core.controls[11].ranges == [1...100])
        let plainIndices: [Int] = [1, 3, 4, 5, 8, 9, 10, 12, 13]
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

    @Test func nextLevelMovesToTheNextOpenLevelAndResetReturnsToTheSeedsLevel() async throws {
        // Seed 98 opens levels 1 … 99: level.next moves 99 to 100 and is then refused (100 does not wrap).
        var core: Core = try await Core.prepare(seed: 98)
        #expect(core.levelNumber == 99 && core.progress.frontier == 99 && core.mode == .campaign)
        #expect(core.apply(Self.turn(3)) == .accepted)
        let before: Core = core
        #expect(core.apply(Self.plain("level.next")) == .rejected(.rule(code: HueCompassExperienceRule.locked)))
        #expect(core == before)
        // Seed 99 opens levels 1 … 100; level.select picks an open level, level.next then moves on.
        var all: Core = try await Core.prepare(seed: 99)
        #expect(all.levelNumber == 100 && all.progress.frontier == 100)
        #expect(all.apply(Self.plain("level.next")) == .rejected(.rule(code: HueCompassExperienceRule.locked)))
        #expect(all.apply(Self.act("level.select", [99])) == .accepted)
        #expect(all.levelNumber == 99 && all.play.records.isEmpty && all.play.stage == .playing)
        #expect(all.apply(Self.plain("level.next")) == .accepted)
        #expect(all.levelNumber == 100 && all.play.records.isEmpty && all.mode == .campaign)
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
        #expect(text.hasPrefix("{\"level\":32,\"mode\":{\"mode\":\"campaign\"},\"progress\":"))
        #expect(text.contains("\"records\":[") && text.contains("\"tutorial\":\"done\""))
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
            try Core.restore(payload: Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":\"32\"").utf8),
                             seed: 31)
        }
        // A schema-1 payload reaches restore only through the migration chain.
        #expect(throws: HueCompassRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":32,\"records\":[]}".utf8), seed: 31)
        }
        // A daily mode naming another level than the saved one.
        let otherDaily: String = "{\"level\":7,\"mode\":\"daily\"}"
        #expect(throws: HueCompassRestoreRefusal.damaged) {
            try Core.restore(payload: Data(text.replacingOccurrences(of: "{\"mode\":\"campaign\"}", with: otherDaily).utf8),
                             seed: 31)
        }
        #expect(throws: HueCompassRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":0").utf8),
                             seed: 31)
        }
        #expect(throws: HueCompassRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":101").utf8),
                             seed: 31)
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
        #expect(Core.migrations.currentVersion == 3)
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 5)
        try engine.activate()
        #expect(engine.handle(control: "compass.turn", values: [4]) == .accepted)
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

    // MARK: Feature 335

    /// The action `control` with `values`.
    static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    /// The adapter action of a kernel action.
    static func action(_ kernel: HueCompassAction) -> ExperienceAction {
        switch kernel {
        case .turn(let steps): turn(Double(steps))
        case .probe: plain("compass.probe")
        case .select(let bearing, let band): select(Double(bearing), Double(band))
        }
    }

    /// Plays the certified witness actions of manifest number `number` on `core`; every one is accepted.
    static func win(_ core: inout Core, number: Int) throws {
        let generated: HueCompassGenerated = try Core.generated(number: number)
        let actions: [HueCompassAction] = HueCompassWitness.actions(for: generated.solution, level: generated.level)
        for kernel in actions { #expect(core.apply(action(kernel)) == .accepted) }
        #expect(core.play.stage == .won)
    }

    @Test func selectAndModesFollowTheProgress() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.mode == .campaign && core.progress.frontier == 1 && core.progress.solved.isEmpty)
        let opening: Core = core
        let openingDigest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("level.select", [2])) == .rejected(.rule(code: HueCompassExperienceRule.locked)))
        #expect(core.apply(Self.plain("level.next")) == .rejected(.rule(code: HueCompassExperienceRule.locked)))
        #expect(core.apply(Self.act("mode.daily", [2026, 2, 30])) == .rejected(.rule(code: HueCompassExperienceRule.date)))
        #expect(core.apply(Self.act("mode.daily", [2025, 2, 29])) == .rejected(.rule(code: HueCompassExperienceRule.date)))
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 1.5]))
                    == .rejected(.rule(code: HueCompassExperienceRule.notWhole)))
        #expect(core.apply(Self.act("level.select", [1.5])) == .rejected(.rule(code: HueCompassExperienceRule.notWhole)))
        #expect(core.apply(Self.act("level.select", [101])) == .rejected(.outOfRange(index: 0)))
        #expect(core.apply(Self.act("mode.practice", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(try Self.digest(core) == openingDigest && core == opening)
        // The certified actions of level 1 win: the units spent and stars are recorded and level 2 opens.
        try Self.win(&core, number: 1)
        let smallest: Int = try Core.generated(number: 1).solution.smallest
        let result: HueCompassProgress.Result = try #require(core.progress.solved[1])
        #expect(result.bestUnits == core.play.spent && core.certifiedSmallest == smallest)
        #expect(result.stars == HueCompassProgress.stars(units: core.play.spent, smallest: smallest))
        #expect(core.progress.frontier == 2 && core.tutorial == .done)
        #expect(try Self.digest(core) != openingDigest)
        #expect(core.apply(Self.act("level.select", [2])) == .accepted)
        #expect(core.levelNumber == 2 && core.mode == .campaign && core.play.records.isEmpty)
        let levelTwo: HueCompassLevel = try Core.level(number: 2)
        #expect(core.tutorial == .aim && core.play.level == levelTwo)
        // Practice: the same level, fresh, with the allowance raised to 24; the records of the level left are dropped;
        // a practice win records nothing; the tutorial shows on levels 1 … 3 in every mode.
        #expect(core.apply(Self.turn(5)) == .accepted)
        #expect(core.apply(Self.plain("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == 2 && core.play.records.isEmpty)
        #expect(core.play.level.allowance == Core.practiceAllowance && core.play.remaining == 24)
        #expect(core.tutorial == .aim)
        let before: HueCompassProgress = core.progress
        try Self.win(&core, number: 2)
        #expect(core.progress == before)
        // Campaign: a fresh campaign play of the same level.
        #expect(core.apply(Self.plain("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 2 && core.play.records.isEmpty)
        #expect(core.play.level == levelTwo)
        // Daily: 2026-01-02 gives level 48, locked in the campaign yet playable; a win records it without opening it.
        let daily: Int = try #require(HueCompassProgress.dailyLevel(year: 2026, month: 1, day: 2))
        #expect(daily == 48 && !core.progress.isOpen(daily))
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 2])) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily && core.tutorial == .done)
        let dailyLevel: HueCompassLevel = try Core.level(number: daily)
        #expect(core.play.level == dailyLevel)
        try Self.win(&core, number: daily)
        #expect(core.progress.solved[daily] != nil && core.progress.frontier == 2 && !core.progress.isOpen(daily))
        // Back to campaign: the daily level is not open, so the frontier.
        #expect(core.apply(Self.plain("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 2)
        // The daily level of 2026-01-01 is level 1, a tutorial level: the tutorial shows in daily mode too.
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 1])) == .accepted)
        #expect(core.levelNumber == 1 && core.mode == .daily(level: 1) && core.tutorial == .aim)
        // Reset returns to the opening state, progress included.
        core.reset()
        #expect(try Self.digest(core) == openingDigest && core == opening)
    }

    @Test func theTutorialAdvancesAndUndoRestoresTheDigestWithIt() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.tutorial == .aim && core.tutorial == HueCompassTutorialStep.initial(level: 1))
        let startDigest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.turn(9)) == .accepted)
        #expect(core.tutorial == .probe)
        #expect(core.apply(Self.plain("play.undo")) == .accepted)
        // The digest returns; the tutorial does not move back.
        #expect(try Self.digest(core) == startDigest && core.tutorial == .probe)
        #expect(core.apply(Self.plain("play.redo")) == .accepted)
        #expect(core.tutorial == .probe)
        #expect(core.apply(Self.plain("compass.probe")) == .accepted)
        #expect(core.tutorial == .select)
        // Dismissing ends it; the tutorial step is never digested.
        let digest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.plain("tutorial.dismiss")) == .accepted)
        #expect(try Self.digest(core) == digest && core.tutorial == .done)
        // Every opening starts the tutorial again on levels 1 … 3; level 4 has none.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        #expect(core.tutorial == .aim)
        let later: Core = try await Core.prepare(seed: 3)
        #expect(later.tutorial == .done)
        // The end of the level ends the tutorial.
        var ended: Core = try await Core.prepare(seed: 2)
        #expect(ended.tutorial == .aim)
        try Self.win(&ended, number: 3)
        #expect(ended.tutorial == .done)
    }

    @Test func theHintAndTheFailureExplanationReadThePlay() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let level: HueCompassLevel = core.play.level
        let before: Core = core
        for hintLevel in 1...3 {
            let hint: HueCompassHint = try #require(core.hint(level: hintLevel))
            #expect(hint == HueCompassHints.hint(level: hintLevel, play: core.play))
        }
        #expect(core.failureExplanation == nil && core == before)
        let (bearing, band): (Int, Int) = Self.miss(level)
        #expect(core.apply(Self.select(Double(bearing), Double(band))) == .accepted)
        #expect(core.play.stage == .failed && core.hint(level: 1) == nil)
        let explanation: HueCompassFailureExplanation = try #require(core.failureExplanation)
        #expect(explanation == HueCompassFailureExplanation(play: core.play) && explanation.failure == .selection)
        #expect(core.progress.solved.isEmpty && core.progress.frontier == 1)
        // Retry: a fresh campaign play of the same level.
        #expect(core.apply(Self.plain("mode.campaign")) == .accepted)
        #expect(core.play == before.play && core.failureExplanation == nil)
    }

    @Test func aSchemaOnePayloadMigrates() async throws {
        let seeds: [UInt64] = [31, 0]
        for seed in seeds {
            var core: Core = try await Core.prepare(seed: seed)
            #expect(core.apply(Self.turn(9)) == .accepted)
            let object: [String: Any] = try #require(
                try JSONSerialization.jsonObject(with: try core.snapshotPayload()) as? [String: Any])
            let schemaOne: [String: Any] = ["level": try #require(object["level"]),
                                            "records": try #require(object["records"])]
            let migrated: [String: Any] = try Core.migrations.migrate(schemaOne, from: 1)
            #expect(migrated["tutorial"] == nil)
            let payload: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
            let restored: Core = try Core.restore(payload: payload, seed: seed)
            let number: Int = Core.levelNumber(forSeed: seed)
            #expect(restored.levelNumber == number && restored.mode == .campaign)
            #expect(restored.progress.frontier == number && restored.progress.solved.isEmpty)
            #expect(restored.play == core.play && restored.tutorial == HueCompassTutorialStep.initial(level: number))
            #expect(try Self.digest(restored) == Self.digest(core))
        }
        #expect(throws: HueCompassRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": "x"]) }
        #expect(throws: HueCompassRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": 3]) }
    }

    @Test func aPracticeOrDailySnapshotRoundTrips() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        try Self.win(&core, number: 1)
        #expect(core.apply(Self.plain("mode.practice")) == .accepted)
        #expect(core.apply(Self.turn(4)) == .accepted)
        #expect(core.apply(Self.plain("compass.probe")) == .accepted)
        let practice: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(practice == core && practice.play.level.allowance == Core.practiceAllowance)
        #expect(try Self.digest(practice) == Self.digest(core))
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 2])) == .accepted)
        #expect(core.apply(Self.turn(-6)) == .accepted)
        let daily: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(daily == core && daily.mode == .daily(level: 48))
        #expect(try Self.digest(daily) == Self.digest(core))
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

    // MARK: Feature 337 (R02-G04-07) T-R02G0407-003

    @Test func aCampaignWinRecordsItsTraceAndReplayReproducesIt() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let noReplay: ActionResult = .rejected(.rule(code: HueCompassExperienceRule.noReplay))
        #expect(core.apply(Self.act("replay.start", [1])) == noReplay)
        #expect(core.apply(Self.plain("replay.step")) == noReplay)
        #expect(core.apply(Self.plain("replay.stop")) == noReplay)
        // A detour (a turn and its undo, then a turn, its undo and its redo and the turn back) leaves the net actions:
        // the turns and the certified witness actions.
        #expect(core.apply(Self.turn(5)) == .accepted)
        #expect(core.apply(Self.plain("play.undo")) == .accepted)
        #expect(core.apply(Self.turn(3)) == .accepted)
        #expect(core.apply(Self.plain("play.undo")) == .accepted)
        #expect(core.apply(Self.plain("play.redo")) == .accepted)
        #expect(core.apply(Self.turn(-3)) == .accepted)
        let generated: HueCompassGenerated = try Core.generated(number: 1)
        let witness: [HueCompassAction] = HueCompassWitness.actions(for: generated.solution, level: generated.level)
        for kernel in witness { #expect(core.apply(Self.action(kernel)) == .accepted) }
        #expect(core.play.stage == .won)
        let result: HueCompassProgress.Result = try #require(core.progress.solved[1])
        let trace: [HueCompassAction] = [.turn(3), .turn(-3)] + witness
        #expect(result.trace == trace && result.verified && result.bestUnits == core.play.spent)
        #expect(Core.netActions(core.play.records) == trace)
        let progress: HueCompassProgress = core.progress
        // Replay: a fresh play, the tutorial done, the trace action by action, then the end.
        #expect(core.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(core.mode == .replay(level: 1) && core.tutorial == .done && core.play.records.isEmpty)
        #expect(core.apply(Self.plain("tutorial.dismiss")) == .accepted)
        let refused: [ExperienceAction] = [Self.turn(1), Self.plain("compass.probe"), Self.select(0, 0),
                                           Self.plain("play.undo"), Self.plain("play.redo"), Self.plain("level.next"),
                                           Self.act("level.select", [1]), Self.plain("mode.practice"),
                                           Self.plain("mode.campaign"), Self.act("mode.daily", [2026, 11, 21])]
        for action in refused {
            #expect(core.apply(action) == .rejected(.rule(code: HueCompassExperienceRule.replay)), "\(action)")
        }
        var fresh: HueCompassPlay = try Core.freshPlay(of: try Core.level(number: 1))
        for kernel in trace {
            #expect(core.apply(Self.plain("replay.step")) == .accepted)
            try fresh.apply(kernel, expecting: fresh.fingerprint)
            #expect(core.play.fingerprint == fresh.fingerprint)
        }
        #expect(core.play.stage == .won && core.progress == progress, "replay never records")
        #expect(core.apply(Self.plain("replay.step")) == .rejected(.rule(code: HueCompassExperienceRule.replayEnd)))
        // The replay round-trips through the snapshot.
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && restored.reconciliationDropped == 0)
        #expect(core.apply(Self.plain("replay.stop")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.progress == progress)
    }

    @Test func restoreReconcilesAndDropsAnEditedResult() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        try Self.win(&core, number: 1)
        let stars: Int = try #require(core.progress.solved[1]).stars
        let text: String = try #require(String(data: try core.snapshotPayload(), encoding: .utf8))
        #expect(text.contains("\"verified\":true"))
        let honest: Core = try Core.restore(payload: Data(text.utf8), seed: 0)
        #expect(honest.reconciliationDropped == 0 && honest.progress == core.progress)
        // Other stars claimed for the win: the replay disagrees, the result is dropped, the frontier stays.
        let claimed: Int = stars == 3 ? 2 : 3
        let edited: String = text.replacingOccurrences(of: "\"stars\":\(stars)", with: "\"stars\":\(claimed)")
        #expect(edited != text)
        let checked: Core = try Core.restore(payload: Data(edited.utf8), seed: 0)
        #expect(checked.reconciliationDropped == 1 && checked.progress.solved[1] == nil)
        #expect(checked.progress.frontier == core.progress.frontier)
        // A replay of a dropped result restores in campaign.
        var replaying: Core = core
        #expect(replaying.apply(Self.act("replay.start", [1])) == .accepted)
        let replayText: String = try #require(String(data: try replaying.snapshotPayload(), encoding: .utf8))
        let replayEdited: String = replayText.replacingOccurrences(of: "\"stars\":\(stars)",
                                                                   with: "\"stars\":\(claimed)")
        let back: Core = try Core.restore(payload: Data(replayEdited.utf8), seed: 0)
        #expect(back.mode == .campaign && back.reconciliationDropped == 1)
    }

    @Test func aSchemaTwoPayloadMigratesToThree() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        try Self.win(&core, number: 1)
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: try core.snapshotPayload()) as? [String: Any])
        // The schema-2 form: results without trace or verified.
        var progress: [String: Any] = try #require(object["progress"] as? [String: Any])
        let solved: [Any] = try #require(progress["solved"] as? [Any])
        var plain: [Any] = []
        for entry in solved {
            var result: [String: Any] = try #require(entry as? [String: Any])
            result.removeValue(forKey: "trace")
            result.removeValue(forKey: "verified")
            plain.append(result)
        }
        progress["solved"] = plain
        object["progress"] = progress
        let migrated: [String: Any] = try Core.migratedToSchemaThree(object)
        let payload: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
        let restored: Core = try Core.restore(payload: payload, seed: 0)
        let result: HueCompassProgress.Result = try #require(restored.progress.solved[1])
        let stars: Int = try #require(core.progress.solved[1]).stars
        #expect(!result.verified && result.trace.isEmpty && result.stars == stars)
        #expect(restored.reconciliationDropped == 0 && restored.progress.frontier == core.progress.frontier)
        #expect(throws: HueCompassRestoreRefusal.damaged) { try Core.migratedToSchemaThree(["level": 1]) }
        // An unverified result cannot be replayed.
        var replay: Core = restored
        #expect(replay.apply(Self.act("replay.start", [1])) == .rejected(.rule(code: HueCompassExperienceRule.noReplay)))
    }
}
