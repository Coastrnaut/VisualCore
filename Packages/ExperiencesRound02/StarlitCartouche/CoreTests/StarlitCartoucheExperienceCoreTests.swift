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
// Feature 455 (R02-G16-05) T-R02G1605-004: schema 2 and digest v2, ten controls, `level.next` to the next open level
// (no wrap; `r02-g16.locked` when none), and `StarlitCartoucheProgressionCoreTests` below: the progression controls
// and their refusals, campaign stars and unlocks, practice (budget 24, no stars, no unlocks), a locked daily level
// played without opening it, progress and mode digested but never the tutorial step or the choice, the tutorial steps,
// the schema-2 round trip, the migration of a schema-1 payload and the refusal of a newer schema.
import Foundation
import Testing
@testable import StarlitCartoucheCore
import VisualCoreDiagnostics
import VisualCoreExperience
import VisualCorePersistence
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
        #expect(Core.experienceID == "r02-g16.starlit-cartouche" && Core.schemaVersion == 2)
        #expect(Core.digestDomain == "r02-g16.starlit-cartouche.v2")
        #expect(Core.controls.map(\.id) == Core.actionIDs)
        let ids: [String] = ["route.fly", "play.undo", "play.redo", "level.next", "route.choose", "level.select",
                             "mode.daily", "mode.practice", "mode.campaign", "tutorial.dismiss"]
        #expect(Core.actionIDs == ids)
        #expect(Core.controls[0].ranges == [0...11, 0...8])
        #expect(Core.controls[4].ranges == [0...11, 0...8])
        #expect(Core.controls[5].ranges == [1...100])
        #expect(Core.controls[6].ranges == [1...9999, 1...12, 1...31])
        let plainIndices: [Int] = [1, 2, 3, 7, 8, 9]
        for index in plainIndices { #expect(Core.controls[index].ranges.isEmpty) }
        #expect(Core.qualityTiers == 3 && Core.qualityTiers == StarlitCartoucheTier.all.count)
        #expect(Core.migrations.currentVersion == 2)
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
        #expect(StarlitCartoucheExperienceRule.locked == "r02-g16.locked")
        #expect(StarlitCartoucheExperienceRule.date == "r02-g16.date")
        #expect(Core.practiceBudget == 24)
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
        // Every legal action is accepted; each leg, undo, redo and new opening resets the choice.
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
        // Feature 455: `level.next` needs the next level open; level 2 is not open until level 1 is won.
        #expect(probe.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g16.locked")))
        #expect(probe.chosenStar == 5 && probe.chosenWait == 6)
        #expect(probe.apply(Self.act("mode.practice")) == .accepted && probe.levelNumber == 1)
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
        // Reset, restore and a new opening (here practice; since feature 455 `level.next` needs the next level open)
        // choose the default.
        var reset: Core = core
        reset.reset()
        #expect(Self.holdsDefaultChoice(reset) && reset.play.records.isEmpty)
        let restored: Core = try Core.restore(payload: try core.snapshotPayload(), seed: 0)
        #expect(restored == core && Self.holdsDefaultChoice(restored))
        var next: Core = core
        #expect(next.apply(Self.act("mode.practice")) == .accepted)
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

    @Test func levelNextNeedsAnOpenLevelAndResetReturns() async throws {
        var core: Core = try await Core.prepare(seed: 99)
        #expect(core.levelNumber == 100)
        let hundred: StarlitCartoucheGenerated = try Core.generated(number: 100)
        let first: StarlitCartoucheAction = try #require(hundred.plan.legs.first)
        #expect(core.apply(Self.act(first)) == .accepted)
        // Feature 455: no wrap; after winning level 100, `level.next` is still refused and level 1 is chosen with
        // `level.select`.
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g16.locked")))
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        for step in hundred.plan.legs { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.solved[100] != nil && core.progress.frontier == 100)
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g16.locked")))
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
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
        let prefix: String = "{\"level\":21,\"mode\":{\"mode\":\"campaign\"},\"progress\":{\"frontier\":21,"
        #expect(text.hasPrefix(prefix))
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
        let rest: String = ",\"mode\":{\"mode\":\"campaign\"},"
            + "\"progress\":{\"frontier\":1,\"solved\":[]},\"records\":[]}"
        #expect(throws: StarlitCartoucheRestoreRefusal.levelNumber(0)) {
            try Core.restore(payload: Data(("{\"level\":0" + rest).utf8), seed: 20)
        }
        #expect(throws: StarlitCartoucheRestoreRefusal.levelNumber(101)) {
            try Core.restore(payload: Data(("{\"level\":101" + rest).utf8), seed: 20)
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

/// Feature 455 (R02-G16-05) T-R02G1605-004 (FR-R02G1605-001, 004 … 007; clarifications Q2–Q5): the adapter's teaching
/// and progression, modelled on feature 445's Voxel Origami adapter tests. Level facts used: level 1's certified plan
/// is leg 4 after 1 beat then leg 5 after 0 beats (budget 9); levels 1 … 3 carry the tutorial. Explicit types, plain
/// loops, no wall-clock asserts.
@Suite struct StarlitCartoucheProgressionCoreTests {
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

    /// The certified plan legs of level `number`.
    static func plan(_ number: Int) throws -> [StarlitCartoucheAction] {
        try Core.generated(number: number).plan.legs
    }

    /// The first leg from `core` (stars by index, waits 0 … 8) the kernel accepts that leaves the play in `stage`.
    static func leg(from core: Core, leaving stage: StarlitCartoucheStage) -> StarlitCartoucheAction? {
        for star in 0..<core.play.level.stars.count where star != core.play.star {
            for wait in Core.waitRange {
                var trial: Core = core
                guard trial.apply(act("route.fly", [Double(star), Double(wait)])) == .accepted else { continue }
                if trial.play.stage == stage { return .leg(star, wait) }
            }
        }
        return nil
    }

    /// A daily date of 2026 whose daily level is not a tutorial level (4 … 100) and not open on a fresh opening of
    /// level 1, with that level; the level is computed with `StarlitCartoucheProgress.dailyLevel`.
    static func plainDaily() throws -> (date: [Double], level: Int) {
        let date: [Double] = [2026, 11, 18]
        let level: Int = try #require(StarlitCartoucheProgress.dailyLevel(year: 2026, month: 11, day: 18))
        try #require(level > StarlitCartoucheTutorialStep.tutorialLevels.upperBound)
        return (date, level)
    }

    @Test func theProgressionControlsRefuseWhatTheyMust() async throws {
        let core: Core = try await Core.prepare(seed: 0)
        let opening: StateDigest = try Self.digest(core)
        let locked: ActionResult = .rejected(.rule(code: StarlitCartoucheExperienceRule.locked))
        let date: ActionResult = .rejected(.rule(code: StarlitCartoucheExperienceRule.date))
        let notWhole: ActionResult = .rejected(.rule(code: StarlitCartoucheExperienceRule.notWhole))
        #expect(locked == .rejected(.rule(code: "r02-g16.locked")) && date == .rejected(.rule(code: "r02-g16.date")))
        let actions: [ExperienceAction] = [
            Self.act("level.select", [2]), Self.act("level.select", [100]), Self.act("level.select", [0]),
            Self.act("level.select", [101]), Self.act("level.select", [1.5]), Self.act("level.select", []),
            Self.act("mode.daily", [0, 1, 1]), Self.act("mode.daily", [2026, 13, 1]),
            Self.act("mode.daily", [2026, 1, 32]), Self.act("mode.daily", [2026, 2, 30]),
            Self.act("mode.daily", [2025, 2, 29]), Self.act("mode.daily", [2026, 4, 31]),
            Self.act("mode.daily", [2026, 1.5, 1]), Self.act("mode.daily", [2026, 1]),
            Self.act("mode.practice", [1]), Self.act("mode.campaign", [1]), Self.act("tutorial.dismiss", [1]),
            Self.act("level.next"),
        ]
        let expected: [ActionResult] = [
            locked, locked, .rejected(.outOfRange(index: 0)),
            .rejected(.outOfRange(index: 0)), notWhole, .rejected(.wrongValueCount(expected: 1, found: 0)),
            .rejected(.outOfRange(index: 0)), .rejected(.outOfRange(index: 1)),
            .rejected(.outOfRange(index: 2)), date,
            date, date,
            notWhole, .rejected(.wrongValueCount(expected: 3, found: 2)),
            .rejected(.wrongValueCount(expected: 0, found: 1)), .rejected(.wrongValueCount(expected: 0, found: 1)),
            .rejected(.wrongValueCount(expected: 0, found: 1)),
            locked,
        ]
        #expect(actions.count == expected.count)
        for index in actions.indices {
            var copy: Core = core
            #expect(copy.apply(actions[index]) == expected[index], "\(actions[index].control) \(actions[index].values)")
            let after: StateDigest = try Self.digest(copy)
            #expect(copy == core && after == opening, "\(actions[index].control) \(actions[index].values)")
            #expect(copy.chosenStar == core.chosenStar && copy.chosenWait == core.chosenWait)
        }
        // A leap year's 29 February is a date.
        var leap: Core = core
        #expect(leap.apply(Self.act("mode.daily", [2028, 2, 29])) == .accepted)
        let leapLevel: Int = try #require(StarlitCartoucheProgress.dailyLevel(year: 2028, month: 2, day: 29))
        #expect(leap.mode == .daily(level: leapLevel) && leap.levelNumber == leapLevel)
        #expect(leap.play.records.isEmpty && leap.play.stage == .playing)
    }

    @Test func campaignWinsRecordStarsAndOpenTheNextLevel() async throws {
        let actions: [StarlitCartoucheAction] = try Self.plan(1)
        let certified: Int = actions.count
        #expect(certified == 2 && actions == [.leg(4, 1), .leg(5, 0)])
        // A win that spent one undone leg more than the plan: 2 stars, level 2 opened.
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.certifiedLegs == certified && core.mode == .campaign && core.progress.frontier == 1)
        #expect(core.band == 1)
        #expect(core.apply(Self.act(actions[0])) == .accepted)
        #expect(core.apply(Self.act("play.undo")) == .accepted)
        for step in actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && StarlitCartoucheProgress.actionsSpent(core.play) == certified + 1)
        let twoStars: Int = StarlitCartoucheProgress.stars(actionsSpent: certified + 1, certified: certified)
        #expect(twoStars == 2)
        let twoStarResult = StarlitCartoucheProgress.Result(actionsSpent: certified + 1, stars: twoStars)
        #expect(core.progress.solved[1] == twoStarResult)
        #expect(core.progress.frontier == 2 && core.progress.isOpen(2) && !core.progress.isOpen(3))
        // level.next goes to the newly opened level 2, fresh, with its tutorial.
        var next: Core = core
        #expect(next.apply(Self.act("level.next")) == .accepted)
        #expect(next.levelNumber == 2 && next.play.records.isEmpty && next.mode == .campaign)
        let secondLegs: Int = try Self.plan(2).count
        #expect(next.tutorial == .fly && next.certifiedLegs == secondLegs)
        // A better result replaces it: the plan alone, 3 stars.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        #expect(core.levelNumber == 1 && core.play.records.isEmpty && core.mode == .campaign)
        for step in actions { #expect(core.apply(Self.act(step)) == .accepted) }
        let best: StarlitCartoucheProgress.Result = StarlitCartoucheProgress.Result(actionsSpent: certified, stars: 3)
        #expect(core.progress.solved[1] == best)
        // A worse result keeps the best one: four undone legs more than the plan (1 star) change nothing.
        #expect(core.apply(Self.act("level.select", [1])) == .accepted)
        for _ in 0..<4 {
            #expect(core.apply(Self.act(actions[0])) == .accepted)
            #expect(core.apply(Self.act("play.undo")) == .accepted)
        }
        for step in actions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && StarlitCartoucheProgress.actionsSpent(core.play) == certified + 4)
        #expect(StarlitCartoucheProgress.stars(actionsSpent: certified + 4, certified: certified) == 1)
        #expect(core.progress.solved[1] == best && core.progress.frontier == 2)
        // The frontier: level 2 can be chosen, level 3 cannot.
        #expect(core.apply(Self.act("level.select", [3])) == .rejected(.rule(code: "r02-g16.locked")))
        #expect(core.apply(Self.act("level.select", [2])) == .accepted)
        #expect(core.levelNumber == 2 && core.play.stage == .playing && core.tutorial == .fly)
        // level.next from the frontier is refused: no next open level.
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g16.locked")))
        #expect(core.levelNumber == 2)
    }

    @Test func practiceAndDailyFollowTheirRules() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        let certified: StarlitCartoucheLevel = try Core.level(number: 1)
        // Practice: a copy of the level with the budget raised to 24; a win records nothing and opens nothing.
        #expect(core.apply(Self.act("route.choose", [0, 3])) == .accepted)
        #expect(core.apply(Self.act("mode.practice")) == .accepted)
        #expect(core.mode == .practice && core.levelNumber == 1 && core.play.records.isEmpty)
        #expect(core.play.level.budget == 24 && core.play.actionsLeft == 24 && core.tutorial == .fly)
        #expect(core.chosenStar == 4 && core.chosenWait == 0)
        #expect(Core.practiceBudget == 24 && certified.budget != 24)
        #expect(core.play.level.stars == certified.stars && core.play.level.corridors == certified.corridors)
        #expect(core.play.level.hazards == certified.hazards && core.play.level.symbol == certified.symbol)
        #expect(core.play.level.seed == certified.seed && core.play.level.tutorial == certified.tutorial)
        #expect(core.play.level.id == certified.id && core.play.level.difficulty == certified.difficulty)
        #expect(core.play.level.deadline == certified.deadline && core.play.level.beacon == certified.beacon)
        #expect(try Core.practiceLevel(of: certified) == core.play.level)
        let before: StarlitCartoucheProgress = core.progress
        for step in try Self.plan(1) { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress == before && core.progress.solved.isEmpty)
        #expect(core.progress.frontier == 1)
        // Campaign returns to the current level when it is open, fresh, with the certified budget.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1 && core.play.records.isEmpty)
        #expect(core.play.level == certified && core.play.actionsLeft == certified.budget)
        // Daily: the date's level, playable while still locked; level.next from it is refused; a win records the
        // level's best result and stars and opens nothing.
        let (dailyDate, daily): ([Double], Int) = try Self.plainDaily()
        #expect(!core.progress.isOpen(daily))
        #expect(core.apply(Self.act("mode.daily", dailyDate)) == .accepted)
        #expect(core.mode == .daily(level: daily) && core.levelNumber == daily && core.tutorial == .done)
        let dailyCertified: StarlitCartoucheLevel = try Core.level(number: daily)
        #expect(core.play.level == dailyCertified && !core.progress.isOpen(daily))
        #expect(core.band == StarlitCartoucheProgress.band(of: daily))
        #expect(core.apply(Self.act("level.next")) == .rejected(.rule(code: "r02-g16.locked")))
        let dailyActions: [StarlitCartoucheAction] = try Self.plan(daily)
        #expect(core.certifiedLegs == dailyActions.count)
        for step in dailyActions { #expect(core.apply(Self.act(step)) == .accepted) }
        #expect(core.play.stage == .won && core.progress.frontier == 1 && !core.progress.isOpen(daily))
        let result: StarlitCartoucheProgress.Result = try #require(core.progress.solved[daily])
        #expect(result == StarlitCartoucheProgress.Result(actionsSpent: dailyActions.count, stars: 3))
        // Campaign from a level that is not open goes to the frontier.
        #expect(core.apply(Self.act("mode.campaign")) == .accepted)
        #expect(core.mode == .campaign && core.levelNumber == 1)
        // A daily tutorial level carries the tutorial: 2026-01-01 is level 1.
        #expect(StarlitCartoucheProgress.dailyLevel(year: 2026, month: 1, day: 1) == 1)
        #expect(core.apply(Self.act("mode.daily", [2026, 1, 1])) == .accepted)
        #expect(core.mode == .daily(level: 1) && core.levelNumber == 1 && core.tutorial == .fly)
    }

    @Test func progressAndModeAreDigestedButNotTheStepOrTheChoice() async throws {
        // The same fresh play in another mode digests differently.
        var campaign: Core = try await Core.prepare(seed: 0)
        var practice: Core = campaign
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(campaign.apply(Self.act("mode.campaign")) == .accepted)
        #expect(try Self.digest(practice) != (try Self.digest(campaign)))
        var dailyOne: Core = campaign
        #expect(dailyOne.apply(Self.act("mode.daily", [2026, 1, 1])) == .accepted)
        #expect(dailyOne.play == campaign.play && dailyOne.levelNumber == campaign.levelNumber)
        #expect(try Self.digest(dailyOne) != (try Self.digest(campaign)))
        // The same fresh play after a campaign win: only the progress differs, and the digest with it.
        var won: Core = campaign
        for step in try Self.plan(1) { #expect(won.apply(Self.act(step)) == .accepted) }
        #expect(won.apply(Self.act("level.select", [1])) == .accepted)
        #expect(won.play == campaign.play && won.mode == campaign.mode && won.progress != campaign.progress)
        #expect(try Self.digest(won) != (try Self.digest(campaign)))
        // Neither the choice nor the tutorial step is digested.
        var chosen: Core = campaign
        #expect(chosen.apply(Self.act("route.choose", [0, 7])) == .accepted)
        let campaignDigest: StateDigest = try Self.digest(campaign)
        #expect(chosen == campaign)
        #expect(try Self.digest(chosen) == campaignDigest)
        var dismissed: Core = campaign
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed != campaign)
        #expect(try Self.digest(dismissed) == campaignDigest)
    }

    @Test func theTutorialAdvancesInOrderAndIsNotDigested() async throws {
        var core: Core = try await Core.prepare(seed: 0)
        #expect(core.tutorial == .fly && core.tutorial.text.hasPrefix("Tap a star to choose where to fly"))
        // Dismissing ends it; the step is state (==) and saved, but never digested.
        let digest: StateDigest = try Self.digest(core)
        var dismissed: Core = core
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted)
        #expect(dismissed.tutorial == .done && dismissed != core && dismissed.play == core.play)
        #expect(try Self.digest(dismissed) == digest)
        #expect(try dismissed.snapshotPayload() != (try core.snapshotPayload()))
        #expect(dismissed.apply(Self.act("tutorial.dismiss")) == .accepted && dismissed.tutorial == .done)
        // Choosing a destination is no leg: fly stays.
        var chosen: Core = core
        #expect(chosen.apply(Self.act("route.choose", [2, 3])) == .accepted && chosen.tutorial == .fly)
        // A refused leg moves nothing.
        #expect(chosen.apply(Self.act("route.fly", [3, 0])) == .rejected(.rule(code: "r02-g16.action")))
        #expect(chosen.tutorial == .fly)
        // A leg: fly → symbol; an undo does not move it back, nor a redo forward.
        let first: StarlitCartoucheAction = try #require(try Self.plan(1).first)
        #expect(core.apply(Self.act(first)) == .accepted)
        #expect(core.play.stage == .playing && core.tutorial == .symbol)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .symbol)
        #expect(core.apply(Self.act("play.redo")) == .accepted && core.tutorial == .symbol)
        // A second leg that keeps the play open: symbol → recover; recover lasts.
        let open: StarlitCartoucheAction = try #require(Self.leg(from: core, leaving: .playing))
        #expect(core.apply(Self.act(open)) == .accepted)
        #expect(core.play.stage == .playing && core.tutorial == .recover)
        #expect(core.apply(Self.act("play.undo")) == .accepted && core.tutorial == .recover)
        // The end of the level ends it: the certified plan's last leg wins.
        let last: StarlitCartoucheAction = try #require(try Self.plan(1).last)
        #expect(core.apply(Self.act(last)) == .accepted)
        #expect(core.play.stage == .won && core.tutorial == .done)
        // A winning leg moves any step straight to done: level 1's plan after a fresh opening goes fly → symbol → done.
        var winner: Core = try Core.opening(number: 1)
        let plan: [StarlitCartoucheAction] = try Self.plan(1)
        #expect(winner.apply(Self.act(plan[0])) == .accepted && winner.tutorial == .symbol)
        #expect(winner.apply(Self.act(plan[1])) == .accepted)
        #expect(winner.play.stage == .won && winner.tutorial == .done)
        // A failing leg ends it; the undo that retries does not bring it back; a redo that restores the failed play
        // ends a step restored as fly.
        var broken: Core = try Core.opening(number: 1)
        let failing: StarlitCartoucheAction = try #require(Self.leg(from: broken, leaving: .failed))
        #expect(broken.apply(Self.act(failing)) == .accepted)
        #expect(broken.play.stage == .failed && broken.tutorial == .done)
        #expect(broken.progress.solved.isEmpty && broken.progress.frontier == 1)
        #expect(broken.apply(Self.act("play.undo")) == .accepted)
        #expect(broken.play.stage == .playing && broken.tutorial == .done)
        let brokenText: String = String(decoding: try broken.snapshotPayload(), as: UTF8.self)
        let flyText: String = brokenText.replacingOccurrences(of: "\"tutorial\":\"done\"", with: "\"tutorial\":\"fly\"")
        #expect(flyText != brokenText)
        var redone: Core = try Core.restore(payload: Data(flyText.utf8), seed: 0)
        #expect(redone.tutorial == .fly && redone.play == broken.play && redone.play.canRedo)
        #expect(redone.apply(Self.act("play.redo")) == .accepted)
        #expect(redone.play.stage == .failed && redone.tutorial == .done)
        // Choosing a level or a mode restarts the step of that level; a level without the tutorial starts done.
        #expect(broken.apply(Self.act("mode.practice")) == .accepted)
        #expect(broken.tutorial == StarlitCartoucheTutorialStep.initial(level: broken.levelNumber))
        #expect(broken.tutorial == .fly)
        for number in 1...6 {
            let opening: Core = try Core.opening(number: number)
            let expected: StarlitCartoucheTutorialStep = number <= 3 ? .fly : .done
            #expect(opening.tutorial == expected && StarlitCartoucheTutorialStep.initial(level: number) == expected)
        }
        var plain: Core = try Core.opening(number: 4)
        let plainFirst: StarlitCartoucheAction = try #require(try Self.plan(4).first)
        #expect(plain.apply(Self.act(plainFirst)) == .accepted && plain.tutorial == .done)
        // The step is saved and restored.
        var saved: Core = try await Core.prepare(seed: 0)
        #expect(saved.apply(Self.act(first)) == .accepted)
        let payload: Data = try saved.snapshotPayload()
        #expect(String(decoding: payload, as: UTF8.self).hasSuffix(",\"tutorial\":\"symbol\"}"))
        let restored: Core = try Core.restore(payload: payload, seed: 0)
        #expect(restored == saved && restored.tutorial == .symbol)
    }

    @Test func theSchemaTwoPayloadRoundTripsInEveryModeAndRefusesDamage() async throws {
        // Campaign with progress: level 1 won, level 2 reached with level.next.
        var campaign: Core = try await Core.prepare(seed: 0)
        for step in try Self.plan(1) { #expect(campaign.apply(Self.act(step)) == .accepted) }
        #expect(campaign.apply(Self.act("level.next")) == .accepted)
        #expect(campaign.levelNumber == 2 && campaign.tutorial == .fly)
        // Practice: a leg on the practice copy.
        var practice: Core = try await Core.prepare(seed: 0)
        #expect(practice.apply(Self.act("mode.practice")) == .accepted)
        #expect(practice.apply(Self.act("route.fly", [4, 1])) == .accepted)
        // Daily: the first certified leg of the date's level.
        let (dailyDate, dailyLevel): ([Double], Int) = try Self.plainDaily()
        var daily: Core = try await Core.prepare(seed: 0)
        #expect(daily.apply(Self.act("mode.daily", dailyDate)) == .accepted)
        let dailyFirst: StarlitCartoucheAction = try #require(try Self.plan(dailyLevel).first)
        #expect(daily.apply(Self.act(dailyFirst)) == .accepted)
        let cores: [Core] = [campaign, practice, daily]
        for core in cores {
            let payload: Data = try core.snapshotPayload()
            #expect(try core.snapshotPayload() == payload)
            let restored: Core = try Core.restore(payload: payload, seed: 0)
            let restoredDigest: StateDigest = try Self.digest(restored)
            let savedDigest: StateDigest = try Self.digest(core)
            #expect(restored == core && restoredDigest == savedDigest, "\(core.mode)")
            #expect(restored.certifiedLegs == core.certifiedLegs && restored.openingNumber == 1)
            var reset: Core = restored
            reset.reset()
            #expect(reset == (try Core.opening(number: 1)))
        }
        #expect(practice.play.level.budget == 24)
        let restoredPractice: Core = try Core.restore(payload: try practice.snapshotPayload(), seed: 0)
        #expect(restoredPractice.play.level.budget == 24 && restoredPractice.mode == .practice)
        let campaignText: String = String(decoding: try campaign.snapshotPayload(), as: UTF8.self)
        let certified: Int = try Self.plan(1).count
        let progressText: String = "\"progress\":{\"frontier\":2,"
            + "\"solved\":[{\"actionsSpent\":\(certified),\"level\":1,\"stars\":3}]}"
        #expect(campaignText.contains(progressText))
        #expect(campaignText.hasPrefix("{\"level\":2,\"mode\":{\"mode\":\"campaign\"},"))
        #expect(campaignText.hasSuffix(",\"tutorial\":\"fly\"}"))
        let dailyText: String = String(decoding: try daily.snapshotPayload(), as: UTF8.self)
        let dailyPrefix: String = "{\"level\":\(dailyLevel),\"mode\":{\"level\":\(dailyLevel)"
        #expect(dailyText.hasPrefix(dailyPrefix + ",\"mode\":\"daily\"},"))
        // Damaged: a daily mode naming another level, an unknown mode, an invalid frontier, invalid stars, an unknown
        // tutorial step.
        let otherPrefix: String = "{\"level\":\(dailyLevel),\"mode\":{\"level\":\(dailyLevel - 1)"
        let otherDaily: Data = Data(dailyText.replacingOccurrences(of: dailyPrefix, with: otherPrefix).utf8)
        let unknownMode: Data = Data(campaignText.replacingOccurrences(of: "\"mode\":\"campaign\"",
                                                                       with: "\"mode\":\"arcade\"").utf8)
        let badFrontier: Data = Data(campaignText.replacingOccurrences(of: "\"frontier\":2",
                                                                       with: "\"frontier\":0").utf8)
        let badStars: Data = Data(campaignText.replacingOccurrences(of: "\"stars\":3", with: "\"stars\":4").utf8)
        let badStep: Data = Data(campaignText.replacingOccurrences(of: "\"tutorial\":\"fly\"",
                                                                   with: "\"tutorial\":\"later\"").utf8)
        let damaged: [Data] = [otherDaily, unknownMode, badFrontier, badStars, badStep]
        let campaignPayload: Data = try campaign.snapshotPayload()
        let dailyPayload: Data = try daily.snapshotPayload()
        for payload in damaged {
            #expect(payload != campaignPayload && payload != dailyPayload)
            #expect(throws: StarlitCartoucheRestoreRefusal.damaged) { try Core.restore(payload: payload, seed: 0) }
        }
        // A payload without the tutorial key starts the tutorial at the level's first step.
        let noStep: Data = Data(campaignText.replacingOccurrences(of: ",\"tutorial\":\"fly\"", with: "").utf8)
        #expect(noStep != campaignPayload)
        let restoredNoStep: Core = try Core.restore(payload: noStep, seed: 0)
        #expect(restoredNoStep == campaign)
    }

    @Test func aSchemaOnePayloadMigratesAndANewerSchemaIsRefused() async throws {
        // Level 3 after its first certified leg: the tutorial has advanced, which schema 1 did not save.
        var core: Core = try await Core.prepare(seed: 2)
        #expect(core.levelNumber == 3)
        let plan: [StarlitCartoucheAction] = try Self.plan(3)
        try #require(plan.count >= 2)
        #expect(core.apply(Self.act(plan[0])) == .accepted)
        #expect(core.tutorial == .symbol)
        let records: Data = try Core.payloadEncoder().encode(core.play.records)
        let recordsObject: Any = try JSONSerialization.jsonObject(with: records)
        let schemaOne: [String: Any] = ["level": 3, "records": recordsObject]
        let migrated: [String: Any] = try Core.migratedToSchemaTwo(schemaOne)
        let chained: [String: Any] = try Core.migrations.migrate(schemaOne, from: 1)
        let data: Data = try JSONSerialization.data(withJSONObject: migrated, options: [.sortedKeys])
        let chainedData: Data = try JSONSerialization.data(withJSONObject: chained, options: [.sortedKeys])
        #expect(data == chainedData)
        let restored: Core = try Core.restore(payload: data, seed: 2)
        #expect(restored.levelNumber == 3 && restored.play == core.play && restored.mode == .campaign)
        #expect(restored.progress.frontier == 3 && restored.progress.solved.isEmpty)
        #expect(restored.progress.isOpen(1) && restored.progress.isOpen(3) && !restored.progress.isOpen(4))
        #expect(restored.tutorial == .fly && restored.tutorial == StarlitCartoucheTutorialStep.initial(level: 3))
        // The tutorial step is not digested, so the migrated state digests as the saved one.
        #expect(try Self.digest(restored) == Self.digest(core))
        // A level without the tutorial migrates with it done: the fresh opening of level 7.
        let seven: [String: Any] = try Core.migratedToSchemaTwo(["level": 7, "records": [Any]()])
        let sevenData: Data = try JSONSerialization.data(withJSONObject: seven, options: [.sortedKeys])
        let sevenCore: Core = try Core.restore(payload: sevenData, seed: 6)
        #expect(sevenCore == (try Core.opening(number: 7)) && sevenCore.tutorial == .done)
        // A schema-1 object that is not one is refused.
        #expect(throws: StarlitCartoucheRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": "3"]) }
        #expect(throws: StarlitCartoucheRestoreRefusal.damaged) { try Core.migratedToSchemaTwo(["level": 3]) }
        // A newer schema is refused by the chain.
        #expect(Core.schemaVersion == 2)
        #expect(throws: MigrationError.newerVersion(3)) { try Core.migrations.migrate(schemaOne, from: 3) }
    }

    @Test func theEngineMigratesASchemaOneEnvelopeAndRefusesANewerOne() async throws {
        let id: ExperienceID = try #require(ExperienceID(rawValue: Core.experienceID))
        var engine = ExperienceEngine<Core>(id: id)
        try await engine.prepare(seed: 2)
        try engine.activate()
        // Level 3: its first certified leg.
        let first: StarlitCartoucheAction = try #require(try Self.plan(3).first)
        guard case let .leg(star, wait) = first else { return }
        #expect(engine.handle(control: "route.fly", values: [Double(star), Double(wait)]) == .accepted)
        let played: Core = try #require(engine.core)
        let saved: ExperienceSnapshot = try engine.snapshot()
        let records: Data = try Core.payloadEncoder().encode(played.play.records)
        let recordsObject: Any = try JSONSerialization.jsonObject(with: records)
        let schemaOne: [String: Any] = ["level": 3, "records": recordsObject]
        let schemaOneData: Data = try JSONSerialization.data(withJSONObject: schemaOne, options: [.sortedKeys])
        let old = try ExperienceSnapshot(experience: id, schemaVersion: 1, seed: saved.seed,
                                         stepIndex: saved.stepIndex, digest: saved.digest, payload: schemaOneData)
        try engine.restore(old)
        let migrated: Core = try #require(engine.core)
        #expect(migrated.levelNumber == 3 && migrated.play == played.play && migrated.mode == .campaign)
        #expect(migrated.progress.frontier == 3 && migrated.progress.solved.isEmpty)
        #expect(migrated.tutorial == .fly && played.tutorial == .symbol)
        #expect(try engine.digest() == saved.digest)
        // An envelope of schema 3 is refused and changes nothing.
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
        #expect(engine.core == migrated)
    }

    @Test func noLevelIsGatedByAnythingButBeingOpened() async throws {
        // Opening through wins: levels 1 → 2 → 3 by their certified plans and level.next.
        var core: Core = try await Core.prepare(seed: 0)
        for number in 1...3 {
            #expect(core.levelNumber == number)
            for step in try Self.plan(number) { #expect(core.apply(Self.act(step)) == .accepted) }
            #expect(core.play.stage == .won && core.progress.frontier == number + 1)
            #expect(core.apply(Self.act("level.next")) == .accepted)
        }
        #expect(core.levelNumber == 4)
        // Opening through `open(through:)`: a saved progress with every level open makes every level selectable.
        var progress: StarlitCartoucheProgress = StarlitCartoucheProgress()
        progress.open(through: 100)
        #expect(progress.frontier == 100)
        let fresh: Core = try await Core.prepare(seed: 0)
        let text: String = String(decoding: try fresh.snapshotPayload(), as: UTF8.self)
        let progressJSON: String = String(decoding: try Core.payloadEncoder().encode(progress), as: UTF8.self)
        let allOpenText: String = text.replacingOccurrences(of: "\"progress\":{\"frontier\":1,\"solved\":[]}",
                                                            with: "\"progress\":" + progressJSON)
        #expect(allOpenText != text)
        let allOpen: Core = try Core.restore(payload: Data(allOpenText.utf8), seed: 0)
        #expect(allOpen.progress == progress)
        for number in 1...100 {
            #expect(allOpen.progress.isOpen(number))
            #expect(allOpen.progress.nextOpen(after: number) == (number < 100 ? number + 1 : nil))
        }
        // Selecting through the adapter: the last level of every band (the only refusal of `level.select` in range is
        // `progress.isOpen`).
        let samples: [Int] = [20, 40, 60, 80, 100]
        let refused: ActionResult = .rejected(.rule(code: "r02-g16.locked"))
        for number in samples {
            var copy: Core = allOpen
            #expect(copy.apply(Self.act("level.select", [Double(number)])) == .accepted, "level \(number)")
            #expect(copy.levelNumber == number && copy.mode == .campaign && copy.play.stage == .playing)
            #expect(copy.band == number / 20)
            var locked: Core = fresh
            #expect(locked.apply(Self.act("level.select", [Double(number)])) == refused)
        }
    }
}
