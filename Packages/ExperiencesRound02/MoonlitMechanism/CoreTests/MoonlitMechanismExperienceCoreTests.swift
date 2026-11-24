// MoonlitMechanismExperienceCoreTests — feature 433 (R02-G14-03) T-R02G1403-005 (FR-R02G1403-005, 008, 009;
// SC-R02G1403-004; clarification Q5). The adapter core: the shared conformance checks pass; the declared controls, ids,
// tiers and profile (the quality level names equal `MoonlitMechanismTier.all`); the seed picks level `seed % 100 + 1`
// deterministically in stage `playing` (seeds 0, 1, 99 and 100 give levels 1, 2, 100 and 1); every control is accepted
// when legal and refused with the state unchanged otherwise (the engine's range checks, `r02-g14.not-whole`,
// `r02-g14.frame` for a key frame the level lacks, and every kernel refusal the adapter can meet passing through with
// its code: `r02-g14.action` for a step of 0, the driver re-seated, a gear the level lacks, a lamp step out of range
// and nothing to undo or redo, and `r02-g14.stage`; `stale` cannot arise because every action names the current
// fingerprint); undo restores the earlier digest exactly and redo the later one; `frame.show` changes the snapshot
// (shown key frame, phases, cast and target) but never the digest, the play or the payload; the stored witness of
// level 1 wins through the adapter, the certified witnesses of levels 1, 21 and 41 win, an early run and a spent
// budget fail, undo returns a failed play to playing; `level.next` wraps 100 to 1 and reset returns (key frame 0 shown
// again); the snapshot round trip and refused payloads (damaged, level out of range, a trace of another level, a
// record of a newer schema, an edited trace, an envelope of a newer schema); the certified-candidate table equals the
// 100 stored witnesses' `skipped` and the directly certified levels equal the stored ones; `snapshot(time:)` copies the
// play and the kernel's exact run report. Fixture seed 2_433. Levels are certified once per process, so the run stays
// short. Explicit types, plain loops, single-literal comments.
import Foundation
import Testing
@testable import MoonlitMechanismCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, MoonlitMechanism, the package,
/// Packages).
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/moonlit-mechanism/levels", isDirectory: true)

@Suite struct MoonlitMechanismExperienceCoreTests {
    typealias Core = MoonlitMechanismExperienceCore

    /// The fixture seed of this feature.
    static let fixtureSeed: UInt64 = 2_433

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
    static func act(_ action: MoonlitMechanismAction) -> ExperienceAction {
        switch action {
        case let .turn(step): act("handle.turn", [Double(step)])
        case let .reseat(gear, step): act("gear.reseat", [Double(gear), Double(step)])
        case let .lamp(step): act("lamp.step", [Double(step)])
        case .run: act("machine.run")
        }
    }

    /// The failure a run outcome gives, or nil for a win.
    static func failure(of outcome: MoonlitMechanismOutcome) -> MoonlitMechanismFailure? {
        switch outcome {
        case .won: nil
        case let .jammed(child): .jammed(child)
        case let .forbidden(frame, cell): .forbidden(frame: frame, cell: cell)
        case let .missing(frame, count): .missing(frame: frame, count: count)
        case let .stray(frame, count): .stray(frame: frame, count: count)
        }
    }

    /// The stored witness of level `number`, read with the plain decoder (as the catalog tests read it).
    static func storedWitness(_ number: Int) throws -> MoonlitMechanismWitness {
        let name: String = String(MoonlitMechanismGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: coreWitnessDirectory.appendingPathComponent(name))
        return try JSONDecoder().decode(MoonlitMechanismWitness.self, from: data)
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 3 (then 2 and 4): 2 or 3 gears, lamp at height 2 of 3 on both openings, budgets 8 … 11. No
        // action ends a play (at most 6 actions spent before level.next and 2 after; no run).
        let actions: [ScriptedAction] = [ScriptedAction("handle.turn", [1]), ScriptedAction("gear.reseat", [1, 1]),
                                         ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                         ScriptedAction("lamp.step", [-1]), ScriptedAction("play.undo"),
                                         ScriptedAction("frame.show", [1]), ScriptedAction("level.next"),
                                         ScriptedAction("handle.turn", [-1]), ScriptedAction("frame.show", [1])]
        // Refused on the openings of levels 1 and 3 (two key frames each, lamp at its top height).
        let rejected: [ScriptedAction] = [ScriptedAction("handle.turn", [2]),
                                          ScriptedAction("handle.turn", [0]),
                                          ScriptedAction("handle.turn", [0.5]),
                                          ScriptedAction("handle.turn"),
                                          ScriptedAction("gear.reseat", [0, 1]),
                                          ScriptedAction("gear.reseat", [5, 1]),
                                          ScriptedAction("gear.reseat", [4, 1]),
                                          ScriptedAction("gear.reseat", [1, 0]),
                                          ScriptedAction("lamp.step", [1]),
                                          ScriptedAction("lamp.step", [0]),
                                          ScriptedAction("frame.show", [2]),
                                          ScriptedAction("frame.show", [6]),
                                          ScriptedAction("frame.show", [0.5]),
                                          ScriptedAction("machine.run", [1]),
                                          ScriptedAction("play.undo"), ScriptedAction("play.redo"),
                                          ScriptedAction("level.next", [1]), ScriptedAction("bogus")]
        let plan = ConformancePlan(seeds: [0, 2], stepsPerSegment: 2, actions: actions, rejected: rejected)
        let report: ConformanceReport = await ExperienceConformance.run(Core.self, id: id, plan: plan)
        #expect(report.entries.count == ConformanceCheck.allCases.count)
        for entry in report.entries {
            if !entry.passed { print("conformance", entry.check, entry.detail) }
            #expect(entry.passed, "every conformance check passes")
        }
    }

    @Test func theControlsTheTiersAndTheProfile() {
        #expect(Core.experienceID == "r02-g14.moonlit-mechanism" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g14.moonlit-mechanism.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["handle.turn", "gear.reseat", "lamp.step", "machine.run", "play.undo", "play.redo",
                             "level.next", "frame.show"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[0].ranges == [-1...1] && Core.controls[2].ranges == [-1...1])
        #expect(Core.controls[1].ranges == [0...4, -1...1])
        #expect(Core.controls[7].ranges == [0...5])
        let plainIndices: [Int] = [3, 4, 5, 6]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.qualityTiers == MoonlitMechanismTier.all.count)
        #expect(Core.migrations.currentVersion == 1)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == MoonlitMechanismTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        let expectedElements: [Double] = [1, 4.0 / 6.0, 2.0 / 6.0]
        #expect(elements == expectedElements && iterations == [1, 0.5, 0])
        #expect(passes == [3, 2, 0] && resolutions == [1, 1, 1])
        #expect(MoonlitMechanismExperienceRule.notWhole == "r02-g14.not-whole")
        #expect(MoonlitMechanismExperienceRule.frame == "r02-g14.frame")
        #expect(Core.wonCode == "won" && Core.failedCode == "failed")
        #expect(Core.openingGear == 1 && Core.openingFrame == 0)
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
            let expected: MoonlitMechanismLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.phases == expected.startingPhases)
            #expect(first.play.height == expected.startingHeight)
            // The tutorial (levels 1 … 3) is dismissed by the adapter: the play opens in stage playing.
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.play.actionsLeft == expected.budget && first.qualityTier == 0 && first.shownFrame == 0)
        }
        #expect(try Core.level(number: 1).tutorial && !(try Core.level(number: 100).tutorial))
        #expect(Core.levelNumber(forSeed: Self.fixtureSeed) == 34)
        #expect(throws: MoonlitMechanismError.level("number")) { try Core.level(number: 0) }
        #expect(throws: MoonlitMechanismError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableEqualsTheWitnessesAndCertifiesTheStoredLevels() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for number in 1...100 {
            let witness: MoonlitMechanismWitness = try Self.storedWitness(number)
            #expect(witness.number == number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "a table entry differs")
        }
        // Directly certified levels equal the stored witness levels and actions (84 skips the most candidates, 8).
        let numbers: [Int] = [1, 2, 84, 100]
        for number in numbers {
            let witness: MoonlitMechanismWitness = try Self.storedWitness(number)
            let generated: MoonlitMechanismGenerated = try Core.generated(number: number)
            #expect(generated.level.fingerprint == witness.level.fingerprint, "a level fingerprint differs")
            #expect(generated.level == witness.level && generated.actions == witness.actions)
            #expect(generated.skipped == witness.skipped && generated.difficulty == witness.difficulty)
            #expect(generated.entry == MoonlitMechanismManifest.entries[number - 1])
            // The candidate just before the certified one does not certify (the generator skipped it).
            if witness.skipped > 0 {
                let entry: MoonlitMechanismManifestEntry = MoonlitMechanismManifest.entries[number - 1]
                #expect(Core.certify(entry, index: witness.skipped - 1) == nil, "a skipped candidate certifies")
            }
        }
        #expect(Core.certifiedCandidates[83] == 8)
        // The generator itself gives the same level as the direct certification.
        let entry: MoonlitMechanismManifestEntry = MoonlitMechanismManifest.entries[0]
        #expect(try MoonlitMechanismGenerator.generate(entry) == Core.generated(number: 1))
    }

    @Test func theStoredWitnessOfLevelOneWinsThroughTheAdapter() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let witness: MoonlitMechanismWitness = try Self.storedWitness(1)
        #expect(core.play.level == witness.level)
        #expect(witness.actions == [.turn(1), .lamp(-1), .run])
        for step in witness.actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
        #expect(core.play.report.outcome == .won && core.play.failure == nil)
        #expect(core.play.records.count == witness.actions.count)
        #expect(core.snapshot(time: 0).isWon)
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: two gears (9 and 12 teeth), lamp at height 2 of 3, two key frames, budget 9.
        var core: Core = try await Core.prepare(seed: 0)
        let level: MoonlitMechanismLevel = core.play.level
        #expect(level.gears.count == 2 && level.lampHeights == 3 && level.startingHeight == 2)
        #expect(level.keyFrames.count == 2 && level.budget == 9)
        let opening: StateDigest = try Self.digest(core)
        let illegal: [ExperienceAction] = [Self.act("handle.turn", [2]), Self.act("handle.turn", [-2]),
                                           Self.act("handle.turn", [0]), Self.act("handle.turn", [0.5]),
                                           Self.act("handle.turn", [.nan]), Self.act("handle.turn"),
                                           Self.act("handle.turn", [1, 1]), Self.act("gear.reseat", [0, 1]),
                                           Self.act("gear.reseat", [2, 1]), Self.act("gear.reseat", [5, 1]),
                                           Self.act("gear.reseat", [1, 0]), Self.act("gear.reseat", [1, 0.5]),
                                           Self.act("gear.reseat", [1.5, 1]), Self.act("gear.reseat", [1]),
                                           Self.act("lamp.step", [1]), Self.act("lamp.step", [0]),
                                           Self.act("lamp.step", [2]), Self.act("frame.show", [2]),
                                           Self.act("frame.show", [6]), Self.act("frame.show", [-1]),
                                           Self.act("frame.show", [0.5]), Self.act("frame.show"),
                                           Self.act("machine.run", [1]), Self.act("play.undo"),
                                           Self.act("play.redo"), Self.act("play.undo", [1]),
                                           Self.act("level.next", [1]), Self.act("nope")]
        for action in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(action)
            #expect(!result.isAccepted, "an illegal action was accepted")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.isEmpty, "a refusal changed the state")
            #expect(copy.shownFrame == 0)
        }
        var probe: Core = core
        // Outside the declared ranges or the value count: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.act("handle.turn", [2])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("handle.turn", [-2])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("gear.reseat", [5, 1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("gear.reseat", [1, 2])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("lamp.step", [2])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("frame.show", [6])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("frame.show", [-1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("handle.turn", [.nan])) == .rejected(.nonFinite(index: 0)))
        #expect(probe.apply(Self.act("gear.reseat", [1])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("frame.show")) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        let noValues: ActionResult = .rejected(.wrongValueCount(expected: 0, found: 1))
        #expect(probe.apply(Self.act("machine.run", [1])) == noValues)
        #expect(probe.apply(Self.act("play.undo", [1])) == noValues)
        #expect(probe.apply(Self.act("play.redo", [1])) == noValues)
        #expect(probe.apply(Self.act("level.next", [1])) == noValues)
        let notWhole: ActionResult = .rejected(.rule(code: MoonlitMechanismExperienceRule.notWhole))
        #expect(probe.apply(Self.act("handle.turn", [0.5])) == notWhole)
        #expect(probe.apply(Self.act("gear.reseat", [1.5, 1])) == notWhole)
        #expect(probe.apply(Self.act("gear.reseat", [1, -0.5])) == notWhole)
        #expect(probe.apply(Self.act("lamp.step", [0.25])) == notWhole)
        #expect(probe.apply(Self.act("frame.show", [0.5])) == notWhole)
        // A key frame the level lacks: the adapter's refusal.
        let frame: ActionResult = .rejected(.rule(code: MoonlitMechanismExperienceRule.frame))
        #expect(probe.apply(Self.act("frame.show", [2])) == frame)
        #expect(probe.apply(Self.act("frame.show", [5])) == frame)
        // Every kernel refusal the adapter can meet passes through with its reason code.
        let action: ActionResult = .rejected(.rule(code: MoonlitMechanismError.action("step").reasonCode))
        let stage: ActionResult = .rejected(.rule(code: MoonlitMechanismError.stage.reasonCode))
        #expect(action == .rejected(.rule(code: "r02-g14.action")) && stage == .rejected(.rule(code: "r02-g14.stage")))
        #expect(probe.apply(Self.act("handle.turn", [0])) == action)       // a step of 0
        #expect(probe.apply(Self.act("gear.reseat", [0, 1])) == action)    // the driver
        #expect(probe.apply(Self.act("gear.reseat", [2, 1])) == action)    // a gear level 1 lacks
        #expect(probe.apply(Self.act("gear.reseat", [4, -1])) == action)   // a gear level 1 lacks
        #expect(probe.apply(Self.act("gear.reseat", [1, 0])) == action)    // a step of 0
        #expect(probe.apply(Self.act("lamp.step", [1])) == action)         // above the top height
        #expect(probe.apply(Self.act("lamp.step", [0])) == action)         // a step of 0
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe.apply(Self.act("nope")) == .rejected(.unknownControl("nope")))
        #expect(probe == core && probe.shownFrame == 0)

        // A turn, a re-seat and a lamp step each spend one action.
        let start: [Int] = core.play.phases
        #expect(core.apply(Self.act("handle.turn", [1])) == .accepted)
        let turned: [Int] = MoonlitMechanismTrain.turned(level.gears, phases: start, by: 1)
        #expect(core.play.phases == turned && core.play.actionsLeft == 8 && core.play.records.count == 1)
        #expect(core.apply(Self.act("gear.reseat", [1, -1])) == .accepted)
        let reseated: Int = MoonlitMechanismTrain.mod(turned[1] - 1, level.gears[1].teeth)
        #expect(core.play.phases == [turned[0], reseated] && core.play.actionsLeft == 7)
        #expect(core.apply(Self.act("lamp.step", [-1])) == .accepted)
        #expect(core.play.height == 1 && core.play.actionsLeft == 6)
        #expect(core.apply(Self.act("lamp.step", [-1])) == .accepted)
        #expect(core.play.height == 0)
        #expect(core.apply(Self.act("lamp.step", [-1])) == action)         // below height 0
        #expect(core.play.stage == .playing && core.outcome == nil)
        #expect(core.play.report == level.run(phases: core.play.phases, height: core.play.height))
        #expect(try Self.digest(core) != opening)

        // The stage refusal: a won play refuses every kernel control but still shows key frames and moves on.
        var won: Core = try Core.opening(number: 1)
        let generated: MoonlitMechanismGenerated = try Core.generated(number: 1)
        for step in generated.actions { #expect(won.apply(Self.act(step)) == .accepted) }
        #expect(won.play.stage == .won && won.outcome?.code == Core.wonCode)
        let final: Core = won
        let finalDigest: StateDigest = try Self.digest(won)
        #expect(won.apply(Self.act("handle.turn", [1])) == stage)
        #expect(won.apply(Self.act("gear.reseat", [1, 1])) == stage)
        #expect(won.apply(Self.act("lamp.step", [1])) == stage)
        #expect(won.apply(Self.act("machine.run")) == stage)
        #expect(won.apply(Self.act("play.undo")) == stage)
        #expect(won.apply(Self.act("play.redo")) == stage)
        #expect(won == final)
        #expect(won.apply(Self.act("frame.show", [1])) == .accepted)
        #expect(try Self.digest(won) == finalDigest && won == final && won.shownFrame == 1)
        #expect(won.apply(Self.act("level.next")) == .accepted)
        #expect(won.levelNumber == 2 && won.play.stage == .playing && won.shownFrame == 0)
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLater() async throws {
        var core: Core = try await Core.prepare(seed: 2)
        let startDigest: StateDigest = try Self.digest(core)
        let start: MoonlitMechanismPlay = core.play
        // Level 3: three gears, lamp at height 2 of 3, budget 11.
        let steps: [ExperienceAction] = [Self.act("handle.turn", [1]), Self.act("gear.reseat", [2, 1]),
                                         Self.act("lamp.step", [-1])]
        for step in steps { #expect(core.apply(step) == .accepted) }
        let moved: Core = core
        let movedDigest: StateDigest = try Self.digest(core)
        #expect(movedDigest != startDigest && core.play.stage == .playing)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(core.play.phases == start.phases && core.play.height == start.height)
        #expect(core.play.actionsLeft == start.actionsLeft && core.play.report == start.report)
        #expect(core.play.stage == .playing)
        #expect(try Self.digest(core) == startDigest)
        for _ in 0..<3 { #expect(core.apply(Self.act("play.redo")) == .accepted) }
        #expect(core.play.phases == moved.play.phases && core.play.height == moved.play.height)
        #expect(core.play.actionsLeft == moved.play.actionsLeft && core.play.records.count == 9)
        #expect(try Self.digest(core) == movedDigest)
        // A new action clears the redo history.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("handle.turn", [-1])) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g14.action")))
        for _ in 0..<3 { #expect(core.apply(Self.act("play.undo")) == .accepted) }
        #expect(try Self.digest(core) == startDigest)
    }

    @Test func frameShowChangesTheSnapshotButNeverTheDigest() async throws {
        // Level 21: three key frames.
        var core: Core = try await Core.prepare(seed: 20)
        #expect(core.levelNumber == 21 && core.play.level.keyFrames.count == 3 && core.shownFrame == 0)
        #expect(core.apply(Self.act("handle.turn", [1])) == .accepted)
        let before: Core = core
        let digest: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let zero: MoonlitMechanismSceneSnapshot = core.snapshot(time: 1)
        #expect(zero.shownFrame == 0)
        for frame in 0..<3 {
            #expect(core.apply(Self.act("frame.show", [Double(frame)])) == .accepted)
            #expect(core.shownFrame == frame)
            #expect(try Self.digest(core) == digest && core == before && core.snapshotPayload() == payload)
            let snapshot: MoonlitMechanismSceneSnapshot = core.snapshot(time: 1)
            let report: MoonlitMechanismFrameReport = core.play.report.frames[frame]
            #expect(snapshot.shownFrame == frame && snapshot.cast == report.cast && snapshot.phases == report.phases)
            #expect(snapshot.target == core.play.level.keyFrames[frame].target)
            #expect(snapshot.setUpPhases == core.play.phases && snapshot.report == core.play.report)
            #expect(snapshot == MoonlitMechanismSceneSnapshot(play: core.play, shownFrame: frame, levelNumber: 21,
                                                              time: 1))
            #expect((snapshot == zero) == (frame == 0))
        }
        // A missing key frame is refused and the shown one stays.
        let shown: Core = core
        #expect(core.apply(Self.act("frame.show", [3])) == .rejected(.rule(code: "r02-g14.frame")))
        #expect(core.shownFrame == 2 && core == shown)
        // frame.show is not a kernel action: nothing to undo beyond the turn, and the frame survives undo.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.shownFrame == 2 && core.play.records.count == 2)
        #expect(core.apply(Self.act("play.undo")) == .rejected(.rule(code: "r02-g14.action")))
        // level.next, reset and restore show key frame 0 again.
        var next: Core = shown
        #expect(next.apply(Self.act("level.next")) == .accepted)
        #expect(next.levelNumber == 22 && next.shownFrame == 0)
        var reset: Core = shown
        reset.reset()
        #expect(reset.shownFrame == 0 && reset.levelNumber == 21 && reset.play.records.isEmpty)
        let restored: Core = try Core.restore(payload: try shown.snapshotPayload(), seed: 20)
        #expect(restored == shown && restored.shownFrame == 0)
    }

    @Test func theWitnessWinsEarlyRunsAndSpentBudgetsFailAndUndoRetries() async throws {
        let numbers: [Int] = [1, 21, 41]
        let stageCode: ActionResult = .rejected(.rule(code: "r02-g14.stage"))
        for number in numbers {
            let generated: MoonlitMechanismGenerated = try Core.generated(number: number)
            let level: MoonlitMechanismLevel = generated.level
            var core: Core = try Core.opening(number: number)
            let before: StateDigest = try Self.digest(core)

            // A run at the opening fails with the start's own cause.
            var early: Core = core
            #expect(early.apply(Self.act("machine.run")) == .accepted)
            let startOutcome: MoonlitMechanismOutcome = level.run(phases: level.startingPhases,
                                                                  height: level.startingHeight).outcome
            let expectedFailure: MoonlitMechanismFailure? = Self.failure(of: startOutcome)
            #expect(expectedFailure != nil)
            #expect(early.play.stage == .failed && early.play.failure == expectedFailure, "the early run's cause")
            #expect(early.outcome?.code == Core.failedCode && early.play.actionsLeft == level.budget - 1)
            #expect(early.apply(Self.act("play.undo")) == .accepted)
            #expect(early.play.stage == .playing && early.outcome == nil)
            #expect(try Self.digest(early) == before)

            // Turns back and forth spend the budget: failed on the last one.
            var failing: Core = core
            var count: Int = 0
            while failing.play.stage == .playing && count < 64 {
                let step: Double = count % 2 == 0 ? 1 : -1
                #expect(failing.apply(Self.act("handle.turn", [step])) == .accepted)
                count += 1
            }
            #expect(count == level.budget, "the budget is spent on its last action")
            #expect(failing.play.stage == .failed && failing.play.failure == .budget(count - 1))
            #expect(failing.play.actionsLeft == 0 && failing.outcome?.code == Core.failedCode)
            let failedSnapshot: MoonlitMechanismSceneSnapshot = failing.snapshot(time: 0)
            #expect(failedSnapshot.stage == .failed && failedSnapshot.failure == .budget(count - 1))
            #expect(failedSnapshot.actionsLeft == 0 && failedSnapshot.budget == level.budget)
            let failed: Core = failing
            #expect(failing.apply(Self.act("handle.turn", [1])) == stageCode)
            #expect(failing.apply(Self.act("machine.run")) == stageCode)
            #expect(failing.apply(Self.act("play.redo")) == stageCode)
            #expect(failing == failed)
            #expect(failing.apply(Self.act("play.undo")) == .accepted)
            #expect(failing.play.stage == .playing && failing.outcome == nil)
            while failing.play.canUndo { #expect(failing.apply(Self.act("play.undo")) == .accepted) }
            #expect(try Self.digest(failing) == before)

            // The certified witness: won on its last action (the run).
            for step in generated.actions { #expect(core.apply(Self.act(step)) == .accepted) }
            #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode, "the witness wins")
            #expect(core.play.report.outcome == .won && core.play.failure == nil)
            #expect(core.apply(Self.act("level.next")) == .accepted)
            let next: Int = number % 100 + 1
            #expect(core.play.stage == .playing && core.levelNumber == next && core.outcome == nil)
            core.reset()
            #expect(core.levelNumber == number && core.play.records.isEmpty && core.play.stage == .playing)
        }
    }

    @Test func nextLevelWrapsAndResetReturnsToTheSeedsLevel() async throws {
        var core: Core = try await Core.prepare(seed: 40)
        #expect(core.levelNumber == 41)
        #expect(core.apply(Self.act("handle.turn", [1])) == .accepted)
        #expect(core.apply(Self.act("frame.show", [2])) == .accepted)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 42 && core.play.records.isEmpty && core.play.stage == .playing)
        core.reset()
        let fresh: Core = try await Core.prepare(seed: 40)
        let resetDigest: StateDigest = try Self.digest(core)
        let freshDigest: StateDigest = try Self.digest(fresh)
        #expect(core == fresh && resetDigest == freshDigest && core.shownFrame == 0)
        // The wrap: level 100 → 1.
        var last: Core = try Core.opening(number: 100)
        #expect(last.apply(Self.act("level.next")) == .accepted)
        let first: Core = try await Core.prepare(seed: 0)
        #expect(last.levelNumber == 1 && last == first)
        last.reset()
        #expect(last.levelNumber == 100)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        var core: Core = try await Core.prepare(seed: 20)
        let generated: MoonlitMechanismGenerated = try Core.generated(number: 21)
        // Every action of the witness but the run, another turn, then an undo.
        try #require(generated.actions.count >= 2)
        for step in generated.actions.dropLast() { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.apply(Self.act("handle.turn", [1])) == .accepted)
        #expect(core.play.stage == .playing)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let payload: Data = try core.snapshotPayload()
        #expect(try core.snapshotPayload() == payload)
        let text: String = try #require(String(data: payload, encoding: .utf8))
        #expect(text.hasPrefix("{\"level\":21,\"records\":["))
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
        // The restored play still wins with the witness's run after the redo is undone.
        var finishing: Core = restored
        #expect(finishing.apply(Self.act("machine.run")) == .accepted)
        #expect(finishing.play.stage == .won)
        let other: Core = try Core.restore(payload: payload, seed: 0)
        #expect(other == core && other.openingNumber == 1)
        var otherReset: Core = other
        otherReset.reset()
        #expect(otherReset.levelNumber == 1 && otherReset.play.records.isEmpty)
        // A fresh play round-trips too.
        let opening: Core = try await Core.prepare(seed: 7)
        let openingPayload: Data = try opening.snapshotPayload()
        #expect(String(data: openingPayload, encoding: .utf8) == "{\"level\":8,\"records\":[]}")
        #expect(try Core.restore(payload: openingPayload, seed: 7) == opening)

        #expect(throws: MoonlitMechanismRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{}".utf8), seed: 20)
        }
        #expect(throws: MoonlitMechanismRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 20)
        }
        #expect(throws: MoonlitMechanismRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"21\",\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: MoonlitMechanismRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: MoonlitMechanismRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 20)
        }
        // The same records on another level: the records carry level 21's seed.
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "\"level\":21", with: "\"level\":1").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: MoonlitMechanismRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: wrongLevel, seed: 20)
        }
        // A record of a newer schema.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: MoonlitMechanismRestoreRefusal.kernel(.malformed("schema 0"))) {
            try Core.restore(payload: newer, seed: 20)
        }
        // A trace that no longer replays: an edited next fingerprint.
        let first: MoonlitMechanismRecord = try #require(core.play.records.first)
        let edited: Data = Data(text.replacingOccurrences(of: first.next, with: String(repeating: "0", count: 64)).utf8)
        #expect(edited != payload)
        var editedRefused: Bool = false
        do {
            _ = try Core.restore(payload: edited, seed: 20)
        } catch let refusal as MoonlitMechanismRestoreRefusal {
            if case .kernel(.malformed) = refusal { editedRefused = true }
        }
        #expect(editedRefused)
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 5)
        try engine.activate()
        // Level 6: two gears, lamp at height 2 of 3.
        #expect(engine.handle(control: "handle.turn", values: [1]) == .accepted)
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

    @Test func theSnapshotCopiesThePlayAndTheKernelsReport() async throws {
        // Level 3 after the first action of its witness: the snapshot copies the play exactly.
        var core: Core = try await Core.prepare(seed: 2)
        let generated: MoonlitMechanismGenerated = try Core.generated(number: 3)
        let first: MoonlitMechanismAction = try #require(generated.actions.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        let play: MoonlitMechanismPlay = core.play
        let level: MoonlitMechanismLevel = play.level
        let snapshot: MoonlitMechanismSceneSnapshot = core.snapshot(time: 2.5)
        #expect(snapshot == MoonlitMechanismSceneSnapshot(play: play, shownFrame: 0, levelNumber: 3, time: 2.5))
        #expect(snapshot.gears == level.gears && snapshot.setUpPhases == play.phases)
        #expect(snapshot.height == play.height && snapshot.lampHeights == level.lampHeights)
        #expect(snapshot.width == level.width && snapshot.rows == level.rows)
        let exact: MoonlitMechanismRunReport = level.run(phases: play.phases, height: play.height)
        #expect(snapshot.report == play.report && snapshot.report == exact)
        #expect(snapshot.cast == exact.frames[0].cast && snapshot.phases == exact.frames[0].phases)
        #expect(snapshot.keyFrames == level.keyFrames && snapshot.forbidden == level.forbidden)
        #expect(snapshot.stage == .playing && snapshot.failure == nil && snapshot.levelNumber == 3)
        #expect(snapshot.actionsLeft == level.budget - 1 && snapshot.budget == level.budget && snapshot.time == 2.5)
        // Non-finite and negative times read as 0.
        let zero: MoonlitMechanismSceneSnapshot = core.snapshot(time: 0)
        #expect(core.snapshot(time: .nan) == zero && core.snapshot(time: .infinity) == zero)
        #expect(core.snapshot(time: -3) == zero && zero.shownFrame == 0)
        // After the win the snapshot's report holds and the stage is won.
        for step in generated.actions.dropFirst() { #expect(core.apply(Self.act(step)) == .accepted) }
        let won: MoonlitMechanismSceneSnapshot = core.snapshot(time: 1)
        #expect(won.stage == .won && won.isWon && won.report.outcome == .won && won.missingCells.isEmpty)
    }

    @Test func theTierAndTheSnapshotTimeNeverTouchTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: Self.fixtureSeed)
        #expect(core.levelNumber == 34)
        #expect(core.apply(Self.act("handle.turn", [1])) == .accepted)
        let digest: StateDigest = try Self.digest(core)
        let before: Core = core
        let tiers: [Int] = [-3, 0, 1, 2, 9]
        let clamped: [Int] = [0, 0, 1, 2, 2]
        let shells: [Int] = [2, 2, 1, 0, 0]
        for index in tiers.indices {
            core.setQualityTier(tiers[index])
            #expect(core.qualityTier == clamped[index] && core.renderTier.glowShells == shells[index])
            #expect(core.renderTier == MoonlitMechanismTier.of(clamped[index]))
            #expect(try Self.digest(core) == digest && core == before)
        }
        let times: [Double] = [0, 1, 120.5, 1e9, -4, .nan]
        for time in times {
            let snapshot: MoonlitMechanismSceneSnapshot = core.snapshot(time: time)
            #expect(snapshot.stage == core.play.stage && snapshot.actionsLeft == core.play.actionsLeft)
            #expect(snapshot.levelNumber == core.levelNumber && snapshot.time.isFinite)
            core.update(step: 3)
            #expect(try Self.digest(core) == digest)
        }
        core.shedCaches()
        #expect(try Self.digest(core) == digest && core == before)
    }
}
