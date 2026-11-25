// StarlitCartoucheExperienceCoreTests — feature 453 (R02-G16-03) T-R02G1603-005 (FR-R02G1603-005, 008, 009;
// SC-R02G1603-004; clarifications Q1, Q5). The adapter core: the shared conformance checks pass; the declared controls,
// ids, tiers and profile (the quality level names equal `StarlitCartoucheTier.all`); the seed picks level
// `seed % 100 + 1` deterministically in stage `playing` with the default choice (seeds 0, 1, 99 and 100 give levels 1,
// 2, 100 and 1); every control is accepted when legal and refused with the state unchanged otherwise (the engine's
// range checks, `r02-g16.not-whole`, `r02-g16.choice` for a chosen star the level lacks or the ship's own star, and
// every kernel refusal the adapter can meet passing through with its code: `r02-g16.action` for an unknown star, the
// ship's own star, no corridor and nothing to undo or redo, and `r02-g16.stage`; `stale` cannot arise because every leg
// names the current fingerprint); undo restores the earlier digest exactly and redo the later one; `route.choose`
// changes the snapshot but never the digest, the play or the payload, and the choice resets to the default after every
// leg, undo, redo, `level.next`, reset and restore; the certified plan of level 1 wins through the adapter, a failing
// leg fails and undo returns the failed play to playing; `level.next` wraps 100 to 1 and reset returns; the snapshot
// round trip and refused payloads (damaged, level out of range, a trace of another level, a record of a newer schema,
// an edited trace, an envelope of a newer schema); the certified-candidate table equals the generator's search for four
// levels and the 100 stored witnesses' `skipped`; `snapshot(time:)` copies the play and the kernel's exact report.
// Levels are certified once per process, so the run stays short. Explicit types, plain loops, single-literal comments.
import Foundation
import Testing
@testable import StarlitCartoucheCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCoreSimulation

/// The repository's witness directory, found from this file (five levels up: CoreTests, StarlitCartouche, the package,
/// Packages).
private let coreWitnessDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("docs/games/starlit-cartouche/levels", isDirectory: true)

/// Whether the stored witnesses are present (they are in the repository; an isolated copy of the package lacks them).
private let coreWitnessesPresent: Bool = FileManager.default.fileExists(
    atPath: coreWitnessDirectory.appendingPathComponent("001.witness.json").path)

@Suite struct StarlitCartoucheExperienceCoreTests {
    typealias Core = StarlitCartoucheExperienceCore

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
    static func act(_ action: StarlitCartoucheAction) -> ExperienceAction {
        switch action {
        case let .leg(star, wait): act("route.fly", [Double(star), Double(wait)])
        }
    }

    /// The default choice of `core`'s play: the other end of the lowest-index corridor from the ship's star.
    static func defaultStar(_ core: Core) -> Int {
        StarlitCartoucheSceneSnapshot.defaultChoice(core.play.level, star: core.play.star)
    }

    /// Whether `core` holds the default choice with wait 0.
    static func holdsDefaultChoice(_ core: Core) -> Bool {
        core.chosenStar == defaultStar(core) && core.chosenWait == 0
    }

    /// The stored witness of level `number`: its number, `skipped` and level fingerprint, read as plain JSON.
    static func storedWitness(_ number: Int) throws -> (number: Int, skipped: Int, fingerprint: String) {
        let name: String = String(StarlitCartoucheGenerator.levelID(number).suffix(3)) + ".witness.json"
        let data: Data = try Data(contentsOf: coreWitnessDirectory.appendingPathComponent(name))
        let object: [String: Any] = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let level: [String: Any] = try #require(object["level"] as? [String: Any])
        let stored: Int = try #require(object["number"] as? Int)
        let skipped: Int = try #require(object["skipped"] as? Int)
        let fingerprint: String = try #require(level["fingerprint"] as? String)
        return (stored, skipped, fingerprint)
    }

    /// A leg from `core`'s opening that the kernel accepts and that fails the level, or nil.
    static func failingLeg(_ core: Core) -> (star: Int, wait: Int)? {
        for star in 0..<core.play.level.stars.count where star != core.play.star {
            for wait in Core.waitRange {
                var trial: Core = core
                guard trial.apply(act("route.fly", [Double(star), Double(wait)])) == .accepted else { continue }
                if trial.play.stage == .failed { return (star, wait) }
            }
        }
        return nil
    }

    @Test func conformance() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        // Levels 1 and 3 (then 2 and 4). Level 1's certified plan starts with leg 4 after 1 beat; undone before a
        // second leg, so no action ends a play.
        let actions: [ScriptedAction] = [ScriptedAction("route.fly", [4, 1]), ScriptedAction("play.undo"),
                                         ScriptedAction("play.redo"), ScriptedAction("route.choose", [2, 3]),
                                         ScriptedAction("play.undo"), ScriptedAction("route.choose", [0, 5]),
                                         ScriptedAction("level.next"), ScriptedAction("route.choose", [1, 0]),
                                         ScriptedAction("route.fly", [5, 1]), ScriptedAction("play.undo")]
        // Refused on the openings of levels 1 and 3 (6 stars, the ship at star 1, no corridor 1–3).
        let rejected: [ScriptedAction] = [ScriptedAction("route.fly", [12, 0]),
                                          ScriptedAction("route.fly", [6, 0]),
                                          ScriptedAction("route.fly", [11, 0]),
                                          ScriptedAction("route.fly", [1, 0]),
                                          ScriptedAction("route.fly", [3, 0]),
                                          ScriptedAction("route.fly", [-1, 0]),
                                          ScriptedAction("route.fly", [4, 9]),
                                          ScriptedAction("route.fly", [4, -1]),
                                          ScriptedAction("route.fly", [4, 0.5]),
                                          ScriptedAction("route.fly", [4.5, 0]),
                                          ScriptedAction("route.fly", [4]),
                                          ScriptedAction("route.choose", [1, 0]),
                                          ScriptedAction("route.choose", [6, 0]),
                                          ScriptedAction("route.choose", [11, 8]),
                                          ScriptedAction("route.choose", [12, 0]),
                                          ScriptedAction("route.choose", [2, 9]),
                                          ScriptedAction("route.choose", [2.5, 0]),
                                          ScriptedAction("route.choose", [2]),
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
        #expect(Core.experienceID == "r02-g16.starlit-cartouche" && Core.schemaVersion == 1)
        #expect(Core.digestDomain == "r02-g16.starlit-cartouche.v1")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["route.fly", "play.undo", "play.redo", "level.next", "route.choose"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[0].ranges == [0...11, 0...8])
        #expect(Core.controls[4].ranges == [0...11, 0...8])
        let plainIndices: [Int] = [1, 2, 3]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.qualityTiers == StarlitCartoucheTier.all.count)
        #expect(Core.migrations.currentVersion == 1)
        let profile: QualityProfile = Core.qualityProfile
        #expect(profile.names == ["level-0", "level-1", "level-2"])
        #expect(profile.names == StarlitCartoucheTier.all.map(\.name))
        #expect(QualityDeclaration.problems(profile: profile, tierCount: 3,
                                            catalogNames: ["level-0", "level-1", "level-2"]).isEmpty)
        let elements: [Double] = profile.levels.map(\.elementShare)
        let iterations: [Double] = profile.levels.map(\.iterationShare)
        let passes: [Int] = profile.levels.map(\.effectPasses)
        let resolutions: [Double] = profile.levels.map(\.resolutionShare)
        #expect(elements == [1, 0.5, 0.0625] && iterations == [1, 0.5, 0])
        #expect(passes == [2, 1, 0] && resolutions == [1, 1, 1])
        #expect(StarlitCartoucheExperienceRule.notWhole == "r02-g16.not-whole")
        #expect(StarlitCartoucheExperienceRule.choice == "r02-g16.choice")
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
            let expected: StarlitCartoucheLevel = try Core.generated(number: numbers[index]).level
            #expect(first.play.level == expected && first.play.star == expected.start && first.play.beat == 0)
            // The tutorial (levels 1 … 3) is dismissed by the adapter: the play opens in stage playing.
            #expect(first.play.stage == .playing && first.play.records.isEmpty && first.outcome == nil)
            #expect(first.play.actionsLeft == expected.budget && first.qualityTier == 0)
            #expect(Self.holdsDefaultChoice(first) && first.chosenStar != first.play.star)
        }
        // Level 1: the ship at star 1, whose only corridor (index 0) leads to star 4.
        let one: Core = try await Core.prepare(seed: 0)
        #expect(one.play.star == 1 && one.chosenStar == 4 && one.chosenWait == 0)
        #expect(try Core.level(number: 1).tutorial && !(try Core.level(number: 100).tutorial))
        #expect(throws: StarlitCartoucheError.level("number")) { try Core.level(number: 0) }
        #expect(throws: StarlitCartoucheError.level("number")) { try Core.level(number: 101) }
    }

    @Test func theCandidateTableEqualsTheGeneratorsSearch() throws {
        #expect(Core.certifiedCandidates.count == 100)
        for value in Core.certifiedCandidates {
            #expect(value >= 0 && value < StarlitCartoucheGenerator.maxCandidates)
        }
        // Four levels re-derived by the generator's whole search (levels 5 and 29 skip 2 candidates).
        let numbers: [Int] = [1, 5, 29, 100]
        for number in numbers {
            let entry: StarlitCartoucheManifestEntry = StarlitCartoucheManifest.entries[number - 1]
            let searched: StarlitCartoucheGenerated = try StarlitCartoucheGenerator.generate(entry)
            #expect(searched.skipped == Core.certifiedCandidates[number - 1], "a table entry differs")
            let direct: StarlitCartoucheGenerated = try Core.generated(number: number)
            #expect(direct == searched, "the direct certification differs from the generator")
            #expect(direct.entry == entry && direct.level.id == StarlitCartoucheGenerator.levelID(number))
            // The candidate just before the certified one does not certify (the generator skipped it).
            if searched.skipped > 0 {
                #expect(Core.certify(entry, index: searched.skipped - 1) == nil, "a skipped candidate certifies")
            }
        }
        #expect(Core.certifiedCandidates[4] == 2 && Core.certifiedCandidates[28] == 2)
    }

    @Test(.enabled(if: coreWitnessesPresent, "needs the stored witnesses, docs/games/starlit-cartouche/levels"))
    func theCandidateTableEqualsTheStoredWitnesses() throws {
        for number in 1...100 {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            #expect(witness.number == number)
            #expect(Core.certifiedCandidates[number - 1] == witness.skipped, "a table entry differs")
        }
        // Directly certified levels equal the stored witness levels.
        let numbers: [Int] = [1, 5, 21, 100]
        for number in numbers {
            let witness: (number: Int, skipped: Int, fingerprint: String) = try Self.storedWitness(number)
            let generated: StarlitCartoucheGenerated = try Core.generated(number: number)
            #expect(generated.level.fingerprint == witness.fingerprint, "a level fingerprint differs")
            #expect(generated.skipped == witness.skipped)
        }
    }

    @Test func theCertifiedPlanOfLevelOneWinsThroughTheAdapter() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let generated: StarlitCartoucheGenerated = try Core.generated(number: 1)
        #expect(generated.plan.legs == [.leg(4, 1), .leg(5, 0)])
        for step in generated.plan.legs {
            #expect(core.apply(Self.act(step)) == .accepted)
            #expect(Self.holdsDefaultChoice(core), "the choice resets after each leg")
        }
        #expect(core.play.stage == .won && core.outcome?.code == Core.wonCode)
        #expect(core.play.report.matched && core.play.failure == nil)
        #expect(core.play.records.count == generated.plan.size)
        #expect(core.snapshot(time: 0).isWon)
        // A won play is final: a leg, undo and redo are the kernel's stage refusal; choosing is still accepted.
        let stage: ActionResult = .rejected(.rule(code: "r02-g16.stage"))
        #expect(core.apply(Self.act("route.fly", [4, 0])) == stage)
        #expect(core.apply(Self.act("play.undo")) == stage)
        #expect(core.apply(Self.act("play.redo")) == stage)
        #expect(core.apply(Self.act("route.choose", [2, 3])) == .accepted)
        #expect(core.chosenStar == 2 && core.chosenWait == 3)
    }

    @Test func everyActionIsAppliedOrRefusedWithItsCode() async throws {
        // Level 1: 6 stars, the ship at star 1 (one corridor, to star 4), budget 9.
        let core: Core = try await Core.prepare(seed: 0)
        let level: StarlitCartoucheLevel = core.play.level
        #expect(level.stars.count == 6 && level.budget == 9 && core.play.star == 1)
        let opening: StateDigest = try Self.digest(core)
        let illegal: [ExperienceAction] = [Self.act("route.fly", [12, 0]), Self.act("route.fly", [6, 0]),
                                           Self.act("route.fly", [11, 0]), Self.act("route.fly", [1, 0]),
                                           Self.act("route.fly", [3, 0]), Self.act("route.fly", [-1, 0]),
                                           Self.act("route.fly", [4, 9]), Self.act("route.fly", [4, -1]),
                                           Self.act("route.fly", [4, 0.5]), Self.act("route.fly", [4.5, 0]),
                                           Self.act("route.fly", [.nan, 0]), Self.act("route.fly", [4]),
                                           Self.act("route.fly"), Self.act("route.fly", [4, 1, 1]),
                                           Self.act("route.choose", [1, 0]), Self.act("route.choose", [6, 0]),
                                           Self.act("route.choose", [11, 0]), Self.act("route.choose", [12, 0]),
                                           Self.act("route.choose", [-1, 0]), Self.act("route.choose", [2, 9]),
                                           Self.act("route.choose", [2, -1]), Self.act("route.choose", [2, 0.5]),
                                           Self.act("route.choose", [2.5, 0]), Self.act("route.choose", [2]),
                                           Self.act("route.choose", [.infinity, 0]),
                                           Self.act("play.undo"), Self.act("play.redo"),
                                           Self.act("play.undo", [1]), Self.act("level.next", [1]),
                                           Self.act("nope")]
        for action in illegal {
            var copy: Core = core
            let result: ActionResult = copy.apply(action)
            #expect(!result.isAccepted, "an illegal action was accepted")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening && copy.play.records.isEmpty, "a refusal changed the state")
            #expect(copy.chosenStar == core.chosenStar && copy.chosenWait == core.chosenWait)
        }
        var probe: Core = core
        // Outside the declared ranges or the value count: the engine's refusal; fractions: the adapter's.
        #expect(probe.apply(Self.act("route.fly", [12, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("route.fly", [-1, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("route.fly", [4, 9])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("route.choose", [12, 0])) == .rejected(.outOfRange(index: 0)))
        #expect(probe.apply(Self.act("route.choose", [2, 9])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("route.choose", [2, -1])) == .rejected(.outOfRange(index: 1)))
        #expect(probe.apply(Self.act("route.fly", [.nan, 0])) == .rejected(.nonFinite(index: 0)))
        #expect(probe.apply(Self.act("route.fly", [4])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        #expect(probe.apply(Self.act("route.choose", [2])) == .rejected(.wrongValueCount(expected: 2, found: 1)))
        let noValues: ActionResult = .rejected(.wrongValueCount(expected: 0, found: 1))
        #expect(probe.apply(Self.act("play.undo", [1])) == noValues)
        #expect(probe.apply(Self.act("play.redo", [1])) == noValues)
        #expect(probe.apply(Self.act("level.next", [1])) == noValues)
        let notWhole: ActionResult = .rejected(.rule(code: StarlitCartoucheExperienceRule.notWhole))
        #expect(probe.apply(Self.act("route.fly", [4, 0.5])) == notWhole)
        #expect(probe.apply(Self.act("route.fly", [4.5, 0])) == notWhole)
        #expect(probe.apply(Self.act("route.choose", [2, 0.5])) == notWhole)
        #expect(probe.apply(Self.act("route.choose", [2.5, 0])) == notWhole)
        // A chosen star the level lacks, or the ship's own star: the adapter's refusal.
        let choice: ActionResult = .rejected(.rule(code: StarlitCartoucheExperienceRule.choice))
        #expect(probe.apply(Self.act("route.choose", [1, 0])) == choice)
        #expect(probe.apply(Self.act("route.choose", [6, 0])) == choice)
        #expect(probe.apply(Self.act("route.choose", [11, 8])) == choice)
        // The kernel's refusals pass through with their codes.
        let action: ActionResult = .rejected(.rule(code: "r02-g16.action"))
        #expect(probe.apply(Self.act("route.fly", [6, 0])) == action)
        #expect(probe.apply(Self.act("route.fly", [11, 0])) == action)
        #expect(probe.apply(Self.act("route.fly", [1, 0])) == action)
        #expect(probe.apply(Self.act("route.fly", [3, 0])) == action)
        #expect(probe.apply(Self.act("play.undo")) == action)
        #expect(probe.apply(Self.act("play.redo")) == action)
        #expect(probe == core && probe.play.records.isEmpty && Self.holdsDefaultChoice(probe))
        // Every legal choice is accepted (a star without a corridor from the ship included).
        let others: [Int] = [0, 2, 3, 4, 5]
        for star in others {
            for wait in Core.waitRange {
                #expect(probe.apply(Self.act("route.choose", [Double(star), Double(wait)])) == .accepted)
                #expect(probe.chosenStar == star && probe.chosenWait == wait)
            }
        }
        #expect(try Self.digest(probe) == opening && probe == core)
        // Every legal action is accepted; each leg, undo, redo and level.next resets the choice.
        #expect(probe.apply(Self.act("route.fly", [4, 1])) == .accepted && probe.play.actionsSpent == 1)
        #expect(probe.play.star == 4 && Self.holdsDefaultChoice(probe) && probe.chosenStar == 1)
        #expect(probe.apply(Self.act("route.choose", [5, 6])) == .accepted)
        #expect(probe.apply(Self.act("play.undo")) == .accepted && probe.play.actionsSpent == 0)
        #expect(Self.holdsDefaultChoice(probe) && probe.chosenStar == 4)
        #expect(probe.apply(Self.act("route.choose", [5, 6])) == .accepted)
        #expect(probe.apply(Self.act("play.redo")) == .accepted && probe.play.actionsSpent == 1)
        #expect(Self.holdsDefaultChoice(probe))
        #expect(probe.apply(Self.act("route.choose", [5, 6])) == .accepted)
        // A refused leg keeps the choice.
        #expect(probe.apply(Self.act("route.fly", [3, 0])) == action)
        #expect(probe.chosenStar == 5 && probe.chosenWait == 6)
        #expect(probe.apply(Self.act("level.next")) == .accepted && probe.levelNumber == 2)
        #expect(probe.play.records.isEmpty && Self.holdsDefaultChoice(probe))
    }

    @Test func undoRestoresTheEarlierDigestAndRedoTheLaterOne() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("route.fly", [4, 1])) == .accepted)
        let afterLeg: StateDigest = try Self.digest(core)
        #expect(afterLeg != opening)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening && core.play.records.count == 2)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(try Self.digest(core) == afterLeg && core.play.records.count == 3)
        // A new leg after an undo (the same one again) clears the redo stack.
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("route.fly", [4, 1])) == .accepted)
        #expect(try Self.digest(core) == afterLeg)
        #expect(core.apply(Self.act("play.redo")) == .rejected(.rule(code: "r02-g16.action")))
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(try Self.digest(core) == opening)
    }

    @Test func choosingChangesTheSnapshotButNeverTheDigest() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let before: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let play: StarlitCartouchePlay = core.play
        var snapshots: [StarlitCartoucheSceneSnapshot] = []
        for star in 0..<play.level.stars.count where star != play.star {
            for wait in Core.waitRange {
                #expect(core.apply(Self.act("route.choose", [Double(star), Double(wait)])) == .accepted)
                let snapshot: StarlitCartoucheSceneSnapshot = core.snapshot(time: 1)
                #expect(snapshot.chosenStar == star && snapshot.chosenWait == wait)
                #expect(snapshot.report == play.report && snapshot.star == play.star)
                #expect(try Self.digest(core) == before && core.play == play)
                #expect(try core.snapshotPayload() == payload)
                snapshots.append(snapshot)
            }
        }
        #expect(snapshots.count == 45)
        for index in 1..<snapshots.count { #expect(snapshots[index] != snapshots[index - 1]) }
        // A refused choice keeps the chosen one.
        let chosen: (star: Int, wait: Int) = (core.chosenStar, core.chosenWait)
        let refusal: ActionResult = .rejected(.rule(code: StarlitCartoucheExperienceRule.choice))
        #expect(core.apply(Self.act("route.choose", [1, 2])) == refusal)
        #expect(core.apply(Self.act("route.choose", [7, 2])) == refusal)
        #expect(core.chosenStar == chosen.star && core.snapshot(time: 1).chosenWait == chosen.wait)
        // Reset, restore and level.next choose the default.
        var reset: Core = core
        reset.reset()
        #expect(Self.holdsDefaultChoice(reset) && reset.play.records.isEmpty)
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && Self.holdsDefaultChoice(restored))
        var next: Core = core
        #expect(next.apply(Self.act("level.next")) == .accepted)
        #expect(Self.holdsDefaultChoice(next))
    }

    @Test func aFailingLegFailsAndUndoReturnsToPlaying() async throws {
        // Level 1: the first leg the kernel accepts that fails the level (a window, hazard or stroke).
        let opening: Core = try Core.opening(number: 1)
        let leg: (star: Int, wait: Int) = try #require(Self.failingLeg(opening))
        var core: Core = opening
        let openingDigest: StateDigest = try Self.digest(core)
        #expect(core.apply(Self.act("route.fly", [Double(leg.star), Double(leg.wait)])) == .accepted)
        #expect(core.play.stage == .failed && core.outcome?.code == Core.failedCode && core.play.failure != nil)
        #expect(core.play.star == opening.play.star && core.play.beat == 0 && Self.holdsDefaultChoice(core))
        let snapshot: StarlitCartoucheSceneSnapshot = core.snapshot(time: 0)
        #expect(snapshot.failure == core.play.failure && snapshot.failedLeg?.to == leg.star)
        #expect(snapshot.failedLeg?.wait == leg.wait && snapshot.failedLeg?.from == opening.play.star)
        let stage: ActionResult = .rejected(.rule(code: "r02-g16.stage"))
        #expect(core.apply(Self.act("route.fly", [4, 1])) == stage)
        #expect(core.apply(Self.act("route.choose", [0, 4])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.play.stage == .playing && core.outcome == nil && Self.holdsDefaultChoice(core))
        #expect(try Self.digest(core) == openingDigest)
    }

    @Test func levelNextWrapsAndResetReturns() async throws {
        var core: Core = try await Core.prepare(seed: 99)
        #expect(core.levelNumber == 100)
        let first: StarlitCartoucheAction = try #require(try Core.generated(number: 100).plan.legs.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("level.next")) == .accepted)
        #expect(core.levelNumber == 1 && core.play.records.isEmpty && core.play.stage == .playing)
        #expect(core.play.level == (try Core.level(number: 1)))
        #expect(Self.holdsDefaultChoice(core))
        core.setQualityTier(2)
        core.reset()
        #expect(core.levelNumber == 100 && core.play.records.isEmpty && core.qualityTier == 2)
        let fresh: Core = try await Core.prepare(seed: 99)
        #expect(core == fresh)
        #expect(try Self.digest(core) == Self.digest(fresh))
        #expect(core.chosenStar == fresh.chosenStar && core.chosenWait == fresh.chosenWait)
    }

    @Test func snapshotRestoreRoundTripAndRefusals() async throws {
        // Level 21 after a leg, an undo, a redo and an undo.
        var core: Core = try await Core.prepare(seed: 20)
        let first: StarlitCartoucheAction = try #require(try Core.generated(number: 21).plan.legs.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        #expect(core.apply(Self.act("play.redo")) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        let savedDigest: StateDigest = try Self.digest(core)
        let payload: Data = try core.snapshotPayload()
        let text: String = String(decoding: payload, as: UTF8.self)
        #expect(text.hasPrefix("{\"level\":21,\"records\":["))
        let restored: Core = try Core.restore(payload: payload, seed: 20)
        let restoredDigest: StateDigest = try Self.digest(restored)
        #expect(restored == core && restoredDigest == savedDigest)
        #expect(restored.play.canRedo && restored.openingNumber == 21 && Self.holdsDefaultChoice(restored))
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
        #expect(throws: StarlitCartoucheRestoreRefusal.damaged) { try Core.restore(payload: Data("{}".utf8), seed: 20) }
        #expect(throws: StarlitCartoucheRestoreRefusal.damaged) {
            try Core.restore(payload: Data("nope".utf8), seed: 20)
        }
        #expect(throws: StarlitCartoucheRestoreRefusal.damaged) {
            try Core.restore(payload: Data("{\"level\":\"21\",\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: StarlitCartoucheRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data("{\"level\":0,\"records\":[]}".utf8), seed: 20)
        }
        #expect(throws: StarlitCartoucheRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data("{\"level\":101,\"records\":[]}".utf8), seed: 20)
        }
        // A trace of level 21 restored as level 22 (another seed).
        let wrongLevel: Data = Data(text.replacingOccurrences(of: "{\"level\":21,", with: "{\"level\":22,").utf8)
        #expect(wrongLevel != payload)
        #expect(throws: StarlitCartoucheRestoreRefusal.kernel(.malformed("seed 0"))) {
            try Core.restore(payload: wrongLevel, seed: 20)
        }
        // A record of a newer schema.
        let newer: Data = Data(text.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":2").utf8)
        #expect(newer != payload)
        #expect(throws: StarlitCartoucheRestoreRefusal.kernel(.malformed("schema 0"))) {
            try Core.restore(payload: newer, seed: 20)
        }
        // An edited trace: the first record's index changed.
        let edited: Data = Data(text.replacingOccurrences(of: "\"index\":0,", with: "\"index\":3,").utf8)
        #expect(edited != payload)
        #expect(throws: StarlitCartoucheRestoreRefusal.kernel(.malformed("record 0"))) {
            try Core.restore(payload: edited, seed: 20)
        }
    }

    @Test func theEngineRefusesAnEnvelopeOfANewerSchema() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 0)
        try engine.activate()
        // Level 1: the first leg of its certified plan.
        #expect(engine.handle(control: "route.fly", values: [4, 1]) == .accepted)
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
        // Level 41 after the first leg of its certified plan.
        var core: Core = try await Core.prepare(seed: 40)
        let first: StarlitCartoucheAction = try #require(try Core.generated(number: 41).plan.legs.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        let play: StarlitCartouchePlay = core.play
        let level: StarlitCartoucheLevel = play.level
        let snapshot: StarlitCartoucheSceneSnapshot = core.snapshot(time: 2.5)
        #expect(snapshot.stars == level.stars && snapshot.corridors == level.corridors)
        #expect(snapshot.hazards == level.hazards && snapshot.symbol == level.symbol)
        var positions: [StarlitCartoucheVector] = []
        for star in level.stars { positions.append(star.position(at: play.beat)) }
        #expect(snapshot.positions == positions && snapshot.beat == play.beat && play.beat > 0)
        #expect(snapshot.legs == play.legs && snapshot.drawn == play.drawn.sorted())
        #expect(snapshot.report == play.report && snapshot.star == play.star)
        #expect(snapshot.stage == play.stage && snapshot.failure == play.failure && snapshot.failedLeg == nil)
        #expect(snapshot.actionsLeft == play.actionsLeft && snapshot.budget == level.budget)
        #expect(snapshot.beacon == level.beacon && snapshot.deadline == level.deadline)
        #expect(snapshot.levelNumber == 41 && snapshot.time == 2.5)
        #expect(snapshot.chosenStar == core.chosenStar && snapshot.chosenWait == core.chosenWait)
        #expect(core.renderTier == StarlitCartoucheTier.of(0))
    }
}
