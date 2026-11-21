// WaveKnotKeeperExperienceCoreTests — feature 323 (R02-G03-03) T-R02G0303-005 (FR-R02G0303-003, 005; SC-R02G0303-002;
// clarification Q5). The adapter core: the shared conformance checks pass; the seed picks level `seed % 100 + 1`
// deterministically in stage `playing`; a legal point.move changes the digest and an illegal one is refused with the
// state unchanged (the engine's range checks, `r02-g03.not-whole`, the kernel's `r02-g03.move`); point.select changes
// only the selection, never the digest; undo restores the earlier digest exactly and redo the later one; the certified
// solution wins; `level.next` wraps 100 to 1 and reset returns; the snapshot round trip and refused payloads (damaged,
// level out of range, a stale trace, an edited record, a record of a newer schema); the quality tier and the presenter's
// snapshot time never touch the digest. Feature 325 (R02-G03-05) T-R02G0305-004: the progression actions
// (`level.select`, `mode.daily`, `mode.practice`, `mode.campaign`, `tutorial.dismiss`, `tutorial.hint`), a win's record,
// the schema-1 → 2 migration and undo restoring the digest with the tutorial advanced. Legal moves are found with the kernel's own `refusal(of:points:level:)`, so no
// rope coordinates are hard-coded. Explicit types, plain loops, short runs.
import Foundation
import Testing
@testable import WaveKnotKeeperCore
import VisualCoreDiagnostics
import VisualCoreExperience

@Suite struct WaveKnotKeeperExperienceCoreTests {
    typealias Core = WaveKnotKeeperExperienceCore

    /// The digest of `core` as the engine computes it.
    static func digest(_ core: Core) throws -> StateDigest {
        var builder = DigestBuilder(domain: Core.experienceID)
        try core.writeDigest(into: &builder)
        return builder.finish()
    }

    /// The `point.move` action for a kernel move.
    static func action(_ move: WaveKnotKeeperMove) -> ExperienceAction {
        let index: Int = Core.directionOrder.firstIndex(of: move.direction) ?? 0
        return ExperienceAction(control: "point.move", values: [Double(move.point), Double(index)], step: 0)
    }

    /// The `point.move` action with the given values.
    static func move(_ point: Double, _ direction: Double) -> ExperienceAction {
        ExperienceAction(control: "point.move", values: [point, direction], step: 0)
    }

    /// The `point.select` action with the given value.
    static func select(_ point: Double) -> ExperienceAction {
        ExperienceAction(control: "point.select", values: [point], step: 0)
    }

    /// A control with no values.
    static func plain(_ control: String) -> ExperienceAction {
        ExperienceAction(control: control, step: 0)
    }

    /// Whether `move` is legal on `level`'s start rope and does not win there.
    static func isQuietStart(_ move: WaveKnotKeeperMove, level: WaveKnotKeeperLevel) -> Bool {
        guard WaveKnotKeeperPlay.refusal(of: move, points: level.points, level: level) == nil else { return false }
        var moved: [WaveKnotKeeperPoint] = level.points
        moved[move.point] = moved[move.point].moved(move.direction)
        return !level.wins(moved)
    }

    /// The first move in point-then-direction order that is legal and does not win from the start of every level in
    /// `levels`.
    static func quietMove(on levels: [WaveKnotKeeperLevel]) -> WaveKnotKeeperMove? {
        let count: Int = levels.map(\.points.count).min() ?? 0
        for point in 0..<count {
            for direction in Core.directionOrder {
                let move = WaveKnotKeeperMove(point: point, direction: direction)
                var quiet: Bool = true
                for level in levels where !isQuietStart(move, level: level) { quiet = false }
                if quiet { return move }
            }
        }
        return nil
    }

    /// The first move in point-then-direction order the kernel refuses on `core`'s rope, with its refusal.
    static func refusedMove(on core: Core) -> (WaveKnotKeeperMove, WaveKnotKeeperError)? {
        let play: WaveKnotKeeperPlay = core.play
        for point in play.points.indices {
            for direction in Core.directionOrder {
                let move = WaveKnotKeeperMove(point: point, direction: direction)
                if let refusal = WaveKnotKeeperPlay.refusal(of: move, points: play.points, level: play.level) {
                    return (move, refusal)
                }
            }
        }
        return nil
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 (tutorial) and 100 (hardest band), then 1 after level.next (only the seed's levels are open); the
        // scripted moves are legal on them and none wins. Two seeds keep the run short (each preparation generates a certified level, once).
        let first: WaveKnotKeeperMove = try #require(Self.quietMove(on: [try Core.level(number: 1),
                                                                        try Core.level(number: 100)]))
        let second: WaveKnotKeeperMove = try #require(Self.quietMove(on: [try Core.level(number: 2),
                                                                         try Core.level(number: 1)]))
        let a: [Double] = [Double(first.point), Double(Core.directionOrder.firstIndex(of: first.direction) ?? 0)]
        let b: [Double] = [Double(second.point), Double(Core.directionOrder.firstIndex(of: second.direction) ?? 0)]
        let actions: [ScriptedAction] = [ScriptedAction("point.select", [0]),
                                         ScriptedAction("point.move", a),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("play.undo"), ScriptedAction("level.next"),
                                         ScriptedAction("point.select", [3]),
                                         ScriptedAction("point.move", b),
                                         ScriptedAction("tutorial.hint"), ScriptedAction("tutorial.dismiss"),
                                         ScriptedAction("mode.practice"), ScriptedAction("mode.campaign"),
                                         ScriptedAction("mode.daily", [2026, 1, 1]), ScriptedAction("level.select", [1])]
        let rejected: [ScriptedAction] = [ScriptedAction("point.move", [0, 0.5]),
                                          ScriptedAction("point.move", [0.5, 1]),
                                          ScriptedAction("point.move", [16, 0]),
                                          ScriptedAction("point.move", [0, 6]),
                                          ScriptedAction("point.move", [0]),
                                          ScriptedAction("point.select", [16]),
                                          ScriptedAction("point.select", [1.5]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus"),
                                          ScriptedAction("level.select", [101]),
                                          ScriptedAction("mode.daily", [2026, 2, 30]),
                                          ScriptedAction("mode.daily", [2026, 1]),
                                          ScriptedAction("mode.practice", [1])]
        let plan = ConformancePlan(seeds: [0, 99], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g03.wave-knot-keeper" && Core.schemaVersion == 3)
        #expect(Core.digestDomain == "r02-g03.wave-knot-keeper.v3")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        #expect(Core.actionIDs == ["point.move", "point.select", "play.undo", "play.redo", "level.next", "level.select",
                                   "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss", "tutorial.hint",
                                   "replay.start", "replay.step", "replay.stop"])
        #expect(Core.controls[0].ranges == [0...15, 0...5])
        #expect(Core.controls[1].ranges == [0...15])
        for index in 2..<5 { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.controls[5].ranges == [1...100])
        #expect(Core.controls[6].ranges == [1...9999, 1...12, 1...31])
        for index in 7..<11 { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.controls[11].ranges == [1...100])
        #expect(Core.controls[12].ranges.isEmpty && Core.controls[13].ranges.isEmpty)
        #expect(Core.practiceAllowance == 64)
        #expect(Core.directionOrder == [.plusX, .minusX, .plusY, .minusY, .plusZ, .minusZ])
        #expect(Core.qualityTiers == 3)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 0.625, 0.375] && iterations == [1, 0.5, 0.25] && passes == [2, 1, 0])
        #expect(resolutions == [1, 1, 1])
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
            let expected: WaveKnotKeeperLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.points == expected.points)
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.selected == nil)
        }
        #expect(Core.levelNumber(forSeed: 99) == 100)
        // The cache hands back the generator's own level.
        let fresh: WaveKnotKeeperLevel = try WaveKnotKeeperGenerator.generate(WaveKnotKeeperManifest.entries[0]).level
        #expect(try Core.level(number: 1) == fresh)
        #expect(throws: WaveKnotKeeperError.level("number")) { try Core.level(number: 0) }
        #expect(throws: WaveKnotKeeperError.level("number")) { try Core.level(number: 101) }
    }

    @Test func aLegalMoveChangesTheDigestAndIllegalOnesChangeNothing() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let count: Int = core.play.points.count
        let (refused, refusal): (WaveKnotKeeperMove, WaveKnotKeeperError) = try #require(Self.refusedMove(on: core))
        let refusedValues: [Double] = Self.action(refused).values
        var illegal: [[Double]] = [[0, 0.5], [0.25, 1], [16, 0], [-1, 0], [0, 6], [0, -1], [0, .nan], [0], [0, 1, 1],
                                   refusedValues]
        if count < 16 { illegal.append([Double(count), 0]) }
        for values in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(ExperienceAction(control: "point.move", values: values, step: 0))
            #expect(!result.isAccepted, "\(values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.isEmpty, "\(values)")
        }
        var probe: Core = core
        // The kernel's refusals pass through with its reason code.
        #expect(probe.apply(Self.action(refused)) == .rejected(.rule(code: refusal.reasonCode)))
        #expect(refusal.reasonCode == "r02-g03.move")
        if count < 16 {
            #expect(probe.apply(Self.move(Double(count), 0)) == .rejected(.rule(code: "r02-g03.move")))
        }
        // Outside the declared ranges: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.move(16, 0)) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.move(0, 6)) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.move(0, 1.5)) == .rejected(.rule(code: WaveKnotKeeperExperienceRule.notWhole)))
        #expect(probe.apply(Self.plain("play.undo")) == .rejected(.rule(code: "r02-g03.move")))
        #expect(probe.apply(Self.plain("play.redo")) == .rejected(.rule(code: "r02-g03.move")))
        #expect(probe.apply(Self.plain("nope")) == .rejected(.unknownControl("nope")))
        #expect(probe == core)
        let legal: WaveKnotKeeperMove = try #require(Self.quietMove(on: [core.play.level]))
        let expected: WaveKnotKeeperPoint = core.play.points[legal.point].moved(legal.direction)
        #expect(core.apply(Self.action(legal)) == .accepted)
        #expect(core.play.points[legal.point] == expected && core.play.records.count == 1 && core.play.spent == 1)
        #expect(core.play.stage == .playing)
        #expect(try Self.digest(core) != opening)
    }

    @Test func selectChangesOnlyTheSelection() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let count: Int = core.play.points.count
        #expect(core.apply(Self.select(Double(count - 1))) == .accepted)
        #expect(core.selected == count - 1 && core.snapshot(time: 0).selected == count - 1)
        #expect(core.apply(Self.select(0)) == .accepted)
        #expect(core.selected == 0)
        #expect(try Self.digest(core) == opening && core.play.records.isEmpty)
        if count < 16 {
            #expect(core.apply(Self.select(Double(count))) == .rejected(.rule(code: "r02-g03.move")))
        }
        #expect(core.apply(Self.select(16)) == .rejected(.outOfRange(index: 0)))
        #expect(core.apply(Self.select(0.5)) == .rejected(.rule(code: WaveKnotKeeperExperienceRule.notWhole)))
        #expect(try core.selected == 0 && Self.digest(core) == opening)
        // The selection is not in the payload: a restored core has none.
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && restored.selected == nil)
        core.reset()
        #expect(core.selected == nil)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 12)
        let start: [WaveKnotKeeperPoint] = core.play.points
        let startDigest: StateDigest = try Self.digest(core)
        let legal: WaveKnotKeeperMove = try #require(Self.quietMove(on: [core.play.level]))
        #expect(core.apply(Self.action(legal)) == .accepted)
        let moved: [WaveKnotKeeperPoint] = core.play.points
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest)
        #expect(core.apply(Self.plain("play.undo")) == .accepted)
        #expect(core.play.points == start && core.play.spent == 0)
        #expect(try Self.digest(core) == startDigest)
        #expect(core.apply(Self.plain("play.redo")) == .accepted)
        #expect(core.play.points == moved && core.play.spent == 1 && core.play.records.count == 3)
        #expect(try Self.digest(core) == movedDigest)
        #expect(core.apply(Self.plain("play.redo")) == .rejected(.rule(code: "r02-g03.move")))
    }

    @Test func theCertifiedSolutionWins() async throws {
        let seeds: [UInt64] = [0, 41]
        for seed in seeds {
            var core: Core = try await Core.prepare(seed: seed)
            let generated: WaveKnotKeeperGenerated = try Core.generated(number: core.levelNumber)
            for move in generated.solution.moves {
                #expect(core.apply(Self.action(move)) == .accepted, "seed \(seed) \(move)")
            }
            #expect(core.play.stage == .won && core.play.points == generated.solution.final, "seed \(seed)")
            #expect(core.outcome?.code == Core.wonCode, "seed \(seed)")
            #expect(core.snapshot(time: 0).matchesTarget)
            let won: Core = core
            #expect(core.apply(Self.plain("play.undo")) == .rejected(.rule(code: "r02-g03.stage")))
            #expect(core == won)
            core.reset()
            #expect(core.play.stage == .playing && core.outcome == nil && core.play.records.isEmpty)
        }
    }

    @Test func nextLevelWrapsAndResetReturnsToTheSeedsLevel() async throws {
        // Seed 99 opens levels 1 … 100: level.next wraps 100 to 1, then moves to 2.
        var core: Core = try await Core.prepare(seed: 99)
        #expect(core.levelNumber == 100 && core.progress.frontier == 100)
        let legal: WaveKnotKeeperMove = try #require(Self.quietMove(on: [core.play.level]))
        #expect(core.apply(Self.action(legal)) == .accepted)
        #expect(core.apply(Self.select(1)) == .accepted)
        #expect(core.apply(Self.plain("level.next")) == .accepted)
        #expect(core.levelNumber == 1 && core.play.records.isEmpty && core.play.stage == .playing)
        #expect(core.selected == nil)
        #expect(core.apply(Self.plain("level.next")) == .accepted)
        #expect(core.levelNumber == 2 && core.play.stage == .playing)
        // Seed 0 opens level 1 only: level.next stays on level 1 with a fresh play.
        var first: Core = try await Core.prepare(seed: 0)
        let opening: Core = first
        #expect(first.apply(Self.action(try #require(Self.quietMove(on: [first.play.level])))) == .accepted)
        #expect(first.apply(Self.plain("level.next")) == .accepted)
        #expect(first.levelNumber == 1 && first.play == opening.play)
        core.reset()
        let fresh: Core = try await Core.prepare(seed: 99)
        let resetDigest: StateDigest = try Self.digest(core)
        let freshDigest: StateDigest = try Self.digest(fresh)
        #expect(core == fresh && resetDigest == freshDigest)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        var core: Core = try await Core.prepare(seed: 31)
        let legal: WaveKnotKeeperMove = try #require(Self.quietMove(on: [core.play.level]))
        #expect(core.apply(Self.action(legal)) == .accepted)
        #expect(core.apply(Self.plain("play.undo")) == .accepted)
        #expect(core.apply(Self.plain("play.redo")) == .accepted)
        #expect(core.apply(Self.plain("play.undo")) == .accepted)
        let payload: Data = try core.snapshotPayload()
        #expect(try core.snapshotPayload() == payload)
        let text: String = try #require(String(data: payload, encoding: .utf8))
        #expect(text.hasPrefix("{\"level\":32,\"mode\":"))
        #expect(text.contains("\"progress\":") && text.contains("\"records\":[") && text.contains("\"tutorial\":"))
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

        #expect(throws: WaveKnotKeeperRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 31)
        }
        #expect(throws: WaveKnotKeeperRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 31)
        }
        #expect(throws: WaveKnotKeeperRestoreRefusal.damaged) {
            try Core.restore(payload: Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":\"32\"").utf8),
                             seed: 31)
        }
        // A schema-1 payload reaches restore only through the migration chain.
        #expect(throws: WaveKnotKeeperRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":32,\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: WaveKnotKeeperRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":0").utf8),
                             seed: 31)
        }
        #expect(throws: WaveKnotKeeperRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":101").utf8),
                             seed: 31)
        }
        // The same records on another level: the first record's previous fingerprint is stale there.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":1").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: WaveKnotKeeperRestoreRefusal.kernel(.stale)) {
            try Core.restore(payload: wrongLevel, seed: 31)
        }
        // A record of a newer schema: the replayed record (schema 1) differs from the stored one.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: WaveKnotKeeperRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: newer, seed: 31)
        }
        // An edited tick: the replayed record differs from the stored one.
        let edited: Data = Data(text.replacingOccurrences(of: "\"tick\":0", with: "\"tick\":7").utf8)
        #expect(edited != payload)
        #expect(throws: WaveKnotKeeperRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: edited, seed: 31)
        }
        // The engine refuses a payload of a newer snapshot schema before the core sees it.
        #expect(Core.migrations.currentVersion == 3)
    }

    // MARK: Feature 325

    /// The action `control` with whole values.
    static func act(_ control: String, _ values: [Double] = []) -> ExperienceAction {
        ExperienceAction(control: control, values: values, step: 0)
    }

    @Test func selectAndModesFollowTheProgress() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.mode == .campaign && core.progress.frontier == 1)
        let opening: Core = core
        #expect(core.apply(Self.act("level.select", [2])) == .rejected(.rule(code: WaveKnotKeeperExperienceRule.locked)))
        #expect(core.apply(Self.act("mode.daily", [2026, 2, 30]))
                    == .rejected(.rule(code: WaveKnotKeeperExperienceRule.date)))
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 1.5]))
                    == .rejected(.rule(code: WaveKnotKeeperExperienceRule.notWhole)))
        #expect(core == opening)
        // The certified solution of level 1 wins and opens level 2 with its stars.
        let solution: [WaveKnotKeeperMove] = try Core.generated(number: 1).solution.moves
        for move in solution { #expect(core.apply(Self.action(move)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.frontier == 2)
        #expect(core.apply(Self.act("level.select", [2])) == .accepted)
        #expect(core.levelNumber == 2 && core.mode == .campaign && core.play.records.isEmpty)
        // Practice: the same level with the allowance raised; a practice win records nothing.
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == 2 && core.play.level.allowance == Core.practiceAllowance)
        #expect(core.tutorial == .done)
        let before: WaveKnotKeeperProgress = core.progress
        for move in try Core.generated(number: 2).solution.moves { #expect(core.apply(Self.action(move)) == .accepted) }
        #expect(core.play.stage == .won && core.progress == before)
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 2 && core.play.records.isEmpty)
        // Daily: the date's level, recorded on a win without opening a level.
        let daily: Int = try #require(WaveKnotKeeperProgress.dailyLevel(year: 2026, month: 1, day: 1))
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 1])) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily)
        let frontier: Int = core.progress.frontier
        for move in try Core.generated(number: daily).solution.moves {
            #expect(core.apply(Self.action(move)) == .accepted)
        }
        #expect(core.play.stage == .won && core.progress.frontier == frontier)
        // Back to campaign: a daily level beyond the frontier falls back to the frontier.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.progress.isOpen(core.levelNumber))
        // Reset returns to the opening state, progress included.
        core.reset()
        #expect(core == opening)
    }

    @Test func theTutorialAdvancesAndUndoRestoresTheDigestWithIt() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let hint: WaveKnotKeeperHint = try #require(core.hint(level: 1))
        #expect(core.tutorial == .move(hint.point))
        let startDigest: StateDigest = try Self.digest(core)
        let legal: WaveKnotKeeperMove = try #require(Self.quietMove(on: [core.play.level]))
        #expect(core.apply(Self.action(legal)) == .accepted)
        #expect(core.tutorial == .signature)
        #expect(core.apply(Self.plain("play.undo")) == .accepted)
        // The digest returns; the tutorial does not move back.
        #expect(try Self.digest(core) == startDigest && core.tutorial == .signature)
        #expect(core.apply(Self.plain("tutorial.hint")) == .accepted)
        #expect(try core.tutorial == .hints && Self.digest(core) == startDigest)
        #expect(core.apply(Self.plain("tutorial.dismiss")) == .accepted)
        #expect(core.tutorial == .done)
        // Level 4 has no tutorial; neither has practice.
        let later: Core = try await Core.prepare(seed: 3)
        #expect(later.tutorial == .done)
    }

    @Test func aFailedPlayIsExplainedAndUndoRewindsTheFailingMove() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let entries: [ScenarioStep] = Core.allowanceEntries
        #expect(!entries.isEmpty)
        for entry in entries {
            let scripted: ScriptedAction = try #require(entry.action)
            #expect(core.apply(ExperienceAction(control: scripted.control, values: scripted.values, step: 0)) == .accepted)
        }
        #expect(core.play.stage == .failed)
        let explanation: WaveKnotKeeperFailureExplanation = try #require(core.failureExplanation)
        #expect(explanation.text.hasSuffix("Undo the last move or retry the level."))
        #expect(core.hint(level: 3) == nil)
        let spent: Int = core.play.spent
        #expect(core.apply(Self.plain("play.undo")) == .accepted)
        #expect(core.play.stage == .playing && core.play.spent == spent - 1 && core.failureExplanation == nil)
    }

    @Test func aSchemaOnePayloadMigrates() async throws {
        var core: Core = try await Core.prepare(seed: 31)
        let legal: WaveKnotKeeperMove = try #require(Self.quietMove(on: [core.play.level]))
        #expect(core.apply(Self.action(legal)) == .accepted)
        let object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: try core.snapshotPayload()) as? [String: Any])
        let schemaOne: [String: Any] = ["level": try #require(object["level"]), "records": try #require(object["records"])]
        let migrated: [String: Any] = try Core.migratedToSchemaTwo(schemaOne)
        let payload: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
        let restored: Core = try Core.restore(payload: payload, seed: 31)
        #expect(restored.levelNumber == 32 && restored.mode == .campaign && restored.progress.frontier == 32)
        #expect(restored.play == core.play && restored.tutorial == .done)
        #expect(try Self.digest(restored) == Self.digest(core))
        #expect(throws: WaveKnotKeeperRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": "x"]) }
    }

    @Test func theTierAndTheSnapshotTimeNeverTouchTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: 44)
        let legal: WaveKnotKeeperMove = try #require(Self.quietMove(on: [core.play.level]))
        #expect(core.apply(Self.action(legal)) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let sides: [Int] = [16, 16, 10, 6, 6]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.sides == sides[index])
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: WaveKnotKeeperSceneSnapshot = core.snapshot(time: time)
            #expect(snapshot.points == core.play.points && snapshot.stage == core.play.stage)
            #expect(snapshot.levelNumber == core.levelNumber && snapshot.time.isFinite)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }

    // MARK: Feature 327 (R02-G03-07) T-R02G0307-003

    @Test func aCampaignWinRecordsItsTraceAndReplayReproducesIt() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.apply(Self.act("replay.start", [1])) == .rejected(.rule(code: WaveKnotKeeperExperienceRule.noReplay)))
        #expect(core.apply(Self.plain("replay.step")) == .rejected(.rule(code: WaveKnotKeeperExperienceRule.noReplay)))
        #expect(core.apply(Self.plain("replay.stop")) == .rejected(.rule(code: WaveKnotKeeperExperienceRule.noReplay)))
        // A detour (a quiet move and its undo) leaves the net moves: the certified solution.
        let quiet: WaveKnotKeeperMove = try #require(Self.quietMove(on: [core.play.level]))
        #expect(core.apply(Self.action(quiet)) == .accepted)
        #expect(core.apply(Self.plain("play.undo")) == .accepted)
        let solution: [WaveKnotKeeperMove] = try Core.generated(number: 1).solution.moves
        for move in solution { #expect(core.apply(Self.action(move)) == .accepted) }
        #expect(core.play.stage == .won)
        let result: WaveKnotKeeperProgress.Result = try #require(core.progress.solved[1])
        #expect(result.trace == solution && result.verified && result.bestMoves == solution.count)
        let progress: WaveKnotKeeperProgress = core.progress
        // Replay: a fresh play, the tutorial done, the trace move by move, then the end.
        #expect(core.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(core.mode == .replay(level: 1) && core.tutorial == .done && core.play.records.isEmpty)
        #expect(core.apply(Self.select(0)) == .accepted)
        #expect(core.apply(Self.plain("tutorial.dismiss")) == .accepted)
        let refused: [ExperienceAction] = [Self.action(quiet), Self.plain("play.undo"), Self.plain("play.redo"),
                                           Self.plain("level.next"), Self.act("level.select", [1]),
                                           Self.plain("mode.practice"), Self.plain("tutorial.hint")]
        for action in refused {
            #expect(core.apply(action) == .rejected(.rule(code: WaveKnotKeeperExperienceRule.replay)), "\(action)")
        }
        var fresh: WaveKnotKeeperPlay = try Core.freshPlay(of: try Core.level(number: 1))
        for move in solution {
            #expect(core.apply(Self.plain("replay.step")) == .accepted)
            try fresh.apply(move, expecting: fresh.fingerprint)
            #expect(core.play.fingerprint == fresh.fingerprint)
        }
        #expect(core.play.stage == .won && core.progress == progress, "replay never records")
        #expect(core.apply(Self.plain("replay.step")) == .rejected(.rule(code: WaveKnotKeeperExperienceRule.replayEnd)))
        // The replay round-trips through the snapshot.
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && restored.reconciliationDropped == 0)
        #expect(core.apply(Self.plain("replay.stop")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.progress == progress)
    }

    @Test func restoreReconcilesAndDropsAnEditedResult() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        for move in try Core.generated(number: 1).solution.moves { #expect(core.apply(Self.action(move)) == .accepted) }
        let text: String = try #require(String(data: try core.snapshotPayload(), encoding: .utf8))
        #expect(text.contains("\"verified\":true"))
        let honest: Core = try Core.restore(payload: Data(text.utf8), seed: 0)
        #expect(honest.reconciliationDropped == 0 && honest.progress == core.progress)
        // Two stars claimed for a three-star win: the replay disagrees, the result is dropped, the frontier stays.
        let edited: String = text.replacingOccurrences(of: "\"stars\":3", with: "\"stars\":2")
        #expect(edited != text)
        let checked: Core = try Core.restore(payload: Data(edited.utf8), seed: 0)
        #expect(checked.reconciliationDropped == 1 && checked.progress.solved[1] == nil)
        #expect(checked.progress.frontier == core.progress.frontier)
        // A replay of a dropped result restores in campaign.
        var replaying: Core = core
        #expect(replaying.apply(Self.act("replay.start", [1])) == .accepted)
        let replayText: String = try #require(String(data: try replaying.snapshotPayload(), encoding: .utf8))
        let replayEdited: String = replayText.replacingOccurrences(of: "\"stars\":3", with: "\"stars\":2")
        let back: Core = try Core.restore(payload: Data(replayEdited.utf8), seed: 0)
        #expect(back.mode == .campaign && back.reconciliationDropped == 1)
    }

    @Test func aSchemaTwoPayloadMigratesToThree() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        for move in try Core.generated(number: 1).solution.moves { #expect(core.apply(Self.action(move)) == .accepted) }
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
        let result: WaveKnotKeeperProgress.Result = try #require(restored.progress.solved[1])
        #expect(!result.verified && result.trace.isEmpty && result.stars == 3)
        #expect(restored.reconciliationDropped == 0 && restored.progress.frontier == core.progress.frontier)
        #expect(throws: WaveKnotKeeperRestoreRefusal.damaged) { try Core.migratedToSchemaThree(["level": 1]) }
        // An unverified result cannot be replayed.
        var replay: Core = restored
        #expect(replay.apply(Self.act("replay.start", [1])) == .rejected(.rule(code: WaveKnotKeeperExperienceRule.noReplay)))
    }
}
