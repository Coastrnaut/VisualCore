// EchoCartographerExperienceCoreTests — feature 403 (R02-G11-03) T-R02G1103-005 (FR-R02G1103-003, 005; clarifications
// Q4, Q5). The adapter core: the shared conformance checks pass; the declared controls, ids, tiers and profile; the seed
// picks level `seed % 100 + 1` deterministically in stage `playing` (seeds 0, 1, 99 and 100 give levels 1, 2, 100 and
// 1); every control is accepted when legal and refused with the state unchanged otherwise (the engine's range checks,
// `r02-g11.not-whole`, and every kernel refusal the adapter can meet passing through with its code: `r02-g11.action`,
// `noop` and `stage`; `stale` cannot arise because every cell action names the current fingerprint); undo restores the
// earlier digest exactly and redo the later one; the certified witness wins, misses spend the energy and fail, undo
// returns a failed play to playing; `level.next` wraps 100 to 1 and reset returns; the snapshot round trip and refused
// payloads (damaged, level out of range, a trace of another level, a record of a newer schema, an edited trace, an
// envelope of a newer schema); the certified-candidate table equals the 100 stored witnesses' `skipped` and the
// directly certified levels equal the stored ones (level fingerprint); `snapshot(time:)` mirrors what the player knows.
// Feature 405 (R02-G11-05) T-R02G1105-004: schema 2 and digest v2; eleven controls; `level.next` to the next open level
// (refused with `r02-g11.locked` when none, no wrap); the progression controls (`level.select`, `mode.daily`,
// `mode.practice`, `mode.campaign`, `tutorial.dismiss`) with their refusals; a campaign win records stars and opens the
// next level, a daily win opens nothing, practice records nothing; progress and mode in the digest, the tutorial step
// in the snapshot but not the digest; the migration of a schema-1 payload.
// Fixture seed 2_403. Levels are certified once per process, so the run stays short. Explicit types, plain loops.
import Foundation
import Testing
@testable import EchoCartographerCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

/// The repository's witness directory, found from this file.
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/echo-cartographer/levels", isDirectory: true)

@Suite struct EchoCartographerExperienceCoreTests {
    typealias Core = EchoCartographerExperienceCore

    /// The fixture seed of this feature.
    static let fixtureSeed: UInt64 = 2_403

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
    static func act(_ action: EchoCartographerAction) -> ExperienceAction {
        switch action {
        case let .pulse(x, y): act("cell.pulse", [Double(x), Double(y)])
        case let .claim(x, y): act("cell.claim", [Double(x), Double(y)])
        case let .mark(x, y): act("cell.mark", [Double(x), Double(y)])
        }
    }

    /// A claim cell of `level` that misses every beacon (farther than the tolerance from each) and is no known wall
    /// in `play`; nil when there is none.
    static func missCell(_ level: EchoCartographerLevel, _ play: EchoCartographerPlay) -> EchoCartographerCell? {
        for y in 0..<level.chamber.height {
            for x in 0..<level.chamber.width {
                let cell = EchoCartographerCell(x: x, y: y)
                if play.knowledge[cell] == .wall { continue }
                var far: Bool = true
                for beacon in level.beacons where cell.distance(to: beacon) <= level.tolerance { far = false }
                if far { return cell }
            }
        }
        return nil
    }

    /// The stored witness of level `number`, read with the plain decoder.
    static func storedWitness(_ number: Int) throws -> EchoCartographerWitness {
        let name: String = String(EchoCartographerGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: coreWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(EchoCartographerWitness.self, from: data)
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 2 (then 2 and 3): marks, a pulse from level 1's entry, undo and redo, level.next and a mark.
        // No action ends a play (marks are free; one pulse leaves energy).
        let actions: [ScriptedAction] = [ScriptedAction("cell.mark", [1, 1]), ScriptedAction("cell.pulse", [0, 3]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("cell.mark", [2, 2]), ScriptedAction("play.undo"),
                                         ScriptedAction("level.next"), ScriptedAction("cell.mark", [0, 0])]
        // Refused on the openings of levels 1 and 2 (6 × 6 and at most 9 × 9; only the entry is known).
        let rejected: [ScriptedAction] = [ScriptedAction("cell.pulse", [16, 0]),
                                          ScriptedAction("cell.claim", [0, 16]),
                                          ScriptedAction("cell.mark", [0.5, 1]),
                                          ScriptedAction("cell.pulse", [0]),
                                          ScriptedAction("cell.pulse", [15, 15]),
                                          ScriptedAction("cell.claim", [15, 0]),
                                          ScriptedAction("cell.mark", [0, 15]),
                                          ScriptedAction("cell.pulse", [5, 5]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 1], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries { #expect(entry.passed, "\(entry.check): \(entry.detail)") }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g11.echo-cartographer" && Core.schemaVersion == 2)
        #expect(Core.digestDomain == "r02-g11.echo-cartographer.v2")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["cell.pulse", "cell.claim", "cell.mark", "play.undo", "play.redo", "level.next",
                             "level.select", "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss"]
        #expect(Core.actionIDs == ids)
        let cellIndices: [Int] = [0, 1, 2]
        for index in cellIndices { #expect(Core.controls[index].ranges == [0...15, 0...15]) }
        let plainIndices: [Int] = [3, 4, 5, 8, 9, 10]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.controls[6].ranges == [1...100])
        #expect(Core.controls[7].ranges == [1...9999, 1...12, 1...31])
        #expect(Core.qualityTiers == 3 && Core.migrations.currentVersion == 2)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == EchoCartographerTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 0.5, 0] && iterations == [1, 0.5, 0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(EchoCartographerExperienceRule.notWhole == "r02-g11.not-whole")
        #expect(Core.wonCode == "won" && Core.failedCode == "failed")
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
            let expected: EchoCartographerLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.knowledge == expected.openingKnowledge)
            // The tutorial (levels 1 … 3) is dismissed by the adapter: the play opens in stage playing.
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.play.energy == expected.energy && first.qualityTier == 0)
        }
        #expect(try Core.level(number: 1).tutorial && !(try Core.level(number: 100).tutorial))
        #expect(Core.levelNumber(forSeed: Self.fixtureSeed) == 4)
        #expect(throws: EchoCartographerError.level("number")) { try Core.level(number: 0) }
        #expect(throws: EchoCartographerError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableEqualsTheWitnessesAndCertifiesTheStoredLevels() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for number in 1...100 {
            let witness: EchoCartographerWitness = try Self.storedWitness(number)
            #expect(witness.number == number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "level \(number)")
        }
        // Directly certified levels equal the stored witness levels and actions.
        let numbers: [Int] = [1, 6, 57, 100]
        for number in numbers {
            let witness: EchoCartographerWitness = try Self.storedWitness(number)
            let generated: EchoCartographerGenerated = try Core.generated(number: number)
            #expect(generated.level.fingerprint == witness.level.fingerprint, "level \(number)")
            #expect(generated.level == witness.level && generated.actions == witness.actions)
            #expect(generated.skipped == witness.skipped && generated.difficulty == witness.difficulty)
            #expect(generated.entry == EchoCartographerManifest.entries[number - 1])
            // The candidate just before the certified one does not certify (the generator skipped it).
            if witness.skipped > 0 {
                let entry: EchoCartographerManifestEntry = EchoCartographerManifest.entries[number - 1]
                #expect(Core.certify(entry, index: witness.skipped - 1) == nil, "level \(number)")
            }
        }
        // The generator itself gives the same level as the direct certification.
        let entry: EchoCartographerManifestEntry = EchoCartographerManifest.entries[5]
        #expect(try EchoCartographerGenerator.generate(entry) == Core.generated(number: 6))
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: 6 × 6, entry (0, 3), one beacon at (1, 2), tolerance 1, energy 9, miss cost 1.
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let illegal: [ExperienceAction] = [Self.act("cell.pulse", [16, 0]), Self.act("cell.pulse", [-1, 0]),
                                           Self.act("cell.claim", [0, 16]), Self.act("cell.mark", [0.5, 2]),
                                           Self.act("cell.pulse", [0, .nan]), Self.act("cell.pulse", [0]),
                                           Self.act("cell.mark", [0, 1, 2]), Self.act("cell.pulse", [6, 0]),
                                           Self.act("cell.claim", [0, 6]), Self.act("cell.mark", [15, 15]),
                                           Self.act("cell.pulse", [1, 1]), Self.act("play.undo"),
                                           Self.act("play.redo"), Self.act("play.undo", [1]),
                                           Self.act("level.next", [1]), Self.act("nope")]
        for action in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(action)
            #expect(!result.isAccepted, "\(action.control) \(action.values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.isEmpty, "\(action.control)")
        }
        var probe: Core = core
        // Outside the declared ranges or the value count: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.act("cell.pulse", [16, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("cell.pulse", [-1, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("cell.claim", [0, 16])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("cell.pulse", [0, .nan])) == .rejected(.nonFinite(index: 1)))
        #expect(probe.apply(Self.act("cell.pulse", [0])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("play.undo", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        #expect(probe.apply(Self.act("level.next", [1])) == .rejected(.wrongValueCount(expected: 0, found: 1)))
        let notWhole: ActionResult = .rejected(.rule(code: EchoCartographerExperienceRule.notWhole))
        #expect(probe.apply(Self.act("cell.mark", [0.5, 2])) == notWhole)
        #expect(probe.apply(Self.act("cell.claim", [0, 2.25])) == notWhole)
        // Every kernel refusal the adapter can meet passes through with its reason code.
        let action: ActionResult = .rejected(.rule(code: EchoCartographerError.action("cell").reasonCode))
        let noop: ActionResult = .rejected(.rule(code: EchoCartographerError.noop.reasonCode))
        let stage: ActionResult = .rejected(.rule(code: EchoCartographerError.stage.reasonCode))
        #expect(action == .rejected(.rule(code: "r02-g11.action")) && noop == .rejected(.rule(code: "r02-g11.noop")))
        #expect(stage == .rejected(.rule(code: "r02-g11.stage")))
        #expect(probe.apply(Self.act("cell.pulse", [6, 0])) == action)      // outside the chamber
        #expect(probe.apply(Self.act("cell.claim", [0, 6])) == action)      // outside the chamber
        #expect(probe.apply(Self.act("cell.mark", [15, 15])) == action)     // outside the chamber
        #expect(probe.apply(Self.act("cell.pulse", [1, 1])) == action)      // not known open
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe.apply(Self.act("nope")) == .rejected(.unknownControl("nope")))
        #expect(probe == core)

        // A pulse from the entry spends one and reveals walls; a claim on a revealed wall is refused.
        #expect(core.apply(Self.act("cell.pulse", [0, 3])) == .accepted)
        #expect(core.play.energy == 8 && core.play.records.count == 1 && core.play.stage == .playing)
        #expect(core.play.lastEcho?.emitter == EchoCartographerCell(x: 0, y: 3))
        #expect(try Self.digest(core) != opening)
        var wall: EchoCartographerCell? = nil
        for index in 0..<core.play.level.chamber.cellCount where wall == nil && core.play.knowledge[index] == .wall {
            wall = core.play.level.chamber.cell(index)
        }
        let known: EchoCartographerCell = try #require(wall)
        #expect(core.play.level.chamber.isWall(known))
        let pulsed: Core = core
        #expect(core.apply(Self.act("cell.claim", [Double(known.x), Double(known.y)])) == action)
        #expect(core == pulsed)
        // Markers toggle for free; a ninth is refused.
        var marking: Core = core
        for x in 0..<6 { #expect(marking.apply(Self.act("cell.mark", [Double(x), 0])) == .accepted) }
        for x in 0..<2 { #expect(marking.apply(Self.act("cell.mark", [Double(x), 5])) == .accepted) }
        #expect(marking.play.markers.count == 8 && marking.play.energy == 8)
        #expect(marking.apply(Self.act("cell.mark", [2, 5])) == action)
        #expect(marking.apply(Self.act("cell.mark", [0, 0])) == .accepted)
        #expect(marking.play.markers.count == 7)

        // The noop refusal: a second claim on a located beacon of a level with several beacons (level 100).
        var several: Core = try Core.opening(number: 100)
        let beacon: EchoCartographerCell = several.play.level.beacons[0]
        #expect(several.play.level.beacons.count >= 2)
        let claim: ExperienceAction = Self.act("cell.claim", [Double(beacon.x), Double(beacon.y)])
        #expect(several.apply(claim) == .accepted)
        #expect(several.play.located.count == 1 && several.play.stage == .playing)
        let located: Core = several
        #expect(several.apply(claim) == noop)
        #expect(several == located)

        // The stage refusal: a won play refuses everything but level.next.
        var won: Core = try Core.opening(number: 1)
        let generated: EchoCartographerGenerated = try Core.generated(number: 1)
        for step in generated.actions { #expect(won.apply(Self.act(step)) == .accepted) }
        #expect(won.play.stage == .won && won.outcome?.code == Core.wonCode)
        let final: Core = won
        #expect(won.apply(Self.act("cell.pulse", [0, 3])) == stage)
        #expect(won.apply(Self.act("cell.claim", [0, 0])) == stage)
        #expect(won.apply(Self.act("cell.mark", [0, 0])) == stage)
        #expect(won.apply(Self.act("play.undo")) == stage)
        #expect(won.apply(Self.act("play.redo")) == stage)
        #expect(won == final)
        #expect(won.apply(Self.act("level.next")) == .accepted)
        #expect(won.levelNumber == 2 && won.play.stage == .playing)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let startDigest: StateDigest = try Self.digest(core)
        let start: EchoCartographerPlay = core.play
        let steps: [ExperienceAction] = [Self.act("cell.pulse", [0, 3]), Self.act("cell.mark", [4, 4]),
                                         Self.act("cell.claim", [5, 5])]
        for step in steps { #expect(core.apply(step) == .accepted) }
        let moved: Core = core
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest && core.play.stage == .playing && core.play.energy == 7)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(core.play.knowledge == start.knowledge && core.play.energy == start.energy)
        #expect(core.play.markers.isEmpty && core.play.stage == .playing)
        #expect(try Self.digest(core) == startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.redo")) == .accepted) }
        #expect(core.play.knowledge == moved.play.knowledge && core.play.energy == 7)
        #expect(core.play.records.count == 9)
        #expect(try Self.digest(core) == movedDigest)
        // A new action clears the redo history.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("cell.mark", [1, 0])) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g11.action")))
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(try Self.digest(core) == startDigest)
    }

    @Test func theWitnessWinsMissesFailAndUndoRetries() async throws {
        let numbers: [Int] = [1, 21, 41]
        let stageCode: ActionResult = .rejected(.rule(code: "r02-g11.stage"))
        for number in numbers {
            let generated: EchoCartographerGenerated = try Core.generated(number: number)
            let level: EchoCartographerLevel = generated.level
            var core: Core = try Core.opening(number: number)
            var failing: Core = core
            let before: StateDigest = try Self.digest(failing)
            let miss: EchoCartographerCell = try #require(Self.missCell(level, failing.play))
            let missAction: ExperienceAction = Self.act("cell.claim", [Double(miss.x), Double(miss.y)])
            var count: Int = 0
            while failing.play.stage == .playing && count < 64 {
                #expect(failing.apply(missAction) == .accepted)
                count += 1
            }
            #expect(failing.play.stage == .failed && failing.play.failure == .energy(count - 1), "level \(number)")
            #expect(failing.play.energy == 0 && failing.outcome?.code == Core.failedCode)
            let failedSnapshot: EchoCartographerSceneSnapshot = failing.snapshot(time: 0)
            #expect(failedSnapshot.stage == .failed && failedSnapshot.failure == .energy(count - 1))
            #expect(failedSnapshot.energy == 0 && failedSnapshot.budget == level.energy)
            let failed: Core = failing
            #expect(failing.apply(missAction) == stageCode)
            #expect(failing.apply(Self.act("play.redo")) == stageCode)
            #expect(failing == failed)
            #expect(failing.apply(Self.act("play.undo")) == .accepted)
            #expect(failing.play.stage == .playing && failing.outcome == nil)
            while failing.play.canUndo { #expect(failing.apply(Self.act("play.undo")) == .accepted) }
            #expect(try Self.digest(failing) == before)
            // The certified witness: won on its last action.
            for step in generated.actions { #expect(core.apply(Self.act(step)) == .accepted) }
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "level \(number)")
            #expect(core.play.located.count == level.beacons.count)
            #expect(core.apply(Self.act("level.next")) == .accepted)
            let next: Int = number % 100 + 1
            #expect(core.play.stage == .playing && core.levelNumber == next && core.outcome == nil)
            core.reset()
            #expect(core.levelNumber == number && core.play.records.isEmpty && core.play.stage == .playing)
        }
    }

    @Test func nextLevelOpensOnlyAfterAWinAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 40)
        #expect(core.levelNumber == 41 && core.progress.frontier == 41)
        #expect(core.apply(Self.act("cell.mark", [0, 0])) == .accepted)
        let before: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: EchoCartographerExperienceRule.locked)))
        #expect(try Self.digest(core) == before)
        core.reset()
        for step in try Core.generated(number: 41).actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.frontier == 42)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 42 && core.play.records.isEmpty && core.play.stage == .playing)
        core.reset()
        let fresh: Core = try await Core.prepare(seed: 40)
        let resetDigest: StateDigest = try Self.digest(core)
        let freshDigest: StateDigest = try Self.digest(fresh)
        #expect(core == fresh && resetDigest == freshDigest)
        // No wrap: after winning level 100 there is no next open level.
        var last: Core = try Core.opening(number: 100)
        for step in try Core.generated(number: 100).actions { #expect(last.apply(Self.act(step)) == .accepted) }
        #expect(last.play.stage == .won)
        #expect(last.apply(Self.act("level.next")) == .rejected(.rule(code: EchoCartographerExperienceRule.locked)))
        last.reset()
        #expect(last.levelNumber == 100)
    }

    @Test func theProgressionControlsFollowTheirRules() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let locked: ActionResult = .rejected(.rule(code: EchoCartographerExperienceRule.locked))
        // level.select: only open levels.
        #expect(core.apply(Self.act("level.select", [2])) == locked)
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        // The tutorial of level 1: pulse first; dismiss ends it and is not digested.
        #expect(core.tutorial == .pulse)
        let tutorialDigest: StateDigest = try Self.digest(core)
        var dismissed: Core = core
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed.tutorial == .done && dismissed != core)
        #expect(try Self.digest(dismissed) == tutorialDigest)
        // A campaign win of level 1: three stars at the certified energy, the tutorial done, level 2 open.
        let generated: EchoCartographerGenerated = try Core.generated(number: 1)
        let first: EchoCartographerAction = try #require(generated.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.tutorial == .narrow)
        for step in generated.actions.dropFirst() { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.tutorial == .done)
        let result: EchoCartographerProgress.Result = try #require(core.progress.solved[1])
        #expect(result.energySpent == generated.plan.pulses.count && result.stars == 3)
        #expect(core.progress.frontier == 2)
        #expect(core.apply(Self.act("level.select", [2])) == .accepted && core.levelNumber == 2)
        // Practice: the energy raised to 60, a win records nothing.
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.play.energy == Core.practiceEnergy && core.levelNumber == 2)
        let practiceProgress: EchoCartographerProgress = core.progress
        for step in try Core.generated(number: 2).actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress == practiceProgress)
        // Campaign returns to the current level when it is open.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 2 && core.play.records.isEmpty)
        // Daily: an impossible date is refused; a daily level still locked is playable and a win opens nothing.
        let dateRefused: ActionResult = .rejected(.rule(code: EchoCartographerExperienceRule.date))
        let beforeDate: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("mode.daily", [2026, 2, 30])) == dateRefused)
        #expect(try Self.digest(core) == beforeDate)
        let daily: Int = try #require(EchoCartographerProgress.dailyLevel(year: 2026, month: 11, day: 23))
        #expect(core.apply(Self.act("mode.daily", [2026, 11, 23])) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily)
        let frontier: Int = core.progress.frontier
        for step in try Core.generated(number: daily).actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.frontier == frontier)
        #expect(core.progress.solved[daily] != nil)
        // Progress and mode are digested: the same play in another mode digests differently.
        var campaign: Core = try await Core.prepare(seed: 0)
        var practice: Core = campaign
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(campaign.apply(Self.act("mode.campaign")) == .accepted)
        #expect(try Self.digest(practice) != (try Self.digest(campaign)))
    }

    @Test func aSchemaOnePayloadMigrates() async throws {
        var core: Core = try await Core.prepare(seed: 2)
        let generated: EchoCartographerGenerated = try Core.generated(number: 3)
        let first: EchoCartographerAction = try #require(generated.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        let encoder: JSONEncoder = Core.payloadEncoder()
        let records: Data = try encoder.encode(core.play.records)
        let recordsObject: Any = try JSONSerialization.jsonObject(with: records)
        let schemaOne: [String: Any] = ["level": 3, "records": recordsObject]
        let migrated: [String: Any] = try Core.migratedToSchemaTwo(schemaOne)
        let data: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
        let restored: Core = try Core.restore(payload: data, seed: 2)
        #expect(restored.levelNumber == 3 && restored.play == core.play && restored.mode == .campaign)
        #expect(restored.progress.frontier == 3 && restored.progress.solved.isEmpty)
        #expect(restored.tutorial == EchoCartographerTutorialStep.initial(level: 3))
        #expect(throws: EchoCartographerRestoreRefusal.damaged) {
            try Core.migratedToSchemaTwo(["level": "3"])
        }
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        var core: Core = try await Core.prepare(seed: 20)
        let generated: EchoCartographerGenerated = try Core.generated(number: 21)
        // Every action of the witness but the last (none of them ends the play), a mark, then an undo.
        try #require(generated.actions.count >= 2)
        for step in generated.actions.dropLast() { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.apply(Self.act("cell.mark", [0, 0])) == .accepted)
        #expect(core.play.stage == .playing)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let payload: Data = try core.snapshotPayload()
        #expect(try core.snapshotPayload() == payload)
        let text: String = try #require(String(data: payload, encoding: .utf8))
        #expect(text.hasPrefix("{\"level\":21,\"mode\":{\"mode\":\"campaign\"},\"progress\":"))
        let restored: Core = try Core.restore(payload: payload, seed: 20)
        let restoredDigest: StateDigest = try Self.digest(restored)
        let savedDigest: StateDigest = try Self.digest(core)
        #expect(restored == core && restoredDigest == savedDigest)
        #expect(restored.play.canRedo && restored.openingNumber == 21)
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

        #expect(throws: EchoCartographerRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 20)
        }
        #expect(throws: EchoCartographerRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 20)
        }
        #expect(throws: EchoCartographerRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"21\",\"records\":[]}".utf8), seed: 20)
        }
        let levelZero: Data = Data(text.replacingOccurrences(of: "\"level\":21", with: "\"level\":0").utf8)
        #expect(throws: EchoCartographerRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: levelZero, seed: 20)
        }
        let levelBeyond: Data = Data(text.replacingOccurrences(of: "\"level\":21", with: "\"level\":101").utf8)
        #expect(throws: EchoCartographerRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: levelBeyond, seed: 20)
        }
        // The same records on another level: the records carry level 21's seed.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":21", with: "\"level\":1").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: EchoCartographerRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: wrongLevel, seed: 20)
        }
        // A record of a newer schema.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: EchoCartographerRestoreRefusal.kernel(.malformed("schema 0"))) {
            try Core.restore(payload: newer, seed: 20)
        }
        // A trace that no longer replays: an edited next fingerprint.
        let first: EchoCartographerRecord = try #require(core.play.records.first)
        let edited: Data = Data(text.replacingOccurrences(of: first.next, with: String(repeating: "0", count: 64)).utf8)
        #expect(edited != payload)
        var editedRefused: Bool = false
        do {
            _ = try Core.restore(payload: edited, seed: 20)
        } catch let refusal as EchoCartographerRestoreRefusal {
            if case .kernel(.malformed) = refusal { editedRefused = true }
        }
        #expect(editedRefused)
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 5)
        try engine.activate()
        #expect(engine.handle(control: "cell.mark", values: [0, 1]) == .accepted)
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

    @Test func theSnapshotMirrorsWhatThePlayerKnows() async throws {
        // Level 1 after the first pulse of its witness and a marker: the snapshot copies the known state exactly.
        var core: Core = try await Core.prepare(seed: 0)
        let generated: EchoCartographerGenerated = try Core.generated(number: 1)
        let first: EchoCartographerAction = try #require(generated.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("cell.mark", [5, 0])) == .accepted)
        let play: EchoCartographerPlay = core.play
        let level: EchoCartographerLevel = play.level
        let snapshot: EchoCartographerSceneSnapshot = core.snapshot(time: 2.5)
        #expect(snapshot.width == level.chamber.width && snapshot.height == level.chamber.height)
        #expect(snapshot.knowledge == play.knowledge.cells && snapshot.entry == level.entry)
        #expect(snapshot.markers == [EchoCartographerCell(x: 5, y: 0)] && snapshot.located.isEmpty)
        #expect(snapshot.lastEcho == play.lastEcho && snapshot.lastEcho != nil)
        #expect(snapshot.stage == .playing && snapshot.failure == nil && snapshot.levelNumber == 1)
        #expect(snapshot.energy == level.energy - 1 && snapshot.budget == level.energy && snapshot.time == 2.5)
        for wall in snapshot.wallCells { #expect(level.chamber.isWall(wall)) }
        for open in snapshot.openCells { #expect(level.chamber.isOpen(open)) }
        // Non-finite and negative times read as 0.
        let zero: EchoCartographerSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        #expect(core.snapshot(time: -3) == zero)
        // After the win the located beacon appears.
        for step in generated.actions.dropFirst() { #expect(core.apply(Self.act(step)) == .accepted) }
        let won: EchoCartographerSceneSnapshot = core.snapshot(time: 1)
        #expect(won.stage == .won && won.located == level.beacons)
    }

    @Test func theTierAndTheSnapshotTimeNeverTouchTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: Self.fixtureSeed)
        let entry: EchoCartographerCell = core.play.level.entry
        #expect(core.apply(Self.act("cell.pulse", [Double(entry.x), Double(entry.y)])) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let shells: [Int] = [2, 2, 1, 0, 0]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.glowShells == shells[index])
            #expect(core.renderTier == EchoCartographerTier.of(clamped[index]))
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: EchoCartographerSceneSnapshot = core.snapshot(time: time)
            #expect(snapshot.stage == core.play.stage && snapshot.energy == core.play.energy)
            #expect(snapshot.levelNumber == core.levelNumber && snapshot.time.isFinite)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }
}
