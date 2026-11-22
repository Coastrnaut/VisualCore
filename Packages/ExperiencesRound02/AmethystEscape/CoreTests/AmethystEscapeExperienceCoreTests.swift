// AmethystEscapeExperienceCoreTests — feature 363 (R02-G07-03) T-R02G0703-005 (FR-R02G0703-001 … 006; clarifications
// Q4, Q5). The adapter core: the shared conformance checks pass; the seed picks level `seed % 100 + 1` deterministically
// in stage `playing` (seeds 0, 1, 99 and 100 give levels 1, 2, 100 and 1); every control is accepted when legal and
// refused with the state unchanged otherwise (the engine's range checks, `r02-g07.not-whole`, the kernel's
// `r02-g07.action`, `r02-g07.stuck` and `r02-g07.stage`); undo restores the earlier digest exactly and redo the later
// one; the certified solution wins and the budget fails, undo returns a failed play to playing; `level.next` wraps 100 to
// 1 and reset returns; the snapshot round trip and refused payloads (damaged, level out of range, a trace of another
// level, an edited record, a record of a newer schema, an envelope of a newer schema); the quality tier and the
// presenter's snapshot time never touch the digest. Levels of bands 1 and 2 (1 … 40) keep the run short; only the
// preparation and wrap checks generate level 100. Explicit types, plain loops.
import Foundation
import Testing
@testable import AmethystEscapeCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

@Suite struct AmethystEscapeExperienceCoreTests {
    typealias Core = AmethystEscapeExperienceCore

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
    static func act(_ action: AmethystEscapeAction) -> ExperienceAction {
        switch action {
        case .rotate(let shell, let step): act("shell.rotate", [Double(shell), Double(step)])
        case .advance: act("pearl.advance")
        }
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 2 (and 2 and 3 for the restore engine): rotations, undo and redo, then level.next. Every level
        // has at least two shells and a budget of at least eight, and a rotation never ends a play below the budget.
        let actions: [ScriptedAction] = [ScriptedAction("shell.rotate", [0, 1]),
                                         ScriptedAction("shell.rotate", [1, -1]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("shell.rotate", [0, -1]),
                                         ScriptedAction("play.undo"), ScriptedAction("level.next"),
                                         ScriptedAction("shell.rotate", [1, 1]),
                                         ScriptedAction("shell.rotate", [0, 1])]
        let rejected: [ScriptedAction] = [ScriptedAction("shell.rotate", [5, 1]),
                                          ScriptedAction("shell.rotate", [-1, 1]),
                                          ScriptedAction("shell.rotate", [0, 2]),
                                          ScriptedAction("shell.rotate", [0, 0.5]),
                                          ScriptedAction("shell.rotate", [0, 0]),
                                          ScriptedAction("shell.rotate", [0]),
                                          ScriptedAction("pearl.advance", [1]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 1], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g07.amethyst-escape" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g07.amethyst-escape.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        #expect(Core.actionIDs == ["shell.rotate", "pearl.advance", "play.undo", "play.redo", "level.next"])
        #expect(Core.controls[0].ranges == [0...4, -1...1])
        let plainIndices: [Int] = [1, 2, 3, 4]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.migrations.currentVersion == 1)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == AmethystEscapeTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 2.0 / 3.0, 1.0 / 3.0] && iterations == [1, 2.0 / 3.0, 1.0 / 3.0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(AmethystEscapeExperienceRule.notWhole == "r02-g07.not-whole")
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
            let expected: AmethystEscapeLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.crystal == AmethystEscapeCrystal(level: expected))
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.play.moves == 0 && first.qualityTier == 0)
        }
        // The cache hands back the generator's own level.
        let entry: AmethystEscapeManifestEntry = AmethystEscapeManifest.entries[1]
        let fresh: AmethystEscapeLevel = try AmethystEscapeGenerator.generate(entry).level
        #expect(try Core.level(number: 2) == fresh)
        #expect(throws: AmethystEscapeError.level("number")) { try Core.level(number: 0) }
        #expect(throws: AmethystEscapeError.level("number")) { try Core.level(number: 101) }
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let level: AmethystEscapeLevel = core.play.level
        let opening: StateDigest = try Self.digest(core)
        var illegal: [ExperienceAction] = [Self.act("shell.rotate", [5, 1]), Self.act("shell.rotate", [-1, 1]),
                                           Self.act("shell.rotate", [0, 2]), Self.act("shell.rotate", [0, -2]),
                                           Self.act("shell.rotate", [0.5, 1]), Self.act("shell.rotate", [0, .nan]),
                                           Self.act("shell.rotate", [0, 0]), Self.act("shell.rotate", [0]),
                                           Self.act("pearl.advance", [1]), Self.act("play.undo"),
                                           Self.act("play.redo"), Self.act("play.undo", [1]),
                                           Self.act("level.next", [1]), Self.act("nope")]
        if level.shells.count < 5 { illegal.append(Self.act("shell.rotate", [Double(level.shells.count), 1])) }
        for action in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(action)
            #expect(!result.isAccepted, "\(action.control) \(action.values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.isEmpty, "\(action.control)")
        }
        var probe: Core = core
        // Outside the declared ranges or the value count: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.act("shell.rotate", [5, 1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("shell.rotate", [0, 2])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("shell.rotate", [0])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("pearl.advance", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("level.next", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        let notWhole: ActionResult = .rejected(.rule(code: AmethystEscapeExperienceRule.notWhole))
        #expect(probe.apply(Self.act("shell.rotate", [0.5, 1])) == notWhole)
        #expect(probe.apply(Self.act("shell.rotate", [0, 0.5])) == notWhole)
        // The kernel's refusals pass through with their reason codes.
        let action: ActionResult = .rejected(.rule(code: "r02-g07.action"))
        #expect(probe.apply(Self.act("shell.rotate", [0, 0])) == action)
        if level.shells.count < 5 {
            #expect(probe.apply(Self.act("shell.rotate", [Double(level.shells.count), 1])) == action)
        }
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe.apply(Self.act("nope")) == .rejected(.unknownControl("nope")))
        #expect(probe == core)

        // A rotation spends one move and turns the shell by one sector each way.
        #expect(core.apply(Self.act("shell.rotate", [1, 1])) == .accepted)
        #expect(core.play.crystal.offsets[1] == 1 && core.play.moves == 1 && core.play.records.count == 1)
        #expect(try Self.digest(core) != opening)
        #expect(core.apply(Self.act("shell.rotate", [1, -1])) == .accepted)
        #expect(core.play.crystal.offsets[1] == 0 && core.play.moves == 2)

        // `stuck`: a seeded walk over levels 1 … 10 finds a state with no aperture lined up and a wall ahead.
        var random = SeededRandom(seed: 2_363)
        var stuck: Core? = nil
        for number in 1...10 where stuck == nil {
            var walker: Core = try Core.opening(number: number)
            for _ in 0..<40 where stuck == nil && walker.play.stage == .playing {
                if walker.play.crystal.transition(level: walker.play.level) == .stuck {
                    stuck = walker
                } else {
                    let shell: Int = random.int(0...(walker.play.level.shells.count - 1))
                    let choice: Int = random.int(0...2)
                    let next: ExperienceAction = choice == 0
                        ? Self.act("pearl.advance") : Self.act("shell.rotate", [Double(shell), choice == 1 ? 1 : -1])
                    _ = walker.apply(next)
                    if walker.play.remaining <= 1 { break }
                }
            }
        }
        var blocked: Core = try #require(stuck)
        let wall: Core = blocked
        #expect(blocked.apply(Self.act("pearl.advance")) == .rejected(.rule(code: "r02-g07.stuck")))
        #expect(blocked == wall)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 12)
        let startDigest: StateDigest = try Self.digest(core)
        let start: AmethystEscapeCrystal = core.play.crystal
        #expect(core.apply(Self.act("shell.rotate", [0, 1])) == .accepted)
        #expect(core.apply(Self.act("shell.rotate", [1, -1])) == .accepted)
        #expect(core.apply(Self.act("shell.rotate", [1, -1])) == .accepted)
        let moved: Core = core
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(core.play.crystal == start && core.play.moves == 0 && core.play.stage == .playing)
        #expect(try Self.digest(core) == startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.redo")) == .accepted) }
        #expect(core.play.crystal == moved.play.crystal && core.play.moves == 3)
        #expect(core.play.records.count == 9)
        #expect(try Self.digest(core) == movedDigest)
        // A new action clears the redo history.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("shell.rotate", [0, -1])) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g07.action")))
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(try Self.digest(core) == startDigest)
    }

    @Test func theSolutionWinsTheBudgetFailsAndUndoRetries() async throws {
        let numbers: [Int] = [1, 24]
        let stageCode: ActionResult = .rejected(.rule(code: "r02-g07.stage"))
        for number in numbers {
            let generated: AmethystEscapeGenerated = try Core.generated(number: number)
            let level: AmethystEscapeLevel = generated.level
            var core: Core = try Core.opening(number: number)
            // Rotations back and forth until the budget is spent: failed (budget); undo returns to playing.
            var failing: Core = core
            let before: StateDigest = try Self.digest(failing)
            for index in 0..<level.budget {
                let step: Double = index % 2 == 0 ? 1 : -1
                #expect(failing.apply(Self.act("shell.rotate", [0, step])) == .accepted)
            }
            #expect(failing.play.stage == .failed && failing.play.failure == .budget, "level \(number)")
            #expect(failing.outcome?.code == Core.failedCode)
            #expect(failing.snapshot(time: 0).stage == .failed && failing.snapshot(time: 0).failure == .budget)
            let failed: Core = failing
            #expect(failing.apply(Self.act("shell.rotate", [0, 1])) == stageCode)
            #expect(failing.apply(Self.act("pearl.advance")) == stageCode)
            #expect(failing.apply(Self.act("play.redo")) == stageCode)
            #expect(failing == failed)
            #expect(failing.apply(Self.act("play.undo")) == .accepted)
            #expect(failing.play.stage == .playing && failing.outcome == nil)
            while failing.play.canUndo { #expect(failing.apply(Self.act("play.undo")) == .accepted) }
            #expect(try Self.digest(failing) == before)
            // The certified solution: won on its last action.
            for step in generated.solution.actions { #expect(core.apply(Self.act(step)) == .accepted) }
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "level \(number)")
            #expect(core.play.moves == generated.solution.smallest && core.snapshot(time: 0).escaped)
            let won: Core = core
            #expect(core.apply(Self.act("play.undo")) == stageCode)
            #expect(core.apply(Self.act("shell.rotate", [0, 1])) == stageCode)
            #expect(core.apply(Self.act("pearl.advance")) == stageCode)
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
        #expect(core.apply(Self.act("shell.rotate", [1, 1])) == .accepted)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 40 && core.play.records.isEmpty && core.play.stage == .playing)
        core.reset()
        let fresh: Core = try await Core.prepare(seed: 38)
        let resetDigest: StateDigest = try Self.digest(core)
        let freshDigest: StateDigest = try Self.digest(fresh)
        #expect(core == fresh && resetDigest == freshDigest)
        // The wrap: level 100 → 1.
        var last: Core = try Core.opening(number: 100)
        #expect(last.apply(Self.act("level.next")) == .accepted)
        let first: Core = try await Core.prepare(seed: 0)
        #expect(last.levelNumber == 1 && last == first)
        last.reset()
        #expect(last.levelNumber == 100)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        var core: Core = try await Core.prepare(seed: 31)
        #expect(core.apply(Self.act("shell.rotate", [1, 1])) == .accepted)
        #expect(core.apply(Self.act("shell.rotate", [0, -1])) == .accepted)
        #expect(core.apply(Self.act("shell.rotate", [1, 1])) == .accepted)
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

        #expect(throws: AmethystEscapeRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 31)
        }
        #expect(throws: AmethystEscapeRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 31)
        }
        #expect(throws: AmethystEscapeRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"32\",\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: AmethystEscapeRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: AmethystEscapeRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 31)
        }
        // The same records on another level: the first record's previous fingerprint is not that play's.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":1").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: AmethystEscapeRestoreRefusal.kernel(.malformed("replay"))) {
            try Core.restore(payload: wrongLevel, seed: 31)
        }
        // A record of a newer schema: the replayed record (schema 1) differs from the stored one.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: AmethystEscapeRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: newer, seed: 31)
        }
        // An edited move number: the replayed record differs from the stored one.
        let edited: Data = Data(text.replacingOccurrences(of: "\"move\":0", with: "\"move\":7").utf8)
        #expect(edited != payload)
        #expect(throws: AmethystEscapeRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: edited, seed: 31)
        }
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 5)
        try engine.activate()
        #expect(engine.handle(control: "shell.rotate", values: [1, 1]) == .accepted)
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
        #expect(core.apply(Self.act("shell.rotate", [1, -1])) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let bevels: [Int] = [3, 3, 2, 1, 1]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.bevelSegments == bevels[index])
            #expect(core.renderTier == AmethystEscapeTier.of(clamped[index]))
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: AmethystEscapeSceneSnapshot = core.snapshot(time: time)
            #expect(snapshot.pearl == core.play.crystal.pearl && snapshot.stage == core.play.stage)
            #expect(snapshot.shells.map(\.offset) == core.play.crystal.offsets)
            #expect(snapshot.levelNumber == core.levelNumber && snapshot.time.isFinite)
            #expect(snapshot.moves == core.play.moves && snapshot.budget == core.play.level.budget)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }
}
