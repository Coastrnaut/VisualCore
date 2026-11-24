// VoxelOrigamiExperienceCoreTests — feature 443 (R02-G15-03) T-R02G1503-005 (FR-R02G1503-005, 008, 009;
// SC-R02G1503-004; clarifications Q4, Q5). The adapter core: the shared conformance checks pass; the declared controls,
// ids, tiers and profile (the quality level names equal `VoxelOrigamiTier.all`); the seed picks level `seed % 100 + 1`
// deterministically in stage `playing` with its first turnable hinge chosen (seeds 0, 1, 99 and 100 give levels 1, 2,
// 100 and 1); every control is accepted when legal and refused with the state unchanged otherwise (the engine's range
// checks, `r02-g15.not-whole`, `r02-g15.hinge` for a chosen hinge the level lacks, and every kernel refusal the adapter
// can meet passing through with its code: `r02-g15.action` for the root, a hinge the level lacks, a step of 0, an idle
// hinge and nothing to undo or redo, and `r02-g15.stage`; `stale` cannot arise because every turn names the current
// fingerprint); undo restores the earlier digest exactly and redo the later one; `hinge.choose` changes the snapshot
// but never the digest, the play or the payload; the certified plan of level 1 wins through the adapter, a refused
// lattice turn and a spent budget fail, undo returns a failed play to playing; `level.next` wraps 100 to 1 and reset
// returns (the first turnable hinge chosen again); the snapshot round trip and refused payloads (damaged, level out of
// range, a trace of another level, a record of a newer schema, an edited trace, an envelope of a newer schema); the
// certified-candidate table equals the generator's search for five levels and, when the repository's witnesses are
// present, the 100 stored witnesses' `skipped`; `snapshot(time:)` copies the play and the kernel's exact report. Levels
// are certified once per process, so the run stays short. Explicit types, plain loops, single-literal comments.
import Foundation
import Testing
@testable import VoxelOrigamiCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, VoxelOrigami, the package,
/// Packages).
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/voxel-origami/levels", isDirectory: true)

/// Whether the stored witnesses are present (they are in the repository; an isolated copy of the package lacks them).
private let coreWitnessesPresent: Bool = FileManager.default.fileExists(
    atPath: coreWitnessDirectory.appendingPathComponent("001.witness.json").path)

@Suite struct VoxelOrigamiExperienceCoreTests {
    typealias Core = VoxelOrigamiExperienceCore

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
    static func act(_ action: VoxelOrigamiAction) -> ExperienceAction {
        switch action {
        case let .turn(hinge, step): act("hinge.turn", [Double(hinge), Double(step)])
        }
    }

    /// The stored witness of level `number`: its number, `skipped` and level fingerprint, read as plain JSON.
    static func storedWitness(_ number: Int) throws -> (number: Int, skipped: Int, fingerprint: String) {
        let name: String = String(VoxelOrigamiGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: coreWitnessDirectory.appendingPathComponent(name))
        let object: [String: Any] = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let level: [String: Any] = try #require(object["level"] as? [String: Any])
        let stored: Int = try #require(object["number"] as? Int)
        let skipped: Int = try #require(object["skipped"] as? Int)
        let fingerprint: String = try #require(level["fingerprint"] as? String)
        return (stored, skipped, fingerprint)
    }

    /// A hinge of `play` that cannot turn now (a leaf or every descendant on its axis), or nil.
    static func idleHinge(_ play: VoxelOrigamiPlay) -> Int? {
        for hinge in 1..<play.level.cubes.count where !play.level.canTurn(hinge, turns: play.turns) { return hinge }
        return nil
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 3 (then 2 and 4): 6 cubes each, budgets 9 and 11. Level 1's certified plan starts with hinge 4,
        // −1; undone before a second turn, so no action ends a play.
        let actions: [ScriptedAction] = [ScriptedAction("hinge.turn", [4, -1]), ScriptedAction("play.undo"),
                                         ScriptedAction("play.redo"), ScriptedAction("hinge.choose", [2]),
                                         ScriptedAction("play.undo"), ScriptedAction("hinge.choose", [5]),
                                         ScriptedAction("level.next"), ScriptedAction("hinge.choose", [1]),
                                         ScriptedAction("hinge.turn", [1, -1]), ScriptedAction("play.undo")]
        // Refused on the openings of levels 1 and 3 (6 cubes: hinges 1 … 5).
        let rejected: [ScriptedAction] = [ScriptedAction("hinge.turn", [0, 1]),
                                          ScriptedAction("hinge.turn", [6, 1]),
                                          ScriptedAction("hinge.turn", [11, -1]),
                                          ScriptedAction("hinge.turn", [12, 1]),
                                          ScriptedAction("hinge.turn", [1, 0]),
                                          ScriptedAction("hinge.turn", [1, 2]),
                                          ScriptedAction("hinge.turn", [1, 0.5]),
                                          ScriptedAction("hinge.turn", [1.5, 1]),
                                          ScriptedAction("hinge.turn", [1]),
                                          ScriptedAction("hinge.choose", [0]),
                                          ScriptedAction("hinge.choose", [6]),
                                          ScriptedAction("hinge.choose", [12]),
                                          ScriptedAction("hinge.choose", [0.5]),
                                          ScriptedAction("hinge.choose"),
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
        // Since feature 447 the snapshot schema is 3 and the digest domain v3.
        #expect(Core.experienceID == "r02-g15.voxel-origami" && Core.schemaVersion == 3)
        #expect(Core.digestDomain == "r02-g15.voxel-origami.v3")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["hinge.turn", "play.undo", "play.redo", "level.next", "hinge.choose", "level.select",
                             "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss", "replay.start",
                             "replay.step", "replay.stop", "settings.sound"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[0].ranges == [0...11, -1...1])
        #expect(Core.controls[4].ranges == [0...11])
        #expect(Core.controls[5].ranges == [1...100])
        #expect(Core.controls[6].ranges == [1...9999, 1...12, 1...31])
        // Since feature 447 four controls follow: replay.start [1…100], replay.step, replay.stop, settings.sound [0…1].
        #expect(Core.controls[10].ranges == [1...100])
        #expect(Core.controls[13].ranges == [0...1])
        let plainIndices: [Int] = [1, 2, 3, 7, 8, 9, 11, 12]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.qualityTiers == VoxelOrigamiTier.all.count)
        // Since feature 447 the migration chain ends at schema 3.
        #expect(Core.migrations.currentVersion == 3)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == VoxelOrigamiTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        let expectedElements: [Double] = [1, 2.0 / 3.0, 1.0 / 3.0]
        #expect(elements == expectedElements && iterations == [1, 0.5, 0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(VoxelOrigamiExperienceRule.notWhole == "r02-g15.not-whole")
        #expect(VoxelOrigamiExperienceRule.hinge == "r02-g15.hinge")
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
            let expected: VoxelOrigamiLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.turns == expected.startTurns)
            // The tutorial (levels 1 … 3) is dismissed by the adapter: the play opens in stage playing.
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.play.actionsLeft == expected.budget && first.qualityTier == 0)
            // The first hinge that can turn is chosen.
            #expect(expected.canTurn(first.chosenHinge, turns: first.play.turns))
            for hinge in 1..<first.chosenHinge { #expect(!expected.canTurn(hinge, turns: first.play.turns)) }
            #expect(first.chosenHinge == Core.openingHinge(of: first.play))
        }
        #expect(try Core.level(number: 1).tutorial && !(try Core.level(number: 100).tutorial))
        #expect(throws: VoxelOrigamiError.level("number")) { try Core.level(number: 0) }
        #expect(throws: VoxelOrigamiError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableEqualsTheGeneratorsSearch() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for value in Core.certifiedCandidates {
            #expect(value >= 0 && value < VoxelOrigamiGenerator.maxCandidates)
        }
        // Five levels re-derived by the generator's whole search (level 4 skips 5 candidates).
        let numbers: [Int] = [1, 2, 4, 11, 100]
        for number in numbers {
            let entry: VoxelOrigamiManifestEntry = VoxelOrigamiManifest.entries[number - 1]
            let searched: VoxelOrigamiGenerated = try VoxelOrigamiGenerator.generate(entry)
            #expect(searched.skipped == Core.certifiedCandidates[number - 1], "a table entry differs")
            let direct: VoxelOrigamiGenerated = try Core.generated(number: number)
            #expect(direct == searched, "the direct certification differs from the generator")
            #expect(direct.entry == entry && direct.level.id == VoxelOrigamiGenerator.levelID(number))
            // The candidate just before the certified one does not certify (the generator skipped it).
            if searched.skipped > 0 {
                #expect(Core.certify(entry, index: searched.skipped - 1) == nil, "a skipped candidate certifies")
            }
        }
        #expect(Core.certifiedCandidates[3] == 5 && Core.certifiedCandidates[93] == 57)
    }

    @Test(.enabled(if: coreWitnessesPresent, "needs the stored witnesses, docs/games/voxel-origami/levels"))
    func theCandidateTableEqualsTheStoredWitnesses() throws {
        for number in 1...100 {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            #expect(witness.number == number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "a table entry differs")
        }
        // Directly certified levels equal the stored witness levels (94 skips the most candidates, 57).
        let numbers: [Int] = [1, 2, 94, 100]
        for number in numbers {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            let generated: VoxelOrigamiGenerated = try Core.generated(number: number)
            #expect(generated.level.fingerprint == witness.fingerprint, "a level fingerprint differs")
            #expect(generated.skipped == witness.skipped)
        }
    }

    @Test func theCertifiedPlanOfLevelOneWinsThroughTheAdapter() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let generated: VoxelOrigamiGenerated = try Core.generated(number: 1)
        #expect(generated.plan.turns == [.turn(4, -1), .turn(4, -1)])
        for step in generated.plan.turns { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
        #expect(core.play.report.matched && core.play.failure == nil)
        #expect(core.play.records.count == generated.plan.size)
        #expect(core.snapshot(time: 0).isWon)
        // A won play is final: a turn and undo are the kernel's stage refusal; choosing a hinge is still accepted.
        let stage: ActionResult = .rejected(.rule(code: "r02-g15.stage"))
        #expect(core.apply(Self.act("hinge.turn", [4, 1])) == stage)
        #expect(core.apply(Self.act("play.undo")) == stage)
        #expect(core.apply(Self.act("play.redo")) == stage)
        #expect(core.apply(Self.act("hinge.choose", [2])) == .accepted && core.chosenHinge == 2)
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: 6 cubes (hinges 1 … 5), budget 9.
        let core: Core = try await Core.prepare(seed: 0)
        let level: VoxelOrigamiLevel = core.play.level
        #expect(level.cubes.count == 6 && level.budget == 9)
        let opening: StateDigest = try Self.digest(core)
        let openingHinge: Int = core.chosenHinge
        let illegal: [ExperienceAction] = [Self.act("hinge.turn", [0, 1]), Self.act("hinge.turn", [6, 1]),
                                           Self.act("hinge.turn", [11, 1]), Self.act("hinge.turn", [12, 1]),
                                           Self.act("hinge.turn", [-1, 1]), Self.act("hinge.turn", [1, 0]),
                                           Self.act("hinge.turn", [1, 2]), Self.act("hinge.turn", [1, -2]),
                                           Self.act("hinge.turn", [1, 0.5]), Self.act("hinge.turn", [1.5, 1]),
                                           Self.act("hinge.turn", [.nan, 1]), Self.act("hinge.turn", [1]),
                                           Self.act("hinge.turn"), Self.act("hinge.turn", [1, 1, 1]),
                                           Self.act("hinge.choose", [0]), Self.act("hinge.choose", [6]),
                                           Self.act("hinge.choose", [12]), Self.act("hinge.choose", [-1]),
                                           Self.act("hinge.choose", [0.5]), Self.act("hinge.choose"),
                                           Self.act("play.undo"), Self.act("play.redo"),
                                           Self.act("play.undo", [1]), Self.act("level.next", [1]),
                                           Self.act("nope")]
        for action in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(action)
            #expect(!result.isAccepted, "an illegal action was accepted")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.isEmpty, "a refusal changed the state")
            #expect(copy.chosenHinge == openingHinge)
        }
        var probe: Core = core
        // Outside the declared ranges or the value count: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.act("hinge.turn", [12, 1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("hinge.turn", [-1, 1])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("hinge.turn", [1, 2])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("hinge.choose", [12])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("hinge.turn", [.nan, 1])) == .rejected(.nonFinite(index: 0)))
        #expect(probe.apply(Self.act("hinge.turn", [1])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("hinge.choose")) == .rejected(.wrongValueCount(expected: 1, found: 0)))
        let noValues: ActionResult = .rejected(.wrongValueCount(expected: 0, found: 1))
        #expect(probe.apply(Self.act("play.undo", [1])) == noValues)
        #expect(probe.apply(Self.act("play.redo", [1])) == noValues)
        #expect(probe.apply(Self.act("level.next", [1])) == noValues)
        let notWhole: ActionResult = .rejected(.rule(code: VoxelOrigamiExperienceRule.notWhole))
        #expect(probe.apply(Self.act("hinge.turn", [1, 0.5])) == notWhole)
        #expect(probe.apply(Self.act("hinge.turn", [1.5, 1])) == notWhole)
        #expect(probe.apply(Self.act("hinge.choose", [0.5])) == notWhole)
        // A chosen hinge the level lacks, or the root: the adapter's refusal.
        let hinge: ActionResult = .rejected(.rule(code: VoxelOrigamiExperienceRule.hinge))
        #expect(probe.apply(Self.act("hinge.choose", [0])) == hinge)
        #expect(probe.apply(Self.act("hinge.choose", [6])) == hinge)
        #expect(probe.apply(Self.act("hinge.choose", [11])) == hinge)
        // The kernel's refusals pass through with their codes.
        let action: ActionResult = .rejected(.rule(code: "r02-g15.action"))
        #expect(probe.apply(Self.act("hinge.turn", [0, 1])) == action)
        #expect(probe.apply(Self.act("hinge.turn", [6, 1])) == action)
        #expect(probe.apply(Self.act("hinge.turn", [11, -1])) == action)
        #expect(probe.apply(Self.act("hinge.turn", [1, 0])) == action)
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        if let idle = Self.idleHinge(probe.play) {
            #expect(probe.apply(Self.act("hinge.turn", [Double(idle), 1])) == action)
        }
        #expect(probe == core && probe.play.records.isEmpty)
        // Every legal action is accepted.
        for value in 1...5 {
            #expect(probe.apply(Self.act("hinge.choose", [Double(value)])) == .accepted && probe.chosenHinge == value)
        }
        #expect(probe.apply(Self.act("hinge.turn", [4, -1])) == .accepted && probe.play.actionsSpent == 1)
        #expect(probe.apply(Self.act("play.undo")) == .accepted && probe.play.actionsSpent == 0)
        #expect(probe.apply(Self.act("play.redo")) == .accepted && probe.play.actionsSpent == 1)
        // Feature 445: `level.next` needs the next level open; level 2 is not open until level 1 is won.
        #expect(probe.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g15.locked")))
        #expect(probe.apply(Self.act("mode.practice")) == .accepted && probe.levelNumber == 1)
        #expect(probe.play.records.isEmpty && probe.chosenHinge == Core.openingHinge(of: probe.play))
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLaterOne() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("hinge.turn", [4, -1])) == .accepted)
        let afterTurn: StateDigest = try Self.digest(core)
        #expect(afterTurn != opening)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening && core.play.records.count == 2)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(try Self.digest(core) == afterTurn && core.play.records.count == 3)
        // A different turn after an undo clears the redo stack.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let other: Int = core.play.level.canTurn(4, turns: core.play.turns) ? 4 : core.chosenHinge
        #expect(core.apply(Self.act("hinge.turn", [Double(other), 1])) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g15.action")))
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
    }

    @Test func choosingAHingeChangesTheSnapshotButNeverTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let before: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let play: VoxelOrigamiPlay = core.play
        var snapshots: [VoxelOrigamiSceneSnapshot] = []
        for hinge in 1..<play.level.cubes.count {
            #expect(core.apply(Self.act("hinge.choose", [Double(hinge)])) == .accepted)
            let snapshot: VoxelOrigamiSceneSnapshot = core.snapshot(time: 1)
            #expect(snapshot.chosenHinge == hinge)
            #expect(snapshot.cells == play.pose.cells && snapshot.report == play.report)
            #expect(try Self.digest(core) == before && core.play == play)
            #expect(try core.snapshotPayload() == payload)
            snapshots.append(snapshot)
        }
        for index in 1..<snapshots.count { #expect(snapshots[index] != snapshots[index - 1]) }
        // A missing hinge is refused and keeps the chosen one.
        let chosen: Int = core.chosenHinge
        #expect(core.apply(Self.act("hinge.choose", [6])) == .rejected(.rule(code: VoxelOrigamiExperienceRule.hinge)))
        #expect(core.apply(Self.act("hinge.choose", [0])) == .rejected(.rule(code: VoxelOrigamiExperienceRule.hinge)))
        #expect(core.chosenHinge == chosen && core.snapshot(time: 1).chosenHinge == chosen)
        // The choice survives a turn, an undo and a redo; level.next, reset and restore choose the opening hinge.
        #expect(core.apply(Self.act("hinge.turn", [4, -1])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.chosenHinge == chosen)
        var reset: Core = core
        reset.reset()
        #expect(reset.chosenHinge == Core.openingHinge(of: reset.play) && reset.play.records.isEmpty)
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && restored.chosenHinge == Core.openingHinge(of: restored.play))
        // A new opening (here practice; since feature 445 `level.next` needs the next level open).
        var next: Core = core
        #expect(next.apply(Self.act("mode.practice")) == .accepted)
        #expect(next.chosenHinge == Core.openingHinge(of: next.play))
    }

    @Test func aRefusedTurnAndASpentBudgetFailAndUndoReturnsToPlaying() async throws {
        // A turn the lattice check refuses, on the first of levels 1 … 10 that has one at its opening.
        var found: (core: Core, hinge: Int, step: Int)? = nil
        for number in 1...10 where found == nil {
            let opening: Core = try Core.opening(number: number)
            let cubes: [VoxelOrigamiCube] = opening.play.level.cubes
            for hinge in 1..<cubes.count where found == nil && opening.play.level.canTurn(hinge,
                                                                                         turns: opening.play.turns) {
                for step in [-1, 1] where found == nil {
                    if VoxelOrigamiLattice.check(cubes, turns: opening.play.turns, hinge: hinge, step: step) != nil {
                        found = (opening, hinge, step)
                    }
                }
            }
        }
        let refused: (core: Core, hinge: Int, step: Int) = try #require(found)
        var core: Core = refused.core
        let opening: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("hinge.turn", [Double(refused.hinge), Double(refused.step)])) == .accepted)
        #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode)
        #expect(core.snapshot(time: 0).brokenTurn?.hinge == refused.hinge)
        #expect(core.play.turns == refused.core.play.turns)
        let stage: ActionResult = .rejected(.rule(code: "r02-g15.stage"))
        #expect(core.apply(Self.act("hinge.turn", [Double(refused.hinge), Double(-refused.step)])) == stage)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.play.stage == .playing && core.outcome == nil)
        #expect(try Self.digest(core) == opening)
        // Level 1: clear turns that never match spend the budget of 9 and fail the level `budget(8)`.
        var spender: Core = try Core.opening(number: 1)
        var guardCount: Int = 0
        while spender.play.stage == .playing, guardCount < 40 {
            guardCount += 1
            var moved: Bool = false
            for hinge in 1..<spender.play.level.cubes.count where !moved {
                for step in [1, -1] where !moved {
                    var trial: Core = spender
                    guard trial.apply(Self.act("hinge.turn", [Double(hinge), Double(step)])) == .accepted else {
                        continue
                    }
                    if trial.play.stage == .won { continue }
                    if case .collision = trial.play.failure { continue }
                    if case .sweep = trial.play.failure { continue }
                    spender = trial
                    moved = true
                }
            }
            if !moved { break }
        }
        #expect(spender.play.stage == .failed && spender.play.failure == .budget(8))
        #expect(spender.play.actionsLeft == 0 && spender.outcome?.code == Core.failedCode)
        #expect(spender.apply(Self.act("play.undo")) == .accepted)
        #expect(spender.play.stage == .playing && spender.play.actionsLeft == 1)
    }

    @Test func levelNextNeedsAnOpenLevelAndResetReturns() async throws {
        var core: Core = try await Core.prepare(seed: 99)
        #expect(core.levelNumber == 100)
        #expect(core.apply(Self.act("hinge.turn", [Double(core.chosenHinge), 1])) == .accepted)
        // Feature 445: no wrap; after winning level 100, `level.next` is refused and level 1 is chosen with
        // `level.select`.
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g15.locked")))
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let hundred: VoxelOrigamiGenerated = try Core.generated(number: 100)
        for step in hundred.plan.turns { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.solved[100] != nil)
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g15.locked")))
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        #expect(core.levelNumber == 1 && core.play.records.isEmpty && core.play.stage == .playing)
        #expect(core.play.level == (try Core.level(number: 1)))
        #expect(core.chosenHinge == Core.openingHinge(of: core.play))
        core.setQualityTier(2)
        core.reset()
        #expect(core.levelNumber == 100 && core.play.records.isEmpty && core.qualityTier == 2)
        let fresh: Core = try await Core.prepare(seed: 99)
        #expect(core == fresh)
        #expect(try Self.digest(core) == Self.digest(fresh))
        #expect(core.chosenHinge == fresh.chosenHinge)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        // Level 21 after a turn, an undo and a redo.
        var core: Core = try await Core.prepare(seed: 20)
        let first: VoxelOrigamiAction = try #require(try Core.generated(number: 21).plan.turns.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let savedDigest: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let text: String = String(decoding: payload, as: UTF8.self)
        #expect(text.hasPrefix("{\"level\":21,\"mode\":{\"mode\":\"campaign\"},\"progress\":{\"frontier\":21,"))
        let restored: Core = try Core.restore(payload: payload, seed: 20)
        let restoredDigest: StateDigest = try Self.digest(restored)
        #expect(restored == core && restoredDigest == savedDigest)
        #expect(restored.play.canRedo && restored.openingNumber == 21)
        var redone: Core = restored
        #expect(redone.apply(Self.act("play.redo")) == .accepted)
        #expect(redone.play.actionsSpent == 1)
        let other: Core = try Core.restore(payload: payload, seed: 0)
        #expect(other == core && other.openingNumber == 1)
        var otherReset: Core = other
        otherReset.reset()
        #expect(otherReset.levelNumber == 1 && otherReset.play.records.isEmpty)
        let opening: Core = try await Core.prepare(seed: 7)
        let openingPayload: Data = try opening.snapshotPayload()
        #expect(try Core.restore(payload: openingPayload, seed: 7) == opening)
        // Refusals.
        #expect(throws: VoxelOrigamiRestoreRefusal.damaged) { try Core.restore(payload: Data("{}".utf8), seed: 20) }
        #expect(throws: VoxelOrigamiRestoreRefusal.damaged) { try Core.restore(payload: Data("nope".utf8), seed: 20) }
        #expect(throws: VoxelOrigamiRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"21\",\"records\":[]}".utf8), seed: 20)
        }
        let rest: String = ",\"mode\":{\"mode\":\"campaign\"},\"progress\":{\"frontier\":1,\"solved\":[]},\"records\":[]}"
        #expect(throws: VoxelOrigamiRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data(("{\"level\":0" + rest).utf8), seed: 20)
        }
        #expect(throws: VoxelOrigamiRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data(("{\"level\":101" + rest).utf8), seed: 20)
        }
        // A trace of level 21 restored as level 22 (another seed).
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "{\"level\":21,", with: "{\"level\":22,").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: VoxelOrigamiRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: wrongLevel, seed: 20)
        }
        // A record of a newer schema.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: VoxelOrigamiRestoreRefusal.kernel(.malformed("schema 0"))) {
            try Core.restore(payload: newer, seed: 20)
        }
        // An edited trace: the first record's index changed.
        let edited: Data = Data(text.replacingOccurrences(of: "\"index\":0,", with: "\"index\":3,").utf8)
        #expect(edited != payload)
        #expect(throws: VoxelOrigamiRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: edited, seed: 20)
        }
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        // Level 1: the first turn of its certified plan.
        #expect(engine.handle(control: "hinge.turn", values: [4, -1]) == .accepted)
        let before: StateDigest = try engine.digest()
        let saved: ExperienceSnapshot = try engine.snapshot()
        let newer = try ExperienceSnapshot(experience: id, schemaVersion: 4, seed: saved.seed,
                                           stepIndex: saved.stepIndex, digest: saved.digest,
                                           payload: Data(saved.payload.utf8))
        var refused: Bool = false
        do {
            try engine.restore(newer)
        } catch {
            refused = error == .snapshot(.newerSchema(found: 4, current: 3))   // since feature 447 the current schema is 3
        }
        #expect(refused)
        #expect(try engine.digest() == before)
        try engine.restore(saved)
        #expect(try engine.digest() == before)
    }

    @Test func theSnapshotCopiesThePlayAndTheKernelsReport() async throws {
        // Level 41 after the first turn of its certified plan.
        var core: Core = try await Core.prepare(seed: 40)
        let first: VoxelOrigamiAction = try #require(try Core.generated(number: 41).plan.turns.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        let play: VoxelOrigamiPlay = core.play
        let level: VoxelOrigamiLevel = play.level
        let snapshot: VoxelOrigamiSceneSnapshot = core.snapshot(time: 2.5)
        #expect(snapshot.cubes == level.cubes && snapshot.turns == play.turns)
        #expect(snapshot.cells == play.pose.cells && snapshot.orientations == play.pose.orientations)
        #expect(snapshot.report == play.report && snapshot.report == level.report(turns: play.turns))
        #expect(snapshot.stage == play.stage && snapshot.failure == play.failure)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.levelNumber == 41 && snapshot.time == 2.5 && snapshot.chosenHinge == core.chosenHinge)
        var turnable: [Int] = []
        for hinge in 1..<level.cubes.count where level.canTurn(hinge, turns: play.turns) { turnable.append(hinge) }
        #expect(snapshot.turnable == turnable)
        #expect(snapshot.target.count == level.target.count)
        var onTarget: Int = 0
        for index in snapshot.cells.indices where snapshot.isOnTarget(index) { onTarget += 1 }
        #expect(onTarget == play.report.covered)
        #expect(core.renderTier == VoxelOrigamiTier.of(0))
    }
}
