// NocturneGardenExperienceCoreTests — feature 383 (R02-G09-03) T-R02G0903-005 (FR-R02G0903-005, 008, 009;
// clarifications Q4, Q5). The adapter core: the shared conformance checks pass; the declared controls, ids, tiers and
// profile; the seed picks level `seed % 100 + 1` deterministically in stage `playing` (seeds 0, 1, 99 and 100 give
// levels 1, 2, 100 and 1); every control is accepted when legal and refused with the state unchanged otherwise (the
// engine's range checks, `r02-g09.not-whole`, the kernel's `r02-g09.action`, `supply`, `noop` and `stage`); undo
// restores the earlier digest exactly and redo the later one; the certified solution wins, a leak and the budget fail,
// undo returns a failed play to playing; `level.next` wrapped 100 to 1 (feature 385: no longer) and reset returns; the
// snapshot round trip and refused payloads (damaged, level out of range, a trace of another level, a record of a newer
// schema, an envelope of a newer schema); the certified-candidate table equals the 100 stored witnesses' `skipped` and
// the directly certified levels equal the stored ones; `snapshot(time:)` mirrors the play. Fixture seed 2_383. Levels
// are certified once per process, so the run stays short. Explicit types, plain loops.
//
// Feature 385 (R02-G09-05) T-R02G0905-004: schema 2 and the progression controls — `level.select`, `mode.daily`,
// `mode.practice`, `mode.campaign` and `tutorial.dismiss` with their refusals (`r02-g09.locked`, `r02-g09.date`, wrong
// value counts); `level.next` moves to the next open level only (100 no longer wraps); a campaign win records stars by
// moves made (move-and-undo detours included) and opens the next level, a daily win opens nothing (a locked daily level
// is playable) and practice (budget 40, a fresh play) records nothing; `mode.campaign` returns; the tutorial is
// dismissed and advances on accepted moves, never back on undo, and is not digested; the schema-2 round trip, the
// migration of a schema-1 payload (directly and through the engine's migration chain), damaged progress or mode (a
// daily mode naming another level among them) refused and an envelope of a newer schema (3) refused. Fixture seed
// 2_385 for this feature.
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
    /// The fixture seed of feature 385.
    static let progressionSeed: UInt64 = 2_385

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
        // Levels 1 and 2: a sun change, undo and redo, another sun change, undo, a plant, then level.next (refused
        // since feature 385 while the next level is locked) and a sun change.
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
        #expect(Core.experienceID == "r02-g09.nocturne-garden" && Core.schemaVersion == 3)
        #expect(Core.digestDomain == "r02-g09.nocturne-garden.v3")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["bloom.plant", "bloom.move", "bloom.resize", "bloom.remove", "sun.set", "play.undo",
                             "play.redo", "level.next", "level.select", "mode.daily", "mode.practice",
                             "mode.campaign", "tutorial.dismiss", "replay.start", "replay.step", "replay.stop",
                             "settings.sound"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[13].ranges == [1...100] && Core.controls[16].ranges == [0...1])
        #expect(Core.controls[0].ranges == [0...5, 0...31, 0...23, 1...3])
        #expect(Core.controls[1].ranges == [0...11, 0...31, 0...23])
        #expect(Core.controls[2].ranges == [0...11, 1...3])
        #expect(Core.controls[3].ranges == [0...11])
        #expect(Core.controls[4].ranges == [1...4])
        #expect(Core.controls[8].ranges == [1...100])
        #expect(Core.controls[9].ranges == [1...9_999, 1...12, 1...31])
        let plainIndices: [Int] = [5, 6, 7, 10, 11, 12, 14, 15]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        for kind in NocturneGardenKind.allCases { #expect(Core.kind(kind.order) == kind) }
        #expect(Core.kind(-1) == nil && Core.kind(6) == nil)
        #expect(Core.qualityTiers == 3 && Core.migrations.currentVersion == 3)
        #expect(Core.practiceBudget == 40 && Core.practiceBudget == NocturneGardenMode.practiceBudget)
        #expect(NocturneGardenExperienceRule.locked == "r02-g09.locked")
        #expect(NocturneGardenExperienceRule.date == "r02-g09.date")
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
                                           Self.act("level.next"), Self.act("level.select", [2]),
                                           Self.act("level.select", [0]), Self.act("level.select", [1.5]),
                                           Self.act("level.select", []), Self.act("mode.daily", [2027, 2, 29]),
                                           Self.act("mode.daily", [2026, 13, 1]), Self.act("mode.daily", [2026, 4, 31]),
                                           Self.act("mode.daily", [2026, 1, 0]), Self.act("mode.daily", [2026, 11]),
                                           Self.act("mode.practice", [1]), Self.act("mode.campaign", [1]),
                                           Self.act("tutorial.dismiss", [1]), Self.act("nope")]
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
        #expect(probe.apply(Self.act("level.select", [])) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        #expect(probe.apply(Self.act("level.select", [1, 2])) == .rejected(.wrongValueCount(expected: 1, found: 2)))
        #expect(probe.apply(Self.act("level.select", [101])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("level.select", [0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("mode.daily", [2026, 11])) == .rejected(.wrongValueCount(expected: 3, found: 2)))
        #expect(probe.apply(Self.act("mode.daily", [2026, 13, 1])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("mode.daily", [2026, 1, 32])) == .rejected(.outOfRange(index: 2)))
        #expect(probe.apply(Self.act("mode.daily", [0, 1, 1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("mode.practice", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("mode.campaign", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("tutorial.dismiss", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        let locked: ActionResult = .rejected(.rule(code: NocturneGardenExperienceRule.locked))
        #expect(probe.apply(Self.act("level.next")) == locked)
        #expect(probe.apply(Self.act("level.select", [2])) == locked)
        let date: ActionResult = .rejected(.rule(code: NocturneGardenExperienceRule.date))
        #expect(probe.apply(Self.act("mode.daily", [2027, 2, 29])) == date)
        #expect(probe.apply(Self.act("mode.daily", [2026, 4, 31])) == date)
        #expect(probe.apply(Self.act("mode.daily", [2026, 2, 30])) == date)
        // Day 0 lies outside the declared day range 1 … 31: the engine refuses it before the calendar check.
        #expect(probe.apply(Self.act("mode.daily", [2026, 1, 0])) == .rejected(.outOfRange(index: 2)))
        let notWhole: ActionResult = .rejected(.rule(code: NocturneGardenExperienceRule.notWhole))
        #expect(probe.apply(Self.act("level.select", [1.5])) == notWhole)
        #expect(probe.apply(Self.act("mode.daily", [2026, 1, 1.5])) == notWhole)
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
            // Feature 385: the campaign win opened the next level; level 100 has none (no wrap).
            if number < 100 {
                #expect(core.progress.frontier == number + 1)
                #expect(core.apply(Self.act("level.next")) == .accepted)
                #expect(core.play.stage == .playing && core.levelNumber == number + 1 && core.outcome == nil)
            } else {
                #expect(core.progress.frontier == 100)
                #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: NocturneGardenExperienceRule.locked)))
            }
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

    /// Feature 385: `level.next` moves to the next open level only (a locked next level is refused, 100 does not wrap);
    /// a selected open level opens fresh; reset returns to the seed's opening state, progress included.
    @Test func nextLevelNeedsAnOpenLevelAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 40)
        #expect(core.levelNumber == 41 && core.progress.frontier == 41 && core.mode == .campaign)
        let sun: ExperienceAction = try #require(Self.neutralSun(core))
        #expect(core.apply(sun) == .accepted)
        let before: StateDigest = try Self.digest(core)
        let locked: ActionResult = .rejected(.rule(code: NocturneGardenExperienceRule.locked))
        let moved: Core = core
        #expect(core.apply(Self.act("level.next")) == locked)
        #expect(core.apply(Self.act("level.select", [42])) == locked)
        let lockedDigest: StateDigest = try Self.digest(core)
        #expect(core == moved && lockedDigest == before)
        #expect(core.apply(Self.act("level.select", [12])) == .accepted)
        #expect(core.levelNumber == 12 && core.play.records.isEmpty && core.mode == .campaign)
        let twelve: NocturneGardenLevel = try Core.level(number: 12)
        #expect(core.play.level == twelve && core.tutorial == .done)
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
        last.reset()
        #expect(last.levelNumber == 100)
    }

    /// Applies `actions` to `core`, each accepted, after `detours` detours of (the first action, undo); returns the
    /// moves made.
    static func win(_ core: inout Core, actions: [NocturneGardenAction], detours: Int) -> Int {
        guard let first = actions.first else { return 0 }
        for _ in 0..<detours {
            #expect(core.apply(Self.act(first)) == .accepted)
            #expect(core.play.stage == .playing)
            #expect(core.apply(Self.act("play.undo")) == .accepted)
        }
        for action in actions { #expect(core.apply(Self.act(action)) == .accepted) }
        #expect(core.play.stage == .won)
        return NocturneGardenProgress.movesMade(core.play)
    }

    /// Whether `result` has `movesMade` and `stars` and is verified with a non-empty trace (feature 387: a campaign win
    /// records its winning trace).
    static func isVerified(_ result: NocturneGardenProgress.Result?, movesMade: Int, stars: Int) -> Bool {
        guard let result else { return false }
        return result.movesMade == movesMade && result.stars == stars && result.verified && !result.trace.isEmpty
    }

    /// Feature 385 (clarification Q3): a campaign win records the moves made (undone moves included) and its stars,
    /// keeps the better result and opens the next level; since feature 387 with its verified trace.
    @Test func aCampaignWinRecordsStarsByMovesMade() throws {
        let first: NocturneGardenGenerated = try Core.generated(number: 1)
        let second: NocturneGardenGenerated = try Core.generated(number: 2)
        let smallest: Int = first.solution.smallest
        var core: Core = try Core.opening(number: 1)
        #expect(core.certifiedSmallest == smallest && core.progress.solved.isEmpty && core.progress.frontier == 1)
        // Two detours: smallest + 2 moves made, 2 stars; level 2 opens.
        let twoDetours: Int = Self.win(&core, actions: first.solution.actions, detours: 2)
        #expect(twoDetours == smallest + 2 && core.play.moves == smallest)
        #expect(Self.isVerified(core.progress.solved[1], movesMade: smallest + 2, stars: 2))
        #expect(core.progress.frontier == 2 && core.outcome?.code == Core.wonCode)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 2 && core.mode == .campaign && core.play.records.isEmpty)
        // Level 1 again without a detour: the better result (3 stars) replaces the stored one.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        let noDetour: Int = Self.win(&core, actions: first.solution.actions, detours: 0)
        #expect(noDetour == smallest)
        #expect(Self.isVerified(core.progress.solved[1], movesMade: smallest, stars: 3))
        // A worse result (three detours, 1 star) keeps it.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        let threeDetours: Int = Self.win(&core, actions: first.solution.actions, detours: 3)
        #expect(threeDetours == smallest + 3)
        #expect(Self.isVerified(core.progress.solved[1], movesMade: smallest, stars: 3))
        #expect(core.progress.frontier == 2)
        // Level 2 with three detours: 1 star; level 3 opens.
        #expect(core.apply(Self.act("level.next")) == .accepted)
        let secondMoves: Int = Self.win(&core, actions: second.solution.actions, detours: 3)
        #expect(Self.isVerified(core.progress.solved[2], movesMade: secondMoves, stars: 1))
        #expect(secondMoves == second.solution.smallest + 3 && core.progress.frontier == 3)
    }

    /// Feature 385 (clarification Q4): daily mode opens nothing and plays a locked level; practice is a fresh play with
    /// the budget 40 that records nothing; `mode.campaign` returns.
    @Test func dailyPracticeAndCampaignModes() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.mode == .campaign && core.progress.frontier == 1 && core.tutorial == .plant)
        let date: ActionResult = .rejected(.rule(code: NocturneGardenExperienceRule.date))
        let opening: Core = core
        #expect(core.apply(Self.act("mode.daily", [2027, 2, 29])) == date)
        #expect(core == opening)
        let daily: Int = try #require(NocturneGardenProgress.dailyLevel(year: 2026, month: 1, day: 2))
        #expect(daily == 72)
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 2])) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily && core.progress.frontier == 1)
        #expect(!core.progress.isOpen(daily) && core.tutorial == .done && core.play.records.isEmpty)
        let dailyCertified: NocturneGardenGenerated = try Core.generated(number: daily)
        #expect(core.play.level == dailyCertified.level && core.certifiedSmallest == dailyCertified.solution.smallest)
        // A daily win on a locked level records its stars but opens nothing.
        var dailyWin: Core = core
        _ = Self.win(&dailyWin, actions: dailyCertified.solution.actions, detours: 0)
        #expect(dailyWin.progress.solved[daily]?.stars == 3 && dailyWin.progress.frontier == 1)
        #expect(dailyWin.apply(Self.act("level.next")) == .rejected(.rule(code: NocturneGardenExperienceRule.locked)))
        // Practice of the daily level: the same level fresh with the budget 40.
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == daily && core.play.level.budget == Core.practiceBudget)
        // Campaign returns to the frontier when the current level is not open.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.tutorial == .plant)

        // Practice on level 1 after a move: a fresh play of the practice copy; a win records nothing, opens nothing.
        let certified: NocturneGardenGenerated = try Core.generated(number: 1)
        let sun: ExperienceAction = try #require(Self.neutralSun(core))
        #expect(core.apply(sun) == .accepted)
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.play.records.isEmpty && core.play.moves == 0 && core.play.stage == .playing)
        let practiced: NocturneGardenLevel = core.play.level
        #expect(practiced.budget == 40 && certified.level.budget < 40)
        #expect(practiced.target == certified.level.target && practiced.forbidden == certified.level.forbidden)
        #expect(practiced.supply == certified.level.supply && practiced.sizes == certified.level.sizes)
        #expect(practiced.elevations == certified.level.elevations && practiced.sun == certified.level.sun)
        #expect(practiced.required == certified.level.required && practiced.id == certified.level.id)
        #expect(practiced.leakAllowance == certified.level.leakAllowance && practiced.tutorial == certified.level.tutorial)
        #expect(core.tutorial == .plant && core.levelNumber == 1)
        #expect(core.snapshot(time: 0).budget == 40)
        _ = Self.win(&core, actions: certified.solution.actions, detours: 0)
        #expect(core.progress.solved.isEmpty && core.progress.frontier == 1)
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: NocturneGardenExperienceRule.locked)))
        // Campaign returns to level 1 with its certified budget, fresh.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.play.level == certified.level && core.play.records.isEmpty)
        #expect(core.levelNumber == 1 && core.progress.solved.isEmpty)
        // The progression seed: daily mode from level 86 (seed 2_385) to the date's level, practice keeps the level.
        var seeded: Core = try await Core.prepare(seed: Self.progressionSeed)
        #expect(seeded.levelNumber == 86 && seeded.progress.frontier == 86)
        #expect(seeded.apply(Self.act("mode.practice")) == .accepted)
        #expect(seeded.levelNumber == 86 && seeded.play.level.budget == 40 && seeded.mode == .practice)
        #expect(seeded.apply(Self.act("level.select", [86])) == .accepted)
        let eightySix: NocturneGardenLevel = try Core.level(number: 86)
        #expect(seeded.mode == .campaign && seeded.play.level == eightySix)
    }

    /// Feature 385 (clarification Q2): the tutorial starts on levels 1 … 3, advances on accepted moves, ends with the
    /// level, never moves back on undo or redo, can be dismissed, and is not part of the digest.
    @Test func theTutorialAdvancesIsDismissedAndIsNotDigested() async throws {
        for number in 1...3 {
            let generated: NocturneGardenGenerated = try Core.generated(number: number)
            var core: Core = try Core.opening(number: number)
            #expect(core.tutorial == .plant, "level \(number)")
            var seen: [NocturneGardenTutorialStep] = [core.tutorial]
            for action in generated.solution.actions {
                #expect(core.apply(Self.act(action)) == .accepted)
                if seen.last != core.tutorial { seen.append(core.tutorial) }
            }
            var expected: [NocturneGardenTutorialStep] = [.plant, .shape, .finish, .done]
            if generated.solution.actions.count == 2 { expected = [.plant, .shape, .done] }
            if generated.solution.actions.count == 1 { expected = [.plant, .done] }
            #expect(seen == expected, "level \(number): \(seen)")
            #expect(core.play.stage == .won && core.tutorial == .done)
        }
        let four: Core = try Core.opening(number: 4)
        #expect(four.tutorial == .done)
        // Undo and redo never move the step; the digest ignores the step.
        var core: Core = try Core.opening(number: 1)
        let fresh: Core = core
        let freshDigest: StateDigest = try Self.digest(fresh)
        let sun: ExperienceAction = try #require(Self.neutralSun(core))
        #expect(core.apply(sun) == .accepted)
        #expect(core.tutorial == .shape)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.tutorial == .shape && core.play.elevation == fresh.play.elevation)
        #expect(try Self.digest(core) == freshDigest)
        #expect(core != fresh)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(core.tutorial == .shape)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(sun) == .accepted)
        #expect(core.tutorial == .finish)
        // A failing end ends it: the budget spent on sun changes.
        var failing: Core = try Core.opening(number: 2)
        for _ in 0..<failing.play.level.budget {
            let change: ExperienceAction = try #require(Self.neutralSun(failing))
            #expect(failing.apply(change) == .accepted)
        }
        #expect(failing.play.stage == .failed && failing.tutorial == .done)
        // Dismissal ends it; later moves keep it ended; the digest is unchanged by the dismissal.
        var dismissed: Core = try await Core.prepare(seed: 0)
        let before: StateDigest = try Self.digest(dismissed)
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        let dismissedDigest: StateDigest = try Self.digest(dismissed)
        #expect(dismissed.tutorial == .done && dismissedDigest == before)
        #expect(dismissed.apply(sun) == .accepted)
        #expect(dismissed.tutorial == .done)
        var undismissed: Core = try await Core.prepare(seed: 0)
        #expect(undismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(undismissed.apply(sun) == .accepted && undismissed == dismissed)
        // Reopening a tutorial level restarts the tutorial at its initial step.
        #expect(dismissed.apply(Self.act("mode.campaign")) == .accepted)
        #expect(dismissed.tutorial == .plant)
    }

    /// Feature 385: a schema-1 payload migrates to schema 2 (the levels up to the saved level open, campaign mode, the
    /// tutorial at its initial step).
    @Test func aSchemaOnePayloadMigrates() throws {
        var core: Core = try Core.opening(number: 7)
        let sun: ExperienceAction = try #require(Self.neutralSun(core))
        #expect(core.apply(sun) == .accepted)
        let records: Data = try JSONEncoder().encode(core.play.records)
        let recordsText: String = String(decoding: records, as: UTF8.self)
        let schemaOne: String = "{\"level\":7,\"records\":" + recordsText + "}"
        let object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: Data(schemaOne.utf8)) as? [String: Any])
        let migrated: [String: Any] = try Core.migratedToSchemaTwo(object)
        #expect(migrated["tutorial"] == nil)
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
        #expect(tutorialLevel.levelNumber == 2 && tutorialLevel.tutorial == .plant)
        #expect(tutorialLevel.progress.frontier == 2)
        #expect(throws: NocturneGardenRestoreRefusal.damaged) {
            try Core.migratedToSchemaTwo(["level": "7"])
        }
        #expect(throws: NocturneGardenRestoreRefusal.damaged) {
            try Core.migratedToSchemaTwo(["level": 7])
        }
        #expect(Core.migrations.currentVersion == 3)
    }

    /// Feature 385: an engine restores a schema-1 envelope through the migration chain.
    @Test func theEngineMigratesASchemaOneEnvelope() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 4)
        try engine.activate()
        var expected: Core = try Core.opening(number: 5)
        let sun: ExperienceAction = try #require(Self.neutralSun(expected))
        #expect(engine.handle(control: sun.control, values: sun.values) == .accepted)
        let saved: ExperienceSnapshot = try engine.snapshot()
        #expect(expected.apply(sun) == .accepted)
        let records: String = String(decoding: try JSONEncoder().encode(expected.play.records), as: UTF8.self)
        let schemaOne: String = "{\"level\":5,\"records\":" + records + "}"
        let old = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: saved.seed,
                                         stepIndex: saved.stepIndex, digest: saved.digest,
                                         payload: Data(schemaOne.utf8))
        try engine.restore(old)
        #expect(try engine.digest() == saved.digest)
    }

    /// Feature 385: the digest carries the progress and the mode but never the tutorial step.
    @Test func theDigestCarriesProgressAndModeButNotTheTutorial() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        let base: StateDigest = try Self.digest(core)
        // Progress: a level-1 win and back to level 1 fresh differs from the opening only in progress.
        var won: Core = core
        _ = Self.win(&won, actions: try Core.generated(number: 1).solution.actions, detours: 0)
        #expect(won.apply(Self.act("level.select", [1])) == .accepted)
        #expect(won.play == core.play && won.mode == core.mode && won.progress != core.progress)
        #expect(try Self.digest(won) != base)
        // Mode: practice differs (its level is the practice copy); campaign back restores the digest.
        var practice: Core = core
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(try Self.digest(practice) != base)
        #expect(practice.apply(Self.act("mode.campaign")) == .accepted)
        #expect(try Self.digest(practice) == base && practice == core)
        // Tutorial: dismissing changes `==` but not the digest.
        var dismissed: Core = core
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        let dismissedDigest: StateDigest = try Self.digest(dismissed)
        #expect(dismissed != core && dismissedDigest == base)
        // The fixture seed of this feature: a reset returns the opening digest after progression actions.
        var seeded: Core = try await Core.prepare(seed: Self.progressionSeed)
        let seededDigest: StateDigest = try Self.digest(seeded)
        #expect(seeded.apply(Self.act("mode.daily", [2026, 11, 22])) == .accepted)
        #expect(try Self.digest(seeded) != seededDigest)
        seeded.reset()
        #expect(try Self.digest(seeded) == seededDigest && seeded.mode == .campaign)
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

        #expect(throws: NocturneGardenRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 31)
        }
        #expect(throws: NocturneGardenRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 31)
        }
        #expect(throws: NocturneGardenRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"32\",\"records\":[]}".utf8), seed: 31)
        }
        // A schema-1 payload is not a schema-2 one (it migrates only through the chain).
        #expect(throws: NocturneGardenRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":32,\"records\":[]}".utf8), seed: 31)
        }
        #expect(throws: NocturneGardenRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data(text.replacingOccurrences(of: "\"level\":32", with: "\"level\":0").utf8),
                             seed: 31)
        }
        #expect(throws: NocturneGardenRestoreRefusal.levelNumber(101)) {
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
            #expect(throws: NocturneGardenRestoreRefusal.damaged) {
                try Core.restore(payload: Data(variant.utf8), seed: 31)
            }
        }
        // A daily mode naming its own level restores (the level may be locked in the campaign).
        let dailyLevel: Int = try #require(NocturneGardenProgress.dailyLevel(year: 2026, month: 11, day: 22))
        var daily: Core = core
        #expect(daily.apply(Self.act("mode.daily", [2026, 11, 22])) == .accepted)
        #expect(daily.levelNumber == dailyLevel && daily.mode == .daily(level: dailyLevel))
        let dailyRestored: Core = try Core.restore(payload: try daily.snapshotPayload(), seed: 31)
        #expect(dailyRestored == daily && dailyRestored.certifiedSmallest == daily.certifiedSmallest)
        #expect(try Self.digest(dailyRestored) == Self.digest(daily))
        // A practice state round-trips with its budget.
        var practice: Core = core
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        let practiceSun: ExperienceAction = try #require(Self.neutralSun(practice))
        #expect(practice.apply(practiceSun) == .accepted)
        let practiceRestored: Core = try Core.restore(payload: try practice.snapshotPayload(), seed: 31)
        #expect(practiceRestored == practice && practiceRestored.play.level.budget == 40)
        #expect(try Self.digest(practiceRestored) == Self.digest(practice))
        // Progress with a won level and a tutorial step round-trip.
        var winner: Core = try Core.opening(number: 2)
        _ = Self.win(&winner, actions: try Core.generated(number: 2).solution.actions, detours: 1)
        let winnerRestored: Core = try Core.restore(payload: try winner.snapshotPayload(), seed: 1)
        #expect(winnerRestored == winner && winnerRestored.progress.solved[2]?.stars == 2)
        #expect(winnerRestored.progress.frontier == 3 && winnerRestored.tutorial == .done)
        var teaching: Core = try Core.opening(number: 3)
        let teachingSun: ExperienceAction = try #require(Self.neutralSun(teaching))
        #expect(teaching.apply(teachingSun) == .accepted && teaching.tutorial == .shape)
        let teachingRestored: Core = try Core.restore(payload: try teaching.snapshotPayload(), seed: 2)
        #expect(teachingRestored == teaching && teachingRestored.tutorial == .shape)
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

    /// Feature 387: a won campaign play records its effective moves as a verified result (an undone detour left out but
    /// counted in the moves made); replay plays the trace move by move, refuses other play actions, ends with replay-end
    /// and never changes progress; stop returns to campaign.
    @Test func replayPlaysTheStoredTraceAndChangesNothing() throws {
        var core: Core = try Core.opening(number: 1)
        let certified: NocturneGardenGenerated = try Core.generated(number: 1)
        let actions: [NocturneGardenAction] = certified.solution.actions
        #expect(core.apply(Self.act("replay.start", [1])) == .rejected(.rule(code: "r02-g09.no-replay")))
        #expect(core.apply(Self.act("replay.step")) == .rejected(.rule(code: "r02-g09.no-replay")))
        #expect(core.apply(Self.act("replay.stop")) == .rejected(.rule(code: "r02-g09.no-replay")))
        // A detour that is undone stays out of the trace but counts as a move made.
        #expect(core.apply(Self.act(actions[0])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        for action in actions { #expect(core.apply(Self.act(action)) == .accepted) }
        #expect(core.play.stage == .won)
        let result: NocturneGardenProgress.Result = try #require(core.progress.solved[1])
        #expect(result.verified && result.trace == actions && result.movesMade == actions.count + 1)
        let progress: NocturneGardenProgress = core.progress
        #expect(core.apply(Self.act("replay.start", [2])) == .rejected(.rule(code: "r02-g09.no-replay")))
        #expect(core.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(core.mode == .replay(level: 1) && core.tutorial == .done && core.play.records.isEmpty)
        let refusedControls: [String] = ["bloom.plant", "bloom.move", "bloom.resize", "bloom.remove", "sun.set",
                                         "play.undo", "play.redo", "level.next", "level.select", "mode.daily",
                                         "mode.practice", "mode.campaign"]
        let refusedValues: [[Double]] = [[0, 0, 0, 1], [0, 0, 0], [0, 1], [0], [1], [], [], [], [1], [2026, 11, 22],
                                         [], []]
        for index in refusedControls.indices {
            let before: Core = core
            #expect(core.apply(Self.act(refusedControls[index], refusedValues[index]))
                == .rejected(.rule(code: "r02-g09.replay")), "\(refusedControls[index])")
            #expect(core == before)
        }
        #expect(core.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted)
        var reference: NocturneGardenPlay = try Core.freshPlay(of: certified.level)
        for action in actions {
            #expect(core.apply(Self.act("replay.step")) == .accepted)
            try reference.apply(action, expecting: reference.fingerprint)
            #expect(core.play.fingerprint == reference.fingerprint)
        }
        #expect(core.play.stage == .won && core.progress == progress)
        #expect(core.outcome == ExperienceOutcome(code: Core.wonCode))
        #expect(core.apply(Self.act("replay.step")) == .rejected(.rule(code: "r02-g09.replay-end")))
        #expect(core.apply(Self.act("replay.step")) == .rejected(.rule(code: "r02-g09.replay-end")))
        // A saved replay round-trips.
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && restored.reconciliationDropped == 0)
        #expect(core.apply(Self.act("replay.stop")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.soundOn && core.progress == progress)
        #expect(core.play.records.isEmpty)
        #expect(core.apply(Self.act("replay.stop")) == .rejected(.rule(code: "r02-g09.no-replay")))
        // A replay stopped before its end returns to campaign with the progress unchanged.
        #expect(core.apply(Self.act("replay.start", [1])) == .accepted)
        #expect(core.apply(Self.act("replay.step")) == .accepted)
        #expect(core.apply(Self.act("replay.stop")) == .accepted)
        #expect(core.mode == .campaign && core.progress == progress)
    }

    /// Feature 387: the sound choice is snapshotted and in `==`, never in the digest; reset turns it off.
    @Test func theSoundChoiceIsSavedButNotDigested() throws {
        var core: Core = try Core.opening(number: 4)
        let before: StateDigest = try Self.digest(core)
        #expect(!core.soundOn)
        #expect(core.apply(Self.act("settings.sound", [1])) == .accepted && core.soundOn)
        #expect(try Self.digest(core) == before)
        #expect(core.apply(Self.act("settings.sound", [0.5])) == .rejected(.rule(code: "r02-g09.not-whole")))
        let payload: Data = try core.snapshotPayload()
        #expect(String(decoding: payload, as: UTF8.self).contains("\"sound\":true"))
        let restored: Core = try Core.restore(payload: payload, seed: 3)
        #expect(restored.soundOn && restored == core)
        var off: Core = core
        #expect(off.apply(Self.act("settings.sound", [0])) == .accepted && !off.soundOn)
        #expect(off != core)
        #expect(try Self.digest(off) == before)
        core.reset()
        #expect(!core.soundOn)
    }

    /// A schema-2 object (as feature 385 wrote it: results without `trace` or `verified`) of level 3 with level 1 won
    /// with 4 moves made (smallest 3: 2 stars) and the frontier at 5.
    static func schemaTwoObject() throws -> [String: Any] {
        var progress: NocturneGardenProgress = NocturneGardenProgress()
        progress.record(level: 1, movesMade: 4, smallest: 3, mode: .campaign)
        progress.open(through: 5)
        var progressObject: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: try Core.payloadEncoder().encode(progress)) as? [String: Any])
        var solved: [[String: Any]] = try #require(progressObject["solved"] as? [[String: Any]])
        for index in solved.indices {
            solved[index].removeValue(forKey: "trace")
            solved[index].removeValue(forKey: "verified")
        }
        progressObject["solved"] = solved
        return ["level": 3, "records": [Any](), "progress": progressObject, "mode": ["mode": "campaign"],
                "tutorial": "done"]
    }

    /// Feature 387: a schema-2 object migrates to schema 3 (empty traces, unverified, sound off) and restores with its
    /// progress; a schema-1 object migrates through 2 to 3; the engine restores schema-1 and schema-2 envelopes.
    @Test func schemaOneAndTwoMigrateToThree() async throws {
        let two: [String: Any] = try Self.schemaTwoObject()
        let three: [String: Any] = try Core.migratedToSchemaThree(two)
        #expect(three["sound"] as? Bool == false)
        let progressThree: [String: Any] = try #require(three["progress"] as? [String: Any])
        let solvedThree: [[String: Any]] = try #require(progressThree["solved"] as? [[String: Any]])
        #expect(solvedThree.count == 1 && solvedThree[0]["verified"] as? Bool == false)
        #expect((solvedThree[0]["trace"] as? [Any])?.isEmpty == true)
        let restored: Core = try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: three, options: [.sortedKeys]), seed: 2)
        #expect(restored.progress.frontier == 5 && restored.reconciliationDropped == 0)
        #expect(restored.progress.solved[1] == NocturneGardenProgress.Result(movesMade: 4, stars: 2))
        #expect(!restored.soundOn && restored.levelNumber == 3 && restored.mode == .campaign)
        #expect(throws: NocturneGardenRestoreRefusal.damaged) { try Core.migratedToSchemaThree(["level": 1]) }
        #expect(throws: NocturneGardenRestoreRefusal.damaged) {
            try Core.migratedToSchemaThree(["level": 1, "progress": ["frontier": 1]])
        }
        // 1 → 3: no won levels, the levels up to the saved level open, campaign, sound off.
        let one: [String: Any] = ["level": 6, "records": [Any]()]
        let oneToThree: [String: Any] = try Core.migratedToSchemaThree(try Core.migratedToSchemaTwo(one))
        let fromOne: Core = try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: oneToThree, options: [.sortedKeys]), seed: 0)
        #expect(fromOne.levelNumber == 6 && fromOne.progress.frontier == 6 && fromOne.progress.solved.isEmpty)
        #expect(!fromOne.soundOn && fromOne.mode == .campaign && fromOne.reconciliationDropped == 0)
        // The engine applies the chain to schema-1 and schema-2 envelopes.
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 2)
        try engine.activate()
        let saved: ExperienceSnapshot = try engine.snapshot()
        let twoData: Data = try JSONSerialization.data(withJSONObject: two, options: [.sortedKeys])
        let envelopeTwo = try ExperienceSnapshot(experience: id, schemaVersion: 2, seed: saved.seed,
                                                 stepIndex: saved.stepIndex, digest: try Self.digest(restored),
                                                 payload: twoData)
        try engine.restore(envelopeTwo)
        #expect(try engine.digest() == Self.digest(restored))
        let oneData: Data = try JSONSerialization.data(withJSONObject: one, options: [.sortedKeys])
        let envelopeOne = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: saved.seed,
                                                 stepIndex: saved.stepIndex, digest: try Self.digest(fromOne),
                                                 payload: oneData)
        try engine.restore(envelopeOne)
        #expect(try engine.digest() == Self.digest(fromOne))
    }

    /// Feature 387: an edited verified result is dropped on restore and counted, the frontier kept as saved; an honest
    /// one survives; a saved replay of a dropped result returns to campaign at that level.
    @Test func editedResultsAreDroppedOnRestore() throws {
        let certified: NocturneGardenGenerated = try Core.generated(number: 2)
        let trace: [NocturneGardenAction] = certified.solution.actions
        let smallest: Int = certified.solution.smallest
        var honest: NocturneGardenProgress = NocturneGardenProgress()
        honest.open(through: 7)
        honest.record(level: 2, movesMade: trace.count, smallest: smallest, trace: trace)
        var edited: NocturneGardenProgress = honest
        // The same trace claimed with one move fewer than it holds.
        edited.drop(level: 2)
        edited.record(level: 2, movesMade: trace.count - 1, smallest: smallest, trace: trace)
        var core: Core = try Core.opening(number: 2)
        #expect(core.apply(Self.act(trace[0])) == .accepted)
        var object: [String: Any] = try #require(
            try JSONSerialization.jsonObject(with: try core.snapshotPayload()) as? [String: Any])
        object["progress"] = try JSONSerialization.jsonObject(with: try Core.payloadEncoder().encode(honest))
        let kept: Core = try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), seed: 1)
        #expect(kept.reconciliationDropped == 0 && kept.progress == honest)
        object["progress"] = try JSONSerialization.jsonObject(with: try Core.payloadEncoder().encode(edited))
        let checked: Core = try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), seed: 1)
        #expect(checked.reconciliationDropped == 1 && checked.progress.solved[2] == nil)
        #expect(checked.progress.frontier == 7 && checked.play == core.play)
        // The dropped count is not state: not in the digest or `==`.
        #expect(try Self.digest(checked) == Self.digest(try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), seed: 1)))
        // A saved replay of the edited result: the result is dropped, so the restore is campaign at level 2.
        object["mode"] = ["mode": "replay", "level": 2]
        object["records"] = [Any]()
        let replay: Core = try Core.restore(
            payload: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]), seed: 1)
        #expect(replay.mode == .campaign && replay.levelNumber == 2 && replay.reconciliationDropped == 1)
        // A replay mode naming another level is damaged.
        object["mode"] = ["mode": "replay", "level": 3]
        #expect(throws: NocturneGardenRestoreRefusal.damaged) {
            try Core.restore(payload: try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
                             seed: 1)
        }
    }
}
