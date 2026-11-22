// NocturneGardenExperienceCoreTests — feature 383 (R02-G09-03) T-R02G0903-005 (FR-R02G0903-005, 008, 009;
// clarifications Q4, Q5). The adapter core: the shared conformance checks pass; the declared controls, ids, tiers and
// profile; the seed picks level `seed % 100 + 1` deterministically in stage `playing` (seeds 0, 1, 99 and 100 give
// levels 1, 2, 100 and 1); every control is accepted when legal and refused with the state unchanged otherwise (the
// engine's range checks, `r02-g09.not-whole`, the kernel's `r02-g09.action`, `supply`, `noop` and `stage`); undo
// restores the earlier digest exactly and redo the later one; the certified solution wins, a leak and the budget fail,
// undo returns a failed play to playing; `level.next` wraps 100 to 1 and reset returns; the snapshot round trip and
// refused payloads (damaged, level out of range, a trace of another level, a record of a newer schema, an envelope of a
// newer schema); the certified-candidate table equals the 100 stored witnesses' `skipped` and the directly certified
// levels equal the stored ones; `snapshot(time:)` mirrors the play. Fixture seed 2_383. Levels are certified once per
// process, so the run stays short. Explicit types, plain loops.
import Foundation
import Testing
@testable import NocturneGardenCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/nocturne-garden/levels", isDirectory: true)

@Suite struct NocturneGardenExperienceCoreTests {
    typealias Core = NocturneGardenExperienceCore

    /// The fixture seed of this feature.
    static let fixtureSeed: UInt64 = 2_383

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
    static func act(_ action: NocturneGardenAction) -> ExperienceAction {
        switch action {
        case let .plant(kind, column, row, size):
            act("bloom.plant", [Double(kind.order), Double(column), Double(row), Double(size)])
        case let .move(bloom, column, row):
            act("bloom.move", [Double(bloom), Double(column), Double(row)])
        case let .resize(bloom, size):
            act("bloom.resize", [Double(bloom), Double(size)])
        case let .remove(bloom):
            act("bloom.remove", [Double(bloom)])
        case let .sun(elevation):
            act("sun.set", [Double(elevation)])
        }
    }

    /// A sun change of `core` to another allowed elevation: on an empty bed it neither leaks nor wins.
    static func neutralSun(_ core: Core) -> ExperienceAction? {
        for elevation in core.play.level.elevations.sorted() where elevation != core.play.elevation {
            return act("sun.set", [Double(elevation)])
        }
        return nil
    }

    /// The stored witness of level `number`.
    static func storedWitness(_ number: Int) throws -> NocturneGardenWitness {
        let name: String = String(NocturneGardenGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: coreWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(NocturneGardenWitness.self, from: data)
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 2 (and 2 and 3 for the restore engine): a sun change, undo and redo, another sun change, undo,
        // a plant, then level.next and a sun change.
        let actions: [ScriptedAction] = [ScriptedAction("sun.set", [3]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("sun.set", [2]), ScriptedAction("play.undo"),
                                         ScriptedAction("bloom.plant", [0, 4, 0, 2]),
                                         ScriptedAction("level.next"), ScriptedAction("sun.set", [3])]
        // Refused on the opening of levels 1 and 2 (supply tulip and star, or tulip and lily; bed 16 × 12; size 2;
        // elevations 2 and 3, opening 2).
        let rejected: [ScriptedAction] = [ScriptedAction("bloom.plant", [6, 0, 0, 2]),
                                          ScriptedAction("bloom.plant", [0, 32, 0, 2]),
                                          ScriptedAction("bloom.plant", [0, 0, 0, 4]),
                                          ScriptedAction("bloom.plant", [0, 0.5, 0, 2]),
                                          ScriptedAction("bloom.plant", [1, 4, 0, 2]),
                                          ScriptedAction("bloom.plant", [0, 16, 0, 2]),
                                          ScriptedAction("bloom.plant", [0, 4, 0, 1]),
                                          ScriptedAction("bloom.plant", [0, 4, 0]),
                                          ScriptedAction("bloom.move", [0, 1, 1]),
                                          ScriptedAction("bloom.resize", [0, 2]),
                                          ScriptedAction("bloom.remove", [0]),
                                          ScriptedAction("sun.set", [1]), ScriptedAction("sun.set", [2]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 1], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g09.nocturne-garden" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g09.nocturne-garden.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["bloom.plant", "bloom.move", "bloom.resize", "bloom.remove", "sun.set", "play.undo",
                             "play.redo", "level.next"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[0].ranges == [0...5, 0...31, 0...23, 1...3])
        #expect(Core.controls[1].ranges == [0...11, 0...31, 0...23])
        #expect(Core.controls[2].ranges == [0...11, 1...3])
        #expect(Core.controls[3].ranges == [0...11])
        #expect(Core.controls[4].ranges == [1...4])
        let plainIndices: [Int] = [5, 6, 7]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        for kind in NocturneGardenKind.allCases { #expect(Core.kind(kind.order) == kind) }
        #expect(Core.kind(-1) == nil && Core.kind(6) == nil)
        #expect(Core.qualityTiers == 3 && Core.migrations.currentVersion == 1)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == NocturneGardenTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 2.0 / 3.0, 1.0 / 3.0] && iterations == [1, 2.0 / 3.0, 1.0 / 3.0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(NocturneGardenExperienceRule.notWhole == "r02-g09.not-whole")
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
            let expected: NocturneGardenLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.blooms.isEmpty)
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.play.moves == 0 && first.play.elevation == expected.sun && first.qualityTier == 0)
        }
        #expect(Core.levelNumber(forSeed: Self.fixtureSeed) == 84)
        #expect(throws: NocturneGardenError.level("number")) { try Core.level(number: 0) }
        #expect(throws: NocturneGardenError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableEqualsTheWitnessesAndCertifiesTheStoredLevels() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for number in 1...100 {
            let witness: NocturneGardenWitness = try Self.storedWitness(number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "level \(number)")
        }
        // Directly certified levels equal the stored witness levels and solutions.
        let numbers: [Int] = [1, 5, 65, 100]
        for number in numbers {
            let witness: NocturneGardenWitness = try Self.storedWitness(number)
            let generated: NocturneGardenGenerated = try Core.generated(number: number)
            #expect(generated.level == witness.level && generated.solution.actions == witness.actions)
            #expect(generated.skipped == witness.skipped && generated.bound == witness.bound)
            #expect(generated.entry == NocturneGardenManifest.entries[number - 1])
            // The candidate just before the certified one does not certify (the generator skipped it).
            if witness.skipped > 0 {
                let entry: NocturneGardenManifestEntry = NocturneGardenManifest.entries[number - 1]
                #expect(Core.certify(entry, index: witness.skipped - 1) == nil, "level \(number)")
            }
        }
        // The generator itself gives the same level as the direct certification.
        let entry: NocturneGardenManifestEntry = NocturneGardenManifest.entries[4]
        #expect(try NocturneGardenGenerator.generate(entry) == Core.generated(number: 5))
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: bed 16 × 12, supply tulip and star, size 2, elevations 2 and 3, opening sun 2.
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let illegal: [ExperienceAction] = [Self.act("bloom.plant", [6, 0, 0, 2]),
                                           Self.act("bloom.plant", [-1, 0, 0, 2]),
                                           Self.act("bloom.plant", [0, 32, 0, 2]),
                                           Self.act("bloom.plant", [0, 0, 24, 2]),
                                           Self.act("bloom.plant", [0, 0, 0, 0]),
                                           Self.act("bloom.plant", [0, 0.5, 0, 2]),
                                           Self.act("bloom.plant", [0, 0, 0, .nan]),
                                           Self.act("bloom.plant", [1, 4, 0, 2]),
                                           Self.act("bloom.plant", [0, 16, 0, 2]),
                                           Self.act("bloom.plant", [0, 4, 12, 2]),
                                           Self.act("bloom.plant", [0, 4, 0, 3]),
                                           Self.act("bloom.plant", [0, 4, 0]),
                                           Self.act("bloom.move", [0, 1, 1]), Self.act("bloom.move", [12, 1, 1]),
                                           Self.act("bloom.resize", [0, 2]), Self.act("bloom.remove", [0]),
                                           Self.act("sun.set", [1]), Self.act("sun.set", [2]),
                                           Self.act("sun.set", [5]), Self.act("sun.set", [2.5]),
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
        #expect(probe.apply(Self.act("bloom.plant", [6, 0, 0, 2])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("bloom.plant", [0, 32, 0, 2])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("bloom.plant", [0, 0, 24, 2])) == .rejected(.outOfRange(index: 2)))
        #expect(probe.apply(Self.act("bloom.plant", [0, 0, 0, 4])) == .rejected(.outOfRange(index: 3)))
        #expect(probe.apply(Self.act("bloom.move", [12, 0, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("sun.set", [0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("bloom.plant", [0, 4, 0])) == .rejected(.wrongValueCount(expected: 4, found: 3)))
        #expect(probe.apply(Self.act("bloom.remove")) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(probe.apply(Self.act("play.undo", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("level.next", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        let notWhole: ActionResult = .rejected(.rule(code: NocturneGardenExperienceRule.notWhole))
        #expect(probe.apply(Self.act("bloom.plant", [0, 0.5, 0, 2])) == notWhole)
        #expect(probe.apply(Self.act("bloom.resize", [0, 1.5])) == notWhole)
        #expect(probe.apply(Self.act("sun.set", [2.5])) == notWhole)
        // The kernel's refusals pass through with their reason codes.
        let action: ActionResult = .rejected(.rule(code: "r02-g09.action"))
        let supply: ActionResult = .rejected(.rule(code: "r02-g09.supply"))
        let noop: ActionResult = .rejected(.rule(code: "r02-g09.noop"))
        #expect(probe.apply(Self.act("bloom.plant", [1, 4, 0, 2])) == supply)
        #expect(probe.apply(Self.act("bloom.plant", [0, 16, 0, 2])) == action)
        #expect(probe.apply(Self.act("bloom.plant", [0, 4, 0, 1])) == action)
        #expect(probe.apply(Self.act("bloom.move", [0, 1, 1])) == action)
        #expect(probe.apply(Self.act("bloom.resize", [0, 2])) == action)
        #expect(probe.apply(Self.act("bloom.remove", [0])) == action)
        #expect(probe.apply(Self.act("sun.set", [1])) == action)
        #expect(probe.apply(Self.act("sun.set", [2])) == noop)
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe.apply(Self.act("nope")) == .rejected(.unknownControl("nope")))
        #expect(probe == core)

        // A plant spends one move and adds the bloom; the shadow is the kernel's mask.
        #expect(core.apply(Self.act("bloom.plant", [0, 4, 0, 2])) == .accepted)
        let tulip = NocturneGardenBloom(kind: .tulip, column: 4, row: 0, size: 2)
        #expect(core.play.blooms == [tulip] && core.play.moves == 1 && core.play.records.count == 1)
        #expect(core.play.stage == .playing && !core.play.mask.cells.isEmpty)
        #expect(try Self.digest(core) != opening)
        // A second tulip is out of supply; the bloom refuses its own cell and size.
        #expect(core.apply(Self.act("bloom.plant", [0, 8, 0, 2])) == supply)
        #expect(core.apply(Self.act("bloom.move", [0, 4, 0])) == noop)
        #expect(core.apply(Self.act("bloom.resize", [0, 2])) == noop)
        #expect(core.apply(Self.act("bloom.resize", [0, 3])) == action)
        #expect(core.apply(Self.act("bloom.move", [1, 4, 0])) == action)
        #expect(core.apply(Self.act("bloom.move", [0, 4, 12])) == action)
        // Move, undo, then remove: each action spends one move (a move may leak, so it is undone first).
        var moved: Core = core
        #expect(moved.apply(Self.act("bloom.move", [0, 5, 0])) == .accepted)
        #expect(moved.play.blooms[0].column == 5 && moved.play.moves == 2)
        #expect(moved.apply(Self.act("play.undo")) == .accepted)
        #expect(moved.apply(Self.act("bloom.remove", [0])) == .accepted)
        #expect(moved.play.blooms.isEmpty && moved.play.mask.cells.isEmpty && moved.play.moves == 2)
        // The sun moves the shadow.
        var sun: Core = core
        #expect(sun.apply(Self.act("sun.set", [3])) == .accepted)
        #expect(sun.play.elevation == 3 && sun.play.moves == 2)
        // A level with two sizes accepts a resize (level 21: sizes 1 and 2).
        var resized: Core = try Core.opening(number: 21)
        #expect(resized.apply(Self.act("bloom.plant", [1, 2, 5, 1])) == .accepted)
        #expect(resized.apply(Self.act("bloom.resize", [0, 2])) == .accepted)
        #expect(resized.play.blooms[0].size == 2 && resized.play.moves == 2)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 20)
        let startDigest: StateDigest = try Self.digest(core)
        let start: Int = core.play.elevation
        for _ in 0..<3 {
            let sun: ExperienceAction = try #require(Self.neutralSun(core))
            #expect(core.apply(sun) == .accepted)
        }
        let moved: Core = core
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(core.play.elevation == start && core.play.moves == 0 && core.play.stage == .playing)
        #expect(try Self.digest(core) == startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.redo")) == .accepted) }
        #expect(core.play.elevation == moved.play.elevation && core.play.moves == 3)
        #expect(core.play.records.count == 9)
        #expect(try Self.digest(core) == movedDigest)
        // A new action clears the redo history.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let other: ExperienceAction = try #require(Self.neutralSun(core))
        #expect(core.apply(other) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g09.action")))
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(try Self.digest(core) == startDigest)
    }

    @Test func theSolutionWinsTheBudgetFailsAndUndoRetries() async throws {
        let numbers: [Int] = [1, 21, 100]
        let stageCode: ActionResult = .rejected(.rule(code: "r02-g09.stage"))
        for number in numbers {
            let generated: NocturneGardenGenerated = try Core.generated(number: number)
            let level: NocturneGardenLevel = generated.level
            var core: Core = try Core.opening(number: number)
            // Sun changes on the empty bed until the budget is spent: failed (budget); undo returns to playing.
            var failing: Core = core
            let before: StateDigest = try Self.digest(failing)
            for _ in 0..<level.budget {
                let sun: ExperienceAction = try #require(Self.neutralSun(failing))
                #expect(failing.apply(sun) == .accepted)
            }
            #expect(failing.play.stage == .failed && failing.play.failure == .budget, "level \(number)")
            #expect(failing.outcome?.code == Core.failedCode)
            let failedSnapshot: NocturneGardenSceneSnapshot = failing.snapshot(time: 0)
            #expect(failedSnapshot.stage == .failed && failedSnapshot.failure == .budget)
            #expect(!failedSnapshot.leakFailure && failedSnapshot.moves == level.budget)
            let failed: Core = failing
            #expect(failing.apply(Self.act("sun.set", [Double(level.sun)])) == stageCode)
            #expect(failing.apply(Self.act("play.redo")) == stageCode)
            #expect(failing == failed)
            #expect(failing.apply(Self.act("play.undo")) == .accepted)
            #expect(failing.play.stage == .playing && failing.outcome == nil)
            while failing.play.canUndo { #expect(failing.apply(Self.act("play.undo")) == .accepted) }
            #expect(try Self.digest(failing) == before)
            // The certified solution: won on its last action.
            for step in generated.solution.actions { #expect(core.apply(Self.act(step)) == .accepted) }
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "level \(number)")
            #expect(core.play.moves == generated.solution.smallest)
            let won: Core = core
            #expect(core.apply(Self.act("play.undo")) == stageCode)
            #expect(core.apply(Self.act("play.redo")) == stageCode)
            #expect(core.apply(Self.act("sun.set", [Double(level.sun)])) == stageCode)
            #expect(core == won)
            #expect(core.apply(Self.act("level.next")) == .accepted)
            let next: Int = number % 100 + 1
            #expect(core.play.stage == .playing && core.levelNumber == next && core.outcome == nil)
            core.reset()
            #expect(core.levelNumber == number && core.play.records.isEmpty && core.play.stage == .playing)
        }
    }

    @Test func aLeakFailsAndUndoRetries() async throws {
        // The first plant on level 100 (no leak allowed) that leaks into the forbidden ring.
        let core: Core = try Core.opening(number: 100)
        let before: StateDigest = try Self.digest(core)
        let level: NocturneGardenLevel = core.play.level
        var leaked: Core? = nil
        let size: Int = try #require(level.sizes.sorted().last)
        for kind in NocturneGardenKind.allCases where level.supplyCount(kind) > 0 && leaked == nil {
            for cell in 0..<level.cellCount where leaked == nil {
                var copy: Core = core
                let plant: ExperienceAction = Self.act(.plant(kind, cell % level.width, cell / level.width, size))
                if copy.apply(plant).isAccepted, case .leak = copy.play.failure { leaked = copy }
            }
        }
        var failed: Core = try #require(leaked)
        #expect(failed.play.failure == .leak(0) && failed.play.stage == .failed)
        #expect(failed.outcome?.code == Core.failedCode)
        let snapshot: NocturneGardenSceneSnapshot = failed.snapshot(time: 1)
        #expect(snapshot.leakFailure && !snapshot.leaking.isEmpty)
        #expect(snapshot.leaking == failed.play.mask.cells.intersection(level.forbidden).sorted())
        #expect(failed.apply(Self.act("sun.set", [2])) == .rejected(.rule(code: "r02-g09.stage")))
        #expect(failed.apply(Self.act("play.undo")) == .accepted)
        let retried: StateDigest = try Self.digest(failed)
        #expect(failed.play.stage == .playing && failed.play.failure == nil && retried == before)
    }

    @Test func nextLevelWrapsAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 40)
        #expect(core.levelNumber == 41)
        let sun: ExperienceAction = try #require(Self.neutralSun(core))
        #expect(core.apply(sun) == .accepted)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 42 && core.play.records.isEmpty && core.play.stage == .playing)
        core.reset()
        let fresh: Core = try await Core.prepare(seed: 40)
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
        let generated: NocturneGardenGenerated = try Core.generated(number: 32)
        // Every action of the solution but the last (none of them ends the play), then an undo.
        try #require(generated.solution.actions.count >= 2)
        for step in generated.solution.actions.dropLast() { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .playing)
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

        #expect(throws: NocturneGardenRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 31)
        }
        #expect(throws: NocturneGardenRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 31)
        }
        #expect(throws: NocturneGardenRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"32\",\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: NocturneGardenRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: NocturneGardenRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 31)
        }
        // The same records on another level: the first record's previous fingerprint is not that play's.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":1").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: NocturneGardenRestoreRefusal.kernel(.malformed("replay"))) {
            try Core.restore(payload: wrongLevel, seed: 31)
        }
        // A record of a newer schema: the replayed record (schema 1) differs from the stored one.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: NocturneGardenRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: newer, seed: 31)
        }
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 5)
        try engine.activate()
        let elevations: [Int] = try Core.level(number: 6).elevations.sorted()
        let opening: Int = try Core.level(number: 6).sun
        let target: Int = try #require(elevations.first { $0 != opening })
        #expect(engine.handle(control: "sun.set", values: [Double(target)]) == .accepted)
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

    @Test func theSnapshotMirrorsThePlay() async throws {
        // Level 1 after the first plant of its solution and a sun change: the snapshot copies the kernel exactly.
        var core: Core = try await Core.prepare(seed: 0)
        let generated: NocturneGardenGenerated = try Core.generated(number: 1)
        let first: NocturneGardenAction = try #require(generated.solution.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("sun.set", [3])) == .accepted)
        let play: NocturneGardenPlay = core.play
        let snapshot: NocturneGardenSceneSnapshot = core.snapshot(time: 2.5)
        #expect(snapshot.width == play.level.width && snapshot.height == play.level.height)
        #expect(snapshot.shadow == play.mask.cells.sorted() && !snapshot.shadow.isEmpty)
        #expect(snapshot.target == play.level.target.sorted() && snapshot.forbidden == play.level.forbidden.sorted())
        #expect(snapshot.blooms == play.blooms && snapshot.sun == 3 && snapshot.sun == play.elevation)
        #expect(snapshot.moves == 2 && snapshot.moves == play.moves && snapshot.budget == play.level.budget)
        #expect(snapshot.stage == play.stage && snapshot.failure == nil && snapshot.levelNumber == 1)
        #expect(snapshot.sizes == play.level.sizes.sorted() && snapshot.time == 2.5)
        #expect(core.snapshot(time: .nan).time == 0 && core.snapshot(time: .infinity) == core.snapshot(time: 0))
    }

    @Test func theTierAndTheSnapshotTimeNeverTouchTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: Self.fixtureSeed)
        let sun: ExperienceAction = try #require(Self.neutralSun(core))
        #expect(core.apply(sun) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let mist: [Int] = [3, 3, 2, 1, 1]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.mistLayers == mist[index])
            #expect(core.renderTier == NocturneGardenTier.of(clamped[index]))
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: NocturneGardenSceneSnapshot = core.snapshot(time: time)
            #expect(snapshot.stage == core.play.stage && snapshot.moves == core.play.moves)
            #expect(snapshot.levelNumber == core.levelNumber && snapshot.time.isFinite)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }
}
